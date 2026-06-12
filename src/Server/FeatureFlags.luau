--!nonstrict
-- Per-player feature flag manager. Fetches flags from /flags for a subject, caches
-- them on the subject's PlayerState, and emits deduplicated $feature_flag_called
-- events.

local FlagCache = require(script.Parent.FlagCache)
local Defaults = require(script.Parent.Parent.Shared.Defaults)
local Version = require(script.Parent.Parent.Shared.Version)

local FeatureFlags = {}
FeatureFlags.__index = FeatureFlags

-- opts: {
--   config, transport, logger,
--   capture = function(playerState, eventName, properties) -- emits an event
-- }
function FeatureFlags.new(opts)
    return setmetatable({
        _config = opts.config,
        _transport = opts.transport,
        _logger = opts.logger,
        _capture = opts.capture,
    }, FeatureFlags)
end

function FeatureFlags:_ensureStore(playerState)
    if not playerState.flagStore then
        playerState.flagStore = FlagCache.empty()
    end
    return playerState.flagStore
end

function FeatureFlags:_buildBody(playerState)
    local body = {
        api_key = self._config.projectKey,
        distinct_id = playerState.distinctId,
    }

    local groups = playerState:groupsOrNil()
    if groups then
        body["$groups"] = groups
    end

    -- person_properties: default device/lib props plus any caller-supplied ones.
    local personProps = nil
    if self._config.sendDefaultPersonPropertiesForFlags then
        personProps = {
            ["$lib"] = Version.LibraryName,
            ["$lib_version"] = Version.SdkVersion,
            ["$os"] = playerState.os or "Roblox",
        }
        if playerState.platform then
            personProps["$device_type"] = playerState.platform
        end
    end
    for key, value in playerState.personPropertiesForFlags do
        personProps = personProps or {}
        personProps[key] = value
    end
    if personProps then
        body["person_properties"] = personProps
    end

    -- group_properties: { [groupType]: { [key]: value } }
    local groupProps = nil
    for groupType, props in playerState.groupPropertiesForFlags do
        groupProps = groupProps or {}
        groupProps[groupType] = props
    end
    if groupProps then
        body["group_properties"] = groupProps
    end

    return body
end

-- Fetches flags for a subject. Yields on the network request. Returns success.
function FeatureFlags:reload(playerState): boolean
    local store = self:_ensureStore(playerState)
    local result = self._transport:fetchFlags(self:_buildBody(playerState))

    if result.ok and type(result.body) == "table" then
        FlagCache.applyResponse(store, result.body)
        playerState.flagsLoaded = true
        -- A new flag generation resets the called-event dedup.
        table.clear(playerState.flagCalled)
        self._logger:debug(`feature flags loaded for {playerState.distinctId}`)
        return true
    end

    self._logger:warn(
        `feature flags fetch failed for {playerState.distinctId} (status {result.statusCode})`
    )
    return false
end

function FeatureFlags:getValue(playerState, key: string): (boolean | string)?
    if not playerState.flagStore then
        return nil
    end
    return FlagCache.getValue(playerState.flagStore, key)
end

-- Builds the public FeatureFlag result table for a key.
function FeatureFlags:get(playerState, key: string)
    local value = self:getValue(playerState, key)
    local payload = playerState.flagStore and FlagCache.getPayload(playerState.flagStore, key)
        or nil

    local variant = if type(value) == "string" then value else nil

    return {
        key = key,
        value = if value == nil then false else value,
        isEnabled = FlagCache.isEnabled(value),
        variant = variant,
        payload = payload,
    }
end

-- Emits a deduplicated $feature_flag_called event for an accessed flag.
function FeatureFlags:trackCalled(playerState, key: string, value: boolean | string)
    if not self._config.sendFeatureFlagEvents then
        return
    end

    local dedupKey = `{playerState.distinctId}:{key}:{tostring(value)}`
    if playerState.flagCalled[dedupKey] then
        return
    end
    playerState.flagCalled[dedupKey] = true

    local props = {
        ["$feature_flag"] = key,
        ["$feature_flag_response"] = value,
    }

    local store = playerState.flagStore
    if store then
        if store.requestId ~= nil then
            props["$feature_flag_request_id"] = store.requestId
        end
        if store.evaluatedAt ~= nil then
            props["$feature_flag_evaluated_at"] = store.evaluatedAt
        end
        local details = store.details[key]
        if details then
            if details.id ~= nil then
                props["$feature_flag_id"] = details.id
            end
            if details.version ~= nil then
                props["$feature_flag_version"] = details.version
            end
            if details.reason ~= nil then
                props["$feature_flag_reason"] = details.reason
            end
        end
    end

    self._capture(playerState, Defaults.EVENTS.FEATURE_FLAG_CALLED, props)
end

function FeatureFlags:setPersonProperties(playerState, properties)
    for key, value in properties do
        playerState.personPropertiesForFlags[key] = value
    end
end

function FeatureFlags:resetPersonProperties(playerState)
    table.clear(playerState.personPropertiesForFlags)
end

function FeatureFlags:setGroupProperties(playerState, groupType: string, properties)
    local existing = playerState.groupPropertiesForFlags[groupType] or {}
    for key, value in properties do
        existing[key] = value
    end
    playerState.groupPropertiesForFlags[groupType] = existing
end

function FeatureFlags:resetGroupProperties(playerState, groupType: string?)
    if groupType then
        playerState.groupPropertiesForFlags[groupType] = nil
    else
        table.clear(playerState.groupPropertiesForFlags)
    end
end

return FeatureFlags
