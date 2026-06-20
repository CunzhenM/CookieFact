local tween_service = game:GetService("TweenService")
local replicated_storage = game:GetService("ReplicatedStorage")

local remotes = replicated_storage.Remotes
local display_remote = remotes.DisplayGlobalAnnouncement

local templates = replicated_storage.Templates
local message_template = templates.Message.Message

local gui = script.Parent
local container = gui.Container

local appear_tween_info = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.Out
)
local disappear_tween_info = TweenInfo.new(
	0.5,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.Out
)

function message_appear(message_frame)
	message_frame.Background.BackgroundTransparency = 1
	message_frame.Background.TextLabel.TextTransparency = 1
	message_frame.Background.TextLabel.UIStroke.Transparency = 1
	
	tween_service:Create(
		message_frame.Background, 
		appear_tween_info, 
		{BackgroundTransparency = 0}
	):Play()
	tween_service:Create(
		message_frame.Background.TextLabel, 
		appear_tween_info, 
		{TextTransparency = 0}
	):Play()
	tween_service:Create(
		message_frame.Background.TextLabel.UIStroke, 
		appear_tween_info, 
		{Transparency = 0}
	):Play()
	
	script.Sound:Play()
end

function message_disappear(message_frame)
	tween_service:Create(
		message_frame.Background, 
		appear_tween_info, 
		{
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0)
		}
	):Play()
	tween_service:Create(
		message_frame.Background.TextLabel, 
		appear_tween_info, 
		{TextTransparency = 1}
	):Play()
	local tween = tween_service:Create(
		message_frame.Background.TextLabel.UIStroke, 
		appear_tween_info, 
		{Transparency = 1}
	)
	tween:Play()
	tween.Completed:Wait()
	message_frame:Destroy()
end

function display_message(message, duration)
	
	local message_frame = message_template:Clone()
	message_frame.Background.TextLabel.Text = message
	
	message_appear(message_frame)
	
	message_frame.Parent = container
	
	task.wait(duration)
	message_disappear(message_frame)
end

display_remote.OnClientEvent:Connect(display_message)