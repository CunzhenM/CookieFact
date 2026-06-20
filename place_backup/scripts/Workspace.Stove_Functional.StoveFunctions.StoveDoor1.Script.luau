local stovedoor1 = script.Parent
local hingepos = script.Parent.Hinge.Position
local tpart = script.Parent.Tpart.ClickDetector
local open = false
local db = false

tpart.MouseClick:Connect(function()
if db == false then
if open == false then 
	open = true
db = true

for i = 1,16,1 do
stovedoor1:SetPrimaryPartCFrame(stovedoor1:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(.1,math.rad(0),0,0))	
	wait()
end
db = false
elseif open == true and db == false then

for i = 1,16,1 do
stovedoor1:SetPrimaryPartCFrame(stovedoor1:GetPrimaryPartCFrame(hingepos) * CFrame.Angles(-.1,math.rad(0),0,0))	
	wait()
open = false
db = true
end
db = false
end
end
end)
