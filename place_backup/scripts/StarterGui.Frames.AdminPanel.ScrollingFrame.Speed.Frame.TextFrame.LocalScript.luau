local textBox = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local setSpeedRemote = ReplicatedStorage:FindFirstChild("SetSpeedRemote")
if not setSpeedRemote then
	setSpeedRemote = Instance.new("RemoteEvent")
	setSpeedRemote.Name = "SetSpeedRemote"
	setSpeedRemote.Parent = ReplicatedStorage
end

local addSpeedRemote = ReplicatedStorage:FindFirstChild("AddSpeedRemote")
if not addSpeedRemote then
	addSpeedRemote = Instance.new("RemoteEvent")
	addSpeedRemote.Name = "AddSpeedRemote"
	addSpeedRemote.Parent = ReplicatedStorage
end

local container = script.Parent.Parent

local setButton = container:FindFirstChild("Set")
local addButton = container:FindFirstChild("Add")

textBox:GetPropertyChangedSignal("Text"):Connect(function()
end)

if setButton then
	setButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			setSpeedRemote:FireServer(amount)
		else
			warn("bro, " .. textBox.Text .. " is not a number. fix your life")
		end
	end)
else
	warn("the set button is literally missing, i'm tweaking fr")
end

if addButton then
	addButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			addSpeedRemote:FireServer(amount)
		else
			warn("how am i supposed to add " .. textBox.Text .. "? use a real number lol")
		end
	end)
else
	warn("add button is gone, ts is cooked")
end