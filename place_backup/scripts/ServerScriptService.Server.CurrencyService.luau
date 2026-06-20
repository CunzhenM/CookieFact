--!strict
-- Server-authoritative currency. THE single source of truth for player balances.
--
-- Never trust the client: there is no remote that lets a client change its own money.
-- Every shop / upgrade / payout calls this service on the server:
--   * earn / payout  -> CurrencyService.Add(player, amount, reason)
--   * shop / upgrade -> CurrencyService.TrySpend(player, cost, reason)  (atomic, safe)
--   * read           -> CurrencyService.Get(player) / CanAfford(player, amount)
-- A read-only mirror is replicated to each player (see CurrencyConfig) for UI to read.
-- Persistence goes through CurrencyStore (a stub today; drop in DataStore there later).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CurrencyConfig"))
local CurrencyStore = require(script.Parent:WaitForChild("CurrencyStore"))

local CurrencyService = {}

-- Authoritative balances (server memory) -- the single source of truth.
local balances: { [Player]: number } = {}

-- Fires (player, newBalance, oldBalance, reason) on every change. Server systems can
-- listen; clients use the replicated mirror value instead.
local balanceChanged = Instance.new("BindableEvent")
CurrencyService.BalanceChanged = balanceChanged.Event

-- Whole-number, finite amounts only.
local function sanitize(amount: number): number?
	if type(amount) ~= "number" then
		return nil
	end
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return nil
	end
	return math.floor(amount)
end

-- Mirror the balance to a per-player read-only value clients can read.
local function mirror(player: Player, amount: number)
	local folder = player:FindFirstChild(CurrencyConfig.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CurrencyConfig.FolderName
		folder.Parent = player
	end
	local value = folder:FindFirstChild(CurrencyConfig.ValueName)
	if not value then
		value = Instance.new("NumberValue") -- NumberValue holds integers exactly up to 2^53
		value.Name = CurrencyConfig.ValueName
		value.Parent = folder
	end
	(value :: NumberValue).Value = amount
end

local function applyBalance(player: Player, amount: number, reason: string?)
	local old = balances[player] or 0
	balances[player] = amount
	mirror(player, amount)
	balanceChanged:Fire(player, amount, old, reason)
end

-- ===== Public API =====

function CurrencyService.Get(player: Player): number
	return balances[player] or 0
end

function CurrencyService.CanAfford(player: Player, amount: number): boolean
	local amt = sanitize(amount)
	if not amt or amt < 0 then
		return false
	end
	return (balances[player] or 0) >= amt
end

-- Earn / payout. Returns the new balance (unchanged on invalid input).
function CurrencyService.Add(player: Player, amount: number, reason: string?): number
	local amt = sanitize(amount)
	if not amt or amt <= 0 then
		return balances[player] or 0
	end
	local new = (balances[player] or 0) + amt
	applyBalance(player, new, reason)
	return new
end

-- Spend. Atomic: deducts only if the player can afford it. Returns success.
function CurrencyService.TrySpend(player: Player, amount: number, reason: string?): boolean
	local amt = sanitize(amount)
	if not amt or amt <= 0 then
		return false
	end
	local current = balances[player] or 0
	if current < amt then
		return false
	end
	applyBalance(player, current - amt, reason)
	return true
end

-- Force-set a balance (admin / data load). Prefer Add/TrySpend for gameplay.
function CurrencyService.Set(player: Player, amount: number, reason: string?)
	local amt = sanitize(amount)
	if not amt or amt < 0 then
		return
	end
	applyBalance(player, amt, reason)
end

-- ===== Lifecycle =====

local function onPlayerAdded(player: Player)
	if balances[player] ~= nil then
		return -- already loaded
	end
	local saved = CurrencyStore.Load(player.UserId)
	applyBalance(player, saved or CurrencyConfig.StartingBalance, "load")
end

local function onPlayerRemoving(player: Player)
	local amount = balances[player]
	if amount ~= nil then
		CurrencyStore.Save(player.UserId, amount)
	end
	balances[player] = nil
end

local function saveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local amount = balances[player]
		if amount ~= nil then
			CurrencyStore.Save(player.UserId, amount)
		end
	end
end

function CurrencyService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Background autosave (no-op until DataStore is wired into CurrencyStore).
	task.spawn(function()
		while true do
			task.wait(CurrencyConfig.AutosaveInterval)
			saveAll()
		end
	end)

	-- Flush on shutdown.
	game:BindToClose(saveAll)
end

return CurrencyService
