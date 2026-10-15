--!nonstrict
local h = require("./helper")
local RetryPolicy = require("../src/Shared/RetryPolicy")

for _, case in
    {
        { status = 200, expected = "success" },
        { status = 204, expected = "success" },
        { status = 0, expected = "retry" },
        { status = 301, expected = "retry" },
        { status = 408, expected = "retry" },
        { status = 429, expected = "retry" },
        { status = 500, expected = "retry" },
        { status = 503, expected = "retry" },
        { status = 413, expected = "retry_smaller" },
        { status = 400, expected = "drop" },
        { status = 401, expected = "drop" },
        { status = 404, expected = "drop" },
    }
do
    h.test(`RetryPolicy: classify({case.status}) is {case.expected}`, function()
        h.expectEqual(RetryPolicy.classify(case.status), case.expected)
    end)
end

for _, case in
    {
        { status = 0, expected = true },
        { status = 502, expected = true },
        { status = 504, expected = true },
        { status = 200, expected = false },
        { status = 400, expected = false },
        { status = 429, expected = false },
        { status = 500, expected = false },
        { status = 503, expected = false },
    }
do
    h.test(`RetryPolicy: shouldRetryFlags({case.status}) is {case.expected}`, function()
        h.expectEqual(RetryPolicy.shouldRetryFlags(case.status), case.expected)
    end)
end

for _, case in
    {
        { attempt = 1, expected = 0.3 },
        { attempt = 2, expected = 0.6 },
        { attempt = 3, expected = 1.2 },
    }
do
    h.test(`RetryPolicy: flagsRetryDelay({case.attempt}) is {case.expected}s`, function()
        h.expectEqual(RetryPolicy.flagsRetryDelay(case.attempt), case.expected)
    end)
end

return true
