local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Shared.Packages.Network)

local UPDATE_INTERVAL = 10

-- Usernames exclus du leaderboard (Dev/Admin)
local EXCLUDED_USERNAMES = {
	"furi0us_jumper1194", --put ur username
	"TheMaroc_tacos",
	"Timeo99294",
}

local function isExcluded(player: Player): boolean
	for _, name in ipairs(EXCLUDED_USERNAMES) do
		if player.Name:lower() == name:lower() then
			return true
		end
	end
	return false
end

local function getLeaderboardData()
	local cashList = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not isExcluded(player) then
			local balance = _G.GameStateAPI and _G.GameStateAPI.GetBalance(player) or 0
			table.insert(cashList, {
				key = tostring(player.UserId),
				value = tostring(balance)
			})
		end
	end
	table.sort(cashList, function(a, b)
		return tonumber(a.value) > tonumber(b.value)
	end)
	return { Cash = cashList }
end

local function updateLeaderboard()
	local data = getLeaderboardData()
	for _, player in ipairs(Players:GetPlayers()) do
		Network.FireClient(player, "LeaderboardUPD", data)
	end
end

task.spawn(function()
	while true do
		task.wait(UPDATE_INTERVAL)
		updateLeaderboard()
	end
end)

Players.PlayerAdded:Connect(function()
	task.wait(5)
	updateLeaderboard()
end)

print("[LeaderboardHandler] Initialized")