local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local button = script.Parent
print("[IndexButtonHandler] init for button", button:GetFullName())

local function getIndexFrame()
	local frames = PlayerGui:FindFirstChild("Frames")
	if not frames then return nil end
	return frames:FindFirstChild("Index")
end

local function toggle()
	local indexFrame = getIndexFrame()
	if not indexFrame then
		warn("[IndexButtonHandler] Frames.Index not found in PlayerGui")
		return
	end
	indexFrame.Visible = not indexFrame.Visible
	print("[IndexButtonHandler] toggled -> Visible=" .. tostring(indexFrame.Visible))
end

button.Activated:Connect(function()
	print("[IndexButtonHandler] Activated fired")
	toggle()
end)

button.MouseButton1Click:Connect(function()
	print("[IndexButtonHandler] MouseButton1Click fired")
	toggle()
end)
