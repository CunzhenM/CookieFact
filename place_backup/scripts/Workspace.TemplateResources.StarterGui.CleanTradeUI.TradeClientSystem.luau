local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("TradeEvents")

-- 📌 MAPPING TO YOUR MANUAL UI
local MainGui = script.Parent

local OpenBtn = MainGui:WaitForChild("OpenBtn")

local PlayerListFrame = MainGui:WaitForChild("PlayerListFrame")
local PlayerScroll = PlayerListFrame:WaitForChild("PlayerScroll")
local RequestBtn = PlayerListFrame:WaitForChild("RequestBtn")
local CloseListBtn = PlayerListFrame:WaitForChild("CloseListBtn")

local PopupFrame = MainGui:WaitForChild("PopupFrame")
local PopupText = PopupFrame:WaitForChild("PopupText")
local AcceptReqBtn = PopupFrame:WaitForChild("AcceptReqBtn")
local DeclineReqBtn = PopupFrame:WaitForChild("DeclineReqBtn")

local TradeMainFrame = MainGui:WaitForChild("TradeMainFrame")
local CancelTradeBtn = TradeMainFrame:WaitForChild("CancelTradeBtn")
local Container = TradeMainFrame:WaitForChild("Container")

local InvScroll = Container:WaitForChild("InventoryColumn"):WaitForChild("InvScroll")
local MyOfferScroll = Container:WaitForChild("MyOfferColumn"):WaitForChild("MyOfferScroll")
local TheirOfferScroll = Container:WaitForChild("TheirOfferColumn"):WaitForChild("TheirOfferScroll")
local MyAcceptBtn = Container:WaitForChild("MyOfferColumn"):WaitForChild("MyAcceptBtn")
local TheirStatus = Container:WaitForChild("TheirOfferColumn"):WaitForChild("TheirStatus")

local OriginalSizes = {
	[PlayerListFrame] = UDim2.new(0, 380, 0, 520),
	[PopupFrame] = UDim2.new(0, 400, 0, 220),
	[TradeMainFrame] = UDim2.new(0.9, 0, 0.85, 0)
}

--------------------------------------------------
-- 🎵 SOUND SYSTEM
--------------------------------------------------
local sounds = {
	Click = Instance.new("Sound", MainGui),
	Hover = Instance.new("Sound", MainGui),
	Success = Instance.new("Sound", MainGui),
	Error = Instance.new("Sound", MainGui),
	ConfettiPop = Instance.new("Sound", MainGui),
	PopIn = Instance.new("Sound", MainGui) -- New sound for items appearing
}

sounds.Click.SoundId = "rbxassetid://6895079853"
sounds.Click.Volume = 0.5
sounds.Hover.SoundId = "rbxassetid://6895079632"
sounds.Hover.Volume = 0.2
sounds.Hover.Pitch = 1.3 
sounds.Success.SoundId = "rbxassetid://2865227271"
sounds.Success.Volume = 0.6
sounds.Error.SoundId = "rbxassetid://6895078103"
sounds.Error.Volume = 0.6
sounds.ConfettiPop.SoundId = "rbxassetid://5886931501"
sounds.ConfettiPop.Volume = 0.8
sounds.PopIn.SoundId = "rbxassetid://6895079632"
sounds.PopIn.Volume = 0.1
sounds.PopIn.Pitch = 1.8

local function playSound(name)
	if sounds[name] then sounds[name]:Play() end
end

--------------------------------------------------
-- ✨ PEAK DETAILING: VISUAL EFFECTS
--------------------------------------------------
local function addUpgradedEffect(btn)
	local scale = btn:FindFirstChild("UIScale") or Instance.new("UIScale", btn)
	scale.Scale = 1

	btn.MouseEnter:Connect(function()
		if btn.AutoButtonColor == false then return end -- Don't hover if disabled
		playSound("Hover")
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Scale = 1}):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		if btn.AutoButtonColor == false then return end
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 0.92}):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		if btn.AutoButtonColor == false then return end
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
	end)
end

-- Apply effects
addUpgradedEffect(OpenBtn)
addUpgradedEffect(CloseListBtn)
addUpgradedEffect(RequestBtn)
addUpgradedEffect(AcceptReqBtn)
addUpgradedEffect(DeclineReqBtn)
addUpgradedEffect(CancelTradeBtn)
addUpgradedEffect(MyAcceptBtn)

