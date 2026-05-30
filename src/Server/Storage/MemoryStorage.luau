--!strict
-- Default in-memory storage provider. Data lives for the lifetime of the server.

local MemoryStorage = {}
MemoryStorage.__index = MemoryStorage

export type MemoryStorage = typeof(setmetatable(
    {} :: { _data: { [string]: string } },
    MemoryStorage
))

function MemoryStorage.new(): MemoryStorage
    return setmetatable({ _data = {} }, MemoryStorage)
end

function MemoryStorage:get(key: string): string?
    return self._data[key]
end

function MemoryStorage:set(key: string, value: string)
    self._data[key] = value
end

function MemoryStorage:remove(key: string)
    self._data[key] = nil
end

return MemoryStorage
