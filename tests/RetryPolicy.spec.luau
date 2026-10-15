--!nonstrict
local h = require("./helper")
local RetryPolicy = require("../src/Shared/RetryPolicy")

h.test("RetryPolicy: 2xx is success", function()
    h.expectEqual(RetryPolicy.classify(200), "success")
    h.expectEqual(RetryPolicy.classify(204), "success")
end)

h.test("RetryPolicy: network error and 3xx/5xx retry", function()
    h.expectEqual(RetryPolicy.classify(0), "retry")
    h.expectEqual(RetryPolicy.classify(301), "retry")
    h.expectEqual(RetryPolicy.classify(500), "retry")
    h.expectEqual(RetryPolicy.classify(503), "retry")
end)

h.test("RetryPolicy: 413 retries with a smaller batch", function()
    h.expectEqual(RetryPolicy.classify(413), "retry_smaller")
end)

h.test("RetryPolicy: other 4xx are dropped", function()
    h.expectEqual(RetryPolicy.classify(400), "drop")
    h.expectEqual(RetryPolicy.classify(401), "drop")
    h.expectEqual(RetryPolicy.classify(404), "drop")
    h.expectEqual(RetryPolicy.classify(429), "drop")
end)

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
