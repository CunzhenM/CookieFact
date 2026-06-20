--!strict
-- Replaces the deleted "Extremely Fast Conveyor Belt": while the local player stands on a Road
-- "SideWalk" part, boost WalkSpeed; stepping off restores normal. Client-side for responsiveness.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SidewalkController = {}

local BOOST_SPEED = 28
local CHECK_INTERVAL = 0.1
local RAY_DOWN = Vector3.new(0, -7, 0)

local function isSidewalk(inst)
	return inst ~= nil and inst.Name:lower():find("sidewalk") ~= nil
end

function SidewalkController.Start()
	local player = Players.LocalPlayer
	local normalSpeed = 16
	local boosted = false
	local acc = 0

	local function onChar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			normalSpeed = hum.WalkSpeed
		end
		boosted = false
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end

	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < CHECK_INTERVAL then
			return
		end
		acc = 0
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp) or hum.Health <= 0 then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = Workspace:Raycast(hrp.Position, RAY_DOWN, params)
		local onSidewalk = hit ~= nil and isSidewalk(hit.Instance)
		if onSidewalk and not boosted then
			normalSpeed = hum.WalkSpeed
			hum.WalkSpeed = BOOST_SPEED
			boosted = true
		elseif not onSidewalk and boosted then
			hum.WalkSpeed = normalSpeed
			boosted = false
		end
	end)
end

return SidewalkController
