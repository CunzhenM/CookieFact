local v1 = game:GetService("RunService")
local v2 = game:GetService("ReplicatedStorage")
local u3 = require(v2.Shared.Packages.Trove)
local u4 = {
    ["Tag"] = ({
        ["Tag"] = "ShonGradient"
    }).Tag
}
u4.__index = u4
local u5 = {}
function u4.new(p6) --[[ Line: 19 ]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    local v7 = u4
    local v8 = setmetatable({
        ["Gradient"] = p6,
        ["Initialized"] = false
    }, v7)
    v8:_init()
    return v8
end
function u4.Tick(p9, p10) --[[ Line: 30 ]]
    p9.Ticked = p9.Ticked + p10
    p9.Ticked = p9.Ticked % 3
    local v11 = p9.Ticked / 3
    local v12 = math.clamp(v11, 0, 1)
    local v13 = p9.Gradient
    local v14 = Vector2.new
    local v15 = p9.Start
    local v16 = p9.End
    v13.Offset = v14(math.lerp(v15, v16, v12), 0)
end
function u4._init(u17) --[[ Line: 38 ]]
    --[[
    Upvalues:
        [1] = u3
        [2] = u5
    --]]
    if not u17.Initialized then
        u17.Initialized = true
        u17.Trove = u3.new()
        local v18 = u17.Gradient
        local u19 = v18:FindFirstAncestorOfClass("BillboardGui")
        if u19 then
            u17.Enabled = u19.Enabled
            u17.Trove:Connect(u19:GetPropertyChangedSignal("Enabled"), function() --[[ Name: UpdateGUI, Line 50 ]]
                --[[
                Upvalues:
                    [1] = u17
                    [2] = u19
                --]]
                u17.Enabled = u19.Enabled
            end)
        end
        u17.Enabled = true
        u17.Start = -0.18
        u17.End = 0.32
        u17.Ticked = 0
        v18.Offset = Vector2.new(-0.18, 0)
        u5[u17.Gradient] = u17
    end
end
function u4.Destroy(p20) --[[ Line: 70 ]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    u5[p20.Gradient] = nil
    p20.Trove:Destroy()
end
v1.PreRender:Connect(function(p21) --[[ Line: 76 ]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    for _, v22 in pairs(u5) do
        if v22.Enabled then
            v22:Tick(p21)
        end
    end
end)
return u4