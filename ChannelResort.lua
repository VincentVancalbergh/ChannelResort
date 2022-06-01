local version = GetAddOnMetadata("ChannelResort", "Version") 
print("ChannelResort: " .. version)

local preferred = {}
local autoJoinChannel = 0

--Cache Blizz functions in a seperate object
local wowAPI = {}
wowAPI.UnitName = UnitName
wowAPI.GetRealmName = GetRealmName
wowAPI.GetChannelList = GetChannelList
wowAPI.JoinPermanentChannel = JoinPermanentChannel
wowAPI.SwapChatChannelsByChannelIndex = C_ChatInfo.SwapChatChannelsByChannelIndex
wowAPI.ChangeChatColor = ChangeChatColor

local function dump(o)
	if type(o) == 'table' then
		local s = '{ ';
		local firstValue = true;
		for k,v in pairs(o) do
			if (firstValue == false) then
				s = s .. ', ';
			end
			if type(k) ~= 'number' then
				k = '"'..k..'"';
			end
			s = s ..k..'=' .. dump(v);
			firstValue = false;
		end
		return s .. ' }';
	else
		return tostring(o);
	end
end

local function tablelength(T)
	local count = 0;
	for _ in pairs(T) do
		count = count + 1;
	end
	return count;
end

local function tablemaxkey(T)
	local maxKey = nil
	for k, v in pairs(T) do
		if (type(k) == 'number') then
			if maxKey == nil then
				maxKey = k
			else
				if k > maxKey then
					maxKey = k
				end
			end
		end
	end
	return maxKey;
end

local function tablefindvalue(T, key, value)
	for k, v in pairs(T) do
		if (v[key] == value) then
			return k;
		end
	end
	return nil;
end

local name = wowAPI.UnitName("player")
local realm = wowAPI.GetRealmName()
local realmAndName = realm .. "." .. name

local function GetChatTextColor(chanId)
	local chanName = "CHANNEL" .. chanId;
	local channelInfo = ChatTypeInfo[chanName];
	local chanColor = {
		r = channelInfo.r,
		g = channelInfo.g,
		b = channelInfo.b
	}
	return chanColor;
end

