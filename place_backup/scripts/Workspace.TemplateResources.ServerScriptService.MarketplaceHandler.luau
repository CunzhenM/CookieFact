local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Packages.Network)

-- ─── IDs Gamepasses ───────────────────────────────────────────────────
local GAMEPASSES = {
	VIP            = 1837252645,
	x2Cash         = 1834657751,
	x2KickPower    = 1836652582,
	x2BrainrotLuck = 1838127623,
	x2MutationLuck = 1837522725,
}

-- ─── IDs Produits Développeur ─────────────────────────────────────────
local PRODUCTS = {
	StarterPack1   = 3591784729,  -- SP
	StarterPack2   = 3571978482,  -- MP
	StarterPack3   = 3571978399,  -- GP
	StarterPack4   = 3571978797,  -- SEP
	Rebirth        = 3591787411,
	Speed1         = 3571977912,
	Speed5         = 3571978279,
	Speed10        = 3571978190,
	OfflineClaim10 = 3591790743,
	ServerLuck_x2  = 3571980293,
	ServerLuck_x4  = 3571980509,
	ServerLuck_x8  = 3571980660,
	SmallCash      = 3591785390,
	MediumCash     = 3591785692,
	BigCash        = 3591785964,
	HugeCash       = 3591786870,
	InsaneCash     = 3591787117,
}

-- ─── Cash Packs ───────────────────────────────────────────────────────
local CASH_PACKS = {
	[3591785390] = 5000,
	[3591785692] = 20000,
	[3591785964] = 75000,
	[3591786870] = 250000,
	[3591787117] = 1000000,
}

-- ─── Contenu des StarterPacks ─────────────────────────────────────────
local STARTER_PACK_CONTENT = {
	[PRODUCTS.StarterPack1] = {
		Brainrots = { "Plan Red", "Plan Blue" },
		KickBonus = 1000,
	},
	[PRODUCTS.StarterPack2] = {
		Brainrots = { "Penguino Cocosino", "67" },
		KickBonus = 10000,
	},
	[PRODUCTS.StarterPack3] = {
		Brainrots = { "Udin Din Din Dun", "Pandaccini Bananini", "Octopusini Bluberini" },
		KickBonus = 0,
	},
	[PRODUCTS.StarterPack4] = {
		Brainrots = { "Tralalero Tralala", "Dipperi Chiperini", "Matteo" },
		KickBonus = 0,
	},
}

-- ─── État des joueurs ─────────────────────────────────────────────────
-- Stocke les gamepasses et le ServerLuck par joueur
local playerGamepasses: {[Player]: {[string]: boolean}} = {}
local playerServerLuck: {[Player]: number} = {}

-- ─── API publique pour les autres scripts ─────────────────────────────
_G.MarketplaceAPI = {
	-- Retourne le multiplicateur de coins (brainrots) pour un joueur
	GetCashMultiplier = function(player: Player): number
		local gp = playerGamepasses[player]
		if not gp then return 1 end
		local mult = 1
		if gp.VIP then mult = mult * 1.5 end
		if gp.x2Cash then mult = mult * 2 end
		return mult
	end,

	-- Retourne le multiplicateur de Kick Power pour un joueur
	GetKickMultiplier = function(player: Player): number
		local gp = playerGamepasses[player]
		if not gp then return 1 end
		if gp.x2KickPower then return 2 end
		return 1
	end,

	-- Retourne le multiplicateur de Brainrot Luck pour un joueur
	GetBrainrotLuckMultiplier = function(player: Player): number
		local gp = playerGamepasses[player]
		if not gp then return 1 end
		local mult = 1
		if gp.VIP then mult = mult * 2 end
		if gp.x2BrainrotLuck then mult = mult * 2 end
		return mult
	end,

	-- Retourne le multiplicateur de Mutation Luck pour un joueur
	GetMutationLuckMultiplier = function(player: Player): number
		local gp = playerGamepasses[player]
		if not gp then return 1 end
		local mult = 1
		if gp.x2MutationLuck then mult = mult * 2 end
		return mult
	end,

	-- Retourne le multiplicateur ServerLuck pour un joueur
	GetServerLuck = function(player: Player): number
		return playerServerLuck[player] or 1
	end,

	-- Vérifie si un joueur a le VIP
	HasVIP = function(player: Player): boolean
		local gp = playerGamepasses[player]
		return gp and gp.VIP or false
	end,
}

-- ─── Application des Gamepasses ───────────────────────────────────────
local function applyGamepasses(player: Player)
	local gp = playerGamepasses[player]
	if not gp then return end

	-- Push les multiplicateurs au client
	if gp.x2Cash or gp.VIP then
		local mult = _G.MarketplaceAPI.GetCashMultiplier(player)
		Network.FireClient(player, "CoinsMulti", mult, gp.VIP and "VIP" or nil)
	end
	if gp.x2KickPower then
		Network.FireClient(player, "KickMulti", 2, nil)
	end
	if gp.x2BrainrotLuck or gp.VIP then
		local mult = _G.MarketplaceAPI.GetBrainrotLuckMultiplier(player)
		Network.FireClient(player, "sl_upd", playerServerLuck[player] or 1, nil, mult, nil)
	end

	-- Tag VIP dans le chat/leaderboard
	if gp.VIP then
		-- Tu peux ajouter ici un badge VIP si tu as un système de chat tag
		print(("[MarketplaceHandler] %s a le VIP"):format(player.Name))
	end
