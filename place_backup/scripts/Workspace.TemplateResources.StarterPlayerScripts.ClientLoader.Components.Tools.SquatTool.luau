local v1 = game:GetService("ReplicatedStorage")
local u2 = game:GetService("RunService")
local u3 = require(v1.Modules.ServicesLoader.WeightServiceClient)
local v4 = require(v1.Shared.Data.Tags)
local u5 = require(v1.Shared.Packages.Trove)
require(v1.Shared.Packages.Signal)
local u6 = require(v1.Modules.UILoader.KickUpgradesUI)
local u7 = require(v1.Modules.ControllerLoader.ZoneController)
local u8 = require(v1.Modules.HandlerLoader.GameHandler)
local u9 = require(v1.Modules.ControllerLoader.AnimationController)
local _ = v1.Objects.Animations
local u10 = require(v1.Shared.Data.WeightsData)
local u11 = game:GetService("Players").LocalPlayer
local u12 = {
    ["Tag"] = ({
        ["Tag"] = v4.SquatTool
    }).Tag
}
u12.__index = u12
function u12.new(p13) --[[ Line: 48 ]]
    --[[
    Upvalues:
        [1] = u11
        [2] = u12
    --]]
    if p13.Parent == u11.Backpack or p13.Parent == u11.Character then
        local v14 = u12
        local v15 = setmetatable({
            ["Tool"] = p13,
            ["Initialized"] = false
        }, v14)
        v15:_init()
        return v15
    end
end
function u12._init(p16) --[[ Line: 61 ]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u11
        [3] = u10
        [4] = u9
        [5] = u6
        [6] = u7
        [7] = u8
        [8] = u3
        [9] = u2
    --]]
    if not p16.Initialized then
        p16.Initialized = true
        local u17 = p16.Tool
        local u18 = u5.new()
        p16.Trove = u18
        local u19 = 0
        local u20 = nil
        local function u22() --[[ Line: 78 ]]
            --[[
            Upvalues:
                [1] = u11
                [2] = u10
                [3] = u17
                [4] = u9
                [5] = u6
            --]]
            if u11.Character then
                u11.Character.PrimaryPart.Anchored = false
                local v21 = u10.Animations[u17.Name] or u10.Animations.Default
                u9.StopAnim(v21)
            end
            u6:Unequipped()
        end
        u18:Connect(u17.Equipped, function() --[[ Line: 87 ]]
            --[[
            Upvalues:
                [1] = u11
                [2] = u7
                [3] = u8
                [4] = u17
                [5] = u10
                [6] = u9
                [7] = u3
                [8] = u19
                [9] = u20
                [10] = u2
                [11] = u6
                [12] = u18
                [13] = u22
            --]]
            if not u11.Character and true or (u7.Zone == "KickReady" and true or u8.InGame) then
                local v23 = u17
                local v24 = u11.Character
                local v25 = v24 and (v23.Parent == v24 and v24:FindFirstChildOfClass("Humanoid"))
                if v25 then
                    v25:UnequipTools()
                end
            end
            local v26 = u10.Animations[u17.Name] or u10.Animations.Default
            local u27 = u9.PlayAnim(v26)
            if u27 then
                u27.Looped = true
                u27:AdjustSpeed(1.5 * u3.Multipliers.Speed)
            end
            local v28 = u3.MultiplierChanged:Connect(function() --[[ Line: 100 ]]
                --[[
                Upvalues:
                    [1] = u27
                    [2] = u3
                --]]
                if u27 then
                    u27:AdjustSpeed(1.5 * u3.Multipliers.Speed)
                end
            end)
            u19 = tick()
            u20 = u2.PreRender:Connect(function() --[[ Line: 107 ]]
                --[[
                Upvalues:
                    [1] = u19
                    [2] = u3
                    [3] = u6
                --]]
                local v29 = tick()
                if v29 - u19 >= 1 / u3.Multipliers.Speed then
                    u19 = v29
                    u6:Pop()
                end
            end)
            u18:Add(v28)
            u18:Add(u20)
            u18:Add(u22)
            u11.Character.PrimaryPart.Anchored = true
        end)
        u18:Connect(u17.Unequipped, function() --[[ Line: 123 ]]
            --[[
            Upvalues:
                [1] = u20
                [2] = u18
                [3] = u22
                [4] = u6
                [5] = u10
                [6] = u17
                [7] = u9
                [8] = u11
            --]]
            if u20 and u20.Connected then
                u18:Remove(u20)
                u20:Disconnect()
            end
            u18:Remove(u22)
            u6:Unequipped()
            local v30 = u10.Animations[u17.Name] or u10.Animations.Default
            u9.StopAnim(v30)
            u11.Character.PrimaryPart.Anchored = false
        end)
        p16.Trove:Add(u7.ZoneChanged:Connect(function(p31) --[[ Line: 136 ]]
            --[[
            Upvalues:
                [1] = u17
                [2] = u11
            --]]
            if p31 == "KickReady" then
                local v32 = u17
                local v33 = u11.Character
                local v34 = v33 and (v32.Parent == v33 and v33:FindFirstChildOfClass("Humanoid"))
                if v34 then
                    v34:UnequipTools()
                end
            end
        end))
        p16.Trove:Add(u8.GameChanged:Connect(function(p35) --[[ Line: 142 ]]
            --[[
            Upvalues:
                [1] = u17
                [2] = u11
            --]]
            if p35 then
                local v36 = u17
                local v37 = u11.Character
                local v38 = v37 and (v36.Parent == v37 and v37:FindFirstChildOfClass("Humanoid"))
                if v38 then
                    v38:UnequipTools()
                end
            end
        end))
    end
end
function u12.Destroy(p39) --[[ Line: 149 ]]
    p39.Trove:Destroy()
end
return u12