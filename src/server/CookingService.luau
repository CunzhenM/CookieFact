--!strict
-- Server side of cooking: authoritative bake of a dough into a cookie.
--
-- The client reports a dough that has settled on the oven (with its resting CFrame).
-- We snap the dough there so everyone agrees on its spot, float a countdown timer
-- above it, and after BakeTime replace it with a Cookie at the exact same location.
-- Grabbing the dough again cancels the bake.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DragConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DragConfig"))
local CookConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CookConfig"))

local CookingService = {}

type Cook = { anchor: Attachment, cancelled: boolean }
local cooking: { [Instance]: Cook } = {}

local function isDough(root: Instance): boolean
	return root.Parent ~= nil and CollectionService:HasTag(root, CookConfig.DoughTag)
end

-- Is the dough sitting on top of the oven's footprint?
local function onOven(dough: Instance, oven: BasePart): boolean
	local cf, size = dough:GetBoundingBox()
	local p = cf.Position
	local top = oven.Position.Y + oven.Size.Y / 2
	local withinXZ = math.abs(p.X - oven.Position.X) <= oven.Size.X / 2 + 1
		and math.abs(p.Z - oven.Position.Z) <= oven.Size.Z / 2 + 1
	local atSurface = p.Y >= top - 0.5 and p.Y <= top + size.Y / 2 + 2
	return withinXZ and atSurface
end

-- A small countdown billboard floating above the dough.
local function makeTimer(dough: Instance): (Attachment, TextLabel)
	local cf, size = dough:GetBoundingBox()
	local anchorPart: BasePart? = if dough:IsA("BasePart") then dough :: BasePart else nil
	if not anchorPart then
		for _, d in ipairs(dough:GetDescendants()) do
			if d:IsA("BasePart") then
				anchorPart = d :: BasePart
				break
			end
		end
	end

	local att = Instance.new("Attachment")
	att.Name = "CookTimer"
	att.Parent = anchorPart
	-- Set WorldPosition only AFTER parenting, or it's reinterpreted as local space.
	att.WorldPosition = cf.Position + Vector3.new(0, size.Y / 2 + 1.8, 0)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CookTimerGui"
	billboard.Size = UDim2.fromOffset(120, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = att

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 22, 18)
	frame.BackgroundTransparency = 0.3
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.35, 0)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 226, 165)
	label.TextScaled = true
	label.Text = tostring(CookConfig.BakeTime)
	label.Parent = frame

	return att, label
end

local function finishCook(dough: Instance, cook: Cook)
	cooking[dough] = nil
	local pivot = dough:GetPivot()
	cook.anchor:Destroy()

	local template = Workspace:FindFirstChild(CookConfig.CookieTemplateName)
	if template then
		local cookie = template:Clone()
		cookie:PivotTo(pivot) -- exact location of the dough
		if cookie:IsA("BasePart") then
			cookie.Anchored = false
		end
		CollectionService:AddTag(cookie, DragConfig.Tag)
		cookie.Parent = Workspace
	end
	dough:Destroy()
end

local function startCooking(dough: Instance, reportedCFrame: CFrame?)
	if cooking[dough] or not isDough(dough) then
		return
	end
	local oven = Workspace:FindFirstChild(CookConfig.OvenPartName)
	if not oven or not oven:IsA("BasePart") then
		return
	end
	-- Agree on where it landed, then double-check it's really on the oven.
	if reportedCFrame then
		dough:PivotTo(reportedCFrame)
	end
	if not onOven(dough, oven) then
		return
	end

	local att, label = makeTimer(dough)
	local cook: Cook = { anchor = att, cancelled = false }
	cooking[dough] = cook

	task.spawn(function()
		for remaining = CookConfig.BakeTime, 1, -1 do
			if cook.cancelled or cooking[dough] ~= cook or not dough.Parent then
				break
			end
			label.Text = tostring(remaining)
			task.wait(1)
		end
		if cook.cancelled or cooking[dough] ~= cook or not dough.Parent then
			if cooking[dough] == cook then
				cooking[dough] = nil
			end
			if att.Parent then
				att:Destroy()
			end
			return
		end
		finishCook(dough, cook)
	end)
end

local function cancelCooking(dough: Instance)
	local cook = cooking[dough]
	if not cook then
		return
	end
	cook.cancelled = true
	cooking[dough] = nil
	if cook.anchor.Parent then
		cook.anchor:Destroy()
	end
end

function CookingService.Start()
	local remotes = ReplicatedStorage:WaitForChild(DragConfig.RemotesFolder)

	local requestCook = remotes:FindFirstChild(CookConfig.CookRemote)
	if not requestCook then
		requestCook = Instance.new("RemoteEvent")
		requestCook.Name = CookConfig.CookRemote
		requestCook.Parent = remotes
	end
	;(requestCook :: RemoteEvent).OnServerEvent:Connect(function(_player, dough, reportedCFrame)
		if typeof(dough) ~= "Instance" then
			return
		end
		local cf = if typeof(reportedCFrame) == "CFrame" then reportedCFrame else nil
		startCooking(dough, cf)
	end)

	-- Grabbing a baking dough (it fires the drag request) cancels the bake.
	local requestDrag = remotes:WaitForChild(DragConfig.RequestRemote) :: RemoteEvent
	requestDrag.OnServerEvent:Connect(function(_player, root)
		if typeof(root) == "Instance" and cooking[root] then
			cancelCooking(root)
		end
	end)
end

return CookingService
