local messaging_service = game:GetService("MessagingService")
local replicated_storage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local remotes = replicated_storage.Remotes
local display_remote = remotes.DisplayGlobalAnnouncement
local send_remote = remotes.SendGlobalAnnouncement

local gui = script.GlobalAnnouncements

local ALLOWED_IDS = {7417559307} --Change to your user id
local PREFIX = "/global"
local READ_SPEED = 3
local MIN_DURATION = 5
local TOPIC = "GlobalAnnouncement"
local NAME_FONT_COLOR = {255, 70, 73}
local VERIFIED_ICON = utf8.char(0xE000)

function format_announcement(player, announcement)
	local name = player.DisplayName
	local formatted_announcement = 
		"<font color='rgb(" ..
		NAME_FONT_COLOR[1] .. "," ..
		NAME_FONT_COLOR[2] .. "," ..
		NAME_FONT_COLOR[3] .. ")'>" ..
		name .. "</font>" .. VERIFIED_ICON .. " : " .. announcement
	return formatted_announcement
end

function send_announcement(player, announcement, duration)
	announcement = format_announcement(player, announcement)
	messaging_service:PublishAsync(
		TOPIC,
		{announcement, duration}
	)
end

function get_duration(duration, announcement)
	
	duration = tonumber(duration)
	if not duration then
		duration = math.max(
			string.len(announcement) / READ_SPEED, 
			MIN_DURATION
		)
	end
	return duration
end

function player_added(player)
	if not table.find(ALLOWED_IDS, player.UserId) then
		return
	end
	
	player.Chatted:Connect(function(chat_message)
		
		local args = string.split(chat_message, " ")
		local command = string.lower(args[1])
		if command ~= PREFIX then
			return
		end
		
		local duration = tonumber(args[2])
		local message_start = 3
		if not duration then
			message_start = 2
		end
		
		local message = ""
		for i = message_start, #args do
			message ..= args[i]
			if i ~= #args then
				message ..= " "
			end
		end
		
		duration = get_duration(duration, message)
		send_announcement(player, message, duration)
	end)
	
	local player_gui = player.PlayerGui
	gui:Clone().Parent = player_gui
	
	player.characterAdded:Connect(function()
		gui:Clone().Parent = player_gui
	end)
end

for _, player in players:GetPlayers() do
	player_added(player)
end

players.PlayerAdded:Connect(player_added)

messaging_service:SubscribeAsync(TOPIC, function(message)
	
	local data = message.Data
	local announcement = data[1]
	local duration = data[2]
	
	display_remote:FireAllClients(announcement, duration)
end)

send_remote.OnServerEvent:Connect(function(player, announcement, duration)
	if not table.find(ALLOWED_IDS, player.UserId) then
		return
	end
	
	duration = get_duration(duration, announcement)
	send_announcement(player, announcement, duration)
end)