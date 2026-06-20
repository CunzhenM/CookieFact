--!strict
-- Client side of the machine shop. On a machine's purchase prompt, shows the partner's
-- ProductConfirmFrame (CLONED, never his instance) with {Product}/{Price} filled in; on Yes
-- fires the Buy remote. Falls back to a simple dialog if his frame is missing.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))

local MachineShopController = {}

local player
local buyR
local backdrop
local confirmFrame
local confirmLabel
local labelTemplate = "Would you like to purchase {Product} for ${Price}?"
local activeYes = nil

local function hide()
	backdrop.Visible = false
	confirmFrame.Visible = false
	activeYes = nil
end

local function showConfirm(productName, price, onYes)
	activeYes = onYes
	if confirmLabel then
		local txt = labelTemplate:gsub("{Product}", productName)
		txt = txt:gsub("{Price}", tostring(price))
		confirmLabel.Text = txt
	end
	backdrop.Visible = true
	confirmFrame.Visible = true
end

local function buildFallback(parent)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(360, 170)
	f.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	f.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Transparency = 0.5
	s.Parent = f
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -24, 0, 80)
	lbl.Position = UDim2.fromOffset(12, 12)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 18
	lbl.TextWrapped = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Text = labelTemplate
	lbl.Parent = f
	local function mk(name, txt, color, x)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.fromOffset(150, 50)
		b.Position = UDim2.new(0, x, 1, -62)
		b.BackgroundColor3 = color
		b.Font = Enum.Font.GothamBold
		b.TextSize = 18
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = txt
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 10)
		cc.Parent = b
		b.Parent = f
		return b
	end
	local yes = mk("Yes", "Yes", Color3.fromRGB(95, 200, 120), 12)
	local no = mk("No", "No", Color3.fromRGB(200, 80, 80), 198)
	f.Parent = parent
	return f, lbl, yes, no
end

local function setup(gui)
	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.Visible = false
	backdrop.Parent = gui

	local yesBtn, noBtn

	local frames = StarterGui:FindFirstChild(PlacementConfig.ConfirmFramesScreen)
	local template = frames and frames:FindFirstChild(PlacementConfig.ConfirmFrameName)
	if template and template:IsA("GuiObject") then
		local clone = template:Clone()
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Position = UDim2.fromScale(0.5, 0.5)
		clone.Visible = false
		clone.Parent = gui
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("InputAction") then
				d.Enabled = false
			end
		end
		confirmFrame = clone
		confirmLabel = clone:FindFirstChild("Label", true)
		if confirmLabel then
			labelTemplate = confirmLabel.Text
		end
		local buttons = clone:FindFirstChild("Buttons")
		yesBtn = buttons and buttons:FindFirstChild("Yes")
		noBtn = buttons and buttons:FindFirstChild("No")
	end

	if not (confirmFrame and yesBtn and noBtn) then
		local f, lbl, y, n = buildFallback(gui)
		confirmFrame = f
		confirmLabel = lbl
		yesBtn = y
		noBtn = n
	end

	yesBtn.Activated:Connect(function()
		local cb = activeYes
		hide()
		if cb then
			cb()
		end
	end)
	noBtn.Activated:Connect(hide)
	backdrop.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			hide()
		end
	end)
end

function MachineShopController.Start()
	player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	buyR = remotes:WaitForChild(PlacementConfig.Remotes.Buy)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MachineShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	setup(gui)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
		if plr ~= player then
			return
		end
		local factory = Workspace:FindFirstChild(PlacementConfig.FactoryFolderName)
		if not factory or not prompt:IsDescendantOf(factory) then
			return
		end
		local model = prompt
		while model and model.Parent ~= factory do
			model = model.Parent
		end
		if not model then
			return
		end
		local cost = model:GetAttribute("Cost") or 0
		local label = model:GetAttribute("Label") or model.Name
		local id = model.Name
		showConfirm(label, cost, function()
			buyR:FireServer(id)
		end)
	end)
end

return MachineShopController
