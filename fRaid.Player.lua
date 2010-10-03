-- vim: set softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
--
-- Author      : Jessica Chen Huang
-- Create Date : 2/13/2009 10:43 AM

--Goals:
--  Keeps track of players, their dkp, and other useful data
--  Syncable between users running this mod
--  Audit trail of activity

--Data Structures:
--  PlayerList - table, key = playername, value = player data
--  ChangeList - table, key = playername, value = list of changes
--    this list maintains the audit trail of changes to the PlayerList
--    when syncing...

--for reference
--fRaid.db.global.Player.PlayerList {name => {dkp, attendance}
--fRaid.db.global.Player.ChangeList {myname => {idx => {name, action, note, timestamp, oldvalue, newvalue}}}
--  possible actions: new, delete, dkp, blacklisted, unblacklisted
--fRaid.db.global.Player.Count
--fRaid.db.global.Player.LastModified
--fRaid.db.global.Player.AttendanceTotal
--fRaid.GUI2.PlayerFrame

fRaid.Player = {}

local LIST = {} --table to hold functions
fRaid.Player.LIST = LIST

function fRaid.Player.OnInitialize()
    if not fRaid.db.global.Player.ChangeList[UnitName('player')] then
        fRaid.db.global.Player.ChangeList[UnitName('player')] = {}
    end
end

--===================================================================================
local rank1 = 'Raider'
local rank2 = 'Member'

--private functions used by LIST functions
local function createplayerobj()
    local obj = {
	    dkp = 0,
	    attendance = 0,
	    class = '',
	    rank = '',
	    attflag = '', --high or low
    }
    
    return obj
end

--===================================================================================
--Functions that access PlayerList
--USE ONLY THESE FUNCTIONS TO ACCESS PLAYERLIST--

function LIST.Count(recount)
    if not recount then
        return fRaid.db.global.Player.Count
    else
        --recount
        local count = 0
        for name, data in pairs(fRaid.db.global.Player.PlayerList) do
            count = count + 1
        end
        --update count
        fRaid.db.global.Player.Count = count
        
        --return
        return fRaid.db.global.Player.Count
    end
end

--returns a copy of playerobj
function LIST.GetPlayer(name, createnew)
    if not name or name == '' then
        return nil
    end
    
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))

    local obj = fRaid.db.global.Player.PlayerList[name]
    if createnew and not obj then
        obj = createplayerobj()
        fRaid.db.global.Player.PlayerList[name] = obj --add player
        
        local rosterdata = fLib.Guild.GetInfo(name)
        if rosterdata then
	        obj.rank = rosterdata.rank
	        obj.class = rosterdata.class
        end
        
        fRaid.db.global.Player.Count = fRaid.db.global.Player.Count + 1
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'new', '', fRaid.db.global.Player.LastModified})
        
        fRaid:Print('Added new player ' .. name)
    end
    
    --make copy
    local objcopy = nil
    if obj then
    	objcopy = {}
	    for key,val in pairs(obj) do
	        objcopy[key] = val
	    end
    end
    
    return objcopy
end

--removes the player
function LIST.DeletePlayer(name, note)
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))
    
    local obj = fRaid.db.global.Player.PlayerList[name]
    if obj then
        --zero dkp
        LIST.SetDkp(name, 0, 'delete')
        
        --delete
        fRaid.db.global.Player.PlayerList[name] = nil
        fRaid.db.global.Player.Count = fRaid.db.global.Player.Count - 1
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'delete', note, fRaid.db.global.Player.LastModified, obj})
    end
end

--set the player's dkp
function LIST.SetDkp(name, dkp, note)
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))
    
    local obj = fRaid.db.global.Player.PlayerList[name]
    if obj and obj.dkp ~= dkp then
        local olddkp = obj.dkp
        obj.dkp = dkp
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'dkp', note, fRaid.db.global.Player.LastModified, olddkp, obj.dkp})
    end
end

function LIST.Blacklist(name, reason)
	--make sure name is formatted correctly
	name = fRaid:Capitalize(strlower(strtrim(name)))
	
	local obj = fRaid.db.global.Player.PlayerList[name]
	if obj then
		obj.blacklisted = true
		fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
		
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'blacklisted', reason, fRaid.db.global.Player.LastModified})
	end
end

function LIST.UnBlacklist(name)
	--make sure name is formatted correctly
	name = fRaid:Capitalize(strlower(strtrim(name)))
	
	local obj = fRaid.db.global.Player.PlayerList[name]
	if obj then
		obj.blacklisted = nil
		fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
		
		--audit
		tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'unblacklisted', '', fRaid.db.global.Player.LastModified})
	end
end


--recalculates all player's dkp based on all the events logged in the ChangeList
function LIST.RecalculateDkp()
	local nametodkp, latesttimestamp = LIST.CalculateDkp()
	
	local newdkp
	for name, obj in pairs(fRaid.db.global.Player.PlayerList) do
		newdkp = nametodkp[name]
		if not newdkp then
			if obj.dkp ~= 0 then
				fRaid:Print("Discrepancy: " .. name .. " current dkp = " .. obj.dkp .. ", calculated dkp = 0")
				obj.dkp = 0
			end
		elseif newdkp ~= obj.dkp then
			fRaid:Print("Discrepancy: " .. name .. " current dkp = " .. obj.dkp .. ", calculated dkp = " .. newdkp)
			obj.dkp = newdkp
		end
		nametodkp[name] = nil
	end
	for name, dkp in pairs(nametodkp) do
		fRaid:Print("Missing: " .. name .. " calculated dkp = " .. dkp)
		local obj = createplayerobj()
		obj.dkp = dkp
		fRaid.db.global.Player.PlayerList[name] = obj
	end
	fRaid.db.global.Player.LastModified = latesttimestamp
    
    fRaid:Print('Recalculate Dkp Complete.')
