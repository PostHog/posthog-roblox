--!nonstrict
-- Builds the standard property set attached to every event.
--
-- Server-wide properties (library + place identifiers) are computed once and
-- cached. Per-event values ($session_id, $groups, $device_type, ...) are added by
-- the capture pipeline, which has the subject in hand.

local Version = require(script.Parent.Parent.Shared.Version)

local Context = {}
Context.__index = Context

function Context.new()
    local self = setmetatable({}, Context)

    -- Place/game identifiers are constant for the lifetime of the server.
    self._serverProps = {
        ["$lib"] = Version.LibraryName,
        ["$lib_version"] = Version.SdkVersion,
        place_id = game.PlaceId,
        place_version = game.PlaceVersion,
        game_id = game.GameId,
        server_job_id = game.JobId,
    }

    return self
end

-- Returns a fresh shallow copy of the cached server properties.
function Context:base(): { [string]: any }
    return table.clone(self._serverProps)
end

return Context
