--!strict
-- Hold Shift to sprint: a WalkSpeed boost plus a slight FOV bump for a sense of speed.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SprintController = {}

local player = Players.LocalPlayer

local SPRINT_BONUS = 10 -- studs/s added to the character's base WalkSpeed
local FOV_BUMP = 8 -- degrees added to the base field of view
local FOV_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local baseWalkSpeed = 16
local baseFOV = 70
local sprinting = false

local function getHumanoid(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function applySprint(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on

	local humanoid = getHumanoid()
	if humanoid then
		humanoid.WalkSpeed = if on then baseWalkSpeed + SPRINT_BONUS else baseWalkSpeed
	end

	local camera = Workspace.CurrentCamera
	if camera then
		local goalFOV = if on then baseFOV + FOV_BUMP else baseFOV
		TweenService:Create(camera, FOV_TWEEN, { FieldOfView = goalFOV }):Play()
	end
end

local function onCharacterAdded(char: Model)
	sprinting = false
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	baseWalkSpeed = humanoid.WalkSpeed
end

function SprintController.Start()
	local camera = Workspace.CurrentCamera
	if camera then
		baseFOV = camera.FieldOfView
	end
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Note: we deliberately don't gate on `gameProcessed` here -- with Shift Lock the
	-- core scripts mark Shift as processed, which would swallow the sprint. We only
	-- skip while the player is typing in a text box.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			applySprint(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			applySprint(false)
		end
	end)
end

return SprintController
