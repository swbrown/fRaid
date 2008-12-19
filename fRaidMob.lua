fRaidMob = {}
local addon = fRaidMob
local NAME = 'fRaidMob'
local db = {}
local needRefresh = true

function addon:OnInitialize()
	db = fRaid.db.global.fRaidMob
end
--fRaid.db.global.mobs (idx => {id, name, rarity, link, mindkp, maxdkp})

function fRaidMob.Add(mobname, location)	
	--check to see if its already saved
	for idx,info in ipairs(db.moblist) do
		if info.name == mobname and info.location == location then
			--don't save
			fRaid:Debug('mob ' .. mobname .. ' in ' .. location .. ' already exists.')
			return
		end
	end
	
	--save
	fRaid:Print('Saving '..mobname .. '/' .. location)
	tinsert(db.moblist, {
		name = mobname,
		location = location,
		dkp = 0,
	})
end

--TODO: award dkp to raid if mob is in moblist
function fRaidMob.Scan(eventName, _, event, _, _, _, _, mob)
	if event ~= "UNIT_DIED" then return end
	if mob then
		--save it
		fRaidMob.Add(mob, GetRealZoneText())
		
		--award dkp popup if in raid
		
	end
end
