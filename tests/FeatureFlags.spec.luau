--!nonstrict
local h = require("./helper")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Load the actual Roblox-bound modules with service/module references supplied by
-- the fixture; no production source is rewritten. HTTP and lifecycle are mocked.
local function loadModule(path, scriptNode, environment)
    local env = table.clone(environment or {})
    env.script = scriptNode
    env.require = function(module)
        return module
    end
    return luau.load(fs.readFile(path), { environment = env, debugName = path })()
end

local function server(response, sendEvents)
    local delivered = {}
    local shared = {
        Defaults = require("../src/Shared/Defaults"),
        Logger = require("../src/Shared/Logger"),
        Uuid = require("../src/Shared/Uuid"),
        RetryPolicy = require("../src/Shared/RetryPolicy"),
        Version = require("../src/Shared/Version"),
        Sanitize = require("../src/Shared/Sanitize"),
        Types = {},
    }
    local modules = {
        Parent = { Shared = shared },
        FlagCache = require("../src/Server/FlagCache"),
        PlayerState = require("../src/Server/PlayerState"),
        EventQueue = require("../src/Server/EventQueue"),
        Session = require("../src/Server/Session"),
        BeforeSend = require("../src/Server/BeforeSend"),
        Storage = { MemoryStorage = require("../src/Server/Storage/MemoryStorage") },
        Context = {
            new = function()
                return {
                    base = function()
                        return {}
                    end,
                }
            end,
        },
        Transport = {
            new = function()
                return {
                    fetchFlags = function()
                        return { ok = true, body = response }
                    end,
                    sendBatch = function(_, batch)
                        for _, event in batch.batch do
                            table.insert(delivered, event)
                        end
                        return { ok = true, statusCode = 200 }
                    end,
                }
            end,
        },
        Autocapture = {
            new = function()
                return { start = function() end, stop = function() end }
            end,
        },
        ExceptionBuilder = {},
        ErrorTracking = {},
        RelayServer = {},
    }
    local environment = {
        task = {
            spawn = function(fn)
                coroutine.wrap(fn)()
            end,
            wait = function()
                coroutine.yield()
            end,
        },
    }
    modules.FeatureFlags =
        loadModule("src/Server/FeatureFlags.luau", { Parent = modules }, environment)
    modules.PlayerRegistry = loadModule("src/Server/PlayerRegistry.luau", { Parent = modules })
    environment.game = {
        GetService = function()
            return {
                IsServer = function()
                    return true
                end,
            }
        end,
        BindToClose = function() end,
    }
    environment.Random = {
        new = function()
            return {
                NextInteger = function()
                    return 42
                end,
            }
        end,
    }
    environment.DateTime = {
        now = function()
            return {
                UnixTimestampMillis = 1700000000000,
                ToIsoDate = function()
                    return "2023-11-14T22:13:20Z"
                end,
            }
        end,
    }
    local sdk = loadModule("src/Server/init.luau", modules, environment)
    sdk:Init({
        projectToken = "phc_test",
        captureErrors = false,
        captureLifecycleEvents = false,
        allowClientEvents = false,
        preloadFeatureFlags = false,
        sendFeatureFlagEvents = sendEvents,
        logLevel = "none",
    })
    return sdk, delivered
end

for _, errorBit in { false, "absent", true } do
    h.test(
        `FeatureFlags: public failed reads, defaults and events with global errors {errorBit}`,
        function()
            local response = {
                flags = {
                    checkout = {
                        enabled = false,
                        variant = "failed-variant",
                        failed = true,
                        metadata = { id = 42, version = 7, payload = "failed-payload" },
                        reason = { description = "Evaluation failed" },
                    },
                    disabled = { enabled = false, failed = false },
                },
                featureFlags = { checkout = "mirror" },
                featureFlagPayloads = { checkout = "mirror-payload" },
                requestId = "request-1",
                errorsWhileComputingFlags = if errorBit == "absent" then nil else errorBit,
            }
            local sdk, events = server(response, true)
            h.expectTrue(sdk:ReloadFeatureFlags())
            local result = sdk:GetFeatureFlag(nil, "checkout")
            h.expectEqual(result, { key = "checkout", value = false, isEnabled = false })
            h.expectNil(sdk:GetFeatureFlagPayload(nil, "checkout"))
            h.expectTrue(sdk:IsFeatureEnabled(nil, "checkout", true))
            sdk:Flush()
            h.expectEqual(#events, 1, "failed reads deduplicate")
            local props = events[1].properties
            h.expectFalse(
                props["$feature_flag_response"],
                "missing false sentinel, not true default or variant"
            )
            h.expectEqual(
                props["$feature_flag_error"],
                if errorBit == true
                    then "evaluation_failed,errors_while_computing_flags"
                    else "evaluation_failed"
            )
            h.expectEqual(props["$feature_flag_id"], 42)
            h.expectEqual(props["$feature_flag_version"], 7)
            h.expectEqual(props["$feature_flag_reason"], "Evaluation failed")
            h.expectEqual(props["$feature_flag_request_id"], "request-1")
            h.expectFalse(
                sdk:IsFeatureEnabled(nil, "disabled", true),
                "healthy false defeats true default"
            )
            sdk:Flush()
            h.expectEqual(#events, 2)
            h.expectEqual(
                events[2].properties["$feature_flag_error"],
                if errorBit == true then "errors_while_computing_flags" else nil
            )
            h.expectTrue(sdk:IsFeatureEnabled(nil, "missing", true))
            sdk:Flush()
            h.expectEqual(#events, 2, "ordinary missing keys still do not emit")
            sdk:Shutdown()

            local scalar, scalarEvents = server(response, true)
            scalar:ReloadFeatureFlags()
            h.expectTrue(scalar:IsFeatureEnabled(nil, "checkout", true))
            scalar:Flush()
            h.expectEqual(
                #scalarEvents,
                1,
                "boolean getter emits failed read without structured getter"
            )
            h.expectFalse(scalarEvents[1].properties["$feature_flag_response"])
            scalar:Shutdown()

            local suppressed, suppressedEvents = server(response, false)
            suppressed:ReloadFeatureFlags()
            suppressed:GetFeatureFlag(nil, "checkout")
            h.expectTrue(suppressed:IsFeatureEnabled(nil, "checkout", true))
            suppressed:Flush()
            h.expectEqual(#suppressedEvents, 0, "event config suppresses failed reads")
            suppressed:Shutdown()
        end
    )
end

h.test("FeatureFlags: retained successful pair has no unused remote failure diagnostic", function()
    for _, value in { true, false, "blue" } do
        local response = {
            flags = {
                checkout = {
                    enabled = value ~= false,
                    variant = if type(value) == "string" then value else nil,
                    metadata = { payload = "successful-payload" },
                },
            },
        }
        local sdk, events = server(response, true)
        sdk:ReloadFeatureFlags()
        response.errorsWhileComputingFlags = true
        response.flags.checkout =
            { enabled = false, failed = true, metadata = { payload = "failed" } }
        response.featureFlags = { checkout = "failed-mirror" }
        response.featureFlagPayloads = { checkout = "failed-payload" }
        sdk:ReloadFeatureFlags()
        h.expectEqual(sdk:GetFeatureFlag(nil, "checkout").value, value)
        h.expectEqual(sdk:GetFeatureFlagPayload(nil, "checkout"), "successful-payload")
        sdk:Flush()
        h.expectEqual(#events, 1)
        h.expectEqual(events[1].properties["$feature_flag_error"], "errors_while_computing_flags")
        sdk:Shutdown()
    end
end)

return true
