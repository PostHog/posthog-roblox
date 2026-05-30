--!nonstrict
local h = require("./helper")
local PlayerState = require("../src/Server/PlayerState")

h.test("PlayerState: new initializes a player subject", function()
    local state = PlayerState.new("123", { userId = 123 })
    h.expectEqual(state.distinctId, "123")
    h.expectEqual(state.userId, 123)
    h.expectFalse(state.isServer)
    h.expectFalse(state.optedOut)
    h.expectFalse(state.isIdentified)
end)

h.test("PlayerState: new marks the server pseudo-subject", function()
    local state = PlayerState.new("server", { isServer = true })
    h.expectTrue(state.isServer)
end)

h.test("PlayerState: setGroup and groupsOrNil", function()
    local state = PlayerState.new("123")
    h.expectNil(state:groupsOrNil(), "no groups returns nil")

    state:setGroup("company", "acme")
    state:setGroup("team", "blue")

    local groups = state:groupsOrNil()
    h.expectEqual(groups.company, "acme")
    h.expectEqual(groups.team, "blue")
end)

return true
