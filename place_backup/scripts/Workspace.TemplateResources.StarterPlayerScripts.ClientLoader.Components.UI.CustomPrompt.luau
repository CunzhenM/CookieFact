local v1 = game:GetService("ReplicatedStorage")
local u2 = game:GetService("UserInputService")
local u3 = game:GetService("TweenService")
local v4 = require(v1.Shared.Data.Tags)
local u5 = require(v1.Shared.Packages.Trove)
local v6 = require(v1.Modules.ServicesLoader.ClientProfile)
local _ = v6.Device == v6.DeviceTypes.Mobile
local u7 = script:WaitForChild("HapticEffect")
local u8 = script:WaitForChild("Prompt")
local v9 = game:GetService("Players").LocalPlayer.PlayerGui
local u10 = v9:FindFirstChild("SurfaceGUIs") or v9:WaitForChild("SurfaceGUIs")
local u11 = {
    ["Tag"] = ({
        ["Tag"] = v4.CustomPrompt
    }).Tag
}
u11.__index = u11
function u11.new(p12) --[[ Line: 33 ]]
    --[[
    Upvalues:
        [1] = u11
    --]]
    local v13 = {
        ["ProximityPrompt"] = p12,
        ["Adornee"] = p12.Parent,
        ["Initialized"] = false
    }
    local v14 = u11
    local v15 = setmetatable(v13, v14)
    v15:_init()
    return v15
end
function u11.TweenPrompt(p16) --[[ Line: 46 ]]
    --[[
    Upvalues:
        [1] = u3
    --]]
    local v17 = p16.Billboard
    if v17 then
        v17.Frame.GroupTransparency = 0
        local v18 = TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true)
        u3:Create(v17.Frame, v18, {
            ["GroupTransparency"] = 1
        }):Play()
    end
end
function u11.OnShown(p19) --[[ Line: 55 ]]
    --[[
    Upvalues:
        [1] = u3
    --]]
    if p19.Billboard then
        p19.Billboard.Frame.GroupTransparency = 1
        p19.Billboard.Frame.Rotation = -30
        u3:Create(p19.Billboard.Frame, TweenInfo.new(0.25), {
            ["GroupTransparency"] = 0
        }):Play()
        u3:Create(p19.Billboard.Frame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            ["Rotation"] = 0
        }):Play()
    end
end
function u11.OnHidden(p20) --[[ Line: 64 ]]
    --[[
    Upvalues:
        [1] = u3
    --]]
    if p20.Billboard then
        p20.Billboard.Frame.GroupTransparency = 0
        u3:Create(p20.Billboard.Frame, TweenInfo.new(0.25), {
            ["GroupTransparency"] = 1
        }):Play()
    end
end
function u11.ClonePrompt(u21, p22) --[[ Line: 71 ]]
    --[[
    Upvalues:
        [1] = u8
        [2] = u10
    --]]
    local v23 = u8:Clone()
    local v24 = v23:WaitForChild("Frame")
    local v25 = v24:WaitForChild("InputFrame")
    local v26 = v24:WaitForChild("TextFrame")
    local u27 = v26:WaitForChild("ActionText")
    local u28 = v26:WaitForChild("ObjectText")
    local v29 = v25:WaitForChild("Frame"):WaitForChild("ButtonText")
    local v30 = v25.Frame.ButtonIcon
    u27.Text = u21.ProximityPrompt.ActionText
    u28.Text = u21.ProximityPrompt.ObjectText
    if #u28.Text == 0 then
        u27.Position = UDim2.fromOffset(0, 0)
    else
        u27.Position = UDim2.fromOffset(0, 10)
    end
    if p22 then
        v29.Visible = false
        v29.Parent.ButtonImage.Visible = false
        v30.Image = p22
        v30.Visible = true
    else
        v29.Visible = true
        v30.Visible = false
        v29.Parent.ButtonImage.Visible = true
        v29.Text = u21.ProximityPrompt.KeyboardKeyCode.Name
    end
    local v31 = u21.ProximityPrompt.UIOffset
    if v31 ~= Vector2.zero then
        v23.SizeOffset = Vector2.new(v31.X, v31.Y)
    end
    local function v32() --[[ Line: 110 ]]
        --[[
        Upvalues:
            [1] = u28
            [2] = u21
            [3] = u27
        --]]
        u28.Text = u21.ProximityPrompt.ObjectText
        u27.Text = u21.ProximityPrompt.ActionText
        if #u28.Text == 0 then
            u27.Position = UDim2.fromOffset(0, 0)
        else
            u27.Position = UDim2.fromOffset(0, 10)
        end
    end
    local v33 = u21.EnabledTrove
    if v33 then
        v33:Add(u21.ProximityPrompt:GetPropertyChangedSignal("ActionText"):Connect(v32))
        v33:Add(u21.ProximityPrompt:GetPropertyChangedSignal("ObjectText"):Connect(v32))
    end
    v23.Parent = u10
    v23.Adornee = u21.Adornee
    return v23
