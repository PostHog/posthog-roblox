--!nonstrict
local h = require("./helper")
local Defaults = require("../src/Shared/Defaults")

for _, case in
    {
        { name = "a nil config", config = nil },
        { name = "a non-table config", config = "not a table" },
        { name = "a missing token", config = {} },
        { name = "an empty token", config = { projectToken = "" } },
        { name = "a whitespace token", config = { projectToken = "  \t" } },
        { name = "a non-string token", config = { projectToken = 123 } },
        { name = "a blank apiKey alias", config = { apiKey = " " } },
    }
do
    h.test(`Defaults: projectToken is nil for {case.name}`, function()
        h.expectNil(Defaults.projectToken(case.config))
    end)

    h.test(`Defaults: resolve rejects {case.name}`, function()
        h.expectFalse(pcall(function()
            return Defaults.resolve(case.config)
        end))
    end)
end

for _, case in
    {
        { name = "projectToken", config = { projectToken = "phc_new" }, expected = "phc_new" },
        { name = "apiKey alias", config = { apiKey = "phc_legacy" }, expected = "phc_legacy" },
        {
            name = "projectToken over apiKey",
            config = { projectToken = "phc_new", apiKey = "phc_legacy" },
            expected = "phc_new",
        },
    }
do
    h.test(`Defaults: projectToken reads {case.name}`, function()
        h.expectEqual(Defaults.projectToken(case.config), case.expected)
    end)
end

h.test("Defaults: accepts apiKey as a deprecated alias for projectToken", function()
    local r = Defaults.resolve({ apiKey = "phc_legacy" })
    h.expectEqual(r.projectToken, "phc_legacy")

    -- projectToken wins when both are provided.
    local both = Defaults.resolve({ projectToken = "phc_new", apiKey = "phc_legacy" })
    h.expectEqual(both.projectToken, "phc_new")
end)

h.test("Defaults: accepts enableClientRelay as a deprecated alias", function()
    local r = Defaults.resolve({ projectToken = "phc_x", enableClientRelay = false })
    h.expectFalse(r.allowClientEvents)

    -- allowClientEvents wins when both are provided.
    local both = Defaults.resolve({
        projectToken = "phc_x",
        allowClientEvents = true,
        enableClientRelay = false,
    })
    h.expectTrue(both.allowClientEvents)
end)

h.test("Defaults: applies defaults for omitted options", function()
    local r = Defaults.resolve({ projectToken = "phc_x" })
    h.expectEqual(r.projectToken, "phc_x")
    h.expectEqual(r.host, Defaults.HOST)
    h.expectEqual(r.flushAt, 20)
    h.expectEqual(r.flushIntervalSeconds, 30)
    h.expectEqual(r.maxQueueSize, 1000)
    h.expectEqual(r.maxBatchSize, 50)
    h.expectEqual(r.personProfiles, "identified_only")
    h.expectEqual(r.serverDistinctId, "server")
    h.expectEqual(r.logLevel, "warn")
    h.expectTrue(r.preloadFeatureFlags)
    h.expectTrue(r.allowClientEvents)
    h.expectTrue(r.captureErrors)
    h.expectEqual(r.featureFlagRequestMaxRetries, 1)
end)

h.test("Defaults: allows disabling feature flag request retries", function()
    local r = Defaults.resolve({ projectToken = "phc_x", featureFlagRequestMaxRetries = 0 })
    h.expectEqual(r.featureFlagRequestMaxRetries, 0)
end)

h.test("Defaults: rejects negative feature flag request retries", function()
    h.expectFalse(pcall(function()
        return Defaults.resolve({ projectToken = "phc_x", featureFlagRequestMaxRetries = -1 })
    end))
end)

h.test("Defaults: respects explicit overrides", function()
    local r = Defaults.resolve({
        projectToken = "phc_x",
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
    local r = Defaults.resolve({ projectToken = "phc_x", host = "https://us.i.posthog.com//" })
    h.expectEqual(r.host, "https://us.i.posthog.com")
end)

h.test("Defaults: rejects out-of-range numeric options", function()
    for _, field in { "flushAt", "flushIntervalSeconds", "maxQueueSize", "maxBatchSize" } do
        local config = { projectToken = "phc_x" }
        config[field] = 0
        h.expectFalse(
            pcall(function()
                return Defaults.resolve(config)
            end),
            `{field} = 0 should be rejected`
        )
    end
end)

h.test("Defaults: keeps a beforeSend function", function()
    local hook = function(event)
        return event
    end
    h.expect(Defaults.resolve({ projectToken = "phc_x", beforeSend = hook }).beforeSend == hook)
end)

h.test("Defaults: rejects a non-function beforeSend", function()
    h.expectFalse(pcall(function()
        return Defaults.resolve({ projectToken = "phc_x", beforeSend = "nope" })
    end))
end)

return true
