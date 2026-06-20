local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Network = require(ReplicatedStorage.Shared.Packages.Network)
local WeightsData = require(ReplicatedStorage.Shared.Data.WeightsData)

-- â”€â”€â”€ Pre-create every RemoteEvent expected by the client side â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local CLIENT_EXPECTED_KEYS = {
	-- BaseUpgradesServiceClient
	"bs_upgrade", "bs_updateClient",
	-- ClientBalanceService
	"CoinsChanged", "CoinsMulti",
	-- ClientIndexService
	"IndexUpdate",
	-- ClientPlotService (also registered by PlotService â€” idempotent)
	"PlotAdded",
	-- FriendBoostServiceClient
	"CheckFriend", "FriendsUPD",
	-- KickServiceClient
	"KickData", "KickMulti", "KICK_UPGRADE", "TaviMishkal",
	-- LeaderboardServiceClient
	"LeaderboardUPD",
	-- MessagesService
	"PlayMessage",
	-- MyMarketplaceServiceClient
	"myMarket_data", "myMarket_stock",
	-- NotificationServiceClient
	"NotificationUpdate",
	-- RebirthServiceClient
	"RebirthRequest", "RebirthUpdate",
	-- ServerLuckClient (created at module-load time on client!)
	"sl_upd",
	-- SpeedServiceClient
	"SPEED_UPGRADE", "SPEED_UPDATE", "SPEED_MULTIPLIER",
	-- TimedUpgradesServiceClient
	"TimedUpdate",
	-- TutorialServiceClient
	"TutorialStep",
	-- VFXService
	"VFX_UPD",
	-- WeatherService_Client (also created at module-load on client)
	"WeatherUpdate", "AddedWeather", "RemovedWeather",
	-- WeightServiceClient
	"Weight_Update", "Weight_Multi", "WeightEquip", "Shop_Buy",
	-- WheelSpinServiceClient
	"RequestSpin", "SpinWheel", "UpdateSpins",
	-- Plot interaction (PlotService also creates these, idempotent)
	"S_Interact", "B_Collect", "B_Upgrade", "S_Steal", "LB_OpenRequest",
	-- Tsunami / wave hit replication (client -> server kill)
	"TsunamiHit",
	"OpenSpeedDialogue",
}

for _, key in ipairs(CLIENT_EXPECTED_KEYS) do
	Network.CreateRemote(key)
end

-- â”€â”€â”€ Tunables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local STARTING_BALANCE = 100
local SPEED_BASE = 13
local SPEED_INCR = 1
local SPEED_FREE_LEVELS = 4
local SPEED_BASE_COST = 50
local SPEED_COST_GROWTH = 1.465

local KICK_BASE_COST = 50
local KICK_COST_GROWTH = 1.2
local KICK_MAX_LEVEL = 75

local BONUS_TICK_SECONDS = 12
local BONUS_LEVELS = { 2, 5, 10 }
local BONUS_REWARD = { [2] = 25, [5] = 80, [10] = 200 }

-- â”€â”€â”€ In-memory player state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
type PlayerState = {
	Balance: number,
	SpeedLevel: number,
	KickLevel: number,
	KickXP: number,
	Rebirths: number,
	Spins: number,
	AddedSlots: number,
	TutorialStep: number,
	DiscoveredItems: {[string]: {string}},
	WeightEquipped: string,
	WeightOwned: {string},
}

local state: {[Player]: PlayerState} = {}

local function newState(): PlayerState
	return {
		Balance = STARTING_BALANCE,
		SpeedLevel = 0,
		KickLevel = 1,
		KickXP = 0,
		Rebirths = 0,
		Spins = 0,
		AddedSlots = 0,
		TutorialStep = 1,  -- FIX: commence Ã  1 et non 0
		DiscoveredItems = {},
		WeightEquipped = "Wooden Stick",
		WeightOwned = { "Wooden Stick" },
	}
end

local function getState(player: Player): PlayerState?
	return state[player]
end

-- â”€â”€â”€ Pushers (server â†’ client) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function pushBalance(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "CoinsChanged", s.Balance)
	Network.FireClient(player, "CoinsMulti", 1, nil)
end

local function pushKick(player: Player)
	local s = state[player]; if not s then return end
	print(("[GameServiceHub] pushKick %s level=%d xp=%d"):format(player.Name, s.KickLevel, s.KickXP))
	Network.FireClient(player, "KickData", s.KickLevel, s.KickXP)
	Network.FireClient(player, "KickMulti", 1, nil)
end

