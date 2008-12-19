fRaidLoot = {}
local addon = fRaidLoot
local NAME = 'fRaidLoot'
local db = {}
local needRefresh = true

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
	fRaidLoot.Refresh()
end

function fRaidLoot.GetInfo(id)
	for idx,info in ipairs(db.items) do
		if info.id == id then
			return info
		end
	end
end

--a and b are iteminfos
local sortkeeper = {
	{asc = false, issorted = false},
	{asc = false, issorted = false},
	{asc = false, issorted = false}
}
local function lootcomparer(a, b)
	if a== nil or b == nil then
		return true
	end
	
	local SORT = 1
	local SORT_ASC = false
	for idx,keeper in ipairs(sortkeeper) do
		if keeper.issorted then
			SORT = idx
			SORT_ASC = keeper.asc
		end
	end
	
	local ret = true
	if SORT == 3 then
		if a.maxdkp == b.maxdkp then
			if a.rarity == b.rarity then
				ret = a.name > b.name
			else
				ret = a.rarity < b.rarity
			end								
		else
			ret = a.maxdkp < b.maxdkp
		end
	elseif SORT == 2 then
		if a.mindkp == b.mindkp then
			if a.rarity == b.rarity then
				ret = a.name > b.name
			else
				ret = a.rarity < b.rarity
			end		
		else
			ret = a.mindkp < b.mindkp
		end
	else
		if a.rarity == b.rarity then
			ret = a.name > b.name
		else
			ret = a.rarity < b.rarity
		end
	end
	
	if SORT_ASC then
		return not ret
	else
		return ret
	end
end

