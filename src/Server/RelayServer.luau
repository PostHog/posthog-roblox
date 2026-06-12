--!nonstrict
-- Server side of the client relay. Owns a RemoteEvent under ReplicatedStorage,
-- validates incoming client messages, rate-limits them per player, and attributes
-- them to the firing player (never to a client-supplied id).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ExceptionBuilder = require(script.Parent.ExceptionBuilder)
local Defaults = require(script.Parent.Parent.Shared.Defaults)

local RelayServer = {}
RelayServer.__index = RelayServer

-- opts: {
--   config, logger, registry,
--   now = () -> number,                              -- monotonic seconds
--   capture = function(playerState, eventName, props),
--   captureException = function(playerState, props),
-- }
function RelayServer.new(opts)
    return setmetatable({
        _config = opts.config,
        _logger = opts.logger,
        _registry = opts.registry,
        _now = opts.now,
        _capture = opts.capture,
        _captureException = opts.captureException,
        _remote = nil,
        _connection = nil,
    }, RelayServer)
end

function RelayServer:start()
    local remote = ReplicatedStorage:FindFirstChild(Defaults.REMOTE_NAME)
    if not remote then
        remote = Instance.new("RemoteEvent")
        remote.Name = Defaults.REMOTE_NAME
        remote.Parent = ReplicatedStorage
    end
    self._remote = remote

    self._connection = remote.OnServerEvent:Connect(function(player, message)
        local ok, err = pcall(function()
            self:_handle(player, message)
        end)
        if not ok then
            self._logger:warn(`relay handler error: {tostring(err)}`)
        end
    end)
    self._logger:debug("client relay started")
end

function RelayServer:_stateFor(player: Player)
    local distinctId = tostring(player.UserId)
    return self._registry:getOrCreate(distinctId, { userId = player.UserId })
end

-- Token-bucket rate limit per player. Returns true when the message should drop.
function RelayServer:_rateLimited(state): boolean
    local rate = self._config.clientRateLimitPerSecond
    local now = self._now()

    if state.rateTokens == nil then
        state.rateTokens = rate
        state.rateLastRefill = now
    else
        local elapsed = now - state.rateLastRefill
        state.rateTokens = math.min(rate, state.rateTokens + elapsed * rate)
        state.rateLastRefill = now
    end

    if state.rateTokens < 1 then
        return true
    end
    state.rateTokens -= 1
    return false
end

-- Clients may only send scalar property values, capped in count. This bounds
-- payload size and avoids trusting nested/structured data from an untrusted client.
function RelayServer:_sanitize(properties): { [string]: any }
    local out = {}
    if type(properties) ~= "table" then
        return out
    end

    local count = 0
    local max = self._config.maxClientPropertyCount
    for key, value in properties do
        if type(key) == "string" then
            local valueType = type(value)
            if valueType == "string" or valueType == "number" or valueType == "boolean" then
                out[key] = value
                count += 1
                if count >= max then
                    break
                end
            end
        end
    end
    return out
end

function RelayServer:_handle(player: Player, message: any)
    if type(message) ~= "table" or type(message.kind) ~= "string" then
        return
    end

    local state = self:_stateFor(player)

    -- Capture device context relayed from the client.
    local context = message.context
    if type(context) == "table" then
        if type(context.platform) == "string" then
            state.platform = context.platform
        end
        if type(context.os) == "string" then
            state.os = context.os
        end
    end

    if self:_rateLimited(state) then
        return
    end

    local kind = message.kind

    if kind == "capture" then
        local name = message.name
        if type(name) ~= "string" or name == "" then
            return
        end
        -- Clients cannot emit reserved ($-prefixed) system events.
        if name:sub(1, 1) == "$" then
            self._logger:warn(`client tried to send reserved event "{name}", ignored`)
            return
        end
        self._capture(state, name, self:_sanitize(message.properties))
    elseif kind == "screen" then
        if type(message.name) ~= "string" then
            return
        end
        local props = self:_sanitize(message.properties)
        props["$screen_name"] = message.name
        self._capture(state, Defaults.EVENTS.SCREEN, props)
    elseif kind == "exception" then
        local text = if type(message.message) == "string" then message.message else ""
        local trace = if type(message.trace) == "string" then message.trace else nil
        local errorType = if type(message.errorType) == "string" then message.errorType else nil
        local props = ExceptionBuilder.build(text, trace, {
            handled = message.handled == true,
            exceptionType = errorType,
            mechanismType = "roblox.client",
        })
        for key, value in self:_sanitize(message.properties) do
            props[key] = value
        end
        self._captureException(state, props)
    end
end

function RelayServer:stop()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return RelayServer
