# Getting started

This guide takes you from an empty place to your first events in PostHog in about ten minutes. It
is self-contained: follow it top to bottom and you will have the SDK installed, initialized, and
sending data. For a deeper look at any feature, see the guides linked at the end.

## Before you start

You need two things:

1. A **PostHog project API key** (starts with `phc_`). Find it in PostHog under
   **Settings → Project**. Note your host while you are there: `https://us.i.posthog.com` (US) or
   `https://eu.i.posthog.com` (EU).
2. A **Roblox place** you can edit in Studio.

## 1. Install the SDK

The SDK must end up at `ReplicatedStorage > PostHog`, where both the server and client code load it
from. There are two ways to install it and **you only need one.** Pick whichever matches how you
build your game:

- **Option A (Wally)** if you manage dependencies with Wally and build with Rojo.
- **Option B (model file)** if you build directly in Roblox Studio with no external tooling.

### Option A: Wally (Rojo projects)

Add the dependency to your `wally.toml`:

```toml
[dependencies]
PostHog = "posthog/posthog-roblox@0.1.0"
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

## 2. Enable HTTP requests

Whichever option you picked above, PostHog sends events over HTTP, which only the Roblox **server**
can do, and only when you allow it: **Game Settings → Security → Allow HTTP Requests → On**.

## 3. Initialize on the server

Create a `Script` in `ServerScriptService` and initialize the SDK with your key. Use
`logLevel = "debug"` for now so you can watch it work.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Init({
    apiKey = "phc_YOUR_PROJECT_API_KEY", -- paste your key
    host = "https://us.i.posthog.com",   -- or https://eu.i.posthog.com
    logLevel = "debug",
})
```

Press **Play**. You already have data: the SDK captures `server_started` and `player_joined`
automatically. See [Autocapture](autocapture.md) for the full list.

## 4. Capture your first manual event

Add an event for something specific to your game. Passing the `Player` attributes it to that user.

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    PostHog:Capture(player, "tutorial_started", { step = 1 })
end)
```

## 5. See it in PostHog

Open PostHog and go to **Activity**. Within a few seconds you will see `server_started`,
`player_joined`, and `tutorial_started`. Events send in batches (every 30 seconds, or once 20 are
queued); call `PostHog:Flush()` to send immediately while testing.

If nothing shows up, jump to [Troubleshooting](#troubleshooting).

## 6. Capture from the client

You can also capture from a `LocalScript` (for example in `StarterPlayerScripts`). Client calls are
relayed to the server, which attributes them to the firing player. There is no API key on the
client and no subject argument:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Capture("button_clicked", { button = "play" })
PostHog:Screen("MainMenu")
```

Requiring the SDK on the client also captures unhandled client errors automatically.

## 7. Try identity and a feature flag

```lua
-- Attach properties to the player's profile.
PostHog:Identify(player, { display_name = player.DisplayName })

-- Evaluate a feature flag for the player (server-side).
if PostHog:IsFeatureEnabled(player, "new-shop", false) then
    PostHog:Capture(player, "new_shop_shown")
end
```

## Next steps

You now have the basics. Go deeper on each feature:

- [Capturing events](capturing-events.md): subjects, properties, the client relay, super
  properties, opt-out.
- [Autocapture](autocapture.md): everything captured for free and how to build a dashboard from it.
- [Identifying users and groups](identify-and-groups.md): person properties and group analytics.
- [Feature flags](feature-flags.md): boolean and multivariate flags, payloads, targeting.
- [Error tracking](error-tracking.md): automatic and manual exception capture.
- [Sessions and teleports](sessions.md): continue sessions across places.
- [Configuration](configuration.md): every option.
- [API reference](api-reference.md): every method.

## Troubleshooting

No events showing up? Check, in order:

1. **HTTP is enabled** (step 2). Without it the server cannot send anything.
2. **`Init` ran on the server.** It must be in a `Script` (not a `LocalScript`). With
   `logLevel = "debug"` you should see `PostHog initialized` in the output.
3. **The key and host are correct.** The key starts with `phc_` and the host matches your region.
4. **You waited for a flush.** Events batch every ~30 seconds or once 20 are queued. Call
   `PostHog:Flush()` to send immediately.
5. **Client events are reaching the server.** The server SDK must be initialized with
   `enableClientRelay = true` (the default). If the client logs that the relay was not found, the
   server SDK is not running.
