--!strict
-- Shared configuration for the cooking/baking feature.
local CookConfig = {
	-- The baking surface in the Workspace.
	OvenPartName = "OvenPart",

	-- CollectionService tag marking an object as raw dough that can be baked.
	DoughTag = "Dough",

	-- Name of the Workspace template cloned to replace a finished dough.
	CookieTemplateName = "Cookie",

	-- Seconds a dough bakes before it becomes a cookie.
	BakeTime = 10,

	-- Remote (created under the shared remotes folder) the client uses to report a
	-- dough that has settled on the oven.
	CookRemote = "RequestCook",
}

return CookConfig
