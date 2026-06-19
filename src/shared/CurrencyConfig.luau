--!strict
-- Shared currency settings. Safe for clients to read (it's just config); the actual
-- balances live on the server in CurrencyService.
local CurrencyConfig = {
	-- Label for the currency.
	Name = "Coins",

	-- Balance a brand-new player starts with (used when there's no saved data).
	StartingBalance = 0,

	-- The server mirrors each player's balance into `player.<FolderName>.<ValueName>`
	-- (a NumberValue) so clients/UI can READ it. It is server-written only; the
	-- authoritative source of truth is CurrencyService's in-memory table.
	FolderName = "Currency",
	ValueName = "Coins",

	-- Seconds between background autosaves (stubbed until DataStore is wired in).
	AutosaveInterval = 120,
}

return CurrencyConfig
