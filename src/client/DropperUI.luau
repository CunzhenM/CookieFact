--!strict
-- Dough Dropper interface (client). Hover a placed dropper -> white outline. Click it -> open the
-- crafting GUI laid out like the sketch:
--   (1) left: scrolling recipe list -> selecting one updates (2) and (3).
--   (2) cookie preview + description + stat, with a ticker of the machine's ingredient stock on top.
--   (3) required ingredients with met/unmet checkmarks, a progress bar, and Make / Auto Make buttons.
-- Make/Auto fire server remotes (DropperMachine validates + produces). Machine state lives in model
-- attributes, so the UI reads it live.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropperConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DropperConfig"))

local DropperUI = {}

local PANEL = Color3.fromRGB(24, 26, 32)
local CARD = Color3.fromRGB(34, 38, 48)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 200, 120)
local RED = Color3.fromRGB(255, 95, 95)
local MUTE = Color3.fromRGB(170, 176, 190)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local current: Instance? = nil -- the dropper the GUI is showing
local currentRecipe: string? = nil
local attrConn: RBXScriptConnection? = nil
local tickerOffset = 0

-- ===== tiny ui helpers =====
local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end
local function stroke(p: Instance, color: Color3, tr: number, th: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = tr
	s.Thickness = th
	s.Parent = p
end
local function pad(p: Instance, n: number)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, n)
	u.PaddingBottom = UDim.new(0, n)
	u.PaddingLeft = UDim.new(0, n)
	u.PaddingRight = UDim.new(0, n)
	u.Parent = p
end

-- ===== built once =====
local gui, panel, recipeList, cookieVF, descLabel, statLabel, tickerLabel, ingHolder, progFill, makeBtn, autoBtn
local ingRows: { [string]: { amt: TextLabel, check: TextLabel } } = {}

