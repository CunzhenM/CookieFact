local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local GROUP_CHAR = "PlayerCharacters"
local GROUP_CHAR_KICKING = "PlayerCharactersKicking"  -- transient state during a kick
local GROUP_ZONES = "ZoneParts"
local GROUP_LUCKY_BLOCKS = "LuckyBlocks"
local GROUP_BLOCK = "Block"

-- Tracks which players are currently in the "kicking" state. Used by
-- DescendantAdded so accessories/tools loaded mid-kick get the right group.
local kickingPlayers: {[Player]: boolean} = {}

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_CHAR)
		PhysicsService:RegisterCollisionGroup(GROUP_CHAR_KICKING)
		PhysicsService:RegisterCollisionGroup(GROUP_ZONES)
		PhysicsService:RegisterCollisionGroup(GROUP_LUCKY_BLOCKS)
		PhysicsService:RegisterCollisionGroup(GROUP_BLOCK)

		-- Players ignore each other in both modes
		PhysicsService:CollisionGroupSetCollidable(GROUP_CHAR, GROUP_CHAR, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_CHAR_KICKING, GROUP_CHAR_KICKING, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_CHAR_KICKING, GROUP_CHAR, false)

		-- Both modes still collide with Zones (so KickReady etc. block the player)
		PhysicsService:CollisionGroupSetCollidable(GROUP_CHAR, GROUP_ZONES, true)
		PhysicsService:CollisionGroupSetCollidable(GROUP_CHAR_KICKING, GROUP_ZONES, true)

		-- Lucky Blocks fly through everyone and through Zones
		PhysicsService:CollisionGroupSetCollidable(GROUP_LUCKY_BLOCKS, GROUP_CHAR, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_LUCKY_BLOCKS, GROUP_CHAR_KICKING, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_LUCKY_BLOCKS, GROUP_ZONES, false)
		PhysicsService:CollisionGroupSetCollidable(GROUP_LUCKY_BLOCKS, GROUP_BLOCK, false)

		-- BlockParts: SOLID for normal players, traspable while kicking
		PhysicsService:CollisionGroupSetCollidable(GROUP_BLOCK, GROUP_CHAR, true)
		PhysicsService:CollisionGroupSetCollidable(GROUP_BLOCK, GROUP_CHAR_KICKING, false)
	end)
end

local function setCharacterPartGroup(part: BasePart, player: Player?)
	local group = (player and kickingPlayers[player]) and GROUP_CHAR_KICKING or GROUP_CHAR
	pcall(function() part.CollisionGroup = group end)
end

local function onCharacterAdded(character: Model)
	local player = Players:GetPlayerFromCharacter(character)

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			setCharacterPartGroup(descendant, player)
		end
	end

	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			setCharacterPartGroup(d, player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

setupCollisionGroups()
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- ZoneParts setup (unchanged)
local zonesFolder = Workspace:WaitForChild("Zones", 10)
if zonesFolder then
	local SENSOR_ZONES = { CollectZone = true }
	local function setZoneSolid(object: Instance)
		if object:IsA("BasePart") and not SENSOR_ZONES[object.Name] then
			object.CanCollide = true
			object.CollisionGroup = GROUP_ZONES
		end
	end
	for _, descendant in ipairs(zonesFolder:GetDescendants()) do
		setZoneSolid(descendant)
	end
	zonesFolder.DescendantAdded:Connect(setZoneSolid)
end

-- ─── Public API ───────────────────────────────────────────────────────
-- _G.CollisionAPI.SetCharacterKicking(player, kicking: boolean)
--   Switches every BasePart in player.Character to the kicking/normal group.
--   Idempotent. Persists across the call so any new accessories added
--   mid-kick (DescendantAdded) inherit the same group.
_G.CollisionAPI = {
	SetCharacterKicking = function(player: Player, kicking: boolean)
		kickingPlayers[player] = kicking and true or nil
		local char = player and player.Character
		if not char then return end
		local group = kicking and GROUP_CHAR_KICKING or GROUP_CHAR
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				pcall(function() d.CollisionGroup = group end)
			end
		end
	end,
}

Players.PlayerRemoving:Connect(function(player)
	kickingPlayers[player] = nil
end)

print("[CollisionController] BlockParts SOLID for players; per-player kick group enables walk-through.")
