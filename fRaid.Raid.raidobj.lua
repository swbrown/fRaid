-- Author      : Jessica Chen Huang
-- Create Date : 6/15/2009 6:30PM

fRaid.Raid.raidobj = {}

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
	
	local funcs = {
		AwardDkp = fRaid.Raid.raidobj.AwardDkp,
	}
	
	for funcn,funcp in pairs(funcs) do
		ro[funcn] = funcp
	end
	
	return ro
end

function fRaid.Raid.raidobj.load(data)
	local ro = fRaid.Raid.raidobj.new()
	ro.Data = data
	return ro
end

function fRaid.Raid.raidobj.AwardDkp(self, amount, timestamp)
	local present = false
	for name,data in pairs(self.Data.RaiderList) do
		present = false
		--check if they were in the raid duringn timestamp
		for idx,timeslot in ipairs(data.timestamplist) do
			if timestamp >= timeslot.starttime and timestamp <= timeslot.endtime then
				present = true
			end
		end
		
		--award them amount dkp
		if present then
			fRaid.Player.AddDkp(name, amount, timestamp)
		end
	end
end
