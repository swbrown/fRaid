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
--DkpAwarded - list of dkpobj (doesn't include bosskill dkp)
----dkpobj: t, dkp


fRaid.Raid.raidobj = {}
local myfuncs = {}

function fRaid.Raid.raidobj.new(starttime)
	local ro = {}
	ro.Data = {}
	
	if starttime then
		ro.Data.StartTime = starttime
	else
		ro.Data.StartTime = fLib.GetTimestamp()
	end
	
	ro.Data.Owner = UnitName('player')
	ro.Data.IsProgression = false
	
	ro.Data.RaiderList = {}
	ro.Data.ListedPlayers = {}
	ro.Data.BossList = {}
	ro.Data.DkpAwarded = {}
	
	local funcs = {
		Load = myfuncs.Load,
		AwardDkp = myfuncs.AwardDkp,
	}
	
	for funcn,funcp in pairs(funcs) do
		ro[funcn] = funcp
	end
	
	return ro
end

function myfuncs.Load(self, data)
	self.Data = data
end

function myfuncs.AwardDkp(self, amount, timestamp)
	if not timestamp then
		timestamp = fLib.GetTimestamp()
	end

	--TODO: add this dkp award to the DkpAwarded list
	tinsert(self.Data.DkpAwarded, {timestamp, amount})

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
			fRaid.Player.AddDkp(name, amount, timestamp)
		end
	end 
end

function myfuncs.AddListedPlayers(self, listobj)
	--save listed players who haven't been in the raid already
	
	local tempp = {}
	if listobj then
		tempp = fList.GetPlayersFromListObj(listobj)
	else
		tempp = fList.GetPlayers()
	end
	
	for idx, name in ipairs(tempp) do
		--if they haven't been in the raid yet
		if not self.Data.RaiderList[name] then
			--and aren't already in ListedPlayers
			if not fLib.ExistsInList(self.Data.ListedPlayers, name) then
				--add them
				tinsert(self.Data.ListedPlayers, name)
			end
		end
	end
	
	--clean up ListedPlayers
	local idx
	for name, _ in pairs(self.Data.RaiderList) do
		idx = fLib.ExistsInList(self.Data.ListedPlayers, name)
		if idx then
			tremove(self.Data.ListedPlayers, idx)
		end
	end
end