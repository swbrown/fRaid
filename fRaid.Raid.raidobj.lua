-- Author      : Jessica Chen Huang
-- Create Date : 6/15/2009 6:30PM

--oRaid: oData

--oData: StartTime, StopTime, tRaiders, tInstanceTypes, lDkpCharges

--tRaiders
----key = raidername
----value = oRaider

--tInstanceTypes
----key = instance type
----val = tInstances

--tInstances
----key = instancename
----value = tBosses

--tBosses
----key = bossname
----val = oBoss

--lDkpCharges: oCharge

--oRaider: guild, rank, lRaidts, lListts

--oBoss: ts, mode, dkp, llLoot, lRaiders, lList, tToBeP
--oCharge: ts, note, dkp, lRaiders, lList, tToBeP

--lRaidts: oTs
--lListts: oTs

--oTs: s (start time), e (end time)

--lLoot: oLoot
--lRaiders: raidername
--lList: raidername

--tToBeP
----key = raidername
----val = timeout

--oLoot: itemid, TODO: bid stuff

--There are 3 types of functions: active, simulation and maintenance.
--Active(A) - uses the current timestamp
--Simulation(S) - uses a provided timestamp
--Maintenance(M) - uses some index referencing the Data

--Active/Simulation
----functions should be called in the order they are happening in real life
----the timestamp should be bewteen starttime and endtime if it exists

--(A/S) Start(timestamp), Stop(timestamp)
----sets oData.StartTime, oData.StopTime

--(M) AddRaider(name)
----creates/adds an oRaider at oData.tRaiders[name]
----returns oRaider

--(M) RemoveRaider(name)
----TODO: cannot be deleted if they won loot (oLoot)
----need to uncharge any dkp charged by oCharge or oBoss
----wipes the oRaider at oData.tRaiders[name]

--(A/S) JoinRaid(name, timestamp), LeaveRaid(name, timestamp)
----updates oData.tRaiders[name].lRaidts,lListts

--(A/S) List(name, timestamp), Unlist(name, timestamp)
----updates oData.tRaiders[name].lListts
----cannot be in list if in raid

--(M) AddInstance(instancetype, instancename)
----creates/adds an empty tBosses at oData.tInstanceType[instancetype][instancename]

--(M) RemoveInstance(instancetype, instancename)
----RemoveBoss each oBoss in tBosses
----wipes the tBosses at oData.tInstanceType[instancetype][instancename]

--(A/S) AddBoss(instancetype, instancename, bossname, timestamp, dkp)
----creates/adds an oBoss at oData.tInstanceType[instancetype][instancename][bossname]

--(M) RemoveBoss(instancetype, instancename, bossname)
----uncharge any dkp charged by oBoss
----wipes the oBoss at oData.tInstanceType[instancetype][instancename][bossname]

--(A/S) AddDkpCharge(amount, timestamp)
----creates/adds an oChange to oData.lDkpCharges
----charge dkp to raid/listed

--(M) DeleteDkpCharge(idx)
----uncharge any dkp charged by the oCharge at oData.lDkpCharges[idx]
----wipes the oCharge

--(M) ChangeBossDkpChange(bossname, amount)
----updates Data.InstanceList[instancename][bossname].dkp
----charge raiders/listed any dkp change

local MYNAME = UnitName('player')
fRaid.Raid.raidobj = {}
local myfuncs = {}

--creates a new raidobj
function fRaid.Raid.raidobj.new()
	local ro = {}
	ro.Data = {}
	
	--ro.Data.Owner = UnitName('player')
	--ro.Data.IsProgression = false
	
	ro.Data.RaiderList = {}
	ro.Data.tInstanceType = {}
	ro.Data.lDkpCharges = {}

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

--(A/S) Start(timestamp), Stop(timestamp)
----sets oData.StartTime, oData.StopTime
function myfuncs.Start(self, timestamp)
	if timestamp then
		self.Data.StartTime = timestamp
	else
		self.Data.StartTime = fLib.GetTimestamp()
	end
end
function myfuncs.Stop(self, timestamp)
	if timestamp then
		self.Data.EndTime = timestamp
	else
		self.Data.EndTime = fLib.GetTimestamp()
	end
	
	--leave all raiders, unlist all raiders
	for name, oRaider in pairs(self.Data.RaiderList) do
		self:LeaveRaid(name, nil, true)
		self:UnList(name, nil, true)
	end
end

