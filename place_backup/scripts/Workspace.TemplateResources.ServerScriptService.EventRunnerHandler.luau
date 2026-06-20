local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local StartEventRemote = getOrCreateRemote("StartEventRemote")
local StopEventRemote = getOrCreateRemote("StopEventRemote")

local function waitForAPI(timeoutSec)
	local deadline = os.clock() + (timeoutSec or 5)
	while not _G.WeatherEventAPI and os.clock() < deadline do
		task.wait(0.1)
	end
	return _G.WeatherEventAPI
end

StartEventRemote.OnServerEvent:Connect(function(player, name)
	if not isAuthorized(player) then return end
	if typeof(name) ~= "string" or name == "" then return end
	local api = waitForAPI()
	if not api then
		warn("[EventRunnerHandler] WeatherEventAPI not available")
		return
	end
	if not api.IsValid(name) then
		warn(("[EventRunnerHandler] %s tried unknown event: %s"):format(player.Name, name))
		return
	end
	local ok, err = api.Start(name)
	if not ok then
		warn(("[EventRunnerHandler] Start(%s) by %s failed: %s"):format(name, player.Name, tostring(err)))
	else
		print(("[EventRunnerHandler] %s started %s"):format(player.Name, name))
	end
end)

StopEventRemote.OnServerEvent:Connect(function(player, name)
	if not isAuthorized(player) then return end
	if typeof(name) ~= "string" then return end
	local api = waitForAPI()
	if not api then
		warn("[EventRunnerHandler] WeatherEventAPI not available")
		return
	end
	-- Blank / "stop" / "all" -> stop-all (matches the chat command convention)
	local target = name
	if target == "" or target:lower() == "stop" or target:lower() == "all" then
		target = "all"
	end
	local ok, info = api.Stop(target)
	if ok then
		print(("[EventRunnerHandler] %s stopped %s (%s)"):format(player.Name, target, tostring(info or "")))
	else
		warn(("[EventRunnerHandler] Stop(%s) by %s: %s"):format(target, player.Name, tostring(info)))
	end
end)

print("[EventRunnerHandler] Listening on StartEventRemote / StopEventRemote.")
