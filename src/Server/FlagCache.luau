--!nonstrict
-- Pure feature-flag store. Operates on already-decoded /flags response tables, so
-- it has no Roblox dependency and is unit-testable in isolation.
--
-- A "store" is a plain table:
--   { values = { [key]: boolean|string },   -- resolved flag value
--     payloads = { [key]: any },             -- decoded JSON payload
--     details = { [key]: { id, version, reason } }, -- v4 metadata (for $feature_flag_called)
--     requestId = string?,
--     evaluatedAt = number? }
--
-- Resolution: v4 (`flags`) takes priority over v3 (`featureFlags`). A non-empty
-- `quotaLimited` array wipes all cached flags.

local FlagCache = {}

function FlagCache.empty()
    return {
        values = {},
        payloads = {},
        details = {},
        requestId = nil,
        evaluatedAt = nil,
    }
end

local function isNonEmptyArray(value: any): boolean
    return type(value) == "table" and #value > 0
end

-- Resolves the value a v4 flag entry represents: a non-empty variant string, else
-- the boolean enabled state.
local function resolveV4Value(flag: any): boolean | string
    local variant = flag.variant
    if type(variant) == "string" and variant ~= "" then
        return variant
    end
    return flag.enabled == true
end

-- Merges a decoded /flags response into the store (in place).
function FlagCache.applyResponse(store, response)
    if type(response) ~= "table" then
        return
    end

    store.requestId = response.requestId
    store.evaluatedAt = response.evaluatedAt

    -- Quota limited: clear everything, keep request metadata.
    if isNonEmptyArray(response.quotaLimited) then
        table.clear(store.values)
        table.clear(store.payloads)
        table.clear(store.details)
        return
    end

    -- v3 format.
    if type(response.featureFlags) == "table" then
        for key, value in response.featureFlags do
            store.values[key] = value
        end
    end
    if type(response.featureFlagPayloads) == "table" then
        for key, payload in response.featureFlagPayloads do
            store.payloads[key] = payload
        end
    end

    -- v4 format overrides v3 for matching keys.
    if type(response.flags) == "table" then
        for key, flag in response.flags do
            if type(flag) == "table" then
                store.values[key] = resolveV4Value(flag)

                local metadata = flag.metadata
                if type(metadata) == "table" then
                    if metadata.payload ~= nil then
                        store.payloads[key] = metadata.payload
                    end

                    local reason = flag.reason
                    store.details[key] = {
                        id = metadata.id,
                        version = metadata.version,
                        reason = type(reason) == "table" and reason.description or nil,
                    }
                end
            end
        end
    end
end

function FlagCache.getValue(store, key: string): (boolean | string)?
    return store.values[key]
end

function FlagCache.getPayload(store, key: string): any?
    return store.payloads[key]
end

function FlagCache.getDetails(store, key: string): any?
    return store.details[key]
end

-- A flag is "enabled" when it is boolean true or a non-empty variant string.
function FlagCache.isEnabled(value: (boolean | string)?): boolean
    if type(value) == "string" then
        return value ~= ""
    end
    return value == true
end

return FlagCache
