-- Author      : Jessica Chen Huang
-- Create Date : 1/2/2009 10:47:12 PM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.ItemList
--fRaid.db.globa.ItemListIndex
--fRaid.db.global.ItemListIndexCount
--fRaid.GUI2.ItemFrame

--Goals:
--  Keeps a listing of items and their min dkp and any other data might add later

--Data Structures:
--  ItemList - table, key = item id, value = item data
--  item data - list, {name, link, rarity, mindkp}

--fRaid.db.global.Item.ItemList
--fRaid.db.global.Item.Count
--fRaid.db.global.Item.LastModified
--fRaid.GUI2.ItemFrame

fRaid.Item = {}

local function createitemobj(name, link, rar, dkp)
	local obj = {
		name = name,
		link = link,
		rarity = rar,
		mindkp = dkp,
	}
	
	return obj
end

function fRaid.Item.Count(recount)
    if recount then
        local count = 0
        for id, data in pairs(fRaid.db.global.Item.ItemList) do
            count = count + 1
        end
        fRaid.db.global.Item.Count = count
    end
    
    return fRaid.db.global.Item.Count
end



function fRaid.Item.GetObjectByLink(itemlink, createnew)
	--extract id
	local itemid = fRaid:ExtractItemId(itemlink)
	return fRaid.Item.GetObjectById(itemid, createnew)
end

--returns itemobj
function fRaid.Item.GetObjectById(itemid, createnew)
    local obj = fRaid.db.global.Item.ItemList[itemid]
    if not obj and createnew then
		--save
		local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemid)

		obj = createitemobj(itemName, itemLink, itemRarity, 0)
		fRaid.db.global.Item.ItemList[itemid] = obj
		fRaid.db.global.Item.Count = fRaid.db.global.Item.Count + 1
		fRaid.db.global.Item.LastModified = fLib.GetTimestamp()
	end
	return obj
end

--add items in the currently open loot window
function fRaid.Item.Scan()
	for i = 1, GetNumLootItems() do
		if LootSlotIsItem(i) then
--			fRaid:Debug('Found slot ' .. i .. ' ' .. GetLootSlotLink(i))
			fRaid.Item.GetObjectByLink(GetLootSlotLink(i), true)
		end
	end
end


