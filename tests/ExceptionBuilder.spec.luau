--!nonstrict
local h = require("./helper")
local ExceptionBuilder = require("../src/Server/ExceptionBuilder")

h.test("ExceptionBuilder: parses the common Source:line function form", function()
    local trace = "ServerScriptService.Main.Combat:42 function attack\n"
        .. "ServerScriptService.Main:8"
    local frames = ExceptionBuilder.parseTraceback(trace)

    h.expectEqual(#frames, 2)
    h.expectEqual(frames[1].filename, "ServerScriptService.Main.Combat")
    h.expectEqual(frames[1].lineno, 42)
    h.expectEqual(frames[1]["function"], "attack")
    h.expectEqual(frames[1].platform, "custom")
    h.expectEqual(frames[1].lang, "luau")
    h.expectEqual(frames[2].filename, "ServerScriptService.Main")
    h.expectEqual(frames[2].lineno, 8)
    h.expectNil(frames[2]["function"])
end)

h.test("ExceptionBuilder: parses the legacy Script '...' form and skips markers", function()
    local trace = "Stack Begin\n"
        .. "Script 'ReplicatedStorage.Lib', Line 10 - function doThing\n"
        .. "Stack End"
    local frames = ExceptionBuilder.parseTraceback(trace)

    h.expectEqual(#frames, 1)
    h.expectEqual(frames[1].filename, "ReplicatedStorage.Lib")
    h.expectEqual(frames[1].lineno, 10)
    h.expectEqual(frames[1]["function"], "doThing")
end)

h.test("ExceptionBuilder: builds an unhandled exception payload", function()
    local props =
        ExceptionBuilder.build("attempt to index nil", "Workspace.A:3", { handled = false })

    h.expectEqual(props["$exception_level"], "error")
    h.expectFalse(props["$exception_handled"])
    h.expectEqual(props["$exception_message"], "attempt to index nil")
    h.expectEqual(props["$exception_source"], "roblox_sdk")

    local list = props["$exception_list"]
    h.expectEqual(#list, 1)
    h.expectEqual(list[1].value, "attempt to index nil")
    h.expectEqual(list[1].mechanism.type, "roblox.ScriptContext")
    h.expectFalse(list[1].mechanism.handled)
    h.expectTrue(list[1].mechanism.synthetic)
    h.expectEqual(list[1].stacktrace.type, "raw")
    h.expectEqual(#list[1].stacktrace.frames, 1)
end)

h.test("ExceptionBuilder: handled exceptions use the generic mechanism", function()
    local props = ExceptionBuilder.build("boom", nil, { handled = true })
    h.expectTrue(props["$exception_handled"])
    h.expectEqual(props["$exception_list"][1].mechanism.type, "generic")
    h.expectEqual(#props["$exception_list"][1].stacktrace.frames, 0)
end)

h.test("ExceptionBuilder: build honors a custom exception type", function()
    local props = ExceptionBuilder.build("boom", nil, {
        handled = true,
        exceptionType = "NetworkError",
    })
    h.expectEqual(props["$exception_type"], "NetworkError")
    h.expectEqual(props["$exception_list"][1].type, "NetworkError")
end)

h.test("ExceptionBuilder: normalize accepts strings, tables, and other values", function()
    local message, trace, exceptionType = ExceptionBuilder.normalize("boom", "A:1")
    h.expectEqual(message, "boom")
    h.expectEqual(trace, "A:1")
    h.expectNil(exceptionType)

    message, trace, exceptionType = ExceptionBuilder.normalize({
        type = "NetworkError",
        message = "request failed",
        trace = "B:2",
    })
    h.expectEqual(message, "request failed")
    h.expectEqual(trace, "B:2")
    h.expectEqual(exceptionType, "NetworkError")

    -- An explicit trace argument wins over the table's trace.
    local _, explicitTrace = ExceptionBuilder.normalize({ message = "x", trace = "B:2" }, "C:3")
    h.expectEqual(explicitTrace, "C:3")

    -- Malformed tables degrade to safe defaults.
    message, trace, exceptionType = ExceptionBuilder.normalize({ message = 42, type = 1 })
    h.expectEqual(message, "")
    h.expectNil(trace)
    h.expectNil(exceptionType)

    h.expectEqual((ExceptionBuilder.normalize(nil)), "")
    h.expectEqual((ExceptionBuilder.normalize(123)), "123")
end)

return true
