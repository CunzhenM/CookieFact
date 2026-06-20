--!strict
-- Sweeps all UI and adds polish WITHOUT rewriting existing logic: hover/press FX + SFX on every
-- button, pop+fade on dialogs, and wires the partner's dead nav + close buttons. Buttons that
-- already carry their own handler (e.g. Index) are left alone.

local Players = game:GetService("Players")
local UIEffects = require(script.Parent:WaitForChild("UIEffects"))

local PolishController = {}

local NAV_ALIAS = { Trade = "TradeMainFrame" }
local CLOSE_NAMES = { cancel = true, close = true, exit = true, back = true, quit = true, x = true, closebutton = true }

local function hasOwnHandler(btn)
	return btn:FindFirstChildWhichIsA("LuaSourceContainer") ~= nil
end

function PolishController.Start()
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")

	UIEffects.sweepButtons(pg)
	pg.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then task.defer(UIEffects.button, d) end
	end)

	local frames = pg:FindFirstChild("Frames")

	local function setupDialog(dialog)
		if not dialog:IsA("GuiObject") then return end
		UIEffects.bindFrame(dialog)
		for _, b in ipairs(dialog:GetDescendants()) do
			if b:IsA("GuiButton") and not b:GetAttribute("NavWired") and not hasOwnHandler(b) and CLOSE_NAMES[b.Name:lower()] then
				b:SetAttribute("NavWired", true)
				b.Activated:Connect(function() UIEffects.closeFrame(dialog) end)
			end
		end
	end
	if frames then
		for _, d in ipairs(frames:GetChildren()) do setupDialog(d) end
		frames.ChildAdded:Connect(function(d) task.defer(setupDialog, d) end)
	end

	local hud = pg:FindFirstChild("HUD")
	local leftPanel = hud and hud:FindFirstChild("LeftPanel")
	if leftPanel and frames then
		for _, btn in ipairs(leftPanel:GetChildren()) do
			if btn:IsA("GuiButton") and not btn:GetAttribute("NavWired") and not hasOwnHandler(btn) then
				local target = frames:FindFirstChild(NAV_ALIAS[btn.Name] or btn.Name)
				if target and target:IsA("GuiObject") then
					btn:SetAttribute("NavWired", true)
					btn.Activated:Connect(function()
						if target.Visible then UIEffects.closeFrame(target) else target.Visible = true end
					end)
				end
			end
		end
	end

	local function bindMine(screenName)
		local sg = pg:FindFirstChild(screenName)
		if not sg then return end
		for _, c in ipairs(sg:GetChildren()) do
			if c:IsA("Frame") and c.Size ~= UDim2.fromScale(1, 1) then UIEffects.bindFrame(c) end
		end
	end
	bindMine("MachineShop")
	bindMine("PlacementHud")
end

return PolishController
