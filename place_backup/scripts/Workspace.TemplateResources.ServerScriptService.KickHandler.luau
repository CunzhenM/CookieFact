local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local Network    = require(ReplicatedStorage.Shared.Packages.Network)
local RarityData = require(ReplicatedStorage.Shared.Data.RarityData)

local Entities  = ReplicatedStorage.Objects:WaitForChild("Entities")
local ItemsRoot = ReplicatedStorage:FindFirstChild("Items")

local ItemManager
do
	local Modules = ServerScriptService:FindFirstChild("Modules")
	local moduleScript = Modules and Modules:FindFirstChild("ItemManager")
	if moduleScript then
		local ok, mod = pcall(require, moduleScript)
		if ok then ItemManager = mod
		else warn("[KickHandler] ItemManager require fallo:", mod) end
	else
		warn("[KickHandler] ItemManager no existe — kicks no guardarán nada (esperado tras la limpieza)")
	end
end

-- [ TUNING ] -------------------------------------------------------
local MIN_DISTANCE       = 50
local MAX_DISTANCE       = 4000
local CHASE_TIMEOUT_SECS = 60 * 60 * 6  -- 6 horas — efectivamente sin timeout durante una sesión normal
local DEFAULT_LEVEL      = 1
local ZONE_CHECK_PADDING = 5

-- Cooldown escalado por rareza obtenida (segundos)
local COOLDOWN_BY_RARITY = {
	Common    = 1,
	Rare      = 2,
	Epic      = 3,
	Legendary = 4,
	Mythic    = 6,
	Godly     = 10,
	Secret    = 16,
	Rainbow   = 22,
	Hacked    = 30,
	Demon     = 45,
	Celestial = 60,
}
local DEFAULT_COOLDOWN = 2

-- Anti-cheat estadístico:
--   Si los últimos N scales están todos por encima de SUSPICIOUS_THRESHOLD,
--   se aplica un soft-cap durante PUNISHMENT_KICKS kicks. El jugador no se entera.
local SCALE_WINDOW_SIZE     = 5
local SUSPICIOUS_THRESHOLD  = 0.95
local SOFT_CAP              = 0.55   -- scale máximo permitido durante el castigo
local PUNISHMENT_KICKS      = 5

local RARITY_TIERS = {
	"Common", "Rare", "Epic", "Legendary", "Mythic", "Godly",
	"Secret", "Rainbow", "Hacked", "Demon", "Celestial",
}
local TIER_INDEX = {}
for i, name in ipairs(RARITY_TIERS) do TIER_INDEX[name] = i end

local BONUS_RARITY_CHANCE = 5

local MUTATION_CHANCES = {
	{ name = "Neon",    chance = 0.05 },
	{ name = "Ruby",    chance = 0.2  },
	{ name = "Diamond", chance = 1.0  },
	{ name = "Golden",  chance = 5.0  },
}
-- ------------------------------------------------------------------

local rng = Random.new()

local ActiveKicks = {}
local LastKickEnd = {} -- [player] = { time, cooldownSecs }
local PlayerStats = {} -- [player] = { recentScales = {}, punishUntil = 0 }

-- Atributos de debug (editables en Studio en KickHandler.Properties → Attributes):
--   DebugMode (bool)        — prints extra y bypassa anti-cheat estadístico
--   ForcedRarity (string)   — fuerza una rareza específica ("Common", "Celestial", ...)
--   BypassCooldown (bool)   — desactiva el cooldown entre kicks
--   BypassZoneCheck (bool)  — desactiva validación de KickReady/CollectZone
local function attr(name) return script:GetAttribute(name) end

-- ---------------------------------------------------------------
-- Helpers de validación de zona
-- ---------------------------------------------------------------
local function getCharacterRootPosition(player)
	local char = player.Character
	if not char then return nil end
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if not root or not root:IsA("BasePart") then return nil end
	return root.Position
end

local function isPositionInsidePart(position, part, padding)
	if not part or not part:IsA("BasePart") then return false end
	padding = padding or 0
	local rel  = part.CFrame:PointToObjectSpace(position)
	local size = part.Size
	return math.abs(rel.X) <= size.X / 2 + padding
	   and math.abs(rel.Y) <= size.Y / 2 + padding
	   and math.abs(rel.Z) <= size.Z / 2 + padding
end

local function isPlayerInsidePart(player, part, padding)
	local pos = getCharacterRootPosition(player)
	if not pos then return false end
	return isPositionInsidePart(pos, part, padding)
