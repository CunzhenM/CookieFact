--!strict
-- On-screen wayfinder to the player's OWN plot. Off-screen -> a styled arrow pins to the screen
-- edge and rotates toward it with distance; in view -> hides (the plot name tag takes over).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MARGIN = 72
local ArrowController = {}

local function getMyPlot(player)
	local plotName = player:GetAttribute("PlotName")
	if not plotName then
		return nil
	end
	local p = Workspace:FindFirstChild(plotName)
	return (p and p:IsA("BasePart")) and p or nil
end

function ArrowController.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlotArrow"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.fromOffset(66, 84)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	panel.BackgroundTransparency = 0.2
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = panel

	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.38)
	arrow.Size = UDim2.fromOffset(40, 40)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 34
	arrow.TextColor3 = Color3.fromRGB(120, 255, 150)
	arrow.Text = "\u{25B2}"
	arrow.Parent = panel

	local dist = Instance.new("TextLabel")
	dist.AnchorPoint = Vector2.new(0.5, 1)
	dist.Position = UDim2.new(0.5, 0, 1, -8)
	dist.Size = UDim2.new(1, -8, 0, 18)
	dist.BackgroundTransparency = 1
	dist.Font = Enum.Font.GothamMedium
	dist.TextSize = 13
	dist.TextColor3 = Color3.new(1, 1, 1)
	dist.TextStrokeTransparency = 0.6
	dist.Text = ""
	dist.Parent = panel

	RunService.RenderStepped:Connect(function()
		local plot = getMyPlot(player)
		local cam = Workspace.CurrentCamera
		if not plot or not cam then
			panel.Visible = false
			return
		end
		local target = plot.Position + Vector3.new(0, 8, 0)
		local vp = cam.ViewportSize
		local sp = cam:WorldToViewportPoint(target)
		local inView = sp.Z > 0 and sp.X > MARGIN and sp.X < vp.X - MARGIN and sp.Y > MARGIN and sp.Y < vp.Y - MARGIN
		if inView then
			panel.Visible = false
			return
		end
		panel.Visible = true
		local center = Vector2.new(vp.X / 2, vp.Y / 2)
		local screenPos = Vector2.new(sp.X, sp.Y)
		if sp.Z <= 0 then
			screenPos = center * 2 - screenPos
		end
		local dir = screenPos - center
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, -1)
		end
		local clamped = Vector2.new(
			math.clamp(screenPos.X, MARGIN, vp.X - MARGIN),
			math.clamp(screenPos.Y, MARGIN, vp.Y - MARGIN)
		)
		panel.Position = UDim2.fromOffset(clamped.X, clamped.Y)
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
		dist.Text = math.floor((cam.CFrame.Position - target).Magnitude) .. " studs"
	end)
end

return ArrowController
