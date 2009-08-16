-- Author      : Jessica Chen Huang
-- Create Date : 6/15/2009 6:30PM

--Data.StartTime
--Data.StopTime
--Data.RaiderList
----key = raidername, value = raiderobj
--Data.InstanceList
----key = instancename, value = instanceobj
--Data.DkpChargeList
----key = timestamp, value = amount

--raiderobj: guild, rank, raidts, listts
--instanceobj: (aka BossList)
----key = bossname, value = bossobj
--bossobj: ts, dkp, LootList
--LootList:
----key = idx, value = lootobj
--lootobj: itemid, dkp, winner, BidList


--There are 3 types of functions: active, simulation and maintenance.
--Active(A) - uses the current timestamp
--Simulation(S) - uses a provided timestamp
--Maintenance(M) - uses some index referencing the Data

--Active/Simulation
----functions should be called in the order they are happening in real life
----the timestamp should be bewteen starttime and endtime if it exists

--(A) Start(timestamp)
----sets Data.StartTime

--(A) Stop(timestamp)
----sets Data.StopTime

--(M) NewPlayer(name)
----creates/adds a new raiderobj to Data.RaiderList

--(M) CleanupRaiderList()
----removes raiderobjs from Data.RaiderList which have no entries in raidts or listts

--(A/S) JoinRaid(timestamp, name), LeaveRaid(name, timestamp)
----updates Data.RaiderList[name].raidts

--(A/S) List(name, timestamp), Unlist(name, timestamp)
----updates Data.RaiderList[name].listts
----cannot be in list if in raid

--(M) DeleteRaider(name)
----cannot be deleted if they won loot (lootobj)
----need to uncharge any dkp charged by chargeobj or bossobj
----wipes the raiderobj at Data.RaiderList[name]

--(M) NewInstance(instancename)
----creates/adds a new instanceobj to Data.InstanceList

--(M) DeleteInstance(instancename)
----uncharge any dkp charged by bossobj
----wipes the instanceobj at Data.InstanceList[instancename]

--(A/S) AddBoss(bossname, instancename, timestamp)
----creates/adds a new bossobj to Data.InstanceList[instancename]
----timestamp must be in between Data.StarTime and Data.EndTime

--(M) DeleteBoss(bossname, instancename)
----uncharge any dkp charged by bossobj
----wipes the bossobj at Data.InstanceList[instancename][bossname]

--(M) AddLoot(itemid, bossname, instancename)
----creates/adds a new lootobj to Data.InstanceList[instancename][bossname].LootList

--(M) DeleteLoot(itemid, bossname, instancename)
----uncharge any dkp to lootobj.winner
----wipes the lootobj at Data.InstanceList[instancename][bossname].LootList

--(A/S) AddDkpCharge(amount, timestamp)
----creates/adds a new chargeobj to Data.DkpChargeList
----charge dkp to raid/listed

--(M) DeleteDkpCharge(timestamp)
----uncharge any dkp charged by the chargeobj at Data.DkpCharge[timestamp]
----wipes the chargeobj

--(M) ChangeBossDkpCharge(bossname, amount)
----updates Data.InstanceList[instancename][bossname].dkp
----charge raiders/listed any dkp change


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
	ro.Data.DkpChargeList = {}

	--map functions
	for funcn, funcf in pairs(myfuncs) do
		if type(funcf) == 'function' then
			ro[funcn] = funcf
		end
	end
	
	return ro
end

--load existing data into this raidobj
--date: required
function myfuncs.Load(self, data)
	self.Data = data
end

--(A/S) Start(timestamp)
----timestmp: optional
----sets Data.StartTime
function myfuncs.Start(self, timestamp)
	if timestamp then
		self.Data.StartTime = timestamp
	else
		self.Data.StartTime = fLib.GetTimestamp()
	end
end

--(A/S) Stop(timestamp)
----timestamp: optional
----sets Data.StopTime
function myfuncs.Stop(self, timestamp)
	if timestamp then
		self.Data.EndTime = timestamp
	else
		self.Data.EndTime = fLib.GetTimestamp()
	end
end

--(M) NewPlayer(name)
----creates/adds a new raiderobj to Data.RaiderList
function myfuncs.NewPlayer(self, name)
	if not self.Data.RaiderList[name] then
		--create new raiderobj
		local raiderobj = {
			g = '', --maybe they aren't in our guild
			r = '', --maybe their rank changes over time?
			raidts = {},
			listts = {}
		}
		
		self.Data.RaiderList[name] = raiderobj
	end
	
	return self.Data.RaiderList[name]
end

--(M) CleanupRaiderList()
----removes raiderobjs from Data.RaiderList which have no entries in raidts or listts
function myfuncs.CleanupRaiderList(self)
	for name, raiderobj in pairs(self.Data.RaiderList) do
		if #raiderobj.raidts == 0 and #raiderobj.listts == 0 then
			self.Data.RaiderList[name] = nil
		end
	end
end

