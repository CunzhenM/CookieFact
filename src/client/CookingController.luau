--!strict
-- Client side of cooking: notices when a piece of dough comes to rest on the oven
-- and reports it to the server, which runs the actual bake.
--
-- The dough is moved by client-side faux physics, so the client is what knows where
-- it actually landed -- hence detection lives here and the authoritative bake on the
-- server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))
local CookConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CookConfig"))
local FauxPhysics = require(script.Parent:WaitForChild("FauxPhysics"))

local CookingController = {}

local remotes = ReplicatedStorage:WaitForChild(DragConfig.RemotesFolder)
local requestCook = remotes:WaitForChild(CookConfig.CookRemote) :: RemoteEvent

local function isDough(root: Instance): boolean
	return CollectionService:HasTag(root, CookConfig.DoughTag)
end

local function getBox(root: Instance): (CFrame, Vector3)
	if root:IsA("Model") then
		return root:GetBoundingBox()
	end
	local part = root :: BasePart
	return part.CFrame, part.Size
end

function CookingController.Start()
	FauxPhysics.OnRest(function(root: Instance)
		if not root.Parent or not isDough(root) then
			return
		end
		local oven = Workspace:FindFirstChild(CookConfig.OvenPartName)
		if not oven then
			return
		end

		-- Did it actually settle on top of the oven? Probe straight down.
		local cf, size = getBox(root)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { root }
		params.IgnoreWater = true
		local result = Workspace:Raycast(cf.Position, Vector3.new(0, -(size.Y / 2 + 0.75), 0), params)
		if result and (result.Instance == oven or result.Instance:IsDescendantOf(oven)) then
			requestCook:FireServer(root, root:GetPivot())
		end
	end)
end

return CookingController
