fRaidLoot = {}
local addon = fRaidLoot
local NAME = 'fRaidLoot'
local db = {}

function addon:OnInitialize()
	db = fRaid.db.global.fRaidLoot
end

--db.items (idx => {id, name, link, mindkp, maxdkp})

--add items in the currently open loot window
function fRaidLoot.Scan()
	for i = 1, GetNumLootItems() do
		if LootSlotIsItem(i) then
			fRaid:Debug('Found slot ' .. i .. ' ' .. GetLootSlotLink(i))
			fRaidLoot.Add(GetLootSlotLink(i))
		end
	end
end


--arg can be an item id (number) or item link (string)
function fRaidLoot.Add(arg)
	--extract id
	local id = tonumber(arg)
	if not id and type(arg) == 'string' then
		id = fRaid:ExtractItemId(arg)
	else
		error('Invalid arg.  fRaidLoot.Add(arg).  arg should be item id (number) or item link(string)')
	end
	
	--check to see if its already saved
	for idx,info in ipairs(db.items) do
		if info.id == id then
			--don't save
			fRaid:Debug('item '..id..' already exists')
			return
		end
	end
	
	--save
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(id)

	fRaid:Print('Saving '..itemLink)
	tinsert(db.items, {
		id = id,
		name = itemName,
		link = itemLink,
		rarity = itemRarity,
		mindkp = 0,
		maxdkp = 0,
	})
end

function fRaidLoot.GetInfo(id)
	for idx,info in ipairs(db.items) do
		if info.id == id then
			return info
		end
	end
end

local rowcount = 20

function fRaidLoot.View()
	if not addon.GUI then
		local padding = 8
		local x = 8
		local y = 8
		
		--create it
		addon.GUI = fLib.GUI.CreateEmptyFrame(2, NAME .. '_MW')
		local mw = addon.GUI

		mw:SetWidth(300)
		mw:SetHeight(400)
		
		mw:SetPoint('CENTER', -200, 100)
		
		--Title
		fs = fLib.GUI.CreateLabel(mw)
		fs:SetText(NAME)
		fs:SetPoint('TOP', 0, -y)
		y = y + fs:GetHeight() + padding
		
		--Close Button
		button = fLib.GUI.CreateActionButton(mw)
		button:SetText('Close')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:Toggle()
		end)
		button:SetPoint('BOTTOMRIGHT', mw, 'BOTTOMRIGHT', -padding-8, padding+8)
		--button:SetPoint('BOTTOM', 0, padding)
		
		--Some functions for mainwindow
		function mw:SaveLocation()
			db.gui.x = self:GetLeft()
			db.gui.y = self:GetTop()
		end
		--Scripts for mainwindow
		mw:SetScript('OnHide', function()
			this:SaveLocation()
		end)
		
		--Column Headers
		mw.headers= {}
		local fs
		for i = 1, 3 do
			fs = fLib.GUI.CreateLabel(mw)
			tinsert(mw.headers,fs)
			if i == 1 then
				fs:SetPoint('TOPLEFT', x, -y)
				y = y + fs:GetHeight() + padding
			else
				fs:SetPoint('TOPLEFT', mw.headers[i-1], 'TOPRIGHT', 0,0)
			end
		end
		
		mw.headers[1]:SetText('Item')
		mw.headers[2]:SetText('MinDKP')
		mw.headers[3]:SetText('MaxDKP')
				
		mw.buttons= {}
		local b,highlight
		for i = 1, rowcount do
			b = fLib.GUI.CreateActionButton(mw)
			tinsert(mw.buttons, b)
			
			b:SetText('test')
			b:SetWidth(b:GetTextWidth())
			b:SetHeight(b:GetTextHeight())
			
			if i == 1 then
				b:SetPoint('TOPLEFT', mw.headers[1], 'BOTTOMLEFT', 0, -2)
			else
				b:SetPoint('TOPLEFT', mw.buttons[i-1], 'BOTTOMLEFT', 0, -2)
			end
		end
		
		mw.editboxes1= {}
		local eb
		for i = 1, rowcount do
			eb = fLib.GUI.CreateEditBox(mw, 'min')
			tinsert(mw.editboxes1, eb)
			
			eb:SetWidth(100)
			
			if i == 1 then
				b:SetPoint('TOPLEFT', mw.headers[2], 0, -2)
			else
				b:SetPoint('TOPLEFT', mw.editboxes1[i-1], 'BOTTOMLEFT', 0, -2)
			end
		end
		
		mw.ediboxes2= {}
		for i = 1, rowcount do
			eb = fLib.GUI.CreateEditBox(mw, 'max')
			tinsert(mw.ediboxes2, eb)
			
			eb:SetWidth(100)
			
			if i == 1 then
				b:SetPoint('TOPLEFT', mw.headers[3], 0, -2)
			else
				b:SetPoint('TOPLEFT', mw.ediboxes2[i-1], 'BOTTOMLEFT', 0, -2)
			end
		end
	end
	addon.GUI:Toggle()
end