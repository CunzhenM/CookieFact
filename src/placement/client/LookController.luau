--!strict
-- Client half of "look toward camera": feed the local camera CFrame to the server (throttled)
-- while the camera is on the local character. The server applies neck/waist C0 so it replicates.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))

local LookController = {}
local SEND_INTERVAL = 1 / 20

function LookController.Start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	local remote = remotes:WaitForChild(PlacementConfig.Remotes.LookCamera)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < SEND_INTERVAL then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		local char = player.Character
		if not cam or not char then
			return
		end
		local subject = cam.CameraSubject
		if subject and subject:IsDescendantOf(char) then
			remote:FireServer(cam.CFrame)
		end
	end)
end

return LookController
