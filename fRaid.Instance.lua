-- Author      : Jessica Chen Huang
-- Create Date : 1/1/2009 12:36:55 AM

--Keeps track of instances and information pertaining to them
--like....
--  progression dkp ?
--  maybe a counter of how many times have run this instance?
--      gets calculated and can be refreshed by scanning the RaidList?
--  

--fRaid.db.global.CurrentRaid
--fRaid.db.global.Instance.ZoneList
--  key: zone name
--  value: data
--fRaid.db.global.Instance.Count
--fRaid.db.global.Instance.LastModified
--fRaid.GUI2.InstanceFrame

fRaid.Instance = {}

function fRaid.Instance.GetObject(zonename, createnew)
    local obj = fRaid.db.global.InstanceList[zonename]
    if createnew and not obj then
        --create a new one
        obj = {}
        fRaid.db.global.InstanceList[zonename] = obj
        fRaid.db.global.Instance.Count = fRaid.db.global.Instance.Count + 1
        fRaid.db.global.Instance.LastModified = fLib.GetTimestamp()  
    end
    return obj
end

function fRaid.Instance.PLAYER_ENTERING_WORLD()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == 'raid' then
        --add to InstanceList if not already in it
        local zonename = GetRealZoneText()
        local instanceobj = fRaid.Instance.GetObject(zonename, true)
    
        --if current raid is open / exists?
        --add instance to the current raid instance list
        if fRaid.db.global.CurrentRaid then
            --[[
            local instancevisitobj = fRaid.db.global.CurrentRaid.instancevisitobjs[#fRaid.db.global.CurrentRaid.instancevisitobjs]
            if not instancevisitobj or instancenum ~= instancevisitobj.instancenum then
                instancevisitobj = {
                    instancenum = instancenum,
                    timearrived = date("%m/%d/%y %H:%M:%S")
                }
                tinsert(fRaid.db.global.CurrentRaid.instancevisitobjs, instancevisitobj)
            end
            --]]
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
        
        mf.IndexToKey = {}  --index table for sorting the list
        mf.selectedindex = 0
        mf.lastmodified = -1
        
        mf.prevsortcol = 1
        
        function mf:RefreshIndex(force)
            if mf.lastmodified < fRaid.db.global.Instance.LastModified or force then
                wipe(mf.IndexToKey)
                mf.IndexToKey = {}
                for key, val in pairs(fRaid.db.global.Instance.ZoneList) do
                    tinsert(mf.IndexToKey, key)
                end                 
                mf.lastmodified = fRaid.db.global.Instance.LastModified
            end
        end
        
        function mf:SelectedData(index)
            if not index or index < 1 then
                index = mf.selectedindex
            end
            
            local key, obj
            key = mf.IndexToKey[index]
            obj = fRaid.Instance.GetObject(key)
            
            return key, obj
            
            --itemnum = mf.ListIndex[indexnum]
            --itemobj = fRaid.Instance.GetObjectByIndex(itemnum)
            --return itemnum, itemobj
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
        
            b.index = 0
            
            b:SetFrameLevel(4)
            b:GetFontString():SetJustifyH('LEFT')
            b:SetHeight(mf.rowheight)
            b:SetWidth(mf.maxwidth)
            b:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -6-rowoffset)
            
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
                mf.selectedindex = this.index
                
                --fill in details
                mf:RefreshDetails()
            end)
            
            b:SetScript('OnEnter', function()
                this.highlight:Show()
                GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
                GameTooltip:SetPoint('LEFT', mf, 'RIGHT', 0, 0)
                local key, obj = mf:SelectedData(this.indexnum)
                if obj then
                    --GameTooltip:SetHyperlink('item:'..obj.id)
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