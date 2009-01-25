-- Author      : Jessica Chen Huang
-- Create Date : 1/1/2009 12:36:55 AM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.InstanceList
--fRaid.db.global.InstanceListIndex
--fRaid.GUI2.InstanceFrame

fRaid.Instance = {}

--retrieves index of the instanceobj with zone name
function fRaid.Instance.ZoneNameToIndex(zonename)
	if not fRaid.db.global.InstanceListIndex then
		fRaid.db.global.InstanceListIndex = {}
	else
		return fRaid.db.global.InstanceListIndex[zonename]
	end
end

function fRaid.Instance.GetIndex()
	return fRaid.db.global.InstanceListIndex
end

--recreates the InstanceListIndex (maps zone name to index)
function fRaid.Instance.RefreshIndex(announceduplicates)
	if not fRaid.db.global.InstanceListIndex then
		fRaid.db.global.InstanceListIndex = {}
	else
		wipe(fRaid.db.global.InstanceListIndex)
		fRaid.db.global.InstanceListIndexCount = 0
	end
	local count = 0								
	for idx, obj in ipairs(fRaid.db.global.InstanceList) do
		if obj.isvalid then
			if fRaid.db.global.InstanceListIndex[obj.id] and announceduplicates then
				fRaid:Print('ERROR: duplicate instance found.  ID:', obj.id, ', index:', idx, '.')
			end
			fRaid.db.global.InstanceListIndex[obj.name] = idx
			count = count + 1
		end
	end
	fRaid.db.global.InstanceListIndexCount = count
end


function fRaid.Instance.GetObjectByIndex(idx)
	return fRaid.db.global.InstanceList[idx]
end

--returns instanceobj, idx
function fRaid.Instance.GetObjectByName(zonename, createnew)
	local obj, idx
	idx = fRaid.Instance.ZoneNameToIndex(zonename)
	if idx then
		obj = fRaid.db.global.InstanceList[idx]
		if not obj then
			--something is wrong with IndexList
			fRaid.Instance.RefreshIndex()
			idx = fRaid.Instance.ZoneNameToIndex(zonename)
			obj = fRaid.db.global.InstanceList[idx]
		end
	end

	if not obj and createnew then
		--create new instanceobj
		obj = {
			name = zonename,
			bossIdxList = {}, --gets changed when bossobjs are created/removed
			isvalid = true
		}
		tinsert(fRaid.db.global.InstanceList, obj)
		
		--update index
		idx = #fRaid.db.global.InstanceList
		fRaid.db.global.InstanceListIndex[id] = idx
	end
	return obj, idx
end

function fRaid.Instance.RemoveByIndex(idx)
	local obj = fRaid.db.global.InstanceList[idx]
	if obj then
		--check if there are bosses belonging to this instance
		if #obj.bossIdxList > 0 then
			--can't delete
			fRaid:Print('ERROR: cannot remove this instance because bosses belong to it.')
		else
			--can delete
			obj.isvalid = false
			--remove from index
			fRaid.db.global.InstanceListIndex[obj.name] = nil
		end
	end
end

function fRaid.Instance.PLAYER_ENTERING_WORLD()
	local inInstance, instanceType = IsInInstance()
	if inInstance and instanceType == 'raid' then
		--add to InstanceList if not already in it
		local zonename = GetRealZoneText()
		local instanceobj, idx = fRaid.Instance.GetObjectByName(zonename, true)
	
		--if current raid is open / exists?
		--add instance to the current raid instance list
		if fRaid.db.global.CurrentRaid then
			local instancevisitobj = fRaid.db.global.CurrentRaid.instancevisitobjs[#fRaid.db.global.CurrentRaid.instancevisitobjs]
			if not instancevisitobj or instancenum ~= instancevisitobj.instancenum then
				instancevisitobj = {
					instancenum = instancenum,
					timearrived = date("%m/%d/%y %H:%M:%S")
				}
				tinsert(fRaid.db.global.CurrentRaid.instancevisitobjs, instancevisitobj)
			end
		end
	end
end

function fRaid.Instance.View()
	local mf = fRaid.GUI2.InstanceFrame

	if not mf.viewedonce then
		--------------------------------------------------------------
		--Top Section-------------------------------------------------
		--------------------------------------------------------------
		local title = fLibGUI.CreateLabel(mf)
		title:SetText('Current Zone:')
		title:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -5)
		local prevtitle = title
		
		mf.title_curzone = fLibGUI.CreateLabel(mf)
		mf.title_curzone:SetText('...')
		mf.title_curzone:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLibGUI.CreateLabel(mf)
		title:SetText('Instance?')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		prevtitle = title

		mf.title_isinstance = fLibGUI.CreateLabel(mf)
		mf.title_isinstance:SetText('...')
		mf.title_isinstance:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLibGUI.CreateLabel(mf)
		title:SetText('Instance Type:')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)

		mf.title_instancetype = fLibGUI.CreateLabel(mf)
		mf.title_instancetype:SetText('...')
		mf.title_instancetype:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		local tex = fLibGUI.CreateSeparator(mf)
		tex:SetWidth(mf:GetWidth() - 32)
		tex:SetPoint('TOP', mf, 'TOP', 0,-60)
		
		--------------------------------------------------------------
		--InstanceList Section-------------------------------------------------
		--------------------------------------------------------------
		local b, eb, ix, ui
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
			itemobj = fRaid.Instance.GetObjectByIndex(itemnum)
			return itemnum, itemobj
		end

		--create ui elements
		--table with 1 column
		mf.columnframes = {}	
		local currentframe	
		for i = 1, 1 do
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
				
		mf.columnframes[1].headerbutton:SetText('Instances')
		mf.columnframes[1]:SetWidth(75)
				
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
	
		
		mf.viewedonce = true
	end
	
	local inInstance, instanceType = IsInInstance()
	local zonename = GetRealZoneText()
	
	mf.title_curzone:SetText(zonename)
	if inInstance then
		mf.title_isinstance:SetText('Yes')
	else
		mf.title_isinstance:SetText('No')
	end
	mf.title_instancetype:SetText(instanceType)
	
	mf:Show()
end