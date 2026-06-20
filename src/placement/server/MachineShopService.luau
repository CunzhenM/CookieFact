--!strict
-- Machine shop: the fixed production line. Reads Workspace.CookieFactory models (each: a
-- Base placeholder, an optional Marker silhouette, Cost/Order/Label attrs). Hides each Base,
-- puts a ProximityPrompt on the Marker. Client shows the ProductConfirmFrame and on Yes fires
-- Buy; this module re-validates (order, affordability), charges via CurrencyService, and
-- reveals the machine with the build-in animation.

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local BuildAnimation = require(Shared:WaitForChild("BuildAnimation"))

local MachineShopService = {}
local entries = {}
local byId = {}

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

local function charge(player, amount, reason)
	if amount <= 0 then
		return true
	end
	if Currency and Currency.TrySpend then
		return Currency.TrySpend(player, amount, reason) == true
	end
	return true
end

local function nextUnbuiltOrder()
	local n = math.huge
	for _, e in ipairs(entries) do
		if not e.built and e.order < n then
			n = e.order
		end
	end
	return n
end

local function updatePrompts()
	local nextO = nextUnbuiltOrder()
	for _, e in ipairs(entries) do
		if e.prompt then
			e.prompt.Enabled = (not e.built) and ((not PlacementConfig.TycoonLinearUnlock) or e.order <= nextO)
		end
	end
end

function MachineShopService.tryBuy(player, machineId)
	local e = byId[machineId]
	if not e then
		return false, "Unknown machine"
	end
	if e.built then
		return false, "Already built"
	end
	if PlacementConfig.TycoonLinearUnlock and e.order > nextUnbuiltOrder() then
		return false, "Build the previous machine first"
	end
	if not charge(player, e.cost, "buy:" .. machineId) then
		return false, "Not enough Coins"
	end
	e.built = true
	for part in pairs(e.originals) do
		part.CanCollide = true
	end
	BuildAnimation.play(e.base, e.originals)
	if e.marker then
		e.marker.Transparency = 1
		local g = e.marker:FindFirstChildWhichIsA("BillboardGui")
		if g then
			g.Enabled = false
		end
	end
	if e.prompt then
		e.prompt:Destroy()
		e.prompt = nil
	end
	updatePrompts()
	return true, "ok"
end

local function register(model, idx)
	local base = model:FindFirstChild("Base")
	if not base then
		return
	end
	local marker = model:FindFirstChild("Marker")
	local entry = {
		model = model,
		base = base,
		marker = (marker and marker:IsA("BasePart")) and marker or nil,
		prompt = nil,
		cost = model:GetAttribute("Cost") or 0,
		order = model:GetAttribute("Order") or idx,
		built = false,
		originals = BuildAnimation.capture(base),
	}
	BuildAnimation.hide(base)
	if entry.marker then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Purchase"
		prompt.ObjectText = (model:GetAttribute("Label") or model.Name)
			.. (entry.cost > 0 and (" ($" .. entry.cost .. ")") or " (FREE)")
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 14
		prompt.Enabled = false
		prompt.Parent = entry.marker
		entry.prompt = prompt
	end
	table.insert(entries, entry)
	byId[model.Name] = entry
end

function MachineShopService.Start()
	resolveCurrency()
	local factory = Workspace:FindFirstChild(PlacementConfig.FactoryFolderName)
	if not factory then
		warn("[PlacementSystem] No Workspace." .. PlacementConfig.FactoryFolderName .. " -- machine shop idle.")
		return
	end
	for i, model in ipairs(factory:GetChildren()) do
		register(model, i)
	end
	table.sort(entries, function(a, b)
		return a.order < b.order
	end)
	updatePrompts()

	local folder = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	local R = PlacementConfig.Remotes
	local buyR = folder:FindFirstChild(R.Buy)
	if not buyR then
		buyR = Instance.new("RemoteEvent")
		buyR.Name = R.Buy
		buyR.Parent = folder
	end
	local resultR = folder:WaitForChild(R.Result)
	buyR.OnServerEvent:Connect(function(player, machineId)
		if type(machineId) ~= "string" then
			return
		end
		local ok, reason = MachineShopService.tryBuy(player, machineId)
		resultR:FireClient(player, ok, reason, machineId)
	end)
end

return MachineShopService
