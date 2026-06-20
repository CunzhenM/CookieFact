local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EntitiesData = require(ReplicatedStorage.Shared.Data.EntitiesData)

local AUTHORIZED_USER_IDS = {
	[7417559307] = true,
}

local function isAuthorized(player)
	return AUTHORIZED_USER_IDS[player.UserId] == true
end

local function getOrCreateRemote(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then return existing end
	local rev = Instance.new("RemoteEvent")
	rev.Name = name
	rev.Parent = ReplicatedStorage
	return rev
end

local AddMoneyRemote   = getOrCreateRemote("AddMoneyRemote")
local SetMoneyRemote   = getOrCreateRemote("SetMoneyRemote")
local AddSpeedRemote   = getOrCreateRemote("AddSpeedRemote")
local SetSpeedRemote   = getOrCreateRemote("SetSpeedRemote")
local AddRebirthRemote = getOrCreateRemote("AddRebirthRemote")
local SetRebirthRemote = getOrCreateRemote("SetRebirthRemote")
local AddKickRemote    = getOrCreateRemote("AddKickRemote")
local SetKickRemote    = getOrCreateRemote("SetKickRemote")
local GiveBrainrotRemote = getOrCreateRemote("GiveBrainrotRemote")

local function sanitize(amount)
	local n = tonumber(amount)
	if not n or n ~= n then return nil end -- nil / NaN
	return math.floor(n)
end

local function call(method, player, amount)
	local n = sanitize(amount); if not n then return end
	local api = _G.GameStateAPI
	if api and api[method] then
		api[method](player, n)
	end
end

local function bind(remote, method, label)
	remote.OnServerEvent:Connect(function(player, amount)
		if not isAuthorized(player) then return end
		call(method, player, amount)
		print(("[AdminPanel] %s %s by %s -> %s"):format(label, tostring(amount), player.Name, method))
	end)
end

bind(AddMoneyRemote,   "AddBalance",      "AddMoney")
bind(SetMoneyRemote,   "SetBalance",      "SetMoney")
bind(AddSpeedRemote,   "AddSpeedLevel",   "AddSpeed")
bind(SetSpeedRemote,   "SetSpeedLevel",   "SetSpeed")
bind(AddRebirthRemote, "AddRebirths",     "AddRebirth")
bind(SetRebirthRemote, "SetRebirths",     "SetRebirth")
bind(AddKickRemote,    "AddKickLevel",    "AddKick")
bind(SetKickRemote,    "SetKickLevel",    "SetKick")

-- GiveBrainrot: caller is the recipient. Validates brainrot name against
-- EntitiesData and the level is a positive integer. Rarity is looked up so
-- the Tool's Rarity attribute is set correctly for the inventory UI.
GiveBrainrotRemote.OnServerEvent:Connect(function(player, name, level)
	if not isAuthorized(player) then return end
	if typeof(name) ~= "string" or name == "" then return end
	local lvl = tonumber(level)
	if not lvl or lvl < 1 then return end
	lvl = math.floor(lvl)

	local data = EntitiesData.Brainrots and EntitiesData.Brainrots[name]
	if not data then
		warn(("[AdminPanel] %s tried unknown brainrot: %s"):format(player.Name, tostring(name)))
		return
	end

	if not _G.ItemManagerAPI or not _G.ItemManagerAPI.Give then
		warn("[AdminPanel] ItemManagerAPI not available")
		return
	end

	_G.ItemManagerAPI.Give(player, name, nil, data.Rarity, lvl, false)
	print(("[AdminPanel] %s gave %s (lvl %d) to themselves"):format(player.Name, name, lvl))
end)

print("[AdminPanelHandler] Bound 9 admin remotes (Money/Speed/Rebirth/Kick Add+Set + GiveBrainrot).")
