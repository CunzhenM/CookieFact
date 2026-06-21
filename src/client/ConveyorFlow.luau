--!strict
-- Conveyor flow direction (client copy of the server ConveyorService logic), so faux-physics
-- bodies can ride belts on the client the same way real unanchored parts ride them on the server.
--   * STRAIGHT belt -> the belt's own facing (-LookVector). No markers needed.
--   * CORNER / curved belt -> steer along the model's `Direction` markers
--     ("Direction"/"Direction0", "Direction1", ...). 3+ markers => treated as curved.
local ConveyorFlow = {}

local LOOKAHEAD = 1 -- studs ahead on a curved path to steer toward (small = tracks the bend tightly)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

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
				local digits = c.Name:match("^Direction(%d*)$")
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
			target = a + dir * (segLen * t + remaining)
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

function ConveyorFlow.getFlowDirection(belt: BasePart, position: Vector3): Vector3
	local waypoints = getWaypoints(belt)
	if waypoints then
		return pathFlow(waypoints, flat(position))
	end
	-- Tilted belt (a ramp): follow the slope via the two Direction markers (Direction0 -> Direction1),
	-- so items ride up/down with the incline instead of being pushed flat. The returned vector keeps
	-- its Y. Flat straights fall through to the simple -LookVector below.
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

return ConveyorFlow
