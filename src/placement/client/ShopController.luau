--!strict
-- Per-plot Machine Shop (client). Clones StarterGui.Frames.Frames.MachineShop (never fights the
-- partner's copy), strips its scripts, and fills its `Scrolling` list with the placeable catalog in
-- the house style. The server says when THIS player opened THEIR OWN kiosk -> pop the frame in
-- (UIEffects pop+fade) + SFX. Picking an item enters place mode. Non-owner -> error toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local PlacementController = require(script.Parent:WaitForChild("PlacementController"))
local UIEffects = require(script.Parent:WaitForChild("UIEffects"))

local ShopController = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CARD = Color3.fromRGB(20, 22, 28)
local CARD_TOP = Color3.fromRGB(40, 44, 54)
local BUY_COLOR = Color3.fromRGB(46, 160, 86)
local FREE_COLOR = Color3.fromRGB(70, 130, 200)
local ERR_COLOR = Color3.fromRGB(255, 90, 90)

local player = Players.LocalPlayer
local shopFrame
local toast

local openSfx, errorSfx, buySfx
local function ensureSounds()
	if openSfx then
		return
	end
	local folder = SoundService:FindFirstChild("CookieShopSFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CookieShopSFX"
		folder.Parent = SoundService
	end
	openSfx = Instance.new("Sound")
	openSfx.SoundId = "rbxassetid://139804904213958"
	openSfx.Volume = 0.5
	openSfx.Parent = folder
	errorSfx = Instance.new("Sound")
	errorSfx.SoundId = "rbxassetid://550209561"
	errorSfx.Volume = 0.5
	errorSfx.Parent = folder
	buySfx = Instance.new("Sound")
	buySfx.SoundId = "rbxassetid://111773238101465"
	buySfx.Volume = 0.5
	buySfx.Parent = folder
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function makeRow(machine, order)
	local row = Instance.new("Frame")
	row.Name = "Machine_" .. machine.id
	row.LayoutOrder = order
	row.Size = UDim2.fromScale(0.95, 0.26)
	row.BackgroundTransparency = 1

	local card = Instance.new("Frame")
	card.Name = "Design"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = CARD
	card.BackgroundTransparency = 0.05
	card.Parent = row
	corner(card, 10)
	stroke(card, machine.color, 0.1, 2)
	local grad = Instance.new("UIGradient")
	grad.Rotation = -90
	grad.Color = ColorSequence.new(CARD_TOP, CARD)
	grad.Parent = card

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.fromScale(0.05, 0.34)
	name.Size = UDim2.fromScale(0.6, 0.4)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = WHITE
	name.Text = machine.label
	name.Parent = card
	stroke(name, BLACK, 0, 2)

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0, 0.5)
	sub.Position = UDim2.fromScale(0.05, 0.73)
	sub.Size = UDim2.fromScale(0.6, 0.22)
	sub.Font = Enum.Font.Gotham
	sub.TextScaled = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = Color3.fromRGB(170, 176, 190)
	sub.Text = string.format("Footprint %d x %d", machine.footprint[1], machine.footprint[2])
	sub.Parent = card

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AutoButtonColor = false
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.fromScale(0.96, 0.5)
	buy.Size = UDim2.fromScale(0.26, 0.62)
	buy.BackgroundColor3 = machine.cost > 0 and BUY_COLOR or FREE_COLOR
	buy.Font = Enum.Font.GothamBold
	buy.TextScaled = true
	buy.TextColor3 = WHITE
	buy.Text = machine.cost > 0 and ("$" .. machine.cost) or "FREE"
	buy.Parent = card
	corner(buy, 8)
	stroke(buy, BLACK, 0, 2)
	local bpad = Instance.new("UIPadding")
	bpad.PaddingTop = UDim.new(0, 4)
	bpad.PaddingBottom = UDim.new(0, 4)
	bpad.PaddingLeft = UDim.new(0, 6)
	bpad.PaddingRight = UDim.new(0, 6)
	bpad.Parent = buy

	buy.Activated:Connect(function()
		if buySfx then
			buySfx:Play()
		end
		PlacementController.enterPlace(machine.id)
		ShopController.close()
	end)
	UIEffects.button(buy)
	return row
end

local function populate(scrolling)
	local list = scrolling:FindFirstChildWhichIsA("UIListLayout")
	for _, c in ipairs(scrolling:GetChildren()) do
		if not (c:IsA("UIListLayout") or c:IsA("UIPadding")) then
			c:Destroy()
		end
	end
	if list then
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
	end
	for i, machine in ipairs(PlacementConfig.Machines) do
		makeRow(machine, i).Parent = scrolling
	end
	if list then
		local function resize()
			scrolling.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 8)
		end
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
		resize()
	end
