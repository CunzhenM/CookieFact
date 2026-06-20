local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local textBox = script.Parent :: TextBox
local container = textBox.Parent
local runButton = container:FindFirstChild("Run") :: ImageButton?
local selectButton = container:FindFirstChild("Select") :: ImageButton?
local stopButton = container:FindFirstChild("Stop") :: ImageButton?

-- Walk up to AdminPanel and grab SelectEvent.
-- Path: eventName -> Frame -> EventRunner -> Frame(SmallCommands) -> SmallCommands -> ScrollingFrame -> AdminPanel
local adminPanel = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent
local selectEventFrame = adminPanel:FindFirstChild("SelectEvent") :: Frame?
local scrollingFrame = selectEventFrame and selectEventFrame:FindFirstChild("ScrollingFrame")

-- Capture whatever Size you set in Studio so the open-tween restores to it.
-- (The previous version hardcoded UDim2.new(0.232, 0, 0.999, 0), overwriting your layout.)
local OPEN_SIZE = (selectEventFrame and selectEventFrame.Size) or UDim2.new(0.5, 0, 0.9, 0)
local CLOSED_SIZE = UDim2.new(0, 0, 0, 0)

local function getOrCreateRemote(name: string): RemoteEvent
	local r = ReplicatedStorage:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then return r end
	local rev = Instance.new("RemoteEvent")
	rev.Name = name
	rev.Parent = ReplicatedStorage
	return rev
end

local startEventRemote = getOrCreateRemote("StartEventRemote")
local stopEventRemote = getOrCreateRemote("StopEventRemote")

local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function closeSelectEvent()
	if not selectEventFrame then return end
	local tween = TweenService:Create(selectEventFrame, tweenInfo, { Size = CLOSED_SIZE })
	tween:Play()
	tween.Completed:Connect(function()
		if selectEventFrame.Size == CLOSED_SIZE then
			selectEventFrame.Visible = false
			selectEventFrame.Size = OPEN_SIZE
		end
	end)
end

local function openSelectEvent()
	if not selectEventFrame then return end
	selectEventFrame.Size = CLOSED_SIZE
	selectEventFrame.Visible = true
	TweenService:Create(selectEventFrame, tweenInfo, { Size = OPEN_SIZE }):Play()
end

if selectButton and selectEventFrame then
	selectButton.MouseButton1Click:Connect(function()
		if selectEventFrame.Visible then
			closeSelectEvent()
		else
			openSelectEvent()
		end
	end)
end

-- Wire every ImageButton/TextButton inside the ScrollingFrame.
-- The button's Name is the event name sent to the server.
local function wireEventButton(btn: Instance)
	if not (btn:IsA("ImageButton") or btn:IsA("TextButton")) then return end
	btn.MouseButton1Click:Connect(function()
		textBox.Text = btn.Name
		closeSelectEvent()
	end)
end

if scrollingFrame then
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		wireEventButton(child)
	end
	scrollingFrame.ChildAdded:Connect(wireEventButton)
end

-- Run: send the name in the box to the server.
if runButton then
	runButton.MouseButton1Click:Connect(function()
		local name = textBox.Text
		if name == "" then return end
		startEventRemote:FireServer(name)
	end)
end

-- Stop: send the name in the box, or "stop" if blank (server treats as stop-all).
if stopButton then
	stopButton.MouseButton1Click:Connect(function()
		local name = textBox.Text
		if name == "" then name = "stop" end
		stopEventRemote:FireServer(name)
	end)
end
