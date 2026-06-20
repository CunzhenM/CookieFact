local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local EntitiesData = require(ReplicatedStorage.Shared.Data.EntitiesData)

local brainrotName = script.Parent :: TextBox
local frame = brainrotName.Parent
local levelBox = frame:FindFirstChild("BrainrotLevel") :: TextBox?
local selectButton = frame:FindFirstChild("Select") :: ImageButton?
local giveButton = frame:FindFirstChild("Give") :: ImageButton?

-- BrainrotName -> Frame -> GiveBrainrot -> ScrollingFrame -> AdminPanel
local adminPanel = frame.Parent.Parent.Parent
local selector = adminPanel:FindFirstChild("BrainrotSelector1") :: Frame?
local scrollingFrame = selector and selector:FindFirstChild("ScrollingFrame")

-- Close button lives at BrainrotSelector1.Close.ImageButton
local closeContainer = selector and selector:FindFirstChild("Close")
local closeButton = closeContainer and closeContainer:FindFirstChild("ImageButton") :: ImageButton?

local OPEN_SIZE = (selector and selector.Size) or UDim2.new(0.7, 0, 1, 0)
local CLOSED_SIZE = UDim2.new(0, 0, 0, 0)

local function getOrCreateRemote(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	local rev = Instance.new("RemoteEvent")
	rev.Name = name
	rev.Parent = ReplicatedStorage
	return rev
end

local giveRemote = getOrCreateRemote("GiveBrainrotRemote")
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function closeSelector()
	if not selector then return end
	local tween = TweenService:Create(selector, tweenInfo, { Size = CLOSED_SIZE })
	tween:Play()
	tween.Completed:Connect(function()
		if selector.Size == CLOSED_SIZE then
			selector.Visible = false
			selector.Size = OPEN_SIZE
		end
	end)
end

local function openSelector()
	if not selector then return end
	selector.Size = CLOSED_SIZE
	selector.Visible = true
	TweenService:Create(selector, tweenInfo, { Size = OPEN_SIZE }):Play()
end

if selectButton and selector then
	selectButton.MouseButton1Click:Connect(function()
		if selector.Visible then
			closeSelector()
		else
			openSelector()
		end
	end)
end

if closeButton and selector then
	closeButton.MouseButton1Click:Connect(function()
		if selector.Visible then
			closeSelector()
		end
	end)
end

-- ─── Brainrot click handling ──────────────────────────────────────────────
local activeStroke: UIStroke? = nil

local function selectBrainrot(brainrotFrame: Instance)
	local inner = brainrotFrame:FindFirstChild("Frame")
	if not inner then return end
	local stroke = inner:FindFirstChild("RainbowStroke")
	if not (stroke and stroke:IsA("UIStroke")) then return end

	if activeStroke and activeStroke ~= stroke then
		activeStroke.Enabled = false
	end
	stroke.Enabled = true
	activeStroke = stroke

	brainrotName.Text = brainrotFrame.Name
end

local wiredButtons: {[Instance]: boolean} = {}

local function wireBrainrot(brainrotFrame: Instance)
	if not brainrotFrame:IsA("Frame") then return end
	if wiredButtons[brainrotFrame] then return end
	local inner = brainrotFrame:FindFirstChild("Frame")
	if not inner then return end
	local clickDetector = inner:FindFirstChild("ClickDetector")
	if not clickDetector then return end
	if clickDetector:IsA("TextButton") or clickDetector:IsA("ImageButton") then
		wiredButtons[brainrotFrame] = true
		clickDetector.MouseButton1Click:Connect(function()
			selectBrainrot(brainrotFrame)
		end)
	end
end

local function wireClass(classFolder: Instance)
	if classFolder.Name:sub(1, 6) ~= "Class_" then return end
	local brainrots = classFolder:FindFirstChild("Brainrots")
	if not brainrots then return end
	for _, child in ipairs(brainrots:GetChildren()) do
		wireBrainrot(child)
	end
	brainrots.ChildAdded:Connect(wireBrainrot)
end

if scrollingFrame then
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		wireClass(child)
	end
	scrollingFrame.ChildAdded:Connect(wireClass)
end

-- ─── Auto-load 3D previews into ViewportFrames + 360° rotation ────────────
local viewportLoaded: {[Instance]: boolean} = {}

-- All cameras share a single RenderStepped loop; each entry tracks where to
-- orbit. Centralized so 104 viewports cost ~104 CFrame writes per frame.
type CameraInfo = { cam: Camera, pivot: Vector3, distance: number, yOffset: number }
local rotatingCameras: { CameraInfo } = {}

local ROT_SPEED = math.pi / 3 -- ~60° per second; one full turn every 6s

local function populateViewport(brainrotFrame: Instance)
	if viewportLoaded[brainrotFrame] then return end
	local inner = brainrotFrame:FindFirstChild("Frame")
	if not inner then return end
	local vf = inner:FindFirstChild("ViewportFrame")
	if not (vf and vf:IsA("ViewportFrame")) then return end

	-- Already populated (e.g. cached from earlier session)?
	if vf:FindFirstChild("RenderedBrainrot") then
		viewportLoaded[brainrotFrame] = true
		return
	end

	local data = EntitiesData.Brainrots and EntitiesData.Brainrots[brainrotFrame.Name]
	if not data or typeof(data.Model) ~= "Instance" then return end

	local clone = data.Model:Clone()
	clone.Name = "RenderedBrainrot"

	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end

	clone.Parent = vf

	local cf, size = clone:GetBoundingBox()
	local cam = Instance.new("Camera")
	local maxDim = math.max(size.X, size.Y, size.Z)
	local distance = maxDim * 1.6 + 2
	cam.FieldOfView = 50
	cam.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(0, size.Y * 0.15, distance),
		cf.Position
	)
	cam.Parent = vf
	vf.CurrentCamera = cam

	table.insert(rotatingCameras, {
		cam = cam,
		pivot = cf.Position,
		distance = distance,
		yOffset = size.Y * 0.15,
	})

	viewportLoaded[brainrotFrame] = true
