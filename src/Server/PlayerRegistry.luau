--!nonstrict
-- Owns the set of live PlayerState objects, keyed by distinct id.

local PlayerState = require(script.Parent.PlayerState)

local PlayerRegistry = {}
PlayerRegistry.__index = PlayerRegistry

function PlayerRegistry.new()
    return setmetatable({
        _byDistinctId = {},
    }, PlayerRegistry)
end

-- Returns the existing state for a distinct id, or creates a bare one. `info` is
-- only applied when a new state is created.
function PlayerRegistry:getOrCreate(distinctId: string, info: any?): PlayerState.PlayerState
    local existing = self._byDistinctId[distinctId]
    if existing then
        return existing
    end

    local state = PlayerState.new(distinctId, info)
    self._byDistinctId[distinctId] = state
    return state
end

function PlayerRegistry:get(distinctId: string): PlayerState.PlayerState?
    return self._byDistinctId[distinctId]
end

function PlayerRegistry:remove(distinctId: string)
    self._byDistinctId[distinctId] = nil
end

function PlayerRegistry:all(): { [string]: PlayerState.PlayerState }
    return self._byDistinctId
end

return PlayerRegistry
