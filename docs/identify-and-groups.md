# Identifying users and groups

Every player already has a stable identity: their Roblox `UserId`, which the SDK uses as the
PostHog `distinct_id`. You do not need to call `Identify` to track a player. You call it to attach
properties to their person profile so you can segment and filter by them in PostHog.

## Person properties

`Identify(subject, setProperties, setOnceProperties)` updates the subject's person profile.

```lua
PostHog:Identify(player, {
    display_name = player.DisplayName,
    level = 12,
    vip = true,
})
```

- `setProperties` (the `$set` table) is written every time. Use it for values that change, like
  `level`.
- `setOnceProperties` (the `$set_once` table) is written only if the property is not already set.
  Use it for values that should never change after the first time, like `first_seen_place` or
  `signup_source`.

```lua
PostHog:Identify(player,
    { level = 12 },                       -- always updated
    { first_join_date = os.date("!%Y-%m-%d") } -- set only the first time
)
```

Person properties set through `Identify` are also remembered for [feature flag](feature-flags.md)
targeting and trigger a flag reload when `preloadFeatureFlags` is on.

## Person profiles

How person profiles are created is controlled by the `personProfiles` option:

| Mode                | Behavior |
| ------------------- | -------- |
| `"identified_only"` | Default. Player events create profiles; server-scoped events (`nil` subject) do not. |
| `"always"`          | Every event creates or updates a profile. |
| `"never"`           | No event creates a profile. Useful for fully anonymous analytics. |

Players carry a real identity (their `UserId`), so the default is a good fit: you get person-level
analytics for players without creating a junk profile for the server. See
[Configuration](configuration.md#person-profiles).

## Aliasing

`Alias(subject, alias)` links another id to the subject's id, merging their event histories in
PostHog. Use it when the same person is known by two ids, for example linking an external account
id to a player.

```lua
PostHog:Alias(player, "external-account-12345")
```

You rarely need this in Roblox because the `UserId` is already a stable identity. Reach for it
only when you genuinely have two ids for one person.

## Stable ids across systems

Subjects are not limited to `Player` instances: every method that takes a subject also accepts a
plain string distinct id, so you can attribute events to an id you control. If your game shares
users with a system outside Roblox (your own account system, a backend, a website), you have two
options:

- **Keep `UserId` as the distinct id and link the external id** (recommended):

  ```lua
  PostHog:Alias(player, "acct_8f3a2b")
  ```

  Events keep flowing under the player's `UserId` while PostHog merges both ids into one person.

- **Capture directly against your own id**, bypassing the player entirely:

  ```lua
  PostHog:Capture("acct_8f3a2b", "subscription_renewed", { plan = "pro" })
  PostHog:Identify("acct_8f3a2b", { plan = "pro" })
  ```

  Sessions and autocaptured player events still use the `UserId` identity, so prefer `Alias`
  unless the events genuinely concern a non-player entity.

## Groups

Group analytics let you roll players up into a shared entity (a guild, a party, a clan, a server
shard) and analyze that entity as a unit. A group has a **type** (the kind of thing, like `guild`)
and a **key** (which one, like `guild_42`).

```lua
-- Associate a player with their guild and optionally set the guild's properties.
PostHog:Group(player, "guild", "guild_42", {
    name = "Dragon Slayers",
    member_count = 30,
    tier = "gold",
})
```

After this call, events for that player include a `$groups` property, so you can filter and break
down by guild in PostHog. A player can belong to one group of each type at a time; calling `Group`
again with the same type changes which group they are in.

Group membership also feeds [feature flag](feature-flags.md) evaluation: a flag rolled out to
`guild` groups is evaluated against the player's current group. To set group properties used only
for flag targeting (without emitting a group event) use
[`SetGroupPropertiesForFlags`](feature-flags.md#targeting-with-properties).

## See also

- [Feature flags](feature-flags.md): target flags by person and group properties.
- [Capturing events](capturing-events.md): super properties vs person properties.
- [Configuration](configuration.md): the `personProfiles` option.
- [API reference](api-reference.md): full signatures for `Identify`, `Alias`, and `Group`.
