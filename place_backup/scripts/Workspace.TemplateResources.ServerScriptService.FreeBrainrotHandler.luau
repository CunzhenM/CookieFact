local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Network = require(ReplicatedStorage.Shared.Packages.Network)

local FREE_BRAINROT = "Gangster Footera"
local ClaimedStore = DataStoreService:GetDataStore("FreeBrainrot_v1")

Network.CreateRemote("ClaimFreeBrainrot")
Network.CreateRemote("ClaimFreeBrainrot_Result")

Network.OnServerEvent("ClaimFreeBrainrot"):Connect(function(player)
	print("[FreeBrainrot] Reçu de", player.Name)
	local key = "claimed_" .. tostring(player.UserId)

	-- Vérifier si déjà récupéré
	local ok, claimed = pcall(function()
		return ClaimedStore:GetAsync(key)
	end)

	if not ok then
		Network.FireClient(player, "ClaimFreeBrainrot_Result", false, "Erreur serveur, réessaie !")
		return
	end

	if claimed then
		Network.FireClient(player, "ClaimFreeBrainrot_Result", false, "You've already claimed this Brainrot !")
		return
	end

	-- Donner le brainrot
	if _G.ItemManagerAPI then
		_G.ItemManagerAPI.Give(player, FREE_BRAINROT, nil, nil, 1, false)
	end

	-- Marquer comme récupéré
	pcall(function()
		ClaimedStore:SetAsync(key, true)
	end)

	Network.FireClient(player, "ClaimFreeBrainrot_Result", true, "You've received " .. FREE_BRAINROT .. " !")
	print(("[FreeBrainrot] %s a récupéré %s"):format(player.Name, FREE_BRAINROT))

end)

print("[FreeBrainrotHandler] Initialized")