end

function LIST.RecalculateDkpTest()
	local nametodkp = LIST.CalculateDkp()
	
	local newdkp
	for name, obj in pairs(fRaid.db.global.Player.PlayerList) do
		newdkp = nametodkp[name]
		if not newdkp then
			if obj.dkp ~= 0 then
				fRaid:Print("Discrepancy: " .. name .. " current dkp = " .. obj.dkp .. ", calculated dkp = 0")
			end
		elseif newdkp ~= obj.dkp then
			fRaid:Print("Discrepancy: " .. name .. " current dkp = " .. obj.dkp .. ", calculated dkp = " .. newdkp)
		end
		nametodkp[name] = nil
	end
	for name, dkp in pairs(nametodkp) do
		fRaid:Print("Missing: " .. name .. " calculated dkp = " .. dkp)
	end
	
	fRaid:Print('Recalculate Dkp Test Complete.')
end

--calculates player's dkp at capdate
--player's with 0 dkp are omitted
--returns table nametodkp and latesttimestamp
function LIST.CalculateDkp(capdate)
	if not capdate then
		capdate = fLib.GetTimestamp()
	end
	
	local nametodkp = {}
	local latesttimestamp = '-1'
	local name, dkp, diff
	for user, changelist in pairs(fRaid.db.global.Player.ChangeList) do
		for idx, change in ipairs(changelist) do
			if change[4] <= capdate then
				if change[2] == 'dkp' then
					name = change[1]
					dkp = nametodkp[name]
					if not dkp then
						dkp = 0
					end
					diff = change[6] - change[5]
					nametodkp[name] = dkp + diff
					
					if change[4] > latesttimestamp then
						latesttimestamp = change[4]
					end
				end
			end
		end
	end
		
	--erase the names that have 0 dkp
	for name, dkp in pairs(nametodkp) do
		if dkp == 0 then
		nametodkp[name] = nil
		end
	end
	
	return nametodkp, latesttimestamp
end

--removes 'dkp' entries in the changelist older than 40 days
--updates Purge Data: purge date cap and purge start entries
function LIST.Purge()
	--calculate the purge date cap
	local obj = fLib.GetTimestampObj()
	obj = fLib.AddDays(obj, -40)
	local purgedatecap = fLib.GetTimestamp(obj)
	
	--create new purge start entries
	local nametodkp = LIST.CalculateDkp(purgedatecap)
	local newpurgestartentries = {}
	for name, dkp in pairs(nametodkp) do
		tinsert(newpurgestartentries, {name, 'dkp', 'purgestart', purgedatecap, 0, dkp})
	end
	
	--remove old changelist entries
	local entry
	for user, changelist in pairs(fRaid.db.global.Player.ChangeList) do
		if user ~= '*Purge' then
			fRaid:Print("Purging " .. user .. "'s changelist...")
			local count = 0
			local i = 1
			while i ~= 0 do
				entry = changelist[i]
				if entry then
					if entry[4] <= purgedatecap and entry[2] == 'dkp' then
						tremove(changelist, i)
						count = count + 1
					else
						i = i + 1
					end
				else
					i = 0
				end
			end
			fRaid:Print(count .. " entries purged.")
		end
	end

	--replace old purge start entries
	fRaid.db.global.Player.ChangeList["*Purge"] = newpurgestartentries
	
	--save purge date cap
	fRaid.db.global.Player.ChangeList["*Purge"].datecap = purgedatecap
	
	fRaid:Print("Purge complete.  Verifying the new DKP matches up.")
	LIST.RecalculateDkpTest()
end

function LIST.RefreshGuildInfo()
	local gdata
	for name, data in pairs(fRaid.db.global.Player.PlayerList) do
		gdata = fLib.Guild.GetInfo(name)
		if gdata then
			data.rank = gdata.rank
		else
			data.rank = ''
		end
	end
end

--===========================================================================================

function fRaid.Player.DeletePlayer(name)
    fRaid:ConfirmDialog2('Are you sure you want to remove ' .. name .. '?', fRaid.Player.DeletePlayerHandler, name)
end
function fRaid.Player.DeletePlayerHandler(name)
    LIST.DeletePlayer(name)
    fRaid:Print('Deleted ' .. name)
    fRaid.GUI2.PlayerFrame:Refresh()
end

--Add dkp to a player
--amount can be a positive or negative value
function fRaid.Player.AddDkp(name, amount, note)
    --check args
    if not name or name == '' then
        fRaid:Print("ERROR: missing arg1 name")
        return
    end
    if not amount then
        fRaid:Print("ERROR: missing arg2 amount")
        return
    end
    if type(amount) ~= 'number' then
        fRaid:Print("ERROR: bad type arg2 needs to be a number")
        return
    end
    
    --retrive a player info
    local objcopy = LIST.GetPlayer(name, true)

    --check if blacklisted
    if objcopy.blacklisted then
    	fRaid:Print('ERROR: ' .. name .. ' is blacklisted.')
    	return
    end

    --calculate new amount
    local newamount = objcopy.dkp + amount
    
    --dkp cap
    if type(fRaid.db.global.cap) == 'string' then
    	fRaid.db.global.cap = tonumber(fRaid.db.global.cap)
    end
    if fRaid.db.global.cap > 0 then
        if newamount > fRaid.db.global.cap then
            newamount = fRaid.db.global.cap
        end
    end
    
    --save new amount
    LIST.SetDkp(name, newamount, note)
    
    local objcopy2 = LIST.GetPlayer(name)
    local msg = name .. ' - Prev Dkp: ' .. objcopy.dkp .. ',Amt: ' .. amount .. ',New Dkp:' .. objcopy2.dkp

    fRaid:Print('UPDATE: ' .. msg)
    --fRaid:Whisper(name, msg)
    fRaid.Whisper2(msg, name)
