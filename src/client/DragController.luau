--!strict
-- Client side of the drag system (third person).
--
-- Hover a tagged object to outline it. Hold the left mouse button (or touch) on it
-- to grab; release to drop. While held:
--   * The object is held along the camera->cursor direction, anchored at the PLAYER
--     and kept at `dragDistance`. So: orbiting the camera swings it around, walking
--     carries it by the same amount, and the mouse wheel changes its distance.
--   * It eases toward that target with heavy exponential smoothing.
--   * A solid white Highlight outlines it, and the DragVFX beam runs from the
--     player's origin (VFX_Attachment) to the object (Attachment1).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))
local FauxPhysics = require(script.Parent:WaitForChild("FauxPhysics"))

local DragController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remotes created by the server's DragService.
local remotes = ReplicatedStorage:WaitForChild(DragConfig.RemotesFolder)
local requestRemote = remotes:WaitForChild(DragConfig.RequestRemote) :: RemoteEvent
local releaseRemote = remotes:WaitForChild(DragConfig.ReleaseRemote) :: RemoteEvent

-- The shared drag VFX beam that lives in the Workspace.
local dragVFX = Workspace:WaitForChild("DragVFX") :: BasePart
local vfxEnd = dragVFX:WaitForChild("Attachment1") :: Attachment
local vfxBeam: Beam? = nil
for _, d in ipairs(dragVFX:GetDescendants()) do
	if d:IsA("Beam") then
		vfxBeam = d
		break
	end
end

-- Drag state.
local dragging = false
local dragRoot: Instance? = nil
local dragParts: { BasePart } = {}
local smoothedPos = Vector3.zero
local lockedRotation = CFrame.identity
local dragVelocity = Vector3.zero -- smoothed motion of the object, used as throw velocity on release
local dragSmoothing = DragConfig.Smoothing -- smoothing in use for the current drag (depends on camera mode)
local dragFirstPerson = false -- whether this drag started in first person
local dragDistance = DragConfig.MinDistance -- distance from player to object; the wheel adjusts this
local dragHighlight: Highlight? = nil
local originalCollide: { [BasePart]: boolean } = {}
local savedMinZoom, savedMaxZoom = 0.5, 128
local dragBoxSize = Vector3.one -- bounding-box size of the held object (for collision sweeps)
local dragBoxOffset = Vector3.zero -- world offset from the pivot to the box centre (constant while rotation is locked)

-- Hover state.
local hoverHighlight: Highlight? = nil
local hoverTarget: Instance? = nil

local function getCharacterRoot(): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getPlayerOrigin(): Vector3
	local rootPart = getCharacterRoot()
	if rootPart then
		return rootPart.Position
	end
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end
	return smoothedPos
end

-- First person ~ the camera sits right on the head.
local function isFirstPerson(): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local camera = Workspace.CurrentCamera
	if not head or not camera then
		return false
	end
	return (camera.CFrame.Position - (head :: BasePart).Position).Magnitude < 1.5
end

local function getParts(root: Instance): { BasePart }
	local parts = {}
	if root:IsA("BasePart") then
		table.insert(parts, root :: BasePart)
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d :: BasePart)
		end
	end
	return parts
end

-- Would the object settle onto a conveyor if let go here? (Within a tagged belt's
-- footprint and just above its surface.) Used to cancel throw momentum so items
-- placed on a belt don't fling off.
local function isOverConveyor(position: Vector3): boolean
	for _, belt in ipairs(CollectionService:GetTagged(DragConfig.ConveyorBeltTag)) do
		if belt:IsA("BasePart") then
			local lp = (belt :: BasePart).CFrame:PointToObjectSpace(position)
			local size = (belt :: BasePart).Size
			if
				math.abs(lp.X) <= size.X / 2 + 0.5
				and math.abs(lp.Z) <= size.Z / 2 + 0.5
				and lp.Y >= -0.5
				and lp.Y <= 4
			then
				return true
			end
		end
	end
	return false
end

