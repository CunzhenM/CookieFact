--!strict
-- Truck shipping: the tagged truck pulls out of its bay, arcs into a turn onto the street (wheels
-- rolling), fades out, pays the player, then resets. Server-side so all see it + payout is
-- authoritative. Tunable path constants below match the reference video.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local TruckShipService = {}

local DURATION = 3.6
local SPEED = 17
local PULL_FRAC = 0.20
local TURN_FRAC = 0.45
local TURN_ANGLE = math.rad(85)
local TURN_SIGN = 1
local FADE_START = 0.62
local RESET_DELAY = 0.9
local SHIP_AMOUNT = 100
local PROMPT_TEXT = "Ship Cookies"

local busy = false

local Currency = nil
local function resolveCurrency()
	local serverScript = ServerScriptService:FindFirstChild("Server")
	local mod = serverScript and serverScript:FindFirstChild("CurrencyService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" then
			Currency = result
		end
	end
end

local function findTruck()
	local tagged, firstTruck
	for _, c in ipairs(Workspace:GetChildren()) do
		if c:IsA("Model") and c.Name:lower():find("truck") then
			firstTruck = firstTruck or c
			if c:GetAttribute("IsShippingTruck") then
				tagged = c
			end
		end
	end
	return tagged or firstTruck
end

local function collectWheels(truck, home)
	local wheels = {}
	for _, d in ipairs(truck:GetDescendants()) do
		if d.Name:lower():find("wheel") and (d:IsA("Model") or d:IsA("BasePart")) then
			local isTop = d:IsA("Model") or (d:IsA("BasePart") and not (d.Parent and d.Parent.Name:lower():find("wheel")))
			if isTop then
				table.insert(wheels, { obj = d, offset = home:Inverse() * d:GetPivot() })
			end
		end
	end
	return wheels
end

local function pay(recipient, amount)
	if not (Currency and Currency.Add) then
		return
	end
	if recipient then
		Currency.Add(recipient, amount, "shipment")
	else
		for _, plr in ipairs(Players:GetPlayers()) do
			Currency.Add(plr, amount, "shipment")
		end
	end
end

function TruckShipService.ship(recipient, amount)
	if busy then
		return false
	end
	local truck = findTruck()
	if not truck then
		return false
	end
	busy = true
	amount = amount or SHIP_AMOUNT

	local home = truck:GetPivot()
	local parts = {}
	for _, d in ipairs(truck:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, { part = d, transparency = d.Transparency, anchored = d.Anchored })
			d.Anchored = true
		end
	end
	local wheels = collectWheels(truck, home)
	local wheelRadius = 2.5
	local w1 = wheels[1] and wheels[1].obj
	if w1 and w1:IsA("Model") then
		local _, s = w1:GetBoundingBox()
		wheelRadius = math.max(1, s.Y / 2)
	elseif w1 and w1:IsA("BasePart") then
		wheelRadius = math.max(1, w1.Size.Y / 2)
	end

	local cur = home
	local elapsed = 0
	local rollAngle = 0
	while elapsed < DURATION and truck.Parent do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local f = math.min(elapsed / DURATION, 1)
		local ds = SPEED * dt
		local yaw = 0
		if f > PULL_FRAC and f <= PULL_FRAC + TURN_FRAC then
			yaw = TURN_SIGN * TURN_ANGLE * (dt / (TURN_FRAC * DURATION))
		end
		cur = cur * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -ds)
		truck:PivotTo(cur)
		rollAngle += ds / wheelRadius
		for _, w in ipairs(wheels) do
			local rigid = cur * w.offset
			local spun = CFrame.fromAxisAngle(cur.RightVector, rollAngle)
			w.obj:PivotTo(CFrame.new(rigid.Position) * (spun * (rigid - rigid.Position)))
		end
		if f > FADE_START then
			local a = (f - FADE_START) / (1 - FADE_START)
			for _, p in ipairs(parts) do
				p.part.Transparency = p.transparency + (1 - p.transparency) * a
			end
		end
	end

	for _, p in ipairs(parts) do
		p.part.Transparency = 1
	end
	pay(recipient, amount)
	task.wait(RESET_DELAY)
	truck:PivotTo(home)
	for _, w in ipairs(wheels) do
		w.obj:PivotTo(home * w.offset)
	end
	for _, p in ipairs(parts) do
		p.part.Transparency = p.transparency
		p.part.Anchored = p.anchored
	end
	busy = false
	return true
end

function TruckShipService.Start()
	resolveCurrency()
	local truck = findTruck()
	if not truck then
		warn("[PlacementSystem] No truck found for TruckShipService.")
		return
	end
	local host = truck:FindFirstChildWhichIsA("BasePart", true)
	if host then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShipPrompt"
		prompt.ActionText = PROMPT_TEXT
		prompt.ObjectText = "Truck ($" .. SHIP_AMOUNT .. ")"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 16
		prompt.Parent = host
		prompt.Triggered:Connect(function(player)
			TruckShipService.ship(player)
		end)
	end
end

return TruckShipService
