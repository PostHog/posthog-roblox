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

return true
