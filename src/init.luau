--!nonstrict
-- PostHog Roblox SDK entry point.
--
-- Requiring this module returns the server API on the server and the client relay
-- on the client, so game code can `require` it from either context:
--
--   local PostHog = require(ReplicatedStorage.PostHog)
--
-- On the server call `PostHog:Init({ projectKey = "phc_..." })` once from a Script.

local RunService = game:GetService("RunService")

if RunService:IsServer() then
    return require(script.Server)
else
    return require(script.Client)
end
