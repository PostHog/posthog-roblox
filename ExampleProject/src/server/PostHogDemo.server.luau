--!nonstrict
-- Server-side demo of the PostHog Roblox SDK.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PostHog = require(ReplicatedStorage:WaitForChild("PostHog"))

PostHog:Init({
    projectKey = "phc_YOUR_PROJECT_API_KEY", -- replace with your project API key
    host = "https://us.i.posthog.com", -- or https://eu.i.posthog.com
    logLevel = "debug",
})

-- A super property attached to every event from every player on this server.
PostHog:Register("game_mode", "demo")

-- server_started / server_shutdown and player_joined / player_left are captured
-- automatically. This is a custom server-scoped event (nil subject), not tied to a
-- player, for something specific to your game.
PostHog:Capture(nil, "daily_reward_reset", {
    reward_multiplier = 2,
})

Players.PlayerAdded:Connect(function(player)
    -- Events attributed to a specific player by passing the Player instance.
    PostHog:Capture(player, "tutorial_started", { step = 1 })

    -- Identify the player and set person properties.
    PostHog:Identify(player, {
        display_name = player.DisplayName,
    })

    -- Feature flags are evaluated server-side for this player.
    if PostHog:IsFeatureEnabled(player, "new-shop", false) then
        PostHog:Capture(player, "new_shop_shown")
    end

    -- Read a multivariate flag and its payload.
    local flag = PostHog:GetFeatureFlag(player, "welcome-message")
    if flag.variant then
        print(`welcome-message variant for {player.Name}: {flag.variant}`)
    end
end)