local function pushRebirth(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "RebirthUpdate", s.Rebirths)
end

local function pushSlots(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "bs_updateClient", s.AddedSlots)
end

local function pushSpeed(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "SPEED_UPDATE", s.SpeedLevel)
	Network.FireClient(player, "SPEED_MULTIPLIER", 1, nil)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = SPEED_BASE + SPEED_INCR * s.SpeedLevel
	end
end

local function pushWeight(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "Weight_Update", s.WeightEquipped, s.WeightOwned)
	Network.FireClient(player, "Weight_Multi", { Speed = 1, Weight = 1 }, {})
end

local function pushSpins(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "UpdateSpins", s.Spins)
end

local function pushFriends(player: Player)
	Network.FireClient(player, "FriendsUPD", {}, 1)
end

local function pushIndex(player: Player)
	local s = state[player]; if not s then return end
	Network.FireClient(player, "IndexUpdate", s.DiscoveredItems)
end

local function pushTimed(player: Player)
	Network.FireClient(player, "TimedUpdate", {})
end

local function pushLeaderboard(player: Player)
	Network.FireClient(player, "LeaderboardUPD", {})
end

local function pushMarketplace(player: Player)
	Network.FireClient(player, "myMarket_data", {}, {})
	Network.FireClient(player, "myMarket_stock", {})
end

local function pushServerLuck(player: Player)
	Network.FireClient(player, "sl_upd", 1, nil, 1, nil)
end

local function pushWeather(player: Player)
	Network.FireClient(player, "WeatherUpdate", {})
end

local function pushAll(player: Player)
	pushBalance(player); pushKick(player); pushRebirth(player); pushSlots(player)
	pushSpeed(player); pushWeight(player); pushSpins(player); pushFriends(player)
	pushIndex(player); pushTimed(player); pushLeaderboard(player); pushMarketplace(player)
	pushServerLuck(player); pushWeather(player)
end

-- â”€â”€â”€ Handlers (client â†’ server) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Network.OnServerEvent("SPEED_UPGRADE"):Connect(function(player, amount)
	local s = state[player]; if not s then return end
	if typeof(amount) ~= "number" or amount < 1 then
		amount = 1
	end
	local startLevel = s.SpeedLevel
	local targetLevel = s.SpeedLevel + math.floor(amount)
	while s.SpeedLevel < targetLevel do
		local nextLevel = s.SpeedLevel + 1
		local cost
		if nextLevel <= SPEED_FREE_LEVELS then
			cost = 0
		else
			local t = nextLevel - SPEED_FREE_LEVELS
			cost = math.floor(SPEED_BASE_COST * SPEED_COST_GROWTH ^ (t - 1))
		end
		if s.Balance < cost then break end
		s.Balance -= cost
		s.SpeedLevel = nextLevel
	end
	pushBalance(player)
	pushSpeed(player)
	local gained = s.SpeedLevel - startLevel
	if gained > 0 then
		Network.FireClient(player, "NotificationUpdate", "Speed", gained)
	end
end)

local PRODUCT_TO_WEIGHT: {[number]: string} = {}
for name, data in pairs(WeightsData.Weights) do
	if data.Product then
		PRODUCT_TO_WEIGHT[data.Product] = name
	end
end

local function ownsWeight(s: PlayerState, name: string): boolean
	for _, n in ipairs(s.WeightOwned) do
		if n == name then return true end
	end
	return false
end

local WeightModelsFolder = ReplicatedStorage:FindFirstChild("Weights")
	or ReplicatedStorage:FindFirstChild("Objects") and ReplicatedStorage.Objects:FindFirstChild("WeightModels")

local BACK_OFFSET_Y = 1.0
local BACK_OFFSET_Z_FACTOR = 0.5

local function attachWeightToBack(character: Model, weightName: string): Model?
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then return nil end
	local weightModel = WeightModelsFolder and WeightModelsFolder:FindFirstChild(weightName)
	if not weightModel then return nil end

	local clone = weightModel:Clone()
	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
	if not primary then clone:Destroy(); return nil end

	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			if p ~= primary then
				local internalWeld = Instance.new("WeldConstraint")
				internalWeld.Part0 = primary
				internalWeld.Part1 = p
				internalWeld.Parent = p
			end
		end
	end

	local offset = CFrame.new(0, BACK_OFFSET_Y, torso.Size.Z * BACK_OFFSET_Z_FACTOR)
		* CFrame.Angles(0, math.rad(90), 0)
	clone:PivotTo(torso.CFrame * offset)
	clone.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = primary
	weld.Parent = primary

	return clone
