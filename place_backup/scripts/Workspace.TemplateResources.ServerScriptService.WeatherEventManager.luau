local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Packages.Network)

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local EVENT_DURATION = 300  -- segundos por evento
local VALID_EVENTS = {
	Stadium = true,
	Disco = true,
	Void = true,
	TrainingTime = true,
	Fire = true,
	Hacker2 = true,
	Virus = true,
}

-- Lista de admins por nombre. Tu nombre ya esta agregado, edita si lo necesitas.
local ADMIN_USERNAMES = {
	["furi0us_jumper1194"] = true
}
-- O por UserId si prefieres (mas seguro contra cambios de username)
local ADMIN_USER_IDS = {
	-- [123456789] = true,
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
local activeEvents = {}  -- name -> endTime (epoch seconds, GetServerTimeNow)

-- Asegurar que los 3 RemoteEvents existen
Network.CreateRemote("WeatherUpdate")
Network.CreateRemote("AddedWeather")
Network.CreateRemote("RemovedWeather")

local function isAdmin(player)
	return ADMIN_USERNAMES[player.Name] or ADMIN_USER_IDS[player.UserId] or false
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
local function startEvent(name)
	if not VALID_EVENTS[name] then
		return false, "evento invalido: " .. tostring(name)
	end
	if activeEvents[name] then
		return false, "ya activo"
	end
	local endTime = workspace:GetServerTimeNow() + EVENT_DURATION
	activeEvents[name] = endTime
	Network.FireAllClients("AddedWeather", name, endTime)
	print(("[WeatherEventManager] %s iniciado (termina en %ds)"):format(name, EVENT_DURATION))

	-- Auto-stop al expirar
	task.delay(EVENT_DURATION, function()
		if activeEvents[name] == endTime then  -- mismo evento, no fue stop manual
			activeEvents[name] = nil
			Network.FireAllClients("RemovedWeather", name)
			print(("[WeatherEventManager] %s termino (auto)"):format(name))
		end
	end)

	return true
end

local function stopEvent(name)
	if name == "all" then
		local stopped = {}
		for n in pairs(activeEvents) do
			activeEvents[n] = nil
			Network.FireAllClients("RemovedWeather", n)
			table.insert(stopped, n)
		end
		return true, ("detenidos: %s"):format(table.concat(stopped, ", "))
	end
	if not activeEvents[name] then
		return false, "no esta activo"
	end
	activeEvents[name] = nil
	Network.FireAllClients("RemovedWeather", name)
	return true
end

local function listEvents()
	local now = workspace:GetServerTimeNow()
	local lines = {}
	for n, t in pairs(activeEvents) do
		table.insert(lines, ("%s (%ds restantes)"):format(n, math.floor(t - now)))
	end
	if #lines == 0 then
		return "ninguno"
	end
	return table.concat(lines, ", ")
end

----------------------------------------------------------------
-- CHAT COMMAND
----------------------------------------------------------------
local function handleChat(player, message)
	if not isAdmin(player) then return end
	local arg = message:match("^/event%s+(%S+)$")
	if not arg then return end

	if arg == "list" then
		print("[WeatherEventManager] Activos:", listEvents())
	elseif arg == "stop" then
		local _, info = stopEvent("all")
		print("[WeatherEventManager]", info or "sin eventos")
	else
		local ok, err = startEvent(arg)
		if not ok then
			warn("[WeatherEventManager]", err)
		end
	end
end

local function attachChat(player)
	player.Chatted:Connect(function(message) handleChat(player, message) end)
end

Players.PlayerAdded:Connect(function(player)
	attachChat(player)
	-- Sync inicial: enviar al cliente el estado completo (eventos ya activos al joinear)
	Network.FireClient(player, "WeatherUpdate", activeEvents)
end)
for _, p in ipairs(Players:GetPlayers()) do
	attachChat(p)
end

-- Exposed for EventRunnerHandler (admin panel UI). Names mirror the chat
-- command verbs so callers don't need to know the local function names.
_G.WeatherEventAPI = {
	Start = startEvent,
	Stop = stopEvent,
	List = listEvents,
	IsValid = function(name)
		return VALID_EVENTS[name] == true
	end,
}

print("[WeatherEventManager] Listo. Comandos: /event Stadium|Disco|Void|TrainingTime|Fire|Hacker2|Virus|stop|list")
