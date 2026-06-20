local replicated_storage = game:GetService("ReplicatedStorage")

local remotes = replicated_storage.Remotes
local send_remote = remotes.SendGlobalAnnouncement

local gui = script.Parent
local open_button = gui.OpenButton
local container = gui.Container
container.Visible = false
local close_button = container.CloseButton
local send_button = container.SendButton
local message_box = container.MessageBox
local duration_box = container.DurationBox

open_button.MouseButton1Click:Connect(function()
	container.Visible = not container.Visible
end)
close_button.MouseButton1Click:Connect(function()
	container.Visible = false
end)

send_button.MouseButton1Click:Connect(function()
	send_remote:FireServer(
		message_box.Text,
		duration_box.Text
	)
end)