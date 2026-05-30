--!strict
-- Pure classification of an HTTP status code into a delivery action.
-- Mirrors the PostHog Unity SDK's queue retry semantics.
--
-- Actions:
--   "success"       -> 2xx: events delivered, delete them
--   "retry"         -> network error (0), 3xx, or 5xx: keep events, back off and retry
--   "retry_smaller" -> 413 (payload too large): halve the batch size, then retry
--   "drop"          -> other 4xx: non-retryable, delete the events

export type Action = "success" | "retry" | "retry_smaller" | "drop"

local RetryPolicy = {}

function RetryPolicy.classify(statusCode: number): Action
    if statusCode == 0 then
        return "retry"
    end

    if statusCode >= 200 and statusCode < 300 then
        return "success"
    end

    if statusCode >= 300 and statusCode < 400 then
        return "retry"
    end

    if statusCode == 413 then
        return "retry_smaller"
    end

    if statusCode >= 400 and statusCode < 500 then
        return "drop"
    end

    if statusCode >= 500 then
        return "retry"
    end

    -- Unknown / unexpected: retry conservatively.
    return "retry"
end

return RetryPolicy
