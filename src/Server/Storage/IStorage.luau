--!strict
-- Storage contract (documentation module).
--
-- A storage provider persists small named string blobs for the SDK. The default
-- implementation (MemoryStorage) keeps everything in memory, which is the right
-- fit for Roblox's ephemeral servers. The interface is the seam where a
-- DataStore-backed provider can be plugged in later via `config.storage`.
--
-- Contract:
--   storage:get(key)          -> string?   the stored value, or nil
--   storage:set(key, value)   -> ()        persist a value
--   storage:remove(key)       -> ()        delete a value
--
-- All methods are synchronous from the caller's perspective.

local Types = require(script.Parent.Parent.Parent.Shared.Types)

export type Storage = Types.Storage

return {}
