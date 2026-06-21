--!strict
-- Authoritative grid placement, scoped to the player's OWN plot (from PlotService). A player can only
-- ever place/delete on their own plot. Placed machines live in a child folder; occupancy per plot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local GridUtil = require(Shared:WaitForChild("GridUtil"))
local BuildAnimation = require(Shared:WaitForChild("BuildAnimation"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local PlacementService = {}
local occupied = {}

local Currency = nil
local function resolveCurrency()
	local serverScript = ServerScriptService:FindFirstChild("Server")
	local mod = serverScript and serverScript:FindFirstChild("CurrencyService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" then
			Currency = result
			return
		end
	end
	warn("[PlacementSystem] CurrencyService not found -- placement runs free, no payouts.")
end

local function charge(player, amount, reason)
	if not (PlacementConfig.ChargeForPlacement and amount > 0) then
		return true
	end
	if Currency and Currency.TrySpend then
		return Currency.TrySpend(player, amount, reason) == true
	end
	return true
end

local function refund(player, amount, reason)
	if amount > 0 and Currency and Currency.Add then
		Currency.Add(player, amount, reason)
	end
end

local function placedFolder(plot)
	local f = plot:FindFirstChild(PlacementConfig.PlacedFolderName)
	if f and f:IsA("Folder") then
		return f
	end
	f = Instance.new("Folder")
	f.Name = PlacementConfig.PlacedFolderName
	f.Parent = plot
	return f
end

local function makeCookie()
	local tmpl = Workspace:FindFirstChild("Cookie")
	local c
	if tmpl and tmpl:IsA("BasePart") then
		c = tmpl:Clone()
		for _, ch in ipairs(c:GetChildren()) do
			if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") then
				ch:Destroy()
			end
		end
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.5, 1.6, 1.6)
		p.Color = Color3.fromRGB(170, 110, 60)
		p.Material = Enum.Material.SmoothPlastic
		c = p
	end
	c.Name = "Cookie"
	c.Anchored = false
	c.CanCollide = true
	CollectionService:AddTag(c, "Draggable")
	return c
end

-- Raw cookie dough that feeds the factory line: a Dough+Draggable clone of the Workspace "CookieDough"
-- template (a Model the client FauxPhysics sim drops/carries). Falls back to a simple ball.
local function makeDough()
	local tmpl = Workspace:FindFirstChild("CookieDough")
	local d
	if tmpl and (tmpl:IsA("Model") or tmpl:IsA("BasePart")) then
		d = tmpl:Clone()
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.8, 1.3, 1.8)
		p.Color = Color3.fromRGB(222, 184, 135)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = true
		d = p
	end
	d.Name = "CookieDough"
	CollectionService:AddTag(d, "Dough")
	CollectionService:AddTag(d, "Draggable")
	return d
end

-- Wire the dropper's glowing Spout (placed in the editable DoughDropper template; built as a fallback
-- if missing) so the OWNER can click it to drop a cookie. OwnerUserId is stamped by tryPlace.
local function setupDropper(model)
	local spout = model:FindFirstChild("Spout", true)
	if not spout then
		local body = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if not body then
			return
		end
		local p = Instance.new("Part")
		p.Name = "Spout"
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 190, 70)
		p.Size = Vector3.new(1.6, 1.4, 1.6)
		p.CFrame = body.CFrame * CFrame.new(body.Size.X / 2 + 0.6, 0, 0)
		local light = Instance.new("PointLight")
		light.Color = p.Color
		light.Brightness = 3
		light.Range = 9
		light.Parent = p
		p.Parent = model
		spout = p
	end
	local s = spout
	local click = s:FindFirstChildWhichIsA("ClickDetector") or Instance.new("ClickDetector")
	click.MaxActivationDistance = 24
	click.Parent = s
	local lastDrop = 0
	click.MouseClick:Connect(function(player)
		if model:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		local now = os.clock()
		if now - lastDrop < 0.25 then
			return
		end
		lastDrop = now
		local folder = Workspace:FindFirstChild("DroppedDough")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "DroppedDough"
			folder.Parent = Workspace
		end
		local dough = makeDough()
		dough:SetAttribute("OwnerUserId", player.UserId)
		local dropCF = s.CFrame * CFrame.new(1.2, 0, 0)
		if dough:IsA("Model") then
			dough:PivotTo(dropCF)
		else
			dough.CFrame = dropCF
			dough.AssemblyLinearVelocity = s.CFrame.RightVector * 4 + Vector3.new(0, 4, 0)
		end
		dough.Parent = folder
		-- No flat despawn timer: the client ItemLifetime removes dough only once it's abandoned off
		-- the line; a leaving owner's dough is swept in Start. Keeps on-belt / on-machine dough alive.
	end)
end