function fRaidLoot.Sort(colnum)
	if sortkeeper[colnum].issorted then
		sortkeeper[colnum].asc = not sortkeeper[colnum].asc
		table.sort(db.items, lootcomparer)
	else
		sortkeeper[colnum].asc = false
		for idx,keeper in ipairs(sortkeeper) do
			keeper.issorted = false
		end
		sortkeeper[colnum].issorted = true
		table.sort(db.items, lootcomparer)
	end
	
	--refresh gui...
	fRaidLoot.Refresh()
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

		mw:SetWidth(375)
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
		
		--Some functions for mainwindow
		function mw:SaveLocation()
			db.gui.x = self:GetLeft()
			db.gui.y = self:GetTop()
		end
		
		mw.currentrow = 1
		function mw:LoadRows(j)
			mw.currentrow = j
			mw.slider:SetMinMaxValues(1, #db.items - rowcount + 1)
			local iteminfo, text, min, max
			local z = 1
			for i = j, j + rowcount -1 do
				iteminfo = db.items[i]
				if iteminfo then
					text = iteminfo.link
					min = tonumber(iteminfo.mindkp)
					max = tonumber(iteminfo.maxdkp)
				else
					text = ''
				end
				
				if text ~= '' then
					mw.buttons[z]:SetText(text)
					mw.editboxes1[z]:SetNumber(min)
					mw.editboxes2[z]:SetNumber(max)
					mw.buttons[z]:Show()
					mw.editboxes1[z]:Show()
					mw.editboxes2[z]:Show()
					mw.buttons[z].itemindex = i
					mw.editboxes1[z].itemindex = i
					mw.editboxes2[z].itemindex = i
				else
					mw.buttons[z]:Hide()
					mw.editboxes1[z]:Hide()
					mw.editboxes2[z]:Hide()
				end
				
				z = z + 1
			end
		end
		function mw:Refresh()
			self:LoadRows(mw.currentrow)
		end
		
		--Scripts for mainwindow
		mw:SetScript('OnShow', function()
			tinsert(UISpecialFrames,this:GetName())
			
		end)
		mw:SetScript('OnHide', function()
			this:SaveLocation()
		end)
		
		--Separators
		mw.separators= {}
		local tex
		
		--Column Headers
		--3 columns: Item, MinDKP, MaxDKP
		mw.headers= {}
		local b
		for i = 1, 3 do
			b = fLib.GUI.CreateActionButton(mw)
			tinsert(mw.headers,b)
			b:GetFontString():SetJustifyH('LEFT')
			if i == 1 then
				b:SetPoint('TOPLEFT', x, -y)
				y = y + b:GetHeight() + padding
			else
				b:SetPoint('TOPLEFT', mw.headers[i-1], 'TOPRIGHT', 0,0)
			end
			b:SetHeight(12)
			
			b:SetScript('OnClick', function() fRaidLoot.Sort(i) end)
		end
		
		mw.headers[1]:SetText('Item')
		mw.headers[1]:SetWidth(200)
		mw.headers[2]:SetText('MinDKP')
		mw.headers[2]:SetWidth(75)
		mw.headers[3]:SetText('MaxDKP')
		mw.headers[3]:SetWidth(75)
		
		tex = fLib.GUI.CreateSeparator(mw)
		tex:SetWidth(mw:GetWidth()- 32)
		tex:SetPoint('TOPLEFT', mw.headers[1], 'BOTTOMLEFT', 0,-2)
		tinsert(mw.separators, tex)
		
		--Column 1: Item Links
		mw.buttons= {}
		for i = 1, rowcount do
			b = fLib.GUI.CreateActionButton(mw)
			tinsert(mw.buttons, b)
			
			b:GetFontString():SetAllPoints()
			b:GetFontString():SetJustifyH('LEFT')
			b:SetText('test')
			b:SetHeight(b:GetTextHeight())
			
			if i == 1 then
				b:SetPoint('TOPLEFT', mw.headers[1], 'BOTTOMLEFT', 0, -4)
				b:SetPoint('TOPRIGHT', mw.headers[1], 'BOTTOMRIGHT', 0, -4)
			else
				b:SetPoint('TOPLEFT', mw.buttons[i-1], 'BOTTOMLEFT', 0, -4)
				b:SetPoint('TOPRIGHT', mw.buttons[i-1], 'BOTTOMRIGHT', 0, -4)
			end
			
			tex = fLib.GUI.CreateSeparator(mw)
			tex:SetWidth(mw:GetWidth()- 32)
			tex:SetPoint('TOPLEFT', b, 'BOTTOMLEFT', 0,-2)
			tinsert(mw.separators, tex)
			
			b.itemindex= 0
			b:SetScript('OnEnter', function()
				GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
				GameTooltip:SetPoint('RIGHT', mw, 'LEFT', 0, 0)
				GameTooltip:SetHyperlink('item:'..db.items[this.itemindex].id)
			end)
			b:SetScript('OnLeave', function()
				GameTooltip:FadeOut()
			end)
		end
		
		--Column 2: Min DKP
		mw.editboxes1= {}
		local eb
		for i = 1, rowcount do
			eb = fLib.GUI.CreateEditBox2(mw, 'min')
			tinsert(mw.editboxes1, eb)
			
			eb:SetWidth(100)
			eb:SetNumeric(true)			
			
			if i == 1 then
				eb:SetPoint('TOPLEFT', mw.headers[2], 'BOTTOMLEFT', 0, -2)
				eb:SetPoint('TOPRIGHT', mw.headers[2], 'BOTTOMRIGHT', 0, -2)
				
			else
				eb:SetPoint('TOPLEFT', mw.editboxes1[i-1], 'BOTTOMLEFT', 0, -2)
				eb:SetPoint('TOPRIGHT', mw.editboxes1[i-1], 'BOTTOMRIGHT', 0, -2)
			end
			
			eb.itemindex= 0
			eb:SetScript('OnEnterPressed', function()
				--save new value
				db.items[this.itemindex].mindkp = this:GetNumber()
				this:SetNumber(db.items[this.itemindex].mindkp)
				this:ClearFocus()
			end)
			eb:SetScript('OnEscapePressed', function()
				--restore old value
				this:SetNumber(db.items[this.itemindex].mindkp)
				this:ClearFocus()
			end)
			eb:SetScript('OnEditFocusLost', function()
				--restore old value
				this:SetNumber(db.items[this.itemindex].mindkp)
			end)
		end
		
		--Column 3: Max DKP
		mw.editboxes2= {}
		for i = 1, rowcount do
			eb = fLib.GUI.CreateEditBox2(mw, 'max')
			tinsert(mw.editboxes2, eb)
			
			eb:SetWidth(100)
			eb:SetNumeric(true)
			
			if i == 1 then
				eb:SetPoint('TOPLEFT', mw.headers[3], 'BOTTOMLEFT', 0, -2)
				eb:SetPoint('TOPRIGHT', mw.headers[3], 'BOTTOMRIGHT', 0, -2)
			else
				eb:SetPoint('TOPLEFT', mw.editboxes2[i-1], 'BOTTOMLEFT', 0, -2)
				eb:SetPoint('TOPRIGHT', mw.editboxes2[i-1], 'BOTTOMRIGHT', 0, -2)
			end
			
			eb.itemindex= 0
			eb:SetScript('OnEnterPressed', function()
				--save new value
				db.items[this.itemindex].maxdkp = this:GetNumber()
				this:SetNumber(db.items[this.itemindex].maxdkp)
				this:ClearFocus()
			end)
			eb:SetScript('OnEscapePressed', function()
				--restore old value
				this:SetNumber(db.items[this.itemindex].maxdkp)
				this:ClearFocus()
			end)
			eb:SetScript('OnEditFocusLost', function()
				--restore old value
				this:SetNumber(db.items[this.itemindex].mindkp)
			end)
		end
		
		--Scroll bar
		local slider = CreateFrame('slider', nil, mw)
		mw.slider= slider
		slider:SetOrientation('VERTICAL')
		slider:SetMinMaxValues(1, #db.items - rowcount + 1)
		slider:SetValueStep(1)
		slider:SetValue(1)
		
		slider:SetWidth(12)
		slider:SetHeight(mw:GetHeight())
		
		slider:SetPoint('TOPLEFT', mw.headers[3], 'BOTTOMRIGHT', 0, 4)
		slider:SetPoint('BOTTOMLEFT', mw.editboxes2[rowcount], 'BOTTOMRIGHT', 0, -8)
		
		slider:SetThumbTexture('Interface/Buttons/UI-SliderBar-Button-Vertical')
		slider:SetBackdrop({
			  bgFile='Interface/Buttons/UI-SliderBar-Background',
			  edgeFile = 'Interface/Buttons/UI-SliderBar-Border',
			  tile = true,
			  tileSize = 8,
			  edgeSize = 8,
			  insets = {left = 3, right = 3, top = 3, bottom = 3}
			  --insets are for the bgFile
		})

		slider:SetScript('OnValueChanged', function()
			mw:LoadRows(this:GetValue())
		end)
		
		mw:EnableMouseWheel(true)
		mw:SetScript('OnMouseWheel', function(this,delta)
			local current = this.slider:GetValue()
			local min,max = this.slider:GetMinMaxValues()
			if delta < 0 then
				current = current + 3
				if current > max then
					current = max
				end
				this.slider:SetValue(current)
			elseif delta > 0 then
				current = current - 3
				if current < min then
					current = min
				end
				this.slider:SetValue(current)
			end
		end)
		
		--load initial rows
		mw:LoadRows(1)
	end
	addon.GUI:Toggle()
end
function fRaidLoot.Refresh()
	if addon.GUI then
		if addon.GUI:IsVisible() then
			addon.GUI:Refresh()
			needRefresh = false
			return
		end
	end
	needRefresh = true
end