local Players = game:GetService("Players")

local ADMIN_USERNAMES = {
	["goku_1565"] = true,
}
local ADMIN_USER_IDS = {}

local DEFAULT_GIVE = 1000000

local function isAdmin(player)
	return ADMIN_USERNAMES[player.Name] or ADMIN_USER_IDS[player.UserId] or false
end

local function handleChat(player, message)
	if not isAdmin(player) then return end

	local giveArg = message:match("^/cash%s*(%S*)$")
	if giveArg ~= nil then
		local amount = tonumber(giveArg)
		if not amount or amount <= 0 then amount = DEFAULT_GIVE end
		if _G.GameStateAPI and _G.GameStateAPI.AddBalance(player, amount) then
			print(("[AdminCash] +%d → %s"):format(amount, player.Name))
		end
		return
	end

	local setArg = message:match("^/setcash%s+(%S+)$")
	if setArg then
		local amount = tonumber(setArg)
		if not amount then return end
		if _G.GameStateAPI then
			local current = _G.GameStateAPI.GetBalance(player) or 0
			local diff = amount - current
			if diff ~= 0 then
				_G.GameStateAPI.AddBalance(player, diff)
			end
			print(("[AdminCash] set → %d para %s"):format(amount, player.Name))
		end
	end
end

local function attachChat(player)
	player.Chatted:Connect(function(message) handleChat(player, message) end)
end

Players.PlayerAdded:Connect(attachChat)
for _, p in ipairs(Players:GetPlayers()) do attachChat(p) end

print("[AdminCash] Listo. Comandos: /cash [n]  |  /setcash <n>")
