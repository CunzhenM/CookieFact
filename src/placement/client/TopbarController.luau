--!strict
-- Wires the new Topbar (StarterGui.Topbar) icons to our systems:
--   BuildIcon   -> toggle build mode (PlacementHud catalog)
--   ShopIcon    -> toggle the Machine Shop (ShopController)
--   SettingIcon -> toggle the Settings frame
--   InventoryIcon -> toggle the Inventory/Index frame
-- Each icon's clickable is a `ClickRegion` TextButton; we connect those + add UIEffects click/hover
-- SFX, and give toggled frames our pop/fade. Additive + guarded so respawns don't double-wire.

local Players = game:GetService("Players")

local PlacementHud = require(script.Parent:WaitForChild("PlacementHud"))
local ShopController = require(script.Parent:WaitForChild("ShopController"))
local UIEffects = require(script.Parent:WaitForChild("UIEffects"))

local TopbarController = {}
local player = Players.LocalPlayer

local function clickRegionOf(icon)
	local cr = icon:FindFirstChild("ClickRegion", true)
	return (cr and cr:IsA("GuiButton")) and cr or nil
end

local function makeFrameToggle(getFrame)
	return function()
		local frame = getFrame()
		if not frame then
			return
		end
		UIEffects.bindFrame(frame)
		if frame.Visible then
			UIEffects.closeFrame(frame)
		else
			frame.Visible = true
		end
	end
end

local function wire(icon, action)
	if not icon then
		return
	end
	local btn = clickRegionOf(icon)
	if not btn or btn:GetAttribute("CFTopbarWired") then
		return
	end
	btn:SetAttribute("CFTopbarWired", true)
	UIEffects.button(btn)
	btn.Activated:Connect(action)
end

local function wireAll()
	local gui = player:WaitForChild("PlayerGui")
	local topbar = gui:WaitForChild("Topbar", 20)
	local holders = topbar and topbar:WaitForChild("Holders", 10)
	local left = holders and holders:WaitForChild("Left", 10)
	if not left then
		return
	end

	local function settingsFrame()
		local s = gui:FindFirstChild("Settings")
		local f = s and s:FindFirstChild("Frame")
		return (f and f:IsA("GuiObject")) and f or nil
	end
	local function inventoryFrame()
		local frames = gui:FindFirstChild("Frames")
		local inner = frames and frames:FindFirstChild("Frames")
		local idx = (inner and inner:FindFirstChild("Index")) or (frames and frames:FindFirstChild("Index"))
		return (idx and idx:IsA("GuiObject")) and idx or nil
	end

	wire(left:FindFirstChild("BuildIcon"), function()
		PlacementHud.toggle()
	end)
	wire(left:FindFirstChild("ShopIcon"), function()
		ShopController.toggle()
	end)
	wire(left:FindFirstChild("SettingIcon"), makeFrameToggle(settingsFrame))
	wire(left:FindFirstChild("InventoryIcon"), makeFrameToggle(inventoryFrame))
end

function TopbarController.Start()
	task.spawn(wireAll)
	player.CharacterAdded:Connect(function()
		task.defer(wireAll)
	end)
end

return TopbarController
