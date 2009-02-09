-- Author      : Jessica Chen Huang
-- Create Date : 1/2/2009 10:47:12 PM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.ItemList
--fRaid.db.globa.ItemListIndex
--fRaid.db.global.ItemListIndexCount
--fRaid.GUI2.ItemFrame

fRaid.Item = {}

--retrieves index of the itemobj with itemid
function fRaid.Item.ItemIdToIndex(itemid)
	if not fRaid.db.global.ItemListIndex then
		fRaid.Item.RefreshIndex()
	else
		return fRaid.db.global.ItemListIndex[itemid]
	end
end

--recreates the ItemListIndex (maps itemid to index)
function fRaid.Item.RefreshIndex(announceduplicates)
	if not fRaid.db.global.ItemListIndex then
		fRaid.db.global.ItemListIndex = {}
	else
		wipe(fRaid.db.global.ItemListIndex)
		fRaid.db.global.ItemListIndexCount = 0
	end
	local count = 0
	for idx, obj in ipairs(fRaid.db.global.ItemList) do
		if obj.isvalid then
			if fRaid.db.global.ItemListIndex[obj.id] and announceduplicates then
				fRaid:Print('ERROR: duplicate item found.  ID:', obj.id, ', index:', idx, '.')
			end
			fRaid.db.global.ItemListIndex[obj.id] = idx
			count = count + 1
		end
	end
	fRaid.db.global.ItemListIndexCount = count
end

function fRaid.Item.GetCount()
	return fRaid.db.global.ItemListIndexCount
end

--returns an itemobj
function fRaid.Item.GetObjectByIndex(idx)
	return fRaid.db.global.ItemList[idx]
end

function fRaid.Item.GetObjectByLink(itemlink, createnew)
	--extract id
	local itemid = fRaid:ExtractItemId(itemlink)
	
	return fRaid.Item.GetObjectById(itemid, createnew)
end

--returns itemobj, idx
function fRaid.Item.GetObjectById(itemid, createnew)
	local obj, idx
	idx = fRaid.Item.ItemIdToIndex(itemid)
	if idx then
		obj = fRaid.db.global.ItemList[idx]
		if not obj then
			--something is wrong with IndexList
			fRaid.Item.RefreshIndex()
			idx = fRaid.Item.ItemIdToIndex(itemid)
			obj = fRaid.db.global.ItemList[idx]
		end
	end
	
	if not obj and createnew then
		--save
		local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemid)

		obj = {
			id = itemid,
			name = itemName,
			link = itemLink,
			rarity = itemRarity,
			mindkp = 0,
			bossIdxList = {},
			isvalid = true
		}
		tinsert(fRaid.db.global.ItemList, obj)
		
		--update IndexList
		idx = #fRaid.db.global.ItemList
		fRaid.db.global.ItemListIndex[itemid] = idx
	end
	return obj, idx
end

function fRaid.Item.RemoveById(itemid)
	local obj, idx = fRaid.Item.GetObjectById(itemid)
	if obj then
		--remove from bosses that it belongs to
		local bossobj
		for _, bossidx in ipairs(obj.bossIdxList) do
			bossobj = fRaid.Boss.GetObjectByIndex(bossidx)
			for qidx, itemidx in ipairs(bossobj.itemIdxList) do
				if itemidx == idx then
					tremove(bossobj.itemIdxList, qidx)
					break
				end
			end
		end
		
		--delete
		obj.isvalid = false
		--remove from index
		fRaid.db.global.ItemListIndex[obj.id] = nil
	end
end

--add items in the currently open loot window
function fRaid.Item.Scan()
	for i = 1, GetNumLootItems() do
		if LootSlotIsItem(i) then
			fRaid:Debug('Found slot ' .. i .. ' ' .. GetLootSlotLink(i))
			fRaid.Item.GetObjectByLink(GetLootSlotLink(i), true)
		end
	end
end

--[[
function fRaid.Item.GetInfo(id)
	local items = fRaid.db.global.ItemList
	for idx,info in ipairs(items) do
		if info.id == id then
			return info
		end
	end
end
--]]


