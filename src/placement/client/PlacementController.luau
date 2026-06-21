--!strict
-- Client placement brain: ghost preview on the player's OWN plot. Uses the transparent conveyor
-- model as the ghost when one exists (GhostModels), else a solid box w/ name + facing nose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local GridUtil = require(Shared:WaitForChild("GridUtil"))
local CELL = PlacementConfig.CellSize

local PlacementController = {}
local modeChanged = Instance.new("BindableEvent")
PlacementController.ModeChanged = modeChanged.Event
local resultChanged = Instance.new("BindableEvent")
PlacementController.ResultChanged = resultChanged.Event

local player
local camera
local mode = "none"
local selectedId = nil
local rotSteps = 0
local ghost = nil
local ghostIsModel = false
local ghostHighlight = nil
local ghostNose = nil
local ghostTargetCF = nil
local lastValid = false
local lastCX, lastCZ = 0, 0
local deleteHover = nil
local deleteHighlight = nil
local placeR, deleteR, resultR

local function getArea()
	local plotName = player:GetAttribute("PlotName")
	if not plotName then
		return nil
	end
	local a = Workspace:FindFirstChild(plotName)
	return (a and a:IsA("BasePart")) and a or nil
end

local function getPlaced()
	local area = getArea()
	return area and area:FindFirstChild(PlacementConfig.PlacedFolderName)
end

local function canAfford(cost)
	local currency = player:FindFirstChild("Currency")
	local coins = currency and currency:FindFirstChild("Coins")
	if coins and coins:IsA("NumberValue") then
		return coins.Value >= cost
	end
	return true
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost = nil
	ghostIsModel = false
	ghostHighlight = nil
	ghostNose = nil
	ghostTargetCF = nil
end

local function buildGhost(machine)
	clearGhost()
	local ghostModels = Shared:FindFirstChild("GhostModels")
	local template = ghostModels and ghostModels:FindFirstChild(machine.id)
	if template and template:IsA("Model") then
		local clone = template:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local hl = Instance.new("Highlight")
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.OutlineColor = PlacementConfig.OutlineColor
		hl.FillColor = PlacementConfig.GhostColorValid
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0
		hl.Adornee = clone
		hl.Parent = clone
		clone.Parent = Workspace
		ghost = clone
		ghostHighlight = hl
		ghostIsModel = true
		return
	end

	local part = Instance.new("Part")
	part.Name = "PlacementGhost"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = machine.color
	part.Transparency = 0.25
	part.Size = Vector3.new(machine.footprint[1] * CELL - 0.2, machine.height, machine.footprint[2] * CELL - 0.2)
	local hl = Instance.new("Highlight")
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.OutlineColor = PlacementConfig.OutlineColor
	hl.FillColor = PlacementConfig.GhostColorValid
	hl.FillTransparency = 0.7
	hl.OutlineTransparency = 0
	hl.Parent = part
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 1.4)
	bb.StudsOffsetWorldSpace = Vector3.new(0, machine.height / 2 + 1.5, 0)
	bb.AlwaysOnTop = true
	bb.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.4
	lbl.Text = machine.label
	lbl.Parent = bb
	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Anchored = true
	nose.CanCollide = false
	nose.CanQuery = false
	nose.CanTouch = false
	nose.Material = Enum.Material.Neon
	nose.Color = Color3.fromRGB(255, 240, 120)
	nose.Size = Vector3.new(math.max(1, part.Size.X * 0.5), 0.4, 1.2)
	nose.Parent = part
	part.Parent = Workspace
	ghost = part
	ghostHighlight = hl
	ghostNose = nose
end

local function paintGhost(valid)
	if not ghostHighlight then
		return
	end
	ghostHighlight.FillColor = valid and PlacementConfig.GhostColorValid or PlacementConfig.GhostColorInvalid
	ghostHighlight.OutlineColor = valid and PlacementConfig.OutlineColor or PlacementConfig.GhostColorInvalid
end

local function mouseRay()
	local pos = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(pos.X, pos.Y)
end

-- Cell occupancy rebuilt from the placed machines' stored attributes -- the SAME logical-cell test
-- the server uses in tryPlace. We deliberately do NOT test part geometry: conveyor models (corners
-- especially) overhang their tile so belts meet seamlessly, and a geometric query would false-flag
-- those intentional overlaps as "occupied". A spot is invalid only if it shares a GRID CELL with an
-- existing machine; slight visual overlap at the seams is allowed.
local function buildOccupancy(placed)
	local occ = {}
	if not placed then
		return occ
	end
	for _, c in ipairs(placed:GetChildren()) do
		local id = c:GetAttribute("MachineId")
		local mcx = c:GetAttribute("CellX")
		local mcz = c:GetAttribute("CellZ")
		local mrot = c:GetAttribute("Rot") or 0
		local m = (type(id) == "string") and PlacementConfig.getMachine(id) or nil
		-- Support Blocks don't block their cell -- you're allowed to place a machine on top of one.
		if m and mcx and mcz and id ~= "SupportBlock" then
			local fx, fz = GridUtil.rotatedFootprint(m.footprint[1], m.footprint[2], mrot)
			for _, k in ipairs(GridUtil.occupiedKeys(mcx, mcz, fx, fz)) do
				occ[k] = true
			end
		end
	end
	return occ
end

local function cellsConflict(occ, cx, cz, efpx, efpz)
	for _, k in ipairs(GridUtil.occupiedKeys(cx, cz, efpx, efpz)) do
		if occ[k] then
			return true
		end
	end
	return false
end

