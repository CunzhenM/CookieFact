local v1 = game:GetService("ReplicatedStorage")
local u2 = game:GetService("TweenService")
local v3 = require(v1.Shared.Data.Tags)
local u4 = require(v1.Shared.Packages.Trove)
local u5 = {
    ["LastFrame"] = nil,
    ["Tag"] = v3.Frame
}
local u6 = {
    ["Tag"] = u5.Tag
}
u6.__index = u6
function u6.new(p7) --[[ Line: 24 ]]
    --[[
    Upvalues:
        [1] = u6
    --]]
    local v8 = u6
    local v9 = setmetatable({
        ["Object"] = p7,
        ["Initialized"] = false
    }, v8)
    v9:_init()
    return v9
end
function u6.PopUp(p10) --[[ Line: 35 ]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    p10.Object.UIScale.Scale = 0.8
    u2:Create(p10.Object.UIScale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        ["Scale"] = 1
    }):Play()
end
function u6.InitAnimations(u11) --[[ Line: 40 ]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local u12 = u11.Object
    Instance.new("UIScale").Parent = u12
    u11.Trove:Add(u12:GetPropertyChangedSignal("Visible"):Connect(function() --[[ Line: 47 ]]
        --[[
        Upvalues:
            [1] = u12
            [2] = u5
            [3] = u11
        --]]
        if u12.Visible then
            if u5.LastFrame and u5.LastFrame ~= u12 then
                u5.LastFrame.Visible = false
            end
            u5.LastFrame = u12
            u11:PopUp()
        end
    end))
end
function u6._init(p13) --[[ Line: 61 ]]
    --[[
    Upvalues:
        [1] = u4
    --]]
    if not p13.Initialized then
        p13.Initialized = true
        p13.Trove = u4.new()
        p13:InitAnimations()
    end
end
function u6.Destroy(p14) --[[ Line: 70 ]]
    p14.Trove:Destroy()
end
return u6