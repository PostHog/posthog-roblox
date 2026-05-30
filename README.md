# 🦔 PostHog Roblox SDK (BETA)

The PostHog analytics SDK for Roblox. Capture events, identify players, evaluate feature flags,
and track errors from your Roblox experiences.

- **Server-authoritative.** All HTTP and batching happen on the server (the only place Roblox
  allows outbound requests). A thin client module relays calls to the server.
- **Per-player.** Each player is a PostHog user, keyed by their `UserId`.
- **Batteries included.** Events, identity, groups, feature flags, error tracking, and lifecycle
  autocapture.

> Session replay is intentionally not included: it is screenshot based and not feasible on Roblox.

## Requirements

- HTTP requests enabled for your experience (Game Settings → Security → **Allow HTTP Requests**).
- A PostHog project API key (starts with `phc_`).

## Installation

### Wally (recommended)

Add the dependency to your `wally.toml`:

```toml
[dependencies]
PostHog = "posthog/posthog-roblox@0.1.0"
```

Then run `wally install`. Map the resulting `Packages` folder into `ReplicatedStorage` in your
Rojo project so both the server and client can `require` it.

### Manual

Copy `src` into your project as a `ModuleScript` named `PostHog` under `ReplicatedStorage` (for
example with Rojo, or by dragging the built `.rbxm`).

## Quick start

### Server

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Init({
    apiKey = "phc_YOUR_PROJECT_API_KEY",
    host = "https://us.i.posthog.com", -- or https://eu.i.posthog.com
})

Players.PlayerAdded:Connect(function(player)
    -- Attribute an event to a specific player by passing the Player instance.
    PostHog:Capture(player, "level_completed", { level = 5, score = 1250 })
end)

-- A server-scoped event (no player) uses nil as the subject.
PostHog:Capture(nil, "server_started", { max_players = Players.MaxPlayers })
```

### Client

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

-- No player argument: the server attributes this to the firing player.
PostHog:Capture("button_clicked", { button = "play" })
PostHog:Screen("MainMenu")
```

On the client, capture calls are relayed to the server over a `RemoteEvent`. Requiring the module
on the client also enables automatic capture of unhandled client errors.

## Architecture

```
Client (LocalScript)                 Server (Script)
  PostHog:Capture(name, props)          PostHog:Init(config)
  PostHog:Screen(name)          --->    Players.PlayerAdded / Removing
  unhandled errors              RemoteEvent   feature flags  (/flags?v=2)
        |                        relay         HttpService    (/batch)
        '------ FireServer ----------------->  game:BindToClose (final flush)
```

The server owns the event queue, identity, feature flags, error tracking, and all HTTP. The
client never holds the API key and is treated as untrusted: relayed messages are validated,
rate-limited, and always attributed to the firing player.

## Subjects (server API)

Every server method takes a **subject** as its first argument that identifies who the call is
about:

| Subject            | Resolves to                                  |
| ------------------ | -------------------------------------------- |
| a `Player`         | `tostring(player.UserId)`                    |
| a `number`         | `tostring(number)` (a UserId or any id)      |
| a `string`         | used directly as the `distinct_id`           |
| `nil`              | the server itself (`config.serverDistinctId`)|

Server-scoped events (`nil`) are sent with `$process_person_profile = false` so they do not create
a person.

## Configuration

```lua
PostHog:Init({
    apiKey = "phc_...",                         -- required

    host = "https://us.i.posthog.com",          -- PostHog instance URL
    flushAt = 20,                               -- flush after this many queued events
    flushIntervalSeconds = 30,                  -- flush at least this often
    maxQueueSize = 1000,                        -- drop oldest beyond this
    maxBatchSize = 50,                          -- max events per HTTP request

    preloadFeatureFlags = true,                 -- fetch flags when a player joins
    sendFeatureFlagEvents = true,               -- emit $feature_flag_called
    sendDefaultPersonPropertiesForFlags = true, -- include $lib/$os in flag requests

    captureLifecycleEvents = true,              -- player_joined / player_left
    captureErrors = true,                       -- ScriptContext.Error -> $exception
    errorDebounceSeconds = 1,                   -- min gap between auto-captured errors

    personProfiles = "identified_only",         -- "always" | "identified_only" | "never"
    serverDistinctId = "server",                -- distinct id for server-scoped events

    enableClientRelay = true,                   -- create the client RemoteEvent
    clientRateLimitPerSecond = 20,              -- per-player relay rate limit
    maxClientPropertyCount = 100,               -- per-message client property cap

    logLevel = "warn",                          -- "debug" | "info" | "warn" | "error" | "none"
    storage = nil,                              -- advanced: custom Storage provider
})
```

