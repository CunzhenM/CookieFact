local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Network = require(ReplicatedStorage.Shared.Packages.Network)
local Tags = require(ReplicatedStorage.Shared.Data.Tags)
local EntitiesData = require(ReplicatedStorage.Shared.Data.EntitiesData)

local PlotsFolder = Workspace:WaitForChild("Plots")

Players.RespawnTime = 0.5

local PLOT_NAMES = {"Plot1", "Plot2", "Plot3", "Plot4", "Plot5"}
local MAX_PLOTS = #PLOT_NAMES
local COIN_TICK = 1
local AUTO_PLACE_BRAINROT = ""
local AUTO_PLACE_SLOT = 1
local AUTO_PLACE_LUCKYBLOCK = ""
local AUTO_PLACE_LUCKYBLOCK_SLOT = 2

local PlayersFolder = Workspace:FindFirstChild("Players")
if not PlayersFolder then
	PlayersFolder = Instance.new("Folder")
	PlayersFolder.Name = "Players"
	PlayersFolder.Parent = Workspace
end

-- ───────────────── Plot allocation ─────────────────

local plotByPlayer: {[Player]: Model} = {}
local playerByPlot: {[string]: Player} = {}

local function findFreePlot(): Model?
	for _, name in ipairs(PLOT_NAMES) do
		if not playerByPlot[name] then
			local plot = PlotsFolder:FindFirstChild(name)
			if plot and plot:IsA("Model") then
				return plot
			end
		end
	end
	return nil
end

-- ───────────────── Placement ─────────────────

local function clearSlot(plot: Model, slotNum: number)
	local slotsFolder = plot:FindFirstChild("Slots")
	if not slotsFolder then return end
	local slot = slotsFolder:FindFirstChild("Slot" .. slotNum)
	if not slot then return end
	for _, child in ipairs(slot:GetChildren()) do
		if CollectionService:HasTag(child, Tags.PlacedPart) then
			child:Destroy()
		end
	end
end

local function placeBrainrot(plot: Model, slotNum: number, name: string, level: number?, mutation: string?)
	local data = EntitiesData.Brainrots[name] or EntitiesData.LuckyBlocks[name]
	if not data then
		warn(("[PlotService] Unknown brainrot/luckyblock: %s"):format(name))
		return nil
	end
	local slotsFolder = plot:FindFirstChild("Slots")
	local slot = slotsFolder and slotsFolder:FindFirstChild("Slot" .. slotNum)
	if not slot or not slot:IsA("BasePart") then
		warn(("[PlotService] Slot%d not found in %s"):format(slotNum, plot.Name))
		return nil
	end
	clearSlot(plot, slotNum)

	local part = Instance.new("Part")
	part.Name = "PlacedPart"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = slot.CFrame
	part:SetAttribute("ID", name)
	part:SetAttribute("Level", level or 1)
	part:SetAttribute("Coins", 0)
	part:SetAttribute("OfflineCoins", 0)
	if mutation then
		part:SetAttribute("Mutation", mutation)
	end
	CollectionService:AddTag(part, Tags.PlacedPart)
	part.Parent = slot
	return part
end

-- ───────────────── Coin generation loop ─────────────────

local function tickCoins()
	for player, plot in pairs(plotByPlayer) do
		local rebirthLevel = (_G.GameStateAPI and _G.GameStateAPI.GetRebirths and _G.GameStateAPI.GetRebirths(player)) or 0
		local rebirthMult = 1 + rebirthLevel
		local slotsFolder = plot:FindFirstChild("Slots")
		if slotsFolder then
			for _, slot in ipairs(slotsFolder:GetChildren()) do
				for _, part in ipairs(slot:GetChildren()) do
					if part:IsA("BasePart") and CollectionService:HasTag(part, Tags.PlacedPart) then
						local id = part:GetAttribute("ID")
						local level = part:GetAttribute("Level") or 1
						local data = id and EntitiesData.Brainrots[id]
						if data and data.CPS then
							local mult = EntitiesData.GetMultiplierPerLevel(level)
							local cps = data.CPS * mult * rebirthMult * COIN_TICK
							local current = part:GetAttribute("Coins") or 0
							part:SetAttribute("Coins", current + cps)
						end
					end
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(COIN_TICK)
		local ok, err = pcall(tickCoins)
		if not ok then
			warn("[PlotService] tickCoins error:", err)
		end
	end
