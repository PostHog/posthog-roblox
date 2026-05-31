# 🦔 PostHog Roblox SDK (BETA)

The [PostHog](https://posthog.com) analytics SDK for Roblox. Capture events, identify players,
evaluate feature flags, and track errors from your Roblox experiences.

- **Server-authoritative.** All HTTP and batching happen on the server (the only place Roblox
  allows outbound requests). A thin client module relays calls to the server.
- **Per-player.** Each player is a PostHog user, keyed by their `UserId`.
- **Batteries included.** Events, identity, groups, feature flags, error tracking, and lifecycle
  autocapture that records meaningful session metrics out of the box, so you can chart real player
  behavior before writing a single manual event.

> **Note:** This SDK is in **beta**. It's ready to try, but the API may still change before a
> stable release. If you hit a bug or have feedback, please
> [open an issue](https://github.com/PostHog/posthog-roblox/issues). We'd love to hear from you.

## Requirements

- HTTP requests enabled for your experience (Game Settings → Security → **Allow HTTP Requests**).
- A PostHog project API key (starts with `phc_`).

## Installation

The SDK must end up at `ReplicatedStorage > PostHog`, where both the server and client code load it
from. There are two ways to install it and **you only need one.** Pick whichever matches how you
build your game:

- **Option A (Wally)** if you manage dependencies with Wally and build with Rojo.
- **Option B (model file)** if you build directly in Roblox Studio with no external tooling.

### Option A: Wally (Rojo projects)

Add the dependency to your `wally.toml`:

```toml
[dependencies]
PostHog = "posthog/posthog-roblox@0.1.3"
```

Run `wally install`, then map the package into `ReplicatedStorage` in your Rojo project file (for
example `default.project.json`) so it replicates to clients:

```json
"ReplicatedStorage": {
  "$className": "ReplicatedStorage",
  "PostHog": { "$path": "Packages/PostHog" }
}
```

### Option B: Model file (Roblox Studio, no tooling)

Download the latest `posthog-roblox.rbxm` from the
[releases page](https://github.com/PostHog/posthog-roblox/releases). In Studio, right-click
`ReplicatedStorage` → **Insert from File**, select the file, and make sure the inserted instance is
named `PostHog`.

## Enable HTTP requests

Whichever option you picked above, the SDK sends events over HTTP, which only the Roblox server can
do, and only once you allow it: **Game Settings → Security → Allow HTTP Requests → On**.

## Quick start

With `ReplicatedStorage > PostHog` in place and HTTP enabled, initialize on the server and start
capturing. Lifecycle events like `server_started` and `player_joined` are captured automatically, so
you have data the moment you press **Play**.

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

New to the SDK? The **[getting started guide](docs/getting-started.md)** walks through the whole
flow end to end: installing, initializing, verifying your first events in PostHog, and adding
identity and feature flags.

## Documentation

| Guide | What it covers |
| ----- | -------------- |
| [Getting started](docs/getting-started.md) | **Start here.** Install, initialize, and see your first events in PostHog. |
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

This repo uses [Rokit](https://github.com/rojo-rbx/rokit) to manage tooling. After `rokit install`,
run the test suite with `lune run tests/runTests.luau`. See **[DEVELOPMENT.md](DEVELOPMENT.md)** for
the full guide: toolchain, tests and the coverage gate, linting and formatting, building the model
file, and running the example in Roblox Studio.

Releases are automated on tag push; see [RELEASING.md](RELEASING.md).

## License

[MIT](LICENSE)
