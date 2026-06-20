local v1 = game:GetService("ReplicatedStorage")
local v2 = require(v1.Shared.Data.Tags)
local u3 = require(v1.Shared.Packages.Trove)
local v4 = {
    ["Tag"] = v2.NPCClass
}
local u5 = {}
u5.__index = u5
u5.Tag = v4.Tag
function u5.new(p6) --[[ Line: 17 ]]
    --[[
    Upvalues:
        [1] = u5
        [2] = u3
    --]]
    local v7 = u5
    local u8 = setmetatable({}, v7)
    u8.Model = p6
    u8.Trove = u3.new()
    u8.Initialized = false
    task.spawn(function() --[[ Line: 24 ]]
        --[[
        Upvalues:
            [1] = u8
        --]]
        u8:_init()
    end)
    return u8
end
function u5._init(p9) --[[ Line: 31 ]]
    if p9.Initialized then
        return
    else
        p9.Initialized = true
        local v10 = p9.Trove
        local v11 = p9.Model:WaitForChild("Humanoid"):FindFirstChild("Animator")
        if v11 then
            local v12 = p9.Model:FindFirstChildOfClass("Animation")
            if v12 and v12.AnimationId ~= "" then
                local u13 = v11:LoadAnimation(v12)
                u13.Looped = true
                u13:Play()
                u13.TimePosition = workspace.DistributedGameTime % u13.Length
                v10:Add(function() --[[ Line: 62 ]]
                    --[[
                    Upvalues:
                        [1] = u13
                    --]]
                    u13:Destroy()
                end)
            else
                p9:Destroy()
            end
        else
            p9:Destroy()
            return
        end
    end
end
function u5.Destroy(p14) --[[ Line: 68 ]]
    p14.Trove:Destroy()
end
return u5