end

local function populateClass(classFolder: Instance)
	if classFolder.Name:sub(1, 6) ~= "Class_" then return end
	local brainrots = classFolder:FindFirstChild("Brainrots")
	if not brainrots then return end
	for _, child in ipairs(brainrots:GetChildren()) do
		populateViewport(child)
		task.wait()
	end
	brainrots.ChildAdded:Connect(function(child)
		populateViewport(child)
	end)
end

task.spawn(function()
	if not scrollingFrame then return end
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		populateClass(child)
	end
	scrollingFrame.ChildAdded:Connect(populateClass)
end)

-- Single RenderStepped loop drives all viewports' camera orbits. Skips work
-- when the selector is hidden (ViewportFrames don't render anyway, but no
-- point spending CPU).
RunService.RenderStepped:Connect(function()
	if selector and not selector.Visible then return end
	if #rotatingCameras == 0 then return end
	local angle = os.clock() * ROT_SPEED
	local cosA = math.cos(angle)
	local sinA = math.sin(angle)
	for _, info in ipairs(rotatingCameras) do
		local p = info.pivot
		info.cam.CFrame = CFrame.lookAt(
			Vector3.new(p.X + cosA * info.distance, p.Y + info.yOffset, p.Z + sinA * info.distance),
			p
		)
	end
end)

-- ─── Give button ──────────────────────────────────────────────────────────
if giveButton then
	giveButton.MouseButton1Click:Connect(function()
		local name = brainrotName.Text
		if name == nil or name == "" then return end
		local levelStr = levelBox and levelBox.Text or ""
		local level = tonumber(levelStr)
		if not level or level < 1 then return end
		giveRemote:FireServer(name, math.floor(level))
	end)
end
