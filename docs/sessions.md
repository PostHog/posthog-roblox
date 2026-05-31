# Sessions and teleports

A session models one play session. It starts when a player joins and ends when they leave. Every
event a player produces carries a `$session_id` so you can group a player's actions into the visit
they happened in, and PostHog can compute session-based metrics.

The session id is a time-ordered UUID (v7). The server itself also has a session for its lifetime,
used by server-scoped events.

## What you get automatically

With [autocapture](autocapture.md) on:

- `$session_id` is attached to every event.
- `player_left` includes `session_duration_seconds`, the length of the session in seconds.

You do not need to start or stop sessions yourself.

## Continuing a session across teleports

A multi-place experience (a lobby that teleports into rounds, a hub world with sub-games) should
read as **one** session even though the player crosses places. Roblox treats each place as a fresh
join, so by default the player would get a new session id at the destination.

To keep the session continuous, merge the SDK's session fragment into your `TeleportData` before
teleporting. The destination server restores it on join and continues the same session.

```lua
local TeleportService = game:GetService("TeleportService")
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))

local function teleport(player, placeId)
    local options = Instance.new("TeleportOptions")

    -- Merge PostHog's session data into your own teleport data.
    options:SetTeleportData(PostHog:GetSessionTeleportData(player))

    TeleportService:TeleportAsync(placeId, { player }, options)
end
```

`GetSessionTeleportData(player)` returns a table with a single reserved key (`__posthog`). If you
also pass your own teleport data, merge the two tables rather than overwriting:

```lua
local data = PostHog:GetSessionTeleportData(player)
data.my_game_state = { checkpoint = 3 } -- add your own keys alongside

local options = Instance.new("TeleportOptions")
options:SetTeleportData(data)
```

On the destination, a continued session is marked with `is_teleport = true` on the `player_joined`
event, so you can tell organic joins from teleport arrivals.

The destination place must also be running the SDK for the session to continue.

## See also

- [Autocapture](autocapture.md): `$session_id`, `player_joined`, and `session_duration_seconds`.
- [API reference](api-reference.md): `GetSessionTeleportData`.