--(M) AddRaider(name)
----creates/adds an oRaider at oData.tRaiders[name]
----returns oRaider
function myfuncs.AddRaider(self, name, guild, rank)
	fRaid:Debug("<<raidobj.AddRaider>>", name, guild, rank)
	if not self.Data.RaiderList[name] then
		--create new raiderobj
		local oRaider = {
			g = '', --maybe they aren't in our guild
			r = '', --maybe their rank changes over time?
			lRaidts = {},
			lListts = {}
		}
		
		self.Data.RaiderList[name] = oRaider
	end
	
	--update their guild and rank?
	local oRaider = self.Data.RaiderList[name]
	if guild then oRaider.g = guild end
	if rank then oRaider.r = rank end
	
	return oRaider
end

--(M) RemoveRaider(name)
----TODO: cannot be deleted if they won loot (oLoot)
----need to uncharge any dkp charged by oCharge or oBoss
----wipes the oRaider at oData.tRaiders[name]
function myfuncs.RemoveRaider(self, name)
	local raiderobj = self.Data.RaiderList[name]
	--TODO:
	--check each oCharge in oData.lDkpCharges
	--check each oBoss in oData.tInstanceType.tInstances.tBosses
end

--(M) CleanupRaiderList()
----removes oRaiders from oData.tRaiders which have no entries in lRaidts or lListts
function myfuncs.CleanupRaiderList(self)
	for name, oRaider in pairs(self.Data.RaiderList) do
		if #oRaider.lRaidts == 0 and #oRaider.lListts == 0 then
			self.Data.RaiderList[name] = nil
		end
	end
end

function myfuncs.InRaid(self, name, timestamp)
	fRaid:Debug("<<raidobj.InRaid>>", name)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	
	for _, oTs in ipairs(oRaider.lRaidts) do
		fRaid:Debug("<<raidobj.InRaid>>", "comparing "..timestamp.." and "..oTs[1])
		if timestamp >= oTs[1] then
			if not oTs[2] or (oTs[2] and timestamp <= oTs[2]) then
				fRaid:Debug("<<raidobj.InRaid>>", name, "returning true")
				return true
			end
		end
	end
	fRaid:Debug("<<raidobj.InRaid>>", name, "returning false")
	return false
end
function myfuncs.InList(self, name, timestamp)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	
	for _, oTs in ipairs(oRaider.lListts) do
		if timestamp >= oTs[1] then
			if not oTs[2] or (oTs[2] and timestamp <= oTs[2]) then
				return true
			end
		end
	end
	return false
end

--for attendance, to count as present, must have been listed and/or in the raid for > 2 hours??
function myfuncs.Present(self, name, minminutes)
	fRaid:Debug("<<raidobj.Present>>", name, minminutes)
	if not minminutes then
		minminutes = 15
	end
	local oRaider = self:AddRaider(name)

	--add up raid time
	local total = 0
	for _, oTs in ipairs(oRaider.lRaidts) do
		total = total + fLib.T1MinusT2ToMinutes(oTs[2], oTs[1])
		fRaid:Debug("<<raidobj.Present>>", name, "running total="..total)
	end
	
	--add up list time
	for _, oTs in ipairs(oRaider.lListts) do
		total = total + fLib.T1MinusT2ToMinutes(oTs[2], oTs[1])
		fRaid:Debug("<<raidobj.Present>>", name, "running total="..total)
	end
	
	if total > minminutes then
		return true
	end
	return false
end

