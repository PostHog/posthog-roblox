# Using the SDK with roblox-ts

If you write your game in TypeScript with [roblox-ts](https://roblox-ts.com), you can use this SDK
with full type safety through the [`@rbxts/posthog`](https://www.npmjs.com/package/@rbxts/posthog)
package. It ships the same Luau SDK paired with hand-written TypeScript declarations, so there is no
separate runtime: you get the exact SDK described throughout these docs, just typed.

## Install

```sh
npm install @rbxts/posthog
```

`@rbxts/compiler-types` and `@rbxts/types` are peer dependencies (every roblox-ts project already
has them). roblox-ts maps the package into
`ReplicatedStorage/rbxts_include/node_modules/@rbxts/posthog` at compile time, so both server and
client code can import it.

You still need HTTP requests enabled (**Game Settings → Security → Allow HTTP Requests**) and a
PostHog project API key (starts with `phc_`), exactly as in the [getting started
guide](getting-started.md).

## Server

The default import is the server API. Initialize it once from a server script.

```ts
import PostHog from "@rbxts/posthog";
import { Players } from "@rbxts/services";

PostHog.Init({
	apiKey: "phc_YOUR_PROJECT_API_KEY",
	host: "https://us.i.posthog.com", // or https://eu.i.posthog.com
	enableClientRelay: true,
});

Players.PlayerAdded.Connect((player) => {
	PostHog.Capture(player, "tutorial_started", { step: 1 });

	if (PostHog.IsFeatureEnabled(player, "new-shop", false)) {
		PostHog.Capture(player, "new_shop_shown");
	}
});
```

Methods compile to colon calls: `PostHog.Init(config)` in TypeScript becomes `PostHog:Init(config)`
in Luau, which is what the SDK expects.

## Client

In LocalScripts, import the client relay. It forwards calls to the server, which attributes them to
the local player. Unhandled client errors are captured automatically.

```ts
import PostHogClient from "@rbxts/posthog/out/Client";

PostHogClient.Capture("button_clicked", { button: "play" });
PostHogClient.Screen("MainMenu");
```

The client relay only works when the server SDK is initialized with `enableClientRelay: true`.

## The subject model

Every server method takes an explicit `subject` as its first argument, mirroring the Luau API
(see [Capturing events](capturing-events.md)). TypeScript types it as
`Player | number | string | undefined`:

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
PostHog.Capture(undefined, "server_scoped"); // no player: pass undefined
```

## Notes

- **The default import is the server API.** It is correct in server scripts. Client scripts should
  import `@rbxts/posthog/out/Client` to get the client-typed relay.
- **Types follow the Luau API.** `Config`, feature-flag results, and event properties mirror the
  Luau types one-to-one. Property values must be JSON-encodable.
- The full configuration, autocapture behavior, feature flags, error tracking, and method reference
  are the same as the Luau SDK. See the [API reference](api-reference.md) and
  [Configuration](configuration.md).

## See also

- [`@rbxts/posthog` on npm](https://www.npmjs.com/package/@rbxts/posthog)
- [Getting started](getting-started.md) (Luau)
- [API reference](api-reference.md)
