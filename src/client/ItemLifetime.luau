--!strict
-- Lifetime for dropped dough. It despawns dough ONLY once it's been abandoned -- resting on a
-- non-placeable surface (e.g. the floor), not moving, and not baking -- for a grace period. Dough
-- sitting on a conveyor / placed machine, in transit (airborne or dragged), or baking never despawns.
--
-- Runs on the client because dough moves via client faux-physics, so only the client knows where it
-- actually is; the server (ItemLifetime's RequestDespawn handler) does the validated Destroy. Only the
-- dough's owner manages its own dough, so two clients can't fight over it.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CookConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CookConfig"))

local ItemLifetime = {}

local DOUGH_TAG = CookConfig.DoughTag or "Dough"
local GRACE = 20 -- seconds resting off the line before despawn
local POLL = 0.5 -- seconds between checks
local MOVE_EPSILON = 0.15 -- studs of motion that still counts as "in play"

local player = Players.LocalPlayer

local function centerSize(inst: Instance): (Vector3, Vector3)
	if inst:IsA("Model") then
		local cf, size = (inst :: Model):GetBoundingBox()
		return cf.Position, size
	end
	local p = inst :: BasePart
	return p.Position, p.Size
end

-- Returns (resting, onPlaceable). resting=false means airborne (in transit / held -> keep).
-- onPlaceable=true means it's sitting on a conveyor belt or any placed machine -> keep.
local function groundCheck(inst: Instance): (boolean, boolean)
	local pos, size = centerSize(inst)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { inst }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(pos, Vector3.new(0, -(size.Y / 2 + 1), 0), params)
	if not hit then
		return false, false
	end
	if CollectionService:HasTag(hit.Instance, "ConveyorBelt") then
		return true, true
	end
	local a: Instance? = hit.Instance
	while a and a ~= Workspace do
		if a:GetAttribute("MachineId") ~= nil then
			return true, true
		end
		a = a.Parent
	end
	return true, false
end

local function isBaking(inst: Instance): boolean
	return inst:FindFirstChild("CookTimer", true) ~= nil
end

function ItemLifetime.Start()
	local remotes = ReplicatedStorage:WaitForChild("PlacementRemotes")
	local despawnR = remotes:WaitForChild("RequestDespawn") :: RemoteEvent

	local idle: { [Instance]: number } = {}
	local lastPos: { [Instance]: Vector3 } = {}

	task.spawn(function()
		while true do
			task.wait(POLL)
			for _, item in ipairs(CollectionService:GetTagged(DOUGH_TAG)) do
				if item:IsDescendantOf(Workspace) and item:GetAttribute("OwnerUserId") == player.UserId then
					local pos = (centerSize(item))
					local moved = lastPos[item] == nil or (pos - lastPos[item]).Magnitude > MOVE_EPSILON
					lastPos[item] = pos
					local resting, placeable = groundCheck(item)
					if moved or not resting or placeable or isBaking(item) then
						idle[item] = 0
					else
						idle[item] = (idle[item] or 0) + POLL
						if idle[item] >= GRACE then
							idle[item] = nil
							lastPos[item] = nil
							despawnR:FireServer(item)
						end
					end
				end
			end
			for item in pairs(idle) do
				if not item:IsDescendantOf(Workspace) then
					idle[item] = nil
					lastPos[item] = nil
				end
			end
		end
	end)
end

return ItemLifetime
