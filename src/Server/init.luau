--!nonstrict
-- PostHog Roblox SDK - server entry point and public API.
--
-- This is the server-authoritative singleton. It owns the event queue, HTTP
-- transport, per-player state, feature flags, error tracking, autocapture, and the
-- client relay. Every public method takes an explicit `subject` so server code can
-- attribute an event to any player, an arbitrary distinct id, or the server itself.
--
-- Subject resolution:
--   Player instance -> tostring(player.UserId)
--   number          -> tostring(number)         (a UserId or any id)
--   string          -> used as the distinct id
--   nil             -> the server pseudo-subject (config.serverDistinctId)

local RunService = game:GetService("RunService")

local Defaults = require(script.Parent.Shared.Defaults)
local Logger = require(script.Parent.Shared.Logger)
local Uuid = require(script.Parent.Shared.Uuid)
local RetryPolicy = require(script.Parent.Shared.RetryPolicy)
local Version = require(script.Parent.Shared.Version)
local Sanitize = require(script.Parent.Shared.Sanitize)

local Context = require(script.Context)
local Transport = require(script.Transport)
local EventQueue = require(script.EventQueue)
local PlayerRegistry = require(script.PlayerRegistry)
local Session = require(script.Session)
local FlagCache = require(script.FlagCache)
local FeatureFlags = require(script.FeatureFlags)
local ExceptionBuilder = require(script.ExceptionBuilder)
local ErrorTracking = require(script.ErrorTracking)
local Autocapture = require(script.Autocapture)
local RelayServer = require(script.RelayServer)
local MemoryStorage = require(script.Storage.MemoryStorage)

local Types = require(script.Parent.Shared.Types)

local PostHog = {}

-- Private singleton state.
local S = {
    started = false,
    config = nil,
    logger = nil,
    uuid = nil,
    clock = nil,
    context = nil,
    transport = nil,
    queue = nil,
    registry = nil,
    featureFlags = nil,
    errorTracking = nil,
    autocapture = nil,
    relay = nil,
    storage = nil,
    serverState = nil,
    superProperties = {},
    bindToCloseRegistered = false,
}

-- Forward declarations so closures can reference helpers defined below.
local captureWithState
local resolveSubject

local function isNonEmpty(t: any): boolean
    return type(t) == "table" and next(t) ~= nil
end

local function shallowCopy(t)
    if t then
        return table.clone(t)
    end
    return {}
end

local function scheduleFlush()
    task.spawn(function()
        S.queue:flush()
    end)
end

local function buildEventProperties(playerState, provided, opts)
    opts = opts or {}
    local serverScoped = opts.serverScoped or playerState.isServer

    -- Super properties (global) are the lowest priority base.
    local props = table.clone(S.superProperties)

    -- Caller-provided properties override super properties.
    if provided then
        for key, value in provided do
            props[key] = value
        end
    end

    -- SDK / context properties override everything.
    for key, value in S.context:base() do
        props[key] = value
    end

    if playerState.session then
        props["$session_id"] = playerState.session.id
    end

    local groups = playerState:groupsOrNil()
    if groups then
        props["$groups"] = groups
    end

    if serverScoped then
        props["$os"] = "Roblox"
        props["$device_type"] = "Server"
    else
        props["$os"] = playerState.os or "Roblox"
        if playerState.platform then
            props["$device_type"] = playerState.platform
        end
    end

    -- Person profile processing. "always" never disables it; "never" always does;
    -- "identified_only" disables it only for server-scoped events (players carry a
    -- real UserId identity).
    local mode = S.config.personProfiles
    if mode == "never" or (mode == "identified_only" and serverScoped) then
        props["$process_person_profile"] = false
    end

    return props
end

