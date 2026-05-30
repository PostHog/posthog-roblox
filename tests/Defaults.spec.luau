--!nonstrict
local h = require("./helper")
local Defaults = require("../src/Shared/Defaults")

h.test("Defaults: requires a non-empty apiKey", function()
    h.expectFalse(pcall(function()
        return Defaults.resolve({})
    end))
    h.expectFalse(pcall(function()
        return Defaults.resolve({ apiKey = "" })
    end))
    h.expectFalse(pcall(function()
        return Defaults.resolve("not a table")
    end))
end)

h.test("Defaults: applies defaults for omitted options", function()
    local r = Defaults.resolve({ apiKey = "phc_x" })
    h.expectEqual(r.host, Defaults.HOST)
    h.expectEqual(r.flushAt, 20)
    h.expectEqual(r.flushIntervalSeconds, 30)
    h.expectEqual(r.maxQueueSize, 1000)
    h.expectEqual(r.maxBatchSize, 50)
    h.expectEqual(r.personProfiles, "identified_only")
    h.expectEqual(r.serverDistinctId, "server")
    h.expectEqual(r.logLevel, "warn")
    h.expectTrue(r.preloadFeatureFlags)
    h.expectTrue(r.enableClientRelay)
    h.expectTrue(r.captureErrors)
end)

h.test("Defaults: respects explicit overrides", function()
    local r = Defaults.resolve({
        apiKey = "phc_x",
        host = "https://eu.i.posthog.com",
        flushAt = 5,
        preloadFeatureFlags = false,
        personProfiles = "always",
    })
    h.expectEqual(r.host, "https://eu.i.posthog.com")
    h.expectEqual(r.flushAt, 5)
    h.expectFalse(r.preloadFeatureFlags)
    h.expectEqual(r.personProfiles, "always")
end)

h.test("Defaults: strips trailing slashes from host", function()
    local r = Defaults.resolve({ apiKey = "phc_x", host = "https://us.i.posthog.com//" })
    h.expectEqual(r.host, "https://us.i.posthog.com")
end)

h.test("Defaults: rejects out-of-range numeric options", function()
    for _, field in { "flushAt", "flushIntervalSeconds", "maxQueueSize", "maxBatchSize" } do
        local config = { apiKey = "phc_x" }
        config[field] = 0
        h.expectFalse(
            pcall(function()
                return Defaults.resolve(config)
            end),
            `{field} = 0 should be rejected`
        )
    end
end)

return true
