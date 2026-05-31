# Error tracking

The SDK turns Luau errors into PostHog `$exception` events so you can see what is breaking in your
experience, on the server and on the client. Unhandled errors are captured automatically; you can
also report handled errors yourself.

## Automatic capture

Error capture is on by default. Turn it off with `captureErrors = false`.

**Server errors.** The SDK listens to `ScriptContext.Error` and captures unhandled server errors as
`$exception` events. Repeated errors are debounced by `errorDebounceSeconds` (default 1) so an
error firing in a tight loop does not flood the queue.

**Client errors.** Simply requiring the SDK on the client captures unhandled client errors and
relays them to the server. No extra setup is needed.

```lua
-- Server: errors here are captured automatically.
PostHog:Init({ apiKey = "phc_...", captureErrors = true })
```

```lua
-- Client: requiring the module is enough to capture client errors.
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))
-- Pass { captureErrors = false } to opt out on the client.
PostHog:Init({ captureErrors = false })
```

## Manual capture

Report a handled error (one you caught with `pcall`) with `CaptureException`. Pass a traceback as
the second argument to get a useful stack in PostHog.

On the server, the first argument is the [subject](capturing-events.md#subjects):

```lua
local ok, err = pcall(riskyOperation)
if not ok then
    PostHog:CaptureException(player, tostring(err), debug.traceback(), {
        operation = "riskyOperation",
    })
end
```

On the client there is no subject (the server attributes it to the firing player):

```lua
local ok, err = pcall(loadInventory)
if not ok then
    PostHog:CaptureException(tostring(err), debug.traceback())
end
```

## What an `$exception` event looks like

The SDK parses the Roblox traceback into stack frames and builds the standard PostHog exception
shape:

```lua
{
    ["$exception_type"] = "Error",
    ["$exception_message"] = "attempt to index nil with 'Position'",
    ["$exception_level"] = "error",
    ["$exception_handled"] = false, -- true for manual CaptureException
    ["$exception_source"] = "roblox_sdk",
    ["$exception_list"] = {
        {
            type = "Error",
            value = "attempt to index nil with 'Position'",
            mechanism = {
                type = "roblox.ScriptContext", -- roblox.client / generic for other paths
                handled = false,
                source = "roblox",
                synthetic = true,
            },
            stacktrace = {
                type = "raw",
                frames = {
                    {
                        platform = "custom",
                        lang = "luau",
                        filename = "ServerScriptService.Main",
                        abs_path = "ServerScriptService.Main",
                        lineno = 23,
                        in_app = true,
                        ["function"] = "onTouch",
                    },
                    -- ...more frames
                },
            },
        },
    },
}
```

The `mechanism.type` tells you where the error came from:

| Source                          | `mechanism.type`        | `handled` |
| ------------------------------- | ----------------------- | --------- |
| automatic server error          | `roblox.ScriptContext`  | `false`   |
| automatic client error (relayed) | `roblox.client`         | `false`   |
| manual `CaptureException`        | `generic`               | `true`    |

## See also

- [Capturing events](capturing-events.md): subjects and the client relay.
- [Configuration](configuration.md): `captureErrors` and `errorDebounceSeconds`.
- [Autocapture](autocapture.md): the other events you get for free.
