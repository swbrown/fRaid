-- Author      : Jessica Chen Huang
-- Create Date : 1/7/2009 10:41:06 AM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.RaidList
--fRaid.GUI2.RaidFrame

fRaid.Raid = {}


--==================================================================================================

function fRaid.Raid.View()
	local mf = fRaid.GUI2.RaidFrame
	
	if not mf.viewedonce then
		local ui, prevui
		mf.rowheight = 12
		mf.startingrow = 1
		mf.availablerows = 15

		mf.mincolwidth = 20
		mf.mincolheight = mf.rowheight * mf.availablerows + mf.availablerows + mf.rowheight
		--#rows times height of each row plus 1 for each separator plus header row
		mf.maxwidth = 200

		--create ListIndex
		mf.ListIndex = {}
		mf.selectedindexnum = 0
		mf.prevlistcount = 0
		
		mf.prevsortcol = 1
		
		function mf:SelectedData(indexnum)
			local itemnum, itemobj
			if not indexnum or indexnum < 1 then
				indexnum = mf.selectedindexnum
			end
			
			itemnum = mf.ListIndex[indexnum]
			itemobj = mf.items[itemnum]
			return itemnum, itemobj
		end
		
		--create ui elements
		
		--table with 3 columns
		--Name, Dkp, Attendance, Progression Attendance
		
		
		mf.columnframes = {}	
		local currentframe	
		for i = 1, 2 do
			currentframe = fLib.GUI.CreateClearFrame(mf)
			tinsert(mf.columnframes, currentframe)
			
			currentframe.enable = true
			
			currentframe:SetHeight(mf.mincolheight)
			currentframe:SetResizable(true)
			currentframe:SetMinResize(mf.mincolwidth, mf.mincolheight)
			
			--header button
			ui = fLib.GUI.CreateActionButton(currentframe)
			currentframe.headerbutton = ui
			ui.colnum = i
			ui:GetFontString():SetJustifyH('LEFT')
			ui:SetHeight(mf.rowheight)
			ui:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 0, 0)
			ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -4, 0)
			ui:SetScript('OnClick', function()
				--mf:Sort(this.colnum)
				--mf:LoadRows()
			end)
			
			--resize button
			ui = fLib.GUI.CreateActionButton(currentframe)
			currentframe.resizebutton = ui
			ui:GetFontString():SetJustifyH('LEFT')
			ui:SetWidth(4)
			ui:SetHeight(mf.mincolheight)
			ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', 0,0)
			ui:RegisterForDrag('LeftButton')
			
			ui:SetScript('OnDragStart', function(this, button)
				--this:GetParent():StartSizing('RIGHT')
				this.highlight:Show()
			end)
			ui:SetScript('OnDragStop', function(this, button)
				--this:GetParent():StopMovingOrSizing()
				this.highlight:Hide()
				--mf:ResetColumnFramePoints()
			end)
			
			--cells
			currentframe.cells = {}
		end
		
		currentframe = mf.columnframes[1]
		for j = 1, mf.availablerows do
			ui = fLib.GUI.CreateCheck(currentframe)
			tinsert(currentframe.cells, ui)
			ui:SetWidth(12)
			ui:SetHeight(12)
		end
		currentframe = mf.columnframes[2]
		for j = 1, mf.availablerows do
			ui = fLib.GUI.CreateLabel(currentframe)
			tinsert(currentframe.cells, ui)
			ui:SetJustifyH('LEFT')
		end
		
		mf.columnframes[1].headerbutton:SetText('P')
		mf.columnframes[1]:SetWidth(30)
		mf.columnframes[2].headerbutton:SetText('Raid')
		mf.columnframes[2]:SetWidth(125)
		
		--rowbutton for each row
		mf.rowbuttons = {}
		local rowoffset = 0
		for i = 1, mf.availablerows do
			rowoffset = mf.rowheight * i + i
			
			--separator
			ui = fLib.GUI.CreateSeparator(mf)
			ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - rowoffset)
			ui:SetWidth(mf.maxwidth)
			
			--rowbutton
			ui = fLib.GUI.CreateActionButton(mf)
			tinsert(mf.rowbuttons, ui)

			ui.indexnum = 0
			
			ui:SetFrameLevel(4)
			ui:GetFontString():SetJustifyH('LEFT')
			ui:SetHeight(mf.rowheight)
			ui:SetWidth(mf.maxwidth)
			ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -6-rowoffset)
			
			ui.highlightspecial = ui:CreateTexture(nil, "BACKGROUND")
			ui.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			ui.highlightspecial:SetBlendMode("ADD")
			ui.highlightspecial:SetAllPoints(ui)
			ui.highlightspecial:Hide()
			
			ui:SetScript('OnClick', function()
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
		ui = fLib.GUI.CreateSeparator(mf)
		ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.mincolheight)
		ui:SetWidth(mf.maxwidth)
		prevui = ui
		
		--Search box
		ui = fLib.GUI.CreateEditBox(mf, 'Search')
		mf.eb_search = ui
		mf.search = ''
		ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
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
		
		--Raid Details
		ui = fLib.GUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', mf.eb_search, 'BOTTOMLEFT', 0, -5)
		ui:SetText('Name: ')
		prevui = ui
		
		mf.title_name = fLib.GUI.CreateLabel(mf)
		mf.title_name:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		mf.title_name:SetText('')
		
		ui = fLib.GUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
		ui:SetText('Dkp:')
		prevui = ui
		
		mf.title_dkp = fLib.GUI.CreateLabel(mf)
		mf.title_dkp:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		mf.title_dkp:SetText('')
		
		--separator
		ui = fLib.GUI.CreateSeparator(mf)
		ui:SetWidth(1)
		ui:SetHeight(mf:GetHeight() - mf.mincolheight - 15)
		ui:SetPoint('TOP', mf.eb_search, 'BOTTOM', -25,-1)
		prevui = ui
		
		ui = fLib.GUI.CreateLabel(mf)
		ui:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, -5)
		ui:SetText('Modify dkp:')
		prevui = ui
		
		mf.eb_dkpchange = fLib.GUI.CreateEditBox3(mf, 'amount')
		mf.eb_dkpchange:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
		mf.eb_dkpchange:SetWidth(100)
		mf.eb_dkpchange.prevtext = ''
		
		mf.eb_dkpnote = fLib.GUI.CreateEditBox3(mf, 'note')
		mf.eb_dkpnote:SetPoint('TOPLEFT', mf.eb_dkpchange, 'BOTTOMLEFT', 0, -5)
		mf.eb_dkpnote:SetWidth(100)
		
		mf.eb_dkpchange:SetScript('OnEscapePressed', function()
			local num = tonumber(this:GetText())
			if not num then
				this:SetText(0)
			else
				this:SetText(num)
			end
			this:ClearFocus()
		end)
		mf.eb_dkpchange:SetScript('OnEnterPressed', function()
			local num = tonumber(this:GetText())
			if not num then
				this:SetText(0)
			else
				this:SetText(num)
			end
			mf.eb_dkpnote:SetFocus()
			mf.eb_dkpnote:HighlightText()
		end)
		mf.eb_dkpnote:SetScript('OnEscapePressed', function()
			this:ClearFocus()
		end)
		mf.eb_dkpnote:SetScript('OnEnterPressed', function()
			local playernum, playerobj = mf:SelectedData()
			if playerobj then
				local amount = tonumber(mf.eb_dkpchange:GetText())
				if amount and amount > 0 then
					--playerobj.dkp = playerobj.dkp + newdkp
					--TODO: note
					fRaidPlayer:AddDKP(playerobj.name, amount, mf.eb_dkpnote:GetText())
					mf:Refresh()
					mf.eb_dkpchange:SetText('')
					this:SetText('')
					this:ClearFocus()
				else
					mf.eb_dkpchange:SetFocus()
					mf.eb_dkpchange:HighlightText()
				end
			end
		end)


		--REFRESH
		function mf:Refresh()
			--regenerate ListIndex if ItemList has changed
			mf:RefreshListIndex()
			mf:LoadRows()
		end
		
		--CALLED BY REFRESH directly or indirectly
		function mf:RefreshDetails()
			local itemnum, itemobj = mf:SelectedData()
			if itemobj then
				mf.title_name:SetText(itemobj.name)
				mf.title_dkp:SetText(itemobj.dkp)
			else
				mf.title_name:SetText('')
				mf.title_dkp:SetText('')
			end
		end
		
		function mf:RefreshListIndex()
			if mf.prevlistcount ~= #mf.items then
				table.wipe(mf.ListIndex)
				mf.prevlistcount = #mf.items
				local obj, previ
				for i = 1, #mf.items do
					tinsert(mf.ListIndex, i)
				end
				
				local max = #mf.ListIndex - mf.availablerows + 1
				if max < 1 then
					max = 1
				end
				mf.slider:SetMinMaxValues(1, max)
				mf:Sort(mf.prevsortcol)
			end
			
		end

		--a and b are indexes in ListIndex
		mf.sortkeeper = {
			{asc = false, issorted = false},
			{asc = false, issorted = false},
			{asc = false, issorted = false},
			{asc = false, issorted = false}
		}
		function mf.lootcomparer(a, b)
			if a == nil or b == nil then
				return true
			end
			
			if a < 1 or b < 1 then
				return true
			end
			
			--retrieving itemobj
			local aobj = fRaid.db.global.PlayerList[a]
			local bobj = fRaid.db.global.PlayerList[b]
			
			local SORT = 1
			local SORT_ASC = false
			for idx,keeper in ipairs(mf.sortkeeper) do
				if keeper.issorted then
					SORT = idx
					SORT_ASC = keeper.asc
				end
			end
			
			local ret = true
			--[[
			if SORT == 4 then
				ret = aobj.id > bobj.id
			elseif SORT == 3 then
				if aobj.rarity == bobj.rarity then
					ret = aobj.name > bobj.name
				else
					ret = aobj.rarity < bobj.rarity
				end
				--]]
			if SORT == 2 then
				if aobj.dkp == bobj.dkp then
					ret = aobj.name > bobj.name
				else
					ret = aobj.dkp < bobj.dkp
				end
			else
				ret = aobj.name > bobj.name
			end
			
			if SORT_ASC then
				return not ret
			else
				return ret
			end
		end
		
		function mf:Sort(colnum)
			if mf.sortkeeper[colnum].issorted then
				mf.sortkeeper[colnum].asc = not mf.sortkeeper[colnum].asc
				table.sort(mf.ListIndex, mf.lootcomparer)
			else
				mf.prevsortcol = colnum
				mf.sortkeeper[colnum].asc = true
				for idx,keeper in ipairs(mf.sortkeeper) do
					keeper.issorted = false
				end
				mf.sortkeeper[colnum].issorted = true
				table.sort(mf.ListIndex, mf.lootcomparer)
			end
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
						if itemobj.dkp == searchnum then
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
					mf.columnframes[4].cells[i]:SetText('')
					
					mf.rowbuttons[i]:Hide()
					mf.rowbuttons[i].indexnum = 0
				else
					--fill in the cells with stuff
					--local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemobj.id)
					mf.columnframes[1].cells[i]:SetText(itemobj.name)
					mf.columnframes[2].cells[i]:SetText(itemobj.dkp)
					mf.columnframes[3].cells[i]:SetText('')
					mf.columnframes[4].cells[i]:SetText('')
					
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