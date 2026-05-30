--!nonstrict
local h = require("./helper")
local Uuid = require("../src/Shared/Uuid")

local function makeGen(ms: number, byte: number)
    return Uuid.new({
        nowMillis = function()
            return ms
        end,
        randomByte = function()
            return byte
        end,
    })
end

h.test("Uuid: format, version, and variant nibbles", function()
    local id = makeGen(0x017F2A3B4C5D, 0xAB):generate()
    h.expectEqual(#id, 36, "uuid length is 36")
    h.expect(
        id:sub(9, 9) == "-"
            and id:sub(14, 14) == "-"
            and id:sub(19, 19) == "-"
            and id:sub(24, 24) == "-",
        "dashes at 9/14/19/24"
    )
    h.expectEqual(id:sub(15, 15), "7", "version nibble is 7")
    local variant = id:sub(20, 20)
    h.expect(
        variant == "8" or variant == "9" or variant == "a" or variant == "b",
        `variant nibble must be 10xx, got {variant}`
    )
end)

h.test("Uuid: timestamp is encoded big-endian in the prefix", function()
    local id = makeGen(0x017F2A3B4C5D, 0):generate()
    local prefix = id:sub(1, 8) .. id:sub(10, 13)
    h.expectEqual(prefix, "017f2a3b4c5d", "first 48 bits match the timestamp")
end)

h.test("Uuid: monotonic counter within the same millisecond", function()
    local gen = makeGen(1000, 0)
    local a = gen:generate()
    local b = gen:generate()
    h.expectEqual(a:sub(15, 18), "7000", "first id counter is 0")
    h.expectEqual(b:sub(15, 18), "7001", "second id counter is 1")
    h.expect(a < b, "ids increase within the same millisecond")
end)

h.test("Uuid: later timestamps sort after earlier ones", function()
    local ms = 1000
    local gen = Uuid.new({
        nowMillis = function()
            return ms
        end,
        randomByte = function()
            return 0
        end,
    })
    local a = gen:generate()
    ms = 2000
    local b = gen:generate()
    h.expect(a < b, "later timestamp sorts lexicographically after")
end)

return true
