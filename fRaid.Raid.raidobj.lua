-- Author      : Jessica Chen Huang
-- Create Date : 6/15/2009 6:30PM

--raidobj
--contains functions
--contains Data

--raidobj.Data
--Owner - string
--StartTime - string
--EndTime - string
--IsProgression - boolean
--RaiderList - key = name, value = raiderobj
----raiderobj
------guild, rank, timestamplist
--ListedPlayers - list of names
--BossList - key = instance, value = areaobj
----areaobj - key = name, value = bossobj
----bossobj
------time
------dkp
------loot
--DkpChange - list of dkpobj (doesn't include bosskill dkp)
----dkpobj: t, dkp


fRaid.Raid.raidobj = {}
local myfuncs = {}

--creates a new raidobj
function fRaid.Raid.raidobj.new()
	local ro = {}
	ro.Data = {}
	
	--ro.Data.Owner = UnitName('player')
	--ro.Data.IsProgression = false
	
	ro.Data.RaiderList = {}
	ro.Data.ListedPlayers = {}
	ro.Data.BossList = {}
	ro.Data.DkpAwarded = {}
	
	local funcs = {
		Load = myfuncs.Load,
		SetStartTime = myfuncs.SetStartTime,
		SetEndtTime = myfuncs.SetEndTime,
		AwardDkp = myfuncs.AwardDkp,
	}
	
	for funcn,funcp in pairs(funcs) do
		ro[funcn] = funcp
	end
	
	return ro
end

--load existing data into this raidobj
--date: required
function myfuncs.Load(self, data)
	self.Data = data
end

--timestmp: optional
function myfuncs.SetStartTime(self, timestamp)
	if starttime then
		self.Data.StartTime = starttime
	else
		self.Data.StartTime = fLib.GetTimestamp()
	end
end

--timestamp: optional
function myfuncs.SetEndTime(self, timestamp)
	if starttime then
		self.Data.EndTime = starttime
	else
		self.Data.EndTime = fLib.GetTimestamp()
	end
end

--amount: required
--timestamp: optional
function myfuncs.AddDkpChange(self, amount, timestamp)
	if not timestamp then
		timestamp = fLib.GetTimestamp()
	end

	if amount == 0 then
		fRaid:Print('Ignoring attempt to add a dkp change of 0')
		return
	end

	--record this dkp change to the DkpChange list
	tinsert(self.Data.DkpChange, {timestamp, amount})

	--award dkp to the raiders in the raid at the time
	local present = false
	for name,data in pairs(self.Data.RaiderList) do
		present = false
		--check if they were in the raid during timestamp
		for idx,timeslot in ipairs(data.timestamplist) do
			if timeslot.endtime then
				if timestamp >= timeslot.starttime and timestamp <= timeslot.endtime then
					present = true
				end
			else
				if timestamp >= timeslot.starttime then
					present = true
				end
			end
		end
		
		--award them amount dkp
		if present then
			fRaid.Player.AddDkp(name, amount, 'dkpchange added at ' .. timestamp)
		end
	end 
end

--idx: required
function myfuncs.RemoveDkpChange(self, idx)
	local dkpchangeobj = self.Data.DkpChange[idx]
	if dkpchangeobj then
		local ts = dkpchangeobj[1]
		local amount = dkpchangeobj[2]
		
		--subtract dkp from the raiders in the raid at the time
		local present = false
		for name,data in pairs(self.Data.RaiderList) do
			present = false
			--check if they were in the raid during timestamp
			for idx,timeslot in ipairs(data.timestamplist) do
				if timeslot.endtime then
					if timestamp >= timeslot.starttime and timestamp <= timeslot.endtime then
						present = true
					end
				else
					if timestamp >= timeslot.starttime then
						present = true
					end
				end
				
			end
			
			--award them amount dkp
			if present then
				fRaid.Player.AddDkp(name, -amount, 'dkpchange at ' .. timestamp .. ' removed')
			end
		end 
	else
		fRaid:Print("Invalid index to raidobj.Data.DkpChange[idx].")
	end
end

--name: required
--skipcleanup: optional
function myfuncs.AddListedPlayer(self, name, skipcleanup)
	--if they haven't been in the raid yet
	if not self.Data.RaiderList[name] then
		--and aren't already in ListedPlayers
		if not fLib.ExistsInList(self.Data.ListedPlayers, name) then
			--add them
			tinsert(self.Data.ListedPlayers, name)
		end
	end
			
	--clean up ListedPlayers
	if not skipcleanup then
		self:CleanupListedPlayers()
	end
end

function myfuncs.CleanupListedPlayers(self)
	--clean up ListedPlayers
	local idx
	for name, _ in pairs(self.Data.RaiderList) do
		idx = fLib.ExistsInList(self.Data.ListedPlayers, name)
		if idx then
			tremove(self.Data.ListedPlayers, idx)
		end
	end
end

--save listed players who haven't been in the raid already
--listobj: required
function myfuncs.AddListedPlayersFromListObj(self, listobj)
	local tempp = {}
	if listobj then
		tempp = fList.GetPlayersFromListObj(listobj)
	else
		tempp = fList.GetPlayers()
	end
	
	for idx, name in ipairs(tempp) do
		self:AddListedPlayer(name, true)
	end
	
	self:CleanupListedPlayers()
end

--name: required
--guild: required
--rank: required
--timestamp: optional
function myfuncs.AddRaider(self, name, guild, rank, timestamp)
	if not timestamp then
		timestamp = fLib.GetTimestamp()
	end
	local tsobj = {starttime = timestamp}

	local raiderobj = self.Data.RaiderList[name]
	
	if not raiderobj then
		--create new raiderobj
		raiderobj = {
			guild = g, --maybe they aren't in our guild
			rank = r, --maybe their rank changes over time? so should remember what it was
			timestamplist = {
				tsobj
			}
		}
		
		self.Data.RaiderList[name] = raiderobj
	else
		--update timestamp if they are rejoining raid
		timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
		if timestampobj.endtime then
			--add new timestampobj
			tinsert(raiderobj.timestamplist, tsobj)
		end
	end

	--should we update their guild and rank?... i guess so?...
	raiderobj.guild = guild
	raiderobj.rank = rank
end

--track the raiders who have joined or left the raid
local function TrackRaiders()
	--print('Tracking raiders...')
	local name, raiderobj, timestampobj
	local newraiderlist = {}
	
	--track players in raid
	for i = 1, GetNumRaidMembers() do
		name = GetRaidRosterInfo(i)
		if name then
			--print('Found ' .. name)
			local g, _, r = GetGuildInfo('raid' .. i)
			
			raiderobj = fRaid.db.global.Raid.CurrentRaid.RaiderList[name]
			if not raiderobj then
				--create new raiderobj
				raiderobj = {
					guild = g, --maybe they aren't in our guild
					rank = r, --maybe their rank changes over time? so should remember what it was
					timestamplist = {
						{starttime = fLib.GetTimestamp()}
					}
				}
			end
			
			--update timestamp if they are rejoining raid
			timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
			if timestampobj.endtime then
				--create a new timestampobj
				timestampobj = {
				starttime = fLib.GetTimestamp()
				}
				tinsert(raiderobj.timestamplist, timestampobj)
			end
			
			--should we update their guild and rank?... i guess so?...
			raiderobj.guild = g
			raiderobj.rank = r
			
			newraiderlist[name] = raiderobj --add to new list
			fRaid.db.global.Raid.CurrentRaid.RaiderList[name] = nil --remove from old list
		end
	end
	
	--track players that left
	for name, raiderobj in pairs(fRaid.db.global.Raid.CurrentRaid.RaiderList) do
		--print('ending ' .. name)
		timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
		if not timestampobj.endtime then
			timestampobj.endtime = fLib.GetTimestamp()
		end
		
		newraiderlist[name] = raiderobj
		fRaid.db.global.Raid.CurrentRaid.RaiderList[name] = nil
	end
	
	fRaid.db.global.Raid.CurrentRaid.RaiderList = newraiderlist
	
	--TODO: fill in listed players
	--check to see if the listed player was in the raider list
	--if they weren't, then keep t hem in listed players
end