function captureWithState(playerState, eventName, provided, opts)
    if not S.started then
        S.logger:warn("Capture called before Init; event dropped")
        return
    end
    if playerState.optedOut then
        return
    end
    if type(eventName) ~= "string" or eventName == "" then
        S.logger:warn("Capture called with an empty event name")
        return
    end

    local event = {
        uuid = S.uuid:generate(),
        event = eventName,
        distinct_id = playerState.distinctId,
        timestamp = S.clock.iso(),
        -- Sanitize so a non-encodable value can never jam the queue.
        properties = Sanitize.clean(buildEventProperties(playerState, provided, opts)),
    }

    S.queue:enqueue(event)
    if S.queue:shouldFlush() then
        scheduleFlush()
    end
end

function resolveSubject(subject): (any, boolean)
    if subject == nil then
        return S.serverState, true
    end

    local kind = typeof(subject)

    if kind == "Instance" and subject:IsA("Player") then
        local distinctId = tostring(subject.UserId)
        local state = S.registry:get(distinctId)
        if not state then
            state = S.registry:getOrCreate(distinctId, {
                userId = subject.UserId,
                session = Session.create(S.uuid, os.time()),
            })
        elseif not state.session then
            state.session = Session.create(S.uuid, os.time())
        end
        return state, false
    elseif kind == "number" then
        return S.registry:getOrCreate(tostring(subject), {}), false
    elseif kind == "string" then
        return S.registry:getOrCreate(subject, {}), false
    end

    S.logger:warn(`invalid subject type "{kind}", treating as server-scoped`)
    return S.serverState, true
end

local function ensureStarted(): boolean
    if not S.started then
        warn("[PostHog] SDK not initialized. Call PostHog:Init({ apiKey = ... }) first.")
        return false
    end
    return true
end

local function startFlushLoop()
    task.spawn(function()
        while S.started do
            task.wait(S.config.flushIntervalSeconds)
            if S.started and S.queue:count() > 0 then
                S.queue:flush()
            end
        end
    end)
end

local function onBindToClose()
    if not S.queue then
        return
    end

    -- Studio fires BindToClose instantly with no real shutdown window.
    local budget = if RunService:IsStudio() then 2 else Defaults.SHUTDOWN_FLUSH_BUDGET_SECONDS
    local deadline = os.clock() + budget

    repeat
        S.queue:flush()
        if S.queue:count() > 0 then
            task.wait(0.3)
        end
    until S.queue:count() == 0 or os.clock() >= deadline
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function PostHog:Init(userConfig: Types.Config)
    if not RunService:IsServer() then
        warn("[PostHog] Init() must be called from a server Script; ignored on the client.")
        return self
    end
    if S.started then
        S.logger:warn("PostHog already initialized")
        return self
    end

    local config = Defaults.resolve(userConfig)
    S.config = config
    S.logger = Logger.new(config.logLevel)
    S.storage = config.storage or MemoryStorage.new()

    local rng = Random.new()
    S.uuid = Uuid.new({
        nowMillis = function()
            return DateTime.now().UnixTimestampMillis
        end,
        randomByte = function()
            return rng:NextInteger(0, 255)
        end,
    })

    S.clock = {
        seconds = function()
            return os.clock()
        end,
        iso = function()
            return DateTime.now():ToIsoDate()
        end,
    }

    S.context = Context.new()
    S.transport = Transport.new({ host = config.host, logger = S.logger })
    S.queue = EventQueue.new({
        config = config,
        transport = S.transport,
        logger = S.logger,
        retryPolicy = RetryPolicy,
        clock = S.clock,
    })
    S.registry = PlayerRegistry.new()
    S.superProperties = {}

    -- Server pseudo-subject gets its own session for the server's lifetime.
    S.serverState = S.registry:getOrCreate(config.serverDistinctId, {
        isServer = true,
        session = Session.create(S.uuid, os.time()),
    })

    S.featureFlags = FeatureFlags.new({
        config = config,
        transport = S.transport,
        logger = S.logger,
        capture = function(playerState, eventName, props)
            captureWithState(playerState, eventName, props)
        end,
    })

    S.started = true

    if config.captureErrors then
        S.errorTracking = ErrorTracking.new({
            config = config,
            logger = S.logger,
            now = function()
                return os.clock()
            end,
            captureException = function(props)
                captureWithState(S.serverState, Defaults.EVENTS.EXCEPTION, props, {
                    serverScoped = true,
                })
            end,
        })
        S.errorTracking:start()
    end

    S.autocapture = Autocapture.new({
        config = config,
        logger = S.logger,
        registry = S.registry,
        uuid = S.uuid,
        now = function()
            return os.time()
        end,
        capture = function(playerState, eventName, props)
            captureWithState(playerState, eventName, props)
        end,
        onPlayerReady = function(_player, playerState)
            if config.preloadFeatureFlags then
                task.spawn(function()
                    S.featureFlags:reload(playerState)
                end)
            end
        end,
    })
    S.autocapture:start()

    if config.enableClientRelay then
        S.relay = RelayServer.new({
            config = config,
            logger = S.logger,
            registry = S.registry,
            now = function()
                return os.clock()
            end,
            capture = function(playerState, eventName, props)
                captureWithState(playerState, eventName, props)
            end,
            captureException = function(playerState, props)
                captureWithState(playerState, Defaults.EVENTS.EXCEPTION, props)
            end,
        })
        S.relay:start()
    end

    startFlushLoop()

    if not S.bindToCloseRegistered then
        game:BindToClose(onBindToClose)
        S.bindToCloseRegistered = true
    end

    S.logger:info(`PostHog initialized (posthog-roblox {Version.SdkVersion})`)
    return self
