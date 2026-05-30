--!nonstrict
local h = require("./helper")
local FlagCache = require("../src/Server/FlagCache")

h.test("FlagCache: v3 boolean, variant, and payload", function()
    local store = FlagCache.empty()
    FlagCache.applyResponse(store, {
        featureFlags = {
            ["bool-flag"] = true,
            ["variant-flag"] = "test",
            ["off-flag"] = false,
        },
        featureFlagPayloads = {
            ["bool-flag"] = { color = "red" },
        },
        requestId = "req-1",
    })

    h.expectEqual(FlagCache.getValue(store, "bool-flag"), true)
    h.expectEqual(FlagCache.getValue(store, "variant-flag"), "test")
    h.expectEqual(FlagCache.getValue(store, "off-flag"), false)
    h.expectEqual(FlagCache.getPayload(store, "bool-flag"), { color = "red" })
    h.expectEqual(store.requestId, "req-1")
    h.expectNil(FlagCache.getValue(store, "missing"))

    h.expectTrue(FlagCache.isEnabled(FlagCache.getValue(store, "bool-flag")))
    h.expectTrue(FlagCache.isEnabled(FlagCache.getValue(store, "variant-flag")))
    h.expectFalse(FlagCache.isEnabled(FlagCache.getValue(store, "off-flag")))
    h.expectFalse(FlagCache.isEnabled(nil))
end)

h.test("FlagCache: v4 overrides v3 and records details", function()
    local store = FlagCache.empty()
    FlagCache.applyResponse(store, {
        featureFlags = { ["f"] = false },
        flags = {
            ["f"] = {
                enabled = true,
                variant = "alpha",
                metadata = { id = 42, version = 3, payload = { n = 1 } },
                reason = { description = "matched condition" },
            },
        },
        requestId = "req-2",
        evaluatedAt = 1716000000,
    })

    h.expectEqual(FlagCache.getValue(store, "f"), "alpha", "variant wins over v3 boolean")
    h.expectEqual(FlagCache.getPayload(store, "f"), { n = 1 })

    local details = FlagCache.getDetails(store, "f")
    h.expectEqual(details.id, 42)
    h.expectEqual(details.version, 3)
    h.expectEqual(details.reason, "matched condition")
    h.expectEqual(store.evaluatedAt, 1716000000)
end)

h.test("FlagCache: v4 enabled boolean without a variant", function()
    local store = FlagCache.empty()
    FlagCache.applyResponse(store, { flags = { b = { enabled = true } } })
    h.expectEqual(FlagCache.getValue(store, "b"), true)
end)

h.test("FlagCache: non-empty quotaLimited clears all flags", function()
    local store = FlagCache.empty()
    FlagCache.applyResponse(store, { featureFlags = { a = true } })
    h.expectEqual(FlagCache.getValue(store, "a"), true)

    FlagCache.applyResponse(store, { quotaLimited = { "a" }, requestId = "req-3" })
    h.expectNil(FlagCache.getValue(store, "a"), "flags cleared on quota limit")
    h.expectEqual(store.requestId, "req-3", "request metadata still updated")
end)

return true
