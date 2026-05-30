--!nonstrict
local h = require("./helper")
local Sanitize = require("../src/Shared/Sanitize")

h.test("Sanitize: passes scalars through unchanged", function()
    local out = Sanitize.clean({ s = "x", n = 5, b = true, f = 1.5 })
    h.expectEqual(out, { s = "x", n = 5, b = true, f = 1.5 })
end)

h.test("Sanitize: NaN and infinities become strings", function()
    local zero = 0
    local out = Sanitize.clean({ nan = zero / zero, inf = math.huge, ninf = -math.huge })
    h.expect(type(out.nan) == "string", "nan stringified")
    h.expect(type(out.inf) == "string", "inf stringified")
    h.expect(type(out.ninf) == "string", "-inf stringified")
end)

h.test("Sanitize: drops functions", function()
    local out = Sanitize.clean({ keep = 1, fn = function() end })
    h.expectEqual(out.keep, 1)
    h.expectNil(out.fn, "function dropped")
end)

h.test("Sanitize: recurses into nested tables and arrays", function()
    local out = Sanitize.clean({ nested = { a = 1, list = { 1, 2, 3 } } })
    h.expectEqual(out.nested.a, 1)
    h.expectEqual(out.nested.list, { 1, 2, 3 })
end)

h.test("Sanitize: breaks cyclic references", function()
    local t = { a = 1 }
    t.self = t
    local out = Sanitize.clean(t)
    h.expectEqual(out.a, 1)
    h.expectNil(out.self, "cycle dropped")
end)

return true
