local u1 = game:GetService("ReplicatedStorage")
local u2 = require(u1.Modules.ServicesLoader.PolicyInfoService)
local v3 = require(u1.Shared.Data.Tags)
local u4 = require(u1.Shared.Packages.Trove)
local u5 = {
    ["Tag"] = ({
        ["Tag"] = v3.PaidRandomItem
    }).Tag
}
u5.__index = u5
function u5.new(p6) --[[ Line: 19 ]]
    --[[
    Upvalues:
        [1] = u5
    --]]
    local v7 = {
        ["Object"] = p6,
        ["Parent"] = p6.Parent,
        ["Initialized"] = false
    }
    local v8 = u5
    local v9 = setmetatable(v7, v8)
    v9:_init()
    return v9
end
function u5.UpdateObject(p10) --[[ Line: 31 ]]
    --[[
    Upvalues:
        [1] = u2
        [2] = u1
    --]]
    if u2.PolicyInfo.ArePaidRandomItemsRestricted then
        p10.Object.Parent = u1
    elseif p10.Object.Parent ~= p10.Parent then
        p10.Object.Parent = p10.Parent
    end
end
function u5._init(u11) --[[ Line: 39 ]]
    --[[
    Upvalues:
        [1] = u4
        [2] = u2
    --]]
    if not u11.Initialized then
        u11.Initialized = true
        u11.Trove = u4.new()
        u11:UpdateObject()
        u11.Trove:Add(u2.PolicyChanged:Connect(function() --[[ Line: 47 ]]
            --[[
            Upvalues:
                [1] = u11
            --]]
            u11:UpdateObject()
        end))
    end
end
function u5.Destroy(p12) --[[ Line: 52 ]]
    p12.Trove:Destroy()
end
return u5