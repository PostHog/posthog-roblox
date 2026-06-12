--!nonstrict
-- In-memory event queue with batching, backoff, and the PostHog retry policy.
--
-- Fully dependency-injected so it can be unit-tested without any Roblox API:
--   opts.config      -> resolved config (projectKey, maxQueueSize, maxBatchSize)
--   opts.transport   -> { sendBatch(payload) -> { ok, statusCode, body } }
--   opts.logger      -> { debug, info, warn, error }
--   opts.retryPolicy -> { classify(status) -> "success"|"retry"|"retry_smaller"|"drop" }
--   opts.clock       -> { seconds() -> number, iso() -> string }
--
-- flush() yields through the transport; the caller decides threading (the SDK runs
-- it on a task thread). Concurrent flushes are guarded.

local RETRY_DELAY_SECONDS = 5
local MAX_RETRY_DELAY_SECONDS = 30

local EventQueue = {}
EventQueue.__index = EventQueue

function EventQueue.new(opts)
    return setmetatable({
        _config = opts.config,
        _transport = opts.transport,
        _logger = opts.logger,
        _retryPolicy = opts.retryPolicy,
        _clock = opts.clock,

        _events = {},
        _adjustedBatchSize = opts.config.maxBatchSize,
        _pausedUntil = 0,
        _retryCount = 0,
        _flushing = false,
    }, EventQueue)
end

function EventQueue:count(): number
    return #self._events
end

function EventQueue:clear()
    table.clear(self._events)
end

function EventQueue:enqueue(event)
    if #self._events >= self._config.maxQueueSize then
        -- Drop the oldest event to bound memory.
        table.remove(self._events, 1)
        self._logger:warn(`queue full ({self._config.maxQueueSize}), dropped oldest event`)
    end
    table.insert(self._events, event)
end

-- True when the queue has reached the flush-at threshold.
function EventQueue:shouldFlush(): boolean
    return #self._events >= self._config.flushAt
end

function EventQueue:_backoff()
    self._retryCount += 1
    local delay = math.min(self._retryCount * RETRY_DELAY_SECONDS, MAX_RETRY_DELAY_SECONDS)
    self._pausedUntil = self._clock.seconds() + delay
    self._logger:warn(`flush failed, retrying in {delay}s`)
end

function EventQueue:_takeBatch(): { any }
    local size = math.min(#self._events, self._adjustedBatchSize)
    local batch = table.create(size)
    for i = 1, size do
        batch[i] = self._events[i]
    end
    return batch
end

function EventQueue:_removeFront(count: number)
    for _ = 1, count do
        table.remove(self._events, 1)
    end
end

-- Sends queued events in batches until the queue is empty or a retry is scheduled.
function EventQueue:flush()
    if self._flushing then
        return
    end
    self._flushing = true

    local ok, err = pcall(function()
        if self._clock.seconds() < self._pausedUntil then
            return
        end

        while #self._events > 0 do
            local batch = self:_takeBatch()
            local payload = {
                api_key = self._config.projectKey,
                batch = batch,
                sent_at = self._clock.iso(),
            }

            local result = self._transport:sendBatch(payload)
            local action = self._retryPolicy.classify(result.statusCode)

            if action == "success" then
                self:_removeFront(#batch)
                self._retryCount = 0
                self._pausedUntil = 0
            elseif action == "drop" then
                self._logger:warn(
                    `dropping {#batch} events (non-retryable status {result.statusCode})`
                )
                self:_removeFront(#batch)
            elseif action == "retry_smaller" then
                self._adjustedBatchSize = math.max(1, math.floor(self._adjustedBatchSize / 2))
                self._logger:warn(
                    `payload too large, reducing batch size to {self._adjustedBatchSize}`
                )
                self:_backoff()
                return
            else -- "retry"
                self:_backoff()
                return
            end
        end
    end)

    self._flushing = false

    if not ok then
        self._logger:error(`flush error: {tostring(err)}`)
    end
end

return EventQueue
