/**
 * PostHog Roblox SDK — client relay type bindings for roblox-ts.
 *
 * The client is a thin relay: it forwards capture calls and client-side errors to
 * the server over a RemoteEvent. Import in LocalScripts:
 *
 *   import PostHogClient from "@rbxts/posthog/out/Client";
 *   PostHogClient.Capture("button_clicked", { button: "play" });
 *
 * The server SDK must be initialized with `enableClientRelay: true`.
 */

/** Arbitrary event properties. Values must be JSON-encodable. */
type Properties = Record<string, unknown>;

interface ClientConfig {
	/** Capture unhandled client errors automatically. Defaults to true. */
	captureErrors?: boolean;
}

interface PostHogClient {
	/** Optional client configuration. Errors are captured automatically by default. */
	Init(options?: ClientConfig): PostHogClient;
	/** Capture an event. Relayed to the server and attributed to the local player. */
	Capture(eventName: string, properties?: Properties): void;
	/** Capture a screen view. */
	Screen(screenName: string, properties?: Properties): void;
	/** Manually capture a client exception. */
	CaptureException(message: string, trace?: string, properties?: Properties): void;
	/** No-op on the client; flushing happens on the server. Provided for symmetry. */
	Flush(): void;
	IsInitialized(): boolean;
}

declare const PostHogClient: PostHogClient;
export = PostHogClient;
