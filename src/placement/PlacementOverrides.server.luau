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