end

local function createWeightTool(weightName: string): Tool?
	local data = WeightsData.Weights[weightName]
	if not data then return nil end

	local tool = Instance.new("Tool")
	tool.Name = weightName
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.TextureId = data.Image or ""
	tool.ToolTip = weightName
	tool:AddTag("SquatTool")

	local clonedWeight: Model? = nil

	tool.Equipped:Connect(function()
		local character = tool.Parent
		if not character or not character:IsA("Model") then return end
		if clonedWeight and clonedWeight.Parent then
			clonedWeight:Destroy()
		end
		clonedWeight = attachWeightToBack(character, weightName)
	end)

	tool.Unequipped:Connect(function()
		if clonedWeight then
			clonedWeight:Destroy()
			clonedWeight = nil
		end
	end)

	tool.AncestryChanged:Connect(function()
		if not tool:IsDescendantOf(game) and clonedWeight then
			clonedWeight:Destroy()
			clonedWeight = nil
		end
	end)

	return tool
end

local function clearSquatTools(container: Instance?)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:HasTag("SquatTool") then
			child:Destroy()
		end
	end
end

local function applyEquippedWeight(player: Player)
	local s = state[player]; if not s then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	clearSquatTools(backpack)
	clearSquatTools(player.Character)
	local tool = createWeightTool(s.WeightEquipped)
	if tool then
		tool.Parent = backpack
	end
end

local function grantWeight(player: Player, name: string)
	local s = state[player]; if not s then return end
	if not WeightsData.Weights[name] then return end
	if not ownsWeight(s, name) then
		table.insert(s.WeightOwned, name)
	end
	s.WeightEquipped = name
	pushWeight(player)
	applyEquippedWeight(player)
end

Network.OnServerEvent("Shop_Buy"):Connect(function(player, shopName, itemName)
	local s = state[player]; if not s then return end
	if shopName ~= "WeightShop" then return end
	if typeof(itemName) ~= "string" then return end
	local data = WeightsData.Weights[itemName]
	if not data then return end
	if ownsWeight(s, itemName) then return end
	local cost = tonumber(data.Cost) or 0
	if s.Balance < cost then return end
	s.Balance -= cost
	table.insert(s.WeightOwned, itemName)
	s.WeightEquipped = itemName
	pushBalance(player)
	pushWeight(player)
	applyEquippedWeight(player)
end)

Network.OnServerEvent("WeightEquip"):Connect(function(player, itemName)
	local s = state[player]; if not s then return end
	if typeof(itemName) ~= "string" then return end
	if not ownsWeight(s, itemName) then return end
	s.WeightEquipped = itemName
	pushWeight(player)
	applyEquippedWeight(player)
end)

-- ProcessReceipt retirÃ© â€” gÃ©rÃ© par MarketplaceHandler (ServerScriptService)

Network.OnServerEvent("KICK_UPGRADE"):Connect(function(player, amount)
	local s = state[player]; if not s then return end
	if typeof(amount) ~= "number" or amount < 1 then
		amount = 1
	end
	local targetLevel = math.min(s.KickLevel + math.floor(amount), KICK_MAX_LEVEL)
	while s.KickLevel < targetLevel do
		local nextLevel = s.KickLevel + 1
		local cost = math.floor(KICK_BASE_COST * KICK_COST_GROWTH ^ (nextLevel - 1))
		if s.Balance < cost then break end
		s.Balance -= cost
		s.KickLevel = nextLevel
	end
	pushBalance(player)
	pushKick(player)
end)

Network.OnServerEvent("TaviMishkal"):Connect(function(player)
	local s = state[player]; if not s then return end
	local pending = s._PendingBonus
	if not pending then return end
	s._PendingBonus = nil
	s.Balance += pending.reward
	pushBalance(player)
end)

-- â”€â”€â”€ Sell brainrots (Timmy NPC) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Network.CreateRemoteFunction("B_SellAll")
Network.CreateRemoteFunction("B_Sell")

local function brainrotSellPrice(name, player)
	local entityData = require(ReplicatedStorage.Shared.Data.EntitiesData).Brainrots[name]
	if not entityData then return 0 end
	local base = (tonumber(entityData.CPS) or 0) * 10
	local rebirthLevel = (player and state[player] and state[player].Rebirths) or 0
	return math.floor(base * (1 + rebirthLevel))
end