-- Walk up from a clicked/hovered instance to the nearest ancestor carrying the tag.
local function resolveDraggable(inst: Instance?): Instance?
	local current = inst
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, DragConfig.Tag) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function makeOutline(name: string, transparency: number): Highlight
	local hl = Instance.new("Highlight")
	hl.Name = name
	hl.FillTransparency = 1
	hl.OutlineTransparency = transparency
	hl.OutlineColor = DragConfig.OutlineColor
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	return hl
end

-- ===== Hover outline =====

local function clearHover()
	if hoverHighlight then
		hoverHighlight:Destroy()
		hoverHighlight = nil
	end
	hoverTarget = nil
end

local function updateHover()
	if dragging then
		clearHover()
		return
	end
	local target = resolveDraggable(mouse.Target)
	if target == hoverTarget then
		return
	end
	clearHover()
	if target then
		hoverTarget = target
		local hl = makeOutline("HoverHighlight", 0.35)
		hl.Adornee = target
		hl.Parent = target
		hoverHighlight = hl
	end
end

-- ===== VFX =====

local function setVFXEnabled(on: boolean)
	if vfxBeam then
		vfxBeam.Enabled = on
	end
end

-- VFX_Attachment sits at the part's origin, so placing the part at the player's
-- origin puts the beam's start there; Attachment1 is pinned to the object.
local function updateVFX(objectPos: Vector3)
	dragVFX.CFrame = CFrame.new(getPlayerOrigin())
	vfxEnd.WorldPosition = objectPos
end

-- ===== Camera zoom lock (so the wheel only changes drag distance while dragging) =====

local function lockCameraZoom()
	savedMinZoom = player.CameraMinZoomDistance
	savedMaxZoom = player.CameraMaxZoomDistance
	local camera = Workspace.CurrentCamera
	local current = savedMaxZoom
	if camera then
		current = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	end
	player.CameraMinZoomDistance = current
	player.CameraMaxZoomDistance = current
end

local function unlockCameraZoom()
	player.CameraMinZoomDistance = savedMinZoom
	player.CameraMaxZoomDistance = savedMaxZoom
end

-- ===== Collision while dragging =====

local COLLISION_SKIN = 0.05

local function collisionExcludes(root: Instance): { Instance }
	local list: { Instance } = { root, dragVFX }
	if player.Character then
		table.insert(list, player.Character)
	end
	return list
end

-- Blockcast that ignores non-collidable hits, so the object is only ever stopped by
-- something it could actually collide with.
local function castCollidable(boxCF: CFrame, size: Vector3, move: Vector3, baseExcludes: { Instance }): RaycastResult?
	local excludes = table.clone(baseExcludes)
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		local result = Workspace:Blockcast(boxCF, size, move, params)
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

-- Same idea as a thin ray (used to keep the object in front of walls we look through).
local function castCollidableRay(origin: Vector3, delta: Vector3, baseExcludes: { Instance }): RaycastResult?
	local excludes = table.clone(baseExcludes)
	for _ = 1, 8 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excludes
		params.IgnoreWater = true
		local result = Workspace:Raycast(origin, delta, params)
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

-- Half-extent of the held object's (oriented) box along a world direction.
local function boxExtentAlongDir(dir: Vector3): number
	local h = dragBoxSize * 0.5
	return math.abs(dir:Dot(lockedRotation.RightVector)) * h.X
		+ math.abs(dir:Dot(lockedRotation.UpVector)) * h.Y
		+ math.abs(dir:Dot(lockedRotation.LookVector)) * h.Z
end

