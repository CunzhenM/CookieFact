local button = script.Parent
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GAMEPASS_ID = 1707754663

local player = Players.LocalPlayer

button.MouseButton1Click:Connect(function()

	-- Check if player already has admin
	if player:GetAttribute("HasAdmin") == true then
		return
	end

	-- Prompt the gamepass purchase
	local success, errorMessage = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_ID)
	end)

	if not success then
		warn("Failed to prompt gamepass:", errorMessage)
	else
	end
end)