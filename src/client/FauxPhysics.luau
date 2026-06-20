--!strict
-- Faux rigid-body physics for draggables that can't actually be unanchored.
--
-- CookieDough is a Model made of ~27 separate anchored pieces. Unanchoring it would
-- let the pieces scatter, and welding them is fiddly. Instead we keep every piece
-- anchored and move the WHOLE model as one rigid box via PivotTo, integrating the
-- same gravity the engine uses (Workspace.Gravity) ourselves. Collision is a single
-- Blockcast of the model's bounding box along its motion each step.
--
-- Rule: a draggable uses faux physics unless it is a single unanchored BasePart
-- (those, like the Cookie, fall through the real engine instead).
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))
local ConveyorFlow = require(script.Parent:WaitForChild("ConveyorFlow"))

local FauxPhysics = {}

local BELT_TAG = DragConfig.ConveyorBeltTag
local CONVEY_SPEED = 4 -- studs/sec a belt carries a resting faux body (matches server ConveyorService)
local SKIN = 0.05 -- small gap kept from surfaces to avoid clipping
local MAX_STEP = 1 / 30 -- clamp dt so a frame hitch can't tunnel the body through the floor
local KILL_Y = -500 -- give up simulating anything that falls into the void

type Body = { velocity: Vector3, grounded: boolean, gravityScale: number, conveying: boolean? }
local bodies: { [Instance]: Body } = {}

-- Callbacks fired (with the root) the moment a body settles and goes to sleep.
local restCallbacks: { (Instance) -> () } = {}
function FauxPhysics.OnRest(callback: (Instance) -> ())
	table.insert(restCallbacks, callback)
end

function FauxPhysics.IsFaux(root: Instance): boolean
	return not (root:IsA("BasePart") and not (root :: BasePart).Anchored)
end

local function getBox(root: Instance): (CFrame, Vector3)
	if root:IsA("Model") then
		return root:GetBoundingBox()
	end
	local part = root :: BasePart
	return part.CFrame, part.Size
end

-- Swept box that ignores non-collidable hits, so the body only ever sticks to a
-- surface it could physically touch -- not decorations, lights, signage, or other
-- non-collidable-but-queryable parts.
local function castCollidable(cf: CFrame, size: Vector3, move: Vector3, root: Instance): RaycastResult?
	local excludes: { Instance } = { root }
	for _ = 1, 12 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		local result = Workspace:Blockcast(cf, size, move, params)
		if not result then
			return nil
		end
		if result.Instance.CanCollide then
			return result
		end
		table.insert(excludes, result.Instance)
	end
	return nil
end

function FauxPhysics.Stop(root: Instance)
	bodies[root] = nil
end

function FauxPhysics.IsActive(root: Instance): boolean
	return bodies[root] ~= nil
end

-- Begin (or restart) simulating `root` with an initial velocity. Used both to make
-- objects fall on spawn (zero velocity) and to fling them on release. `gravityScale`
-- lightens gravity for the throw (1 = normal); it lasts until the body comes to rest.
function FauxPhysics.Launch(root: Instance, velocity: Vector3, gravityScale: number?)
	if not root:IsDescendantOf(Workspace) then
		return
	end
	bodies[root] = { velocity = velocity, grounded = false, gravityScale = gravityScale or 1 }
end

-- Shortest rotation taking unit vector `a` onto unit vector `b`.
local function rotationBetween(a: Vector3, b: Vector3): CFrame
	local ua, ub = a.Unit, b.Unit
	local d = math.clamp(ua:Dot(ub), -1, 1)
	if d > 0.9999 then
		return CFrame.identity
	elseif d < -0.9999 then
		local axis = ua:Cross(Vector3.xAxis)
		if axis.Magnitude < 1e-3 then
			axis = ua:Cross(Vector3.yAxis)
		end
		return CFrame.fromAxisAngle(axis.Unit, math.pi)
	end
	return CFrame.fromAxisAngle(ua:Cross(ub).Unit, math.acos(d))
end

