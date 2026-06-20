local u1 = game:GetService("ReplicatedStorage")
local u2 = require(u1.Modules.ControllerLoader.PlacementController)
local v3 = require(u1.Shared.Data.Tags)
local u4 = require(u1.Shared.Packages.Trove)
local u5 = require(u1.Shared.Functional.SetupBrainrotGui)
local u6 = require(u1.Shared.Functional.LoadIdleAnimations)
local u7 = game:GetService("Players").LocalPlayer
local u8 = {
    ["Tag"] = ({
        ["Tag"] = v3.EntityTool
    }).Tag
}
u8.__index = u8
function u8.new(p9) --[[ Line: 26 ]]
    --[[
    Upvalues:
        [1] = u8
    --]]
    local v10 = u8
    local v11 = setmetatable({
        ["Tool"] = p9,
        ["Loaded"] = false,
        ["Initialized"] = false
    }, v10)
    v11:_init()
    return v11
end
function u8.LoadModel(p12) --[[ Line: 38 ]]
    --[[
    Upvalues:
        [1] = u1
        [2] = u5
        [3] = u6
    --]]
    local v13 = p12.Tool.Name
    local v14 = u1.Objects.Entities:FindFirstChild(v13)
    if v14 then
        local v15 = p12.Trove:Clone(v14)
        local v16 = p12.Tool:GetAttribute("Mutation")
        if v16 then
            v15:AddTag(v16)
        end
        v15:WaitForChild("Root")
        for _, v17 in ipairs(v15:GetDescendants()) do
            if v17:IsA("MeshPart") or (v17:IsA("Part") or v17:IsA("BasePart")) then
                v17.CanCollide = false
                v17.Massless = true
                v17.Anchored = false
                v17.CanTouch = false
                v17.AudioCanCollide = false
            end
        end
        local v18 = p12.Trove:Add(Instance.new("Weld"))
        v18.Part0 = v15.Root
        v18.Part1 = p12.Tool.Handle
        v18.Parent = v15
        v15.Parent = p12.Tool
        local v19 = u5(v15, p12.Tool, nil, true)
        if v19 then
            p12.Trove:Add(v19)
        end
        local v20 = u6(v15)
        if v20 then
            p12.Trove:Add(v20)
        end
    end
end
function u8._init(u21) --[[ Line: 82 ]]
    --[[
    Upvalues:
        [1] = u4
        [2] = u7
        [3] = u2
    --]]
    if not u21.Initialized then
        u21.Initialized = true
        local u22 = u21.Tool
        local v23 = u4.new()
        u21.Trove = v23
        local u24 = v23:Extend()
        local function v25() --[[ Line: 94 ]]
            --[[
            Upvalues:
                [1] = u22
                [2] = u21
                [3] = u24
            --]]
            if u22:IsDescendantOf(workspace) then
                if u21.Loaded then
                    return
                end
                u21.Loaded = true
                u21:LoadModel()
                u24:Clean()
            end
        end
        if u22:IsDescendantOf(workspace) and not u21.Loaded then
            u21.Loaded = true
            u21:LoadModel()
            u24:Clean()
        end
        u24:Add(u22.AncestryChanged:Connect(v25))
        if u22:IsDescendantOf(u7.Backpack) or u22:IsDescendantOf(u7.Character) then
            u21.Trove:Add(u22.Equipped:Connect(function() --[[ Line: 110 ]]
                --[[
                Upvalues:
                    [1] = u21
                    [2] = u2
                --]]
                u21.Equipped = true
                u2.IsHolding = true
                u2.HoldingChanged:Fire()
            end))
            u21.Trove:Add(u22.Unequipped:Connect(function() --[[ Line: 116 ]]
                --[[
                Upvalues:
                    [1] = u21
                    [2] = u2
                --]]
                u21.Equipped = false
                u2.IsHolding = false
                u2.HoldingChanged:Fire()
            end))
        end
    end
end
function u8.Destroy(p26) --[[ Line: 124 ]]
    --[[
    Upvalues:
        [1] = u2
    --]]
    if p26.Equipped then
        u2.IsHolding = false
        u2.HoldingChanged:Fire()
    end
    p26.Trove:Destroy()
end
return u8