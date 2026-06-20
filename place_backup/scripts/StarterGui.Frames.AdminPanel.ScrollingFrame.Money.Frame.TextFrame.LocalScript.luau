local textBox = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local addRemote = ReplicatedStorage:FindFirstChild("AddMoneyRemote")
if not addRemote then
	addRemote = Instance.new("RemoteEvent")
	addRemote.Name = "AddMoneyRemote"
	addRemote.Parent = ReplicatedStorage
end

local setRemote = ReplicatedStorage:FindFirstChild("SetMoneyRemote")
if not setRemote then
	setRemote = Instance.new("RemoteEvent")
	setRemote.Name = "SetMoneyRemote"
	setRemote.Parent = ReplicatedStorage
end

local container = script.Parent.Parent
local addButton = container:FindFirstChild("Add")
local setButton = container:FindFirstChild("Set")

if addButton then
	addButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			addRemote:FireServer(amount)
		end
	end)
end

if setButton then
	setButton.MouseButton1Click:Connect(function()
		local amount = tonumber(textBox.Text)
		if amount then
			setRemote:FireServer(amount)
		end
	end)
end