end



--mainlist and halflist should be a list of names
function fRaid.Player.AddDkpToPlayers(amount, note, mainlist, halflist)
	if not amount then
		fRaid:Print('ERROR: missing arg1 amount')
		return
	end
	if type(amount) ~= 'number' then
		fRaid:Print("ERROR: bad type arg1 needs to be a number")
		return
	end

	for idx,name in ipairs(mainlist) do
		fRaid.Player.AddDkp(name, amount, note)
	end
	
	for idx,name in ipairs(halflist) do
		fRaid.Player.AddDkp(name, amount/2, note)
	end
end

function fRaid.Player.CalculateDkpDecay(dkp, attendancepercent)
--addy
end

function fRaid.Player.GetRank(name)
	local playerobj = LIST.GetPlayer(name)
	if playerobj and playerobj.rank and playerobj.rank ~= "" then
		return playerobj.rank
	end
	return ""
end

function fRaid.Player.GetAttendanceFlag(name)
	local playerobj = LIST.GetPlayer(name)
	if playerobj and playerobj.attflag and playerobj.attflag ~= "" then
		return playerobj.attflag
	end
	return ""
end

--returns the date of the last raid attended how many raids ago that was
--i.e. 09/10/02 05:55:00, 10 would be the date of the last raid attended
--and that raid was 10 raids ago 
function fRaid.Player.LastRaidAttended(name)
	name = fRaid:Capitalize(strlower(strtrim(name)))

	--First, let's collect the last 60 raids
	local temp = fRaid.Raid.GetSortedRaidList()
	
	--Now let's go thru the raids from the back
	--to find the first one they were in
	for i = #temp, 1, -1 do
		local data = temp[i]
		local owner = data[1]
		local idx = data[2]
		
		local raiddata = fRaid.db.global.Raid.RaidList[owner][idx]
		local oRaid = fRaid.Raid.raidobj.new()
		oRaid:Load(raiddata)
		
		if oRaid:Present(name) then
			return raiddata.StartTime, #temp - i
		end
	end
end

--updates each player's guild rank if they are in the guild
--otherwise they will have no rank
function fRaid.Player.UpdateRank()
	--Erase rank then try to get from fLib.Guild
	local ginfo
	for playername, obj in pairs(fRaid.db.global.Player.PlayerList) do
		obj.rank = ""
		
		ginfo = fLib.Guild.GetInfo(playername)
		if ginfo and ginfo.rank then
			obj.rank = ginfo.rank
		end
	end
	
	fRaid:Print("Update rank complete.")
end

--updates each player's class if they are in the guild
function fRaid.Player.UpdateClass()
	--try to get class from fLib.Guild
	local ginfo
	for playername, obj in pairs(fRaid.db.global.Player.PlayerList) do
		ginfo = fLib.Guild.GetInfo(playername)
		if ginfo and ginfo.class then
			obj.class = ginfo.class
		end
	end
end


--[[
removed...
--promote or demotes players based on their raid attendance
function fRaid.Player.UpdateRankByAttendance()
	--Scan thru each guild member and update their rank based on attendance
	local playerobj, percent
	for name, info in pairs(fLib.Guild.Roster) do
		--retrieve data to calculate percent attendance
		playerobj = fRaid.db.global.Player.PlayerList[name]
		if playerobj then
			percent = fRaid.Player.GetAttendancePercent(name)
		else
			percent = 0
		end
		
		--if < 75% demote only if they are Raider
		--if >= 75% promote only if they are Member
		if percent < 75 and info.rank == "Raider" then
			--demote them
			--fRaid:Print(name .. " queued for demotion.")
			--fLib.Guild.Demote(name)
		elseif percent >= 75 and info.rank == "Member" then
			--promote them
			--fRaid:Print(name .. " queued for promotion.")
			--fLib.Guild.Promote(name)
		end
	end
	
	fLib.Guild.ConfirmMotions(fRaid.Player.UpdateRankByAttendanceComplete)
end
function fRaid.Player.UpdateRankByAttendanceComplete()
	fRaid:Print("Update guild ranks by attendance complete.")
	fRaid.Player.UpdateRank()
end
--]]





function fRaid.Player.SetAttendanceTotal(numraids)
	if not numraids or numraids <= 0 then
		fRaid:Print("Invalid number of raids specified for Attendance Total.")
		return
	end
	
	fRaid.db.global.Player.AttendanceTotal = numraids
end

--updates each player's attendance based on the last numraids
function fRaid.Player.UpdateAttendance()
	local numraids = fRaid.db.global.Player.AttendanceTotal
	
	fRaid:Print("Updating attendance over "..numraids.." raids")
	
	--First, let's collect the last numraids raids
	local temp = fRaid.Raid.GetSortedRaidList(numraids)
	
	--Now, let's zero everyone's attendance
	for playername, playerobj in pairs(fRaid.db.global.Player.PlayerList) do
		playerobj.attendance = 0
	end
	
	--Now, let's go thru each raid and add up their attendance
	local totalraidcount = 0
	for idx, data in pairs(temp) do
		totalraidcount = totalraidcount + 1
		local owner = data[1]
		local idx = data[2]
		local raiddata = fRaid.db.global.Raid.RaidList[owner][idx]
		local oRaid = fRaid.Raid.raidobj.new()
		oRaid:Load(raiddata)
		
		for name, oRaider in pairs(oRaid.Data.RaiderList) do
			if oRaid:Present(name) then
				local playerobj = fRaid.db.global.Player.PlayerList[name]
				if playerobj then
					playerobj.attendance = playerobj.attendance + 1
				end
			end
		end
	end
	fRaid.db.global.Player.AttendanceTotal = totalraidcount

	fRaid:Print(totalraidcount, " raids scanned")
