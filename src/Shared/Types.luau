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
    apiKey: string,

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

    -- Client relay.
    enableClientRelay: boolean?,
    clientRateLimitPerSecond: number?,
    maxClientPropertyCount: number?,

    -- Diagnostics.
    logLevel: LogLevel?,

    -- Advanced: override persistent storage (defaults to in-memory).
    storage: Storage?,
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