Network.OnServerInvoke("B_SellAll", function(player)
	local s = state[player]
	if not s then return false end
	local total = 0
	local function sellTools(container)
		if not container then return end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and tool:HasTag("EntityTool") then
				local price = brainrotSellPrice(tool.Name, player)
				total += price
				local uid = tool:GetAttribute("UID")
				if uid and _G.ItemManagerAPI then
					_G.ItemManagerAPI.Remove(player, uid)
				else
					tool:Destroy()
				end
			end
		end
	end
	sellTools(player:FindFirstChildOfClass("Backpack"))
	sellTools(player.Character)
	if total > 0 then
		s.Balance += total
		pushBalance(player)
		return total
	end
	return false
end)

Network.OnServerInvoke("B_Sell", function(player)
	local s = state[player]
	if not s then return false end
	local heldTool
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if container then
			for _, c in ipairs(container:GetChildren()) do
				if c:IsA("Tool") and c:HasTag("EntityTool") then
					heldTool = c
					break
				end
			end
		end
		if heldTool then break end
	end
	if not heldTool then return false end
	local price = brainrotSellPrice(heldTool.Name, player)
	if price <= 0 then return false end
	local uid = heldTool:GetAttribute("UID")
	if uid and _G.ItemManagerAPI then
		_G.ItemManagerAPI.Remove(player, uid)
	else
		heldTool:Destroy()
	end
	s.Balance += price
	pushBalance(player)
	return price
end)

Network.OnServerEvent("TsunamiHit"):Connect(function(player)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end)

Network.OnServerEvent("RebirthRequest"):Connect(function(player)
	local s = state[player]; if not s then return end
	s.Rebirths += 1
	s.Balance = STARTING_BALANCE
	s.SpeedLevel = 0
	pushAll(player)
	if _G.PlotAPI and _G.PlotAPI.UpdateCashMultiplier then
		_G.PlotAPI.UpdateCashMultiplier(player, s.Rebirths)
	end
end)

local MAX_ADDED_SLOTS = 20
Network.OnServerEvent("bs_upgrade"):Connect(function(player)
	local s = state[player]; if not s then return end
	if s.AddedSlots >= MAX_ADDED_SLOTS then return end
	s.AddedSlots += 1
	if _G.PlotAPI then
		_G.PlotAPI.AddSlot(player)
	end
	pushSlots(player)
end)

Network.OnServerEvent("CheckFriend"):Connect(function(player)
	pushFriends(player)
end)

-- FIX: mise Ã  jour de l'attribut TutorialStep pour que le client le dÃ©tecte
Network.OnServerEvent("TutorialStep"):Connect(function(player, step)
	local s = state[player]; if not s then return end
	if typeof(step) == "number" then
		s.TutorialStep = math.max(0, math.floor(step))
		player:SetAttribute("TutorialStep", s.TutorialStep)
	end
end)

Network.OnServerEvent("RequestSpin"):Connect(function(player)
	local s = state[player]; if not s then return end
	if s.Spins <= 0 then return end
	s.Spins -= 1
	pushSpins(player)
	Network.FireClient(player, "SpinWheel", "Common", 0)
end)