-- On first contact, lay the body flush against the surface (its up axis = the surface
-- normal, so the flat bottom is parallel) and leave it stuck there -- no bounce/slide.
local function stickToSurface(root: Instance, center: Vector3, size: Vector3, move: Vector3, result: RaycastResult)
	local allowed = math.max(0, result.Distance - SKIN)
	local translate = if move.Magnitude > 1e-6 then move.Unit * allowed else Vector3.zero
	local pivotT = root:GetPivot() + translate
	local centreT = center + translate

	-- Tilt so the body's up axis matches the surface normal (rotate about its centre).
	local n = result.Normal.Unit
	local rotAlign = rotationBetween(pivotT.UpVector, n)
	local pivotR = (CFrame.new(centreT) * rotAlign * CFrame.new(-centreT)) * pivotT

	-- Slide along the normal so the bottom face rests on the surface.
	local halfThickness = size.Y / 2
	local distCentre = (centreT - result.Position):Dot(n)
	root:PivotTo(pivotR + n * ((halfThickness + SKIN) - distCentre))
end

-- The ConveyorBelt-tagged part directly under a resting body (or nil). Lets a settled faux
-- body keep riding a belt instead of sleeping. Uses the belts' own bounds, so it never snags
-- on the non-collidable Direction markers above the belt.
local function beltUnder(root: Instance): BasePart?
	local cf, size = getBox(root)
	local boxCF = cf * CFrame.new(0, -size.Y / 2, 0)
	local boxSize = Vector3.new(math.max(size.X * 0.5, 1), 1.2, math.max(size.Z * 0.5, 1))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = CollectionService:GetTagged(BELT_TAG)
	local hits = Workspace:GetPartBoundsInBox(boxCF, boxSize, params)
	return hits[1]
end

local function step(root: Instance, body: Body, dt: number)
	if not root.Parent then
		bodies[root] = nil
		return
	end

	local cf, size = getBox(root)
	local center = cf.Position
	if center.Y < KILL_Y then
		bodies[root] = nil
		return
	end

	-- Resting on a conveyor belt: ride it along the flow instead of sleeping. It only settles
	-- (and fires OnRest -> baking) once it rolls off the belt onto something else (next belt / oven).
	if body.conveying then
		local belt = beltUnder(root)
		if belt then
			local flow = ConveyorFlow.getFlowDirection(belt, center)
			local delta = Vector3.new(flow.X, 0, flow.Z) * CONVEY_SPEED * dt
			if delta.Magnitude > 1e-6 then
				root:PivotTo(root:GetPivot() + delta)
			end
			return
		end
		-- Rolled off the belt: drop back into gravity so it settles on whatever comes next.
		body.conveying = false
		body.velocity = Vector3.zero
	end

	-- Integrate gravity (matches the engine, optionally lightened) and a touch of air drag.
	local v = body.velocity + Vector3.new(0, -Workspace.Gravity * body.gravityScale, 0) * dt
	v *= math.max(0, 1 - DragConfig.AirDrag * dt)

	local move = v * dt
	if move.Magnitude < 1e-5 then
		body.velocity = v
		return
	end

	local result = castCollidable(cf, size, move, root)
	if result then
		-- First collidable thing it touches: align flush to that surface and stick.
		stickToSurface(root, center, size, move, result)
		-- Landed on a belt? Start conveying instead of sleeping (and don't bake yet).
		if CollectionService:HasTag(result.Instance, BELT_TAG) or beltUnder(root) then
			body.conveying = true
			body.velocity = Vector3.zero
			return
		end
		bodies[root] = nil
		for _, cb in ipairs(restCallbacks) do
			task.spawn(cb, root)
		end
		return
	end

	-- Still airborne.
	body.velocity = v
	root:PivotTo(root:GetPivot() + move)
end

function FauxPhysics.Start()
	-- Every faux-physics draggable falls under gravity from the start, as if it were
	-- unanchored.
	local function consider(inst: Instance)
		if (inst:IsA("Model") or inst:IsA("BasePart")) and FauxPhysics.IsFaux(inst) then
			FauxPhysics.Launch(inst, Vector3.zero)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(DragConfig.Tag)) do
		consider(inst)
	end
	CollectionService:GetInstanceAddedSignal(DragConfig.Tag):Connect(consider)

	RunService.Heartbeat:Connect(function(dt: number)
		dt = math.min(dt, MAX_STEP)
		for root, body in pairs(bodies) do
			step(root, body, dt)
		end
	end)
end

return FauxPhysics
