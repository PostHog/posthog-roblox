--!nonstrict
-- Thin wrapper around HttpService JSON with safe decoding.
--
-- Note on empty tables: HttpService:JSONEncode encodes an empty Lua table as `[]`
-- (an array), not `{}` (an object). The SDK avoids this by never serializing empty
-- maps: payload builders omit empty `properties` sub-objects (`$set`, `$groups`,
-- `person_properties`, ...) entirely rather than sending `{}`.

local HttpService = game:GetService("HttpService")

local Json = {}

function Json.encode(value: any): string
    return HttpService:JSONEncode(value)
end

-- Decodes a JSON string, returning (ok, valueOrError).
function Json.tryDecode(text: string): (boolean, any)
    return pcall(function()
        return HttpService:JSONDecode(text)
    end)
end

-- Decodes a JSON string, returning the value or nil on failure.
function Json.decode(text: string): any?
    local ok, value = Json.tryDecode(text)
    if ok then
        return value
    end
    return nil
end

return Json
