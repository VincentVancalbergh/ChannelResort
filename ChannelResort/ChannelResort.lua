local version = GetAddOnMetadata("ChannelResort", "Version") 
print("ChannelResort: " .. version)

local CurrentProfile = {
	Preferred = { },
	AutoJoinChannel = 0
};

--Cache Blizz functions in a seperate object
local wowAPI = {}
wowAPI.UnitName = UnitName;
wowAPI.GetRealmName = GetRealmName;
wowAPI.GetChannelList = GetChannelList;
wowAPI.JoinPermanentChannel = JoinPermanentChannel;
wowAPI.SwapChatChannelsByChannelIndex = C_ChatInfo.SwapChatChannelsByChannelIndex;
wowAPI.ChangeChatColor = ChangeChatColor;
wowAPI.GetAddOnInfo = GetAddOnInfo;
wowAPI.GetAddOnMetadata = GetAddOnMetadata;

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

local function tableminkey(T)
	local minKey = nil
	for k, v in pairs(T) do
		if (type(k) == 'number') then
			if minKey == nil then
				minKey = k
			else
				if k < minKey then
					minKey = k
				end
			end
		end
	end
	return minKey;
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
	if (CurrentProfile.Preferred == nil or tablelength(CurrentProfile.Preferred) == 0) then
		print("ChannelResort: No preferences stored");
		return;
	end
	local resortNeeded = false;
	local channels = GetChannels();

	for chanId, preferChanInfo in pairs(CurrentProfile.Preferred) do
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
	if (CurrentProfile.Preferred == nil or tablelength(CurrentProfile.Preferred) == 0) then
		print("ChannelResort: No preferences stored");
		return;
	end
	
	local prunedPreferred = { }
	
	-- Prune or join channels that are not joined (yet)
	local channels = GetChannels();
	for chanId, chanInfo in pairs(CurrentProfile.Preferred) do
		local chanName = chanInfo.name;
		local foundChanId = tablefindvalue(channels, "name", chanName);
		if (foundChanId == nil) then
			if (CurrentProfile.AutoJoinChannel == 1) then
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

local function resetSetupData()
	local addonVersion = GetAddOnMetadata("ChannelResort", "Version");
	ChannelResortData = {
		Version = addonVersion,
		Profiles = { }
	};
end

local function resetProfile(profileName)
	ChannelResortData.Profiles[profileName] = nil;
end

local function getProfile(profileName)
	return ChannelResortData.Profiles[profileName];
end

local function updateProfile(profileName, profile)
	ChannelResortData.Profiles[profileName] = profile;
	return profile;
end

local function initAndGetProfile(profileName)
	local profile = getProfile(profileName);
	if profile == nil then
		profile = { };
		updateProfile(profileName, profile);
	end
	return profile;
end

local function getSetupData()
	CurrentProfile.Preferred = nil
	CurrentProfile.AutoJoinChannel = nil
		
	-- Get the correct preferred channels and AutoJoin option
	local setupMe = getProfile(realmAndName);
	local setupGlobal = getProfile("Global");
	
	if (setupMe ~= nil) then
		CurrentProfile.Preferred = setupMe.Preferred
		CurrentProfile.AutoJoinChannel = setupMe.AutoJoinChannel
	end
	if (CurrentProfile.Preferred == nil and setupGlobal ~= nil) then
		CurrentProfile.Preferred = setupGlobal.Preferred
	end
	if (CurrentProfile.AutoJoinChannel == nil and setupGlobal ~= nil) then
		CurrentProfile.AutoJoinChannel = setupGlobal.AutoJoinChannel
	end
end

local function printSetupData()
	local preferredStr = "Not Set"
	if (CurrentProfile.Preferred ~= nil and tablelength(CurrentProfile.Preferred) > 0) then
		preferredStr = dump(CurrentProfile.Preferred)
	end
	
	local autoJoinStr = "Not Set"
	if (CurrentProfile.AutoJoinChannel == 0) then
		autoJoinStr = "False"
	end
	if (CurrentProfile.AutoJoinChannel == 1) then
		autoJoinStr = "True"
	end
	
	print("ChannelResort: Preferred Channels = " .. preferredStr .. ", Auto Join Channels = " .. autoJoinStr)
end

