# Autocapture

The SDK records the lifecycle of your servers and players automatically. With autocapture on
(the default) you can build a useful analytics dashboard without writing a single manual event:
concurrent players, session length, retention, device and country splits, server uptime, and
errors all flow in on their own.

Autocapture is controlled by one option:

```lua
PostHog:Init({
    apiKey = "phc_...",
    captureLifecycleEvents = true, -- default; set false to turn lifecycle events off
})
```

Automatic error capture is separate and controlled by `captureErrors`. See
[Error tracking](error-tracking.md).

## Events captured automatically

| Event             | Fires when                          | Properties |
| ----------------- | ----------------------------------- | ---------- |
| `server_started`  | the SDK initializes on a server      | `player_count`, `max_players`, `is_private_server`, `is_reserved_server` |
| `server_shutdown` | the server shuts down (`BindToClose`) | `player_count`, `uptime_seconds` |
| `player_joined`   | a player joins                       | `is_teleport`, `player_count`, `account_age_days`, `membership_type`, `country_code`, `platform` |
| `player_left`     | a player leaves                      | `session_duration_seconds`, `player_count`, `platform`, `country_code` |
| `player_idle`     | Roblox reports a player has gone idle | `idle_seconds` |

Notes on the properties:

- `player_count` is the number of connected players right after the event: it includes a joining
  player and excludes a leaving one, so it reads as live concurrency.
- `is_teleport` is `true` when the player arrived from another place in your experience and the
  session was continued (see [Sessions](sessions.md)).
- `account_age_days` and `membership_type` come from the `Player` object. `membership_type` is the
  name of the `Player.MembershipType` enum (for example `None` or `Premium`).
- `is_reserved_server` is `true` for matchmade reserved servers; `is_private_server` is `true` for
  any non-public server, including player-owned (VIP) servers.
- `uptime_seconds` is how long the server ran before shutting down.
- `player_idle` uses `Player.Idled`, which Roblox raises after roughly 20 minutes of inactivity. It
  can fire more than once for a player who stays idle.

These names are not reserved, so you can rename them by editing your own wrapper, but the defaults
are chosen to read well on a dashboard.

## Context on every event

Every event the SDK sends (autocaptured, system, or your own) carries a standard set of context
properties, so you can segment any chart by place, version, session, or device without adding them
yourself:

| Property         | Meaning |
| ---------------- | ------- |
| `$lib`           | `"posthog-roblox"` |
| `$lib_version`   | the SDK version |
| `place_id`       | `game.PlaceId` |
| `place_version`  | `game.PlaceVersion` |
| `game_id`        | `game.GameId` (the universe id) |
| `server_job_id`  | `game.JobId` (the unique id of this server instance) |
| `$session_id`    | the player's session id (see [Sessions](sessions.md)) |
| `$groups`        | the subject's groups, when any are set |
| `$os`            | `"Roblox"`, or the client OS when relayed |
| `$device_type`   | `"Server"` for server-scoped events, or `Mobile` / `Console` / `Desktop` for a player |

## Build a dashboard with zero manual events

The autocaptured data alone answers most "how is my game doing" questions. A few examples of what
you can chart immediately in PostHog:

- **Concurrent players (CCU)** over time, from `player_count`, broken down by `place_version` or
  `country_code`.
- **Session length** distribution, from `player_left.session_duration_seconds`.
- **New vs returning players**, from PostHog's first-seen data on each `player_joined`.
- **Retention and stickiness**, using `player_joined` as the returning event.
- **Device mix**, from `$device_type` (Mobile / Console / Desktop).
- **Geography**, from `country_code`.
- **Premium share**, from `membership_type`.
- **Server fleet health**, from `server_started` / `server_shutdown` counts and `uptime_seconds`.
- **Private vs public play**, from `is_private_server` and `is_reserved_server`.
- **Idle rate**, from `player_idle`.
- **Error rate**, from automatic `$exception` events (see [Error tracking](error-tracking.md)).

Add your own [manual events](capturing-events.md) on top to track game-specific actions
(purchases, level completions, quest steps).

## Limitations to know

- **`platform` on `player_joined` may be empty.** Device type is a client signal. The server learns
  it the first time the client relays anything, which can be after the join event. It is reliably
  present on later events and on `player_left`. If you need device on join, capture a client event
  early (for example `PostHog:Screen("Loading")`) so the relay reports the device.
- **`country_code` needs `LocalizationService`.** It is best effort and can be `nil` if the lookup
  fails or is disabled.
- **Studio shuts down instantly.** `server_shutdown` is emitted on `BindToClose`, but Studio gives
  almost no shutdown window, so the final flush is best effort there. It works normally on live
  servers.

## See also

- [Capturing events](capturing-events.md): add your own events.
- [Sessions and teleports](sessions.md): how `$session_id` and `session_duration_seconds` work.
- [Error tracking](error-tracking.md): automatic `$exception` capture.
- [Configuration](configuration.md): the `captureLifecycleEvents` and `captureErrors` switches.
