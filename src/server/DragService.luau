--!strict
-- Server side of the drag system.
--
-- The client does all of the visual/positioning work, but a part only replicates
-- to the server and other players if the mover owns it. So when a client grabs a
-- draggable, we hand it network ownership; on release we take it back and kill any
-- leftover velocity so it doesn't fling. We also enforce "one dragger per object"
-- and "one object per dragger".
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))

local DragService = {}

-- root (BasePart/Model) -> the player currently dragging it
local activeDrags: { [Instance]: Player } = {}
-- player -> the root they are dragging (so we can clean up if they leave)
local draggingByPlayer: { [Player]: Instance } = {}

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

local function isValidDraggable(root: Instance): boolean
	return root.Parent ~= nil and CollectionService:HasTag(root, DragConfig.Tag)
end

local MAX_THROW = 200 -- studs/s server-side cap on a thrown object
local GRAVITY_FORCE_NAME = "DragReducedGravity"

-- Offset part of gravity with an upward VectorForce so a first-person throw floats
-- further, then clean it up once the part settles (or after a timeout).
local function applyReducedGravity(part: BasePart, scale: number)
	local existing = part:FindFirstChild(GRAVITY_FORCE_NAME)
	if existing then
		existing:Destroy()
	end
	if scale >= 1 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = GRAVITY_FORCE_NAME .. "Att"
	attachment.Parent = part

	local force = Instance.new("VectorForce")
	force.Name = GRAVITY_FORCE_NAME
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.new(0, part.AssemblyMass * workspace.Gravity * (1 - scale), 0)
	force.Parent = part

	task.spawn(function()
		local elapsed = 0
		while force.Parent and elapsed < DragConfig.FlingGravityDuration do
			task.wait(0.15)
			elapsed += 0.15
			if not part.Parent or part.AssemblyLinearVelocity.Magnitude < 3 then
				break
			end
		end
		force:Destroy()
		attachment:Destroy()
	end)
end

local function stopDrag(root: Instance, throwVelocity: Vector3?, gravityScale: number?)
	local player = activeDrags[root]
	activeDrags[root] = nil
	if player then
		draggingByPlayer[player] = nil
	end
	local gravityApplied = false
	for _, part in ipairs(getParts(root)) do
		if not part.Anchored then
			-- Return physics control to the server, preserving the throw velocity (or
			-- stopping the part if there was none).
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
			part.AssemblyLinearVelocity = throwVelocity or Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			-- One force per assembly is enough to lighten the whole body's gravity.
			if gravityScale and not gravityApplied then
				applyReducedGravity(part, gravityScale)
				gravityApplied = true
			end
		end
	end
end

function DragService.Start()
	local remotes = Instance.new("Folder")
	remotes.Name = DragConfig.RemotesFolder

	local requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = DragConfig.RequestRemote
	requestRemote.Parent = remotes

	local releaseRemote = Instance.new("RemoteEvent")
	releaseRemote.Name = DragConfig.ReleaseRemote
	releaseRemote.Parent = remotes

	remotes.Parent = ReplicatedStorage

	requestRemote.OnServerEvent:Connect(function(player, root)
		if typeof(root) ~= "Instance" or not isValidDraggable(root) then
			return
		end
		-- Someone else already has it.
		local current = activeDrags[root]
		if current and current ~= player then
			return
		end
		-- This player was holding something else; let it go first.
		local prev = draggingByPlayer[player]
		if prev and prev ~= root then
			stopDrag(prev)
		end

		local granted = false
		for _, part in ipairs(getParts(root)) do
			if not part.Anchored then
				local ok = pcall(function()
					part:SetNetworkOwner(player)
				end)
				granted = granted or ok
			end
		end

		if granted then
			activeDrags[root] = player
			draggingByPlayer[player] = root
		end
	end)

	releaseRemote.OnServerEvent:Connect(function(player, root, throwVelocity, gravityScale)
		if typeof(root) ~= "Instance" then
			return
		end
		local vel: Vector3? = nil
		if typeof(throwVelocity) == "Vector3" then
			vel = if throwVelocity.Magnitude > MAX_THROW then throwVelocity.Unit * MAX_THROW else throwVelocity
		end
		local scale: number? = nil
		if typeof(gravityScale) == "number" then
			scale = math.clamp(gravityScale, 0.2, 1)
		end
		if activeDrags[root] == player then
			stopDrag(root, vel, scale)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local root = draggingByPlayer[player]
		if root then
			stopDrag(root)
		end
	end)
end

return DragService
