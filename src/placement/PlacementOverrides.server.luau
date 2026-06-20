--!strict
-- PlacementOverrides (server) -- a STANDALONE script (sibling of the partner-owned PlacementSystem)
-- that re-applies the Cookie Factory fixes which otherwise live inside the co-developed
-- PlacementService. Because a parallel session keeps regenerating PlacementService and wiping those
-- edits, we do them out here at runtime instead, where they can't be clobbered:
--   1. Dough Dropper drops DOUGH (Workspace.CookieDough), not cookies.
--   2. A newly placed conveyor gets its belt pad centered on its grid cell (flush corners).
--   3. Dropped-dough lifetime: a RequestDespawn remote (for the client ItemLifetime) + a leaver sweep.
-- All operations are idempotent, so if PlacementService later does these itself, this is a no-op.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local GridUtil = require(Shared:WaitForChild("GridUtil"))

local CONVEYORS = { Conveyor = true, LeftConveyor = true, RightConveyor = true }

-- ===== 1. Dough dropper drops dough =====

local function makeDough(): Instance
	local tmpl = Workspace:FindFirstChild("CookieDough")
	local d: Instance
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

local function rewireDropper(model: Instance)
	if model:GetAttribute("CFDoughWired") then
		return
	end
	local spout = model:FindFirstChild("Spout", true)
	for _ = 1, 20 do -- the spout may be added a frame or two after the model
		if spout then
			break
		end
		task.wait(0.1)
		spout = model:FindFirstChild("Spout", true)
	end
	if not (spout and spout:IsA("BasePart")) then
		return
	end
	model:SetAttribute("CFDoughWired", true)
	for _, ch in ipairs(spout:GetChildren()) do
		if ch:IsA("ClickDetector") then
			ch:Destroy() -- drop the partner's cookie click handler
		end
	end
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 24
	click.Parent = spout
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
		local dropCF = (spout :: BasePart).CFrame * CFrame.new(1.2, 0, 0)
		if dough:IsA("Model") then
			dough:PivotTo(dropCF)
		elseif dough:IsA("BasePart") then
			dough.CFrame = dropCF
			dough.AssemblyLinearVelocity = (spout :: BasePart).CFrame.RightVector * 4 + Vector3.new(0, 4, 0)
		end
		dough.Parent = folder
	end)
end

-- ===== 2. Center a placed conveyor's belt on its cell =====

local function plotOf(model: Instance): BasePart?
	local placed = model.Parent -- PlacedMachines folder
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
	if not (model:IsA("Model")) then
		return
	end
	local id = model:GetAttribute("MachineId")
	if id == "DoughDropper" then
		task.spawn(rewireDropper, model)
	elseif typeof(id) == "string" and CONVEYORS[id] then
		task.spawn(function()
			task.wait(0.6) -- let the partner's seat + build-animation finish first
			centerConveyor(model)
		end)
	end
end

-- Process machines already placed, then watch for new ones (tryPlace stamps the attributes before
-- it parents the model, so DescendantAdded already sees MachineId).
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

-- ===== 3. Dropped-dough lifetime (server side for the client ItemLifetime) =====

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