end

--updates the attendance flag based on player.attendance
function fRaid.Player.UpdateFlagByAttendance()
	--Update their attflag
	local percent = 0
	for playername, playerobj in pairs(fRaid.db.global.Player.PlayerList) do
		if not playerobj.attflag or playerobj.attflag == "" then
			playerobj.attflag = "high"
		end
			
		percent = fRaid.Player.CalculatePercent(playerobj.attendance)
		if playerobj.attflag == "high" and percent < 50 then
			playerobj.attflag = "low"
		elseif playerobj.attflag == "low" and percent >= 75 then
			playerobj.attflag = "high"
		end
	end
	fRaid:Print("Update flags by attendance complete.")
end

function fRaid.Player.TakeAttendanceFlagSnapshot(time)
	if not time then
		fRaid:Print("TakeAttendanceFlagSnapshot(time) missing parameter time.")
		return
	end
	--AttendanceFlagSnapshots = {}, --list of afsnapshots: {snapshotdate, snapshot}; snapshot maps playername to
	if #fRaid.db.global.Player.AttendanceFlagSnapshots == 0 then
		--only happens the very very first time
		local snapshot = {}
		snapshot.Time = time
		snapshot.Data = {}
		for name, _ in pairs(fRaid.db.global.Player.PlayerList) do
			--everyone starts out high
			snapshot.Data[name] = "high"
		end
	
		tinsert(fRaid.db.global.Player.AttendanceFlagSnapshots, snapshot)
	else
		--calculate from last snapshot up to date
		--save flags at date
	end
end



--calculates attendance over numraids
--limits calculation to guildees of a certain rank
function fRaid.Player.UpdateTempAttendance(numraids, rank)
	if not numraids or numraids <= 0 then
		fRaid:Print("numraids required > 0")
		return
	end
	
	fRaid:Print("Updating temp attendance over " .. numraids .. " raids")
	
	--First, let's collect the last numraids raids
	local temp = fRaid.Raid.GetSortedRaidList(numraids)
	
	--create TempAttendance list
	--will eventually map name -> attendance%
	fRaid.Player.TempAttendance = {}
	
	--fill with guildees of a certain rank
	for name, data in pairs(fRaid.db.global.Player.PlayerList) do
		if rank then
			if data.rank == rank then
				fRaid.Player.TempAttendance[name] = 0
			end
		else
			fRaid.Player.TempAttendance[name] = 0
		end
	end
	
	--Now, let's go thru each raid and add up their attendance
	local totalraidcount = 0
	for idx, data in pairs(temp) do
		totalraidcount = totalraidcount + 1
		local owner = data[1]
		local idx = data[2]
		local raiddata = fRaid.db.global.Raid.RaidList[owner][idx]
		local oRaid = fRaid.Raid.raidobj.new()
		oRaid:Load(raiddata)
		
		for name, oRaider in pairs(oRaid.Data.RaiderList) do
			if oRaid:Present(name) then
				if fRaid.Player.TempAttendance[name] then
					fRaid.Player.TempAttendance[name] = fRaid.Player.TempAttendance[name] + 1
				end
			end
		end
	end
	
	fRaid.Player.TempAttendanceCount = totalraidcount
	fRaid.Player.TempAttendanceRank = rank
	for name, num in pairs(fRaid.Player.TempAttendance) do
		fRaid.Player.TempAttendance[name] = floor(num / totalraidcount * 100)
	end

	fRaid:Print(totalraidcount .. " raids scanned")
end

function fRaid.Player.PrintTempAttendance(channel)
	if not fRaid.Player.TempAttendanceCount or fRaid.Player.TempAttendanceCount <= 0 then
		fRaid:Print("No temp attendance calculated")
	end	

	local function sortfunc(name1, name2)
		local ret = name1 < name2
		local att1 = fRaid.Player.TempAttendance[name1]
		local att2 = fRaid.Player.TempAttendance[name2]
		if att1 ~= att2 then
			ret = att1 > att2
		end
		return ret
	end
	local temp = {}
	for name, att in pairs(fRaid.Player.TempAttendance) do
		tinsert(temp, name)
	end
	sort(temp, sortfunc)

	local str = "Attendance over " ..  fRaid.Player.TempAttendanceCount .. " raids"
	if fRaid.Player.TempAttendanceRank and fRaid.Player.TempAttendanceRank ~= "" then
		str = str .. " (" .. fRaid.Player.TempAttendanceRank .. "s only)"
	end
	str = str .. ":"
	fLib.Com.Special(str, channel)
	str = ""
	
	local percent = 0
	local lastpercent = -1
	for _, name in ipairs(temp) do
		percent = fRaid.Player.TempAttendance[name]
		if (percent ~= lastpercent) then
			if lastpercent ~= -1 then
				str = str .. "]"
				fLib.Com.Special(str, channel)
				str = ""
			end
			str = str .. percent .. "%[" .. name
			lastpercent = percent
		else
			str = str .. "," .. name
		end
	end

	if str ~= "" then
		str = str .. "]"
		fLib.Com.Special(str, channel)
	end
end

