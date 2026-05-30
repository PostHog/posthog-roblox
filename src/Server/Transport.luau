--!nonstrict
-- HTTP transport over HttpService:RequestAsync (server only). Every call is wrapped
-- in pcall: RequestAsync throws on network failure, when HTTP is disabled, and when
-- the request budget is exceeded. Those are normalized to statusCode 0 so the queue
-- treats them as retryable.

local HttpService = game:GetService("HttpService")

local Json = require(script.Parent.Parent.Shared.Json)
local Defaults = require(script.Parent.Parent.Shared.Defaults)

local Transport = {}
Transport.__index = Transport

export type Result = {
    ok: boolean,
    statusCode: number,
    body: any?, -- decoded JSON, or nil
}

-- opts: { host: string, logger }
function Transport.new(opts)
    return setmetatable({
        _host = opts.host,
        _logger = opts.logger,
    }, Transport)
end

function Transport:_request(url: string, bodyTable: any): Result
    local body = Json.encode(bodyTable)

    local ok, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
            },
            Body = body,
        })
    end)

    if not ok then
        self._logger:warn(`HTTP request failed: {tostring(response)}`)
        return { ok = false, statusCode = 0, body = nil }
    end

    local decoded = nil
    if type(response.Body) == "string" and response.Body ~= "" then
        decoded = Json.decode(response.Body)
    end

    return {
        ok = response.Success,
        statusCode = response.StatusCode,
        body = decoded,
    }
end

-- Sends a batch payload to the capture endpoint.
function Transport:sendBatch(payload: any): Result
    return self:_request(`{self._host}/batch`, payload)
end

-- Fetches feature flags for the given request body.
function Transport:fetchFlags(body: any): Result
    local url = `{self._host}/flags/?v={Defaults.FLAGS_VERSION}`
    return self:_request(url, body)
end

return Transport
