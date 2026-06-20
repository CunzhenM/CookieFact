local v1 = game:GetService("ReplicatedStorage")
local u2 = require(v1.Modules.ServicesLoader.ClientProfile)
local u3 = game:GetService("TweenService")
local u4 = game:GetService("SoundService")
local v5 = require(v1.Shared.Data.Tags)
local u6 = Random.new()
local u7 = {
    ["Tag"] = ({
        ["Tag"] = v5.Button
    }).Tag
}
u7.__index = u7
function u7.new(p8) --[[ Line: 27 ]]
    --[[
    Upvalues:
        [1] = u7
    --]]
    local v9 = u7
    local v10 = setmetatable({
        ["Object"] = p8,
        ["Initialized"] = false
    }, v9)
    v10:_init()
    return v10
end
function u7.InitAnimations(p11) --[[ Line: 38 ]]
    --[[
    Upvalues:
        [1] = u2
        [2] = u4
        [3] = u3
        [4] = u6
    --]]
    local v12 = p11.Object
    local v13 = u2.Device
    local u14 = v12:HasTag("Rotate")
    if u14 then
        u14 = v12:FindFirstChildOfClass("ImageLabel")
    end
    if u14 then
        (u14:FindFirstChild("UIScale") or Instance.new("UIScale")).Parent = u14
    end
    local u15 = 1
    local u16 = v12:FindFirstChild("UIScale") or Instance.new("UIScale")
    u16.Parent = v12
    local u17 = u16.Scale
    local u18 = u17 * 0.9
    local u19 = u17 * 1.05
    local function u21() --[[ Line: 56 ]]
        --[[
        Upvalues:
            [1] = u4
            [2] = u3
            [3] = u16
            [4] = u18
        --]]
        u4.Effects.UI["UI Click"]:Play()
        local v20 = {
            ["Scale"] = u18
        }
        u3:Create(u16, TweenInfo.new(0.02), v20):Play()
    end
    local function u23() --[[ Line: 61 ]]
        --[[
        Upvalues:
            [1] = u14
            [2] = u3
            [3] = u16
            [4] = u17
        --]]
        if u14 then
            u3:Create(u14, TweenInfo.new(0.1), {
                ["Rotation"] = 0
            }):Play()
            u3:Create(u14.UIScale, TweenInfo.new(0.1), {
                ["Scale"] = 1
            }):Play()
        end
        local v22 = {
            ["Scale"] = u17
        }
        u3:Create(u16, TweenInfo.new(0.02), v22):Play()
    end
    local function u25() --[[ Line: 69 ]]
        --[[
        Upvalues:
            [1] = u14
            [2] = u15
            [3] = u3
            [4] = u6
            [5] = u16
            [6] = u19
        --]]
        if u14 then
            u15 = u15 * -1
            u3:Create(u14, TweenInfo.new(0.1), {
                ["Rotation"] = u15 * u6:NextInteger(10, 20)
            }):Play()
            u3:Create(u14.UIScale, TweenInfo.new(0.1), {
                ["Scale"] = 1.1
            }):Play()
        end
        local v24 = {
            ["Scale"] = u19
        }
        u3:Create(u16, TweenInfo.new(0.02), v24):Play()
    end
    local function v27() --[[ Line: 78 ]]
        --[[
        Upvalues:
            [1] = u16
            [2] = u17
            [3] = u3
            [4] = u18
        --]]
        local v26 = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true)
        u16.Scale = u17
        u3:Create(u16, v26, {
            ["Scale"] = u18
        }):Play()
    end
    if v13 == u2.DeviceTypes.Mobile then
        v12.TouchLongPress:Connect(function(_, p28) --[[ Line: 85 ]]
            --[[
            Upvalues:
                [1] = u21
                [2] = u23
            --]]
            if p28 == Enum.UserInputState.Begin then
                u21()
            elseif p28 == Enum.UserInputState.End then
                u23()
            end
        end)
        v12.TouchTap:Connect(v27)
        v12.InputEnded:Connect(function(p29) --[[ Line: 95 ]]
            --[[
            Upvalues:
                [1] = u23
            --]]
            if p29.UserInputType == Enum.UserInputType.Touch then
                u23()
            end
        end)
    else
        local u30 = false
        v12.InputBegan:Connect(function(p31) --[[ Line: 102 ]]
            --[[
            Upvalues:
                [1] = u30
                [2] = u4
                [3] = u25
                [4] = u21
            --]]
            local v32 = p31.UserInputType == Enum.UserInputType.MouseMovement
            local v33 = p31.UserInputType == Enum.UserInputType.MouseButton1
            if v32 then
                u30 = true
                u4.Effects.UI.Hover:Play()
                u25()
            elseif v33 then
                u21()
            end
        end)
        v12.InputEnded:Connect(function(p34) --[[ Line: 114 ]]
            --[[
            Upvalues:
                [1] = u23
                [2] = u30
                [3] = u25
            --]]
            local v35 = p34.UserInputType == Enum.UserInputType.MouseMovement
            local v36 = p34.UserInputType == Enum.UserInputType.MouseButton1
            if v35 then
                u23()
                u30 = false
            end
            if v36 then
                if u30 then
                    u25()
                    return
                end
                u23()
            end
        end)
    end
end
function u7._init(p37) --[[ Line: 135 ]]
    if not p37.Initialized then
        p37.Initialized = true
        p37:InitAnimations()
    end
end
function u7.Destroy(_) --[[ Line: 143 ]] end
return u7