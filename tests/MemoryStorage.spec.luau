--!nonstrict
local h = require("./helper")
local MemoryStorage = require("../src/Server/Storage/MemoryStorage")

h.test("MemoryStorage: set, get, and remove", function()
    local storage = MemoryStorage.new()
    h.expectNil(storage:get("missing"))

    storage:set("k", "v")
    h.expectEqual(storage:get("k"), "v")

    storage:set("k", "v2")
    h.expectEqual(storage:get("k"), "v2", "set overwrites")

    storage:remove("k")
    h.expectNil(storage:get("k"))
end)

return true