function fRaid.Player.CalculatePercent(attendancecount)
	if attendancecount > fRaid.db.global.Player.AttendanceTotal or attendancecount < 0 then
		fRaid:Print("Invalid attendance count provided.")
	else
		return floor(attendancecount / fRaid.db.global.Player.AttendanceTotal * 100)
	end
end

function fRaid.Player.GetAttendancePercent(playername)
	playername = fRaid:Capitalize(strlower(strtrim(playername)))
	local playerobj = fRaid.db.global.Player.PlayerList[playername]
	if playerobj and playerobj.attendance and playerobj.attendance > 0 and fRaid.db.global.Player.AttendanceTotal > 0 then
		return fRaid.Player.CalculatePercent(playerobj.attendance)
	else
		return 0
	end
end

function fRaid.Player.GetAttendanceWindow(playername)

	-- If the player doesn't exist, return an empty list.
	playerobj = fRaid.db.global.Player.PlayerList[playername]
	if not playerobj then
		return {}
	end

	-- Get the last few raids corresponding to the attendance window.
	local numraids = fRaid.db.global.Player.AttendanceTotal
	local raids = fRaid.Raid.GetSortedRaidList(numraids)

	-- Collect their missed raids.
	local window = {}
	for idx, data in pairs(raids) do
		local owner = data[1]
		local idx = data[2]

		local raiddata = fRaid.db.global.Raid.RaidList[owner][idx]
		local oRaid = fRaid.Raid.raidobj.new()
		oRaid:Load(raiddata)
		
		if oRaid:Present(playername) then
			table.insert(window, true)
		else
			table.insert(window, false)
		end
	end

	return window
end

function fRaid.Player.GetAttendanceWindowMessage(window)

	message = "["
	for i, attended in pairs(window) do
		if attended then
			message = message .. "X"
		else
			message = message .. "_"
		end
	end
	message = message .. "]"

	return message
end

function fRaid.Player.GetAttendanceUntilHigh(playername)

	-- Get the player attendance window if available.
	local window = fRaid.Player.GetAttendanceWindow(playername)
	if #window == 0 then
		return 0
	end

	-- If the player is already at high attendance, no more raids 
	-- are necessary.
	local obj = fRaid.db.global.Player.PlayerList[playername]
	if obj.attflag == "high" then
		return 0
	end

	-- Loop shifting in attended raids until we'd be at the threshold 
	-- for high attendance.
	local raidsUntilHigh = 0
	for i = 0, #window do

		-- Get the percentage attended for this window.
		local totalAttended = 0
		for raid, attended in pairs(window) do
			if attended then
				totalAttended = totalAttended + 1
			end
		end
		local percentAttended = totalAttended / #window

		-- If it would make us high attendance, we're done.
		if percentAttended >= 0.75 then
			break
		end

		-- Otherwise, we'll pretend a raid was just attended and try 
		-- again.
		table.remove(window, 1)
		table.insert(window, true)
		raidsUntilHigh = raidsUntilHigh + 1
	end

	return raidsUntilHigh
end

function fRaid.Player.PrintAttendance(channel, minpercent)
	if not channel then
		channel = "OFFICER"
	end
	
	if not minpercent then
		minpercent = 0
	end
	
	if minpercent > 100 then
		minpercent = 100
	end
	
	local minraids = ceil(minpercent * fRaid.db.global.Player.AttendanceTotal / 100)
	
	local function sortfunc(name1, name2)
		local ret = name1 < name2
		local att1 = fRaid.db.global.Player.PlayerList[name1].attendance
		local att2 = fRaid.db.global.Player.PlayerList[name2].attendance
		if att1 ~= att2 then
			ret = att1 > att2
		end
		return ret
	end
	local temp = {}
	for playername, playerobj in pairs(fRaid.db.global.Player.PlayerList) do
		if playerobj.attendance >= minraids then
			tinsert(temp, playername)
		end
	end
	sort(temp, sortfunc)
	
	local str = "Attendance " ..  fRaid.db.global.Player.AttendanceTotal .. " raids: "
	fLib.Com.Special(str, channel)
	str = ""
	
	local percent = 0
	local lastpercent = -1
	for _, playername in ipairs(temp) do
		percent = floor(fRaid.db.global.Player.PlayerList[playername].attendance / fRaid.db.global.Player.AttendanceTotal * 100)
	
		if (percent ~= lastpercent) then
			if lastpercent ~= -1 then
				str = str .. "]"
				fLib.Com.Special(str, channel)
				str = ""
			end
			str = str .. percent .. "%[" .. playername
			lastpercent = percent
		else
			str = str .. "," .. playername
		end
	end
	
	if str ~= "" then
		str = str .. "]"
		fLib.Com.Special(str, channel)
	end
end

function fRaid.Player.MakeDkpMessage(name)
	name = fRaid:Capitalize(strlower(strtrim(name)))
	local obj = fRaid.db.global.Player.PlayerList[name]
	local dkp = 0
	if obj and obj.dkp > 0 then
		dkp = obj.dkp
	end
	return name .. " has " .. dkp .. " dkp"
end

