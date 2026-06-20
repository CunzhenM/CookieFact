--!strict
-- Per-plot Machine Shop (server). Each plot gets a kiosk with a ProximityPrompt; only the plot's
-- OWNER may open it -- anyone else gets an error toast. Opening fires a remote the client uses to
-- pop the styled MachineShop UI. Additive; filters PromptTriggered to our prompts only.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))

local ShopService = {}

local KIOSK_FOLDER = "CookieShopKiosks"
local kioskPlot = {}
local promptKiosk = {}

local function plotsInWorkspace()
	local out = {}
	for _, c in ipairs(Workspace:GetChildren()) do
		if c:IsA("BasePart") and c.Name:match("^Plot(%d+)$") then
			table.insert(out, c)
		end
	end
	return out
end

local function buildKiosk(plot, parent)
	local model = Instance.new("Model")
	model.Name = "ShopKiosk_" .. plot.Name

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = Vector3.new(4, 5, 4)
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(24, 26, 32)
	base.CFrame = plot.CFrame * CFrame.new(plot.Size.X / 2 - 8, plot.Size.Y / 2 + base.Size.Y / 2, plot.Size.Z / 2 - 8)
	base.Parent = model
	model.PrimaryPart = base

	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Anchored = true
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(120, 200, 255)
	glow.Size = Vector3.new(4.2, 0.4, 4.2)
	glow.CFrame = base.CFrame * CFrame.new(0, base.Size.Y / 2 + 0.2, 0)
	glow.Parent = model
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Brightness = 2
	light.Range = 10
	light.Parent = glow

	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(180, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, base.Size.Y / 2 + 2.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 90
	bb.Adornee = base
	bb.Parent = base
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	panel.BackgroundTransparency = 0.2
	panel.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
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
	lbl.Text = "Machine Shop"
	lbl.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = lbl

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Machines"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base

	model.Parent = parent
	kioskPlot[model] = plot
	promptKiosk[prompt] = model
end

function ShopService.Start()
	local remotes = ReplicatedStorage:FindFirstChild(PlacementConfig.RemotesFolderName)
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = PlacementConfig.RemotesFolderName
		remotes.Parent = ReplicatedStorage
	end
	local function ensure(name)
		local r = remotes:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = remotes
		end
		return r
	end
	local openR = ensure(PlacementConfig.Remotes.OpenShop)
	local errR = ensure(PlacementConfig.Remotes.ShopError)

	local folder = Workspace:FindFirstChild(KIOSK_FOLDER)
	if folder then
		folder:ClearAllChildren()
	else
		folder = Instance.new("Folder")
		folder.Name = KIOSK_FOLDER
		folder.Parent = Workspace
	end
	kioskPlot = {}
	promptKiosk = {}
	for _, plot in ipairs(plotsInWorkspace()) do
		buildKiosk(plot, folder)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local kiosk = promptKiosk[prompt]
		if not kiosk then
			return
		end
		local plot = kioskPlot[kiosk]
		local owner = plot and plot:GetAttribute("OwnerUserId")
		if owner == player.UserId then
			openR:FireClient(player)
		else
			errR:FireClient(player, "This isn't your shop!")
		end
	end)
end

return ShopService