end)

-- ───────────────── Rebirth cash multiplier ─────────────────

local REBIRTH_BASE_MULTIPLIER = 1
local REBIRTH_MULTIPLIER_INCREMENT = 1
local function rebirthMultiplierForLevel(level: number)
	return REBIRTH_BASE_MULTIPLIER + REBIRTH_MULTIPLIER_INCREMENT * (level or 0)
end

local function updateCashMultiplierLabel(plot: Model, level: number)
	local deco = plot:FindFirstChild("Decorations")
	local cm = deco and deco:FindFirstChild("CashMultiplier")
	local sg = cm and cm:FindFirstChildOfClass("SurfaceGui")
	local label = sg and sg:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = ("x%d Multi"):format(rebirthMultiplierForLevel(level))
	end
end

-- ───────────────── Dynamic slot expansion (BaseUpgrades) ─────────────────

local ServerStorage = game:GetService("ServerStorage")
local TEMPLATE = ServerStorage:FindFirstChild("Plot2")

local function spawnFromTemplate(plot: Model, folderName: string, slotIdx: number)
	if not TEMPLATE then
		warn("[PlotService] ServerStorage.Plot2 template missing — cannot expand slots")
		return nil
	end
	local templateFolder = TEMPLATE:FindFirstChild(folderName)
	local plotFolder = plot:FindFirstChild(folderName)
	if not templateFolder or not plotFolder then return nil end
	if plotFolder:FindFirstChild("Slot" .. slotIdx) then return nil end

	local source = templateFolder:FindFirstChild("Slot" .. slotIdx)
	if not source or not source:IsA("BasePart") then return nil end

	local templateCF = TEMPLATE:GetPivot()
	local plotCF = plot:GetPivot()
	local localCF = templateCF:ToObjectSpace(source.CFrame)
	local worldCF = plotCF:ToWorldSpace(localCF)

	local clone = source:Clone()
	clone.CFrame = worldCF
	clone.Parent = plotFolder
	return clone
end

local function ensureFloor(plot: Model, floorName: string)
	if not TEMPLATE then return nil end
	local plotFloors = plot:FindFirstChild("Floors")
	if not plotFloors then
		plotFloors = Instance.new("Folder")
		plotFloors.Name = "Floors"
		plotFloors.Parent = plot
	end
	if plotFloors:FindFirstChild(floorName) then return nil end

	local templateFloors = TEMPLATE:FindFirstChild("Floors")
	local source = templateFloors and templateFloors:FindFirstChild(floorName)
	if not source then return nil end

	local templateCF = TEMPLATE:GetPivot()
	local plotCF = plot:GetPivot()
	local localCF = templateCF:ToObjectSpace(source:GetPivot())
	local worldCF = plotCF:ToWorldSpace(localCF)

	local clone = source:Clone()
	clone:PivotTo(worldCF)
	clone.Parent = plotFloors
	return clone
end

local function spawnSlot(plot: Model, slotIdx: number)
	local s1 = spawnFromTemplate(plot, "Slots", slotIdx)
	spawnFromTemplate(plot, "Buttons", slotIdx)
	if slotIdx == 11 then
		ensureFloor(plot, "Floor1")
	elseif slotIdx == 21 then
		ensureFloor(plot, "Floor2")
	end
	return s1
end

-- ───────────────── Plot lifecycle ─────────────────

local function releasePlot(player: Player)
	local plot = plotByPlayer[player]
	if plot then
		plot:SetAttribute("Owner", nil)
		plot:SetAttribute("OwnerUserId", nil)
		local slotsFolder = plot:FindFirstChild("Slots")
		if slotsFolder then
			for _, slot in ipairs(slotsFolder:GetChildren()) do
				for _, child in ipairs(slot:GetChildren()) do
					if CollectionService:HasTag(child, Tags.PlacedPart) then
						child:Destroy()
					end
				end
			end
		end
		playerByPlot[plot.Name] = nil
		plotByPlayer[player] = nil
	end
end