local function buildCookieViewport(parent: Instance)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Cookie"
	vf.BackgroundColor3 = CARD
	vf.BackgroundTransparency = 0.15
	vf.Size = UDim2.fromScale(0.42, 0.82)
	vf.Position = UDim2.fromScale(0.04, 0.12)
	corner(vf, 12)
	stroke(vf, WHITE, 0.6, 1.5)
	local cam = Instance.new("Camera")
	vf.CurrentCamera = cam
	cam.Parent = vf
	local tmpl = Workspace:FindFirstChild("Cookie")
	if tmpl and tmpl:IsA("BasePart") then
		local c = tmpl:Clone()
		c.Anchored = true
		c.CFrame = CFrame.new()
		c.Parent = vf
		local d = math.max(c.Size.Magnitude, 2)
		cam.CFrame = CFrame.new(Vector3.new(0, d * 0.5, d * 1.15), Vector3.new(0, 0, 0))
		vf:SetAttribute("HasModel", true)
	else
		local ball = Instance.new("Frame")
		ball.Size = UDim2.fromScale(0.55, 0.55)
		ball.Position = UDim2.fromScale(0.225, 0.225)
		ball.BackgroundColor3 = Color3.fromRGB(170, 110, 60)
		corner(ball, 1000)
		ball.Parent = vf
	end
	vf.Parent = parent
	return vf
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "DropperUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = gui
	dim.Activated:Connect(function()
		DropperUI.close()
	end)

	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(940, 700)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	corner(panel, 16)
	stroke(panel, WHITE, 0.4, 2)
	pad(panel, 14)
	panel.Parent = gui

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(34, 34)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, 0, 0, 0)
	close.BackgroundColor3 = Color3.fromRGB(54, 40, 44)
	close.Text = "✕"
	close.TextColor3 = WHITE
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.ZIndex = 5
	corner(close, 8)
	close.Parent = panel
	close.Activated:Connect(function()
		DropperUI.close()
	end)

	-- (1) recipe list
	local sec1 = Instance.new("Frame")
	sec1.Position = UDim2.fromScale(0, 0)
	sec1.Size = UDim2.new(0.22, -6, 1, 0)
	sec1.BackgroundColor3 = CARD
	sec1.BackgroundTransparency = 0.2
	corner(sec1, 12)
	stroke(sec1, WHITE, 0.7, 1)
	sec1.Parent = panel
	local title1 = Instance.new("TextLabel")
	title1.Size = UDim2.new(1, 0, 0, 34)
	title1.BackgroundTransparency = 1
	title1.Text = "Recipes"
	title1.Font = Enum.Font.GothamBold
	title1.TextSize = 16
	title1.TextColor3 = WHITE
	title1.Parent = sec1
	recipeList = Instance.new("ScrollingFrame")
	recipeList.Position = UDim2.fromOffset(0, 36)
	recipeList.Size = UDim2.new(1, 0, 1, -40)
	recipeList.BackgroundTransparency = 1
	recipeList.BorderSizePixel = 0
	recipeList.ScrollBarThickness = 5
	recipeList.CanvasSize = UDim2.new()
	recipeList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	recipeList.Parent = sec1
	local rl = Instance.new("UIListLayout")
	rl.Padding = UDim.new(0, 6)
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = recipeList

	-- (2) cookie preview
	local sec2 = Instance.new("Frame")
	sec2.Position = UDim2.new(0.22, 6, 0, 0)
	sec2.Size = UDim2.new(0.78, -6, 0.66, -6)
	sec2.BackgroundColor3 = CARD
	sec2.BackgroundTransparency = 0.2
	corner(sec2, 12)
	stroke(sec2, WHITE, 0.7, 1)
	sec2.Parent = panel
	-- ticker
	local tickerHolder = Instance.new("Frame")
	tickerHolder.Size = UDim2.new(1, 0, 0, 30)
	tickerHolder.BackgroundColor3 = PANEL
	tickerHolder.BackgroundTransparency = 0.2
	tickerHolder.ClipsDescendants = true
	corner(tickerHolder, 8)
	tickerHolder.Parent = sec2
	tickerLabel = Instance.new("TextLabel")
	tickerLabel.AutomaticSize = Enum.AutomaticSize.X
	tickerLabel.Size = UDim2.new(0, 0, 1, 0)
	tickerLabel.BackgroundTransparency = 1
	tickerLabel.Font = Enum.Font.GothamMedium
	tickerLabel.TextSize = 14
	tickerLabel.TextColor3 = Color3.fromRGB(255, 226, 165)
	tickerLabel.TextXAlignment = Enum.TextXAlignment.Left
	tickerLabel.Text = ""
	tickerLabel.Parent = tickerHolder
	cookieVF = buildCookieViewport(sec2)
	cookieVF.Position = UDim2.fromScale(0.04, 0.16)
	cookieVF.Size = UDim2.fromScale(0.42, 0.78)
	local info = Instance.new("Frame")
	info.Position = UDim2.fromScale(0.5, 0.16)
	info.Size = UDim2.fromScale(0.46, 0.78)
	info.BackgroundTransparency = 1
	info.Parent = sec2
	local rname = Instance.new("TextLabel")
	rname.Name = "RecipeName"
	rname.Size = UDim2.new(1, 0, 0, 30)
	rname.BackgroundTransparency = 1
	rname.Font = Enum.Font.GothamBold
	rname.TextSize = 22
	rname.TextXAlignment = Enum.TextXAlignment.Left
	rname.TextColor3 = WHITE
	rname.Text = ""
	rname.Parent = info
	descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.fromOffset(0, 38)
	descLabel.Size = UDim2.new(1, 0, 0, 120)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 15
	descLabel.TextWrapped = true
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextColor3 = MUTE
	descLabel.Text = ""
	descLabel.Parent = info
	statLabel = Instance.new("TextLabel")
	statLabel.AnchorPoint = Vector2.new(0, 1)
	statLabel.Position = UDim2.fromScale(0, 1)
	statLabel.Size = UDim2.new(1, 0, 0, 26)
	statLabel.BackgroundTransparency = 1
	statLabel.Font = Enum.Font.GothamMedium
	statLabel.TextSize = 14
	statLabel.TextXAlignment = Enum.TextXAlignment.Left
	statLabel.TextColor3 = Color3.fromRGB(150, 210, 235)
	statLabel.Text = ""
	statLabel.Parent = info

	-- (3) ingredients + buttons + progress
	local sec3 = Instance.new("Frame")
	sec3.Position = UDim2.new(0.22, 6, 0.66, 6)
	sec3.Size = UDim2.new(0.78, -6, 0.34, -6)
	sec3.BackgroundColor3 = CARD
	sec3.BackgroundTransparency = 0.2
	corner(sec3, 12)
	stroke(sec3, WHITE, 0.7, 1)
	sec3.Parent = panel
	ingHolder = Instance.new("Frame")
	ingHolder.Position = UDim2.fromOffset(12, 10)
	ingHolder.Size = UDim2.new(0.72, -12, 1, -46)
	ingHolder.BackgroundTransparency = 1
	ingHolder.Parent = sec3
	local il = Instance.new("UIListLayout")
	il.Padding = UDim.new(0, 4)
	il.SortOrder = Enum.SortOrder.LayoutOrder
	il.Parent = ingHolder
	-- progress
	local progBg = Instance.new("Frame")
	progBg.AnchorPoint = Vector2.new(0, 1)
	progBg.Position = UDim2.new(0, 12, 1, -10)
	progBg.Size = UDim2.new(0.72, -12, 0, 16)
	progBg.BackgroundColor3 = PANEL
	corner(progBg, 8)
	stroke(progBg, WHITE, 0.7, 1)
	progBg.Parent = sec3
	progFill = Instance.new("Frame")
	progFill.Size = UDim2.fromScale(0, 1)
	progFill.BackgroundColor3 = GREEN
	corner(progFill, 8)
	progFill.Parent = progBg
	-- buttons (right, stacked)
	makeBtn = Instance.new("TextButton")
	makeBtn.AnchorPoint = Vector2.new(1, 0)
	makeBtn.Position = UDim2.new(1, -12, 0, 12)
	makeBtn.Size = UDim2.new(0.24, 0, 0.42, -6)
	makeBtn.BackgroundColor3 = GREEN
	makeBtn.Text = "Make"
	makeBtn.Font = Enum.Font.GothamBold
	makeBtn.TextSize = 18
	makeBtn.TextColor3 = WHITE
	makeBtn.AutoButtonColor = true
	corner(makeBtn, 10)
	makeBtn.Parent = sec3
	makeBtn.Activated:Connect(function()
		if current and currentRecipe then
			DropperUI._makeR:FireServer(current, currentRecipe)
		end
	end)
	autoBtn = Instance.new("TextButton")
	autoBtn.AnchorPoint = Vector2.new(1, 1)
	autoBtn.Position = UDim2.new(1, -12, 1, -10)
	autoBtn.Size = UDim2.new(0.24, 0, 0.42, -6)
	autoBtn.BackgroundColor3 = Color3.fromRGB(60, 64, 78)
	autoBtn.Text = "Auto: Off"
	autoBtn.Font = Enum.Font.GothamBold
	autoBtn.TextSize = 16
	autoBtn.TextColor3 = WHITE
	corner(autoBtn, 10)
	autoBtn.Parent = sec3
	autoBtn.Activated:Connect(function()
		if current and currentRecipe then
			local on = not (current:GetAttribute("AutoMake") == true)
			DropperUI._autoR:FireServer(current, currentRecipe, on)
		end
	end)
