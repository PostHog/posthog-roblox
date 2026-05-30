--!nonstrict
local h = require("./helper")
local EventQueue = require("../src/Server/EventQueue")
local RetryPolicy = require("../src/Shared/RetryPolicy")

local function noopLogger()
    return {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
    }
end

local function fakeClock()
    local t = 0
    local clock = {
        seconds = function()
            return t
        end,
        iso = function()
            return "2026-01-01T00:00:00Z"
        end,
    }
    local function setSeconds(value)
        t = value
    end
    return clock, setSeconds
end

local function fakeTransport(responses)
    return {
        calls = {},
        _idx = 0,
        sendBatch = function(self, payload)
            self._idx += 1
            table.insert(self.calls, payload)
            return responses[self._idx] or responses[#responses] or { ok = true, statusCode = 200 }
        end,
    }
end

local function makeConfig(overrides)
    local config = { apiKey = "phc_test", maxQueueSize = 5, maxBatchSize = 2, flushAt = 3 }
    if overrides then
        for key, value in overrides do
            config[key] = value
        end
    end
    return config
end

local function event(name)
    return { uuid = name, event = name, distinct_id = "d", timestamp = "t", properties = {} }
end

local function newQueue(config, transport, clock)
    return EventQueue.new({
        config = config,
        transport = transport,
        logger = noopLogger(),
        retryPolicy = RetryPolicy,
        clock = clock,
    })
end

h.test("EventQueue: delivers and empties on success", function()
    local transport = fakeTransport({ { ok = true, statusCode = 200 } })
    local queue = newQueue(makeConfig(), transport, (fakeClock()))
    queue:enqueue(event("a"))
    queue:enqueue(event("b"))
    queue:flush()

    h.expectEqual(queue:count(), 0, "queue drained")
    h.expectEqual(#transport.calls, 1, "single batch for 2 events")
    h.expectEqual(#transport.calls[1].batch, 2)
    h.expectEqual(transport.calls[1].api_key, "phc_test")
    h.expectEqual(transport.calls[1].sent_at, "2026-01-01T00:00:00Z")
end)

h.test("EventQueue: splits into batches of maxBatchSize", function()
    local transport = fakeTransport({ { ok = true, statusCode = 200 } })
    local queue = newQueue(makeConfig(), transport, (fakeClock()))
    for i = 1, 3 do
        queue:enqueue(event("e" .. i))
    end
    queue:flush()

    h.expectEqual(queue:count(), 0)
    h.expectEqual(#transport.calls, 2, "3 events -> two batches")
    h.expectEqual(#transport.calls[1].batch, 2)
    h.expectEqual(#transport.calls[2].batch, 1)
end)

h.test("EventQueue: retains events and pauses on 500", function()
    local clock, setSeconds = fakeClock()
    local transport = fakeTransport({ { ok = false, statusCode = 500 } })
    local queue = newQueue(makeConfig(), transport, clock)
    queue:enqueue(event("a"))

    queue:flush()
    h.expectEqual(queue:count(), 1, "event retained on server error")

    queue:flush()
    h.expectEqual(#transport.calls, 1, "no resend while paused")

    setSeconds(100)
    queue:flush()
    h.expectEqual(#transport.calls, 2, "retries after the pause expires")
end)

h.test("EventQueue: drops events on a non-retryable 400", function()
    local transport = fakeTransport({ { ok = false, statusCode = 400 } })
    local queue = newQueue(makeConfig(), transport, (fakeClock()))
    queue:enqueue(event("a"))
    queue:flush()
    h.expectEqual(queue:count(), 0, "events dropped on 400")
end)

h.test("EventQueue: halves the batch size on 413", function()
    local clock, setSeconds = fakeClock()
    local transport = fakeTransport({
        { ok = false, statusCode = 413 },
        { ok = true, statusCode = 200 },
        { ok = true, statusCode = 200 },
    })
    local queue = newQueue(makeConfig({ maxBatchSize = 2, maxQueueSize = 10 }), transport, clock)
    queue:enqueue(event("a"))
    queue:enqueue(event("b"))

    queue:flush()
    h.expectEqual(#transport.calls[1].batch, 2, "first attempt used the full batch")
    h.expectEqual(queue:count(), 2, "events retained after 413")

    setSeconds(1000)
    queue:flush()
    h.expectEqual(queue:count(), 0, "drained after halving")
    h.expectEqual(#transport.calls[2].batch, 1, "batch size reduced to 1")
end)

h.test("EventQueue: drops the oldest event when over capacity", function()
    local transport = fakeTransport({ { ok = true, statusCode = 200 } })
    local queue = newQueue(
        makeConfig({ maxQueueSize = 3, flushAt = 999, maxBatchSize = 10 }),
        transport,
        (fakeClock())
    )
    for i = 1, 5 do
        queue:enqueue(event("e" .. i))
    end
    h.expectEqual(queue:count(), 3, "queue capped at maxQueueSize")

    queue:flush()
    h.expectEqual(transport.calls[1].batch[1].event, "e3", "oldest survivors are e3..e5")
    h.expectEqual(transport.calls[1].batch[3].event, "e5")
end)

h.test("EventQueue: shouldFlush reflects the flushAt threshold", function()
    local queue = newQueue(makeConfig({ flushAt = 2 }), fakeTransport({}), (fakeClock()))
    queue:enqueue(event("a"))
    h.expectFalse(queue:shouldFlush())
    queue:enqueue(event("b"))
    h.expectTrue(queue:shouldFlush())
end)

h.test("EventQueue: clear empties the queue", function()
    local queue = newQueue(makeConfig(), fakeTransport({}), (fakeClock()))
    queue:enqueue(event("a"))
    queue:enqueue(event("b"))
    queue:clear()
    h.expectEqual(queue:count(), 0)
end)

return true
