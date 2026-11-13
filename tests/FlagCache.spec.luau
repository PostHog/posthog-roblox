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

for _, errorBit in { false, "absent", true } do
    h.test(
        `FlagCache: failed records and flat mirrors omitted with global errors {errorBit}`,
        function()
            local store = FlagCache.empty()
            local response = {
                flags = {
                    checkout = {
                        enabled = false,
                        failed = true,
                        metadata = { id = 42, payload = { copy = "failed" } },
                    },
                    variant = {
                        enabled = true,
                        variant = "failed-variant",
                        failed = true,
                        metadata = { payload = "failed-payload" },
                    },
                    disabled = { enabled = false, failed = false },
                    healthy = { enabled = false },
                },
                featureFlags = { checkout = false, variant = "mirror" },
                featureFlagPayloads = { checkout = "mirror", variant = "mirror" },
                errorsWhileComputingFlags = if errorBit == "absent" then nil else errorBit,
            }
            FlagCache.applyResponse(store, response)
            h.expectNil(FlagCache.getValue(store, "checkout"))
            h.expectNil(FlagCache.getPayload(store, "checkout"))
            h.expectNil(FlagCache.getValue(store, "variant"))
            h.expectNil(FlagCache.getPayload(store, "variant"))
            h.expectFalse(FlagCache.getValue(store, "disabled"))
            h.expectFalse(FlagCache.getValue(store, "healthy"))
        end
    )

    h.test(`FlagCache: failed refresh replaces unless response-wide errors {errorBit}`, function()
        local store = FlagCache.empty()
        FlagCache.applyResponse(store, {
            featureFlags = { enabled = true, disabled = false, variant = "blue", deleted = true },
            featureFlagPayloads = { enabled = "local", disabled = "local", variant = "local" },
        })
        FlagCache.applyResponse(store, {
            flags = {
                enabled = { enabled = false, failed = true },
                disabled = { enabled = false, failed = true },
                variant = { enabled = true, variant = "failed", failed = true },
                healthy = { enabled = false },
            },
            featureFlags = { enabled = false, disabled = "failed", variant = "failed" },
            featureFlagPayloads = { enabled = "failed", disabled = "failed", variant = "failed" },
            errorsWhileComputingFlags = if errorBit == "absent" then nil else errorBit,
        })
        for key, value in { enabled = true, disabled = false, variant = "blue", deleted = true } do
            h.expectEqual(FlagCache.getValue(store, key), if errorBit == true then value else nil)
            if key ~= "deleted" then
                h.expectEqual(
                    FlagCache.getPayload(store, key),
                    if errorBit == true then "local" else nil
                )
            end
        end
        h.expectFalse(FlagCache.getValue(store, "healthy"))
    end)
end

h.test("FlagCache: recovery and quota clear per-flag failure diagnostics", function()
    local store = FlagCache.empty()
    local failure =
        { flags = { checkout = { enabled = false, failed = true, metadata = { id = 1 } } } }
    FlagCache.applyResponse(store, failure)
    h.expectTrue(store.failed.checkout)
    FlagCache.applyResponse(
        store,
        { featureFlags = { checkout = false }, errorsWhileComputingFlags = true }
    )
    h.expectFalse(FlagCache.getValue(store, "checkout"))
    h.expectNil(store.failed.checkout)
    h.expectNil(FlagCache.getDetails(store, "checkout"))
    FlagCache.applyResponse(store, failure)
    FlagCache.applyResponse(
        store,
        { flags = { checkout = { enabled = false } }, errorsWhileComputingFlags = true }
    )
    h.expectFalse(FlagCache.getValue(store, "checkout"))
    h.expectNil(store.failed.checkout)
    h.expectNil(FlagCache.getDetails(store, "checkout"))
    FlagCache.applyResponse(store, failure)
    FlagCache.applyResponse(store, { quotaLimited = { "feature_flags" } })
    h.expectNil(store.failed.checkout)
end)

return true