end

local function buildFallback()
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(420, 470)
	f.BackgroundColor3 = BLACK
	f.BackgroundTransparency = 0.25
	corner(f, 14)
	stroke(f, BLACK, 0, 2.8)
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "Title"
	titleFrame.BackgroundTransparency = 1
	titleFrame.Size = UDim2.new(1, 0, 0, 44)
	titleFrame.Parent = f
	local titleText = Instance.new("TextLabel")
	titleText.Name = "Text"
	titleText.BackgroundTransparency = 1
	titleText.Size = UDim2.fromScale(1, 1)
	titleText.Font = Enum.Font.GothamBold
	titleText.TextScaled = true
	titleText.TextColor3 = WHITE
	titleText.Text = "Machine Shop"
	titleText.Parent = titleFrame
	stroke(titleText, BLACK, 0, 2)
	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "Scrolling"
	scrolling.BackgroundTransparency = 1
	scrolling.BorderSizePixel = 0
	scrolling.Position = UDim2.fromOffset(0, 50)
	scrolling.Size = UDim2.new(1, 0, 1, -56)
	scrolling.ScrollBarThickness = 5
	scrolling.Parent = f
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Vertical
	sl.Padding = UDim.new(0, 8)
	sl.Parent = scrolling
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	close.Font = Enum.Font.GothamBold
	close.TextScaled = true
	close.TextColor3 = WHITE
	close.Text = "X"
	corner(close, 8)
	stroke(close, Color3.fromRGB(100, 0, 0), 0, 2)
	close.Parent = f
	return f
end

local function makeToast(gui)
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, 0, 0, 100)
	t.Size = UDim2.fromOffset(360, 46)
	t.BackgroundColor3 = CARD
	t.BackgroundTransparency = 1
	t.TextTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = ERR_COLOR
	t.Text = ""
	t.Parent = gui
	corner(t, 10)
	stroke(t, ERR_COLOR, 0.3, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = t
	return t
end

local function showToast(msg)
	toast.Text = msg
	toast.BackgroundTransparency = 0.1
	toast.TextTransparency = 0
	toast.Position = UDim2.new(0.5, 0, 0, 86)
	TweenService:Create(toast, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 0, 104) }):Play()
	if errorSfx then
		errorSfx:Play()
	end
	task.delay(1.8, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

function ShopController.close()
	if shopFrame and shopFrame.Visible then
		UIEffects.closeFrame(shopFrame)
	end
end

function ShopController.open()
	if shopFrame and not shopFrame.Visible then
		shopFrame.Visible = true
		if openSfx then
			openSfx:Play()
		end
	end
end

function ShopController.toggle()
	if not shopFrame then
		return
	end
	if shopFrame.Visible then
		ShopController.close()
	else
		ShopController.open()
	end
end

function ShopController.Start()
	ensureSounds()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CookieShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")

	local outer = player.PlayerGui:WaitForChild("Frames", 10)
	local inner = outer and outer:FindFirstChild("Frames")
	local template = inner and inner:FindFirstChild("MachineShop")
	if template and template:IsA("GuiObject") then
		shopFrame = template:Clone()
		for _, d in ipairs(shopFrame:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
	else
		shopFrame = buildFallback()
	end
	shopFrame.Name = "MachineShop"
	shopFrame.Visible = false
	shopFrame.Parent = gui

	local title = shopFrame:FindFirstChild("Title")
	local titleText = title and title:FindFirstChild("Text")
	if titleText and titleText:IsA("TextLabel") then
		titleText.Text = "Machine Shop"
	end

	local scrolling = shopFrame:FindFirstChild("Scrolling")
	if scrolling and scrolling:IsA("ScrollingFrame") then
		populate(scrolling)
	end

	local closeBtn = shopFrame:FindFirstChild("Close")
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.Activated:Connect(function()
			ShopController.close()
		end)
	end

	UIEffects.bindFrame(shopFrame)
	UIEffects.sweepButtons(shopFrame)

	toast = makeToast(gui)

	local remotes = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	local openR = remotes:WaitForChild(PlacementConfig.Remotes.OpenShop)
	local errR = remotes:WaitForChild(PlacementConfig.Remotes.ShopError)
	openR.OnClientEvent:Connect(function()
		shopFrame.Visible = true
		if openSfx then
			openSfx:Play()
		end
	end)
	errR.OnClientEvent:Connect(function(msg)
		showToast(typeof(msg) == "string" and msg or "This isn't your shop!")
	end)
end

return ShopController