## API

### Server

| Method | Description |
| --- | --- |
| `PostHog:Init(config)` | Initialize the SDK (call once from a server `Script`). |
| `PostHog:Capture(subject, eventName, properties?)` | Capture an event. |
| `PostHog:Screen(subject, screenName, properties?)` | Capture a `$screen` event. |
| `PostHog:Identify(subject, setProps?, setOnceProps?)` | Set person properties. |
| `PostHog:Alias(subject, alias)` | Link the subject's id to another id. |
| `PostHog:Group(subject, groupType, groupKey, groupProps?)` | Associate the subject with a group. |
| `PostHog:Register(key, value)` / `:Unregister(key)` | Server-global super properties. |
| `PostHog:IsFeatureEnabled(subject, key, default?)` | Returns a boolean. |
| `PostHog:GetFeatureFlag(subject, key)` | Returns `{ key, value, isEnabled, variant, payload }`. |
| `PostHog:GetFeatureFlagPayload(subject, key)` | Returns the decoded flag payload. |
| `PostHog:ReloadFeatureFlags(subject)` | Re-fetch flags (yields). |
| `PostHog:SetPersonPropertiesForFlags(subject, props, reload?)` | Flag evaluation properties. |
| `PostHog:SetGroupPropertiesForFlags(subject, groupType, props, reload?)` | Flag group properties. |
| `PostHog:CaptureException(subject, message, trace?, properties?)` | Manually report an error. |
| `PostHog:GetSessionTeleportData(player)` | TeleportData fragment to continue a session. |
| `PostHog:OptOut(subject)` / `:OptIn(subject)` | Stop / resume capturing for a subject. |
| `PostHog:Flush()` | Send queued events now. |
| `PostHog:Shutdown()` | Stop and flush. |

### Client

| Method | Description |
| --- | --- |
| `PostHog:Init(options?)` | Optional; pass `{ captureErrors = false }` to disable error capture. |
| `PostHog:Capture(eventName, properties?)` | Relay an event to the server. |
| `PostHog:Screen(screenName, properties?)` | Relay a screen view. |
| `PostHog:CaptureException(message, trace?, properties?)` | Relay a handled error. |

Clients cannot send reserved (`$`-prefixed) event names; those are emitted by the SDK.

## Feature flags

Flags are evaluated per player against the PostHog `/flags` endpoint and cached on the server.

```lua
if PostHog:IsFeatureEnabled(player, "new-shop", false) then
    -- ...
end

local flag = PostHog:GetFeatureFlag(player, "welcome-message")
if flag.variant == "friendly" then
    -- flag.payload holds the decoded JSON payload, if any
end
```

With `preloadFeatureFlags = true` (default), flags are fetched when a player joins. Otherwise call
`PostHog:ReloadFeatureFlags(player)` before reading them.

## Sessions and teleports

A session starts when a player joins and ends when they leave. To continue a session across a
teleport within your universe, merge the SDK's data into your `TeleportData`:

```lua
local TeleportService = game:GetService("TeleportService")

local options = Instance.new("TeleportOptions")
options:SetTeleportData(PostHog:GetSessionTeleportData(player))
TeleportService:TeleportAsync(placeId, { player }, options)
```

## Error tracking

Unhandled errors are captured automatically as PostHog `$exception` events: on the server via
`ScriptContext.Error`, and on the client by simply requiring the SDK (the error is relayed to the
server). Report a handled error yourself with `CaptureException`.

## Development

This repo uses [Rokit](https://github.com/rojo-rbx/rokit) to manage tooling. After
`rokit install`:

```sh
# Run the unit test suite (pure-logic modules) with lune
lune run tests/runTests.luau

# Lint and format
selene src tests
stylua src tests ExampleProject

# Serve to Roblox Studio
rojo serve
```

The `ExampleProject/` directory is a runnable demo that maps the SDK from `../src`.

## Verifying in Roblox Studio

1. Open `ExampleProject` with Rojo (`rojo serve` from that folder) and connect from Studio.
2. In Game Settings, enable **Allow HTTP Requests**.
3. Put your project API key in `PostHogDemo.server.luau`.
4. Press Play. You should see `server_started`, `player_joined`, and the demo events appear in
   your PostHog project's Activity view, and a `welcome-message` flag value logged to the output.

## License

[MIT](LICENSE)
