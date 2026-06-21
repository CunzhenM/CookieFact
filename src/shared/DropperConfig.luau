--!strict
-- Dough Dropper recipes + tuning. Shared by the server machine (DropperMachine) and the client UI
-- (DropperUI). Placeholder content for now -- one recipe, Chocolate Chip.
local DropperConfig = {}

DropperConfig.StartingAmount = 9999 -- testing: each placed dropper starts stocked with this much of every ingredient
DropperConfig.AutoCooldown = 2.0 -- seconds between auto-make productions

-- Every ingredient a machine can stock. `id` keys the machine attribute "Ing_<id>"; order = ticker order.
DropperConfig.Ingredients = {
	{ id = "Flour", name = "Flour" },
	{ id = "Sugar", name = "Sugar" },
	{ id = "Butter", name = "Butter" },
	{ id = "ChocolateChips", name = "Chocolate Chips" },
	{ id = "Eggs", name = "Eggs" },
}

DropperConfig.Recipes = {
	{
		id = "ChocolateChip",
		name = "Chocolate Chip",
		description = "The classic — gooey chocolate chips in a golden, chewy cookie.",
		stat = "Sells for 5  •  Bakes in 10s",
		color = Color3.fromRGB(170, 110, 60),
		requires = { Flour = 3, Sugar = 2, Butter = 1, ChocolateChips = 4, Eggs = 1 },
	},
}

DropperConfig.RemotesFolder = "DropperRemotes"
DropperConfig.Remotes = {
	Make = "MakeDough",
	SetAuto = "SetAutoMake",
}

function DropperConfig.getRecipe(id: string?)
	for _, r in ipairs(DropperConfig.Recipes) do
		if r.id == id then
			return r
		end
	end
	return nil
end

function DropperConfig.ingredientName(id: string): string
	for _, ing in ipairs(DropperConfig.Ingredients) do
		if ing.id == id then
			return ing.name
		end
	end
	return id
end

return DropperConfig