-- Clone the editable template for this machine (MachineModels.<id>); fall back to a placeholder box.
local function buildMachineVisual(machine)
	local models = Shared:FindFirstChild("MachineModels")
	local template = models and models:FindFirstChild(machine.id)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		-- Keep the model's OWN collision setup (conveyor Direction markers are CanCollide=false on
		-- purpose); just guarantee parts are anchored so a placed machine can't be shoved around.
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		if machine.id == "DoughDropper" then
			setupDropper(clone)
		end
		return clone
	end

	local part = Instance.new("Part")
	part.Name = machine.id
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = machine.color
	part.Size = Vector3.new(machine.footprint[1] * PlacementConfig.CellSize, machine.height, machine.footprint[2] * PlacementConfig.CellSize)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 1.6)
	bb.StudsOffsetWorldSpace = Vector3.new(0, machine.height / 2 + 1, 0)
	bb.MaxDistance = 120
	bb.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.5
	lbl.TextScaled = true
	lbl.Text = machine.label
	lbl.Parent = bb

	if machine.id == "DoughDropper" then
		local model = Instance.new("Model")
		model.Name = machine.id
		part.Parent = model
		model.PrimaryPart = part
		setupDropper(model)
		return model
	end
	return part
end

local CONVEYOR_BELT_HEIGHT = 2.5

local function findConveyorBelt(container)
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "ConveyorBelt") then
			return d
		end
	end
	return nil
end

local function seatModelOnSurface(container, surfaceTop)
	local belt = findConveyorBelt(container)
	if belt then
		local dy = (surfaceTop + CONVEYOR_BELT_HEIGHT) - (belt.Position.Y + belt.Size.Y / 2)
		container:PivotTo(container:GetPivot() + Vector3.new(0, dy, 0))
	else
		local boxCF, boxSize = container:GetBoundingBox()
		local dy = surfaceTop - (boxCF.Position.Y - boxSize.Y / 2)
		container:PivotTo(container:GetPivot() + Vector3.new(0, dy, 0))
	end
end

-- Conveyor belt models can be built off-center within their tile (corners especially), so snapping the
-- model's pivot to the cell center leaves the belt -- and the spot the next piece attaches to -- off-grid.
-- After seating, shift the model in XZ so the BELT pad centers on the cell. No-op for straights / non-belts.
local function centerBeltOnCell(container, cellCF)
	local belt = findConveyorBelt(container)
	if not belt then
		return
	end
	local bp = belt.Position
	local dx = cellCF.Position.X - bp.X
	local dz = cellCF.Position.Z - bp.Z
	if math.abs(dx) > 1e-3 or math.abs(dz) > 1e-3 then
		container:PivotTo(container:GetPivot() + Vector3.new(dx, 0, dz))
	end
end

local function positionContainer(container, cf)
	if container:IsA("Model") then
		container:PivotTo(cf)
	else
		container.CFrame = cf
	end
end

function PlacementService.tryPlace(player, machineId, cx, cz, rot, skipCharge)
	local plot = PlotService.getPlot(player)
	if not plot then
		return false, "You have no plot yet"
	end
	local machine = PlacementConfig.getMachine(machineId)
	if not machine then
		return false, "Unknown machine"
	end
	rot = math.floor(tonumber(rot) or 0) % 4
	cx = math.floor(tonumber(cx) or -1)
	cz = math.floor(tonumber(cz) or -1)

	local efpx, efpz = GridUtil.rotatedFootprint(machine.footprint[1], machine.footprint[2], rot)
	if not GridUtil.inBounds(plot, cx, cz, efpx, efpz) then
		return false, "Outside your plot"
	end
	local occ = occupied[plot]
	if not occ then
		occ = {}
		occupied[plot] = occ
	end
	local keys = GridUtil.occupiedKeys(cx, cz, efpx, efpz)
	-- Stacking: a machine may be placed ON TOP of a Support Block (or a stack of them). Any other
	-- occupant still blocks. supportBelow is the support we'll seat the new machine onto.
	local supportBelow = nil
	for _, k in ipairs(keys) do
		local occupant = occ[k]
		if occupant then
			if occupant:GetAttribute("MachineId") == "SupportBlock" then
				supportBelow = occupant
			else
				return false, "Space occupied"
			end
		end
	end

	if not skipCharge and not charge(player, machine.cost or 0, "place:" .. machineId) then
		return false, "Not enough Coins"
	end

	-- Seat on the support block's top when stacking, otherwise on the plot surface.
	local surfaceTop = plot.Position.Y + plot.Size.Y / 2
	if supportBelow then
		local sCf, sSize = supportBelow:GetBoundingBox()
		surfaceTop = sCf.Position.Y + sSize.Y / 2
	end
	local cf = GridUtil.blockCFrame(plot, cx, cz, efpx, efpz, machine.height, rot)
	local container = buildMachineVisual(machine)
	positionContainer(container, cf)
	if container:IsA("Model") then
		seatModelOnSurface(container, surfaceTop)
		centerBeltOnCell(container, cf)
	elseif supportBelow then
		local p = container.Position
		container.Position = Vector3.new(p.X, surfaceTop + machine.height / 2, p.Z)
	end
	container:SetAttribute("MachineId", machineId)
	container:SetAttribute("OwnerUserId", player.UserId)
	container:SetAttribute("CostPaid", (PlacementConfig.ChargeForPlacement and machine.cost) or 0)
	container:SetAttribute("CellX", cx)
	container:SetAttribute("CellZ", cz)
	container:SetAttribute("Rot", rot)
	container.Parent = placedFolder(plot)
	for _, k in ipairs(keys) do
		occ[k] = container
	end
	BuildAnimation.play(container)
	return true, "ok"
