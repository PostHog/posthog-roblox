# Feature flags

Feature flags let you turn features on or off and run experiments without shipping a new place
version. Flags are evaluated **per player on the server** against the PostHog `/flags` endpoint
and cached on the player's state, so reads after the first fetch are instant.

## How evaluation works

When a player joins, the SDK fetches their flags once (because `preloadFeatureFlags` is on by
default) and caches the result. Reading a flag after that does not hit the network. If you turn
preloading off, fetch flags yourself with [`ReloadFeatureFlags`](#reloading) before reading them.

Because evaluation is server-side, flag checks are trustworthy: a client cannot tamper with them.

## Boolean flags

`IsFeatureEnabled(subject, key, default)` returns a boolean. The `default` is returned when the
flag has not loaded or does not exist.

```lua
if PostHog:IsFeatureEnabled(player, "new-shop", false) then
    showNewShop(player)
else
    showOldShop(player)
end
```

## Multivariate flags and payloads

`GetFeatureFlag(subject, key)` returns the full result so you can read a variant string and any
attached JSON payload.

```lua
local flag = PostHog:GetFeatureFlag(player, "welcome-message")

-- flag = {
--   key      = "welcome-message",
--   value    = "friendly",   -- true/false for boolean flags, or the variant string
--   isEnabled = true,         -- true for an enabled boolean or any non-empty variant
--   variant  = "friendly",   -- the variant name, or nil for a boolean flag
--   payload  = { text = "Hi there!" }, -- decoded JSON payload, or nil
-- }

if flag.variant == "friendly" then
    setGreeting(player, flag.payload.text)
end
```

If you only need the payload, `GetFeatureFlagPayload(subject, key)` returns the decoded payload (or
`nil`).

```lua
local payload = PostHog:GetFeatureFlagPayload(player, "shop-config")
if payload then
    applyShopConfig(player, payload)
end
```

## Reloading

`ReloadFeatureFlags(subject)` re-fetches a subject's flags from PostHog. It **yields** (makes a
network request) and returns `true` on success.

```lua
task.spawn(function()
    if PostHog:ReloadFeatureFlags(player) then
        -- flags are fresh
    end
end)
```

Call it when something that affects targeting changes mid-session (the player leveled up, joined a
guild, changed a setting), or on a timer if you roll flags out gradually and want long sessions to
pick up changes.

## Targeting with properties

Flags can target players by person or group properties. Set the properties the SDK sends with the
flag request:

```lua
-- Person properties for this player's flag evaluation.
PostHog:SetPersonPropertiesForFlags(player, {
    level = 12,
    region = "us-east",
})

-- Group properties for a group the player belongs to.
PostHog:SetGroupPropertiesForFlags(player, "guild", {
    tier = "gold",
})
```

Both methods reload flags afterward by default. Pass `false` as the last argument to set the
properties without reloading (for example when you are about to set several and want one reload):

```lua
PostHog:SetPersonPropertiesForFlags(player, { level = 12 }, false)
PostHog:SetGroupPropertiesForFlags(player, "guild", { tier = "gold" }, false)
PostHog:ReloadFeatureFlags(player) -- one reload for both
```

Properties set through [`Identify`](identify-and-groups.md) and [`Group`](identify-and-groups.md)
are also used for targeting, so you often do not need these methods at all.

## `$feature_flag_called` events

When you read a flag that has a value, the SDK emits a `$feature_flag_called` event so PostHog can
power experiment results. These are deduplicated per player and flag value, so reading the same
flag in a loop does not spam events. A new flag fetch resets the dedup so a changed value is
reported again.

Turn this off with `sendFeatureFlagEvents = false` if you do not run experiments and want to save
events.

## Preloading and timing

- With `preloadFeatureFlags = true` (default), a player's flags are fetched on join and after
  `Identify`. Read them any time after the player has joined.
- With preloading off, `IsFeatureEnabled` and `GetFeatureFlag` return the default until you call
  `ReloadFeatureFlags`.
- The flag request includes default library and device properties unless you set
  `sendDefaultPersonPropertiesForFlags = false`.
- If your PostHog project is over its flag quota, the response clears all flags for that request
  and reads fall back to defaults.

## See also

- [Identifying users and groups](identify-and-groups.md): properties used for targeting.
- [Configuration](configuration.md): `preloadFeatureFlags`, `sendFeatureFlagEvents`,
  `sendDefaultPersonPropertiesForFlags`.
- [API reference](api-reference.md): full flag method signatures.
