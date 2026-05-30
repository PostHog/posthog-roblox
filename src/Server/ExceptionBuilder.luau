--!nonstrict
-- Pure builder for PostHog `$exception` event properties.
--
-- Roblox surfaces errors as strings (a message and a traceback), so this follows
-- the PostHog Unity SDK's "log string" parsing path rather than its typed-exception
-- path. No Roblox dependency, so it is unit-testable in isolation.

local ExceptionBuilder = {}

local function trim(text: string): string
    return (text:gsub("^%s*(.-)%s*$", "%1"))
end

-- Parses a single traceback line into a stack frame, or nil if it is not a frame.
local function parseLine(line: string)
    line = trim(line)
    if line == "" or line == "Stack Begin" or line == "Stack End" then
        return nil
    end

    -- Legacy form: Script 'ServerScriptService.Main', Line 23 - function foo
    local source, lineNumber, funcPart = line:match("^Script '(.-)',%s*Line (%d+)%s*%-?%s*(.*)$")

    if not source then
        -- Common form: ServerScriptService.Main:23 function foo  (or no function)
        source, lineNumber, funcPart = line:match("^(.-):(%d+)%s*(.*)$")
    end

    if not source then
        return nil
    end

    local functionName = nil
    if funcPart and funcPart ~= "" then
        functionName = trim((funcPart:gsub("^function%s+", "")))
        if functionName == "" or functionName == "-" then
            functionName = nil
        end
    end

    local frame = {
        platform = "custom",
        lang = "luau",
        filename = source,
        abs_path = source,
        lineno = tonumber(lineNumber),
        in_app = true,
    }
    if functionName then
        frame["function"] = functionName
    end
    return frame
end

-- Parses a Roblox traceback string into an ordered list of stack frames.
function ExceptionBuilder.parseTraceback(trace: string?): { any }
    local frames = {}
    if type(trace) ~= "string" or trace == "" then
        return frames
    end

    for line in trace:gmatch("[^\r\n]+") do
        local frame = parseLine(line)
        if frame then
            table.insert(frames, frame)
        end
    end

    return frames
end

-- Builds the `$exception` event properties.
-- opts: {
--   handled: boolean?,        -- true for manual CaptureException, false for global handler
--   exceptionType: string?,   -- defaults to "Error"
--   mechanismType: string?,   -- defaults based on `handled`
-- }
function ExceptionBuilder.build(message: string?, trace: string?, opts: any?)
    opts = opts or {}

    local handled = opts.handled == true
    local exceptionType = opts.exceptionType or "Error"
    local value = message or ""
    local frames = ExceptionBuilder.parseTraceback(trace)
    local mechanismType = opts.mechanismType
        or (if handled then "generic" else "roblox.ScriptContext")

    return {
        ["$exception_type"] = exceptionType,
        ["$exception_message"] = value,
        ["$exception_level"] = "error",
        ["$exception_handled"] = handled,
        ["$exception_source"] = "roblox_sdk",
        ["$exception_list"] = {
            {
                type = exceptionType,
                value = value,
                mechanism = {
                    type = mechanismType,
                    handled = handled,
                    source = "roblox",
                    synthetic = true,
                },
                stacktrace = {
                    type = "raw",
                    frames = frames,
                },
            },
        },
    }
end

return ExceptionBuilder
