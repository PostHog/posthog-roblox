--!nonstrict
-- Leveled logger. Messages are emitted only when their level is at or above the
-- configured threshold. All output is prefixed with "[PostHog]".

local Logger = {}
Logger.__index = Logger

local LEVELS = {
    debug = 0,
    info = 1,
    warn = 2,
    error = 3,
    none = 4,
}

local PREFIX = "[PostHog]"

export type Logger = typeof(setmetatable({} :: { _level: number }, Logger))

function Logger.new(level: string?): Logger
    return setmetatable({
        _level = LEVELS[level or "warn"] or LEVELS.warn,
    }, Logger)
end

function Logger:setLevel(level: string)
    local resolved = LEVELS[level]
    if resolved ~= nil then
        self._level = resolved
    end
end

function Logger:debug(message: string)
    if self._level <= LEVELS.debug then
        print(`{PREFIX} {message}`)
    end
end

function Logger:info(message: string)
    if self._level <= LEVELS.info then
        print(`{PREFIX} {message}`)
    end
end

function Logger:warn(message: string)
    if self._level <= LEVELS.warn then
        warn(`{PREFIX} {message}`)
    end
end

function Logger:error(message: string)
    if self._level <= LEVELS.error then
        warn(`{PREFIX} {message}`)
    end
end

return Logger
