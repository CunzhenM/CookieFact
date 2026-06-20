local v1 = game:GetService("ReplicatedStorage")
local u2 = game:GetService("MarketplaceService")
local u3 = game:GetService("Players")
local v4 = require(v1.Shared.Data.Tags)
local u5 = require(v1.Shared.Data.Gamepasses)
local u6 = require(v1.Shared.Packages.Network)
local u7 = u3.LocalPlayer
local u8 = {
    ["Tag"] = ({
        ["Tag"] = v4.GamepassButton
    }).Tag
}
u8.__index = u8
function u8.new(p9) --[[ Line: 24 ]]
    --[[
    Upvalues:
        [1] = u8
    --]]
    if p9:IsA("GuiButton") then
        local v10 = u8
        local v11 = setmetatable({
            ["Owned"] = nil,
            ["PriceInRobux"] = nil,
            ["ActivatedCon"] = nil,
            ["Key"] = nil,
            ["Button"] = p9
        }, v10)
        v11:_init()
        return v11
    end
end
function u8.UpdateLabels(p12) --[[ Line: 41 ]]
    local v13 = p12.Button:FindFirstChild("Label") or p12.Button:WaitForChild("Label", 1)
    if v13 then
        v13.Text = p12.Owned and "Owned" or ("%*%*"):format(utf8.char(57346), p12.PriceInRobux)
    end
end
function u8.GetPrice(u14, u15) --[[ Line: 48 ]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    task.spawn(function() --[[ Line: 49 ]]
        --[[
        Upvalues:
            [1] = u2
            [2] = u15
            [3] = u14
        --]]
        local v16, v17 = pcall(function() --[[ Line: 50 ]]
            --[[
            Upvalues:
                [1] = u2
                [2] = u15
            --]]
            return u2:GetProductInfoAsync(u15, Enum.InfoType.GamePass)
        end)
        if v16 then
            u14.PriceInRobux = v17.PriceInRobux
            u14:UpdateLabels()
        end
        u14:CheckUserOwns()
    end)
end
function u8.GetCheckPlayer(_) --[[ Line: 63 ]]
    --[[
    Upvalues:
        [1] = u7
        [2] = u3
    --]]
    local v18 = u7:GetAttribute("GiftTargetId")
    return v18 and u3:GetPlayerByUserId(v18) or u7
end
function u8.CheckUserOwns(p19) --[[ Line: 74 ]]
    p19.Owned = p19:GetCheckPlayer():GetAttribute(p19.Key)
    p19:UpdateLabels()
end
function u8.PromptOnActivated(u20, u21) --[[ Line: 81 ]]
    --[[
    Upvalues:
        [1] = u7
        [2] = u3
        [3] = u6
        [4] = u2
    --]]
    if u20.ActivatedCon then
        u20.ActivatedCon:Disconnect()
    end
    u20.ActivatedCon = u20.Button.Activated:Connect(function() --[[ Line: 86 ]]
        --[[
        Upvalues:
            [1] = u20
            [2] = u7
            [3] = u3
            [4] = u6
            [5] = u21
            [6] = u2
        --]]
        if u20.Owned then
            return
        else
            local v22 = u7:GetAttribute("GiftTargetId")
            local v23 = v22 and u3:GetPlayerByUserId(v22)
            if v23 then
                u6.FireServer("myMarket_gift", u21, v23)
                print("fired")
            else
                u2:PromptGamePassPurchase(u7, u21)
            end
        end
    end)
end
function u8.InitializeButton(u24) --[[ Line: 105 ]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u7
        [3] = u3
    --]]
    local u25 = u24.Button:GetAttribute("Key")
    if u25 then
        u24.Key = u25
        local v26 = u5.Gamepasses[u25]
        if v26 then
            u24:PromptOnActivated(v26)
            u24:GetPrice(v26)
            u7:GetAttributeChangedSignal(u25):Connect(function() --[[ Line: 117 ]]
                --[[
                Upvalues:
                    [1] = u24
                --]]
                u24:CheckUserOwns()
            end)
            u7:GetAttributeChangedSignal("GiftTargetId"):Connect(function() --[[ Line: 120 ]]
                --[[
                Upvalues:
                    [1] = u24
                    [2] = u7
                    [3] = u3
                    [4] = u25
                --]]
                if u24.TargetCon then
                    u24.TargetCon:Disconnect()
                    u24.TargetCon = nil
                end
                local v27 = u7:GetAttribute("GiftTargetId")
                local v28 = v27 and u3:GetPlayerByUserId(v27)
                if v28 then
                    u24.TargetCon = v28:GetAttributeChangedSignal(u25):Connect(function() --[[ Line: 130 ]]
                        --[[
                        Upvalues:
                            [1] = u24
                        --]]
                        u24:CheckUserOwns()
                    end)
                end
                u24:CheckUserOwns()
            end)
        end
    else
        return
    end
end
function u8._init(p29) --[[ Line: 139 ]]
    p29:InitializeButton()
end
function u8.Destroy(p30) --[[ Line: 143 ]]
    if p30.ActivatedCon then
        p30.ActivatedCon:Disconnect()
    end
end
return u8