function fRaid.Player.MakeAttendanceMessage(name)
	name = fRaid:Capitalize(strlower(strtrim(name)))
	local att = fRaid.Player.GetAttendancePercent(name)
	if not fRaid.db.global.Player.AttendanceTotal then
		fRaid.db.global.Player.AttendanceTotal = 0
	end
	
	local obj = fRaid.db.global.Player.PlayerList[name]
	if not obj then
		return name .. " is not recognzied as a player"
	end
	local attflag = ""
	if obj.attflag == "low" then
		attflag = "Low Attendance"
	elseif obj.attflag == "high" then
		attflag = "High Attendance"
	else
		attflag = "Not Calculated"
	end

	return name .. " is currently flagged as " .. attflag .. ".  Actual percent is " .. att .. "% over " .. fRaid.db.global.Player.AttendanceTotal .. " raids.  Attendance window, oldest first: " .. fRaid.Player.GetAttendanceWindowMessage(fRaid.Player.GetAttendanceWindow(name)) .. ".  " .. fRaid.Player.GetAttendanceUntilHigh(name) .. " raid(s) until High Attendance"
	--return name .. "'s attendance is " .. att .. "% for the past " .. fRaid.db.global.Player.AttendanceTotal .. " raids."
end

function fRaid.Player.MakeBiddingRulesMessage()
	local msg = "Tier 1: High Attendance - no cap, Tier 2: Member, Low Attendance - 120dkp, Tier 3: Initiate - 60dkp, Tier 4: F&F Alt Apps - 20dkp, Min Bid - 20dkp"
end

--cmd is a player name or TODO: one of the keywords
local keywords = {
priest = true,
mage = true, 
warrior = true, 
warlock = true, 
deathknight = true, 
paladin = true, 
druid = true, 
shaman = true, 
hunter = true
}

function fRaid.Player.WhisperCommand(cmd, name, whispertarget)
	local msg = "Unknown Command"
	if cmd == "dkp" then
		msg = fRaid.Player.MakeDkpMessage(name)
	elseif cmd == "att" then
		msg = fRaid.Player.MakeAttendanceMessage(name)
	end
	
	if not whispertarget then
		fRaid:Print(msg)
	else
		fRaid.Whisper2(msg, whispertarget)
	end
end



function fRaid.Player.Find(name, cutoff)
	for user, changelist in pairs(fRaid.db.global.Player.ChangeList) do
		for idx, change in ipairs(changelist) do
			if change[1] == name then
				if cutoff then
					if change[4] >= cutoff then
						fRaid:Print(user, "action:"..change[2], "note:"..change[3], "date:"..change[4], "start:"..change[5], "diff:"..change[6]-change[5], "end:"..change[6])
					end
				else
					fRaid:Print(user, "action:"..change[2], "note:"..change[3], "date:"..change[4], "start:"..change[5], "diff:"..change[6]-change[5], "end:"..change[6])
				end
			end
		end
	end
end

function fRaid.Player.FindDiff(name, charge)
	local diff = 0
	for user, changelist in pairs(fRaid.db.global.Player.ChangeList) do
		for idx, change in ipairs(changelist) do
			if change[1] == name then
				diff = change[6]-change[5]
				if diff == charge then
					fRaid:Print(user, "action:"..change[2], "note:"..change[3], "date:"..change[4], "start:"..change[5], "diff:"..change[6]-change[5], "end:"..change[6])
				end
			end
		end
	end
end

--==================================================================================================

