--!nonstrict
-- Per-subject state held on the server. A subject is usually a player (keyed by
-- their UserId as a string) but can also be the server pseudo-subject or an
-- arbitrary distinct id passed by server code.

local PlayerState = {}
PlayerState.__index = PlayerState

export type PlayerState = typeof(setmetatable({}, PlayerState))

-- info: {
--   userId: number?,        -- numeric Roblox UserId, nil for non-player subjects
--   isServer: boolean?,     -- true for the server pseudo-subject
--   session: { id: string, startTime: number }?,
--   platform: string?,      -- "Mobile" | "Console" | "Desktop", relayed from client
-- }
function PlayerState.new(distinctId: string, info: any?): PlayerState
    info = info or {}
    return setmetatable({
        distinctId = distinctId,
        userId = info.userId,
        isServer = info.isServer == true,

        session = info.session,

        -- Identity / targeting.
        groups = {}, -- { [groupType]: groupKey }
        isIdentified = false,
        optedOut = false,

        -- Device context relayed from the client (players only).
        platform = info.platform,
        os = info.os,
        countryCode = nil,

        -- Feature flags (managed by the FeatureFlags module).
        flagStore = nil, -- FlagCache store table
        flagsLoaded = false,
        personPropertiesForFlags = {},
        groupPropertiesForFlags = {}, -- { [groupType]: { [key]: value } }
        flagCalled = {}, -- dedup set: { ["distinctId:key:value"] = true }

        -- Client relay rate limiting (token bucket).
        rateTokens = nil,
        rateLastRefill = nil,
    }, PlayerState)
end

function PlayerState:setGroup(groupType: string, groupKey: string)
    self.groups[groupType] = groupKey
end

-- Returns a shallow copy of groups, or nil when there are none (so callers can
-- omit an empty `$groups` object rather than serialize `{}` as `[]`).
function PlayerState:groupsOrNil(): { [string]: string }?
    local copy = nil
    for groupType, groupKey in self.groups do
        copy = copy or {}
        copy[groupType] = groupKey
    end
    return copy
end

return PlayerState
