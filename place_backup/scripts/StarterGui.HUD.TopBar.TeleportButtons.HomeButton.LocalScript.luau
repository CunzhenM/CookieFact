
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")


local player = Players.LocalPlayer
local button = script.Parent

local PlayerGui = player:WaitForChild("PlayerGui")
local Frames = PlayerGui:WaitForChild("Frames")
local frame = Frames:WaitForChild("AdminPanel")

local speed = 0.2
local tweenInfo = TweenInfo.new(speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local blurTweenInfo = TweenInfo.new(speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local fullSize = frame.Size
local shrunkSize = UDim2.new(0, 0, 0, 0)
local targetBlurSize = 24

-- List of authorized player UserIds
local AUTHORIZED_PLAYERS = {
	7417559307,
}

local CHAT_COMMAND = "!admin"

local function isAuthorized()
	for _, userId in ipairs(AUTHORIZED_PLAYERS) do
		if player.UserId == userId then
			return true
		end
	end
	return false
end

-- Hidden by default; "!admin" reveals it for authorized players only
button.Visible = false

local function tweenBlurs(targetSize)
	for _, effect in pairs(Lighting:GetChildren()) do
		if effect.Name == "Blur" and effect:IsA("BlurEffect") then
			effect.Enabled = true
			TweenService:Create(effect, blurTweenInfo, {Size = targetSize}):Play()
		end
	end
end

frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Size = shrunkSize
frame.Visible = false

local function toggleMenu()
	if not isAuthorized() then
		Popup.Error("You're Not Authorized To Have Admin Commands")
		return
	end

	if not frame.Visible then
		frame.Visible = true
		tweenBlurs(targetBlurSize)
		TweenService:Create(frame, tweenInfo, {Size = fullSize}):Play()
	else
		tweenBlurs(0)
		local closeTween = TweenService:Create(frame, tweenInfo, {Size = shrunkSize})
		closeTween.Completed:Connect(function()
			if frame.Size == shrunkSize then
				frame.Visible = false
			end
		end)
		closeTween:Play()
	end
end

button.Activated:Connect(toggleMenu)

-- "E" hotkey: same toggle as the button click. Authorization check is inside
-- toggleMenu, so non-admins pressing E get the same silent ignore as a click
-- (well, the popup) and the input is ignored if the player is typing.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E and isAuthorized() then
		toggleMenu()
	end
end)

local function handleChatCommand(message)
	if typeof(message) ~= "string" then return end
	local trimmed = message:lower():match("^%s*(.-)%s*$") or ""
	if trimmed ~= CHAT_COMMAND then return end
	if not isAuthorized() then return end
	button.Visible = not button.Visible
end

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	TextChatService.MessageReceived:Connect(function(textChatMessage)
		local source = textChatMessage.TextSource
		if source and source.UserId == player.UserId then
			handleChatCommand(textChatMessage.Text)
		end
	end)
else
	player.Chatted:Connect(handleChatCommand)
end