local function CreatePlayerFrame()
	local mf = fRaid.GUI2.PlayerFrame
	
	--create index table
	mf.index_to_name = {}
	mf.lastmodified = 0 --keeps track of fRaid.db.global.Player.LastModified
	
	--variables to keep track of sorting
	mf.sortdirty = true
    mf.sortkeeper = {
        {asc = false, issorted = false, name = 'Name'},
        {asc = false, issorted = false, name = 'Dkp'},
        {asc = false, issorted = false, name = 'Rank'},
        {asc = false, issorted = false, name = 'Role'},
        {asc = false, issorted = false, name = 'Att'},
        {asc = false, issorted = false, name = 'Prog'},
        {asc = false, issorted = false, name = 'Id'}
    }
    
	mf.table = fLibGUI.Table.CreateTable(mf, mf:GetWidth() - 10, 200, 6)
	
	--refreshes the index table from the PlayerList
	function mf:RefreshIndex(force)
        if self.lastmodified ~= fRaid.db.global.Player.LastModified or force then
            --print('Refreshing index...')
            table.wipe(self.index_to_name)
            self.lastmodified = fRaid.db.global.Player.LastModified
            
            for name,data in pairs(fRaid.db.global.Player.PlayerList) do
                tinsert(self.index_to_name, name)
            end
            
            local max = #self.index_to_name - self.table.rowcount + 1
            if max < 1 then
                max = 1
            end
            self.table.slider:SetMinMaxValues(1, max)
            self:ResetSort()
        end
    end
    
    --retrieves data from the PlayerList for the player name at index
	function mf:RetrieveData(index)
	    local name, data
	    if not index or index < 1 then
	        index = self.table.selectedindex
	    end
	    
	    name = self.index_to_name[index]
	    data = fRaid.db.global.Player.PlayerList[name]
	    
	    return name, data
	end
    
    function mf:ResetSort()
	    self.sortdirty = true
	    for idx,keeper in ipairs(self.sortkeeper) do
	    	keeper.issorted = false
	    end
    end
    
    --click on a header
    function mf:ClickHeader()
    	mf.sortdirty = true
        self:Sort()
        self:LoadRows()
    end
    
    --click on a row
    function mf:ClickRow()
        self:RefreshDetails()
    end
    
    --scroll
    function mf:Scroll()
        self:LoadRows()
    end
    
    
    function mf.lootcomparer(a, b) --a and b are names (key for PlayerList)
        --retrieve data
        local adata = fRaid.db.global.Player.PlayerList[a]
        local bdata = fRaid.db.global.Player.PlayerList[b]
        
        --find the sorted column and how it is sorted
        local SORT = mf.table.selectedcolnum
        local SORT_ASC = mf.sortkeeper[SORT].asc
        local SORT_NAME = mf.sortkeeper[SORT].name
        
        local ret = true
        
        if SORT_NAME == 'Rank' then
        	if adata.rank == bdata.rank then
        		ret = a > b
        	else
        		ret = adata.rank > bdata.rank
        	end
        elseif SORT_NAME == 'Dkp' then
            if adata.dkp == bdata.dkp then
                ret = a > b
            else
                ret = adata.dkp < bdata.dkp
            end
        elseif SORT_NAME == 'Att' then
        	if adata.attendance == bdata.attendance then
        		ret = a > b
        	else
        		ret = adata.attendance < bdata.attendance
        	end
        else
            ret = a > b
        end
        
        if SORT_ASC then
            return not ret
        else
            return ret
        end
    end
    
    function mf:Sort(colnum)
        if colnum and column ~= mf.table.selectedcolnum then
            mf.table.selectedcolnum = colnum
            mf.sortdirty = true
        end
        
        if mf.sortdirty then
            colnum = mf.table.selectedcolnum
            if mf.sortkeeper[colnum].issorted then
                --toggle ascending / descending sort
                mf.sortkeeper[colnum].asc = not mf.sortkeeper[colnum].asc
            else
                --mf.sortkeeper[colnum].asc = true
                for idx,keeper in ipairs(mf.sortkeeper) do
                    keeper.issorted = false
                end
                mf.sortkeeper[colnum].issorted = true
            end
            table.sort(mf.index_to_name, mf.lootcomparer)
        end
        
        mf.sortdirty = false
    end
    
    function mf:LoadRows(startingindex)
	    --print('Loading rows...')
	    if startingindex then
	        self.table.startingindex = startingindex
	    end
	
	    self:RefreshIndex()
	    self:Sort()
	    
	    local name, data
	    local index = self.table.startingindex
	    
	    local searchmatch = false
	    local searchnum, searchname
	    searchnum = tonumber(self.search)
	    searchname = strlower(self.search)
	    
	    local selectedindexfound = false
	    local exactmatchindex = 0
	    local exactmatchrow = 0
	    
	    for i = 1, self.table.rowcount do
	        --search
	        searchmatch = false
	        while not searchmatch do
	            name, data = self:RetrieveData(index)
	            if self.search == '' or not data then
	                searchmatch = true
	            else
	                if data.dkp == searchnum then
	                    searchmatch = true
	                elseif strfind(strlower(name), searchname, 1, true) then
	                    searchmatch = true
	                    if strlower(name) == strlower(searchname) then
	                        exactmatchrow = i
	                        exactmatchindex = index
	                    end
	                else
	                    index = index + 1
	                end
	            end
	        end
	        
	        if not data then
	            for j = 1, self.table.colcount do
	                self.table.columns[j].cells[i]:SetText('')
	            end
	            
	            self.table.rowbuttons[i]:Hide()
	            self.table.rowbuttons[i].index = 0
	        else
	            --fill in cells with stuff
	            self.table.columns[1].cells[i]:SetText(name)
	            self.table.columns[2].cells[i]:SetText(data.dkp)
	            self.table.columns[3].cells[i]:SetText(data.rank)
	            self.table.columns[4].cells[i]:SetText(data.role)
	            self.table.columns[5].cells[i]:SetText(data.attendance)
	            self.table.columns[6].cells[i]:SetText(data.attflag)
	            --self.table.columns[7].cells[i]:SetText(index)
	            
	            --attach correct indexnum to rowbutton
	            self.table.rowbuttons[i]:Show()
	            self.table.rowbuttons[i].index = index
	            
	            if index == self.table.selectedindex then
	                self.table.rowbuttons[i].highlightspecial:Show()
	                selectedindexfound = true
	            else
	                self.table.rowbuttons[i].highlightspecial:Hide()
	            end
	        end
	        index = index + 1
	    end
	    
	    if exactmatchrow > 0 then
	        --print('exact match at ', exactmatchindex)
	        self.table.rowbuttons[exactmatchrow].highlightspecial:Show()
	        self.table.selectedindex = exactmatchindex
	    elseif not selectedindexfound then
	        self.table.selectedindex = 0
	    end
	    
	    self:RefreshDetails()
	end
	
	function mf:Refresh()
	    self:LoadRows()
	end
	
	function mf:RefreshDetails()
	    local name, data = self:RetrieveData()
	    if name and data then
	        self.title_name:SetText(name)
	        self.title_dkp:SetText(data.dkp)
	    else
	        self.title_name:SetText('')
	        self.title_dkp:SetText('')
	    end
	end
end

