# Capturing events

An event is a named thing that happened (`level_completed`, `item_purchased`,
`button_clicked`) plus optional properties that describe it. This guide covers how to send
events from the server and the client.

> Many useful events are captured for you with no code. See
> [Autocapture](autocapture.md) before adding manual events so you do not duplicate them.

## Server

On the server every capture call takes a **subject** as its first argument. The subject decides
who the event is attributed to.

```lua
local Players = game:GetService("Players")
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))

Players.PlayerAdded:Connect(function(player)
    -- Attribute the event to a specific player.
    PostHog:Capture(player, "level_completed", {
        level = 5,
        score = 1250,
        used_powerup = true,
    })
end)
```

### Subjects

The subject resolves to the PostHog `distinct_id` that the event is attributed to:

| Subject       | Resolves to                                    | Use it for                          |
| ------------- | ---------------------------------------------- | ----------------------------------- |
| a `Player`    | `tostring(player.UserId)`                       | anything a player did               |
| a `number`    | `tostring(number)`                              | a known UserId you do not have the `Player` for |
| a `string`    | the string, used as-is                          | your own id scheme                  |
| `nil`         | `config.serverDistinctId` (default `"server"`)  | server-wide events not tied to a player |

A `nil` subject marks the event server-scoped. Server-scoped events are sent with
`$process_person_profile = false` so they never create a person profile for the server. See
[person profiles](identify-and-groups.md#person-profiles).

```lua
-- Not tied to any player.
PostHog:Capture(nil, "economy_reset", { reward_multiplier = 2 })
```

### Event properties

Properties are a plain table. On the server values can be strings, numbers, booleans, or nested
tables and arrays. Values that cannot be serialized to JSON (Instances, functions, `NaN`, cyclic
tables) are dropped or stringified automatically so a bad value can never break the queue.

```lua
PostHog:Capture(player, "quest_finished", {
    quest_id = "dragon_cave",
    rewards = { gold = 100, items = { "sword", "shield" } }, -- nested is fine on the server
    duration_seconds = 142.5,
})
```

Property names beginning with `$` are reserved for PostHog. You can read them on events the SDK
sends, but prefer your own names for custom data.

### Screen views

`Screen` is a convenience wrapper that captures a `$screen` event with a `$screen_name` property.
Use it for menus, shops, and other "pages" of your UI.

```lua
PostHog:Screen(player, "Shop", { tab = "weapons" })
```

## Client

The client cannot make HTTP requests, so it relays calls to the server over a `RemoteEvent`. The
client API does **not** take a subject: the server always attributes a relayed event to the
player who fired it.

```lua
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Capture("button_clicked", { button = "play" })
PostHog:Screen("MainMenu")
```

The client buffers calls until the relay is ready, so you can capture immediately on load. If the
server SDK is not running (or `allowClientEvents` is off) buffered calls are dropped after a short
wait.

### What the client may send

The relay treats clients as untrusted. Each message is validated on the server before it becomes
an event:

- **Reserved names are rejected.** Clients cannot send `$`-prefixed event names; those are emitted
  by the SDK only.
- **Property values must be scalars.** Only strings, numbers, and booleans survive. Nested tables
  from the client are dropped.
- **Property count is capped** by `maxClientPropertyCount` (default 100).
- **Calls are rate limited** per player by `clientRateLimitPerSecond` (default 20) using a token
  bucket. Excess calls are dropped.
- **Attribution is forced** to the firing player. A client cannot capture as someone else.

Tune these with [configuration](configuration.md). For sensitive or high-trust events, capture on
the server instead.

## Super properties

Super properties are attached to **every** event from **every** subject on the server. They are
server-global, which suits values that describe the whole server instance (region, build, game
mode).

```lua
PostHog:Register("server_region", "us-east")
PostHog:Register("build_channel", "live")

-- Stop attaching a super property.
PostHog:Unregister("build_channel")
```

Precedence, lowest to highest: super properties, then the properties you pass to a capture call,
then SDK context properties. For per-player data use [`Identify`](identify-and-groups.md) or
per-call properties rather than super properties.

## Opting players out

`OptOut` stops the SDK from capturing anything for a subject until `OptIn` is called. Use it to
honor an in-game privacy setting.

```lua
PostHog:OptOut(player)  -- events for this player are dropped
PostHog:OptIn(player)   -- resume capturing
```

## When events are sent

Events are queued in memory and flushed to PostHog:

- when `flushAt` events are queued (default 20),
- every `flushIntervalSeconds` (default 30),
- on `game:BindToClose()` (server shutdown), and
- when you call `PostHog:Flush()`.

`Flush` is asynchronous and never yields the caller. Call it while testing to see events land
right away.

## See also

- [Autocapture](autocapture.md): events you get with no code.
- [Identifying users and groups](identify-and-groups.md): person properties and group analytics.
- [Configuration](configuration.md): queue tuning and relay limits.
- [API reference](api-reference.md): full method signatures.
