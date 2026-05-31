# Configuration

Pass options to `PostHog:Init` on the server. Only `apiKey` is required; everything else has a
sensible default.

```lua
PostHog:Init({
    apiKey = "phc_YOUR_PROJECT_API_KEY", -- required

    host = "https://us.i.posthog.com",
    flushAt = 20,
    flushIntervalSeconds = 30,
    maxQueueSize = 1000,
    maxBatchSize = 50,

    preloadFeatureFlags = true,
    sendFeatureFlagEvents = true,
    sendDefaultPersonPropertiesForFlags = true,

    captureLifecycleEvents = true,
    captureErrors = true,
    errorDebounceSeconds = 1,

    personProfiles = "identified_only",
    serverDistinctId = "server",

    enableClientRelay = true,
    clientRateLimitPerSecond = 20,
    maxClientPropertyCount = 100,

    logLevel = "warn",
    storage = nil,
})
```

`Init` raises if `apiKey` is missing or empty, or if a numeric option is below its minimum. The
host has any trailing slash stripped automatically.

## Options

### Connection

| Option   | Type     | Default                       | Description |
| -------- | -------- | ----------------------------- | ----------- |
| `apiKey` | `string` | required                       | Your PostHog project API key. Starts with `phc_`. |
| `host`   | `string` | `https://us.i.posthog.com`     | PostHog instance URL. Use `https://eu.i.posthog.com` for EU cloud, or your self-hosted URL. |

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

See [Person profiles](identify-and-groups.md#person-profiles).

### Client relay

| Option                     | Type      | Default | Description |
| -------------------------- | --------- | ------- | ----------- |
| `enableClientRelay`        | `boolean` | `true`  | Create the `RemoteEvent` that lets clients relay events. |
| `clientRateLimitPerSecond` | `number`  | `20`    | Per-player token-bucket rate limit for relayed messages. |
| `maxClientPropertyCount`   | `number`  | `100`   | Maximum properties accepted from a single client message. |

Set `enableClientRelay = false` if you only capture on the server and want no client surface. See
[the client section of Capturing events](capturing-events.md#client).

### Diagnostics

| Option     | Type       | Default  | Description |
| ---------- | ---------- | -------- | ----------- |
| `logLevel` | `LogLevel` | `"warn"` | One of `"debug"`, `"info"`, `"warn"`, `"error"`, `"none"`. |

Use `"debug"` while integrating to see the SDK's lifecycle and HTTP activity in the output.

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
