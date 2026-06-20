local u1 = game:GetService("TweenService")
local v2 = game:GetService("ReplicatedStorage")
local u3 = require(v2.Shared.Packages.Trove)
local u4 = {
    ["Tag"] = ({
        ["Tag"] = "ColorRainbow"
    }).Tag
}
u4.__index = u4
local u5 = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)
function u4.new(p6) --[[ Line: 26 ]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    local v7 = u4
    local v8 = setmetatable({
        ["Object"] = p6,
        ["Tween"] = nil,
        ["Initialized"] = false
    }, v7)
    v8:_init()
    return v8
end
function u4._init(p9) --[[ Line: 38 ]]
    --[[
    Upvalues:
        [1] = u3
        [2] = u1
        [3] = u5
    --]]
    if p9.Initialized then
        return
    else
        p9.Initialized = true
        p9.Trove = u3.new()
        local v10 = p9.Object.ClassName
        if v10 == "UIGradient" then
            local u11 = p9.Object
            local v12 = p9.Trove:Add(Instance.new("NumberValue"))
            v12.Parent = u11
            p9.Trove:Connect(v12.Changed, function(p13) --[[ Line: 54 ]]
                --[[
                Upvalues:
                    [1] = u11
                --]]
                u11.Color = ColorSequence.new(Color3.fromHSV(p13, 0.75, 1))
            end)
            local u14 = u1:Create(v12, u5, {
                ["Value"] = 1
            })
            u14:Play()
            p9.Trove:Add(function() --[[ Line: 61 ]]
                --[[
                Upvalues:
                    [1] = u14
                --]]
                u14:Cancel()
                u14:Destroy()
            end)
        elseif v10 == "BasePart" or (v10 == "MeshPart" or v10 == "Part") then
            local u15 = p9.Object
            local u16 = p9.Object:FindFirstChildOfClass("SurfaceAppearance")
            local v17 = p9.Trove:Add(Instance.new("NumberValue"))
            v17.Parent = u15
            p9.Trove:Add(v17.Changed:Connect(function(p18) --[[ Line: 71 ]]
                --[[
                Upvalues:
                    [1] = u15
                    [2] = u16
                --]]
                u15.Color = Color3.fromHSV(p18, 0.75, 0.7)
                if u16 then
                    u16.Color = Color3.fromHSV(p18, 0.75, 0.7)
                end
            end))
            local u19 = u1:Create(v17, u5, {
                ["Value"] = 1
            })
            u19:Play()
            p9.Trove:Add(function() --[[ Line: 81 ]]
                --[[
                Upvalues:
                    [1] = u19
                --]]
                u19:Cancel()
                u19:Destroy()
            end)
        end
    end
end
function u4.Destroy(p20) --[[ Line: 88 ]]
    p20.Trove:Destroy()
end
return u4