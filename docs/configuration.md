# Configuration

Pass options to `PostHog:Init` on the server. Only `projectToken` is required; everything else has a
sensible default.

```lua
PostHog:Init({
    projectToken = "phc_YOUR_PROJECT_TOKEN", -- required

    host = "https://us.i.posthog.com",
    flushAt = 20,
    flushIntervalSeconds = 30,
    maxQueueSize = 1000,
    maxBatchSize = 50,

    preloadFeatureFlags = true,
    sendFeatureFlagEvents = true,
    sendDefaultPersonPropertiesForFlags = true,
    featureFlagRequestMaxRetries = 1,

    captureLifecycleEvents = true,
    captureErrors = true,
    errorDebounceSeconds = 1,

    personProfiles = "identified_only",
    serverDistinctId = "server",

    allowClientEvents = true,
    clientRateLimitPerSecond = 20,
    maxClientPropertyCount = 100,

    logLevel = "warn",
    storage = nil,
    beforeSend = nil,
})
```

`Init` logs a warning and does nothing if `projectToken` is missing or blank. It raises if a numeric
option is below its minimum. The host has any trailing slash stripped automatically.

The pre-0.2 names `apiKey` and `enableClientRelay` are still accepted as deprecated aliases for
`projectToken` and `allowClientEvents`. They log a warning and will be removed in 1.0.

## Options

### Connection

| Option       | Type     | Default                       | Description |
| ------------ | -------- | ----------------------------- | ----------- |
| `projectToken` | `string` | required                       | Your PostHog project token. Starts with `phc_`. |
| `host`       | `string` | `https://us.i.posthog.com`     | PostHog instance URL. Use `https://eu.i.posthog.com` for EU cloud, or your self-hosted URL. |

### Event queue

| Option                 | Type     | Default | Minimum | Description |
| ---------------------- | -------- | ------- | ------- | ----------- |
| `flushAt`              | `number` | `20`    | `1`     | Flush once this many events are queued. |
| `flushIntervalSeconds` | `number` | `30`    | `1`     | Flush at least this often. |
| `maxQueueSize`         | `number` | `1000`  | `1`     | Drop the oldest events past this size. |
| `maxBatchSize`         | `number` | `50`    | `1`     | Maximum events per HTTP request. |

Lower `flushAt` and `flushIntervalSeconds` to send sooner (handy while testing); raise them to
batch more aggressively on a busy server.

### Feature flags

| Option                                | Type      | Default | Description |
| ------------------------------------- | --------- | ------- | ----------- |
| `preloadFeatureFlags`                 | `boolean` | `true`  | Fetch a player's flags when they join. |
| `sendFeatureFlagEvents`               | `boolean` | `true`  | Emit `$feature_flag_called` when a flag is read. |
| `sendDefaultPersonPropertiesForFlags` | `boolean` | `true`  | Include `$lib`, `$os`, and device in flag requests. |
| `featureFlagRequestMaxRetries`        | `number`  | `1`     | Retries for a flag request after a network error, 502 or 504. `0` disables retries. |

See [Feature flags](feature-flags.md).

### Autocapture and errors

| Option                   | Type      | Default | Description |
| ------------------------ | --------- | ------- | ----------- |
| `captureLifecycleEvents` | `boolean` | `true`  | Emit `server_started` / `server_shutdown` / `player_joined` / `player_left` / `player_idle`. |
| `captureErrors`          | `boolean` | `true`  | Capture unhandled errors as `$exception` events. |
| `errorDebounceSeconds`   | `number`  | `1`     | Minimum gap between auto-captured server errors. |

See [Autocapture](autocapture.md) and [Error tracking](error-tracking.md).

### Person profiles

| Option             | Type              | Default             | Description |
| ------------------ | ----------------- | ------------------- | ----------- |
| `personProfiles`   | `PersonProfiles`  | `"identified_only"` | How person profiles are created. |
| `serverDistinctId` | `string`          | `"server"`          | The `distinct_id` used for server-scoped (`nil` subject) events. |

`personProfiles` accepts:

- `"identified_only"` (default): player events create profiles, server-scoped events do not.
- `"always"`: every event creates or updates a profile.
- `"never"`: no event creates a profile.

`serverDistinctId` only applies to events about the server itself: pass `nil` as the subject (or
let autocapture emit `server_started` / `server_shutdown` / server `$exception` events) and the
event is attributed to this id. It never affects player events, and clients can never choose their
own distinct id; the server always derives it from the firing player's `UserId`.

See [Person profiles](identify-and-groups.md#person-profiles).

### Client events

Roblox clients cannot make HTTP requests, so the client SDK relays events to the server over a
`RemoteEvent` and the server sends them to PostHog. These options control that ingestion surface
only; they never affect server-side capture.

| Option                     | Type      | Default | Description |
| -------------------------- | --------- | ------- | ----------- |
| `allowClientEvents`        | `boolean` | `true`  | Create the `RemoteEvent` and accept events relayed from clients. |
| `clientRateLimitPerSecond` | `number`  | `20`    | Per-player token-bucket rate limit for relayed messages. |
| `maxClientPropertyCount`   | `number`  | `100`   | Maximum properties accepted from a single client message. |

Set `allowClientEvents = false` if you only capture on the server and want no client surface. See
[the client section of Capturing events](capturing-events.md#client).

### Diagnostics

| Option     | Type       | Default  | Description |
| ---------- | ---------- | -------- | ----------- |
| `logLevel` | `LogLevel` | `"warn"` | One of `"debug"`, `"info"`, `"warn"`, `"error"`, `"none"`. |

Use `"debug"` while integrating to see the SDK's lifecycle and HTTP activity in the output.

### Filtering events

| Option       | Type                         | Default | Description |
| ------------ | ---------------------------- | ------- | ----------- |
| `beforeSend` | `(event: Event) -> Event?`   | `nil`   | Modify or drop every event before it is queued. |

`beforeSend` runs on the fully built event (properties, `$session_id`, `$groups` and SDK context
included), for server, client-relayed and autocaptured events alike. Return the event to send it,
or `nil` to drop it. If the callback errors, the SDK logs the error and drops the event.

```lua
PostHog:Init({
    projectToken = "phc_YOUR_PROJECT_TOKEN",
    beforeSend = function(event)
        if event.event == "player_idle" then
            return nil
        end
        event.properties.email = nil
        return event
    end,
})
```

### Storage (advanced)

| Option    | Type       | Default     | Description |
| --------- | ---------- | ----------- | ----------- |
| `storage` | `Storage?` | in-memory   | Override the persistence provider. |

The event queue is in memory by default, which suits Roblox's ephemeral servers. The `Storage`
interface is a seam for a custom provider (for example a DataStore-backed one):

```lua
export type Storage = {
    get: (self: Storage, key: string) -> string?,
    set: (self: Storage, key: string, value: string) -> (),
    remove: (self: Storage, key: string) -> (),
}
```

## See also

- [API reference](api-reference.md): every method.
- [Getting started](getting-started.md): a guided first integration.