--(A/S) JoinRaid(name, timestamp)
----timestamp: optional
----updates Data.RaiderList[name].raidts
----updates Data.RaiderList[name].listts
function myfuncs.JoinRaid(self, name, timestamp)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local newtsobj = {timestamp}
	local raiderobj = self:NewPlayer(name)

	--assume caller is doing the right thing
	--timestamp must be later than last raidts end time and last listts start or end time
	local raidjoinable = false
	local tsobj = raiderobj.raidts[#raiderobj.raidts]
	if not tsobj then
		raidjoinable = true
	else
		if tsobj[2] then --is an end time
			if timestamp > tsobj[2] then
				raidjoinable = true
			else
				fRaid:Print('JoinRaid failed: 1 timestamp too early')
			end
		elseif tsobj[1] then --is a start time
			if timestamp >= tsobj[1] then
				fRaid:Print('JoinRaid failed: '..name..' is already in raid')
			else
				fRaid:Print('JoinRaid failed: 2 timestamp too early')
			end
		else
			--tsobj should never be empty, but in case it is...
			tremove(raiderobj.raidts)
			fRaid:Print('JoinRaid failed: empty raid tsobj')
		end
	end
	
	if raidjoinable then
		raidjoinable = false
		
		--check listts start/end times
		tsobj = raiderobj.listts[#raiderobj.listts]
		if not tsobj then
			raidjoinable = true
		else
			if tsobj[2] then -- is an end time
				if timestamp > tsobj[2] then
					raidjoinable = true
				else
					fRaid:Print('JoinRaid failed: 3 timestamp too early')
				end
			elseif tsobj[1] then -- is a start time
				if timestamp > tsobj[1] then
					raidjoinable = true
					--unlist raider
					tsobj[2] = timestamp
				else
					fRaid:Print('JoinRaid failed: 4 timestamp too early')
				end
			else
				--tsobj should never be empty, but in case it is...
				tremove(raiderobj.listts)
				fRaid:Print('JoinRaid failed: empty list tsobj')
			end
		end
		
		if raidjoinable then
			--join raid
			tinsert(raiderobj.raidts, newtsobj)
			fRaid:Print(name..' has joined the raid')
			return
		end
	end
	
	fRaid:Print(name..' failed to join the raid')
end

--(A/S) LeaveRaid(name, timestamp)
----timestamp: optional
----updates Data.RaiderList[name].raidts
function myfuncs.LeaveRaid(self, name, timestamp)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local raiderobj = self:NewPlayer(name)
	
	--only if last tsobj is missing end time
	--and timestamp must be later than last raid start time
	local tsobj = raiderobj.raidts[#raiderobj.raidts]
	if tsobj and tsobj[1] and not tsobj[2] and timestamp > tsobj[1] then
		tsobj[2] = timestamp
	end
	
	fRaid:Print('LeaveRaid failed.')
end

--(A/S) List(name, timestamp), Unlist(name, timestamp)
----updates Data.RaiderList[name].listts
----cannot be in list if in raid
function myfuncs.List(name, timestamp)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local raiderobj = self:NewPlayer(name)
	
	
end

--(M) DeleteRaider(name)
----cannot be deleted if they won loot (lootobj)
----need to uncharge any dkp charged by chargeobj or bossobj
----wipes the raiderobj at Data.RaiderList[name]

--(M) NewInstance(instancename)
----creates/adds a new instanceobj to Data.InstanceList

--(M) DeleteInstance(instancename)
----uncharge any dkp charged by bossobj
----wipes the instanceobj at Data.InstanceList[instancename]

--(A/S) AddBoss(bossname, instancename, timestamp)
----creates/adds a new bossobj to Data.InstanceList[instancename]
----timestamp must be in between Data.StarTime and Data.EndTime

--(M) DeleteBoss(bossname, instancename)
----uncharge any dkp charged by bossobj
----wipes the bossobj at Data.InstanceList[instancename][bossname]

--(M) AddLoot(itemid, bossname, instancename)
----creates/adds a new lootobj to Data.InstanceList[instancename][bossname].LootList

--(M) DeleteLoot(itemid, bossname, instancename)
----uncharge any dkp to lootobj.winner
----wipes the lootobj at Data.InstanceList[instancename][bossname].LootList

--(A/S) AddDkpCharge(amount, timestamp)
----creates/adds a new chargeobj to Data.DkpCharge
----charge dkp to raid/listed

--(M) DeleteDkpCharge(timestamp)
----uncharge any dkp charged by the chargeobj at Data.DkpCharge[timestamp]
----wipes the chargeobj

--(M) ChangeBossDkpCharge(bossname, amount)
----updates Data.InstanceList[instancename][bossname].dkp
----charge raiders/listed any dkp change


















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
	--tinsert(self.Data.DkpChange, {timestamp, amount})

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
	
	--temporary fix....
	for _, name in ipairs(self.Data.ListedPlayers) do
		fRaid.Player.AddDkp(name, amount/2, 'dkpchange added at ' .. timestamp)
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


function myfuncs.LeaveRaider(self, name, timestamp)
	if not timestamp then
		timestamp = fLib.GetTimestamp()
	end
	local tsobj = {starttime = timestamp}
	
	local raiderobj = self.Data.RaiderList[name]
	
	if not raiderobj then
		fRaid:Print(name .. ' never joined the raid.')
		return
	else
		--end the timetsamp entry if valid
		timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
		if not timestampobj.starttime then
			fRaid:Print(name .. ' has not joined the raid recently.')
			return
		end
		if timestamp < timestampobj.starttime then
			fRaid:Print(timestamp .. ' cannot be earlier than ' .. timestampobj.starttime)
			return
		end
		timestampobj.endtime = timestamp
	end
end

function myfuncs.InsertRaider(self, name, starttime, endtime)
	
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