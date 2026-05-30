# Getting started with PostHog on Roblox

This guide takes you from zero to your first event in about 10 minutes. No prior PostHog
experience needed.

## What you'll need

- A **PostHog account** (free at [posthog.com](https://posthog.com)) and your **project API key**.
- A **Roblox experience** you can edit in Roblox Studio.

## 1. Get your project API key

In PostHog, open **Settings → Project** and copy the **Project API Key** (it starts with `phc_`).
While you're there, note your host: `https://us.i.posthog.com` (US) or `https://eu.i.posthog.com`
(EU).

## 2. Add the SDK to your game

Pick one of the two options.

### Option A — Wally (recommended)

If your project uses [Rojo](https://rojo.space) and [Wally](https://wally.run), add the dependency
to your `wally.toml`:

```toml
[dependencies]
PostHog = "posthog/posthog-roblox@0.1.0"
```

Run `wally install`, then make sure your Rojo project maps the installed package into
`ReplicatedStorage` so both server and client can reach it:

```json
"ReplicatedStorage": {
  "$className": "ReplicatedStorage",
  "PostHog": { "$path": "Packages/PostHog" }
}
```

### Option B — Manual (no tooling)

1. Download the latest `posthog-roblox.rbxm` from the
   [Releases page](https://github.com/PostHog/posthog-roblox/releases).
2. In Studio, right-click **ReplicatedStorage → Insert from File** and pick the `.rbxm`.
3. Rename the inserted module to `PostHog` if it isn't already.

You should now have `ReplicatedStorage > PostHog`.

## 3. Enable HTTP requests

PostHog sends events over HTTP, which only the Roblox **server** can do, and only when you allow
it:

- **Game Settings → Security → Allow HTTP Requests → On**, or
- in the command bar: `game:GetService("HttpService").HttpEnabled = true`

## 4. Initialize on the server

Create a **Script** in **ServerScriptService** (for example `PostHogInit`) and paste:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Init({
    apiKey = "phc_YOUR_PROJECT_API_KEY", -- paste your key
    host = "https://us.i.posthog.com",   -- or https://eu.i.posthog.com
})
```

## 5. Capture your first event

Still on the server, capture an event for each player who joins. Passing the `Player` attributes
the event to that user (their Roblox `UserId` becomes the PostHog `distinct_id`):

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    PostHog:Capture(player, "player_spawned", { team = "red" })
end)
```

Press **Play**. The SDK also captures `player_joined` automatically.

## 6. See it in PostHog

Open PostHog → **Activity** (or **Activity → Explore**). Within a few seconds you'll see
`player_joined` and `player_spawned`. If you don't, jump to [Troubleshooting](#troubleshooting).

## 7. Capture from the client

You can also capture from a **LocalScript** (for example in `StarterPlayerScripts`). Client calls
are relayed to the server, which attributes them to the firing player. No API key on the client:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Capture("button_clicked", { button = "play" })
PostHog:Screen("MainMenu")
```

Unhandled client errors are captured automatically as `$exception` events just by requiring the
SDK on the client.

## 8. Identify players and use feature flags

```lua
-- Attach properties to a player's PostHog profile.
PostHog:Identify(player, { display_name = player.DisplayName })

-- Evaluate a feature flag for a player (server-side).
if PostHog:IsFeatureEnabled(player, "new-shop", false) then
    PostHog:Capture(player, "new_shop_shown")
end
```

## Troubleshooting

No events showing up? Check, in order:

1. **HTTP is enabled** (step 3). Without it, the server cannot send anything.
2. **`Init` ran on the server** — it must be a `Script` (not a `LocalScript`), and you should see
   `[PostHog] PostHog initialized` in the output with `logLevel = "debug"`.
3. **The API key and host are correct** (key starts with `phc_`; host matches your region).
4. **You pressed Play** long enough for a flush (events send in batches every ~30s, or sooner once
   20 are queued; call `PostHog:Flush()` to send immediately while testing).
5. Turn on debug logging to see what's happening:

   ```lua
   PostHog:Init({ apiKey = "phc_...", logLevel = "debug" })
   ```

## Next steps

- Full configuration and API reference: [README](../README.md).
- A runnable demo: the [`ExampleProject`](../ExampleProject) folder.