end

-- ---------------------------------------------------------------
-- Anti-cheat: detectar scale siempre máximo, aplicar soft-cap
-- ---------------------------------------------------------------
local function getStats(player)
	local s = PlayerStats[player]
	if not s then
		s = { recentScales = {}, punishUntil = 0, totalKicks = 0 }
		PlayerStats[player] = s
	end
	return s
end

local function recordScale(player, scale)
	local s = getStats(player)
	s.totalKicks = s.totalKicks + 1
	table.insert(s.recentScales, scale)
	if #s.recentScales > SCALE_WINDOW_SIZE then
		table.remove(s.recentScales, 1)
	end

	-- Detección: ventana llena y todos sospechosos
	if #s.recentScales >= SCALE_WINDOW_SIZE then
		local allSus = true
		for _, v in ipairs(s.recentScales) do
			if v < SUSPICIOUS_THRESHOLD then allSus = false; break end
		end
		if allSus and s.totalKicks > s.punishUntil then
			s.punishUntil = s.totalKicks + PUNISHMENT_KICKS
			warn(("[KickHandler] %s muestra patrón sospechoso (%d scales >%.2f) — soft-cap %d kicks"):format(
				player.Name, SCALE_WINDOW_SIZE, SUSPICIOUS_THRESHOLD, PUNISHMENT_KICKS
			))
		end
	end
end

local function applySoftCapIfNeeded(player, scale)
	local s = getStats(player)
	if s.totalKicks <= s.punishUntil then
		return math.min(scale, SOFT_CAP)
	end
	return scale
end

-- ---------------------------------------------------------------
-- Bonus rarity + mutación
-- ---------------------------------------------------------------
local function rollBonusRarity(naturalRarity)
	if rng:NextNumber() * 100 >= BONUS_RARITY_CHANCE then return nil end
	local idx = TIER_INDEX[naturalRarity]
	if not idx or idx >= #RARITY_TIERS then return nil end
	return RARITY_TIERS[idx + 1]
end

local function rollMutation()
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	for _, entry in ipairs(MUTATION_CHANCES) do
		cumulative = cumulative + entry.chance
		if roll <= cumulative then return entry.name end
	end
	return "Normal"
end

-- ---------------------------------------------------------------
-- Resolver nombre del brainrot al formato test34
-- ---------------------------------------------------------------
local function resolveItemName(brainrotName, mutation)
	-- Without an Items folder the ItemManager doesn't need to "resolve" against
	-- a per-mutation lookup; just hand the brainrot name straight through.
	if not ItemsRoot then return brainrotName end
	local lookupFolder = ItemsRoot:FindFirstChild(mutation) or ItemsRoot:FindFirstChild("Normal")
	if not lookupFolder then return brainrotName end

	if lookupFolder:FindFirstChild(brainrotName) then return brainrotName end

	local stripped = brainrotName:gsub("%s+", "")
	if lookupFolder:FindFirstChild(stripped) then return stripped end

	local lowerStripped = stripped:lower()
	for _, child in ipairs(lookupFolder:GetChildren()) do
		if child.Name:lower() == lowerStripped then return child.Name end
	end

	if lookupFolder ~= ItemsRoot:FindFirstChild("Normal") then
		return resolveItemName(brainrotName, "Normal")
	end
	return brainrotName
end

local function grantBrainrot(player, brainrotName, rarity, mutation)
	if not ItemManager then return false, "ItemManager no cargado" end
	local resolved = resolveItemName(brainrotName, mutation)
	if not resolved then
		return false, ("'%s' no existe en Items.%s ni Items.Normal"):format(brainrotName, mutation)
	end
	ItemManager.GiveItemToPlayer(player, resolved, mutation, rarity, DEFAULT_LEVEL, false)
	return true, resolved
end