end

function PostHog:IsInitialized(): boolean
    return S.started
end

function PostHog:Capture(subject: any, eventName: string, properties: Types.Properties?)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    captureWithState(state, eventName, properties, { serverScoped = serverScoped })
end

function PostHog:Screen(subject: any, screenName: string, properties: Types.Properties?)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    local props = shallowCopy(properties)
    props["$screen_name"] = screenName
    captureWithState(state, Defaults.EVENTS.SCREEN, props, { serverScoped = serverScoped })
end

function PostHog:Identify(
    subject: any,
    setProperties: Types.Properties?,
    setOnceProperties: Types.Properties?
)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    state.isIdentified = true

    -- Cache person properties for feature flags before reloading.
    if isNonEmpty(setProperties) or isNonEmpty(setOnceProperties) then
        local merged = {}
        if setOnceProperties then
            for key, value in setOnceProperties do
                merged[key] = value
            end
        end
        if setProperties then
            for key, value in setProperties do
                merged[key] = value
            end
        end
        S.featureFlags:setPersonProperties(state, merged)
    end

    local props = {}
    if isNonEmpty(setProperties) then
        props["$set"] = setProperties
    end
    if isNonEmpty(setOnceProperties) then
        props["$set_once"] = setOnceProperties
    end
    captureWithState(state, Defaults.EVENTS.IDENTIFY, props, { serverScoped = serverScoped })

    if S.config.preloadFeatureFlags then
        task.spawn(function()
            S.featureFlags:reload(state)
        end)
    end
end

function PostHog:Alias(subject: any, alias: string)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    captureWithState(state, Defaults.EVENTS.CREATE_ALIAS, { alias = alias }, {
        serverScoped = serverScoped,
    })
end

function PostHog:Group(
    subject: any,
    groupType: string,
    groupKey: string,
    groupProperties: Types.Properties?
)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    state:setGroup(groupType, groupKey)

    local props = {
        ["$group_type"] = groupType,
        ["$group_key"] = groupKey,
    }
    if isNonEmpty(groupProperties) then
        props["$group_set"] = groupProperties
    end
    captureWithState(state, Defaults.EVENTS.GROUP_IDENTIFY, props, { serverScoped = serverScoped })
end

function PostHog:Register(key: string, value: any)
    S.superProperties[key] = value
end

