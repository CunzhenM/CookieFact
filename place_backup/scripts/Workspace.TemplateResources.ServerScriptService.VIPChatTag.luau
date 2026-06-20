local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local VIP_GAMEPASS_ID = 1837252645

local function onPlayerAdded(player: Player)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
	end)
	if ok and owns then
		local success, err = pcall(function()
			game:GetService("Chat"):SetExtraData("Tags", {
				{
					TagText = "VIP",
					TagColor = Color3.fromRGB(255, 215, 0)
				}
			})
		end)
		-- Méthode via TextChatService (Roblox moderne)
		local TextChatService = game:GetService("TextChatService")
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			player:SetAttribute("VIPTag", true)
		end
		print(("[VIPChatTag] %s a le tag VIP"):format(player.Name))
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
