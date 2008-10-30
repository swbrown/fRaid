fRaidMob = {}

--fRaid.db.global.mobs (idx => {id, name, rarity, link, mindkp, maxdkp})

--arg can be an item id (number) or item link (string)
function fRaidMob.Add(arg)
	--extract id
	local id = 0
	if type(arg) == 'number' then
		id = arg
	elseif type(arg) == 'string' then
		local found, _, itemString = string.find(arg, "^|c%x+|H(.+)|h%[.*%]")
		local _, x = strsplit(":", itemString)
		id = x
	end
	
	--check to see if its already saved
	for idx,info in ipairs(fRaid.db.global.items) do
		if info.id == id then
			--don't save
			fRaid:Debug('item '..id..' already exists')
			return
		end
	end
	
	--save
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(id)

	fRaid:Print('Saving '..itemLink)
	tinsert(fRaid.db.global.items, {
		id = id,
		name = itemName,
		link = itemLink,
		rarity = itemRarity,
		mindkp = 0,
		maxdkp = 0,
	})
end

--add items in the currently open loot window
function fRaidMob.Scan(eventName, _, event, _, _, _, _, mob)
	if event ~= "UNIT_DIED" then return end
	if mob then
		print(mob..' killed')
	end
end