--!strict
-- Server half of "look toward camera": clients feed their camera CFrame; this applies the
-- neck/waist C0 lean each Heartbeat so it REPLICATES to everyone (client-set C0 does not).
-- Math/intensities are the user's; rest C0 captured per character; stale feeds relax to rest.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("PlacementShared")
local PlacementConfig = require(Shared:WaitForChild("PlacementConfig"))

local LookService = {}

local NECK_TURN = 0.5
local WAIST_TURN = 0.3
local STALE_AFTER = 0.4
local LERP = 0.15

local cams = {}
local rigs = {}

local function buildRig(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	if not (char and hum and head) then
		return nil
	end
	local isR6 = hum.RigType == Enum.HumanoidRigType.R6
	local torso = isR6 and char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	if not torso then
		return nil
	end
	local neck = isR6 and torso:FindFirstChild("Neck") or head:FindFirstChild("Neck")
	if not (neck and neck:IsA("Motor6D")) then
		return nil
	end
	local waistInst = (not isR6) and torso:FindFirstChild("Waist") or nil
	local waist = (waistInst and waistInst:IsA("Motor6D")) and waistInst or nil
	return {
		char = char, hum = hum, head = head, torso = torso, neck = neck, waist = waist, isR6 = isR6,
		baseNeck = neck.C0, baseWaist = waist and waist.C0,
	}
end

local function getRig(player)
	local rig = rigs[player]
	if not rig or rig.char ~= player.Character or rig.neck.Parent == nil then
		rig = buildRig(player)
		rigs[player] = rig
	end
	return rig
end

function LookService.Start()
	local folder = ReplicatedStorage:WaitForChild(PlacementConfig.RemotesFolderName)
	local remote = folder:FindFirstChild(PlacementConfig.Remotes.LookCamera)
	if not remote then
		remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = PlacementConfig.Remotes.LookCamera
		remote.Parent = folder
	end

	remote.OnServerEvent:Connect(function(player, cf)
		if typeof(cf) == "CFrame" then
			cams[player] = { cf = cf, t = os.clock() }
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		cams[player] = nil
		rigs[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, data in pairs(cams) do
			local rig = getRig(player)
			if rig then
				if (now - data.t) < STALE_AFTER then
					local headCF = rig.head.CFrame
					local camPos = data.cf.Position
					local dist = (headCF.Position - camPos).Magnitude
					if dist > 0 then
						local pitch = math.asin(math.clamp((headCF.Y - camPos.Y) / dist, -1, 1))
						local cross = (headCF.Position - camPos).Unit:Cross(rig.torso.CFrame.LookVector).Y
						if rig.isR6 then
							rig.neck.C0 = rig.neck.C0:Lerp(rig.baseNeck * CFrame.Angles(-(pitch * 0.4), 0, -cross * NECK_TURN), LERP)
						else
							rig.neck.C0 = rig.neck.C0:Lerp(rig.baseNeck * CFrame.Angles(pitch * 0.4, -cross * NECK_TURN, 0), LERP)
							if rig.waist and rig.baseWaist then
								rig.waist.C0 = rig.waist.C0:Lerp(rig.baseWaist * CFrame.Angles(pitch * 0.2, -cross * WAIST_TURN, 0), LERP)
							end
						end
					end
					rig.hum.AutoRotate = true
				else
					rig.neck.C0 = rig.neck.C0:Lerp(rig.baseNeck, LERP)
					if rig.waist and rig.baseWaist then
						rig.waist.C0 = rig.waist.C0:Lerp(rig.baseWaist, LERP)
					end
				end
			end
		end
	end)
end

return LookService
