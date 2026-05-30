--!strict
-- Default configuration values, shared constants, and config resolution.

local Types = require(script.Parent.Types)

local Defaults = {}

Defaults.HOST = "https://us.i.posthog.com"
Defaults.FLUSH_AT = 20
Defaults.FLUSH_INTERVAL_SECONDS = 30
Defaults.MAX_QUEUE_SIZE = 1000
Defaults.MAX_BATCH_SIZE = 50
Defaults.PRELOAD_FEATURE_FLAGS = true
Defaults.SEND_FEATURE_FLAG_EVENTS = true
Defaults.SEND_DEFAULT_PERSON_PROPERTIES_FOR_FLAGS = true
Defaults.CAPTURE_LIFECYCLE_EVENTS = true
Defaults.CAPTURE_ERRORS = true
Defaults.ERROR_DEBOUNCE_SECONDS = 1
Defaults.PERSON_PROFILES = "identified_only" :: Types.PersonProfiles
Defaults.LOG_LEVEL = "warn" :: Types.LogLevel
Defaults.SERVER_DISTINCT_ID = "server"
Defaults.ENABLE_CLIENT_RELAY = true
Defaults.CLIENT_RATE_LIMIT_PER_SECOND = 20
Defaults.MAX_CLIENT_PROPERTY_COUNT = 100

-- Wire / protocol constants.
Defaults.FLAGS_VERSION = 2
Defaults.REMOTE_NAME = "PostHogRelay"
Defaults.REQUEST_TIMEOUT_SECONDS = 10
-- BindToClose grants ~30s; leave headroom for the final batches.
Defaults.SHUTDOWN_FLUSH_BUDGET_SECONDS = 25
Defaults.RETRY_DELAY_SECONDS = 5
Defaults.MAX_RETRY_DELAY_SECONDS = 30

-- Event names. Lifecycle names are overridable; system ($-prefixed) ones are not.
Defaults.EVENTS = {
    PLAYER_JOINED = "player_joined",
    PLAYER_LEFT = "player_left",
    IDENTIFY = "$identify",
    CREATE_ALIAS = "$create_alias",
    GROUP_IDENTIFY = "$groupidentify",
    FEATURE_FLAG_CALLED = "$feature_flag_called",
    EXCEPTION = "$exception",
    SCREEN = "$screen",
}

local function coalesce(value: any, fallback: any): any
    if value == nil then
        return fallback
    end
    return value
end

-- Fills a user config with defaults and validates it. Returns the resolved config.
-- Raises if the API key is missing or a numeric option is out of range.
function Defaults.resolve(config: Types.Config): Types.Config
    assert(type(config) == "table", "PostHog config must be a table")
    assert(
        type(config.apiKey) == "string" and config.apiKey ~= "",
        "PostHog config.apiKey is required"
    )

    local resolved: Types.Config = {
        apiKey = config.apiKey,
        host = coalesce(config.host, Defaults.HOST),
        flushAt = coalesce(config.flushAt, Defaults.FLUSH_AT),
        flushIntervalSeconds = coalesce(
            config.flushIntervalSeconds,
            Defaults.FLUSH_INTERVAL_SECONDS
        ),
        maxQueueSize = coalesce(config.maxQueueSize, Defaults.MAX_QUEUE_SIZE),
        maxBatchSize = coalesce(config.maxBatchSize, Defaults.MAX_BATCH_SIZE),
        preloadFeatureFlags = coalesce(config.preloadFeatureFlags, Defaults.PRELOAD_FEATURE_FLAGS),
        sendFeatureFlagEvents = coalesce(
            config.sendFeatureFlagEvents,
            Defaults.SEND_FEATURE_FLAG_EVENTS
        ),
        sendDefaultPersonPropertiesForFlags = coalesce(
            config.sendDefaultPersonPropertiesForFlags,
            Defaults.SEND_DEFAULT_PERSON_PROPERTIES_FOR_FLAGS
        ),
        captureLifecycleEvents = coalesce(
            config.captureLifecycleEvents,
            Defaults.CAPTURE_LIFECYCLE_EVENTS
        ),
        captureErrors = coalesce(config.captureErrors, Defaults.CAPTURE_ERRORS),
        errorDebounceSeconds = coalesce(
            config.errorDebounceSeconds,
            Defaults.ERROR_DEBOUNCE_SECONDS
        ),
        personProfiles = coalesce(config.personProfiles, Defaults.PERSON_PROFILES),
        serverDistinctId = coalesce(config.serverDistinctId, Defaults.SERVER_DISTINCT_ID),
        enableClientRelay = coalesce(config.enableClientRelay, Defaults.ENABLE_CLIENT_RELAY),
        clientRateLimitPerSecond = coalesce(
            config.clientRateLimitPerSecond,
            Defaults.CLIENT_RATE_LIMIT_PER_SECOND
        ),
        maxClientPropertyCount = coalesce(
            config.maxClientPropertyCount,
            Defaults.MAX_CLIENT_PROPERTY_COUNT
        ),
        logLevel = coalesce(config.logLevel, Defaults.LOG_LEVEL),
        storage = config.storage,
    }

    assert((resolved.flushAt :: number) >= 1, "config.flushAt must be at least 1")
    assert(
        (resolved.flushIntervalSeconds :: number) >= 1,
        "config.flushIntervalSeconds must be at least 1"
    )
    assert((resolved.maxQueueSize :: number) >= 1, "config.maxQueueSize must be at least 1")
    assert((resolved.maxBatchSize :: number) >= 1, "config.maxBatchSize must be at least 1")

    -- Normalize the host: strip any trailing slash so we can append paths cleanly.
    resolved.host = (resolved.host :: string):gsub("/+$", "")

    return resolved
end

return Defaults
