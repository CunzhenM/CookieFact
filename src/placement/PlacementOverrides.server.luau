--!strict
-- PlacementOverrides (server) -- a STANDALONE script (sibling of the partner-owned PlacementSystem)
-- that re-applies Cookie Factory placement fixes which otherwise live inside the co-developed
-- PlacementService (a parallel session keeps regenerating that file and wiping edits). Done out here
-- at runtime, idempotently, where they can't be clobbered:
--   1. A newly placed conveyor gets its belt pad centered on its grid cell (flush corners).
--   2. Dropped-dough lifetime: a RequestDespawn remote (for the client ItemLifetime) + a leaver sweep.
-- (The Dough Dropper machine itself is handled by the separate DropperMachine script.)
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local GridUtil = require(Shared:WaitForChild("GridUtil"))

local CONVEYORS = { Conveyor = true, LeftConveyor = true, RightConveyor = true }
local RAMPS = { RampUpConveyor = true, RampDownConveyor = true }

-- ===== keep the ramp template models correct on every server start =====
-- The placement MachineModels (used by fixRamp) and preview GhostModels (used by the client) are not
-- Rojo-managed, so an unsaved Studio session can lose or stale them. Rebuild the ramp entries from the
-- Workspace originals every run: exact copy -> MachineModels, half-transparent copy -> GhostModels
-- (Direction markers stay invisible). Idempotent; only touches the ramp entries, never other machines.
local function rebuildRampModels()
	local function ensureFolder(name: string): Instance
		local f = Shared:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = Shared
		end
		return f
	end
	local mm = ensureFolder("MachineModels")
	local gm = ensureFolder("GhostModels")
	for name in pairs(RAMPS) do
		local template = Workspace:FindFirstChild(name)
		if template and template:IsA("Model") then
			local old = mm:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local m = template:Clone()
			m.Name = name
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			m.Parent = mm
			local oldGhost = gm:FindFirstChild(name)
			if oldGhost then
				oldGhost:Destroy()
			end
			local g = template:Clone()
			g.Name = name
			for _, d in ipairs(g:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.Transparency = math.max(0.5, d.Transparency)
				end
			end
			g.Parent = gm
		end
	end
end
rebuildRampModels()

-- ===== center a placed conveyor's belt on its cell =====

local function plotOf(model: Instance): BasePart?
	local placed = model.Parent
	local plot = placed and placed.Parent
	return (plot and plot:IsA("BasePart")) and plot or nil
end

local function findBelt(container: Instance): BasePart?
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "ConveyorBelt") then
			return d
		end
	end
	return nil
end

