--!strict
-- Reusable UI juice: hover/press FX + SFX on buttons, pop+slight-fade open/close on frames.
-- Additive + idempotent (attribute-guarded) so it can sweep the partner's UI safely.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local UIEffects = {}

local HOVER_SCALE = 1.06
local PRESS_SCALE = 0.92
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_INFO = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FRAME_IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FRAME_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FRAME_FROM = 0.86

local HOVER_ID = "rbxassetid://6972108033"
local CLICK_ID = "rbxassetid://6042053626"

local hoverSfx, clickSfx
local function ensureSounds()
	if hoverSfx then return end
	local folder = SoundService:FindFirstChild("PlacementSFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlacementSFX"
		folder.Parent = SoundService
	end
	hoverSfx = Instance.new("Sound")
	hoverSfx.Name = "Hover"; hoverSfx.SoundId = HOVER_ID; hoverSfx.Volume = 0.25; hoverSfx.PlaybackSpeed = 1; hoverSfx.Parent = folder
	clickSfx = Instance.new("Sound")
	clickSfx.Name = "Click"; clickSfx.SoundId = CLICK_ID; clickSfx.Volume = 0.4; clickSfx.PlaybackSpeed = 1; clickSfx.Parent = folder
end

local function ensureScale(gui)
	local s = gui:FindFirstChildWhichIsA("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = gui
	end
	return s
end

function UIEffects.button(btn)
	if btn:GetAttribute("UIFX") then return end
	btn:SetAttribute("UIFX", true)
	ensureSounds()
	local scale = ensureScale(btn)
	local base = scale.Scale
	if base <= 0 then base = 1; scale.Scale = 1 end
	local function to(mult, info)
		TweenService:Create(scale, info, { Scale = base * mult }):Play()
	end
	btn.MouseEnter:Connect(function()
		to(HOVER_SCALE, HOVER_INFO)
		if hoverSfx then hoverSfx:Play() end
	end)
	btn.MouseLeave:Connect(function() to(1, HOVER_INFO) end)
	btn.MouseButton1Down:Connect(function() to(PRESS_SCALE, PRESS_INFO) end)
	btn.MouseButton1Up:Connect(function() to(HOVER_SCALE, PRESS_INFO) end)
	btn.Activated:Connect(function()
		if clickSfx then clickSfx:Play() end
	end)
end

function UIEffects.bindFrame(frame)
	if frame:GetAttribute("UIFXFrame") then return end
	frame:SetAttribute("UIFXFrame", true)
	local scale = ensureScale(frame)
	local base = scale.Scale > 0 and scale.Scale or 1
	scale.Scale = base
	frame:SetAttribute("UIFXBaseScale", base)
	frame:SetAttribute("UIFXBaseBg", frame.BackgroundTransparency)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then return end
		local baseBg = frame:GetAttribute("UIFXBaseBg")
		scale.Scale = base * FRAME_FROM
		frame.BackgroundTransparency = math.min(1, baseBg + 0.25)
		TweenService:Create(scale, FRAME_IN, { Scale = base }):Play()
		TweenService:Create(frame, FRAME_IN, { BackgroundTransparency = baseBg }):Play()
	end)
end

function UIEffects.closeFrame(frame)
	if not frame.Visible then return end
	local scale = ensureScale(frame)
	local base = frame:GetAttribute("UIFXBaseScale") or (scale.Scale > 0 and scale.Scale or 1)
	local baseBg = frame:GetAttribute("UIFXBaseBg") or frame.BackgroundTransparency
	local t = TweenService:Create(scale, FRAME_OUT, { Scale = base * FRAME_FROM })
	TweenService:Create(frame, FRAME_OUT, { BackgroundTransparency = math.min(1, baseBg + 0.25) }):Play()
	t.Completed:Once(function()
		frame.Visible = false
		scale.Scale = base
		frame.BackgroundTransparency = baseBg
	end)
	t:Play()
end

function UIEffects.sweepButtons(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") then UIEffects.button(d) end
	end
end

return UIEffects
