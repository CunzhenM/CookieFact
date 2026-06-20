local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EntitiesData = require(ReplicatedStorage.Shared.Data.EntitiesData)

local ItemManager = {}

type Item = {
	Name: string,
	Mutation: string?,
	Rarity: string?,
	Level: number,
	IsLuckyBlock: boolean,
	UID: string,
}

local owned: {[Player]: {Item}} = {}

local function newUID(): string
	return tostring(os.clock()) .. "-" .. tostring(math.random(1, 1e9))
end

-- Build a Tool. The client component "EntityTool" (tagged "EntityTool")
-- attaches the brainrot model on Equipped and welds it to Tool.Handle, so
-- we need a small invisible Handle BasePart for the client to anchor to.
local function buildTool(item: Item): Tool?
	local data = EntitiesData.Brainrots[item.Name]
	if not data then return nil end

	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.TextureId = data.Image or ""
	tool.ToolTip = item.Name
	tool:SetAttribute("Mutation", item.Mutation)
	tool:SetAttribute("Rarity", item.Rarity)
	tool:SetAttribute("Level", item.Level)
	tool:SetAttribute("UID", item.UID)
	tool:AddTag("EntityTool")

	-- Invisible anchor part. The EntityTool client component will weld the
	-- real brainrot model to this Handle.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 0.5)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

-- Returns the live Items array for a player. If a DataService profile is
-- loaded, the array IS profile.Data.Items (mutations auto-save). Otherwise
-- falls back to an in-memory table (which gets wiped on PlayerRemoving).
local function getItems(player: Player)
	if _G.DataAPI then
		local profile = _G.DataAPI.GetProfile(player)
		if profile and profile.Data then
			profile.Data.Items = profile.Data.Items or {}
			-- Keep `owned` synced so legacy callers still see the same array.
			owned[player] = profile.Data.Items
			return profile.Data.Items
		end
	end
	owned[player] = owned[player] or {}
	return owned[player]
end

function ItemManager.GiveItemToPlayer(
	player: Player,
	name: string,
	mutation: string?,
	rarity: string?,
	level: number?,
	isLuckyBlock: boolean?
)
	if not player or not player.Parent then return false end
	if not EntitiesData.Brainrots[name] then
		warn(("[ItemManager] '%s' is not a known brainrot"):format(tostring(name)))
		return false
	end

	local item: Item = {
		Name = name,
		Mutation = mutation,
		Rarity = rarity,
		Level = level or 1,
		IsLuckyBlock = isLuckyBlock or false,
		UID = newUID(),
	}

	local items = getItems(player)
	table.insert(items, item)

	local tool = buildTool(item)
	if tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			tool.Parent = backpack
		end
	end

	-- Tag as discovered for the Index (uses the mutation key the client expects).
	if _G.GameStateAPI and _G.GameStateAPI.MarkDiscovered then
		_G.GameStateAPI.MarkDiscovered(player, name, mutation or "None")
	end

	return true, item
end

function ItemManager.GetItems(player: Player): {Item}
	return getItems(player)
end

-- Called by GameServiceHub on the first CharacterAdded after profile load.
-- Wipes any leftover EntityTool Tools from Backpack/Character (defensive
-- against double-restore on respawn) and rebuilds Tools from saved items.
function ItemManager.RestoreInventory(player: Player)
	local items = getItems(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:HasTag("EntityTool") then
					child:Destroy()
				end
			end
		end
	end

	for _, item in ipairs(items) do
		local tool = buildTool(item)
		if tool then tool.Parent = backpack end
	end

	print(("[ItemManager] Restored %d brainrots for %s"):format(#items, player.Name))
end

function ItemManager.RemoveItem(player: Player, uid: string): boolean
	local list = getItems(player)
	if not list then return false end
	for i, item in ipairs(list) do
		if item.UID == uid then
			table.remove(list, i)
			-- Also remove the Tool if it's still in Backpack/Character
			for _, container in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
				if container then
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("Tool") and child:GetAttribute("UID") == uid then
							child:Destroy()
						end
					end
				end
			end
			return true
		end
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
end)

-- Expose API for other server scripts (PlotService pickup needs to put the
-- brainrot back in the inventory).
_G.ItemManagerAPI = {
	Give = ItemManager.GiveItemToPlayer,
	Remove = ItemManager.RemoveItem,
	GetItems = ItemManager.GetItems,
	RestoreInventory = ItemManager.RestoreInventory,
}

print("[ItemManager] Initialized (in-memory, no persistence)")
return ItemManager
