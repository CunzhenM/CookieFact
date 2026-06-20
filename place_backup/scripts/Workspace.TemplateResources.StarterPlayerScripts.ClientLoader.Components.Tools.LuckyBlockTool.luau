local u1 = game:GetService("ReplicatedStorage")
local v2 = require(u1.Shared.Data.Tags)
local u3 = require(u1.Shared.Packages.Trove)
local u4 = require(u1.Shared.Packages.Network)
local u5 = game:GetService("Players").LocalPlayer
local u6 = {
    ["Tag"] = ({
        ["Tag"] = v2.LuckyBlockTool
    }).Tag
}
u6.__index = u6
function u6.new(p7) --[[ Line: 22 ]]
    --[[
    Upvalues:
        [1] = u6
    --]]
    local v8 = u6
    local v9 = setmetatable({
        ["Tool"] = p7,
        ["Loaded"] = false,
        ["Initialized"] = false
    }, v8)
    v9:_init()
    return v9
end
function u6.LoadModel(p10) --[[ Line: 34 ]]
    --[[
    Upvalues:
        [1] = u1
    --]]
    local v11 = p10.Tool.Name
    local v12 = u1.Objects.LuckyBlockModels:FindFirstChild(v11)
    if v12 then
        local v13 = p10.Trove:Clone(v12)
        local v14 = p10.Tool:GetAttribute("Mutation")
        if v14 then
            v13:AddTag(v14)
        end
        v13:WaitForChild("Root")
        for _, v15 in ipairs(v13:GetDescendants()) do
            if v15:IsA("MeshPart") or (v15:IsA("Part") or v15:IsA("BasePart")) then
                v15.CanCollide = false
                v15.Massless = true
                v15.Anchored = false
                v15.CanTouch = false
                v15.AudioCanCollide = false
            end
        end
        local v16 = p10.Trove:Add(Instance.new("Weld"))
        v16.Part0 = v13.Root
        v16.Part1 = p10.Tool.Handle
        v16.Parent = v13
        v13.Parent = p10.Tool
    end
end
function u6._init(u17) --[[ Line: 68 ]]
    --[[
    Upvalues:
        [1] = u3
        [2] = u5
        [3] = u4
    --]]
    if not u17.Initialized then
        u17.Initialized = true
        local v18 = u17.Tool
        u17.Trove = u3.new()
        u17.Trove:Add(v18.Equipped:Once(function() --[[ Line: 78 ]]
            --[[
            Upvalues:
                [1] = u17
            --]]
            if not u17.Loaded then
                u17.Loaded = true
                u17:LoadModel()
            end
        end))
        if v18:IsDescendantOf(u5.Backpack) or v18:IsDescendantOf(u5.Character) then
            u17.Trove:Add(v18.Activated:Connect(function() --[[ Line: 88 ]]
                --[[
                Upvalues:
                    [1] = u4
                --]]
                u4.FireServer("lb_open")
            end))
        end
    end
end
function u6.Destroy(p19) --[[ Line: 94 ]]
    p19.Trove:Destroy()
end
return u6