end

function PlacementService.tryDelete(player, target)
	local plot = PlotService.getPlot(player)
	if not plot then
		return false, "You have no plot yet"
	end
	local placed = placedFolder(plot)
	if typeof(target) ~= "Instance" then
		return false, "Invalid target"
	end
	local container = target
	while container and container.Parent ~= placed do
		container = container.Parent
	end
	if not container then
		return false, "Not on your plot"
	end
	local occ = occupied[plot]
	if occ then
		for k, v in pairs(occ) do
			if v == container then
				occ[k] = nil
			end
		end
	end
	local paid = container:GetAttribute("CostPaid") or 0
	refund(player, math.floor(paid * PlacementConfig.RefundFraction), "refund:" .. tostring(container:GetAttribute("MachineId")))
	container:Destroy()
	return true, "ok"
end

function PlacementService.getPlacements(player)
	local out = {}
	local plot = PlotService.getPlot(player)
	local folder = plot and plot:FindFirstChild(PlacementConfig.PlacedFolderName)
	if not folder then
		return out
	end
	for _, c in ipairs(folder:GetChildren()) do
		local id = c:GetAttribute("MachineId")
		if type(id) == "string" then
			table.insert(out, { id = id, cx = c:GetAttribute("CellX") or 0, cz = c:GetAttribute("CellZ") or 0, rot = c:GetAttribute("Rot") or 0 })
		end
	end
	return out
end

function PlacementService.restore(player, list)
	if type(list) ~= "table" then
		return
	end
	for _, e in ipairs(list) do
		if type(e) == "table" and type(e.id) == "string" then
			PlacementService.tryPlace(player, e.id, e.cx or 0, e.cz or 0, e.rot or 0, true)
		end
	end
end

function PlacementService.Start()
	resolveCurrency()

	PlotService.PlotReleased:Connect(function(plot)
		occupied[plot] = nil
		local placed = plot:FindFirstChild(PlacementConfig.PlacedFolderName)
		if placed then
			placed:ClearAllChildren()
		end
	end)

	local folder = ReplicatedStorage:FindFirstChild(PlacementConfig.RemotesFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PlacementConfig.RemotesFolderName
		folder.Parent = ReplicatedStorage
	end
	local function ensure(name)
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	local R = PlacementConfig.Remotes
	local placeR = ensure(R.Place)
	local deleteR = ensure(R.Delete)
	local resultR = ensure(R.Result)

	placeR.OnServerEvent:Connect(function(player, machineId, cx, cz, rot)
		if type(machineId) ~= "string" then
			return
		end
		local ok, reason = PlacementService.tryPlace(player, machineId, cx, cz, rot)
		resultR:FireClient(player, ok, reason, machineId)
	end)

	deleteR.OnServerEvent:Connect(function(player, target)
		local ok, reason = PlacementService.tryDelete(player, target)
		resultR:FireClient(player, ok, reason, "delete")
	end)

	-- Dropped-dough cleanup. The client (ItemLifetime) requests removal of dough it has judged
	-- abandoned; we only honor it for the Dough tag + matching owner, so it can never touch a placed
	-- machine. A leaving player's leftover dough is swept here too.
	local despawnR = ensure("RequestDespawn")
	despawnR.OnServerEvent:Connect(function(player, item)
		if
			typeof(item) == "Instance"
			and CollectionService:HasTag(item, "Dough")
			and item:GetAttribute("OwnerUserId") == player.UserId
		then
			item:Destroy()
		end
	end)

	Players.PlayerRemoving:Connect(function(leaving)
		local folder = Workspace:FindFirstChild("DroppedDough")
		if folder then
			for _, item in ipairs(folder:GetChildren()) do
				if item:GetAttribute("OwnerUserId") == leaving.UserId then
					item:Destroy()
				end
			end
		end
	end)
end

return PlacementService