local function migrateSetupData()
	-- Migrate data if needed
	local migrationDone = false;
	local addonVersion = GetAddOnMetadata("ChannelResort", "Version");
	local currentVersion = ChannelResortData.Version;

	if currentVersion == nil and ChannelResortData.Profiles == nil then
		-- no version number stored, so we try to detect the structure first
		
		-- v0.0.1, v0.0.2 and v0.0.3: ChannelResortData held the profiles directly
		local firstProfileWithPreferences = nil;
		for profileName, profile in pairs(ChannelResortData) do
			local maybePreferred = profile.Preferred;
			if maybePreferred ~= nil and tablelength(maybePreferred) > 0 then
				firstProfileWithPreferences = profile;
			end
		end
		if firstProfileWithPreferences == nil then
			-- No data -> Screw it, reset it
			resetSetupData();
			currentVersion = ChannelResortData.Version;
		else
			local firstChannelId = tableminkey(firstProfileWithPreferences);
			local firstChannelData = firstProfileWithPreferences[firstChannelId];
			if firstChannelData ~= nil then
				if type(firstChannelData) == "string" then
					currentVersion = "0.0.1";
				end
				if type(firstChannelData) == "table" then
					currentVersion = "0.0.2";
				end
			end
		end
	end
	if currentVersion == addonVersion then
		return;
	end

	if currentVersion == "0.0.1" then
		-- v0.0.1 ChannelResortData held the profiles directly and profile.Preferred was an <int, string> Dictionairy, no colour info
		print("ChannelResort: Migrating data from v0.0.1 to v0.0.2");
		for profileName, settings in pairs(ChannelResortData) do
			if settings.Preferred ~= nil then
				ChannelResortData[profileName].Preferred = { };
				for chanId, chanName in pairs(settings.Preferred) do
					local chanInfo = {
						name = chanName,
						color = { }
					}
					ChannelResortData[profileName].Preferred[chanId] = chanInfo;
				end
			end
		end
		currentVersion = "0.0.2";
		migrationDone = true;
	end
	if currentVersion == "0.0.2" or currentVersion == "0.0.3" then
		-- v0.0.2 & 0.0.3 ChannelResortData held the profiles directly and profile.Preferred was an <int, table> Dictionairy, with colour info
		print("ChannelResort: Migrating data from v0.0.2 to v0.0.4");
		local profiles = ChannelResortData;
		ChannelResortData = {
			Version = "0.0.4",
			Profiles = profiles
		};
		currentVersion = ChannelResortData.Version;
		migrationDone = true;
	end
	--This is for versions > 0.0.4
	--if currentVersion == "0.0.4" then
	--	-- v0.0.4 ChannelResortData has Version and holds the profiles in the Profiles property
	--	print("ChannelResort: Migrating data from v" .. currentVersion .. " to v" .. addonVersion);
	--	-- No change to the structure needed, so just up the version number
	--	ChannelResortData.Version = addonVersion;
	--	migrationDone = true;
	--end
	if migrationDone then
		print("ChannelResort: Migration done. Best Re-Store data using /cr [global|me] store");
	end
end

local function eventHandler(self, event, ...)
	-- Initialize the saved variable if empty
	if (ChannelResortData == nil) then
		resetSetupData();
	end
	migrateSetupData();
	getSetupData();
	EvaluateResort();
end

local resortFrame = CreateFrame("FRAME", "ChannelResortFrame")
resortFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
				resetProfile(targetName);
				getSetupData()
				print("ChannelResort: Cleared all data for global")
				return
			end
			if (target == "me") then
				resetProfile(targetName);
				getSetupData()
				print("ChannelResort: Cleared all data specific for the current player")
				return
			end
			if (target == "all") then
				resetSetupData();
				getSetupData();
				print("ChannelResort: Cleared all data (global as well as all players)")
				return
			end
			print("ChannelResort: '", words[1], "'' is not a valid target for the clear command. Try /cr help")
		end
	
		-- [global|me] store: Take your current channel setup and save those as preferred channels
		if (command == "store") then
			if (targetName ~= nil) then
				local profile = initAndGetProfile(targetName);
				profile.Preferred = GetChannels()
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
				local profile = getProfile(targetName);
				if (profile ~= nil) then
					autoJoinVal = profile.AutoJoinChannel;
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
					profile = initAndGetProfile(targetName);
					local newAutoJoinStr = "not set"
					if (autoJoinVal == 1) then
						profile.AutoJoinChannel = 0
						newAutoJoinStr = "False"
					else
						profile.AutoJoinChannel = 1
						newAutoJoinStr = "True"
					end
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' was changed from '" .. autoJoinStr .. "' to '" .. newAutoJoinStr .. "'")
					getSetupData()
					return
				end
				if (option == "on") then
					profile = initAndGetProfile(targetName);
					profile.AutoJoinChannel = 1
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' is now 'True'")
					getSetupData()
					return
				end
				if (option == "off") then
					profile = initAndGetProfile(targetName);
					profile.AutoJoinChannel = 0
					print("ChannelResort: The AutoJoin option for '" .. targetName .. "' is now 'False'")
					getSetupData()
					return
				end
				if (option == "clear") then
					profile = initAndGetProfile(targetName);
					profile.AutoJoinChannel = nil
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