function fRaid.Item.View()
	local mf = fRaid.GUI2.ItemFrame
	
	if not mf.viewedonce then
		local b, eb, tex, ix, ui
		mf.rowheight= 12
		mf.startingrow = 1
		mf.availablerows = 15

		mf.mincolwidth = 20
		mf.mincolheight = mf.rowheight * mf.availablerows + mf.availablerows + mf.rowheight
		--#rows times height of each row plus 1 for each separator plus header row
		mf.maxwidth = mf:GetWidth() - 25

		--create ListIndex for sorting
		mf.ListIndex = {}
		mf.selectedindexnum = 0
		mf.previtemlistcount = 0
		
		mf.prevsortcol = 1
		
		function mf:SelectedData(indexnum)
			local itemnum, itemobj
			if not indexnum or indexnum < 1 then
				indexnum = mf.selectedindexnum
			end
			
			itemnum = mf.ListIndex[indexnum]
			itemobj = fRaid.Item.GetObjectByIndex(itemnum)
			--fRaid.db.global.ItemList[itemnum]
			return itemnum, itemobj
		end
		
		--create ui elements
		
		--table with 4 columns
		--Name, MinDkp, Rarity, Id
		
		
		mf.columnframes = {}	
		local currentframe	
		for i = 1, 3 do
			currentframe = fLibGUI.CreateClearFrame(mf)
			tinsert(mf.columnframes, currentframe)
			
			currentframe.enable = true
			
			currentframe:SetHeight(mf.mincolheight)
			currentframe:SetResizable(true)
			currentframe:SetMinResize(mf.mincolwidth, mf.mincolheight)
			
			--header button
			b = fLibGUI.CreateActionButton(currentframe)
			currentframe.headerbutton = b
			b.colnum = i
			b:GetFontString():SetJustifyH('LEFT')
			b:SetHeight(mf.rowheight)
			b:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 0, 0)
			b:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -4, 0)
			b:SetText('test')
			
			b:SetScript('OnClick', function()
				mf:Sort(this.colnum)
				mf:LoadRows()
			end)			
			
			--resize button
			b = fLibGUI.CreateActionButton(currentframe)
			currentframe.resizebutton = b
			b:GetFontString():SetJustifyH('LEFT')
			b:SetWidth(4)
			b:SetHeight(mf.mincolheight)
			b:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', 0,0)
			b:RegisterForDrag('LeftButton')
			
			b:SetScript('OnDragStart', function(this, button)
				this:GetParent():StartSizing('RIGHT')
				this.highlight:Show()
			end)
			b:SetScript('OnDragStop', function(this, button)
				this:GetParent():StopMovingOrSizing()
				this.highlight:Hide()
				mf:ResetColumnFramePoints()
			end)
			
			--cell labels
			currentframe.cells = {}
			for j = 1, mf.availablerows do
				ui = fLibGUI.CreateLabel(currentframe)
				tinsert(currentframe.cells, ui)
				ui:SetJustifyH('LEFT')
			end
		end
		
		mf.columnframes[1].headerbutton:SetText('Name')
		mf.columnframes[1]:SetWidth(275)
		mf.columnframes[2].headerbutton:SetText('MinDkp')
		mf.columnframes[2]:SetWidth(50)
		mf.columnframes[3].headerbutton:SetText('Rarity')
		mf.columnframes[3]:SetWidth(50)
		--mf.columnframes[4].headerbutton:SetText('Id')
		--mf.columnframes[4]:SetWidth(75)
		
		--rowbutton for each row
		mf.rowbuttons = {}
		local rowoffset = 0
		for i = 1, mf.availablerows do
			rowoffset = mf.rowheight * i + i
			
			--separator
			tex = fLibGUI.CreateSeparator(mf)
			tex:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - rowoffset)
			tex:SetWidth(mf.maxwidth)
			
			--rowbutton
			b = fLibGUI.CreateActionButton(mf)
			tinsert(mf.rowbuttons, b)

			b.indexnum = 0
			
			b:SetFrameLevel(4)
			b:GetFontString():SetJustifyH('LEFT')
			b:SetHeight(mf.rowheight)
			b:SetWidth(mf.maxwidth)
			b:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -6-rowoffset)
			--b:SetPoint('TOPRIGHT', mf, 'TOPRIGHT', -5, -6-rowoffset)
			
			b.highlightspecial = b:CreateTexture(nil, "BACKGROUND")
			b.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			b.highlightspecial:SetBlendMode("ADD")
			b.highlightspecial:SetAllPoints(b)
			b.highlightspecial:Hide()
			
			b:SetScript('OnClick', function()
				--unselect all the other rows
				for i = 1, mf.availablerows do
					mf.rowbuttons[i].highlightspecial:Hide()
				end
				
				--select this row
				this.highlightspecial:Show()
				mf.selectedindexnum = this.indexnum
				
				--fill in details
				mf:RefreshDetails()
			end)
			
			b:SetScript('OnEnter', function()
				this.highlight:Show()
				GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
				GameTooltip:SetPoint('LEFT', mf, 'RIGHT', 0, 0)
				local itemnum, itemobj = mf:SelectedData(this.indexnum)
				if itemobj then
					GameTooltip:SetHyperlink('item:'..itemobj.id)
				end
			end)
			b:SetScript('OnLeave', function()
				this.highlight:Hide()
				GameTooltip:FadeOut()
			end)
			
			--cell location for each column
			for j = 1, #mf.columnframes do
				currentframe = mf.columnframes[j]
				ui = currentframe.cells[i]
				ui:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 5, -rowoffset)
				ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -5, -rowoffset)
			end
		end
		
		--function for resizing columns
		function mf:ResetColumnFramePoints()
			local enabledcolumns = {}
			for i = 1, #mf.columnframes do
				if mf.columnframes[i].enable then
					tinsert(enabledcolumns, i)
				end
			end
			
			local firstcolumndone = false
			local runningwidth = 0
			local currentcol, currentframe, prevframe, maxw, curw
			for i = 1, #enabledcolumns do
				currentcol = enabledcolumns[i]
				currentframe = mf.columnframes[currentcol]

				if not firstcolumndone then
					currentframe:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -5)
					firstcolumndone = true
				else
					currentframe:SetPoint('TOPLEFT', prevframe, 'TOPRIGHT', 0,0)
				end
				
				--calculate allowed width, current width
				maxw = mf.maxwidth - runningwidth - (mf.mincolwidth * (#enabledcolumns - i))
				curw = currentframe:GetRight() - currentframe:GetLeft()
				--check if its larger than allowed width
				if curw > maxw then
					currentframe:SetWidth(maxw)	
				end
				runningwidth = runningwidth + currentframe:GetWidth()

				prevframe = currentframe
			end
			
			if #enabledcolumns > 0 then
				currentcol = enabledcolumns[#enabledcolumns]
				currentframe = mf.columnframes[currentcol]
				currentframe:SetPoint('TOPRIGHT', mf, 'TOPLEFT', mf.maxwidth + 5, -5)
			end
		end
		
		mf:ResetColumnFramePoints()
		
		--Scroll bar
		ui = CreateFrame('slider', nil, mf)
		mf.slider = ui
		ui:SetFrameLevel(5)
		ui:SetOrientation('VERTICAL')
		ui:SetMinMaxValues(1, 1)
		ui:SetValueStep(1)
		ui:SetValue(1)
		
		ui:SetWidth(10)
		ui:SetHeight(mf.mincolheight + mf.rowheight)
		
		ui:SetPoint('TOPRIGHT', mf, 'TOPRIGHT', -5, -5)
		
		ui:SetThumbTexture('Interface/Buttons/UI-SliderBar-Button-Horizontal')
		ui:SetBackdrop({
			  bgFile='Interface/Buttons/UI-SliderBar-Background',
			  edgeFile = 'Interface/Buttons/UI-SliderBar-Border',
			  tile = true,
			  tileSize = 8,
			  edgeSize = 8,
			  insets = {left = 3, right = 3, top = 3, bottom = 3}
			  --insets are for the bgFile
		})

		ui:SetScript('OnValueChanged', function()
			mf:LoadRows(this:GetValue())
		end)
		
		mf:EnableMouseWheel(true)
		mf:SetScript('OnMouseWheel', function(this,delta)
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
		
		--separator
		tex = fLibGUI.CreateSeparator(mf)
		tex:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.mincolheight)
		tex:SetWidth(mf.maxwidth)
		
		--Search box
		ui = fLibGUI.CreateEditBox(mf, 'Search')
		mf.eb_search = ui
		mf.search = ''
		ui:SetPoint('TOPLEFT', tex, 'BOTTOMLEFT', 0, -5)
		ui:SetWidth(mf.maxwidth)
		ui:SetScript('OnEnterPressed', function()
			this:ClearFocus()
		end)
		ui:SetScript('OnTextChanged', function()
			if this:GetText() ~= mf.search then
				mf.search = this:GetText()
				mf:LoadRows()
			end
		end)
		
		--Total Count
		ui = fLibGUI.CreateLabel(mf)
		ui:SetPoint('TOPRIGHT', mf.eb_search, 'BOTTOMRIGHT', -40, -5)
		ui:SetText('Total: ')
		local prevui = ui
		
		mf.title_total = fLibGUI.CreateLabel(mf)
		mf.title_total:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		mf.title_total:SetText('rfg')
		
		----------------
		--Item Details--
		----------------
		--NAME
		ui = fLibGUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', mf.eb_search, 'BOTTOMLEFT', 0, -5)
		ui:SetText('Name: ')
		prevui = ui
		
		mf.title_name = fLibGUI.CreateLabel(mf)
		mf.title_name:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		mf.title_name:SetText('')
		
		--ID
		ui = fLibGUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
		ui:SetText('Id:')
		prevui = ui
		
		mf.title_id = fLibGUI.CreateLabel(mf)
		mf.title_id:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		
		--Min DKP
		ui = fLibGUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
		ui:SetText('Min Dkp')
		prevui = ui
		
		ui = fLibGUI.CreateEditBox2(mf, '#')
		mf.eb_mindkp = ui
		ui:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		ui:SetWidth(60)
		ui:SetNumeric(true)
		ui:SetNumber(0)
		ui:SetScript('OnEnterPressed', function() 
			local itemnum, itemobj = mf:SelectedData()
			if itemobj then
				itemobj.mindkp = this:GetNumber()
			end
			
			this:ClearFocus()
			this:SetNumber(itemobj.mindkp)
			
			--refresh row (just going to refresh entire table)
			mf:Refresh()
		end)


		--REFRESH
		function mf:Refresh()
			--regenerate ItemListIndex if ItemList has changed
			mf:RefreshListIndex()
			mf:LoadRows()
		end
		
		--CALLED BY REFRESH directly or indirectly
		function mf:RefreshDetails()
			local itemnum, itemobj = mf:SelectedData()
			if itemobj then
				mf.title_name:SetText(itemobj.name)
				mf.title_id:SetText(itemobj.id)
				mf.eb_mindkp:SetNumber(itemobj.mindkp)
			else
				mf.title_name:SetText('')
				mf.title_id:SetText('')
				mf.eb_mindkp:SetNumber(0)
			end
		end
		
		--mf.ListIndex is a list of itemidxs
		function mf:RefreshListIndex()
			if mf.previtemlistcount ~= fRaid.Item.GetCount() then
				mf.previtemlistcount = fRaid.Item.GetCount()
				wipe(mf.ListIndex)
				--copy the ItemListIndex
				for _, itemidx in pairs(fRaid.db.global.ItemListIndex) do
					tinsert(mf.ListIndex, itemidx)
				end
				
				local max = #mf.ListIndex - mf.availablerows + 1
				if max < 1 then
					max = 1
				end
				mf.slider:SetMinMaxValues(1, max)
				mf:Sort(mf.prevsortcol)
				
				mf.title_total:SetText(fRaid.Item.GetCount())
			end
			--[[
			if mf.previtemlistcount ~= #fRaid.db.global.ItemList then
				table.wipe(mf.ListIndex)
				mf.previtemlistcount = #fRaid.db.global.ItemList
				local obj, previ
				for i = 1, #fRaid.db.global.ItemList do
					tinsert(mf.ListIndex, i)
				end
				
				local max = #mf.ListIndex - mf.availablerows + 1
				if max < 1 then
					max = 1
				end
				mf.slider:SetMinMaxValues(1, max)
				mf:Sort(mf.prevsortcol)
			end
			--]]
		end

		--a and b are indexes for ItemList
		mf.sortkeeper = {
			{asc = false, dosort = false},
			{asc = false, dosort = false},
			{asc = false, dosort = false},
			--{asc = false, issorted = false}
		}
		function mf.lootcomparer(a, b)
			if a== nil or b == nil then
				return true
			end
			
			if a < 1 or b < 1 then
				return true
			end
			
			--retrieving itemobj
			local aobj = fRaid.Item.GetObjectByIndex(a)--fRaid.db.global.ItemList[a]
			local bobj = fRaid.Item.GetObjectByIndex(b)--fRaid.db.global.ItemList[b]
			
			local SORT = 1
			local SORT_ASC = false
			for idx,keeper in ipairs(mf.sortkeeper) do
				if keeper.dosort then
					SORT = idx
					SORT_ASC = keeper.asc
				end
			end
			
			local ret = true
			if SORT == 3 then
				if aobj.rarity == bobj.rarity then
					SORT_ASC = mf.sortkeeper[1].asc
					ret = aobj.name < bobj.name
				else
					ret = aobj.rarity < bobj.rarity
				end
			elseif SORT == 2 then
				if aobj.mindkp == bobj.mindkp then
					if aobj.name == bobj.name then
						SORT_ASC = mf.sortkeeper[3].asc
						ret = aobj.rarity < bobj.rarity
					else
						SORT_ASC = mf.sortkeeper[1].asc
						ret = aobj.name < bobj.name
					end
				else
					ret = aobj.mindkp > bobj.mindkp
				end
			else
				if aobj.name == bobj.name then
					SORT_ASC = mf.sortkeeper[3].asc
					ret = aobj.rarity < bobj.rarity
				else
					ret = aobj.name < bobj.name
				end
				--[[
				if aobj.rarity == bobj.rarity then
					ret = aobj.name > bobj.name
				else
					SORT_ASC = mf.sortkeeper[3].asc
					ret = aobj.rarity > bobj.rarity
				end
				--]]
			end
			
			if SORT_ASC then
				return ret
			else
				return not ret
			end
		end
		
		function mf:Sort(colnum)
			mf.prevsortcol = colnum
			mf.sortkeeper[colnum].asc = not mf.sortkeeper[colnum].asc
			
			if not mf.sortkeeper[colnum].issorted then
				for idx,keeper in ipairs(mf.sortkeeper) do
					keeper.dosort = false
				end
				mf.sortkeeper[colnum].dosort = true
			end
			
			table.sort(fRaid.GUI2.ItemFrame.ListIndex, mf.lootcomparer)
		end

		function mf:LoadRows(startingindexnum)
			if startingindexnum then
				mf.startingrow = startingindexnum
			end
			
			local itemnum, itemobj
			local indexnum = mf.startingrow
			
			local searchmatch = false
			local searchnum, searchname
			searchnum = tonumber(mf.search)
			searchname = strlower(mf.search)
			
			local selectedindexfound = false
			
			for i = 1, mf.availablerows do
				--search
				searchmatch = false
				while not searchmatch do
					itemnum, itemobj = mf:SelectedData(indexnum)
					if mf.search == '' or not itemobj then
						searchmatch = true
					else
						if itemobj.mindkp == searchnum or itemobj.rarity == searchnum or itemobj.id == searchnum then
							searchmatch = true
						elseif strfind(strlower(itemobj.name), searchname, 1, true) then
							searchmatch = true
						else
							indexnum = indexnum + 1
						end
					end
				end
				
				if not itemobj then
					mf.columnframes[1].cells[i]:SetText('')
					mf.columnframes[2].cells[i]:SetText('')
					mf.columnframes[3].cells[i]:SetText('')
					--mf.columnframes[4].cells[i]:SetText('')
					
					mf.rowbuttons[i]:Hide()
					mf.rowbuttons[i].indexnum = 0
				else
					--fill in the cells with stuff
					--local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemobj.id)
					mf.columnframes[1].cells[i]:SetText(itemobj.link)
					mf.columnframes[2].cells[i]:SetText(itemobj.mindkp)
					mf.columnframes[3].cells[i]:SetText(itemobj.rarity)
					--mf.columnframes[4].cells[i]:SetText(itemobj.id)
					
					--attach correct indexnum to rowbutton
					mf.rowbuttons[i]:Show()
					mf.rowbuttons[i].indexnum = indexnum
					
					if indexnum == mf.selectedindexnum then
						mf.rowbuttons[i].highlightspecial:Show()
						selectedindexfound = true
					else
						mf.rowbuttons[i].highlightspecial:Hide()
					end
				end
				indexnum = indexnum + 1
			end
			
			if not selectedindexfound then
				mf.selectedindexnum = 0
				mf:RefreshDetails()
			end
		end
		
		mf.viewedonce = true
	end

	mf:Refresh()
	mf:Show()
end

