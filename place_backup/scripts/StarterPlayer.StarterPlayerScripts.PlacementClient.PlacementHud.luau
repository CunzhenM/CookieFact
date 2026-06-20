--!strict
-- Placement HUD: a Build toggle opens a catalog; clicking a part EQUIPS it. The catalog is a
-- wrapping grid so every part is visible. Plus Delete toggle, Close, and toasts.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))
local PlacementController = require(script.Parent:WaitForChild("PlacementController"))

local PlacementHud = {}
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(24, 26, 32)
local RED = PlacementConfig.DeleteHighlightColor
local TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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

local panel
local buildToggle
local deleteBtn
local statusLabel
local toast
local catalogButtons = {}

local function setOpen(open)
	panel.Visible = open
	buildToggle.Visible = not open
	if not open then
		PlacementController.exit()
	end
end

local function highlightSelected(machineId)
	for id, entry in pairs(catalogButtons) do
		local selected = id == machineId
		TweenService:Create(entry.accent, TWEEN, { Thickness = selected and 3 or 1.5, Transparency = selected and 0 or 0.4 }):Play()
		TweenService:Create(entry.btn, TWEEN, { BackgroundTransparency = selected and 0 or 0.15 }):Play()
	end
end

local function refresh(modeValue, machineId)
	if modeValue == "place" then
		local m = machineId and PlacementConfig.getMachine(machineId)
		statusLabel.Text = "Placing " .. ((m and m.label) or "?") .. "   |   R rotate   |   click place   |   X cancel"
		highlightSelected(machineId)
		deleteBtn.Text = "Delete"
	elseif modeValue == "delete" then
		statusLabel.Text = "Delete mode   |   click a machine to remove it"
		highlightSelected(nil)
		deleteBtn.Text = "Done"
	else
		statusLabel.Text = "Pick a part to place, or hit Delete"
		highlightSelected(nil)
		deleteBtn.Text = "Delete"
	end
end

local function showToast(ok, reason)
	if ok then
		return
	end
	toast.Text = reason
	toast.BackgroundTransparency = 0.1
	toast.TextTransparency = 0
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	TweenService:Create(toast, TweenInfo.new(0.18), { Position = UDim2.new(0.5, 0, 0, 92) }):Play()
	task.delay(1.6, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local function makeButton(text, w, accentColor)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w, 46)
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.15
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = WHITE
	corner(b, 10)
	local s = stroke(b, accentColor, 0.4, 1.5)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TWEEN, { BackgroundTransparency = 0 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TWEEN, { BackgroundTransparency = 0.15 }):Play()
	end)
	return b, s
end

function PlacementHud.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlacementHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	buildToggle = (makeButton("Build", 130, WHITE))
	buildToggle.AnchorPoint = Vector2.new(0, 1)
	buildToggle.Position = UDim2.new(0, 18, 1, -18)
	buildToggle.Parent = gui
	buildToggle.Activated:Connect(function()
		setOpen(true)
	end)

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.fromOffset(760, 212)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.2
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 16)
	stroke(panel, WHITE, 0.5, 1.5)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(1, 0, 0, 22)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 14
	statusLabel.TextColor3 = WHITE
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = ""
	statusLabel.Parent = panel

	-- Catalog: a wrapping grid so every part is visible (no overflow, no scrolling quirks).
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 28)
	row.Size = UDim2.new(1, 0, 0, 108)
	row.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.CellSize = UDim2.fromOffset(108, 46)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	for _, machine in ipairs(PlacementConfig.Machines) do
		local costText = machine.cost > 0 and ("$" .. machine.cost) or "FREE"
		local btn, accent = makeButton(machine.label .. "\n" .. costText, 108, machine.color)
		btn.Parent = row
		btn.Activated:Connect(function()
			PlacementController.enterPlace(machine.id)
		end)
		catalogButtons[machine.id] = { btn = btn, accent = accent }
	end

	-- Footer: Delete + Close (below the catalog)
	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(1, 1)
	footer.Position = UDim2.fromScale(1, 1)
	footer.Size = UDim2.fromOffset(240, 44)
	footer.Parent = panel
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	fl.VerticalAlignment = Enum.VerticalAlignment.Center
	fl.Padding = UDim.new(0, 8)
	fl.Parent = footer

	deleteBtn = (makeButton("Delete", 110, RED))
	deleteBtn.Parent = footer
	deleteBtn.Activated:Connect(function()
		if PlacementController.getMode() == "delete" then
			PlacementController.exit()
		else
			PlacementController.enterDelete()
		end
	end)

	local closeBtn = (makeButton("Close", 100, WHITE))
	closeBtn.Parent = footer
	closeBtn.Activated:Connect(function()
		setOpen(false)
	end)

	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 92)
	toast.Size = UDim2.fromOffset(340, 40)
	toast.BackgroundColor3 = PANEL
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.TextColor3 = RED
	toast.Text = ""
	toast.Parent = gui
	corner(toast, 10)
	stroke(toast, RED, 0.3, 1.5)

	PlacementController.ModeChanged:Connect(refresh)
	PlacementController.ResultChanged:Connect(showToast)
	refresh("none", nil)
end

return PlacementHud