-- â”€â”€â”€ Player lifecycle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local function onPlayerAdded(player: Player)
	local profile = nil
	if _G.DataAPI then
		profile = _G.DataAPI.WaitForProfile(player, 30)
	end
	if profile then
		state[player] = profile.Data
	else
		warn("[GameServiceHub] No profile for " .. player.Name .. " â€” falling back to in-memory state (changes will not save)")
		state[player] = newState()
	end

	-- FIX: set l'attribut TutorialStep dÃ¨s que le profil est chargÃ©
	local tutorialStep = state[player].TutorialStep or 1
	if tutorialStep < 1 then tutorialStep = 1 end
	player:SetAttribute("TutorialStep", tutorialStep)

	local hasRestoredInventory = false
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local s = state[player]
			local level = (s and s.SpeedLevel) or 0
			hum.WalkSpeed = SPEED_BASE + SPEED_INCR * level
		end
		applyEquippedWeight(player)
		if not hasRestoredInventory and _G.ItemManagerAPI and _G.ItemManagerAPI.RestoreInventory then
			hasRestoredInventory = true
			_G.ItemManagerAPI.RestoreInventory(player)
		end
	end)

	task.delay(3, function()
		if player.Parent and state[player] then
			pushAll(player)
			applyEquippedWeight(player)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	state[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- â”€â”€â”€ Training loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
local TRAINING_TICK = 1
task.spawn(function()
	while true do
		task.wait(TRAINING_TICK)
		for player, s in pairs(state) do
			local char = player.Character
			if char then
				local tool
				for _, c in ipairs(char:GetChildren()) do
					if c:IsA("Tool") and c:HasTag("SquatTool") then
						tool = c; break
					end
				end
				if tool then
					local wd = WeightsData.Weights[tool.Name]
					local pps = (wd and tonumber(wd.PPS)) or 1
					if pps > 0 then
						s.KickLevel = math.floor(s.KickLevel + pps)
						pushKick(player)
					end
				end
			end
		end
	end
end)

-- â”€â”€â”€ Bonus button loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
task.spawn(function()
	while true do
		task.wait(BONUS_TICK_SECONDS + math.random() * 4 - 2)
		for player, s in pairs(state) do
			if player.Parent then
				local level = BONUS_LEVELS[math.random(1, #BONUS_LEVELS)]
				s._PendingBonus = { level = level, reward = BONUS_REWARD[level] or 25 }
				Network.FireClient(player, "TaviMishkal", level)
			end
		end
	end
end)

-- â”€â”€â”€ Global API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
_G.GameStateAPI = {
	GetBalance = function(player)
		local s = state[player]
		return s and s.Balance or 0
	end,
	AddBalance = function(player, amount)
		local s = state[player]; if not s then return false end
		s.Balance += amount
		pushBalance(player)
		return true
	end,
	SetBalance = function(player, amount)
		local s = state[player]; if not s then return false end
		s.Balance = math.max(0, math.floor(tonumber(amount) or 0))
		pushBalance(player)
		return true
	end,
	Spend = function(player, amount)
		local s = state[player]; if not s then return false end
		if s.Balance < amount then return false end
		s.Balance -= amount
		pushBalance(player)
		return true
	end,
	GetKickLevel = function(player)
		local s = state[player]
		return s and s.KickLevel or 1
	end,
	SetKickLevel = function(player, level)
		local s = state[player]; if not s then return false end
		s.KickLevel = math.max(1, math.floor(tonumber(level) or 1))
		pushKick(player)
		return true
	end,
	AddKickLevel = function(player, delta)
		local s = state[player]; if not s then return false end
		s.KickLevel = math.max(1, s.KickLevel + math.floor(tonumber(delta) or 0))
		pushKick(player)
		return true
	end,
	GetSpeedLevel = function(player)
		local s = state[player]
		return s and s.SpeedLevel or 0
	end,
	SetSpeedLevel = function(player, level)
		local s = state[player]; if not s then return false end
		s.SpeedLevel = math.max(0, math.floor(tonumber(level) or 0))
		pushSpeed(player)
		return true
	end,
	AddSpeedLevel = function(player, delta)
		local s = state[player]; if not s then return false end
		s.SpeedLevel = math.max(0, s.SpeedLevel + math.floor(tonumber(delta) or 0))
		pushSpeed(player)
		return true
	end,
	GetRebirths = function(player)
		local s = state[player]
		return s and s.Rebirths or 0
	end,
	MarkDiscovered = function(player, brainrotName, mutation)
		local s = state[player]; if not s then return false end
		if typeof(brainrotName) ~= "string" or brainrotName == "" then return false end
		if not mutation or mutation == "" or mutation == "Normal" then
			mutation = "None"
		end
		s.DiscoveredItems[mutation] = s.DiscoveredItems[mutation] or {}
		for _, n in ipairs(s.DiscoveredItems[mutation]) do
			if n == brainrotName then return true end
		end
		table.insert(s.DiscoveredItems[mutation], brainrotName)
		Network.FireClient(player, "IndexUpdate", brainrotName, mutation)
		return true
	end,
	SetRebirths = function(player, n)
		local s = state[player]; if not s then return false end
		s.Rebirths = math.max(0, math.floor(tonumber(n) or 0))
		pushRebirth(player)
		if _G.PlotAPI and _G.PlotAPI.UpdateCashMultiplier then
			_G.PlotAPI.UpdateCashMultiplier(player, s.Rebirths)
		end
		return true
	end,
	AddRebirths = function(player, delta)
		local s = state[player]; if not s then return false end
		s.Rebirths = math.max(0, s.Rebirths + math.floor(tonumber(delta) or 0))
		pushRebirth(player)
		if _G.PlotAPI and _G.PlotAPI.UpdateCashMultiplier then
			_G.PlotAPI.UpdateCashMultiplier(player, s.Rebirths)
		end
		return true
	end,
}

print(("[GameServiceHub] Initialized â€” pre-created %d RemoteEvents"):format(#CLIENT_EXPECTED_KEYS))