function fRaid.Item.View()
	local mf = fRaid.GUI2.ItemFrame
	
	if not mf.viewedonce then
		--create index table
		mf.index_to_id = {}
		mf.lastmodified = 0--fRaid.db.global.Item.LastModified
        mf.table = fLibGUI.Table.CreateTable(mf, mf:GetWidth() - 10, 200, 4)
        
        function mf:RetrieveData(index)
            if not index or index < 1 then
                index = self.table.selectedindex
            end
            
            local id, data
            id = self.index_to_id[index]
            data = fRaid.db.global.Item.ItemList[id]
            
            return id, data
        end
        
        function mf:RefreshIndex(force)
            if mf.lastmodified ~= fRaid.db.global.Item.LastModified or force then
                table.wipe(mf.index_to_id)
                mf.lastmodified = fRaid.db.global.Item.LastModified
                
                for id, data in pairs(fRaid.db.global.Item.ItemList) do
                    tinsert(mf.index_to_id, id)
                end
                
                local max = #mf.index_to_id - mf.table.rowcount + 1
                if max < 1 then
                    max = 1
                end
                mf.table.slider:SetMinMaxValues(1, max)
                mf.sortdirty = true
            end
        end

		--click on a header
		function mf:ClickHeader()
			mf.sortdirty = true
			self:Sort()
			self:LoadRows()
		end
		
		--click on a row
		function mf:ClickRow()
            self:RefreshDetails()
		end
		
		--scroll
		function mf:Scroll()
            self:LoadRows()
		end


		function mf:LoadRows(startingindex)
			--print('Loading rows...')
			if startingindex then
                self.table.startingindex = startingindex
			end
			
			self:RefreshIndex()
			self:Sort()
			
			local name, data
			local index = self.table.startingindex
			
			local searchmatch = false
			local searchnum, searchname
			searchnum = tonumber(self.search)
			searchname = strlower(self.search)
			
			local selectedindexfound = false
			local exactmatchindex = 0
			local exactmatchrow = 0
			
			for i = 1, self.table.rowcount do
				--search
				searchmatch = false
				while not searchmatch do
					id, data = self:RetrieveData(index)
					if self.search == '' or not data then
						searchmatch = true
					else
						if id == searchnum then
							searchmatch = true
						elseif strfind(strlower(data.name), searchname, 1, true) then
							searchmatch = true
							if strlower(data.name) == strlower(searchname) then
								exactmatchrow = i
								exactmatchindex = index
							end
						else
							index = index + 1
						end
					end
				end
			
				if not data then
					for j = 1, self.table.colcount do
						self.table.columns[j].cells[i]:SetText('')
					end
				
					self.table.rowbuttons[i]:Hide()
					self.table.rowbuttons[i].index = 0
				else
					--fill in cells with stuff
					self.table.columns[1].cells[i]:SetText(data.name)
					self.table.columns[2].cells[i]:SetText(data.mindkp)
					self.table.columns[3].cells[i]:SetText(data.rarity)
					self.table.columns[4].cells[i]:SetText(id)
					
					--attach correct indexnum to rowbutton
					self.table.rowbuttons[i]:Show()
					self.table.rowbuttons[i].index = index
					
					if index == self.table.selectedindex then
						self.table.rowbuttons[i].highlightspecial:Show()
						selectedindexfound = true
					else
						self.table.rowbuttons[i].highlightspecial:Hide()
					end
				end
				index = index + 1
			end
			
			if exactmatchrow > 0 then
				--print('exact match at ', exactmatchindex)
				self.table.rowbuttons[exactmatchrow].highlightspecial:Show()
				self.table.selectedindex = exactmatchindex
				self:RefreshDetails()
			elseif not selectedindexfound then
				self.table.selectedindex = 0
				self:RefreshDetails()
			end
		end

		function mf:Refresh()
			mf:LoadRows()
		end

		function mf:RefreshDetails()
			local id, data = self:RetrieveData()
			if id and data then
				self.title_name:SetText(id)
				self.title_dkp:SetText(data.mindkp)
			else
				self.title_name:SetText('')
				self.title_dkp:SetText('')
			end
		end

		mf.sortdirty = true
		mf.sortkeeper = {
			{asc = false, issorted = false, name = 'Name'},
			{asc = false, issorted = false, name = 'Dkp'},
			{asc = false, issorted = false, name = 'Rarity'},
			{asc = false, issorted = false, name = 'Id'},
		}
		function mf.lootcomparer(a, b) --a and b are ids (key for ItemList)
			--retrieve data
			local adata = fRaid.db.global.Item.ItemList[a]
			local bdata = fRaid.db.global.Item.ItemList[b]
			
			--find the sorted column and how it is sorted
			local SORT = mf.table.selectedcolnum
			local SORT_ASC = mf.sortkeeper[SORT].asc
			local SORT_NAME = mf.sortkeeper[SORT].name
			
			local ret = true
			if SORT_NAME == 'Id' then
				ret = a > b
			elseif SORT_NAME == 'Rarity' then
				if adata.rarity == bdata.rarity then
					ret = adata.name > bdata.name
				else
					ret = adata.rarity < bdata.rarity
				end
			elseif SORT_NAME == 'Dkp' then
				if adata.mindkp == bdata.mindkp then
					ret = adata.name > bdata.name
				else
					ret = adata.mindkp < bdata.mindkp
				end
			else
				ret = adata.name > bdata.name
			end
	
			if SORT_ASC then
				return not ret
			else
				return ret
			end
		end
	
		function mf:Sort(colnum)
			if colnum then
				mf.table.selectedcolnum = colnum
				mf.sortdirty = true
			end
	
			if mf.sortdirty then
				colnum = mf.table.selectedcolnum
				if mf.sortkeeper[colnum].issorted then
					--toggle ascending / descending sort
					mf.sortkeeper[colnum].asc = not mf.sortkeeper[colnum].asc
				else
					mf.sortkeeper[colnum].asc = true
					for idx,keeper in ipairs(mf.sortkeeper) do
						keeper.issorted = false
					end
					mf.sortkeeper[colnum].issorted = true
				end
				table.sort(mf.index_to_id, mf.lootcomparer)
			end
			
			mf.sortdirty = false
		end
	
		local function np(name)
		--[[
			fRaid.Player.AddDkp(name, 0, 'new player')
			
			mf.eb_search:SetText()
			mf.eb_search.newbutton:Hide()
			mf.sortdirty = true
	
			mf:Refresh()
			--]]
		end
		function mf:NewPlayer(name)
		fRaid:ConfirmDialog2('Not yet implemented', np, name)
		--[[
			if not name or name == '' then
				name = self.eb_search:GetText()
			end
			fRaid:ConfirmDialog2('Add new player: ' .. name .. '?', np, name)
			--]]
		end
	
		mf.table:AddHeaderClickAction(mf.ClickHeader, mf)
		mf.table:AddRowClickAction(mf.ClickRow, mf)
		mf.table:AddScrollAction(mf.Scroll, mf)
	
		--fill in headers
		local i = 1
		mf.table.columns[i].headerbutton:SetText('Name')
		mf.table.columns[i]:SetWidth(220)
		i = i + 1
		mf.table.columns[i].headerbutton:SetText('Dkp')
		mf.table.columns[i]:SetWidth(50)
		i = i + 1
		mf.table.columns[i].headerbutton:SetText('Rarity')
		mf.table.columns[i]:SetWidth(40)
		i = i + 1
		mf.table.columns[i].headerbutton:SetText('Id')
		mf.table.columns[i]:SetWidth(75)
		i = i + 1
		
		--separator
		ui = fLibGUI.CreateSeparator(mf)
		ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.table.height)
		ui:SetWidth(mf.table.width)
		prevui = ui
		
		--Search/Name box
		ui = fLibGUI.CreateEditBox(mf, 'Name')
		mf.eb_search = ui
		mf.search = ''
		ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
		ui:SetWidth(mf.table.width)
		ui:SetScript('OnEnterPressed', function(this)
		    this:ClearFocus()
		    if mf.table.selectedindex == 0 then
		    	mf:NewPlayer()
		    end
	    end)
    	ui:SetScript('OnTextChanged', function(this)
	        --print('text changed')
	        if this:GetText() ~= mf.search then
		        mf.table.selectedindex = 0
		        mf:RefreshDetails()
		        mf.search = this:GetText()
		        mf:LoadRows()
		        if mf.table.selectedindex == 0 and mf.search ~= '' then
			        this.newbutton:Show()
			    else
			    	this.newbutton:Hide()
		    	end
	    	end
	    end)
	    prevui = ui
	    
	    ui = fLibGUI.CreateActionButton(mf)
	    mf.eb_search.newbutton = ui
	    ui:SetText('New')
	    ui:SetFrameLevel(4)
	    ui:SetWidth(ui:GetTextWidth())
	    ui:SetHeight(ui:GetTextHeight())
	    ui:SetScript('OnClick', function(this) mf:NewPlayer() end)
	    ui:SetPoint('RIGHT', mf.eb_search, 'RIGHT', -4, 0)
	    ui:Hide()
    
    
	    --Item Details
	    ui = fLibGUI.CreateLabel(mf)
	    ui:SetPoint('TOPLEFT', mf.eb_search, 'BOTTOMLEFT', 0, -5)
	    ui:SetText('Id: ')
	    prevui = ui
	    
	    mf.title_name = fLibGUI.CreateLabel(mf)
	    mf.title_name:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
	    mf.title_name:SetText('')
	    
	    ui = fLibGUI.CreateLabel(mf)
	    ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
	    ui:SetText('Dkp:')
	    prevui = ui
	    
	    mf.title_dkp = fLibGUI.CreateLabel(mf)
	    mf.title_dkp:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
	    mf.title_dkp:SetText('')
            
        mf.viewedonce = true
	end

	mf:Refresh()
	mf:Show()
end

