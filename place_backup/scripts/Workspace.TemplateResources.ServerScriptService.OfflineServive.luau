local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Packages.Network)
local EntitiesData = require(ReplicatedStorage.Shared.Data.EntitiesData)

Network.CreateRemote("Offline_Update")
Network.CreateRemote("Offline_Force")
Network.CreateRemote("Offline_Claim")

local MAX_OFFLINE_SECONDS = 30 * 60  -- 30 minutes max

-- Stocke le timestamp de déconnexion
local DataStoreService = game:GetService("DataStoreService")
local LastSeenStore = DataStoreService:GetDataStore("LastSeen_v1")

-- Stocke les coins offline en attente par joueur
local pendingOfflineCoins: {[Player]: number} = {}

local function getLastSeen(userId: number): number?
	local ok, result = pcall(function()
		return LastSeenStore:GetAsync("user_" .. tostring(userId))
	end)
	if ok then return result end
	return nil
end

local function saveLastSeen(userId: number)
	pcall(function()
		LastSeenStore:SetAsync("user_" .. tostring(userId), os.time())
	end)
end

local function calculateOfflineCoins(player: Player, secondsOffline: number): number
	local profile = _G.DataAPI and _G.DataAPI.GetProfile(player)
	if not profile then return 0 end

	local placed = profile.Data.PlacedBrainrots or {}
	if not next(placed) then return 0 end

	-- Calculer le CPS total des brainrots placés
	local totalCPS = 0
	for _, info in pairs(placed) do
		if info and info.id then
			local data = EntitiesData.Brainrots[info.id]
			if data and data.CPS then
				local level = info.level or 1
				local mult = EntitiesData.GetMultiplierPerLevel(level)
				-- Mutation bonus
				if info.mutation then
					local MutationData = require(ReplicatedStorage.Shared.Data.MutationData)
					local mutBuff = MutationData.Buffs[info.mutation]
					if mutBuff and mutBuff.Value then
						mult = mult * mutBuff.Value
					end
				end
				-- CPS est un InfiniteMath, convertir en nombre
				local cpsValue = tonumber(tostring(data.CPS)) or 0
				totalCPS = totalCPS + cpsValue * mult
			end
		end
	end

	-- Rebirth multiplier
	local rebirths = (_G.GameStateAPI and _G.GameStateAPI.GetRebirths and _G.GameStateAPI.GetRebirths(player)) or 0
	local rebirthMult = 1 + rebirths

	-- Gamepass multiplier (VIP x1.5, x2Cash x2)
	local cashMult = (_G.MarketplaceAPI and _G.MarketplaceAPI.GetCashMultiplier and _G.MarketplaceAPI.GetCashMultiplier(player)) or 1

	local coins = totalCPS * secondsOffline * rebirthMult * cashMult
	return math.floor(coins)
end

local function onPlayerAdded(player: Player)
	-- Attendre que le profil soit chargé
	local profile = _G.DataAPI and _G.DataAPI.WaitForProfile(player, 30)
	if not profile then return end

	-- Récupérer le dernier timestamp
	local lastSeen = getLastSeen(player.UserId)
	if not lastSeen then
		-- Première connexion, pas de coins offline
		saveLastSeen(player.UserId)
		return
	end

	local now = os.time()
	local secondsOffline = math.min(now - lastSeen, MAX_OFFLINE_SECONDS)

	if secondsOffline < 60 then
		-- Moins d'1 minute, pas la peine d'afficher
		saveLastSeen(player.UserId)
		return
	end

	-- Calculer les coins offline
	task.wait(5) -- Attendre que tout soit chargé côté client
	if not player.Parent then return end

	local coins = calculateOfflineCoins(player, secondsOffline)
	if coins <= 0 then
		saveLastSeen(player.UserId)
		return
	end

	-- Stocker les coins en attente
	pendingOfflineCoins[player] = coins

	-- Envoyer au client
	Network.FireClient(player, "Offline_Update", tostring(coins))
	print(("[OfflineService] %s a gagné %d coins offline (%ds)"):format(
		player.Name, coins, secondsOffline))
end

-- Claim normal
Network.OnServerEvent("Offline_Claim"):Connect(function(player)
	local coins = pendingOfflineCoins[player]
	if not coins then return end
	pendingOfflineCoins[player] = nil

	-- Vérifier x10 OfflineClaim
	local x10Flag = player:FindFirstChild("OfflineClaimX10")
	if x10Flag then
		coins = coins * 10
		x10Flag:Destroy()
		print(("[OfflineService] x10 appliqué pour %s → %d coins"):format(player.Name, coins))
	end

	if _G.GameStateAPI then
		_G.GameStateAPI.AddBalance(player, coins)
	end

	Network.FireClient(player, "Offline_Force")
	print(("[OfflineService] %s a réclamé %d coins offline"):format(player.Name, coins))
end)

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	pendingOfflineCoins[player] = nil
	saveLastSeen(player.UserId)
end)

-- Sauvegarder le timestamp régulièrement
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveLastSeen(player.UserId)
		end
	end
end)

print("[OfflineService] Initialized — max offline: 30min")