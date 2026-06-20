local Parent_upvr = script.Parent
local var2_upvw
local Color3_fromRGB_result1_upvr_2 = Color3.fromRGB(77, 0, 1)
local TweenService_upvr = game:GetService("TweenService")
local Color3_fromRGB_result1_upvr = Color3.fromRGB(39, 0, 1)
Parent_upvr:GetPropertyChangedSignal("Visible"):Connect(function() -- Line 8, Named "OnVisible"
	--[[ Upvalues[5]:
		[1]: var2_upvw (read and write)
		[2]: Parent_upvr (readonly)
		[3]: Color3_fromRGB_result1_upvr_2 (readonly)
		[4]: TweenService_upvr (readonly)
		[5]: Color3_fromRGB_result1_upvr (readonly)
	]]
	if var2_upvw then
		var2_upvw:Cancel()
		var2_upvw = nil
	end
	if not Parent_upvr.Visible then
	else
		Parent_upvr.BackgroundColor3 = Color3_fromRGB_result1_upvr_2
		var2_upvw = TweenService_upvr:Create(Parent_upvr, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			BackgroundColor3 = Color3_fromRGB_result1_upvr;
		})
		var2_upvw:Play()
	end
end)