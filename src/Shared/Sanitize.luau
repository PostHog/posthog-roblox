--!nonstrict
-- Makes event properties safe to JSON-encode.
--
-- HttpService:JSONEncode throws on values it cannot represent (Instances, Roblox
-- datatypes, functions, cyclic tables, NaN/inf). A single bad value would otherwise
-- jam the whole event queue, so every event's properties are run through here first:
--   - strings / booleans / finite numbers pass through
--   - NaN and infinities become strings
--   - Roblox datatypes (userdata) are stringified
--   - functions and threads are dropped
--   - tables are cleaned recursively, with cycle and depth guards
--
-- Pure Luau (uses only `type`), so it is unit-testable without any Roblox API.

local MAX_DEPTH = 8

local Sanitize = {}

local function clean(value: any, depth: number, seen: { [any]: boolean }): any
    local valueType = type(value)

    if valueType == "string" or valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        -- NaN (value ~= value) and infinities are not valid JSON.
        if value ~= value or value == math.huge or value == -math.huge then
            return tostring(value)
        end
        return value
    end

    if valueType == "table" then
        if depth > MAX_DEPTH or seen[value] then
            return nil
        end
        seen[value] = true

        local out = {}
        for key, item in value do
            local keyType = type(key)
            if keyType == "string" or keyType == "number" then
                local cleaned = clean(item, depth + 1, seen)
                if cleaned ~= nil then
                    out[key] = cleaned
                end
            end
        end

        seen[value] = nil
        return out
    end

    -- Roblox datatypes (Instance, Vector3, EnumItem, ...) are userdata: stringify them.
    if valueType == "userdata" then
        return tostring(value)
    end

    -- functions / threads are dropped.
    return nil
end

-- Returns a JSON-safe deep copy of a properties table.
function Sanitize.clean(value: any): any
    return clean(value, 0, {})
end

return Sanitize
