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

local v4Seed = {
    flags = {
        kept = { enabled = true },
        other = {
            enabled = true,
            metadata = { id = 7, version = 1, payload = { n = 1 } },
            reason = { description = "condition_match" },
        },
    },
}
local v3Seed = {
    featureFlags = { kept = true, other = true },
    featureFlagPayloads = { other = { n = 1 } },
}
local otherFromV4Seed = {
    value = true,
    payload = { n = 1 },
    details = { id = 7, version = 1, reason = "condition_match" },
}

for _, case in
    {
        {
            name = "error-free v4 response clears a missing flag",
            seed = v4Seed,
            response = { flags = { kept = { enabled = true } }, errorsWhileComputingFlags = false },
            expected = { kept = { value = true }, other = {} },
        },
        {
            name = "error-free v3 response clears a missing flag",
            seed = v3Seed,
            response = { featureFlags = { kept = true } },
            expected = { kept = { value = true }, other = {} },
        },
        {
            name = "error-free response with no flags clears every flag",
            seed = v4Seed,
            response = { flags = {}, errorsWhileComputingFlags = false },
            expected = { kept = {}, other = {} },
        },
        {
            name = "response with errors keeps a missing v4 flag",
            seed = v4Seed,
            response = { flags = { kept = { enabled = true } }, errorsWhileComputingFlags = true },
            expected = { kept = { value = true }, other = otherFromV4Seed },
        },
        {
            name = "response with errors keeps a missing v3 flag",
            seed = v3Seed,
            response = { featureFlags = { kept = false }, errorsWhileComputingFlags = true },
            expected = { kept = { value = false }, other = { value = true, payload = { n = 1 } } },
        },
        {
            name = "response with errors keeps a failed flag",
            seed = v4Seed,
            response = {
                flags = {
                    kept = { enabled = true },
                    other = {
                        enabled = false,
                        failed = true,
                        metadata = { id = 8, version = 2, payload = { n = 2 } },
                    },
                },
                errorsWhileComputingFlags = true,
            },
            expected = { kept = { value = true }, other = otherFromV4Seed },
        },
        {
            name = "response with errors updates a computed flag",
            seed = v4Seed,
            response = {
                flags = { kept = { enabled = false, failed = false } },
                errorsWhileComputingFlags = true,
            },
            expected = { kept = { value = false }, other = otherFromV4Seed },
        },
        {
            name = "response without a flags table keeps every flag",
            seed = v4Seed,
            response = { requestId = "req-4" },
            expected = { kept = { value = true }, other = otherFromV4Seed },
        },
    }
do
    h.test(`FlagCache: {case.name}`, function()
        local store = FlagCache.empty()
        FlagCache.applyResponse(store, case.seed)
        FlagCache.applyResponse(store, case.response)
        for key, flag in case.expected do
            h.expectEqual(FlagCache.getValue(store, key), flag.value, `{key} value`)
            h.expectEqual(FlagCache.getPayload(store, key), flag.payload, `{key} payload`)
            h.expectEqual(FlagCache.getDetails(store, key), flag.details, `{key} details`)
        end
    end)
end

return true