local function endSession(player, success, reason)
	local session = ActiveKicks[player]
	if not session or session.ended then return end
	session.ended = true

	-- Restore solid BlockParts for this player.
	if _G.CollisionAPI and _G.CollisionAPI.SetCharacterKicking then
		_G.CollisionAPI.SetCharacterKicking(player, false)
	end

	if session.failTask then
		-- pcall protege el caso self-cancel: si endSession fue invocado DESDE el failTask
		-- al expirar el timeout, no puede cancelarse a si mismo (cannot cancel thread).
		pcall(task.cancel, session.failTask)
		session.failTask = nil
	end

	if session.deathConn then
		session.deathConn:Disconnect()
		session.deathConn = nil
	end

	if success then
		local mutation = rollMutation()
		Network.FireClient(player, "Collected", session.brainrotName)

		local granted, info = grantBrainrot(player, session.brainrotName, session.rarity, mutation)
		if granted then
			print(("[KickHandler] %s atrapó %s [%s · %s] → entregado como '%s'"):format(
				player.Name, session.brainrotName, session.rarity, mutation, info
			))
		else
			warn(("[KickHandler] %s atrapó %s (%s · %s) pero no se pudo guardar: %s"):format(
				player.Name, session.brainrotName, session.rarity, mutation, tostring(info)
			))
		end
	else
		-- Solo loguear cuando fue por muerte (tsunami). El timeout silencioso.
		if reason == "death" then
			print(("[KickHandler] %s perdió el %s (%s) — tsunami"):format(
				player.Name, session.brainrotName or "?", session.rarity or "?"
			))
		end
	end

	-- Cooldown escalado por la rareza obtenida
	local cd = COOLDOWN_BY_RARITY[session.rarity] or DEFAULT_COOLDOWN
	LastKickEnd[player] = { time = os.clock(), cooldownSecs = cd }

	Network.FireClient(player, "KickEventEnded", success)
	ActiveKicks[player] = nil
end

local KickData = require(game:GetService("ReplicatedStorage").Shared.Data.KickData)

local function distanceFromScale(scale, player)
	scale = math.clamp(tonumber(scale) or 0, 0, 1)
	-- Cap the maximum distance to what the player's KickLevel allows. Without
	-- this the kick always reaches MAX_DISTANCE regardless of training.
	local kickLevel = 1
	if _G.GameStateAPI and player then
		kickLevel = _G.GameStateAPI.GetKickLevel(player) or 1
	end
	local maxAllowed = KickData:GetDistanceFromLevel(kickLevel)
	maxAllowed = math.clamp(maxAllowed, MIN_DISTANCE, MAX_DISTANCE)
	return MIN_DISTANCE + scale * (maxAllowed - MIN_DISTANCE)
end

local function pickBrainrot(rarity)
	local name  = RarityData:GetBrainrotFromRarity(rarity)
	local model = name and Entities:FindFirstChild(name)
	if not model then
		warn(("[KickHandler] Brainrot '%s' (rarity %s) no existe en Objects.Entities — fallback a Common"):format(tostring(name), tostring(rarity)))
		rarity = "Common"
		name   = RarityData:GetBrainrotFromRarity("Common")
		model  = name and Entities:FindFirstChild(name)
	end
	return rarity, name, model
end

-- Cuando rechazamos un kick que el jugador ya inició (botón clickeado),
-- mandamos KickEventEnded(false) para que el cliente vuelva a estado válido
-- y el botón reaparezca (sino se queda colgado por el `:Once` del Activated).
local function rejectKick(player, reason)
	warn(("[KickHandler] %s: kick rechazado — %s"):format(player.Name, reason))
	Network.FireClient(player, "KickEventEnded", false)
end

