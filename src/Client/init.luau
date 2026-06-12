--!nonstrict
-- PostHog Roblox SDK - client entry point.
--
-- The client is a thin relay. It cannot make HTTP requests, so it forwards capture
-- calls and client-side errors to the server over a RemoteEvent. The server owns
-- all batching, identity, and HTTP. Simply requiring this module starts automatic
-- client error capture and connects to the relay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local Defaults = require(script.Parent.Shared.Defaults)
local Types = require(script.Parent.Shared.Types)
local Platform = require(script.Platform)

local MAX_BUFFER = 100
local WAIT_TIMEOUT_SECONDS = 15

local PostHogClient = {}

local remote = nil
local disabled = false
local buffer = {}
local context = { platform = Platform.detect(), os = "Roblox" }
local errorConnection = nil

-- Sends a message to the server, buffering until the relay RemoteEvent appears.
local function deliver(message)
    message.context = context

    if remote then
        remote:FireServer(message)
        return
    end

    if disabled then
        return
    end

    if #buffer >= MAX_BUFFER then
        table.remove(buffer, 1)
    end
    table.insert(buffer, message)
end

local function flushBuffer()
    if not remote then
        return
    end
    for _, message in buffer do
        remote:FireServer(message)
    end
    table.clear(buffer)
end

-- Locate the relay RemoteEvent created by the server. If it never appears, the
-- server SDK is not running (or relay is disabled): drop buffered messages.
task.spawn(function()
    local found = ReplicatedStorage:WaitForChild(Defaults.REMOTE_NAME, WAIT_TIMEOUT_SECONDS)
    if found then
        remote = found
        flushBuffer()
    else
        disabled = true
        table.clear(buffer)
        warn(
            "[PostHog] relay RemoteEvent not found. Initialize the server SDK and keep "
                .. "allowClientEvents = true (the default). Client events are being dropped."
        )
    end
end)

local function connectErrors()
    if errorConnection then
        return
    end
    errorConnection = ScriptContext.Error:Connect(function(message, trace, _script)
        deliver({ kind = "exception", message = message, trace = trace, handled = false })
    end)
end

connectErrors()

-- Optional configuration. Errors are captured automatically; pass
-- `{ captureErrors = false }` to turn that off.
function PostHogClient:Init(options)
    options = options or {}
    if options.captureErrors == false and errorConnection then
        errorConnection:Disconnect()
        errorConnection = nil
    end
    return self
end

function PostHogClient:Capture(eventName: string, properties: { [string]: any }?)
    if type(eventName) ~= "string" or eventName == "" then
        return
    end
    deliver({ kind = "capture", name = eventName, properties = properties })
end

function PostHogClient:Screen(screenName: string, properties: { [string]: any }?)
    deliver({ kind = "screen", name = screenName, properties = properties })
end

function PostHogClient:CaptureException(
    exception: string | Types.ExceptionInput,
    trace: string?,
    properties: { [string]: any }?
)
    local message = exception
    local errorType = nil
    if type(exception) == "table" then
        message = if type(exception.message) == "string" then exception.message else ""
        errorType = if type(exception.type) == "string" then exception.type else nil
        if trace == nil and type(exception.trace) == "string" then
            trace = exception.trace
        end
    end
    deliver({
        kind = "exception",
        message = message,
        trace = trace,
        errorType = errorType,
        handled = true,
        properties = properties,
    })
end

-- Flushing happens server side; provided for API symmetry.
function PostHogClient:Flush() end

function PostHogClient:IsInitialized(): boolean
    return true
end

return PostHogClient
