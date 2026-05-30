--!nonstrict
local h = require("./helper")
local Logger = require("../src/Shared/Logger")

h.test("Logger: new resolves the level and defaults to warn", function()
    h.expectEqual(Logger.new("debug")._level, 0)
    h.expectEqual(Logger.new("error")._level, 3)
    h.expectEqual(Logger.new()._level, 2)
    h.expectEqual(Logger.new("nonsense")._level, 2)
end)

h.test("Logger: setLevel updates the level and ignores unknown levels", function()
    local logger = Logger.new("debug")
    logger:setLevel("error")
    h.expectEqual(logger._level, 3)
    logger:setLevel("bogus")
    h.expectEqual(logger._level, 3, "unknown level is ignored")
end)

h.test("Logger: level methods are callable", function()
    -- At "none" the methods short-circuit before printing, so this stays quiet while
    -- still exercising each method.
    local logger = Logger.new("none")
    logger:debug("d")
    logger:info("i")
    logger:warn("w")
    logger:error("e")
    h.expect(true, "no error raised")
end)

return true
