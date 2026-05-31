/**
 * PostHog Roblox SDK — server type bindings for roblox-ts.
 *
 * Paired at runtime with `init.luau`, which returns the server API when required
 * from a server Script. Import this as the package default in server code:
 *
 *   import PostHog from "@rbxts/posthog";
 *   PostHog.Init({ apiKey: "phc_..." });
 *
 * In LocalScripts, import the client relay instead:
 *
 *   import PostHogClient from "@rbxts/posthog/out/Client";
 */

/** Arbitrary event, person, or group properties. Values must be JSON-encodable. */
type Properties = Record<string, unknown>;

/**
 * How person profiles are processed.
 * - "always": every event creates or updates a person profile.
 * - "identified_only" (default): server-scoped events skip person profiles.
 * - "never": no event creates a person profile.
 */
type PersonProfiles = "always" | "identified_only" | "never";

type LogLevel = "debug" | "info" | "warn" | "error" | "none";

/** Pluggable persistent storage. The default implementation is in-memory. */
interface Storage {
	get(key: string): string | undefined;
	set(key: string, value: string): void;
	remove(key: string): void;
}

interface Config {
	/** Required: your PostHog project API key (starts with "phc_"). */
	apiKey: string;
	/** PostHog instance URL. Defaults to the US cloud. */
	host?: string;
	flushAt?: number;
	flushIntervalSeconds?: number;
	maxQueueSize?: number;
	maxBatchSize?: number;
	preloadFeatureFlags?: boolean;
	sendFeatureFlagEvents?: boolean;
	sendDefaultPersonPropertiesForFlags?: boolean;
	captureLifecycleEvents?: boolean;
	captureErrors?: boolean;
	errorDebounceSeconds?: number;
	personProfiles?: PersonProfiles;
	serverDistinctId?: string;
	enableClientRelay?: boolean;
	clientRateLimitPerSecond?: number;
	maxClientPropertyCount?: number;
	logLevel?: LogLevel;
	/** Advanced: override persistent storage (defaults to in-memory). */
	storage?: Storage;
}

/** The result of reading a feature flag. */
interface FeatureFlag {
	key: string;
	/** `true`/`false` for a boolean flag, or the variant string. */
	value: boolean | string;
	/** True for an enabled boolean flag or any non-empty variant. */
	isEnabled: boolean;
	/** The variant name for multivariate flags, otherwise undefined. */
	variant?: string;
	/** The decoded JSON payload attached to the flag, otherwise undefined. */
	payload?: unknown;
}

/**
 * Who an event is attributed to:
 * - `Player`     attributes to that player by UserId.
 * - `number`     a UserId or any numeric id.
 * - `string`     an explicit distinct id.
 * - `undefined`  the server itself (config.serverDistinctId).
 */
type Subject = Player | number | string | undefined;

interface PostHogServer {
	/** Initialize the SDK. Call once from a server Script. */
	Init(config: Config): PostHogServer;
	IsInitialized(): boolean;

	/** Capture an event for a subject. */
	Capture(subject: Subject, eventName: string, properties?: Properties): void;
	/** Capture a screen view for a subject. */
	Screen(subject: Subject, screenName: string, properties?: Properties): void;

	/** Identify a subject and set person properties. */
	Identify(subject: Subject, setProperties?: Properties, setOnceProperties?: Properties): void;
	/** Alias a subject to another distinct id. */
	Alias(subject: Subject, alias: string): void;
	/** Associate a subject with a group, optionally setting group properties. */
	Group(subject: Subject, groupType: string, groupKey: string, groupProperties?: Properties): void;

	/** Register a super property attached to every event from every subject. */
	Register(key: string, value: unknown): void;
	/** Remove a previously registered super property. */
	Unregister(key: string): void;

	/** Manually capture an exception for a subject. */
	CaptureException(subject: Subject, message: string, trace?: string, properties?: Properties): void;

	/** Read a feature flag for a subject. */
	GetFeatureFlag(subject: Subject, key: string): FeatureFlag;
	/** Whether a boolean (or non-empty variant) flag is enabled for a subject. */
	IsFeatureEnabled(subject: Subject, key: string, defaultValue?: boolean): boolean;
	/** The decoded JSON payload for a flag, or undefined. */
	GetFeatureFlagPayload(subject: Subject, key: string): unknown;
	/** Reload a subject's flags from the server. Yields on the network request. */
	ReloadFeatureFlags(subject: Subject): boolean;
	/** Set person properties used for flag evaluation, optionally reloading. */
	SetPersonPropertiesForFlags(subject: Subject, properties: Properties, reload?: boolean): void;
	/** Set group properties used for flag evaluation, optionally reloading. */
	SetGroupPropertiesForFlags(
		subject: Subject,
		groupType: string,
		properties: Properties,
		reload?: boolean,
	): void;

	/** A TeleportData fragment to merge in so a player's session continues across teleports. */
	GetSessionTeleportData(player: Player): Record<string, unknown>;

	/** Stop capturing events for a subject. */
	OptOut(subject: Subject): void;
	/** Resume capturing events for a subject. */
	OptIn(subject: Subject): void;

	/** Flush queued events immediately. */
	Flush(): void;
	/** Flush and tear down the SDK. */
	Shutdown(): void;
}

declare const PostHog: PostHogServer;
export = PostHog;
