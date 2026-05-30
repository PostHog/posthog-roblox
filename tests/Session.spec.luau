--!nonstrict
local h = require("./helper")
local Session = require("../src/Server/Session")

local function fakeUuid(id)
    return {
        generate = function()
            return id
        end,
    }
end

h.test("Session: create uses the uuid generator and start time", function()
    local session = Session.create(fakeUuid("abc"), 1000)
    h.expectEqual(session.id, "abc")
    h.expectEqual(session.startTime, 1000)
end)

h.test("Session: round-trips through teleport data", function()
    local data = Session.toTeleportData({ id = "sid", startTime = 42 })
    local restored = Session.fromTeleportData(data)
    h.expectEqual(restored.id, "sid")
    h.expectEqual(restored.startTime, 42)
end)

h.test("Session: fromTeleportData rejects missing or malformed data", function()
    h.expectNil(Session.fromTeleportData(nil))
    h.expectNil(Session.fromTeleportData("nope"))
    h.expectNil(Session.fromTeleportData({}))
    h.expectNil(Session.fromTeleportData({ __posthog = { id = 5, startTime = "x" } }))
end)

return true