-- Sweep the held object's bounding box from `fromPos` to `toPos`. If it would pass
-- through a collidable part, stop at the surface and slide along it with the leftover
-- motion. Blockcast is a continuous sweep, so this also stops fast moves tunnelling.
local function resolveCollision(root: Instance, fromPos: Vector3, toPos: Vector3): Vector3
	local move = toPos - fromPos
	if move.Magnitude < 1e-5 then
		return toPos
	end
	local excludes = collisionExcludes(root)
	local boxCF = CFrame.new(fromPos + dragBoxOffset) * lockedRotation
	local result = castCollidable(boxCF, dragBoxSize, move, excludes)
	if not result then
		return toPos
	end

	local allowed = math.max(0, result.Distance - COLLISION_SKIN)
	local stopPos = fromPos + move.Unit * allowed

	-- Slide the remaining motion along the surface.
	local n = result.Normal
	local slide = move.Unit * math.max(0, move.Magnitude - allowed)
	slide = slide - n * slide:Dot(n)
	if slide.Magnitude > 1e-4 then
		local slideCF = CFrame.new(stopPos + dragBoxOffset) * lockedRotation
		local slideResult = castCollidable(slideCF, dragBoxSize, slide, excludes)
		if slideResult then
			return stopPos + slide.Unit * math.max(0, slideResult.Distance - COLLISION_SKIN)
		end
		return stopPos + slide
	end
	return stopPos
end

-- ===== Target =====

-- Far intersection of the cursor ray with the player's bounds sphere: the furthest
-- the object can be held while still sitting under the cursor and inside the sphere.
local function maxRayDistance(origin: Vector3, dir: Vector3, playerOrigin: Vector3): number
	local oc = origin - playerOrigin
	local b = oc:Dot(dir)
	local c = oc:Dot(oc) - DragConfig.SphereRadius * DragConfig.SphereRadius
	local disc = b * b - c
	if disc < 0 then
		-- Cursor ray misses the sphere entirely; fall back to closest approach.
		return math.max(DragConfig.MinDistance, -b)
	end
	return math.max(DragConfig.MinDistance, -b + math.sqrt(disc))
end

-- The object's origin sits exactly on the camera->cursor ray, so it renders right
-- under the cursor, held `dragDistance` along that ray and clamped to the player's
-- bounds sphere. Walking moves the camera with the player, so the object carries
-- along by the same amount; the wheel slides it nearer/farther.
local function computeTarget(): Vector3
	local ray = mouse.UnitRay
	local origin = ray.Origin
	local dir = ray.Direction.Unit
	local maxT = maxRayDistance(origin, dir, getPlayerOrigin())
	dragDistance = math.clamp(dragDistance, DragConfig.MinDistance, maxT)

	-- Raytrace forward from the camera: never hold the object beyond a wall we're
	-- looking through (its near face stops at the surface). Pairs with the box sweep.
	local effective = dragDistance
	if dragRoot then
		local extent = boxExtentAlongDir(dir)
		local hit = castCollidableRay(origin, dir * (dragDistance + extent + 0.5), collisionExcludes(dragRoot))
		if hit then
			effective = math.clamp(hit.Distance - extent - COLLISION_SKIN, DragConfig.MinDistance, dragDistance)
		end
	end
	return origin + dir * effective
end

-- ===== Start / stop =====

local function startDrag(root: Instance)
	dragging = true
	dragRoot = root
	dragParts = getParts(root)
	dragVelocity = Vector3.zero
	-- Camera mode is fixed for the drag (zoom is locked below), so snapshot it now.
	dragFirstPerson = isFirstPerson()
	dragSmoothing = if dragFirstPerson then DragConfig.FirstPersonSmoothing else DragConfig.Smoothing
	-- If the object was falling/sliding under faux physics, take it out of the sim.
	FauxPhysics.Stop(root)
	clearHover()

	local pivot = root:GetPivot()
	smoothedPos = pivot.Position
	lockedRotation = pivot.Rotation
	-- Capture the object's bounding box (in its locked orientation) for collision sweeps.
	local boxCF: CFrame, boxSize: Vector3
	if root:IsA("Model") then
		boxCF, boxSize = (root :: Model):GetBoundingBox()
	else
		local part = root :: BasePart
		boxCF, boxSize = part.CFrame, part.Size
	end
	dragBoxSize = boxSize
	dragBoxOffset = boxCF.Position - pivot.Position
	-- Begin at the object's current depth along the cursor ray so it doesn't snap.
	local ray = mouse.UnitRay
	local dir = ray.Direction.Unit
	dragDistance = math.clamp(
		(pivot.Position - ray.Origin):Dot(dir),
		DragConfig.MinDistance,
		maxRayDistance(ray.Origin, dir, getPlayerOrigin())
	)

	-- Glide rather than collide while held.
	originalCollide = {}
	for _, part in ipairs(dragParts) do
		originalCollide[part] = part.CanCollide
		part.CanCollide = false
	end

	dragHighlight = makeOutline("DragHighlight", 0)
	dragHighlight.Adornee = root
	dragHighlight.Parent = root

	lockCameraZoom()
	setVFXEnabled(true)
	updateVFX(smoothedPos)

	-- Ask the server for ownership so the movement replicates to everyone.
	requestRemote:FireServer(root)
