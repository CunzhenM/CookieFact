local ovenb3 = script.Parent
local hingepos = script.Parent.Hinge
local tpart = script.Parent.Tpart.ClickDetector
local oven3 = script.Parent.Parent.Ovens.Oven3.Union
local light1 = script.Parent.Parent.Light1
local open = false
local db = false

tpart.MouseClick:Connect(function()

if db == false then
if open == false then
	open = true
db = true

for i = 1,22,1 do
ovenb3:SetPrimaryPartCFrame(ovenb3:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(0,math.rad(0),-.1,0))
	wait()
end
oven3.Color = Color3.fromRGB(34, 18, 18)
light1.Material = 'Neon'
db = false
elseif open == true and db == false then

for i = 1,22,1 do
ovenb3:SetPrimaryPartCFrame(ovenb3:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(0,math.rad(0),.1,0))
	wait()
oven3.Color = Color3.fromRGB(17, 17, 17)
light1.Material = 'SmoothPlastic'
open = false
db = true
end
db = false
end
end
end)

