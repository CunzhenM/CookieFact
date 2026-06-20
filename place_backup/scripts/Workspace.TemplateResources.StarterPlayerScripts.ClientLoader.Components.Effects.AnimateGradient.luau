game:GetService("RunService")
local v1 = game:GetService("ReplicatedStorage")
local u2 = require(v1.Modules.ControllerLoader.UIGradientController)
require(v1.Shared.Packages.Trove)
local u3 = {
    ["Tag"] = ({
        ["Tag"] = "AnimateGradient"
    }).Tag
}
u3.__index = u3
function u3.new(p4) --[[ Line: 20 ]]
    --[[
    Upvalues:
        [1] = u3
    --]]
    local v5 = u3
    local v6 = setmetatable({
        ["Gradient"] = p4,
        ["Initialized"] = false
    }, v5)
    v6:_init()
    return v6
end
function u3._init(p7) --[[ Line: 31 ]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    if not p7.Initialized then
        p7.Initialized = true
        u2.Add(p7.Gradient)
    end
end
function u3.Destroy(p8) --[[ Line: 40 ]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    u2.Remove(p8.Gradient)
end
return u3