local function teleportToSpawn(player: Player, char: Model)
	local plot = plotByPlayer[player]
	if not plot or not plot.Parent then return end
	local spawnPart = plot:FindFirstChild("SpawnPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then return end
	local hrp = char:WaitForChild("HumanoidRootPart", 5)
	if not hrp then return end
	char:PivotTo(spawnPart.CFrame * CFrame.new(0, 5, 0))
end

local function reparentCharacter(char: Model)
	if char.Parent ~= PlayersFolder then
		char.Parent = PlayersFolder
	end
end

local function assignPlot(player: Player): Model?
	releasePlot(player)

	local plot = findFreePlot()
	if not plot then
		warn(("[PlotService] No free plot for %s (%d/%d in use)"):format(player.Name, MAX_PLOTS, MAX_PLOTS))
		return nil
	end

	plot:SetAttribute("Owner", player.DisplayName)
	plot:SetAttribute("OwnerUserId", player.UserId)

	local currentRebirth = (_G.GameStateAPI and _G.GameStateAPI.GetRebirths and _G.GameStateAPI.GetRebirths(player)) or 0
	updateCashMultiplierLabel(plot, currentRebirth)

	local plotOwnerPart = plot:FindFirstChild("Decorations") and plot.Decorations:FindFirstChild("PlotOwner")
	if plotOwnerPart and not CollectionService:HasTag(plotOwnerPart, Tags.PlotOwnerPart) then
		CollectionService:AddTag(plotOwnerPart, Tags.PlotOwnerPart)
	end

	plotByPlayer[player] = plot
	playerByPlot[plot.Name] = player

	task.defer(function()
		if player.Parent and plot.Parent then
			Network.FireClient(player, "PlotAdded", plot.Name)
		end
	end)

	if player.Character then
		task.spawn(teleportToSpawn, player, player.Character)
	end

	print(("[PlotService] Assigned %s to %s"):format(plot.Name, player.Name))
	return plot
end

-- ─── Sauvegarde PlacedBrainrots dans le profil ───────────────────────────────

local function savePlacedBrainrot(player: Player, slotNumber: number, id: string?, level: number?, mutation: string?)
	local profile = _G.DataAPI and _G.DataAPI.GetProfile(player)
	if not profile then return end
	if not profile.Data.PlacedBrainrots then
		profile.Data.PlacedBrainrots = {}
	end
	if id then
		profile.Data.PlacedBrainrots[tostring(slotNumber)] = {
			id = id,
			level = level or 1,
			mutation = mutation,
		}
	else
		profile.Data.PlacedBrainrots[tostring(slotNumber)] = nil
	end
end

-- ───────────────── Network events ─────────────────

Network.CreateRemote("PlotAdded")
Network.CreateRemote("S_Interact")
Network.CreateRemote("B_Collect")
Network.CreateRemote("B_Upgrade")
Network.CreateRemote("S_Steal")
Network.CreateRemote("LB_OpenRequest")

local function findPlacedPart(plot: Model, slotNum: number): BasePart?
	local slotsFolder = plot:FindFirstChild("Slots")
	if not slotsFolder then return nil end
	local slot = slotsFolder:FindFirstChild("Slot" .. slotNum)
	if not slot then return nil end
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("BasePart") and CollectionService:HasTag(child, Tags.PlacedPart) then
			return child
		end
	end
	return nil
end

Network.OnServerEvent("S_Interact"):Connect(function(player, slotNumber)
	if typeof(slotNumber) ~= "number" then return end
	local plot = plotByPlayer[player]; if not plot then return end
	local existing = findPlacedPart(plot, slotNumber)

	if existing then
		-- PICKUP
		local id = existing:GetAttribute("ID")
		local mutation = existing:GetAttribute("Mutation")
		local level = existing:GetAttribute("Level") or 1
		local rarity = existing:GetAttribute("Rarity")
		local coins = existing:GetAttribute("Coins") or 0
		if coins > 0 and _G.GameStateAPI then
			_G.GameStateAPI.AddBalance(player, math.floor(coins))
		end
		existing:Destroy()
		-- FIX: Supprimer du profil
		savePlacedBrainrot(player, slotNumber, nil)
		if id and _G.ItemManagerAPI then
			_G.ItemManagerAPI.Give(player, id, mutation, rarity, level, false)
		end
		return
	end

	-- PLACE
	if not player.Character then return end
	local heldTool
	for _, c in ipairs(player.Character:GetChildren()) do
		if c:IsA("Tool") and c:HasTag("EntityTool") then
			heldTool = c; break
		end
	end
	if not heldTool then return end

	local id = heldTool.Name
	local mutation = heldTool:GetAttribute("Mutation")
	local level = heldTool:GetAttribute("Level") or 1
	local placed = placeBrainrot(plot, slotNumber, id, level, mutation)
	if placed then
		local rarity = heldTool:GetAttribute("Rarity")
		if rarity then placed:SetAttribute("Rarity", rarity) end
		-- FIX: Sauvegarder dans le profil
		savePlacedBrainrot(player, slotNumber, id, level, mutation)
		local uid = heldTool:GetAttribute("UID")
		if uid and _G.ItemManagerAPI then
			_G.ItemManagerAPI.Remove(player, uid)
		else
			heldTool:Destroy()
		end
	end
end)

Network.OnServerEvent("B_Collect"):Connect(function(player, slotNumber)
	if typeof(slotNumber) ~= "number" then return end
	local plot = plotByPlayer[player]; if not plot then return end
	local part = findPlacedPart(plot, slotNumber); if not part then return end
	local coins = part:GetAttribute("Coins") or 0
	if coins <= 0 then return end
	if _G.GameStateAPI and _G.GameStateAPI.AddBalance(player, math.floor(coins)) then
		part:SetAttribute("Coins", 0)
		part:SetAttribute("OfflineCoins", 0)
		part:SetAttribute("lastCollect", tick())
	end
end)

Network.OnServerEvent("B_Upgrade"):Connect(function(player, slotNumber)
	if typeof(slotNumber) ~= "number" then return end
	local plot = plotByPlayer[player]; if not plot then return end
	local part = findPlacedPart(plot, slotNumber); if not part then return end
	local id = part:GetAttribute("ID")
	local level = part:GetAttribute("Level") or 1
	local data = id and EntitiesData.Brainrots[id]
	if not data then return end
	if level >= EntitiesData.MAX_LEVEL then return end
	local mutation = part:GetAttribute("Mutation")
	local cost = EntitiesData.GetCostForUpgrade(id, level, mutation)
	if not cost or cost <= 0 then return end
	if _G.GameStateAPI and _G.GameStateAPI.Spend(player, cost) then
		local newLevel = level + 1
		part:SetAttribute("Level", newLevel)
		-- FIX: Mettre à jour le niveau dans le profil
		savePlacedBrainrot(player, slotNumber, id, newLevel, mutation)
	end
end)

Network.OnServerEvent("S_Steal"):Connect(function(player, target)
	if typeof(target) ~= "Instance" then return end
	warn(("[PlotService] S_Steal from %s on %s (no steal system wired)"):format(player.Name, target:GetFullName()))
end)

local function rollLuckyBlock(lbId: string): string?
	local lb = EntitiesData.LuckyBlocks[lbId]
	if not lb or not lb.Pool then return nil end
	local total = 0
	for _, entry in ipairs(lb.Pool) do
		total += entry.Chance
	end
	local r = math.random() * total
	local acc = 0
	for _, entry in ipairs(lb.Pool) do
		acc += entry.Chance
		if r <= acc then return entry.Name end
	end
	return lb.Pool[#lb.Pool].Name
end

local lbCooldowns: {[Player]: number} = {}

Network.OnServerEvent("LB_OpenRequest"):Connect(function(player, slotNumber)
	if typeof(slotNumber) ~= "number" then return end
	local plot = plotByPlayer[player]; if not plot then return end
	local now = os.clock()
	if (lbCooldowns[player] or 0) > now then return end
	lbCooldowns[player] = now + 5

	local part = findPlacedPart(plot, slotNumber)
	if not part then return end
	local lbId = part:GetAttribute("ID")
	if not lbId or EntitiesData.GetTypeFromName(lbId) ~= "LuckyBlock" then return end

	local rolled = rollLuckyBlock(lbId)
	if not rolled then return end

	local point = part.CFrame
	Network.FireClient(player, "VFX_UPD", "OpenLuckyBlock", lbId, point, { Name = rolled, Mutation = nil })

	task.delay(4, function()
		if not plotByPlayer[player] or plotByPlayer[player] ~= plot then return end
		if part.Parent then
			placeBrainrot(plot, slotNumber, rolled, 1)
			-- FIX: Sauvegarder le brainrot rolled dans le profil
			savePlacedBrainrot(player, slotNumber, rolled, 1, nil)
		end
	end)
end)

-- ───────────────── Player lifecycle (FIX PRINCIPAL) ─────────────────

local function onPlayerAdded(player: Player)
	-- FIX: Attendre que le profil DataStore soit prêt avant de construire la base
	local profile = _G.DataAPI and _G.DataAPI.WaitForProfile(player, 30)

	if not profile then
		warn(("[PlotService] Profile never arrived for %s — building empty plot"):format(player.Name))
	end

	local plot = assignPlot(player)

	if plot and profile then
		local data = profile.Data

		-- FIX: Restaurer les slots/étages supplémentaires (AddedSlots)
		local addedSlots = data.AddedSlots or 0
		if addedSlots > 0 then
			local slotsFolder = plot:FindFirstChild("Slots")
			local baseCount = slotsFolder and #slotsFolder:GetChildren() or 10
			for i = 1, addedSlots do
				spawnSlot(plot, baseCount + i)
			end
			print(("[PlotService] Restored %d extra slot(s) for %s"):format(addedSlots, player.Name))
		end

		-- FIX: Restaurer les brainrots placés (PlacedBrainrots)
		local placed = data.PlacedBrainrots or {}
		local restoredCount = 0
		for slotKey, info in pairs(placed) do
			if info and info.id then
				local slotNum = tonumber(slotKey)
				if slotNum then
					placeBrainrot(plot, slotNum, info.id, info.level or 1, info.mutation)
					restoredCount += 1
				end
			end
		end
		if restoredCount > 0 then
			print(("[PlotService] Restored %d placed brainrot(s) for %s"):format(restoredCount, player.Name))
		end
	end

	-- Auto-place seulement si le plot est vide (nouveau joueur)
	if plot and profile then
		local placed = profile.Data.PlacedBrainrots or {}
		local isEmpty = next(placed) == nil
		if isEmpty then
			task.delay(0.5, function()
				if plotByPlayer[player] ~= plot then return end
				if AUTO_PLACE_BRAINROT ~= "" then
					placeBrainrot(plot, AUTO_PLACE_SLOT, AUTO_PLACE_BRAINROT, 1)
				end
				if AUTO_PLACE_LUCKYBLOCK ~= "" then
					placeBrainrot(plot, AUTO_PLACE_LUCKYBLOCK_SLOT, AUTO_PLACE_LUCKYBLOCK, 1)
				end
			end)
		end
	end

	if player.Character then
		reparentCharacter(player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		reparentCharacter(char)
		task.spawn(teleportToSpawn, player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(releasePlot)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ───────────────── PlotAPI ─────────────────

_G.PlotAPI = {
	AddSlot = function(player: Player)
		local plot = plotByPlayer[player]
		if not plot then return false end
		local slotsFolder = plot:FindFirstChild("Slots")
		if not slotsFolder then return false end
		local count = 0
		for _, c in ipairs(slotsFolder:GetChildren()) do
			if c.Name:match("^Slot%d+$") then count += 1 end
		end
		return spawnSlot(plot, count + 1) ~= nil
	end,
	UpdateCashMultiplier = function(player: Player, level: number)
		local plot = plotByPlayer[player]
		if not plot then return false end
		updateCashMultiplierLabel(plot, level or 0)
		return true
	end,
}

_G.PlotPlace = function(playerName: string, slotNum: number, brainrotName: string, level: number?)
	local player = Players:FindFirstChild(playerName)
	local plot = player and plotByPlayer[player]
	if not plot then return false, "no plot" end
	return placeBrainrot(plot, slotNum, brainrotName, level or 1) ~= nil
end

print(("[PlotService] Initialized — capacity %d plots, coin tick %ds"):format(MAX_PLOTS, COIN_TICK))