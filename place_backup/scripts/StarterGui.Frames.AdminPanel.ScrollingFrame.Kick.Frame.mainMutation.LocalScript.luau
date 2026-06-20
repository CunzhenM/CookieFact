local textBox = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local setKickRemote = ReplicatedStorage:FindFirstChild("SetKickRemote")
if not setKickRemote then
	setKickRemote = Instance.new("RemoteEvent")
	setKickRemote.Name = "SetKickRemote"
	setKickRemote.Parent = ReplicatedStorage
end

local addKickRemote = ReplicatedStorage:FindFirstChild("AddKickRemote")
if not addKickRemote then
	addKickRemote = Instance.new("RemoteEvent")
	addKickRemote.Name = "AddKickRemote"
	addKickRemote.Parent = ReplicatedStorage
end

local container = script.Parent.Parent

local setButton = container:FindFirstChild("Set")
local addButton = container:FindFirstChild("Add")

if setButton then
	setButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			setKickRemote:FireServer(amount)
		else
			warn("Kick Set: '" .. textBox.Text .. "' is not a number.")
		end
	end)
else
	warn("Kick Set button missing.")
end

if addButton then
	addButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			addKickRemote:FireServer(amount)
		else
			warn("Kick Add: '" .. textBox.Text .. "' is not a number.")
		end
	end)
else
	warn("Kick Add button missing.")
end
