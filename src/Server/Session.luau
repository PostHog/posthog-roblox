--!strict
-- Per-player session helpers.
--
-- A session models a single play session: it starts when a player joins and is
-- carried across teleports within the same game so a multi-place experience reads
-- as one session. The session id is a UUID v7; the start time is Unix seconds.
--
-- Teleport continuation works by stashing the session under a reserved key in the
-- destination's TeleportData. The SDK reads it on join; games opt in by merging
-- `PostHog:GetSessionTeleportData(player)` into their TeleportData before teleporting.

local TELEPORT_KEY = "__posthog"

local Session = {}

export type Session = {
    id: string,
    startTime: number,
}

-- Creates a fresh session using the injected uuid generator and clock (seconds).
function Session.create(uuid: { generate: (any) -> string }, nowSeconds: number): Session
    return {
        id = uuid:generate(),
        startTime = nowSeconds,
    }
end

-- Restores a session from a player's TeleportData table, or nil if absent/invalid.
function Session.fromTeleportData(teleportData: any): Session?
    if type(teleportData) ~= "table" then
        return nil
    end

    local stashed = teleportData[TELEPORT_KEY]
    if type(stashed) ~= "table" then
        return nil
    end

    if type(stashed.id) ~= "string" or type(stashed.startTime) ~= "number" then
        return nil
    end

    return {
        id = stashed.id,
        startTime = stashed.startTime,
    }
end

-- Builds the TeleportData fragment a game should merge in before teleporting so the
-- session continues at the destination.
function Session.toTeleportData(session: Session): { [string]: any }
    return {
        [TELEPORT_KEY] = {
            id = session.id,
            startTime = session.startTime,
        },
    }
end

return Session
