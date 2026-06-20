--!strict
-- DEV ONLY: gives each player test money in Studio (never on live). Set GIVE_TEST_MONEY=false to disable.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DevTools = {}
local GIVE_TEST_MONEY = true
local TEST_AMOUNT = 1000000

local Currency = nil
local function resolveCurrency()
	local serverScript = ServerScriptService:FindFirstChild("Server")
	local mod = serverScript and serverScript:FindFirstChild("CurrencyService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" then
			Currency = result
		end
	end
end

local function give(player)
	if Currency and Currency.Set then
		Currency.Set(player, TEST_AMOUNT, "dev_test_money")
	end
end

function DevTools.Start()
	if not (GIVE_TEST_MONEY and RunService:IsStudio()) then
		return
	end
	resolveCurrency()
	Players.PlayerAdded:Connect(function(player)
		task.delay(1, give, player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(give, p)
	end
	print("[DevTools] Studio test money ON -- every player gets $" .. TEST_AMOUNT)
end

return DevTools
