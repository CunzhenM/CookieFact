--!strict
-- Dough Dropper machine (server) -- standalone & partner-proof. Turns each placed DoughDropper into a
-- crafting machine: an ingredient stock (large, for testing), a selected recipe, and an auto-make flag,
-- all kept as attributes on the model so the client UI reads them live. This validates + produces
-- (drops dough from the spout), deducting ingredients; auto-make respects a cooldown.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local DropperConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DropperConfig"))

local folder = ReplicatedStorage:FindFirstChild(DropperConfig.RemotesFolder)
if not folder then
	folder = Instance.new("Folder")
	folder.Name = DropperConfig.RemotesFolder
	folder.Parent = ReplicatedStorage
end
local function ensure(name: string): RemoteEvent
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r :: RemoteEvent
end
local makeR = ensure(DropperConfig.Remotes.Make)
local autoR = ensure(DropperConfig.Remotes.SetAuto)

local function makeDough(): Instance
	local tmpl = Workspace:FindFirstChild("CookieDough")
	local d: Instance
	if tmpl and (tmpl:IsA("Model") or tmpl:IsA("BasePart")) then
		d = tmpl:Clone()
	else
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.8, 1.3, 1.8)
		p.Color = Color3.fromRGB(222, 184, 135)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = true
		d = p
	end
	d.Name = "CookieDough"
	CollectionService:AddTag(d, "Dough")
	CollectionService:AddTag(d, "Draggable")
	return d
end

local function inv(model: Instance, id: string): number
	return (model:GetAttribute("Ing_" .. id) :: number?) or 0
end

local function met(model: Instance, recipe): boolean
	for id, amt in pairs(recipe.requires) do
		if inv(model, id) < amt then
			return false
		end
	end
	return true
end

local function produce(model: Instance): boolean
	local recipe = DropperConfig.getRecipe(model:GetAttribute("Recipe") :: string?)
	if not recipe or not met(model, recipe) then
		return false
	end
	local spout = model:FindFirstChild("Spout", true)
	if not (spout and spout:IsA("BasePart")) then
		return false
	end
	for id, amt in pairs(recipe.requires) do
		model:SetAttribute("Ing_" .. id, inv(model, id) - amt)
	end
	local dropped = Workspace:FindFirstChild("DroppedDough")
	if not dropped then
		dropped = Instance.new("Folder")
		dropped.Name = "DroppedDough"
		dropped.Parent = Workspace
	end
	local dough = makeDough()
	dough:SetAttribute("OwnerUserId", model:GetAttribute("OwnerUserId"))
	dough:SetAttribute("Recipe", recipe.id)
	local dropCF = (spout :: BasePart).CFrame * CFrame.new(1.2, 0, 0)
	if dough:IsA("Model") then
		dough:PivotTo(dropCF)
	elseif dough:IsA("BasePart") then
		dough.CFrame = dropCF
		dough.AssemblyLinearVelocity = (spout :: BasePart).CFrame.RightVector * 4 + Vector3.new(0, 4, 0)
	end
	dough.Parent = dropped
	model:SetAttribute("LastProducedAt", Workspace:GetServerTimeNow())
	return true
end

-- Strip the partner's "click to drop" hint + ClickDetector (the dropper is now click-to-open-UI),
-- then stock the machine and set default state.
local function setup(model: Instance)
	if model:GetAttribute("CFDropperReady") then
		return
	end
	model:SetAttribute("CFDropperReady", true)
	local spout = model:FindFirstChild("Spout", true)
	for _ = 1, 20 do
		if spout then
			break
		end
		task.wait(0.1)
		spout = model:FindFirstChild("Spout", true)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ClickDetector") then
			d:Destroy()
		elseif d:IsA("BillboardGui") then
			local onSpout = spout ~= nil and d:IsDescendantOf(spout)
			local txt = d:FindFirstChildWhichIsA("TextLabel", true)
			local hinty = txt ~= nil
				and (string.find(string.lower(txt.Text), "drop") ~= nil or string.find(string.lower(txt.Text), "click") ~= nil)
			if onSpout or hinty then
				d:Destroy()
			end
		end
	end
	for _, ing in ipairs(DropperConfig.Ingredients) do
		if model:GetAttribute("Ing_" .. ing.id) == nil then
			model:SetAttribute("Ing_" .. ing.id, DropperConfig.StartingAmount)
		end
	end
	if model:GetAttribute("Recipe") == nil then
		model:SetAttribute("Recipe", DropperConfig.Recipes[1].id)
	end
	if model:GetAttribute("AutoMake") == nil then
		model:SetAttribute("AutoMake", false)
	end
	if model:GetAttribute("LastProducedAt") == nil then
		model:SetAttribute("LastProducedAt", 0)
	end
end

local function isDropper(inst: Instance): boolean
	return inst:IsA("Model") and inst:GetAttribute("MachineId") == "DoughDropper"
end
local function owns(player: Player, model: Instance): boolean
	return model:GetAttribute("OwnerUserId") == player.UserId
end

for _, plot in ipairs(Workspace:GetChildren()) do
	if plot.Name:match("^Plot%d+$") then
		local placed = plot:FindFirstChild("PlacedMachines")
		if placed then
			for _, m in ipairs(placed:GetChildren()) do
				if isDropper(m) then
					task.spawn(setup, m)
				end
			end
		end
	end
end
Workspace.DescendantAdded:Connect(function(inst)
	if isDropper(inst) then
		task.spawn(setup, inst)
	end
end)

makeR.OnServerEvent:Connect(function(player, model, recipeId)
	if not (typeof(model) == "Instance" and isDropper(model) and owns(player, model)) then
		return
	end
	if typeof(recipeId) == "string" and DropperConfig.getRecipe(recipeId) then
		model:SetAttribute("Recipe", recipeId)
	end
	produce(model)
end)
autoR.OnServerEvent:Connect(function(player, model, recipeId, enabled)
	if not (typeof(model) == "Instance" and isDropper(model) and owns(player, model)) then
		return
	end
	if typeof(recipeId) == "string" and DropperConfig.getRecipe(recipeId) then
		model:SetAttribute("Recipe", recipeId)
	end
	model:SetAttribute("AutoMake", enabled == true)
end)

-- Auto-make loop (throttled; cooldown is whole seconds so 0.2s polling is plenty).
task.spawn(function()
	while true do
		task.wait(0.2)
		local now = Workspace:GetServerTimeNow()
		for _, plot in ipairs(Workspace:GetChildren()) do
			if plot.Name:match("^Plot%d+$") then
				local placed = plot:FindFirstChild("PlacedMachines")
				if placed then
					for _, m in ipairs(placed:GetChildren()) do
						if isDropper(m) and m:GetAttribute("AutoMake") == true then
							if now - ((m:GetAttribute("LastProducedAt") :: number?) or 0) >= DropperConfig.AutoCooldown then
								produce(m)
							end
						end
					end
				end
			end
		end
	end
end)

print("[DropperMachine] online")