end

local function checkGamepasses(player: Player)
	playerGamepasses[player] = {}
	local gp = playerGamepasses[player]

	for name, id in pairs(GAMEPASSES) do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
		end)
		if ok and owns then
			gp[name] = true
			print(("[MarketplaceHandler] %s possède le gamepass %s"):format(player.Name, name))
		end
	end

	applyGamepasses(player)
end

-- ─── Traitement des Produits Développeur ──────────────────────────────
local processedReceipts: {[string]: boolean} = {}

local function grantStarterPack(player: Player, productId: number)
	local content = STARTER_PACK_CONTENT[productId]
	if not content then return false end

	-- Donner les brainrots
	if _G.ItemManagerAPI then
		for _, brainrotName in ipairs(content.Brainrots) do
			_G.ItemManagerAPI.Give(player, brainrotName, nil, nil, 1, false)
			print(("[MarketplaceHandler] Donné %s à %s"):format(brainrotName, player.Name))
		end
	end

	-- Donner les Kick bonus
	if content.KickBonus > 0 and _G.GameStateAPI then
		_G.GameStateAPI.AddKickLevel(player, content.KickBonus)
		print(("[MarketplaceHandler] +%d Kick à %s"):format(content.KickBonus, player.Name))
	end

	return true
end

local function grantServerLuck(player: Player, level: number)
	playerServerLuck[player] = level
	local brainrotMult = _G.MarketplaceAPI.GetBrainrotLuckMultiplier(player)
	Network.FireClient(player, "sl_upd", level, nil, brainrotMult, nil)
	print(("[MarketplaceHandler] ServerLuck x%d pour %s"):format(level, player.Name))
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local key = tostring(receiptInfo.PlayerId) .. ":" .. tostring(receiptInfo.PurchaseId)
	if processedReceipts[key] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local success = false

	-- StarterPacks
	if STARTER_PACK_CONTENT[productId] then
		success = grantStarterPack(player, productId)

		-- ServerLuck
	elseif productId == PRODUCTS.ServerLuck_x2 then
		grantServerLuck(player, 2)
		success = true
	elseif productId == PRODUCTS.ServerLuck_x4 then
		grantServerLuck(player, 4)
		success = true
	elseif productId == PRODUCTS.ServerLuck_x8 then
		grantServerLuck(player, 8)
		success = true

		-- Rebirth (skip 1 rebirth en gardant tout)
	elseif productId == PRODUCTS.Rebirth then
		if _G.GameStateAPI then
			_G.GameStateAPI.AddRebirths(player, 1)
			print(("[MarketplaceHandler] Rebirth acheté par %s"):format(player.Name))
			success = true
		end

		-- Speed Packs
	elseif productId == PRODUCTS.Speed1 then
		if _G.GameStateAPI then
			_G.GameStateAPI.AddSpeedLevel(player, 1)
			print(("[MarketplaceHandler] +1 Speed pour %s"):format(player.Name))
			success = true
		end
	elseif productId == PRODUCTS.Speed5 then
		if _G.GameStateAPI then
			_G.GameStateAPI.AddSpeedLevel(player, 5)
			print(("[MarketplaceHandler] +5 Speed pour %s"):format(player.Name))
			success = true
		end
	elseif productId == PRODUCTS.Speed10 then
		if _G.GameStateAPI then
			_G.GameStateAPI.AddSpeedLevel(player, 10)
			print(("[MarketplaceHandler] +10 Speed pour %s"):format(player.Name))
			success = true
		end

		-- x10 Offline Claim
	elseif productId == PRODUCTS.OfflineClaim10 then
		-- Stocke le flag x10 pour que le système offline l'applique
		local s = player:FindFirstChild("OfflineClaimX10")
		if not s then
			local flag = Instance.new("BoolValue")
			flag.Name = "OfflineClaimX10"
			flag.Value = true
			flag.Parent = player
		end
		print(("[MarketplaceHandler] x10 OfflineClaim acheté par %s"):format(player.Name))
		success = true

		-- Cash Packs
	elseif CASH_PACKS[productId] then
		if _G.GameStateAPI then
			_G.GameStateAPI.AddBalance(player, CASH_PACKS[productId])
			print(("[MarketplaceHandler] +%d coins pour %s"):format(CASH_PACKS[productId], player.Name))
			success = true
		end
	end

	if success then
		processedReceipts[key] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ─── Lifecycle ────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	playerServerLuck[player] = 1
	task.spawn(checkGamepasses, player)
end)

Players.PlayerRemoving:Connect(function(player)
	playerGamepasses[player] = nil
	playerServerLuck[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	playerServerLuck[player] = 1
	task.spawn(checkGamepasses, player)
end

print("[MarketplaceHandler] Initialized — Gamepasses et Produits prêts")