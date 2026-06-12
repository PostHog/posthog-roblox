--!strict
-- Shared type definitions for the PostHog Roblox SDK.

export type Properties = { [string]: any }

-- How person profiles are processed.
--   "always"          -> every event creates/updates a person profile
--   "identified_only" -> server-scoped events skip person profiles (default)
--   "never"           -> no event creates a person profile
export type PersonProfiles = "always" | "identified_only" | "never"

export type LogLevel = "debug" | "info" | "warn" | "error" | "none"

-- Pluggable persistent storage. The default implementation is in-memory.
-- All methods are synchronous from the caller's perspective.
export type Storage = {
    get: (self: Storage, key: string) -> string?,
    set: (self: Storage, key: string, value: string) -> (),
    remove: (self: Storage, key: string) -> (),
}

export type Config = {
    -- Required: your PostHog project API key (starts with "phc_").
    projectKey: string,

    -- PostHog instance URL. Defaults to the US cloud.
    host: string?,

    -- Event queue tuning.
    flushAt: number?,
    flushIntervalSeconds: number?,
    maxQueueSize: number?,
    maxBatchSize: number?,

    -- Feature flags.
    preloadFeatureFlags: boolean?,
    sendFeatureFlagEvents: boolean?,
    sendDefaultPersonPropertiesForFlags: boolean?,

    -- Autocapture and error tracking.
    captureLifecycleEvents: boolean?,
    captureErrors: boolean?,
    errorDebounceSeconds: number?,

    -- Identity / person profiles.
    personProfiles: PersonProfiles?,
    serverDistinctId: string?,

    -- Client events (relayed from clients to the server over a RemoteEvent).
    allowClientEvents: boolean?,
    clientRateLimitPerSecond: number?,
    maxClientPropertyCount: number?,

    -- Diagnostics.
    logLevel: LogLevel?,

    -- Advanced: override persistent storage (defaults to in-memory).
    storage: Storage?,

    -- Deprecated aliases, accepted with a warning. Removed in 1.0.
    apiKey: string?,
    enableClientRelay: boolean?,
}

-- Who an event is about. The server resolves a subject to a distinct id:
--   Player -> tostring(player.UserId)
--   number -> tostring(number) (a UserId or any numeric id)
--   string -> used as the distinct id verbatim
-- Passing nil to a method means the server itself (config.serverDistinctId).
export type Subject = Player | number | string

-- Structured input for CaptureException. Anywhere an ExceptionInput is accepted a
-- plain message string works too, since Luau errors are strings natively.
export type ExceptionInput = {
    type: string?,
    message: string,
    trace: string?,
}

-- A single PostHog event, ready to serialize to JSON.
export type Event = {
    uuid: string,
    event: string,
    distinct_id: string,
    timestamp: string,
    properties: Properties,
}

-- The result of reading a feature flag.
export type FeatureFlag = {
    key: string,
    -- The raw flag value: `true`/`false` for boolean flags, or a variant string.
    value: boolean | string,
    -- True for an enabled boolean flag or any non-empty variant.
    isEnabled: boolean,
    -- The variant name for multivariate flags, otherwise nil.
    variant: string?,
    -- The decoded JSON payload attached to the flag, otherwise nil.
    payload: any?,
}

return {}
