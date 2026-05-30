--!nonstrict
-- Client-only platform detection. The result is relayed to the server as
-- `$device_type` context.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Platform = {}

function Platform.detect(): string
    if GuiService:IsTenFootInterface() then
        return "Console"
    end

    if
        UserInputService.TouchEnabled
        and not UserInputService.MouseEnabled
        and not UserInputService.KeyboardEnabled
    then
        return "Mobile"
    end

    return "Desktop"
end

return Platform
