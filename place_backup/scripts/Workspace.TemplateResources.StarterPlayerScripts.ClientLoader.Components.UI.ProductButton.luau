local v1 = game:GetService("ReplicatedStorage")
local u2 = game:GetService("MarketplaceService")
local u3 = game:GetService("Players")
local v4 = require(v1.Shared.Data.Tags)
local u5 = require(v1.Shared.Data.Products)
local u6 = require(v1.Shared.Packages.Network)
local u7 = u3.LocalPlayer
local u8 = {
    ["Tag"] = ({
        ["Tag"] = v4.ProductButton
    }).Tag
}
u8.__index = u8
local u9 = {}
function u8.new(p10) --[[ Line: 28 ]]
    --[[
    Upvalues:
        [1] = u8
    --]]
    if p10:IsA("GuiButton") then
        local v11 = u8
        local v12 = setmetatable({
            ["PriceInRobux"] = nil,
            ["ActivatedCon"] = nil,
            ["Button"] = p10
        }, v11)
        v12:_init()
        return v12
    end
end
function u8.UpdateLabels(p13) --[[ Line: 43 ]]
    local v14 = p13.Button:FindFirstChild("Label") or p13.Button:WaitForChild("Label", 1)
    if v14 then
        v14.Text = ("%*%*"):format(utf8.char(57346), p13.PriceInRobux)
    end
end
function u8.GetPrice(u15, u16) --[[ Line: 50 ]]
    --[[
    Upvalues:
        [1] = u9
        [2] = u2
    --]]
    if u9[u16] then
        return u9[u16]
    end
    task.spawn(function() --[[ Line: 55 ]]
        --[[
        Upvalues:
            [1] = u2
            [2] = u16
            [3] = u9
            [4] = u15
        --]]
        local v17, v18 = pcall(function() --[[ Line: 56 ]]
            --[[
            Upvalues:
                [1] = u2
                [2] = u16
            --]]
            return u2:GetProductInfoAsync(u16, Enum.InfoType.Product)
        end)
        if v17 then
            u9[u16] = v18.PriceInRobux
            u15.PriceInRobux = v18.PriceInRobux
            u15:UpdateLabels()
        end
    end)
end
function u8.PromptOnActivated(p19, u20) --[[ Line: 68 ]]
    --[[
    Upvalues:
        [1] = u7
        [2] = u3
        [3] = u6
        [4] = u2
    --]]
    if p19.ActivatedCon then
        p19.ActivatedCon:Disconnect()
    end
    p19.ActivatedCon = p19.Button.Activated:Connect(function() --[[ Line: 72 ]]
        --[[
        Upvalues:
            [1] = u7
            [2] = u3
            [3] = u6
            [4] = u20
            [5] = u2
        --]]
        local v21 = u7:GetAttribute("GiftTargetId")
        local v22 = v21 and u3:GetPlayerByUserId(v21)
        if v22 then
            u6.FireServer("myMarket_gift", u20, v22)
            print("fired")
        else
            u2:PromptProductPurchase(u7, u20)
        end
    end)
end
function u8.InitializeButton(p23) --[[ Line: 86 ]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local v24 = p23.Button:GetAttribute("Key")
    if v24 then
        local v25 = u5.Products[v24]
        if v25 then
            p23:PromptOnActivated(v25)
            p23:GetPrice(v25)
        end
    else
        return
    end
end
function u8._init(u26) --[[ Line: 101 ]]
    u26:InitializeButton()
    u26.Button:GetAttributeChangedSignal("Key"):Connect(function() --[[ Line: 103 ]]
        --[[
        Upvalues:
            [1] = u26
        --]]
        u26:InitializeButton()
    end)
end
function u8.Destroy(_) --[[ Line: 108 ]] end
return u8