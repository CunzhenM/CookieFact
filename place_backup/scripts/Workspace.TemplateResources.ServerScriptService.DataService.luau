local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ProfileStore)

-- ─── Template ─────────────────────────────────────────────────────────
-- Mirrors GameServiceHub.newState() + ItemManager.Items.
-- IMPORTANT: every persisted field must be declared here so Profile:Reconcile
-- adds it to existing profiles after a code change.
local TEMPLATE = {
	Balance = 100,
	SpeedLevel = 0,
	KickLevel = 1,
	KickXP = 0,
	Rebirths = 0,
	Spins = 0,
	AddedSlots = 0,
	TutorialStep = 1,
	DiscoveredItems = {},                  -- mutation -> array of brainrot names
	WeightEquipped = "Wooden Stick",
	WeightOwned = { "Wooden Stick" },
	Items = {},                            -- array of brainrot Item structs
	PlacedBrainrots = {}
}

local STORE_NAME = "PlayerData_V1"           -- bump suffix if you ever reshape
local PlayerStore = ProfileStore.New(STORE_NAME, TEMPLATE)

local Profiles: {[Player]: any} = {}

-- ─── Public API ───────────────────────────────────────────────────────
local DataService = {}

function DataService.GetProfile(player: Player)
	return Profiles[player]
end

function DataService.WaitForProfile(player: Player, timeoutSeconds: number?)
	local deadline = os.clock() + (timeoutSeconds or 30)
	while os.clock() < deadline do
		if Profiles[player] then return Profiles[player] end
		if player.Parent ~= Players then return nil end
		task.wait(0.1)
	end
	return Profiles[player]
end

_G.DataAPI = DataService

-- ─── Lifecycle ────────────────────────────────────────────────────────
local function onPlayerAdded(player: Player)
	local key = "Player_" .. tostring(player.UserId)
	local profile = PlayerStore:StartSessionAsync(key, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		warn(("[DataService] Failed to load profile for %s; kicking"):format(player.Name))
		if player.Parent == Players then
			player:Kick("Data load failed — please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()  -- fills any missing template keys

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Data session ended — please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	Profiles[player] = profile
	print(("[DataService] Loaded profile for %s (UserId %d) — Balance=%d Rebirths=%d Items=%d"):format(
		player.Name, player.UserId, profile.Data.Balance or 0, profile.Data.Rebirths or 0, #(profile.Data.Items or {})
	))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then
		profile:EndSession()  -- auto-saves; Profiles[player] cleared by OnSessionEnd
	end
end)

print("[DataService] Initialized — persistent profiles via ProfileStore.")