local function playConfetti(parentFrame)
	playSound("ConfettiPop")
	local colors = {
		Color3.fromRGB(255, 235, 59), Color3.fromRGB(76, 175, 80), 
		Color3.fromRGB(33, 150, 243), Color3.fromRGB(255, 87, 34), 
		Color3.fromRGB(233, 30, 99), Color3.fromRGB(156, 39, 176)
	}

	for i = 1, 120 do -- Increased density for peak detailing
		local size = math.random(8, 16)
		local conf = Instance.new("Frame")
		conf.Size = UDim2.new(0, size, 0, size)
		conf.Position = UDim2.new(0.5, 0, 1, -50)
		conf.BackgroundColor3 = colors[math.random(1, #colors)]
		conf.ZIndex = 100
		conf.BorderSizePixel = 0
		conf.Parent = parentFrame

		local burstX = math.random(-500, 500)
		local burstY = math.random(-700, -250)

		local tUp = TweenService:Create(conf, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, burstX, 1, burstY), Rotation = math.random(-360, 360)
		})
		local tDown = TweenService:Create(conf, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, burstX + math.random(-150, 150), 1.6, 0), Rotation = math.random(-1080, 1080), BackgroundTransparency = 1
		})

		tUp:Play()
		tUp.Completed:Connect(function() tDown:Play() end)
		tDown.Completed:Connect(function() conf:Destroy() end)
	end
end

local function toggleUI(frame, show)
	if show then
		frame.Visible = true
		frame.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = OriginalSizes[frame]}):Play()
	else
		local t = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)})
		t:Play()
		t.Completed:Connect(function() frame.Visible = false end)
	end
end

--------------------------------------------------
-- 🛠️ GAMEPLAY LOGIC & QoL FEATURES
--------------------------------------------------
local selectedPlayer = nil
local myCurrentOffer = {}
local isLocked = false
local isConfirming = false
local myConfirmedState = false -- NEW: Tracks if we clicked confirm
local requester = nil
local actionDebounce = false -- NEW: Prevents button spam

