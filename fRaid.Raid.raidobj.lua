-- Author      : Jessica Chen Huang
-- Create Date : 6/15/2009 6:30PM

fRaid.Raid.raidobj = {}

function fRaid.Raid.raidobj.new()
	local ro = {}
	ro.Data = {}
	
	ro.Data.StartTime = fLib.GetTimestamp()
	ro.Data.Owner = UnitName('player')
	
	ro.Data.IsProgression = false
	
	ro.Data.RaiderList = {}
	ro.Data.ListedPlayers = {}
	
	local funcs = {
		'AwardDkp', fRaid.Raid.raidobj.AwardDkp
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
	for name,data in pairs(self.Data.RaiderList) do
		--check if they were in the raid duringn timestamp
		print(name)
		--award them amount dkp
		print(data)
	end
end
