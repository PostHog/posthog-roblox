--!nonstrict
-- Server-side error capture. Listens to ScriptContext.Error for unhandled errors,
-- debounces them, and emits PostHog `$exception` events through an injected sink.
-- Client errors arrive separately via the relay and are not handled here.

local ScriptContext = game:GetService("ScriptContext")

local ExceptionBuilder = require(script.Parent.ExceptionBuilder)

local ErrorTracking = {}
ErrorTracking.__index = ErrorTracking

-- opts: {
--   config, logger,
--   now = () -> number,                 -- monotonic seconds, for debounce
--   captureException = function(props), -- emits the built $exception properties
-- }
function ErrorTracking.new(opts)
    return setmetatable({
        _config = opts.config,
        _logger = opts.logger,
        _now = opts.now,
        _captureException = opts.captureException,
        _connection = nil,
        _lastCaptureTime = -math.huge,
    }, ErrorTracking)
end

function ErrorTracking:start()
    if self._connection then
        return
    end

    self._connection = ScriptContext.Error:Connect(function(message, trace, _script)
        self:_onError(message, trace)
    end)
    self._logger:debug("error tracking started")
end

function ErrorTracking:_shouldCapture(): boolean
    local debounce = self._config.errorDebounceSeconds
    if not debounce or debounce <= 0 then
        return true
    end
    return (self._now() - self._lastCaptureTime) >= debounce
end

function ErrorTracking:_onError(message: string, trace: string?)
    if not self:_shouldCapture() then
        return
    end
    self._lastCaptureTime = self._now()

    local props = ExceptionBuilder.build(message, trace, {
        handled = false,
        mechanismType = "roblox.ScriptContext",
    })
    self._captureException(props)
end

function ErrorTracking:stop()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return ErrorTracking