function PostHog:Unregister(key: string)
    S.superProperties[key] = nil
end

function PostHog:CaptureException(
    subject: any,
    message: string,
    trace: string?,
    properties: Types.Properties?
)
    if not ensureStarted() then
        return
    end
    local state, serverScoped = resolveSubject(subject)
    local props = ExceptionBuilder.build(message, trace, {
        handled = true,
        mechanismType = "generic",
    })
    if properties then
        for key, value in properties do
            props[key] = value
        end
    end
    captureWithState(state, Defaults.EVENTS.EXCEPTION, props, { serverScoped = serverScoped })
end

function PostHog:GetFeatureFlag(subject: any, key: string): Types.FeatureFlag
    if not ensureStarted() then
        return { key = key, value = false, isEnabled = false, variant = nil, payload = nil }
    end
    local state = resolveSubject(subject)
    local result = S.featureFlags:get(state, key)

    local value = S.featureFlags:getValue(state, key)
    if value ~= nil then
        S.featureFlags:trackCalled(state, key, value)
    end
    return result
end

function PostHog:IsFeatureEnabled(subject: any, key: string, default: boolean?): boolean
    if not ensureStarted() then
        return default == true
    end
    local state = resolveSubject(subject)
    local value = S.featureFlags:getValue(state, key)
    if value == nil then
        return default == true
    end
    S.featureFlags:trackCalled(state, key, value)
    return FlagCache.isEnabled(value)
end

function PostHog:GetFeatureFlagPayload(subject: any, key: string): any?
    if not ensureStarted() then
        return nil
    end
    local state = resolveSubject(subject)
    if not state.flagStore then
        return nil
    end
    return FlagCache.getPayload(state.flagStore, key)
end

-- Reloads feature flags for a subject. Yields on the network request.
function PostHog:ReloadFeatureFlags(subject: any): boolean
    if not ensureStarted() then
        return false
    end
    local state = resolveSubject(subject)
    return S.featureFlags:reload(state)
end

function PostHog:SetPersonPropertiesForFlags(
    subject: any,
    properties: Types.Properties,
    reload: boolean?
)
    if not ensureStarted() then
        return
    end
    local state = resolveSubject(subject)
    S.featureFlags:setPersonProperties(state, properties)
    if reload ~= false then
        task.spawn(function()
            S.featureFlags:reload(state)
        end)
    end
end

function PostHog:SetGroupPropertiesForFlags(
    subject: any,
    groupType: string,
    properties: Types.Properties,
    reload: boolean?
)
    if not ensureStarted() then
        return
    end
    local state = resolveSubject(subject)
    S.featureFlags:setGroupProperties(state, groupType, properties)
    if reload ~= false then
        task.spawn(function()
            S.featureFlags:reload(state)
        end)
    end
end

-- Returns a TeleportData fragment a game merges in before teleporting so the
-- player's session continues at the destination place.
function PostHog:GetSessionTeleportData(player: Player): { [string]: any }
    if not ensureStarted() then
        return {}
    end
    local state = resolveSubject(player)
    if state.session then
        return Session.toTeleportData(state.session)
    end
    return {}
end

function PostHog:OptOut(subject: any)
    if not ensureStarted() then
        return
    end
    local state = resolveSubject(subject)
    state.optedOut = true
end

function PostHog:OptIn(subject: any)
    if not ensureStarted() then
        return
    end
    local state = resolveSubject(subject)
    state.optedOut = false
end

function PostHog:Flush()
    if not ensureStarted() then
        return
    end
    scheduleFlush()
end

function PostHog:Shutdown()
    if not S.started then
        return
    end
    S.started = false
    if S.errorTracking then
        S.errorTracking:stop()
    end
    if S.autocapture then
        S.autocapture:stop()
    end
    if S.relay then
        S.relay:stop()
    end
    if S.queue then
        S.queue:flush()
    end
    S.logger:info("PostHog shut down")
end

return PostHog
