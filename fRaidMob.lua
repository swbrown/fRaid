fRaidMob = {}
local addon = fRaidMob
local NAME = 'fRaidMob'
local db = {}
local needRefresh = true

function addon:OnInitialize()
	--db = fRaid.db.global.fRaidMob
end
--fRaid.db.global.mobs (idx => {id, name, rarity, link, mindkp, maxdkp})

function fRaidMob.Add(mobname, location)
--[[
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
	--]]
end