function fRaid.Player.View()
    local mf = fRaid.GUI2.PlayerFrame

    if not mf.viewedonce then       
        CreatePlayerFrame()
        
        local function np(self, name)
            fRaid.Player.AddDkp(name, 0, 'new player')

            self.eb_search:SetText('')
            self.eb_search.newbutton:Hide()
            self.sortdirty = true
            
            self:Refresh()
        end
        function mf:NewPlayer(name)
            if not name or name == '' then
                name = self.eb_search:GetText()
            end
            fRaid:ConfirmDialog2('Add new player: ' .. name .. '?', np, self, name)
        end
        
        mf.table:AddHeaderClickAction(mf.ClickHeader, mf)
        mf.table:AddRowClickAction(mf.ClickRow, mf)
        mf.table:AddScrollAction(mf.Scroll, mf)
        
        --fill in headers
        local i = 1
        mf.table.columns[i].headerbutton:SetText('Name')
        mf.table.columns[i]:SetWidth(100)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Dkp')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Rank')
        mf.table.columns[i]:SetWidth(60)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Role')
        mf.table.columns[i]:SetWidth(75)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Att')
        mf.table.columns[i]:SetWidth(40)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('AttFlag')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        --mf.table.columns[i].headerbutton:SetText('Id')
        --mf.table.columns[i]:SetWidth(50)
        
        --separator
        ui = fLibGUI.CreateSeparator(mf)
        ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.table.height)
        ui:SetWidth(mf.table.width)
        prevui = ui
        
        --Search/Name box
        ui = fLibGUI.CreateEditBox(mf, 'Name')
        mf.eb_search = ui
        mf.search = ''
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetWidth(mf.table.width)
        ui:SetScript('OnEnterPressed', function(this)
            this:ClearFocus()
            if mf.table.selectedindex == 0 then
                mf:NewPlayer()
            end
        end)
        ui:SetScript('OnTextChanged', function(this)
            --print('text changed')
            if this:GetText() ~= mf.search then
                mf.table.selectedindex = 0
                mf:RefreshDetails()
                mf.search = this:GetText()
                mf:LoadRows()
                if mf.table.selectedindex == 0 and mf.search ~= '' then
                    this.newbutton:Show()
                else
                    this.newbutton:Hide()
                end
            end
        end)
        prevui = ui
        
        ui = fLibGUI.CreateActionButton(mf)
        mf.eb_search.newbutton = ui
        ui:SetText('New')
        ui:SetFrameLevel(4)
        ui:SetWidth(ui:GetTextWidth())
        ui:SetHeight(ui:GetTextHeight())
        ui:SetScript('OnClick', function(this) mf:NewPlayer() end)
        ui:SetPoint('RIGHT', mf.eb_search, 'RIGHT', -4, 0)
        ui:Hide()
        
        
        --Player Details
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', mf.eb_search, 'BOTTOMLEFT', 0, -5)
        ui:SetText('Name: ')
        prevui = ui
        
        mf.title_name = fLibGUI.CreateLabel(mf)
        mf.title_name:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.title_name:SetText('')
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetText('Dkp:')
        prevui = ui
        
        mf.title_dkp = fLibGUI.CreateLabel(mf)
        mf.title_dkp:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.title_dkp:SetText('')
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetText('Role:')
        prevui = ui
        
        mf.eb_role = fLibGUI.CreateEditBox2(mf, '#')
        mf.eb_role:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.eb_role:SetText('')
        mf.eb_role:SetScript('OnEnterPressed', function(this) 
            local itemnum, itemobj = mf:SelectedData()
            if itemobj then
                itemobj.role = this:GetText()
            end
            
            this:ClearFocus()
            this:SetText(itemobj.role)
            
            --refresh row (just going to refresh entire table)
            mf:Refresh()
        end)
        
        --DELETE button
        ui = fLibGUI.CreateActionButton(mf)
        mf.deletebutton = ui
        ui:SetText('DELETE')
        ui:SetFrameLevel(4)
        ui:SetWidth(ui:GetTextWidth())
        ui:SetHeight(ui:GetTextHeight())
        ui:SetScript('OnClick', function(this)
        	if mf.title_name:GetText() then
        		fRaid.Player.DeletePlayer(mf.title_name:GetText())
        	end
        end)
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMRIGHT', 0, -5)
        
        --separator
        ui = fLibGUI.CreateSeparator(mf)
        ui:SetWidth(1)
        ui:SetHeight(mf:GetHeight() - mf.table.height - 15)
        ui:SetPoint('TOP', mf.eb_search, 'BOTTOM', -30,-1)
        prevui = ui
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, -5)
        ui:SetText('Add dkp:')
        prevui = ui
        
        mf.eb_dkpchange = fLibGUI.CreateEditBox3(mf, 'amount')
        mf.eb_dkpchange:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.eb_dkpchange:SetWidth(100)
        mf.eb_dkpchange.prevtext = ''
        
        mf.eb_dkpnote = fLibGUI.CreateEditBox3(mf, 'note')
        mf.eb_dkpnote:SetPoint('TOPLEFT', mf.eb_dkpchange, 'BOTTOMLEFT', 0, -5)
        mf.eb_dkpnote:SetWidth(100)
        
        mf.eb_dkpchange:SetScript('OnEscapePressed', function(this)
            local num = tonumber(this:GetText())
            if not num then
                this:SetText(0)
            else
                this:SetText(num)
            end
            this:ClearFocus()
        end)
        mf.eb_dkpchange:SetScript('OnEnterPressed', function(this)
            local num = tonumber(this:GetText())
            if not num then
                this:SetText(0)
            else
                this:SetText(num)
            end
            mf.eb_dkpnote:SetFocus()
            mf.eb_dkpnote:HighlightText()
        end)
        mf.eb_dkpnote:SetScript('OnEscapePressed', function(this)
            this:ClearFocus()
        end)
        mf.eb_dkpnote:SetScript('OnEnterPressed', function(this)
            local name, playerobj = mf:RetrieveData()
            if playerobj then
                local amount = tonumber(mf.eb_dkpchange:GetText())
                if amount then
                    --playerobj.dkp = playerobj.dkp + newdkp
                    --TODO: note
                    fRaid.Player.AddDkp(name, amount, mf.eb_dkpnote:GetText())
                    mf.eb_dkpchange:SetText('')
                    this:SetText('')
                    this:ClearFocus()
                    mf.sortdirty = true
                    mf:Refresh()
                else
                    mf.eb_dkpchange:SetFocus()
                    mf.eb_dkpchange:HighlightText()
                end
            end
        end)

            
        mf.viewedonce = true
    end

    mf:Refresh()
    mf:Show()
end