local function centerConveyor(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local belt = findBelt(model)
	local plot = plotOf(model)
	if not (belt and plot) then
		return
	end
	local id = model:GetAttribute("MachineId")
	local cx = model:GetAttribute("CellX")
	local cz = model:GetAttribute("CellZ")
	local rot = model:GetAttribute("Rot") or 0
	local m = (typeof(id) == "string") and PlacementConfig.getMachine(id) or nil
	if not (m and typeof(cx) == "number" and typeof(cz) == "number") then
		return
	end
	local efpx, efpz = GridUtil.rotatedFootprint(m.footprint[1], m.footprint[2], rot)
	local cf = GridUtil.blockCFrame(plot, cx, cz, efpx, efpz, m.height, rot)
	local bp = belt.Position
	local dx, dz = cf.Position.X - bp.X, cf.Position.Z - bp.Z
	if math.abs(dx) > 1e-3 or math.abs(dz) > 1e-3 then
		model:PivotTo(model:GetPivot() + Vector3.new(dx, 0, dz))
	end
end

-- Lowest world-Y point of a tagged belt slab (its low-end edge). Used to seat a ramp so its belt
-- starts at floor level. Falls back to the model's bbox bottom if there's no tagged belt.
local function lowestBeltY(model: Instance): number
	local belt = findBelt(model)
	if belt then
		local cf, s = belt.CFrame, belt.Size
		local extentY = 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
		return belt.Position.Y - extentY
	end
	local bbCF, bbSize = model:GetBoundingBox()
	return bbCF.Position.Y - bbSize.Y / 2
end

-- The surface a ramp should sit on: the top of a Support Block sharing its cell (so ramps stack on
-- supports like other machines), else the plot floor.
local function surfaceBelow(model: Instance, plot: BasePart): number
	local floor = plot.Position.Y + plot.Size.Y / 2
	local id = model:GetAttribute("MachineId")
	local m = (typeof(id) == "string") and PlacementConfig.getMachine(id) or nil
	local cx = model:GetAttribute("CellX")
	local cz = model:GetAttribute("CellZ")
	local placed = model.Parent
	if not (m and placed and typeof(cx) == "number" and typeof(cz) == "number") then
		return floor
	end
	local rot = (model:GetAttribute("Rot") :: number?) or 0
	local efpx, efpz = GridUtil.rotatedFootprint(m.footprint[1], m.footprint[2], rot)
	local want = {}
	for _, k in ipairs(GridUtil.occupiedKeys(cx, cz, efpx, efpz)) do
		want[k] = true
	end
	local sm = PlacementConfig.getMachine("SupportBlock")
	for _, c in ipairs(placed:GetChildren()) do
		if c ~= model and sm and c:GetAttribute("MachineId") == "SupportBlock" then
			local scx = c:GetAttribute("CellX")
			local scz = c:GetAttribute("CellZ")
			if typeof(scx) == "number" and typeof(scz) == "number" then
				local sfx, sfz = GridUtil.rotatedFootprint(sm.footprint[1], sm.footprint[2], (c:GetAttribute("Rot") :: number?) or 0)
				for _, k in ipairs(GridUtil.occupiedKeys(scx, scz, sfx, sfz)) do
					if want[k] then
						local cf, size = c:GetBoundingBox()
						return cf.Position.Y + size.Y / 2
					end
				end
			end
		end
	end
	return floor
end

-- Ramps are built tilted in their MODEL PIVOT (e.g. 33deg about X); the partner's
-- PivotTo(blockCFrame) snaps the pivot flat, flattening the ramp. Restore the template's exact
-- pivot rotation (turned by the placement yaw), then seat the belt's low end on the surface below.
local function fixRamp(model: Instance)
	local mm = Shared:FindFirstChild("MachineModels")
	local id = model:GetAttribute("MachineId")
	local template = mm and typeof(id) == "string" and mm:FindFirstChild(id) or nil
	local plot = plotOf(model)
	if not (template and plot) then
		return
	end
	local rot = (model:GetAttribute("Rot") :: number?) or 0
	-- 1) exact template tilt, turned by the placement yaw
	model:PivotTo(CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, math.rad(90 * rot), 0) * template:GetPivot().Rotation)
	-- 2) center the bounding box on the cell, and seat the BELT's low end on the surface below (the
	--    plot floor, or a Support Block's top when stacking) so the belt starts at that level.
	local m = PlacementConfig.getMachine(id)
	local cx = model:GetAttribute("CellX")
	local cz = model:GetAttribute("CellZ")
	local bbCF = model:GetBoundingBox()
	local dx, dz = 0, 0
	if m and typeof(cx) == "number" and typeof(cz) == "number" then
		local efpx, efpz = GridUtil.rotatedFootprint(m.footprint[1], m.footprint[2], rot)
		local cf = GridUtil.blockCFrame(plot, cx, cz, efpx, efpz, m.height, rot)
		dx, dz = cf.Position.X - bbCF.Position.X, cf.Position.Z - bbCF.Position.Z
	end
	local surface = surfaceBelow(model, plot)
	model:PivotTo(model:GetPivot() + Vector3.new(dx, surface - lowestBeltY(model), dz))
end

local function onPlacedMachine(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local id = model:GetAttribute("MachineId")
	if typeof(id) == "string" and CONVEYORS[id] then
		task.spawn(function()
			task.wait(0.6) -- let the partner's seat + build-animation finish first
			centerConveyor(model)
		end)
	elseif typeof(id) == "string" and RAMPS[id] then
		task.spawn(function()
			-- Wait until the partner's BuildAnimation has FULLY settled before tilting. Its staggered
			-- per-part tweens snap each part back to the flat captured pose; a fixed timer races them
			-- (under load the belt ends up barely tilted -> flat-fallback flow sends items downhill), so
			-- poll the bounding box until it stops moving instead.
			local lastCF, lastSize = model:GetBoundingBox()
			local stable = 0
			for _ = 1, 160 do
				task.wait(0.05)
				if not model.Parent then
					return
				end
				local cf, size = model:GetBoundingBox()
				if (cf.Position - lastCF.Position).Magnitude < 1e-3 and (size - lastSize).Magnitude < 1e-3 then
					stable += 1
					if stable >= 4 then
						break
					end
				else
					stable = 0
				end
				lastCF, lastSize = cf, size
			end
			fixRamp(model)
		end)
	end
end

for _, plot in ipairs(Workspace:GetChildren()) do
	if plot.Name:match("^Plot%d+$") then
		local placed = plot:FindFirstChild("PlacedMachines")
		if placed then
			for _, m in ipairs(placed:GetChildren()) do
				onPlacedMachine(m)
			end
		end
	end
end
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and inst:GetAttribute("MachineId") ~= nil then
		onPlacedMachine(inst)
	end
end)

-- ===== dropped-dough lifetime (server side for the client ItemLifetime) =====

local remotes = ReplicatedStorage:FindFirstChild("PlacementRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "PlacementRemotes"
	remotes.Parent = ReplicatedStorage
end
local despawnR = remotes:FindFirstChild("RequestDespawn")
if not despawnR then
	local r = Instance.new("RemoteEvent")
	r.Name = "RequestDespawn"
	r.Parent = remotes
	despawnR = r
end
;(despawnR :: RemoteEvent).OnServerEvent:Connect(function(player, item)
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

print("[PlacementOverrides] online")
