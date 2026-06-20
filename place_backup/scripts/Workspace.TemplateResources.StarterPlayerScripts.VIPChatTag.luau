local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

-- Fonctionne avec le nouveau TextChatService de Roblox
TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local sender = message.TextSource
	if sender then
		local player = Players:GetPlayerByUserId(sender.UserId)
		if player and player:GetAttribute("VIPTag") then
			props.PrefixText = "<font color='#FFD700'>[VIP]</font> " .. message.PrefixText
		end
	end
	return props
end

print("[VIPChatTag] Client initialized")
