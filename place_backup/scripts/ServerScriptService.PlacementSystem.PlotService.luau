--!strict
-- Per-player plot ownership. Discovers Workspace.Plot<number> parts, assigns each joining
-- player a free one (OwnerUserId/OwnerName attrs), floats a name tag above it, frees on leave.
-- getPlot(player) is how other systems scope editing to a player's own plot.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotService = {}
local released = Instance.new("BindableEvent")
PlotService.PlotReleased = released.Event

local plots = {}
local playerPlot = {}
local tags = {}

local function ensureTag(plot)
	if tags[plot] then
		return tags[plot]
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "PlotNameTag"
	bb.Size = UDim2.fromOffset(210, 52)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 22, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 600
	bb.Parent = plot
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	panel.BackgroundTransparency = 0.2
	panel.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = panel
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextStrokeTransparency = 0.5
	lbl.Text = "Open Plot"
	lbl.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = lbl
	tags[plot] = lbl
	return lbl
end

local function refreshTag(plot)
	local lbl = ensureTag(plot)
	local owner = plot:GetAttribute("OwnerName")
	if owner then
		lbl.Text = owner .. "'s Factory"
		lbl.TextColor3 = Color3.fromRGB(120, 255, 150)
	else
		lbl.Text = "Open Plot"
		lbl.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function discoverPlots()
	local list = {}
	for _, c in ipairs(Workspace:GetChildren()) do
		local n = c.Name:match("^Plot(%d+)$")
		if n and c:IsA("BasePart") then
			table.insert(list, { part = c, num = tonumber(n) })
		end
	end
	table.sort(list, function(a, b)
		return a.num < b.num
	end)
	plots = {}
	for _, e in ipairs(list) do
		table.insert(plots, e.part)
	end
end

function PlotService.getPlot(player)
	return playerPlot[player]
end

function PlotService.ownsPosition(player, worldPos)
	local plot = playerPlot[player]
	if not plot then
		return false
	end
	local lp = plot.CFrame:PointToObjectSpace(worldPos)
	return math.abs(lp.X) <= plot.Size.X / 2 and math.abs(lp.Z) <= plot.Size.Z / 2
end

local function assign(player)
	if playerPlot[player] then
		return
	end
	for _, plot in ipairs(plots) do
		if not plot:GetAttribute("OwnerUserId") then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			playerPlot[player] = plot
			player:SetAttribute("PlotName", plot.Name)
			refreshTag(plot)
			return
		end
	end
	warn("[PlacementSystem] No free plot for " .. player.Name .. " (all " .. #plots .. " taken).")
end

local function release(player)
	local plot = playerPlot[player]
	playerPlot[player] = nil
	player:SetAttribute("PlotName", nil)
	if not plot then
		return
	end
	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("OwnerName", nil)
	refreshTag(plot)
	released:Fire(plot)
end

function PlotService.Start()
	discoverPlots()
	for _, plot in ipairs(plots) do
		refreshTag(plot)
	end
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(assign, p)
	end
end

return PlotService
