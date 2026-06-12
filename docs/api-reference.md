# API reference

The module returns the server API when required from a server script and the client API when
required from a client script. The same `require` works on both sides; the SDK picks the right one.

```lua
local PostHog = require(game.ReplicatedStorage:WaitForChild("PostHog"))
```

## Subjects

Every server method that acts on a user takes a **subject** as its first argument:

| Subject    | Resolves to                                    |
| ---------- | ---------------------------------------------- |
| a `Player` | `tostring(player.UserId)`                       |
| a `number` | `tostring(number)`                              |
| a `string` | the string, used as-is                          |
| `nil`      | `config.serverDistinctId` (server-scoped event) |

A subject is just a distinct id, so players are not the only option: pass any string to attribute
events to an id you control (for example an account id shared with your other platforms). See
[Stable ids across systems](identify-and-groups.md#stable-ids-across-systems).

## Server API

### Lifecycle

#### `PostHog:Init(config) -> PostHog`

Initializes the SDK. Call once from a server `Script`. Raises if `config.projectKey` is missing.
See [Configuration](configuration.md) for every option. Returns the module for chaining.

#### `PostHog:IsInitialized() -> boolean`

Returns whether `Init` has run.

#### `PostHog:Flush()`

Sends queued events now. Asynchronous; does not yield.

#### `PostHog:Shutdown()`

Stops autocapture, error tracking, and the relay, then flushes. The SDK also flushes on
`game:BindToClose()` automatically, so you rarely call this directly.

### Capturing

#### `PostHog:Capture(subject, eventName, properties?)`

Captures an event. See [Capturing events](capturing-events.md).

#### `PostHog:Screen(subject, screenName, properties?)`

Captures a `$screen` event with a `$screen_name` property.

#### `PostHog:CaptureException(subject, exception, trace?, properties?)`

Captures a handled error as a `$exception`. `exception` is a message string or a structured
`{ type?, message, trace? }` table. See [Error tracking](error-tracking.md).

### Identity

#### `PostHog:Identify(subject, setProperties?, setOnceProperties?)`

Sets person properties (`$set` and `$set_once`). See
[Identifying users](identify-and-groups.md#person-properties).

#### `PostHog:Alias(subject, alias)`

Links another id to the subject's id.

#### `PostHog:Group(subject, groupType, groupKey, groupProperties?)`

Associates the subject with a group and optionally sets group properties. See
[Groups](identify-and-groups.md#groups).

#### `PostHog:Register(key, value)` / `PostHog:Unregister(key)`

Adds or removes a server-global super property attached to every event. See
[Super properties](capturing-events.md#super-properties).

### Feature flags

#### `PostHog:IsFeatureEnabled(subject, key, default?) -> boolean`

Returns whether a flag is enabled, or `default` if it has not loaded.

#### `PostHog:GetFeatureFlag(subject, key) -> FeatureFlag`

Returns `{ key, value, isEnabled, variant, payload }`.

#### `PostHog:GetFeatureFlagPayload(subject, key) -> any?`

Returns the decoded JSON payload for a flag, or `nil`.

#### `PostHog:ReloadFeatureFlags(subject) -> boolean`

Re-fetches the subject's flags. **Yields** on the network request; returns success.

#### `PostHog:SetPersonPropertiesForFlags(subject, properties, reload?)`

Sets person properties used for flag targeting. Reloads unless `reload` is `false`.

#### `PostHog:SetGroupPropertiesForFlags(subject, groupType, properties, reload?)`

Sets group properties used for flag targeting. Reloads unless `reload` is `false`.

See [Feature flags](feature-flags.md).

### Sessions

#### `PostHog:GetSessionTeleportData(player) -> table`

Returns a `TeleportData` fragment to merge in before teleporting so the player's session continues
at the destination. See [Sessions](sessions.md).

### Privacy

#### `PostHog:OptOut(subject)` / `PostHog:OptIn(subject)`

Stops or resumes capturing for a subject.

## Client API

The client API takes no subject; the server attributes relayed events to the firing player.

#### `PostHog:Init(options?) -> PostHog`

Optional. Pass `{ captureErrors = false }` to stop automatic client error capture. Requiring the
module already connects the relay and starts error capture.

#### `PostHog:Capture(eventName, properties?)`

Relays an event to the server. Reserved (`$`-prefixed) names are rejected server-side.

#### `PostHog:Screen(screenName, properties?)`

Relays a screen view.

#### `PostHog:CaptureException(exception, trace?, properties?)`

Relays a handled error. `exception` is a message string or a structured
`{ type?, message, trace? }` table.

#### `PostHog:Flush()`

No-op on the client (flushing happens on the server). Provided for API symmetry.

#### `PostHog:IsInitialized() -> boolean`

Always `true` on the client.

## Types

```lua
type Subject = Player | number | string -- see Subjects above; nil means the server itself

type ExceptionInput = {
    type: string?,  -- defaults to "Error"
    message: string,
    trace: string?, -- used when no trace argument is passed
}

type FeatureFlag = {
    key: string,
    value: boolean | string, -- true/false for boolean flags, or the variant string
    isEnabled: boolean,      -- true for an enabled boolean or any non-empty variant
    variant: string?,        -- the variant name, or nil for a boolean flag
    payload: any?,           -- decoded JSON payload, or nil
}
```

See [Configuration](configuration.md#storage-advanced) for the `Config`, `Storage`,
`PersonProfiles`, and `LogLevel` types.

## Event reference

Events the SDK emits on your behalf.

### Autocaptured ([Autocapture](autocapture.md))

| Event             | Trigger |
| ----------------- | ------- |
| `server_started`  | SDK initializes |
| `server_shutdown` | server shuts down |
| `player_joined`   | a player joins |
| `player_left`     | a player leaves |
| `player_idle`     | a player goes idle |

### System

| Event                  | Emitted by |
| ---------------------- | ---------- |
| `$identify`            | `Identify` |
| `$create_alias`        | `Alias` |
| `$groupidentify`       | `Group` |
| `$feature_flag_called` | reading a feature flag |
| `$exception`           | error tracking and `CaptureException` |
| `$screen`              | `Screen` |