-- [ EVENT: KickEvent ] ----------------------------------------------
Network.OnServerEvent("KickEvent"):Connect(function(player, scale)
	if ActiveKicks[player] then return end

	-- Cooldown escalado
	if not attr("BypassCooldown") then
		local last = LastKickEnd[player]
		if last and (os.clock() - last.time) < last.cooldownSecs then
			local remaining = last.cooldownSecs - (os.clock() - last.time)
			rejectKick(player, ("cooldown %.1fs restante"):format(remaining))
			return
		end
	end

	-- Zona KickReady
	if not attr("BypassZoneCheck") then
		local kickReady = Workspace:FindFirstChild("Areas") and Workspace.Areas:FindFirstChild("KickReady")
		if not kickReady then
			warn("[KickHandler] workspace.Areas.KickReady no existe — abortando kick")
			rejectKick(player, "KickReady inexistente")
			return
		end
		if not isPlayerInsidePart(player, kickReady, ZONE_CHECK_PADDING) then
			rejectKick(player, "fuera de KickReady")
			return
		end
	end

	-- Anti-cheat: registrar y posible soft-cap (skipped en DebugMode)
	local rawScale = math.clamp(tonumber(scale) or 0, 0, 1)
	local effectiveScale = rawScale
	if not attr("DebugMode") then
		recordScale(player, rawScale)
		effectiveScale = applySoftCapIfNeeded(player, rawScale)
	end

	local distance       = distanceFromScale(effectiveScale, player)
	local naturalRarity  = RarityData:GetRarityByDistance(distance) or "Common"

	-- Override de debug: ForcedRarity reemplaza la rareza natural y skipa bonus
	local forced = attr("ForcedRarity")
	if forced and forced ~= "" then
		naturalRarity = forced
	end

	local bonusRarity    = (forced == "" or not forced) and rollBonusRarity(naturalRarity) or nil
	local finalRarity    = bonusRarity or naturalRarity

	local rarity, name, brainrot = pickBrainrot(finalRarity)
	if not brainrot then
		rejectKick(player, "no se encontró ningún brainrot")
		return
	end

	ActiveKicks[player] = {
		distance      = distance,
		rarity        = rarity,
		brainrotName  = name,
		brainrot      = brainrot,
		bonusRarity   = bonusRarity,
		state         = "kicking",
		startedAt     = os.clock(),
	}

	-- Make BlockParts traspable for this player while the kick is active so
	-- they can chase the brainrot through the lobby wall. Restored in endSession.
	if _G.CollisionAPI and _G.CollisionAPI.SetCharacterKicking then
		_G.CollisionAPI.SetCharacterKicking(player, true)
	end

	local effLabel = (effectiveScale < rawScale) and (" [capped from %.2f]"):format(rawScale) or ""
	if bonusRarity then
		print(("[KickHandler] %s pateó (scale=%.2f%s) → %.0f studs → %s ✨BONUS✨ → %s · %s"):format(
			player.Name, effectiveScale, effLabel, distance, naturalRarity, bonusRarity, name
		))
	else
		print(("[KickHandler] %s pateó (scale=%.2f%s) → %.0f studs → %s · %s"):format(
			player.Name, effectiveScale, effLabel, distance, naturalRarity, name
		))
	end

	Network.FireClient(player, "KickEvent", distance, brainrot, bonusRarity)
end)

Network.OnServerEvent("Transformed"):Connect(function(player)
	local session = ActiveKicks[player]
	if not session or session.state ~= "kicking" then return end
	session.state = "transformed"
end)

local function watchDeath(player, session)
	if session.deathConn then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	session.deathConn = hum.Died:Connect(function()
		if not ActiveKicks[player] or ActiveKicks[player].ended then return end
		-- Esperar a que el respawn termine (Players.RespawnTime + load) y el
		-- player ya esté en su plot antes de imprimir "perdió X" — así el log
		-- llega DESPUÉS del teleport, no antes.
		task.spawn(function()
			player.CharacterAdded:Wait()
			task.wait(0.1)
			if ActiveKicks[player] and not ActiveKicks[player].ended then
				endSession(player, false, "death")
			end
		end)
	end)
end

Network.OnServerEvent("KickZman"):Connect(function(player)
	local session = ActiveKicks[player]
	if not session then return end
	session.state = "chasing"

	watchDeath(player, session)

	if session.failTask then task.cancel(session.failTask) end
	session.failTask = task.delay(CHASE_TIMEOUT_SECS, function()
		if ActiveKicks[player] and not ActiveKicks[player].ended then
			endSession(player, false)
		end
	end)
end)

Network.OnServerEvent("KickCollect"):Connect(function(player)
	local session = ActiveKicks[player]
	if not session or session.ended then return end
	if session.state ~= "chasing" and session.state ~= "transformed" then return end

	local collectZone = Workspace:FindFirstChild("Zones") and Workspace.Zones:FindFirstChild("CollectZone")
	if not collectZone then
		warn("[KickHandler] workspace.Zones.CollectZone no existe — concediendo éxito sin validar")
	elseif not isPlayerInsidePart(player, collectZone, ZONE_CHECK_PADDING) then
		warn(("[KickHandler] %s mandó KickCollect fuera de CollectZone — ignorado"):format(player.Name))
		return
	end

	endSession(player, true)
end)

Players.PlayerRemoving:Connect(function(player)
	local session = ActiveKicks[player]
	if session and session.failTask then task.cancel(session.failTask) end
	ActiveKicks[player] = nil
	LastKickEnd[player] = nil
	PlayerStats[player] = nil
end)

print("[KickHandler] Loaded (Paso 6: anti-cheat + cooldown por rareza + UX rechazo)")