end

-- ===== populate / refresh =====
local function buildRecipeButtons()
	for _, c in ipairs(recipeList:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for i, r in ipairs(DropperConfig.Recipes) do
		local b = Instance.new("TextButton")
		b.Name = r.id
		b.Size = UDim2.new(0.92, 0, 0, 40)
		b.BackgroundColor3 = PANEL
		b.Text = r.name
		b.Font = Enum.Font.GothamSemibold
		b.TextSize = 14
		b.TextColor3 = WHITE
		b.LayoutOrder = i
		corner(b, 8)
		stroke(b, r.color, 0.2, 2)
		b.Parent = recipeList
		b.Activated:Connect(function()
			DropperUI.select(r.id)
		end)
	end
end

local function rebuildIngredientRows(recipe)
	for _, c in ipairs(ingHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	ingRows = {}
	local order = 0
	for id, amt in pairs(recipe.requires) do
		order += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Parent = ingHolder
		local check = Instance.new("TextLabel")
		check.Size = UDim2.fromOffset(24, 24)
		check.BackgroundTransparency = 1
		check.Font = Enum.Font.GothamBold
		check.TextSize = 18
		check.Text = "•"
		check.TextColor3 = MUTE
		check.Parent = row
		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(28, 0)
		name.Size = UDim2.new(1, -120, 1, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.Gotham
		name.TextSize = 15
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = WHITE
		name.Text = DropperConfig.ingredientName(id)
		name.Parent = row
		local amtL = Instance.new("TextLabel")
		amtL.AnchorPoint = Vector2.new(1, 0)
		amtL.Position = UDim2.fromScale(1, 0)
		amtL.Size = UDim2.fromOffset(90, 24)
		amtL.BackgroundTransparency = 1
		amtL.Font = Enum.Font.GothamMedium
		amtL.TextSize = 14
		amtL.TextXAlignment = Enum.TextXAlignment.Right
		amtL.TextColor3 = MUTE
		amtL.Text = "0/" .. amt
		amtL.Parent = row
		ingRows[id] = { amt = amtL, check = check }
	end
end

local function refresh()
	local model = current
	local recipe = DropperConfig.getRecipe(currentRecipe)
	if not (model and recipe) then
		return
	end
	-- ingredient checks
	for id, need in pairs(recipe.requires) do
		local have = (model:GetAttribute("Ing_" .. id) :: number?) or 0
		local row = ingRows[id]
		if row then
			row.amt.Text = tostring(have) .. "/" .. need
			local ok = have >= need
			row.check.Text = ok and "✓" or "✗"
			row.check.TextColor3 = ok and GREEN or RED
		end
	end
	-- ticker (all stock)
	local parts = {}
	for _, ing in ipairs(DropperConfig.Ingredients) do
		local have = (model:GetAttribute("Ing_" .. ing.id) :: number?) or 0
		table.insert(parts, ing.name .. "  " .. tostring(have))
	end
	tickerLabel.Text = table.concat(parts, "        ") .. "        "
	-- auto button
	local auto = model:GetAttribute("AutoMake") == true
	autoBtn.Text = auto and "Auto: On" or "Auto: Off"
	autoBtn.BackgroundColor3 = auto and GREEN or Color3.fromRGB(60, 64, 78)
end

function DropperUI.select(recipeId: string)
	local recipe = DropperConfig.getRecipe(recipeId)
	if not recipe then
		return
	end
	currentRecipe = recipeId
	local rname = cookieVF.Parent:FindFirstChild("RecipeName", true) or panel:FindFirstChild("RecipeName", true)
	for _, d in ipairs(panel:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "RecipeName" then
			d.Text = recipe.name
		end
	end
	descLabel.Text = recipe.description
	statLabel.Text = recipe.stat
	-- highlight selected in list
	for _, c in ipairs(recipeList:GetChildren()) do
		if c:IsA("TextButton") then
			c.BackgroundColor3 = (c.Name == recipeId) and Color3.fromRGB(46, 52, 66) or PANEL
		end
	end
	rebuildIngredientRows(recipe)
	refresh()
end

function DropperUI.open(dropper: Instance)
	current = dropper
	if attrConn then
		attrConn:Disconnect()
	end
	attrConn = dropper.AttributeChanged:Connect(refresh)
	buildRecipeButtons()
	DropperUI.select((dropper:GetAttribute("Recipe") :: string?) or DropperConfig.Recipes[1].id)
	gui.Enabled = true
end

function DropperUI.close()
	gui.Enabled = false
	current = nil
	if attrConn then
		attrConn:Disconnect()
		attrConn = nil
	end
end

-- ===== hover + click in the 3D world =====
local hoverHighlight: Highlight? = nil
local hoverTarget: Instance? = nil

local function dropperUnderMouse(): Instance?
	local t = mouse.Target
	local cur: Instance? = t
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:GetAttribute("MachineId") == "DoughDropper" then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

function DropperUI.Start()
	build()
	local remotes = ReplicatedStorage:WaitForChild(DropperConfig.RemotesFolder)
	DropperUI._makeR = remotes:WaitForChild(DropperConfig.Remotes.Make)
	DropperUI._autoR = remotes:WaitForChild(DropperConfig.Remotes.SetAuto)

	RunService.RenderStepped:Connect(function(dt)
		-- hover outline (only when the panel is closed)
		if not gui.Enabled then
			local d = dropperUnderMouse()
			if d ~= hoverTarget then
				if hoverHighlight then
					hoverHighlight:Destroy()
					hoverHighlight = nil
				end
				hoverTarget = d
				if d then
					local hl = Instance.new("Highlight")
					hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					hl.FillTransparency = 1
					hl.OutlineTransparency = 0
					hl.OutlineColor = WHITE
					hl.Adornee = d
					hl.Parent = d
					hoverHighlight = hl
				end
			end
		elseif hoverHighlight then
			hoverHighlight:Destroy()
			hoverHighlight = nil
			hoverTarget = nil
		end
		-- ticker scroll
		if gui.Enabled then
			tickerOffset += dt * 60
			local w = tickerLabel.AbsoluteSize.X
			if w > 0 and tickerOffset > w then
				tickerOffset -= w
			end
			tickerLabel.Position = UDim2.fromOffset(-tickerOffset, 0)
			-- spin the cookie
			if cookieVF and cookieVF:GetAttribute("HasModel") then
				local m = cookieVF:FindFirstChildWhichIsA("BasePart")
				if m then
					m.CFrame = CFrame.Angles(0, os.clock() * 0.8, 0)
				end
			end
			-- progress bar: auto -> cooldown progress; else readiness
			local model = current
			if model then
				local recipe = DropperConfig.getRecipe(currentRecipe)
				local ready = recipe ~= nil
				if recipe then
					for id, need in pairs(recipe.requires) do
						if ((model:GetAttribute("Ing_" .. id) :: number?) or 0) < need then
							ready = false
							break
						end
					end
				end
				local frac
				if model:GetAttribute("AutoMake") == true then
					local since = Workspace:GetServerTimeNow() - ((model:GetAttribute("LastProducedAt") :: number?) or 0)
					frac = math.clamp(since / DropperConfig.AutoCooldown, 0, 1)
				else
					frac = ready and 1 or 0
				end
				progFill.Size = UDim2.fromScale(frac, 1)
				progFill.BackgroundColor3 = ready and GREEN or RED
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not gui.Enabled then
			local d = dropperUnderMouse()
			if d then
				DropperUI.open(d)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
			DropperUI.close()
		end
	end)
end

return DropperUI