-- Player List
OpenBtn.MouseButton1Click:Connect(function()
	if actionDebounce then return end
	actionDebounce = true; task.wait(0.2); actionDebounce = false

	playSound("Click")
	if PlayerListFrame.Visible then toggleUI(PlayerListFrame, false) return end
	toggleUI(PlayerListFrame, true)

	for _, child in ipairs(PlayerScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= Player then
			local pFrame = Instance.new("Frame")
			pFrame.Size = UDim2.new(0, 266, 0, 54) 
			pFrame.BackgroundColor3 = Color3.fromRGB(240, 245, 255)
			pFrame.Parent = PlayerScroll
			Instance.new("UICorner", pFrame).CornerRadius = UDim.new(0, 10)

			local stroke = Instance.new("UIStroke", pFrame)
			stroke.Color = Color3.fromRGB(200,200,200)
			stroke.Thickness = 2

			local thumb = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
			local imageLabel = Instance.new("ImageLabel", pFrame)
			imageLabel.Size = UDim2.new(0, 44, 0, 44)
			imageLabel.Position = UDim2.new(0, 5, 0, 5)
			imageLabel.Image = thumb
			imageLabel.BackgroundTransparency = 1
			Instance.new("UICorner", imageLabel).CornerRadius = UDim.new(1, 0) 

			local textL = Instance.new("TextLabel", pFrame)
			textL.Size = UDim2.new(1, -70, 1, 0)
			textL.Position = UDim2.new(0, 60, 0, 0)
			textL.Text = p.Name
			textL.Font = Enum.Font.FredokaOne
			textL.TextSize = 18
			textL.TextXAlignment = Enum.TextXAlignment.Left
			textL.BackgroundTransparency = 1
			textL.TextColor3 = Color3.fromRGB(40,40,40)

			local btn = Instance.new("TextButton", pFrame)
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = ""
			addUpgradedEffect(btn) 

			btn.MouseButton1Click:Connect(function()
				playSound("Click")
				selectedPlayer = p
				for _, c in ipairs(PlayerScroll:GetChildren()) do 
					if c:IsA("Frame") then 
						c.BackgroundColor3 = Color3.fromRGB(240, 245, 255) 
						c:FindFirstChild("UIStroke").Color = Color3.fromRGB(200,200,200)
					end 
				end
				pFrame.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
				stroke.Color = Color3.fromRGB(76, 175, 80) -- Green glow when selected!
			end)
		end
	end
end)

CloseListBtn.MouseButton1Click:Connect(function() playSound("Click"); toggleUI(PlayerListFrame, false) end)

RequestBtn.MouseButton1Click:Connect(function()
	if actionDebounce then return end
	if selectedPlayer then
		actionDebounce = true
		playSound("Success")
		Events.SendRequest:FireServer(selectedPlayer)
		RequestBtn.Text = "SENT TO " .. string.upper(selectedPlayer.Name) .. "!"
		RequestBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		task.wait(2.5) 
		RequestBtn.Text = "SEND REQUEST"
		RequestBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
		actionDebounce = false
	else 
		playSound("Error") 
	end
end)

Events.SendRequest.OnClientEvent:Connect(function(plr)
	playSound("Success")
	requester = plr
	PopupText.Text = "<b>"..plr.Name .. "</b> sent a trade request!"
	PopupText.RichText = true
	toggleUI(PopupFrame, true)
end)

DeclineReqBtn.MouseButton1Click:Connect(function() playSound("Click"); toggleUI(PopupFrame, false); Events.DeclineRequest:FireServer(requester) end)
AcceptReqBtn.MouseButton1Click:Connect(function() playSound("Click"); toggleUI(PopupFrame, false); Events.AcceptRequest:FireServer(requester) end)

-- 📌 ITEM UI GENERATOR (With Staggered Waterfall Animation)
local function buildItemCard(toolName, parentFrame, clickCallback, delayIndex)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 90, 0, 90) 
	card.Text = "" 
	card.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	card.Parent = parentFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", card).Color = Color3.fromRGB(200,200,200)

	-- PEAK DETAILING: Waterfall Pop-in Animation
	local scale = Instance.new("UIScale", card)
	scale.Scale = 0
	task.delay(delayIndex * 0.04, function() -- Staggered delay
		if not card.Parent then return end
		playSound("PopIn")
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)

	addUpgradedEffect(card) 

	local iconImage = Instance.new("ImageLabel", card)
	iconImage.Size = UDim2.new(0.6, 0, 0.6, 0)
	iconImage.Position = UDim2.new(0.2, 0, 0.1, 0)
	iconImage.BackgroundTransparency = 1
	iconImage.ScaleType = Enum.ScaleType.Fit

	local realTool = Player.Backpack:FindFirstChild(toolName) or Player.Character:FindFirstChild(toolName)
	if realTool and realTool.TextureId ~= "" then iconImage.Image = realTool.TextureId
	else iconImage.Image = "rbxassetid://10650961811" end

	local nameText = Instance.new("TextLabel", card)
	nameText.Size = UDim2.new(1, -10, 0, 20)
	nameText.Position = UDim2.new(0, 5, 1, -25)
	nameText.Text = toolName
	nameText.Font = Enum.Font.GothamBold
	nameText.TextSize = 10
	nameText.TextColor3 = Color3.fromRGB(60,60,60)
	nameText.TextWrapped = true
	nameText.BackgroundTransparency = 1

	card.MouseButton1Click:Connect(function()
		playSound("Click")
		clickCallback()
	end)
end