local function GetChannels() -- returns { { ChannelID = { name = CHANNELNAME, color = { r = RED, g = GREEN, b = BLUE }, disabled = CHANNELDISABLED }, ... }
	local channels = {}
	local chanList = { wowAPI.GetChannelList() } -- Returns id1, name1, disabled1, id2, name2, disabled2, ..., the bracers turn it into a table
	for i=1, #chanList, 3 do
		local chanId = chanList[i];
		local chanName = chanList[i+1];
		local chanDisabled = chanList[i+2];
		local chanColor = GetChatTextColor(chanId);
		channels[chanId] = {
			name = chanName,
			color = chanColor,
			disabled = chanDisabled
		};
	end
	return channels
end

local function EvaluateResort()
	local preferredCount = tablelength(preferred);
	if (preferred == nil or preferredCount == 0) then
		print("ChannelResort: No preferences stored");
		return;
	end
	local resortNeeded = false;
	local channels = GetChannels();

	for chanId, preferChanInfo in pairs(preferred) do
		local prefChanName = preferChanInfo.name;
		local chanInfo = channels[chanId];
		if chanInfo == nil then
			resortNeeded = true;
		else
			if chanInfo.name ~= prefChanName then
				resortNeeded = true;
			else
				local chanColor = chanInfo.color;
				local prefColor = preferChanInfo.color;
				if chanColor.r ~= prefColor.r or chanColor.g ~= prefColor.g or chanColor.b ~= prefColor.b then
					resortNeeded = true;
				end
			end
		end
	end

	if resortNeeded then
		print("ChannelResort: Resort needed");
	else
		print("ChannelResort: No Resort needed");
	end
end

local function ResortChannels()
	if (preferred == nil or tablelength(preferred) == 0) then
		print("ChannelResort: No preferences stored");
		return;
	end
	
	local prunedPreferred = { }
	
	-- Prune or join channels that are not joined (yet)
	local channels = GetChannels();
	for chanId, chanInfo in pairs(preferred) do
		local chanName = chanInfo.name;
		local foundChanId = tablefindvalue(channels, "name", chanName);
		if (foundChanId == nil) then
			if (autoJoinChannel == 1) then
				print("Trying to autojoin channel '" .. chanName .. "'");
				wowAPI.JoinPermanentChannel(chanName);
				channels = GetChannels(); -- Refresh the channel list
				foundChanId = tablefindvalue(channels, "name", chanName);
				if foundChanId ~= nil then
					prunedPreferred[chanId] = chanInfo;
				else
					print("Autojoin channel '" .. chanName .. "' failed");
				end
			else
				print("Channel '" .. chanName .. "'' is not joined (and Auto Join is not enabled).");
			end
		else
			prunedPreferred[chanId] = chanInfo;
		end
	end
	
	if (tablelength(prunedPreferred) == 0) then
		print("ChannelResort: No usable preferences stored (fix manually and re-store)");
		return;
	end
	
	-- Sort
	local totalSwapsMade = 0;
	local totalColorChanges = 0;
	for chanId, chanInfo in pairs(prunedPreferred) do
		local chanName = chanInfo.name;
		local chanColor = chanInfo.color;
		local foundChanId = tablefindvalue(channels, "name", chanName);
		if (foundChanId ~= nil and foundChanId ~= chanId) then
			-- Channel found, but wrong id
			print("Moving " .. chanName .. " from " .. foundChanId .. " to " .. chanId);
			wowAPI.SwapChatChannelsByChannelIndex(foundChanId, chanId);
			totalSwapsMade = totalSwapsMade + 1;
			channels = GetChannels(); -- Refresh the channel list
		end
		if (foundChanId ~= nil) then
			local foundChanColor = GetChatTextColor(chanId);
			local changeColor = false;
			if chanColor.r and foundChanColor.r ~= chanColor.r then
				foundChanColor.r = chanColor.r;
				changeColor = true
			end
			if chanColor.g and foundChanColor.g ~= chanColor.g then
				foundChanColor.g = chanColor.g;
				changeColor = true
			end
			if chanColor.b and foundChanColor.b ~= chanColor.b then
				foundChanColor.b = chanColor.b;
				changeColor = true
			end
			if changeColor then
				print("Changing color for " .. chanName);
				wowAPI.ChangeChatColor("CHANNEL"..chanId, foundChanColor.r, foundChanColor.g, foundChanColor.b);
				totalColorChanges = totalColorChanges + 1;
			end
		end
	end
	
	print("ChannelResort: " .. totalSwapsMade .. " swaps, " .. totalColorChanges .. " color changes were made");
end

local function getSetupData()
	preferred = nil
	autoJoinChannel = nil
		
	-- Get the correct preferred channels and AutoJoin option
	local setupMe = ChannelResortData[realmAndName]
	local setupGlobal = ChannelResortData["Global"]
	
	if (setupMe ~= nil) then
		preferred = setupMe.Preferred
		autoJoinChannel = setupMe.AutoJoinChannel
	end
	if (preferred == nil and setupGlobal ~= nil) then
		preferred = setupGlobal.Preferred
	end
	if (autoJoinChannel == nil and setupGlobal ~= nil) then
		autoJoinChannel = setupGlobal.AutoJoinChannel
	end
end

local function printSetupData()
	local preferredStr = "Not Set"
	if (preferred ~= nil and tablelength(preferred) > 0) then
		preferredStr = dump(preferred)
	end
	
	local autoJoinStr = "Not Set"
	if (autoJoinChannel == 0) then
		autoJoinStr = "False"
	end
	if (autoJoinChannel == 1) then
		autoJoinStr = "True"
	end
	
	print("ChannelResort: Preferred Channels = " .. preferredStr .. ", Auto Join Channels = " .. autoJoinStr)
end

local resortFrame = CreateFrame("FRAME", "ChannelResortFrame")
resortFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function eventHandler(self, event, ...)
	-- Initialize the saved variable if empty
	if (ChannelResortData == nil) then
		ChannelResortData = { };
	end
	
	getSetupData();

	if type(preferred[1]) == "string" then
		print("ChannelResort: Migrating data from old format");
		for profile, settings in pairs(ChannelResortData) do
			if settings.Preferred ~= nil then
				ChannelResortData[profile].Preferred = { };
				for chanId, chanName in pairs(settings.Preferred) do
					local chanInfo = {
						name = chanName,
						color = { }
					}
					ChannelResortData[profile].Preferred[chanId] = chanInfo;
				end
			end
		end
		print("ChannelResort: Migration done. Best Re-Store data using /cr [global|me] store");
	end
	
	EvaluateResort();
end

resortFrame:SetScript("OnEvent", eventHandler)

local function printHelp()
	print("Use /channelresort or /cr")
	print("In the below commands: Use Global if you only want to set up once for all characters, Me for character specific, All for all characters")
	print("You can combine Global setup as a default and Me setup as an exception for the current character")
	print("Preferred Channel setup and Auto Join Channel setup has seperate Global/Me handling")
	print("/cr: Do the sort")
	print("/cr help: You're reading it")
	print("/cr [global|me|all] clear: Forget all setup for non-specic, specific or clear all data")
	print("/cr reset = all clear")
	print("/cr [global|me] store: Take your current channel setup and save those as preferred channels")
	print("/cr [global|me] autojoin [toggle|on|off|clear|print(default)]: When sorting Autojoin makes you join channels you haven't joined yet")
	print("/cr print: Print the current setup")
	print("/cr eval: Checks if a Resort is needed. Like printed at login.")
end

SlashCmdList['CHANNELRESORT_SLASHCMD'] = function(msg)
	-- Split msg into parts
    words = {}
	for word in msg:gmatch("%w+") do table.insert(words, word) end
	
	-- No arguments = do the sort
	if (#words == 0) then
		ResortChannels()
		return
	end
	
	-- help
	if (words[1]:lower() == "help") then
		printHelp()
		return
	end
	
	-- print: Print the current setup
	if (words[1]:lower() == "print") then
		printSetupData()
		return
	end

	-- eval: Checks if a Resort is needed. Like printed at login.
	if (words[1]:lower() == "eval") then
		EvaluateResort();
		return;
	end
	
	-- reset
	if (words[1]:lower() == "reset") then
		words[1] = "all"
		words[2] = "clear"
	end
	
	if (#words > 1) then
		local target = words[1]:lower()
		local command = words[2]:lower()
		
		local targetName = nil
		if (target == "global") then
			targetName = "Global"
		end
		if (target == "me") then
			targetName = realmAndName
		end
		
		-- [global|me|all] clear: Forget all setup for non-specic, specific or clear all data
		if (command == "clear") then
			if (target == "global") then
				ChannelResortData[targetName] = nil
				getSetupData()
				print("ChannelResort: Cleared all data for global")
				return
			end
			if (target == "me") then
				ChannelResortData[targetName] = nil
				getSetupData()
				print("ChannelResort: Cleared all data specific for the current player")
				return
			end
			if (target == "all") then
				ChannelResortData = {}
				getSetupData()
				print("ChannelResort: Cleared all data (global as well as all players)")
				return
			end
			print("ChannelResort: '", words[1], "'' is not a valid target for the clear command. Try /cr help")
		end
	
		-- [global|me] store: Take your current channel setup and save those as preferred channels
		if (command == "store") then
			if (targetName ~= nil) then
				if (ChannelResortData[targetName] == nil) then
					ChannelResortData[targetName] = { }
				end
				ChannelResortData[targetName].Preferred = GetChannels()
				getSetupData()
				printSetupData()
				return
			end
			print("ChannelResort: '" .. words[1] .. "'' is not a valid target for the store command. Try /cr help")
		end
		
		-- [global|me] autojoin [toggle|on|off|clear|print(default)]: Autojoin makes you join channels you haven't join yet when sorting
		if (command == "autojoin") then
			local option = "print"
			if (#words > 2) then
				option = words[3]:lower()
			end
			
			if (targetName ~= nil) then
				local autoJoinStr = "not set"
				local autoJoinVal = nil
				if (ChannelResortData[targetName] ~= nil) then
					autoJoinVal = ChannelResortData[targetName].AutoJoinChannel	
				end
				if (autoJoinVal == 1) then
					autoJoinStr = "True"
				end
				if (autoJoinVal == 0) then
					autoJoinStr = "False"
				end
				if (option == "print") then
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' is '" .. autoJoinStr .. "'")
					return
				end
				if (option == "toggle") then
					if (ChannelResortData[targetName] == nil) then
						ChannelResortData[targetName] = {}
					end
					local newAutoJoinStr = "not set"
					if (autoJoinVal == 1) then
						ChannelResortData[targetName].AutoJoinChannel = 0
						newAutoJoinStr = "False"
					else
						ChannelResortData[targetName].AutoJoinChannel = 1
						newAutoJoinStr = "True"
					end
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' was changed from '" .. autoJoinStr .. "' to '" .. newAutoJoinStr .. "'")
					getSetupData()
					return
				end
				if (option == "on") then
					if (ChannelResortData[targetName] == nil) then
						ChannelResortData[targetName] = {}
					end
					ChannelResortData[targetName].AutoJoinChannel = 1
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' is now 'True'")
					getSetupData()
					return
				end
				if (option == "off") then
					if (ChannelResortData[targetName] == nil) then
						ChannelResortData[targetName] = {}
					end
					ChannelResortData[targetName].AutoJoinChannel = 0
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' is now 'False'")
					getSetupData()
					return
				end
				if (option == "clear") then
					if (ChannelResortData[targetName] == nil) then
						ChannelResortData[targetName] = {}
					end
					ChannelResortData[targetName].AutoJoinChannel = nil
					print("The AutoJoin option for '" .. targetName .. "' is now 'not set'")
					getSetupData()
					return
				end
				print("ChannelResort: '" .. words[3] .. "'' is not a valid option for the autojoin command. Try /cr help")
			else
				print("ChannelResort: '" .. words[1] .. "'' is not a valid target for the autojoin command. Try /cr help")
			end
		end
	end
	
	print("ChannelResort: Can't recognize '" .. msg .. "'. Try /cr help")
end

SLASH_CHANNELRESORT_SLASHCMD1 = '/channelresort'
SLASH_CHANNELRESORT_SLASHCMD2 = '/cr'