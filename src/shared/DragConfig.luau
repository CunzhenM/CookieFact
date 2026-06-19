--!strict
-- Shared tuning + naming for the drag system. Both the client controller and the
-- server service read from here so the two sides always agree.
local DragConfig = {
	-- CollectionService tag a BasePart or Model must have to be draggable.
	Tag = "Draggable",

	-- Radius (studs) of the invisible bounds sphere centred on the PLAYER (not the
	-- camera). The object is held along the cursor ray, clamped to this sphere.
	SphereRadius = 30,

	-- Closest the object is ever allowed to sit to the player's origin.
	MinDistance = 5,

	-- How far the cursor ray searches for a surface to drag the object across.
	MaxRayLength = 1000,

	-- Position smoothing. Each frame the object eases toward the cursor target with
	-- a framerate-independent exponential lerp. LOWER = heavier / floatier, HIGHER =
	-- snappier. ~7 gives the requested heavy, lagging feel.
	Smoothing = 7,

	-- Studs the object moves toward/away from the player per mouse-wheel notch.
	ScrollStep = 3,

	-- Release / fling tuning.
	VelocitySmoothing = 12, -- how tightly the throw velocity tracks recent motion (higher = snappier)
	FlingMultiplier = 1.1, -- scales the throw speed when you let go
	MaxFlingSpeed = 150, -- studs/s cap on a throw

	-- First-person flinging: snappier drag so throws actually carry.
	FirstPersonSmoothing = 18, -- replaces Smoothing while dragging in first person (higher = snappier)

	-- Thrown objects get lighter gravity so they float and carry further.
	FlingGravityScale = 0.6, -- gravity multiplier for any thrown object (1 = normal)
	FirstPersonGravityScale = 0.4, -- even floatier for first-person throws
	FlingGravityDuration = 6, -- max seconds the lightened gravity lasts on a real (engine) part

	-- Faux-physics (anchored multi-part models simulated as one rigid body).
	GroundFriction = 6, -- horizontal damping per second while resting on a surface
	AirDrag = 0.02, -- gentle air damping per second
	Bounce = 0.25, -- restitution when landing
	RestSpeed = 1.5, -- below this speed on the ground the body goes to sleep

	-- The outline shown around the object while it is being dragged.
	OutlineColor = Color3.new(1, 1, 1),

	-- Remote plumbing (created at runtime by the server service).
	RemotesFolder = "DragRemotes",
	RequestRemote = "RequestDrag",
	ReleaseRemote = "EndDrag",

	-- Tag marking a conveyor belt surface (shared so the drag release can detect when
	-- an item is being dropped onto a conveyor and cancel its throw momentum).
	ConveyorBeltTag = "ConveyorBelt",
}

return DragConfig