end
function u11._init(u34) --[[ Line: 132 ]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u2
        [3] = u3
        [4] = u7
    --]]
    if not u34.Initialized then
        u34.Initialized = true
        local u35 = u5.new()
        u34.Trove = u35
        local u36 = u35:Extend()
        u34.EnabledTrove = u36
        local u37 = u34.ProximityPrompt
        if u37.Style == Enum.ProximityPromptStyle.Custom then
            local u38 = nil
            if u2.TouchEnabled then
                u38 = "rbxasset://textures/ui/Controls/TouchTapIcon@3x.png"
            elseif u2.GamepadEnabled then
                u38 = u2:GetImageForKeyCode(u34.ProximityPrompt.GamepadKeyCode)
            end
            u35:Add(u37.PromptShown:Connect(function() --[[ Line: 153 ]]
                --[[
                Upvalues:
                    [1] = u34
                    [2] = u38
                    [3] = u36
                    [4] = u37
                    [5] = u3
                    [6] = u35
                --]]
                local v39 = u34:ClonePrompt(u38)
                u34.Billboard = v39
                u34:OnShown()
                local v40 = v39.TextButton
                u36:Add(v40.InputBegan:Connect(function(p41) --[[ Line: 160 ]]
                    --[[
                    Upvalues:
                        [1] = u34
                        [2] = u37
                    --]]
                    if p41.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        local v42
                        if p41.UserInputType == Enum.UserInputType.Gamepad1 then
                            v42 = p41.KeyCode == u34.ProximityPrompt.GamepadKeyCode
                        else
                            v42 = false
                        end
                        if not v42 then
                            return
                        end
                    end
                    u37:InputHoldBegin()
                end))
                u36:Add(v40.InputEnded:Connect(function(p43) --[[ Line: 171 ]]
                    --[[
                    Upvalues:
                        [1] = u34
                        [2] = u37
                    --]]
                    if p43.UserInputType ~= Enum.UserInputType.MouseButton1 and p43.UserInputType ~= Enum.UserInputType.Touch then
                        local v44
                        if p43.UserInputType == Enum.UserInputType.Gamepad1 then
                            v44 = p43.KeyCode == u34.ProximityPrompt.GamepadKeyCode
                        else
                            v44 = false
                        end
                        if not v44 then
                            return
                        end
                    end
                    u37:InputHoldEnd()
                end))
                if u37.HoldDuration > 0 then
                    local v45 = v39.Frame.InputFrame.RoundFrame.CircularProgressBar
                    local u46 = v45.FR
                    local u47 = u46.ImageLabel.UIGradient
                    local u48 = v45.FL
                    local u49 = u48.ImageLabel.UIGradient
                    local u50 = v45.Progress
                    local u51 = v39.Frame.InputFrame.UIScale
                    local u52 = v39.Frame.TextFrame
                    local u53 = false
                    local function u58(p54) --[[ Line: 206 ]]
                        --[[
                        Upvalues:
                            [1] = u53
                            [2] = u3
                            [3] = u51
                            [4] = u52
                        --]]
                        local v55 = p54 > 0
                        if u53 == v55 then
                            return
                        else
                            u53 = v55
                            if u53 then
                                u3:Create(u51, TweenInfo.new(0.5), {
                                    ["Scale"] = 1.2
                                }):Play()
                                u3:Create(u52, TweenInfo.new(0.5), {
                                    ["GroupTransparency"] = 1
                                }):Play()
                                for _, v56 in ipairs(u52:GetChildren()) do
                                    if v56:IsA("TextLabel") then
                                        u3:Create(v56, TweenInfo.new(0.5), {
                                            ["Position"] = UDim2.new(-1, 0, 0, v56.Position.Y.Offset)
                                        }):Play()
                                    end
                                end
                            else
                                u3:Create(u51, TweenInfo.new(0.1), {
                                    ["Scale"] = 1
                                }):Play()
                                u3:Create(u52, TweenInfo.new(0.1), {
                                    ["GroupTransparency"] = 0
                                }):Play()
                                for _, v57 in ipairs(u52:GetChildren()) do
                                    if v57:IsA("TextLabel") then
                                        u3:Create(v57, TweenInfo.new(0.1), {
                                            ["Position"] = UDim2.new(0, 0, 0, v57.Position.Y.Offset)
                                        }):Play()
                                    end
                                end
                            end
                        end
                    end
                    u35:Add(u50:GetPropertyChangedSignal("Value"):Connect(function() --[[ Line: 232 ]]
                        --[[
                        Upvalues:
                            [1] = u50
                            [2] = u46
                            [3] = u48
                            [4] = u49
                            [5] = u47
                            [6] = u58
                        --]]
                        local v59 = u50.Value
                        if v59 == 0 then
                            u46.Visible = false
                            u48.Visible = false
                        else
                            u46.Visible = true
                            u48.Visible = true
                        end
                        local v60 = math.clamp(v59, 0, 180)
                        local v61 = math.clamp(v59, 180, 360)
                        u49.Rotation = v60
                        u47.Rotation = v61
                        u58(v59)
                    end))
                    u35:Add(u37.PromptButtonHoldBegan:Connect(function() --[[ Line: 246 ]]
                        --[[
                        Upvalues:
                            [1] = u3
                            [2] = u50
                            [3] = u34
                        --]]
                        u3:Create(u50, TweenInfo.new(u34.ProximityPrompt.HoldDuration), {
                            ["Value"] = 360
                        }):Play()
                    end))
                    u35:Add(u37.PromptButtonHoldEnded:Connect(function() --[[ Line: 250 ]]
                        --[[
                        Upvalues:
                            [1] = u3
                            [2] = u50
                        --]]
                        u3:Create(u50, TweenInfo.new(0.15), {
                            ["Value"] = 0
                        }):Play()
                    end))
                    u36:Add(v40.InputBegan:Connect(function(p62) --[[ Line: 254 ]]
                        --[[
                        Upvalues:
                            [1] = u37
                        --]]
                        local v63
                        if p62.UserInputType == Enum.UserInputType.Touch then
                            v63 = p62.UserInputState == Enum.UserInputState.Begin
                        else
                            v63 = false
                        end
                        if v63 then
                            u37:InputHoldBegin()
                        end
                    end))
                    u36:Add(v40.InputEnded:Connect(function(p64) --[[ Line: 261 ]]
                        --[[
                        Upvalues:
                            [1] = u37
                        --]]
                        if p64.UserInputType == Enum.UserInputType.Touch then
                            u37:InputHoldEnd()
                        end
                    end))
                else
                    u36:Add(v40.InputBegan:Connect(function(p65) --[[ Line: 268 ]]
                        --[[
                        Upvalues:
                            [1] = u37
                        --]]
                        if p65.UserInputType == Enum.UserInputType.Touch and p65.UserInputState == Enum.UserInputState.Begin then
                            u37:InputHoldBegin()
                        end
                    end))
                end
                u36:Add(function() --[[ Line: 275 ]]
                    --[[
                    Upvalues:
                        [1] = u34
                    --]]
                    u34:OnHidden()
                    if u34.Billboard then
                        game.Debris:AddItem(u34.Billboard, 0.33)
                    end
                end)
            end))
            u35:Add(u37.PromptHidden:Connect(function() --[[ Line: 284 ]]
                --[[
                Upvalues:
                    [1] = u36
                --]]
                u36:Clean()
            end))
        end
        u35:Add(u34.ProximityPrompt.Triggered:Connect(function() --[[ Line: 289 ]]
            --[[
            Upvalues:
                [1] = u34
                [2] = u7
            --]]
            u34:TweenPrompt()
            u7:Play()
        end))
    end
end
function u11.Destroy(p66) --[[ Line: 295 ]]
    p66.Trove:Destroy()
end
return u11