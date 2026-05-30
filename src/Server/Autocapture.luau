--!nonstrict
-- Player lifecycle autocapture. Creates per-player state and session on join
-- (continuing a session across teleports), emits player_joined / player_left, and
-- tears down state on leave.

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")

local Session = require(script.Parent.Session)
local Defaults = require(script.Parent.Parent.Shared.Defaults)

local Autocapture = {}
Autocapture.__index = Autocapture

-- opts: {
--   config, logger, registry, uuid,
--   now = () -> number,                                  -- wall-clock seconds
--   capture = function(playerState, eventName, props),   -- emits an event
--   onPlayerReady = function(player, playerState),       -- e.g. preload flags
-- }
function Autocapture.new(opts)
    return setmetatable({
        _config = opts.config,
        _logger = opts.logger,
        _registry = opts.registry,
        _uuid = opts.uuid,
        _now = opts.now,
        _capture = opts.capture,
        _onPlayerReady = opts.onPlayerReady,
        _connections = {},
    }, Autocapture)
end

function Autocapture:start()
    table.insert(
        self._connections,
        Players.PlayerAdded:Connect(function(player)
            self:_handleAdded(player)
        end)
    )
    table.insert(
        self._connections,
        Players.PlayerRemoving:Connect(function(player)
            self:_handleRemoving(player)
        end)
    )

    -- Catch players who joined before the SDK initialized.
    for _, player in Players:GetPlayers() do
        task.spawn(function()
            self:_handleAdded(player)
        end)
    end

    self._logger:debug("autocapture started")
end

function Autocapture:_lookupCountry(player): string?
    local ok, country = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(player)
    end)
    if ok and type(country) == "string" and country ~= "" then
        return country
    end
    return nil
end

function Autocapture:_handleAdded(player: Player)
    local distinctId = tostring(player.UserId)

    -- Continue a session across teleports when the destination carried our data.
    local teleportData = nil
    local okJoin, joinData = pcall(function()
        return player:GetJoinData()
    end)
    if okJoin and joinData then
        teleportData = joinData.TeleportData
    end

    local restored = Session.fromTeleportData(teleportData)
    local session = restored or Session.create(self._uuid, self._now())
    local isTeleport = restored ~= nil

    local state = self._registry:getOrCreate(distinctId, {
        userId = player.UserId,
        session = session,
    })
    state.session = session

    -- Let the SDK react (e.g. preload feature flags) before we emit the join event.
    if self._onPlayerReady then
        self._onPlayerReady(player, state)
    end

    if not self._config.captureLifecycleEvents then
        return
    end

    state.countryCode = self:_lookupCountry(player)

    self._capture(state, Defaults.EVENTS.PLAYER_JOINED, {
        is_teleport = isTeleport,
        account_age_days = player.AccountAge,
        membership_type = player.MembershipType.Name,
        country_code = state.countryCode,
        platform = state.platform,
    })
end

function Autocapture:_handleRemoving(player: Player)
    local distinctId = tostring(player.UserId)
    local state = self._registry:get(distinctId)

    if self._config.captureLifecycleEvents and state and state.session then
        local duration = math.max(0, math.floor(self._now() - state.session.startTime))
        self._capture(state, Defaults.EVENTS.PLAYER_LEFT, {
            session_duration_seconds = duration,
        })
    end

    self._registry:remove(distinctId)
end

function Autocapture:stop()
    for _, connection in self._connections do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

return Autocapture
