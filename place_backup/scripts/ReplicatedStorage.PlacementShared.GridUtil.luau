--!strict
-- Pure grid math driven by a Workspace AREA PART (movable GridPlacementArea).

local PlacementConfig = require(script.Parent:WaitForChild("PlacementConfig"))
local GridUtil = {}
local CELL = PlacementConfig.CellSize

function GridUtil.dimensions(area)
	return math.floor(area.Size.X / CELL), math.floor(area.Size.Z / CELL)
end

function GridUtil.rotatedFootprint(fpx, fpz, rotSteps)
	if rotSteps % 2 == 1 then
		return fpz, fpx
	end
	return fpx, fpz
end

function GridUtil.cellKey(cx, cz)
	return cx .. "," .. cz
end

function GridUtil.minCornerFromWorld(area, worldPoint, efpx, efpz)
	local local_ = area.CFrame:PointToObjectSpace(worldPoint)
	local nx, nz = GridUtil.dimensions(area)
	local cx = math.floor((local_.X + (nx * CELL) / 2) / CELL - efpx / 2 + 0.5)
	local cz = math.floor((local_.Z + (nz * CELL) / 2) / CELL - efpz / 2 + 0.5)
	return cx, cz
end

function GridUtil.inBounds(area, cx, cz, efpx, efpz)
	local nx, nz = GridUtil.dimensions(area)
	return cx >= 0 and cz >= 0 and (cx + efpx) <= nx and (cz + efpz) <= nz
end

function GridUtil.blockCFrame(area, cx, cz, efpx, efpz, height, rot)
	local nx, nz = GridUtil.dimensions(area)
	local localX = (cx + efpx / 2) * CELL - (nx * CELL) / 2
	local localZ = (cz + efpz / 2) * CELL - (nz * CELL) / 2
	local localY = area.Size.Y / 2 + height / 2
	return area.CFrame * CFrame.new(localX, localY, localZ) * CFrame.Angles(0, math.rad(90 * rot), 0)
end

function GridUtil.occupiedKeys(cx, cz, efpx, efpz)
	local keys = {}
	for x = cx, cx + efpx - 1 do
		for z = cz, cz + efpz - 1 do
			table.insert(keys, GridUtil.cellKey(x, z))
		end
	end
	return keys
end

return GridUtil
