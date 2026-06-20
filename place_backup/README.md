# place_backup

A flat, version-controlled snapshot of **every script inside the `CookieFactory.rbxl` place** —
including the systems that live *only* in the place and are **not** part of the Rojo `src/` tree
(the grid placement system, dough dropper, conveyor logic, ovens, and the imported template
resources). It exists so a Studio/computer crash can never lose this code again: it's in git.

## Why this is separate from `src/`

`src/` is Rojo-managed — only the paths mapped in `default.project.json`
(`ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayer…Client`) sync to/from
Studio. The placement system lives at *other* locations in the DataModel and is mixed in with
non-script content (e.g. `ReplicatedStorage.PlacementShared.MachineModels` holds the conveyor
**models**). Mapping those into Rojo wholesale would risk Rojo deleting the models, so this is a
plain backup mirror, **not** a Rojo source. Nothing here is synced automatically.

## Layout

`scripts/<Instance.Path>.luau` — one file per script, named by its full DataModel path. The path
tells you exactly where it belongs (e.g.
`ServerScriptService.PlacementSystem.PlacementService.luau` →
`game.ServerScriptService.PlacementSystem.PlacementService`).

## Refreshing this backup

After a chunk of work in Studio, ask Claude (with the `Roblox_Studio` MCP connected) to
re-export, or re-run the lune extractor in `../_place_extract/`. Filenames are path-stable, so
git diffs show real content changes, not reordering noise.

## Restoring a script

Open the matching instance in Studio (path = filename) and paste the file's contents into it, or
have Claude write it back via the MCP `multi_edit` tool.