local function updateGhost(dt)
	local area = getArea()
	local machine = selectedId and PlacementConfig.getMachine(selectedId)
	if not area or not machine or not ghost then
		return
	end
	local ray = mouseRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { area }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
	local efpx, efpz = GridUtil.rotatedFootprint(machine.footprint[1], machine.footprint[2], rotSteps)
	local nx, nz = GridUtil.dimensions(area)
	if hit and nx >= efpx and nz >= efpz then
		local cx, cz = GridUtil.minCornerFromWorld(area, hit.Position, efpx, efpz)
		cx = math.clamp(cx, 0, nx - efpx)
		cz = math.clamp(cz, 0, nz - efpz)
		lastCX, lastCZ = cx, cz
		ghostTargetCF = GridUtil.blockCFrame(area, cx, cz, efpx, efpz, machine.height, rotSteps)
		-- Tilted models (ramps): preview them EXACTLY as placed -- keep the tilt, seat the BELT's low
		-- end on the plot surface (belt starts at floor level), and center the bounding box on the cell.
		local gm = Shared:FindFirstChild("GhostModels")
		local gt = gm and gm:FindFirstChild(machine.id)
		if ghost and gt and math.abs(gt:GetPivot().UpVector.Y) < 0.98 then
			local oriented = CFrame.new(ghostTargetCF.Position) * CFrame.Angles(0, math.rad(90 * rotSteps), 0) * gt:GetPivot().Rotation
			ghost:PivotTo(oriented)
			local bbCF, bbSize = ghost:GetBoundingBox()
			-- lowest world-Y of the belt slab (its low end); fall back to the bbox bottom
			local lowY = bbCF.Position.Y - bbSize.Y / 2
			for _, d in ipairs(ghost:GetDescendants()) do
				if d:IsA("BasePart") and d:HasTag("ConveyorBelt") then
					local cf, s = d.CFrame, d.Size
					lowY = d.Position.Y - 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
					break
				end
			end
			local surface = area.Position.Y + area.Size.Y / 2
			ghostTargetCF = oriented + Vector3.new(
				ghostTargetCF.Position.X - bbCF.Position.X,
				surface - lowY,
				ghostTargetCF.Position.Z - bbCF.Position.Z
			)
		end
		local occ = buildOccupancy(getPlaced())
		local overlap = cellsConflict(occ, cx, cz, efpx, efpz)
		lastValid = (not overlap) and canAfford(machine.cost or 0)
		paintGhost(lastValid)
	end
	if ghostTargetCF then
		local alpha = 1 - math.exp(-PlacementConfig.GhostSmoothing * dt)
		ghost:PivotTo(ghost:GetPivot():Lerp(ghostTargetCF, alpha))
		if ghostNose and not ghostIsModel then
			local box = ghost
			ghostNose.CFrame = box.CFrame * CFrame.new(0, box.Size.Y / 2 + 0.1, -box.Size.Z / 2)
		end
	end
end

local function clearDeleteHover()
	if deleteHighlight then
		deleteHighlight:Destroy()
		deleteHighlight = nil
	end
	deleteHover = nil
end

local function updateDelete()
	local placed = getPlaced()
	if not placed then
		clearDeleteHover()
		return
	end
	local ray = mouseRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { placed }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local container = nil
	if hit then
		container = hit.Instance
		while container and container.Parent ~= placed do
			container = container.Parent
		end
	end
	if container ~= deleteHover then
		clearDeleteHover()
		if container then
			local hl = Instance.new("Highlight")
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillColor = PlacementConfig.DeleteHighlightColor
			hl.OutlineColor = PlacementConfig.DeleteHighlightColor
			hl.FillTransparency = 0.45
			hl.Adornee = container
			hl.Parent = container
			deleteHighlight = hl
			deleteHover = container
		end
	end
end

function PlacementController.exit()
	mode = "none"
	selectedId = nil
	rotSteps = 0
	clearGhost()
	clearDeleteHover()
	modeChanged:Fire(mode, nil)
end

function PlacementController.enterPlace(machineId)
	local machine = PlacementConfig.getMachine(machineId)
	if not machine then
		return
	end
	mode = "place"
	selectedId = machineId
	rotSteps = 0
	clearDeleteHover()
	buildGhost(machine)
	modeChanged:Fire(mode, machineId)
end

function PlacementController.enterDelete()
	mode = "delete"
	selectedId = nil
	clearGhost()
	modeChanged:Fire(mode, nil)
end

function PlacementController.getMode()
	return mode
end

local function onInput(input, gameProcessed)
	if gameProcessed or mode == "none" then
		return
	end
	local kc = input.KeyCode
	if kc == Enum.KeyCode.X then
		PlacementController.exit()
		return
	end
	if mode == "place" then
		if kc == Enum.KeyCode.R then
			rotSteps = (rotSteps + 1) % 4
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if lastValid and selectedId then
				placeR:FireServer(selectedId, lastCX, lastCZ, rotSteps)
			end
		end
	elseif mode == "delete" then
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if deleteHover then
				deleteR:FireServer(deleteHover)
			end
		end
	end
end

function PlacementController.Start()
	player = Players.LocalPlayer
	camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")
	local remotes = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	placeR = remotes:WaitForChild(PlacementConfig.Remotes.Place)
	deleteR = remotes:WaitForChild(PlacementConfig.Remotes.Delete)
	resultR = remotes:WaitForChild(PlacementConfig.Remotes.Result)
	resultR.OnClientEvent:Connect(function(ok, reason)
		resultChanged:Fire(ok, reason)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if mode == "place" then
			updateGhost(dt)
		elseif mode == "delete" then
			updateDelete()
		end
	end)
	UserInputService.InputBegan:Connect(onInput)
end

return PlacementController