local function reloadShiftUI()
	for _, c in ipairs(InvScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for _, c in ipairs(MyOfferScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end

	local allTools = {}
	for _, t in ipairs(Player.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(allTools, t) end end
	for _, t in ipairs(Player.Character:GetChildren()) do if t:IsA("Tool") then table.insert(allTools, t) end end

	local delayCount = 0
	for _, toolInstance in ipairs(allTools) do
		if not table.find(myCurrentOffer, toolInstance) then
			delayCount += 1
			buildItemCard(toolInstance.Name, InvScroll, function()
				if isLocked or isConfirming then return end
				table.insert(myCurrentOffer, toolInstance)
				Events.UpdateOffer:FireServer(toolInstance, true)
				reloadShiftUI()
			end, delayCount)
		end
	end

	local offerDelayCount = 0
	for _, toolInstance in ipairs(myCurrentOffer) do
		offerDelayCount += 1
		buildItemCard(toolInstance.Name, MyOfferScroll, function()
			if isLocked or isConfirming then return end
			local idx = table.find(myCurrentOffer, toolInstance)
			if idx then table.remove(myCurrentOffer, idx) end
			Events.UpdateOffer:FireServer(toolInstance, false)
			reloadShiftUI()
		end, offerDelayCount)
	end
end

-- Trade Open
Events.AcceptRequest.OnClientEvent:Connect(function()
	toggleUI(PlayerListFrame, false)
	isLocked = false
	isConfirming = false
	myConfirmedState = false
	myCurrentOffer = {}
	reloadShiftUI()

	for _, c in ipairs(TheirOfferScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	MyAcceptBtn.Text = "ACCEPT"
	MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
	MyAcceptBtn.AutoButtonColor = true

	TheirStatus.Text = "Waiting..."
	TheirStatus.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	toggleUI(TradeMainFrame, true)
end)

-- Network Updates
Events.ClientStateUpdate.OnClientEvent:Connect(function(action, data)
	if action == "UpdateTheirOffer" then
		for _, c in ipairs(TheirOfferScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local count = 0
		for _, toolName in ipairs(data) do count += 1; buildItemCard(toolName, TheirOfferScroll, function() end, count) end

	elseif action == "SetMyReady" then
		if data then 
			MyAcceptBtn.Text = "READY ✅"
			MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(33, 150, 243) -- Blue
		else 
			MyAcceptBtn.Text = "ACCEPT"
			MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80) -- Green
		end

	elseif action == "SetTheirReady" then
		if data then 
			playSound("Success")
			TheirStatus.Text = "Ready! ✅"
			TheirStatus.BackgroundColor3 = Color3.fromRGB(33, 150, 243)
		else 
			TheirStatus.Text = "Waiting..."
			TheirStatus.BackgroundColor3 = Color3.fromRGB(80, 80, 80) 
		end

	elseif action == "ResetReady" then
		isLocked = false
		MyAcceptBtn.Text = "ACCEPT"; MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
		TheirStatus.Text = "Waiting..."; TheirStatus.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

	elseif action == "StartCountdown" then
		isLocked = true
		for i = 3, 1, -1 do
			if not TradeMainFrame.Visible or not isLocked then return end
			playSound("Hover")
			MyAcceptBtn.Text = "Locking in " .. i .. "..."
			MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(158, 158, 158)
			TheirStatus.Text = "Locking in " .. i .. "..."
			TheirStatus.BackgroundColor3 = Color3.fromRGB(158, 158, 158)
			task.wait(1)
		end

	elseif action == "UnlockConfirm" then
		if not isLocked then return end
		playSound("Success")
		isConfirming = true
		myConfirmedState = false
		MyAcceptBtn.AutoButtonColor = true
		MyAcceptBtn.Text = "CONFIRM TRADE"
		MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(255, 152, 0) -- Orange
		TheirStatus.Text = "Waiting for Confirm..."
		TheirStatus.BackgroundColor3 = Color3.fromRGB(158, 158, 158)

	elseif action == "SetTheirConfirm" then
		TheirStatus.Text = "Confirmed! ✅"
		TheirStatus.BackgroundColor3 = Color3.fromRGB(76, 175, 80) -- Green completion
	end
end)

-- 📌 YOUR REQUESTED FEATURE: IMMEDIATE CONFIRM VISUALS
MyAcceptBtn.MouseButton1Click:Connect(function()
	if isLocked and not isConfirming then return end 
	if myConfirmedState then return end -- Already confirmed, ignore clicks

	playSound("Click")

	-- Immediate Client-Side Feedback!
	if isConfirming then
		myConfirmedState = true
		MyAcceptBtn.Text = "✅ CONFIRMED!"
		MyAcceptBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80) -- Turns Green instantly
		MyAcceptBtn.AutoButtonColor = false -- Disables hover effect to show it's locked in
		playSound("Success")
	end

	Events.ToggleAction:FireServer()
end)

CancelTradeBtn.MouseButton1Click:Connect(function()
	playSound("Error")
	Events.CancelTrade:FireServer() 
end)

Events.CancelTrade.OnClientEvent:Connect(function(success)
	myCurrentOffer = {}
	isLocked = false
	isConfirming = false
	myConfirmedState = false

	if success then 
		playConfetti(TradeMainFrame) 
		task.wait(2.5) 
	end

	toggleUI(TradeMainFrame, false)
end)