--!strict
-- Cookie Factory :: Placement + Machine-shop tuning. ADDITIVE; never touches partner code.

local PlacementConfig = {}

PlacementConfig.CellSize = 3

PlacementConfig.GridAreaName = "GridPlacementArea"
PlacementConfig.PlacedFolderName = "PlacedMachines"
PlacementConfig.FactoryFolderName = "CookieFactory"

PlacementConfig.DefaultAreaPosition = Vector3.new(520, 3, 60)
PlacementConfig.DefaultAreaSize = Vector3.new(48, 1, 48)

PlacementConfig.FactoryLineStart = Vector3.new(410, 0, 180)
PlacementConfig.FactoryLineSpacing = 30

PlacementConfig.OutlineColor = Color3.new(1, 1, 1)
PlacementConfig.GhostColorValid = Color3.fromRGB(120, 255, 150)
PlacementConfig.GhostColorInvalid = Color3.fromRGB(255, 85, 85)
PlacementConfig.GhostTransparency = 0.45
PlacementConfig.GhostSmoothing = 16
PlacementConfig.DeleteHighlightColor = Color3.fromRGB(255, 70, 70)
PlacementConfig.MarkerTransparency = 0.6

PlacementConfig.BuildTweenTime = 0.45
PlacementConfig.BuildStagger = 0.03

PlacementConfig.ChargeForPlacement = true
PlacementConfig.RefundFraction = 0.5
PlacementConfig.TycoonLinearUnlock = true

PlacementConfig.ConfirmFrameName = "ProductConfirmFrame"
PlacementConfig.ConfirmFramesScreen = "Frames"

PlacementConfig.RemotesFolderName = "PlacementRemotes"
PlacementConfig.Remotes = {
	Place = "RequestPlace",
	Delete = "RequestDelete",
	Buy = "RequestBuyMachine",
	Result = "PlacementResult",

	LookCamera = "LookCamera",
	OpenShop = "OpenMachineShop",
	ShopError = "MachineShopError",}

PlacementConfig.FactoryLine = {
	{ id = "Receiving", label = "Receiving & Storage", step = 1, cost = 0, color = Color3.fromRGB(180, 185, 195), size = Vector3.new(10, 12, 10) },
	{ id = "Mixing", label = "Mixing", step = 3, cost = 100, color = Color3.fromRGB(120, 170, 255), size = Vector3.new(8, 8, 8) },
	{ id = "Depositing", label = "Depositing", step = 6, cost = 250, color = Color3.fromRGB(222, 184, 135), size = Vector3.new(8, 6, 8) },
	{ id = "Baking", label = "Baking (Oven)", step = 7, cost = 500, color = Color3.fromRGB(205, 80, 60), size = Vector3.new(20, 6, 8) },
	{ id = "Cooling", label = "Cooling", step = 8, cost = 900, color = Color3.fromRGB(150, 210, 235), size = Vector3.new(10, 12, 10) },
	{ id = "Coating", label = "Filling / Coating", step = 9, cost = 1500, color = Color3.fromRGB(170, 120, 220), size = Vector3.new(8, 6, 8) },
	{ id = "Cartoning", label = "Cartoning", step = 11, cost = 2500, color = Color3.fromRGB(150, 120, 90), size = Vector3.new(10, 6, 8) },
	{ id = "Distribution", label = "Distribution", step = 12, cost = 4000, color = Color3.fromRGB(95, 200, 120), size = Vector3.new(16, 8, 12) },
}

PlacementConfig.Machines = {
	{ id = "DoughDropper", label = "Dough Dropper", cost = 0, color = Color3.fromRGB(222, 184, 135), footprint = { 1, 1 }, height = 5 },
	{ id = "Mixer", label = "Mixer", cost = 50, color = Color3.fromRGB(120, 170, 255), footprint = { 1, 1 }, height = 5 },
	{ id = "Conveyor", label = "Conveyor", cost = 25, color = Color3.fromRGB(85, 85, 90), footprint = { 1, 1 }, height = 3 },
	{ id = "LeftConveyor", label = "Left Conveyor", cost = 25, color = Color3.fromRGB(85, 85, 90), footprint = { 1, 1 }, height = 2.8 },
	{ id = "RightConveyor", label = "Right Conveyor", cost = 25, color = Color3.fromRGB(85, 85, 90), footprint = { 1, 1 }, height = 2.8 },
	{ id = "Oven", label = "Oven", cost = 120, color = Color3.fromRGB(205, 80, 60), footprint = { 2, 1 }, height = 6 },
	{ id = "Packer", label = "Packer", cost = 200, color = Color3.fromRGB(170, 120, 220), footprint = { 1, 1 }, height = 5 },
	{ id = "Seller", label = "Seller", cost = 300, color = Color3.fromRGB(95, 200, 120), footprint = { 2, 2 }, height = 4 },
}

function PlacementConfig.getMachine(id)
	for _, m in ipairs(PlacementConfig.Machines) do
		if m.id == id then
			return m
		end
	end
	return nil
end

return PlacementConfig
