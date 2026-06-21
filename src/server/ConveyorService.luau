--!strict
-- Conveyor belts. Any unanchored item (a Draggable, e.g. a cookie) resting on a
-- tagged `ConveyorBelt` is carried along the belt's flow direction.
--
-- Flow direction comes from `getFlowDirection(belt, position)`:
--   * STRAIGHT belt -> the belt's own orientation (-LookVector). No marker parts
--     needed, so it works however the belt is rotated.
--   * CORNER / curved belt -> follows a path defined by the model's `Direction`
--     markers (ordered "Direction"/"Direction0", "Direction1", "Direction2", ...).
--     The item steers toward a look-ahead point on that polyline, so it curves
--     smoothly around the bend. A belt is treated as curved when it has 3+ markers.
--
-- We do NOT take network ownership of items: in a shared/solo DataModel setting the
-- velocity is enough, and grabbing ownership mid-physics made dropped cookies teleport.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))

local ConveyorService = {}

local BELT_TAG = DragConfig.ConveyorBeltTag
local ITEM_TAG = DragConfig.Tag -- only carry actual items (cookies are tagged "Draggable")
local SPEED = 4 -- studs/second the belt carries things
local ACCEL = 5 -- how quickly an item eases up to belt speed (smooths the hand-off)
local DETECT_HEIGHT = 3 -- how far above the belt to look for resting items
local DETECT_DIP = 0.1 -- start the detection box just below the surface to catch resting items
local LOOKAHEAD = 1 -- studs ahead on a curved path to steer toward (small = tracks the bend tightly)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ===== Waypoints (corner / curved belts) =====

-- Cached ordered marker parts per belt: a list (3+ = curved path) or false (straight).
local waypointCache: { [BasePart]: { BasePart } | false } = {}

local function getWaypoints(belt: BasePart): { BasePart } | false
	local cached = waypointCache[belt]
	if cached ~= nil then
		return cached
	end
	local result: { BasePart } | false = false
	local model = belt.Parent
	if model then
		local found = {}
		for _, c in ipairs(model:GetChildren()) do
			if c:IsA("BasePart") then
				local digits = c.Name:match("^Direction(%d*)$") -- "Direction", "Direction0", "Direction1", ...
				if digits then
					table.insert(found, { part = c :: BasePart, index = tonumber(digits) or 0 })
				end
			end
		end
		if #found >= 3 then
			table.sort(found, function(a, b)
				return a.index < b.index
			end)
			local parts = {}
			for _, e in ipairs(found) do
				table.insert(parts, e.part)
			end
			result = parts
		end
	end
	waypointCache[belt] = result
	return result
end

-- Steering direction along the marker polyline: nearest point on the path, then look
-- LOOKAHEAD studs further along it (extending past the last marker so items exit).
local function pathFlow(waypoints: { BasePart }, p: Vector3): Vector3
	local bestDist, bestSeg, bestT = math.huge, 1, 0
	for i = 1, #waypoints - 1 do
		local a, b = flat(waypoints[i].Position), flat(waypoints[i + 1].Position)
		local ab = b - a
		local len2 = ab:Dot(ab)
		local t = if len2 > 1e-6 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
		local pt = a + ab * t
		local d = (p - pt).Magnitude
		if d < bestDist then
			bestDist, bestSeg, bestT = d, i, t
		end
	end

	local seg, t, remaining = bestSeg, bestT, LOOKAHEAD
	local target = flat(waypoints[#waypoints].Position)
	while true do
		local a, b = flat(waypoints[seg].Position), flat(waypoints[seg + 1].Position)
		local segVec = b - a
		local segLen = segVec.Magnitude
		local toEnd = segLen * (1 - t)
		if remaining <= toEnd or seg == #waypoints - 1 then
			local dir = if segLen > 1e-6 then segVec.Unit else Vector3.zero
			target = a + dir * (segLen * t + remaining) -- may extend beyond the last marker
			break
		end
		remaining -= toEnd
		seg += 1
		t = 0
	end

	local flow = target - p
	if flow.Magnitude < 1e-4 then
		flow = flat(waypoints[bestSeg + 1].Position) - flat(waypoints[bestSeg].Position)
	end
	return if flow.Magnitude > 1e-6 then flow.Unit else Vector3.zero
end

local function getFlowDirection(belt: BasePart, position: Vector3): Vector3
	local waypoints = getWaypoints(belt)
	if waypoints then
		return pathFlow(waypoints, flat(position))
	end
	-- Tilted belt (a ramp): follow the slope via the two Direction markers (Direction0 -> Direction1),
	-- keeping the Y component so items ride up/down. Flat straights use -LookVector below.
	if math.abs(belt.CFrame.UpVector.Y) < 0.98 then
		local model = belt.Parent
		local m0 = model and model:FindFirstChild("Direction0")
		local m1 = model and model:FindFirstChild("Direction1")
		if m0 and m1 and m0:IsA("BasePart") and m1:IsA("BasePart") then
			local dir = m1.Position - m0.Position
			if dir.Magnitude > 1e-4 then
				return dir.Unit
			end
		end
		return -belt.CFrame.LookVector
	end
	return -belt.CFrame.LookVector
end

-- ===== Carrying items =====

-- Per-item ramped speed (scalar). We ramp the *target* speed up to SPEED and force the
-- velocity to it each frame -- ramping the velocity directly doesn't work since friction
-- cancels each small increment. Items not seen on any belt this frame are forgotten.
local rampSpeed: { [BasePart]: number } = {}

local function conveyBelt(belt: BasePart, alpha: number, seen: { [BasePart]: boolean })
	if not belt.Parent then
		return
	end

	local boxCF = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + DETECT_HEIGHT / 2 - DETECT_DIP, 0)
	local boxSize = Vector3.new(belt.Size.X, DETECT_HEIGHT, belt.Size.Z)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { belt.Parent :: Instance }

	for _, part in ipairs(Workspace:GetPartBoundsInBox(boxCF, boxSize, params)) do
		if not part.Anchored and part.CanCollide and CollectionService:HasTag(part, ITEM_TAG) then
			seen[part] = true
			local flow = getFlowDirection(belt, part.Position)
			local speed = rampSpeed[part] or 0
			speed += (SPEED - speed) * alpha
			rampSpeed[part] = speed
			local v = part.AssemblyLinearVelocity
			-- On a ramp (sloped flow) drive the full 3D velocity so gravity can't drag the item back
			-- down the incline; on flat belts keep the item's own vertical velocity (rest/gravity).
			local vy = if math.abs(flow.Y) > 0.05 then flow.Y * speed else v.Y
			part.AssemblyLinearVelocity = Vector3.new(flow.X * speed, vy, flow.Z * speed)
		end
	end
end

function ConveyorService.Start()
	RunService.Heartbeat:Connect(function(dt: number)
		local alpha = 1 - math.exp(-ACCEL * dt)
		local seen: { [BasePart]: boolean } = {}
		for _, belt in ipairs(CollectionService:GetTagged(BELT_TAG)) do
			if belt:IsA("BasePart") then
				conveyBelt(belt :: BasePart, alpha, seen)
			end
		end
		for part in pairs(rampSpeed) do
			if not seen[part] then
				rampSpeed[part] = nil
			end
		end
	end)
end

return ConveyorService