end

local function stopDrag()
	if not dragging then
		return
	end
	dragging = false

	local root = dragRoot
	local parts = dragParts
	dragRoot = nil
	dragParts = {}

	if dragHighlight then
		dragHighlight:Destroy()
		dragHighlight = nil
	end
	setVFXEnabled(false)
	unlockCameraZoom()

	for part, collide in pairs(originalCollide) do
		if part.Parent then
			part.CanCollide = collide
		end
	end
	originalCollide = {}

	if root then
		-- Carry the drag momentum over so letting go flings the object.
		local releaseVel = dragVelocity * DragConfig.FlingMultiplier
		if releaseVel.Magnitude > DragConfig.MaxFlingSpeed then
			releaseVel = releaseVel.Unit * DragConfig.MaxFlingSpeed
		end
		-- Lighten gravity on every throw (even more in first person) so it carries.
		local gravityScale = if dragFirstPerson then DragConfig.FirstPersonGravityScale else DragConfig.FlingGravityScale

		-- If it's being set down onto a conveyor, drop the throw momentum and use
		-- normal gravity so it just settles and the belt takes over (no fling-off).
		if isOverConveyor(smoothedPos) then
			releaseVel = Vector3.zero
			gravityScale = 1
		end

		if FauxPhysics.IsFaux(root) then
			-- Anchored model: hand it to the gravity simulation with the throw velocity.
			FauxPhysics.Launch(root, releaseVel, gravityScale)
			releaseRemote:FireServer(root)
		else
			-- Real unanchored part: kick it through the engine and let the server keep
			-- that velocity (and lighten its gravity) as it takes ownership back.
			for _, part in ipairs(parts) do
				if not part.Anchored then
					part.AssemblyLinearVelocity = releaseVel
				end
			end
			releaseRemote:FireServer(root, releaseVel, gravityScale)
		end
	end

	dragVelocity = Vector3.zero
end

function DragController.Start()
	RunService.RenderStepped:Connect(function(dt: number)
		if dragging and dragRoot then
			local root = dragRoot
			if not root.Parent then
				stopDrag()
				return
			end

			local target = computeTarget()
			-- Framerate-independent exponential smoothing (snappier in first person).
			local alpha = 1 - math.exp(-dragSmoothing * dt)
			local desiredPos = smoothedPos:Lerp(target, alpha)
			-- Stop the object passing through collidable parts (and slide along them).
			local newPos = resolveCollision(root, smoothedPos, desiredPos)
			-- Track the object's actual motion so we can throw it on release.
			if dt > 0 then
				local instantVel = (newPos - smoothedPos) / dt
				dragVelocity = dragVelocity:Lerp(instantVel, math.clamp(dt * DragConfig.VelocitySmoothing, 0, 1))
			end
			smoothedPos = newPos
			root:PivotTo(CFrame.new(smoothedPos) * lockedRotation)

			-- Keep it from fighting us / building velocity to fling on release.
			for _, part in ipairs(dragParts) do
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end

			updateVFX(smoothedPos)
		else
			updateHover()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local target = resolveDraggable(mouse.Target)
			if target then
				startDrag(target)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			stopDrag()
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Scroll up (+1) pushes the object away; scroll down (-1) pulls it in.
			-- computeTarget clamps the far end to the bounds sphere each frame.
			dragDistance = math.max(
				DragConfig.MinDistance,
				dragDistance + input.Position.Z * DragConfig.ScrollStep
			)
		end
	end)

	-- Drop whatever we're holding if our character is removed mid-drag.
	player.CharacterRemoving:Connect(stopDrag)
end

return DragController
