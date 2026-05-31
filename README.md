# 🦔 PostHog Roblox SDK (BETA)

The [PostHog](https://posthog.com) analytics SDK for Roblox. Capture events, identify players,
evaluate feature flags, and track errors from your Roblox experiences.

- **Server-authoritative.** All HTTP and batching happen on the server (the only place Roblox
  allows outbound requests). A thin client module relays calls to the server.
- **Per-player.** Each player is a PostHog user, keyed by their `UserId`.
- **Batteries included.** Events, identity, groups, feature flags, error tracking, and lifecycle
  autocapture, with a useful dashboard out of the box and no manual events required.

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
Rojo project so both the server and client can `require` it:

```json
"ReplicatedStorage": {
  "$className": "ReplicatedStorage",
  "PostHog": { "$path": "Packages/PostHog" }
}
```

### Manual

Download the latest `posthog-roblox.rbxm` from the
[releases page](https://github.com/PostHog/posthog-roblox/releases) and insert it into
`ReplicatedStorage` (right-click → **Insert from File**). Make sure it is named `PostHog`.

## Hello world

Server (a `Script` in `ServerScriptService`):

```lua
local Players = game:GetService("Players")
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Init({ apiKey = "phc_YOUR_PROJECT_API_KEY" })

Players.PlayerAdded:Connect(function(player)
    PostHog:Capture(player, "hello_world") -- attributed to a player
end)
```

Client (a `LocalScript`):

```lua
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Capture("button_clicked", { button = "play" }) -- relayed to the server
```

That is enough to start sending data. The [getting started guide](docs/getting-started.md) walks
through it step by step and shows how to verify events in PostHog.

## Documentation

| Guide | What it covers |
| ----- | -------------- |
| [Getting started](docs/getting-started.md) | A guided first integration, from install to your first events in PostHog. |
| [Capturing events](docs/capturing-events.md) | `Capture` and `Screen`, server subjects, the client relay, event properties, super properties, opt-out. |
| [Autocapture](docs/autocapture.md) | Events and context captured automatically, and how to build a dashboard with zero manual events. |
| [Identifying users and groups](docs/identify-and-groups.md) | `Identify`, person properties, `Alias`, person profiles, and `Group` analytics. |
| [Feature flags](docs/feature-flags.md) | Boolean and multivariate flags, payloads, reloading, and targeting. |
| [Error tracking](docs/error-tracking.md) | Automatic and manual exception capture on the server and client. |
| [Sessions and teleports](docs/sessions.md) | How sessions work and how to continue them across teleports. |
| [Configuration](docs/configuration.md) | Every `Init` option explained. |
| [API reference](docs/api-reference.md) | The complete server and client API. |

## Architecture

```
Client (LocalScript)                 Server (Script)
  PostHog:Capture(name, props)          PostHog:Init(config)
  PostHog:Screen(name)          --->    autocapture, identity, feature flags
  unhandled errors          RemoteEvent  event queue + HTTP  (/batch, /flags)
        |                      relay      game:BindToClose (final flush)
        '------ FireServer ----------------->
```

The server owns the event queue, identity, feature flags, error tracking, and all HTTP. The client
never holds the API key and is treated as untrusted: relayed messages are validated, rate-limited,
and always attributed to the firing player. See
[Capturing events](docs/capturing-events.md#client) for the relay's security model.

## Development

This repo uses [Rokit](https://github.com/rojo-rbx/rokit) to manage tooling. After
`rokit install`:

```sh
# Run the unit test suite (pure-logic modules) with a 100% function-coverage gate.
lune run tests/runTests.luau

# Lint and format.
selene src tests
stylua src tests ExampleProject

# Serve to Roblox Studio.
rojo serve
```

The [`ExampleProject`](ExampleProject) directory is a runnable demo that maps the SDK from `../src`.
Open it with `rojo serve`, connect from Studio, set your API key in `PostHogDemo.server.luau`, and
press Play to see autocaptured and demo events appear in your PostHog project.

Releases are automated on tag push; see [RELEASING.md](RELEASING.md).

## License

[MIT](LICENSE)