--(A/S) JoinRaid(name, timestamp), LeaveRaid(name, timestamp)
----updates oData.tRaiders[name].lRaidts,lListts
function myfuncs.JoinRaid(self, name, timestamp, silent)
	fRaid:Debug("<<JoinRaid>>", name)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	local oTsnew = {timestamp}
	
	--check lRaidts
	local oTs = oRaider.lRaidts[#oRaider.lRaidts]
	if oTs then --has been in the raid b4
		if oTs[2] then --a closed oTs, has left the raid b4
			if timestamp <= oTs[2] then
				if not silent then fRaid:Print("JoinRaid failed: "..timestamp.." must be > "..oTs[2]..", the last time "..name.." left the raid") end
				return
			--else --timestamp is ok
			end
		else --an open oTs, aka currently in raid
			if not silent then fRaid:Print("JoinRaid failed: "..name.." is currently in the raid") end
			return
		end
	--else --has never been in the raid before
	end
	
	--check lListts
	oTs = oRaider.lListts[#oRaider.lListts]
	if oTs then --has listed b4
		if oTs[2] then --has left the list
			if timestamp <= oTs[2] then
				if not silent then fRaid:Print("JoinRaid failed: "..timestamp.." must be > "..oTs[2]..", the last time "..name.." left the list") end
				return
			--else --timestamp is ok
			end
		else --is currently in the list
			if timestamp <= oTs[1] then
				if not silent then fRaid:Print("JoinRaid failed: "..timestamp.." must be > "..oTs[1]..", the last time "..name.." joined the list") end
				return
			else --timestamp is ok
				--TODO: unlist them
				oTs[2] = timestamp
			end
		end
	--else --has never listed b4
	end

	--join raid
	tinsert(oRaider.lRaidts, oTsnew)
	fRaid:Print("JoinRaid succes: "..name.." has joined the raid")
end
function myfuncs.LeaveRaid(self, name, timestamp, silent)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	
	--check lRaidts
	local oTs = oRaider.lRaidts[#oRaider.lRaidts]
	if oTs then --has been in the raid b4
		if oTs[2] then --a closed oTs, has left the raid b4
		else --an open oTs, aka currently in raid
			if timestamp <= oTs[1] then
				if not silent then fRaid:Print("LeaveRaid failed: "..timestamp.." must be > "..oTs[1]..", the last time "..name.." joined the raid") end
				return
			else
				--leave raid
				oTs[2] = timestamp
				fRaid:Print("LeaveRaid succes: "..name.." has left the raid")
				return
			end
		end
	--else --has never been in the raid before
	end
	if not silent then fRaid:Print("LeaveRaid failed: "..name.." is not in the raid") end
end


--(A/S) List(name, timestamp), Unlist(name, timestamp)
----updates oData.tRaiders[name].lListts
----cannot be in list if in raid
function myfuncs.List(self, name, timestamp, silent)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	local oTsnew = {timestamp}
	
	--check in raid/lRaidts
	--check lRaidts
	local oTs = oRaider.lRaidts[#oRaider.lRaidts]
	if oTs then --has been in the raid b4
		if oTs[2] then --a closed oTs, has left the raid b4
			if timestamp <= oTs[2] then
				if not silent then fRaid:Print("List failed: "..timestamp.." must be > "..oTs[2]..", the last time "..name.." left the raid") end
				return
			--else --timestamp is ok
			end
		else --an open oTs, aka currently in raid
			if not silent then fRaid:Print("List failed: "..name.." is currently in the raid") end
			return
		end
	--else --has never been in the raid before
	end
	
	--check lListts
	oTs = oRaider.lListts[#oRaider.lListts]
	if oTs then --has listed b4
		if oTs[2] then --a closed oTs, has left the list b4
			if timestamp <= oTs[2] then
				if not silent then fRaid:Print("List failed: "..timestamp.." must be > "..oTs[2]..", the last time "..name.." left the list") end
				return
			--else --timestamp is ok
			end
		else --an open oTs, aka currently in list
			if not silent then fRaid:Print("JoinRaid failed: "..name.." is currently in the list") end
			return
		end
	--else --has never listed b4
	end
	
	--list raider
	tinsert(oRaider.lListts, oTsnew)
	fRaid:Print("List succes: "..name.." has listed")
end
function myfuncs.UnList(self, name, timestamp, silent)
	if not timestamp then timestamp = fLib.GetTimestamp() end
	local oRaider = self:AddRaider(name)
	
	--check lListts
	local oTs = oRaider.lListts[#oRaider.lListts]
	if oTs then --has been in the list b4
		if oTs[2] then --a closed oTs, has left the list b4
		else --an open oTs, aka currently in the list
			if timestamp <= oTs[1] then
				if not silent then fRaid:Print("UnList failed: "..timestamp.." must be > "..oTs[1]..", the last time "..name.." listed") end
				return
			else
				--unlist
				oTs[2] = timestamp
				fRaid:Print("UnList succes: "..name.." has unlisted")
				return
			end
		end
	--else --has never been in the list before
	end
	if not silent then fRaid:Print("UnList failed: "..name.." is not in the list") end
end

--(A/S) AddDkpCharge(amount, timestamp)
----creates/adds an oCharge to oData.lDkpCharges
----charge dkp to raid/listed
----if this is a simulation, provide timestamp and lListPresent
----lListPreset is a list of names that get automatically moved to lListed from lToBeP
function myfuncs.AddDkpCharge(self, amount, timestamp, lListPresent)
	fRaid:Debug("<<raidobj.AddDkpCharge>>", amount)
	local timeout
	if not timestamp then
		timestamp = fLib.GetTimestamp()
		local tso = fLib.AddMinutes(nil, 5)
		timeout = fLib.GetTimestamp(tso)
	else
		timeout = timestamp --for simulation timeout is ignored
	end

	if amount == 0 then
		fRaid:Print('Ignoring attempt to add a dkp charge of 0')
		return
	end
	
	--create a new oCharge
	local oCharge = {
		dkp = amount,
		ts = timestamp,
		lRaiders = {}, --list of raiders in the raid, get dkp right away
		lListed = {}, --list of raiders who have whispered back
		to = timeout, --timeout, listed people need to whisper back b4 timeout
		lToBeP = {}, --list of raiders who need to whisper back in order to get dkp
	}
	
	local alt
	for name, oRaider in pairs(self.Data.RaiderList) do
		if self:InRaid(name, timestamp) then
			fRaid.Player.AddDkp(name, amount, 'dkpcharge ' .. timestamp)
			tinsert(oCharge.lRaiders, name)
		elseif self:InList(name, timestamp) then
			--autoawarddkp
			fRaid.Player.AddDkp(name, amount/2, 'dkpcharge ' .. timestamp)
			tinsert(oCharge.lListed, name)
			alt = fList.GetAltFromPlayer(name)
			if alt and alt ~= "" then
				--fRaid:Whisper(alt, name.." was awarded dkp")
				fRaid.Whisper2(name .. " was awarded dkp", alt)
			end
			
			--dkpcheck
			--tinsert(oCharge.lToBeP, name)
		end
	end
	
	--save this oCharge
	tinsert(self.Data.lDkpCharges, oCharge)
	local idx = #self.Data.lDkpCharges
	local listeddkp = oCharge.dkp/2
	
	--whisper lToBeP that they need to whisper you back for dkp
	for _, name in ipairs(oCharge.lToBeP) do
		--fRaid:Whisper(name, "You have been awarded "..listeddkp..", which will expire in 5 minutes.  Please whisper me to receive your dkp.  /w "..MYNAME.." "..fRaid.db.global.prefix.dkpcheckin.." "..idx)
		fRaid.Whisper2("You have been awarded "..listeddkp..", which will expire in 5 minutes.  Please whisper me to receive your dkp.  /w "..MYNAME.." "..fRaid.db.global.prefix.dkpcheckin.." "..idx, name)
		--check if they have an alt
		alt = fList.GetAltFromPlayer(name)
		if alt and alt ~= '' then
			--fRaid:Whisper(alt, name.." has been awarded "..listeddkp..", which will expire in 5 minutes.  Please whisper me to receive your dkp.  /w "..MYNAME.." "..fRaid.db.global.prefix.dkpcheckin.." "..idx)
			fRaid.Whisper2(name.." has been awarded "..listeddkp..", which will expire in 5 minutes.  Please whisper me to receive your dkp.  /w "..MYNAME.." "..fRaid.db.global.prefix.dkpcheckin.." "..idx, alt)
		end
	end
end

--(A) UpdateDkpCharge(idx, name, timestamp)
----marks a listed player as preset (transfers rader from lToBeP to lListed)
function myfuncs.UpdateDkpCharge(self, idx, name, force)
	fRaid:Debug("<<UpdateDkpCharge>>", idx, name)
	local timestamp = fLib.GetTimestamp()
	local oCharge = self.Data.lDkpCharges[idx]
	if oCharge then
		name = fLib:Capitalize(name)
		fRaid:Debug("<<UpdateDkpCharge>>", "oCharge exists, timeout=", oCharge.to)
		--check that they have an open dkp charge
		local i = fLib.ExistsInList(oCharge.lToBeP, name)
		
		local alt = nil
		if not i then
			--check alt
			alt = name
			local nametest = fLib:Capitalize(fList.GetPlayerFromAlt(alt))
			i = fLib.ExistsInList(oCharge.lToBeP, nametest)
			if i then
				name =  nametest
			end
		end

		if i then
			if timestamp <= oCharge.to or force then
				--move them from lToBeP to lListed and charge them dkp
				tremove(oCharge.lToBeP, i)
				fRaid.Player.AddDkp(name, oCharge.dkp/2, 'dkpcharge ' .. timestamp)
				tinsert(oCharge.lListed, name)
				if alt then
					--fRaid:Whisper(alt, name.." was awarded dkp")
					fRaid.Whisper2(name.." was awarded dkp", alt)
				end
			else
				--fRaid:Whisper(name, "Your listed dkp has expired.")
				fRaid.Whisper2("Your listed dkp has expired.", name)
				if alt then fRaid:Whisper(alt, "Your listed dkp has expired.") end
			end
		else
			--fRaid:Whisper(name, "You have no listed dkp for number "..idx)
			fRaid.Whisper2("You have no listed dkp for number "..idx, name)
		end
	else
		--fRaid:Whisper(name, "You have no listed dkp for number "..idx)
		fRaid.Whisper2("You have no listed dkp for number "..idx, name)
	end
end

--(M) RemoveDkpCharge(idx)
----uncharge any dkp charged by the oCharge at oData.lDkpCharges[idx]
----wipes the oCharge
function myfuncs.RemoveDkpCharge(self, idx)
	local timestamp = fLib.GetTimestamp()
	local oCharge = self.Data.lDkpCharges[idx]
	if oCharge then
		--dkp change can only be removed if there are no oCharges still open before timeout
		for idx, x in ipairs(self.Data.lDkpCharges) do
			if timestamp <= x.to then
				fRaid:Print("There is still an active dkp charge at lDkpCharges["..idx.."]")
				return
			end
		end
		
		--for each raider in lRaiders, uncharge them dkp
		for idx, name in ipairs(oCharge.lRaiders) do
			fRaid.Player.AddDkp(name, -oCharge.dkp, 'dkpcharge removed')
		end
		
		--for each listed raider in lListed, uncharge them dkp
		for idx, name in ipairs(oCharge.lListed) do
			fRaid.Player.AddDkp(name, -oCharge.dkp/2, 'dkpcharge removed')
		end
		
		--wipe and set to nil
		tremove(self.Data.lDkpCharges, idx)
		wipe(oCharge)
	else
		fRaid:Print("Invalid index to lDkpCharges[idx].")
	end
end

--(M) AddInstance(instancetype, instancename)
----creates/adds an empty tBosses at oData.tInstanceType[instancetype][instancename]

--(M) RemoveInstance(instancetype, instancename)
----RemoveBoss each oBoss in tBosses
----wipes the tBosses at oData.tInstanceType[instancetype][instancename]

--(A/S) AddBoss(instancetype, instancename, bossname, timestamp, dkp)
----creates/adds an oBoss at oData.tInstanceType[instancetype][instancename][bossname]

--(M) RemoveBoss(instancetype, instancename, bossname)
----uncharge any dkp charged by oBoss
----wipes the oBoss at oData.tInstanceType[instancetype][instancename][bossname]

--(M) ChangeBossDkpCharge(bossname, amount)
----updates Data.InstanceList[instancename][bossname].dkp
----charge raiders/listed any dkp change

--(A/S) UpdateRaiders()
function myfuncs.UpdateRaiders(self)
	fRaid:Debug("<<raidobj.UpdateRaiders>>")
	local name, gname, grank
	--get current raiders
	local tCurrent = {}
	for i = 1, GetNumRaidMembers() do
		name = GetRaidRosterInfo(i)
		if name then
			gname, grank, _ = GetGuildInfo('raid'..i)
			tCurrent[name] = {gname, grank}
		end
	end

	--check existing raiders
	for name, oRaider in pairs(self.Data.RaiderList) do
		if tCurrent[name] then
			--join raiders
			self:JoinRaid(name, nil, true)
			tCurrent[name] = nil
		else
			--leave raiders
			self:LeaveRaid(name, nil, true)
			tCurrent[name] = nil
		end
	end
	
	--join the rest of the new raiders
	for name, info in pairs(tCurrent) do
		self:AddRaider(name, info[1], info[2])
		self:JoinRaid(name, nil, true)
	end
end

--(M) UpdateListedFromList()
function myfuncs.UpdateListed(self, listobj)
	local lCurrent = {}
	if listobj then
		lCurrent = fList.GetPlayersFromListObj(listobj)
	else
		lCurrent = fList.GetPlayers()
	end
	
	--check existing list
	local i
	for name, oRaider in pairs(self.Data.RaiderList) do
		i = fLib.ExistsInList(lCurrent, name)
		if i then
			--list them
			self:List(name, nil, true)
			tremove(lCurrent, i)
		else
			--unlist them
			self:UnList(name, nil, true)
		end
	end
	
	--list the rest of the new raiders
	for idx, name in ipairs(lCurrent) do
		self:List(name, nil, true)
	end
end