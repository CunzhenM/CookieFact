local textBox = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local setRebirthRemote = ReplicatedStorage:FindFirstChild("SetRebirthRemote")
if not setRebirthRemote then
	setRebirthRemote = Instance.new("RemoteEvent")
	setRebirthRemote.Name = "SetRebirthRemote"
	setRebirthRemote.Parent = ReplicatedStorage
end

local addRebirthRemote = ReplicatedStorage:FindFirstChild("AddRebirthRemote")
if not addRebirthRemote then
	addRebirthRemote = Instance.new("RemoteEvent")
	addRebirthRemote.Name = "AddRebirthRemote"
	addRebirthRemote.Parent = ReplicatedStorage
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
			setRebirthRemote:FireServer(amount)
		else
			warn("bestie you gotta enter a real number, " .. textBox.Text .. " is not the vibe")
		end
	end)
else
	warn("set button is literally missing, i'm tweaking")
end

if addButton then
	addButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			addRebirthRemote:FireServer(amount)
		else
			warn("ohhhh noooo put a number in the box or it's over for you")
		end
	end)
else
	warn("add button gone... rip to the rebirths")
end