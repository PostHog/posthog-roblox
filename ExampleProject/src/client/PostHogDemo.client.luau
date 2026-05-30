--!nonstrict
-- Client-side demo of the PostHog Roblox SDK.
--
-- Client calls are relayed to the server, which attributes them to this player.
-- Unhandled client errors are captured automatically just by requiring the SDK.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

-- A relayed event. No player argument: the server uses the firing player.
PostHog:Capture("client_loaded", {
    ui_version = "1.0.0",
})

-- A screen / page view.
PostHog:Screen("MainMenu")

-- Manually report a handled error from the client.
local ok, err = pcall(function()
    error("example handled error")
end)
if not ok then
    PostHog:CaptureException(tostring(err), debug.traceback())
end
