--!strict
-- Persistence layer for currency. STUB for now: nothing is actually saved or loaded,
-- so balances reset when the server restarts. This is the ONE place to add DataStore
-- later -- swap the two function bodies and nothing else in the codebase changes.
--
-- To wire DataStore: uncomment the block below and the bodies marked "DataStore".
local CurrencyStore = {}

-- local DataStoreService = game:GetService("DataStoreService")
-- local store = DataStoreService:GetDataStore("Currency_v1")
-- local function keyFor(userId: number): string
-- 	return "player_" .. userId
-- end

-- Return the saved balance for a user, or nil if there is none / on failure.
-- Returning nil means "no data" -> CurrencyService falls back to StartingBalance.
function CurrencyStore.Load(userId: number): number?
	-- DataStore:
	-- local ok, result = pcall(function()
	-- 	return store:GetAsync(keyFor(userId))
	-- end)
	-- if ok and type(result) == "number" then
	-- 	return result
	-- end
	-- return nil -- on failure, treat as no data (caller should avoid overwriting later)
	return nil
end

-- Persist a user's balance. Returns whether it succeeded.
function CurrencyStore.Save(userId: number, amount: number): boolean
	-- DataStore:
	-- local ok = pcall(function()
	-- 	store:SetAsync(keyFor(userId), amount)
	-- end)
	-- return ok
	return true
end

return CurrencyStore
