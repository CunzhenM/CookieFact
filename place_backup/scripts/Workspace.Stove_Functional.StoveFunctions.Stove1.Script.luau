local stove1 = script.Parent
local hingepos = script.Parent.Hinge
local tpart = script.Parent.Tpart.ClickDetector
local stoveinside = script.Parent.Parent.StoveInside
local light2 = script.Parent.Parent.Light2
local stovelight = script.Parent.Parent.StoveInsideLight.Light
local stovelightpart = script.Parent.Parent.StoveInsideLight.Light.SurfaceLight
local open = false
local db = false

tpart.MouseClick:Connect(function()

if db == false then
if open == false then
	open = true
db = true

for i = 1,22,1 do
stove1:SetPrimaryPartCFrame(stove1:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(0,math.rad(0),-.1,0))
	wait()
end
stoveinside.Color = Color3.fromRGB(34, 18, 18)
light2.Material = 'Neon'
stovelight.Material = 'Neon'
stovelightpart.Enabled = true
db = false
elseif open == true and db == false then

for i = 1,22,1 do
stove1:SetPrimaryPartCFrame(stove1:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(0,math.rad(0),.1,0))
	wait()
stoveinside.Color = Color3.fromRGB(17, 17, 17)
light2.Material = 'SmoothPlastic'
stovelight.Material = 'SmoothPlastic'
stovelightpart.Enabled = false
open = false
db = true
end
db = false
end
end
end)

