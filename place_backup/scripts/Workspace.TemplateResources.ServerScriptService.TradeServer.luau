local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create Remote Events folder automatically
local eventsFolder = ReplicatedStorage:FindFirstChild("TradeEvents")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "TradeEvents"
	eventsFolder.Parent = ReplicatedStorage
end

local events = {"SendRequest", "AcceptRequest", "DeclineRequest", "UpdateOffer", "ToggleAction", "CancelTrade", "ClientStateUpdate"}
for _, name in ipairs(events) do
	if not eventsFolder:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = eventsFolder
	end
end

local activeTrades = {}
local tradeRequests = {}

-- Sending & Handling Requests
eventsFolder.SendRequest.OnServerEvent:Connect(function(plr1, plr2)
	if plr1 == plr2 or activeTrades[plr1] or activeTrades[plr2] then return end
	tradeRequests[plr1] = plr2
	eventsFolder.SendRequest:FireClient(plr2, plr1)
end)

eventsFolder.DeclineRequest.OnServerEvent:Connect(function(plr2, plr1)
	if tradeRequests[plr1] == plr2 then
		tradeRequests[plr1] = nil
	end
end)

eventsFolder.AcceptRequest.OnServerEvent:Connect(function(plr2, plr1)
	if tradeRequests[plr1] == plr2 then
		tradeRequests[plr1] = nil
		local session = {
			P1 = plr1, P2 = plr2,
			Offer1 = {}, Offer2 = {}, -- Stores actual Tool Instances
			State = "Selecting",
			P1Ready = false, P2Ready = false,
			P1Confirmed = false, P2Confirmed = false
		}
		activeTrades[plr1] = session
		activeTrades[plr2] = session
		eventsFolder.AcceptRequest:FireClient(plr1, plr2)
		eventsFolder.AcceptRequest:FireClient(plr2, plr1)
	end
end)

-- Managing Offers (Fixed for Duplicate Items)
eventsFolder.UpdateOffer.OnServerEvent:Connect(function(plr, toolInstance, isAdding)
	local session = activeTrades[plr]
	if not session or session.State ~= "Selecting" or not toolInstance then return end 

	local myOffer = (session.P1 == plr) and session.Offer1 or session.Offer2
	local otherPlr = (session.P1 == plr) and session.P2 or session.P1

	if isAdding then
		-- Verify player actually has the tool equipped or in backpack
		if toolInstance.Parent == plr.Backpack or toolInstance.Parent == plr.Character then
			if not table.find(myOffer, toolInstance) then
				table.insert(myOffer, toolInstance)
			end
		end
	else
		local idx = table.find(myOffer, toolInstance)
		if idx then
			table.remove(myOffer, idx)
		end
	end

	-- Send names of items to the other player so they can see the offer
	local displayNames = {}
	for _, t in ipairs(myOffer) do
		if t and t.Parent then table.insert(displayNames, t.Name) end
	end
	eventsFolder.ClientStateUpdate:FireClient(otherPlr, "UpdateTheirOffer", displayNames)

	-- Unready players if the offer changes
	session.P1Ready = false
	session.P2Ready = false
	eventsFolder.ClientStateUpdate:FireClient(session.P1, "ResetReady")
	eventsFolder.ClientStateUpdate:FireClient(session.P2, "ResetReady")
end)

-- Trade Execution & Phases
eventsFolder.ToggleAction.OnServerEvent:Connect(function(plr)
	local session = activeTrades[plr]
	if not session then return end

	local isP1 = (session.P1 == plr)
	local otherPlr = isP1 and session.P2 or session.P1

	if session.State == "Selecting" then
		if isP1 then session.P1Ready = not session.P1Ready else session.P2Ready = not session.P2Ready end
		local myReady = isP1 and session.P1Ready or session.P2Ready

		eventsFolder.ClientStateUpdate:FireClient(plr, "SetMyReady", myReady)
		eventsFolder.ClientStateUpdate:FireClient(otherPlr, "SetTheirReady", myReady)

		if session.P1Ready and session.P2Ready then
			session.State = "Locked"
			eventsFolder.ClientStateUpdate:FireClient(session.P1, "StartCountdown")
			eventsFolder.ClientStateUpdate:FireClient(session.P2, "StartCountdown")

			task.delay(3, function()
				if activeTrades[plr] == session and session.State == "Locked" then
					session.State = "Confirming"
					eventsFolder.ClientStateUpdate:FireClient(session.P1, "UnlockConfirm")
					eventsFolder.ClientStateUpdate:FireClient(session.P2, "UnlockConfirm")
				end
			end)
		end

	elseif session.State == "Confirming" then
		if isP1 then session.P1Confirmed = true else session.P2Confirmed = true end
		eventsFolder.ClientStateUpdate:FireClient(otherPlr, "SetTheirConfirm")

		if session.P1Confirmed and session.P2Confirmed then
			-- Swap Items!
			local function swapItems(sender, receiver, offerList)
				for _, tool in ipairs(offerList) do
					if tool and (tool.Parent == sender.Backpack or tool.Parent == sender.Character) then
						tool.Parent = receiver.Backpack
					end
				end
			end

			swapItems(session.P1, session.P2, session.Offer1)
			swapItems(session.P2, session.P1, session.Offer2)

			eventsFolder.CancelTrade:FireClient(session.P1, true)
			eventsFolder.CancelTrade:FireClient(session.P2, true)
			activeTrades[session.P1] = nil
			activeTrades[session.P2] = nil
		end
	end
end)

eventsFolder.CancelTrade.OnServerEvent:Connect(function(plr)
	local session = activeTrades[plr]
	if session then
		eventsFolder.CancelTrade:FireClient(session.P1, false)
		eventsFolder.CancelTrade:FireClient(session.P2, false)
		activeTrades[session.P1] = nil
		activeTrades[session.P2] = nil
	end
end)