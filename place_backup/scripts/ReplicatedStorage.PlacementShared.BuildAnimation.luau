--!strict
-- Build-in pop animation (the user's technique), reusable + supporting pre-captured
-- originals so tycoon parts can be hidden then revealed.

local TweenService = game:GetService("TweenService")
local PlacementConfig = require(script.Parent:WaitForChild("PlacementConfig"))
local BuildAnimation = {}

export type Props = { CFrame: CFrame, Transparency: number, Size: Vector3 }

local DEFAULT_INFO = TweenInfo.new(PlacementConfig.BuildTweenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function collectParts(item)
	local parts = {}
	if item:IsA("BasePart") then
		table.insert(parts, item)
	end
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

function BuildAnimation.capture(item)
	local original = {}
	for _, part in ipairs(collectParts(item)) do
		original[part] = { CFrame = part.CFrame, Transparency = part.Transparency, Size = part.Size }
	end
	return original
end

function BuildAnimation.hide(item)
	for _, part in ipairs(collectParts(item)) do
		part.Transparency = 1
		part.Size = Vector3.zero
		part.CanCollide = false
	end
end

function BuildAnimation.play(item, originals, tweenInfo, stagger)
	local info = tweenInfo or DEFAULT_INFO
	local gap = stagger or PlacementConfig.BuildStagger
	local parts = collectParts(item)
	local goals = originals or BuildAnimation.capture(item)
	local rng = Random.new()

	for _, part in ipairs(parts) do
		local goal = goals[part]
		if goal then
			part.Transparency = 1
			part.Size = Vector3.zero
			local positionOffset = Vector3.new(rng:NextNumber(0, 0), rng:NextNumber(-0, 0), rng:NextNumber(0, 0)) * 2
			local rotationOffset = CFrame.Angles(
				rng:NextNumber(-math.pi, math.pi),
				rng:NextNumber(-math.pi, math.pi),
				rng:NextNumber(-math.pi, math.pi)
			)
			part.CFrame = goal.CFrame * CFrame.new(positionOffset) * rotationOffset
		end
	end

	task.spawn(function()
		for _, part in ipairs(parts) do
			local goal = goals[part]
			if goal then
				local tween = TweenService:Create(part, info, {
					CFrame = goal.CFrame,
					Transparency = goal.Transparency,
					Size = goal.Size,
				})
				tween.Completed:Connect(function()
					if part.Parent then
						part.Transparency = goal.Transparency
						part.CFrame = goal.CFrame
						part.Size = goal.Size
					end
				end)
				tween:Play()
				if gap > 0 then
					task.wait(gap)
				end
			end
		end
	end)
end

return BuildAnimation
