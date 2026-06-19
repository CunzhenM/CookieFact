local FauxPhysics = require(script:WaitForChild("FauxPhysics"))
local DragController = require(script:WaitForChild("DragController"))
local CookingController = require(script:WaitForChild("CookingController"))
local SprintController = require(script:WaitForChild("SprintController"))

FauxPhysics.Start()
DragController.Start()
CookingController.Start()
SprintController.Start()
