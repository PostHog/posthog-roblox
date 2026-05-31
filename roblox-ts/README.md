# @rbxts/posthog

[roblox-ts](https://roblox-ts.com) type bindings for the
[PostHog Roblox SDK](https://github.com/PostHog/posthog-roblox). Capture events, identify players,
evaluate feature flags, and track errors from TypeScript with full type safety and autocompletion.

The SDK itself is written in Luau. This package ships that Luau source paired with hand-written
`.d.ts` declarations, so there is no separate runtime to maintain: you get the exact same SDK your
Luau-using teammates do, just with types.

## Requirements

- A roblox-ts project (`@rbxts/compiler-types` and `@rbxts/types` are peer dependencies).
- HTTP requests enabled for your experience (**Game Settings → Security → Allow HTTP Requests**).
- A PostHog project API key (starts with `phc_`).

## Install

```sh
npm install @rbxts/posthog
```

roblox-ts maps the package into `ReplicatedStorage/rbxts_include/node_modules/@rbxts/posthog` at
compile time, so both server and client code can import it.

## Usage

The SDK is server-authoritative: the server does all HTTP, batching, identity, and feature-flag
work, while the client is a thin relay. That split maps to two imports.

### Server

The default import is the server API. Initialize it once from a server script.

```ts
import PostHog from "@rbxts/posthog";
import { Players } from "@rbxts/services";

PostHog.Init({
	apiKey: "phc_YOUR_PROJECT_API_KEY",
	enableClientRelay: true, // required if you also capture from the client
});

Players.PlayerAdded.Connect((player) => {
	// Events are attributed to a subject: a Player, a UserId, a distinct id, or
	// undefined for the server itself.
	PostHog.Capture(player, "level_started", { level: 3 });

	if (PostHog.IsFeatureEnabled(player, "new-shop")) {
		// ...
	}
});

// A server-attributed event (no player): pass undefined as the subject.
PostHog.Capture(undefined, "server_heartbeat", { players: Players.GetPlayers().size() });
```

### Client

In LocalScripts, import the client relay. It forwards calls to the server, which attributes them to
the local player. Unhandled client errors are captured automatically.

```ts
import PostHogClient from "@rbxts/posthog/out/Client";

PostHogClient.Capture("button_clicked", { button: "play" });
PostHogClient.Screen("Shop");
```

## The subject model

Every server method takes an explicit `subject` as its first argument so server code can attribute
an event to anyone:

| Subject | Attributed to |
| ------- | ------------- |
| `Player` | that player, by `UserId` |
| `number` | a `UserId` or any numeric id |
| `string` | an explicit distinct id |
| `undefined` | the server itself (`config.serverDistinctId`) |

```ts
PostHog.Capture(player, "with_player");
PostHog.Capture(123456789, "with_userid");
PostHog.Capture("cohort-42", "with_distinct_id");
PostHog.Capture(undefined, "server_scoped");
```

## Notes

- **Methods compile to colon calls.** `PostHog.Init(config)` in TypeScript compiles to
  `PostHog:Init(config)` in Luau, which is exactly what the SDK expects. Call them as normal
  methods.
- **The default import is the server API.** It is correct in server scripts. Client scripts should
  import `@rbxts/posthog/out/Client` to get the client-typed relay.
- **Types follow the Luau API.** `Config`, feature-flag results, and properties mirror the Luau
  types one-to-one. Property values must be JSON-encodable.

## Documentation

Full guides (configuration, autocapture, feature flags, error tracking, sessions, and the complete
API reference) live with the SDK:

- [Getting started](https://github.com/PostHog/posthog-roblox/blob/main/docs/getting-started.md)
- [API reference](https://github.com/PostHog/posthog-roblox/blob/main/docs/api-reference.md)
- [PostHog Roblox docs](https://posthog.com/docs/libraries/roblox)

## Building and publishing this package

The package is built by copying the Luau source from the repo and pairing the entry modules with
the `.d.ts` files in `bindings/`. There is no TypeScript compile step because the SDK is already
Luau.

```sh
npm install      # type-check dependencies
npm run check    # type-check the bindings (tsc --noEmit)
npm run build    # copy ../src + bindings into out/
```

`npm publish` runs the build automatically via `prepublishOnly`. Publishing under the `@rbxts`
scope requires membership in the roblox-ts npm organization; request access through the
[roblox-ts community](https://roblox-ts.com) or publish under a scope you own.

## License

[MIT](https://github.com/PostHog/posthog-roblox/blob/main/LICENSE)
