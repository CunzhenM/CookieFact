--!strict
-- Persistence reusing the template's ProfileStore. Saves Coins (via partner CurrencyService
-- Get/Set) + the player's built Placements. Skips saving in Studio by default for a clean console
-- (DataStores only truly persist on live servers); flip SAVE_IN_STUDIO to test in Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SAVE_IN_STUDIO = false

local PlotService = require(script.Parent:WaitForChild("PlotService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))

local SaveService = {}

local TEMPLATE = {
	Coins = 0,
	Placements = {},
}
local STORE_NAME = "CookieFactory_Save_V1"
local AUTOSAVE_INTERVAL = 20

local Profiles = {}
local PlayerStore = nil

local function tryRequire(inst)
	if inst and inst:IsA("ModuleScript") then
		local ok, lib = pcall(require, inst)
		if ok and type(lib) == "table" then
			return lib
		end
	end
	return nil
end

local function findProfileStore()
	local ps = tryRequire(ServerScriptService:FindFirstChild("ProfileStore"))
	if ps then
		return ps
	end
	local tr = Workspace:FindFirstChild("TemplateResources")
	local trss = tr and tr:FindFirstChild("ServerScriptService")
	ps = tryRequire(trss and trss:FindFirstChild("ProfileStore"))
	if ps then
		return ps
	end
	return tryRequire(ServerStorage:FindFirstChild("ProfileStore"))
end

local Currency = nil
local function resolveCurrency()
	local serverScript = ServerScriptService:FindFirstChild("Server")
	local mod = serverScript and serverScript:FindFirstChild("CurrencyService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" then
			Currency = result
		end
	end
end

function SaveService.GetProfile(player)
	return Profiles[player]
end

local function capture(player)
	local profile = Profiles[player]
	if not profile then
		return
	end
	if Currency and Currency.Get then
		profile.Data.Coins = Currency.Get(player)
	end
	profile.Data.Placements = PlacementService.getPlacements(player)
end

local function applyLoaded(player, profile)
	if Currency and Currency.Set then
		Currency.Set(player, profile.Data.Coins or 0, "load")
	end
	task.spawn(function()
		local deadline = os.clock() + 20
		while not PlotService.getPlot(player) and os.clock() < deadline and player.Parent == Players do
			task.wait(0.2)
		end
		if PlotService.getPlot(player) then
			PlacementService.restore(player, profile.Data.Placements or {})
		end
	end)
end

local function onPlayerAdded(player)
	if not PlayerStore then
		return
	end
	local profile = PlayerStore:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		warn(("[SaveService] Could not load profile for %s; not saving this session."):format(player.Name))
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	Profiles[player] = profile
	applyLoaded(player, profile)
end

local function onPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		capture(player)
		profile:EndSession()
	end
end

function SaveService.Start()
	if RunService:IsStudio() and not SAVE_IN_STUDIO then
		warn("[SaveService] Studio session -- saving disabled for a clean console. Persists on live servers; set SAVE_IN_STUDIO=true (+ enable API access) to test it here.")
		return
	end
	PlayerStore = findProfileStore()
	if not PlayerStore then
		warn("[SaveService] ProfileStore not found -- saving disabled (game still functional).")
		return
	end
	PlayerStore = PlayerStore.New(STORE_NAME, TEMPLATE)
	resolveCurrency()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(Profiles) do
				capture(player)
			end
		end
	end)
	game:BindToClose(function()
		for player in pairs(Profiles) do
			capture(player)
		end
	end)
	print("[SaveService] online -- persistence via ProfileStore (" .. STORE_NAME .. ")")
end

return SaveService
