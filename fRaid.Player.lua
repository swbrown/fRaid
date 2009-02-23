-- Author      : Jessica Chen Huang
-- Create Date : 2/13/2009 10:43 AM

--Goals:
--  Keeps track of players, their dkp, and other useful data
--  Syncable between users running this mod
--  Audit trail of activity

--Data Structures:
--  PlayerList - table, key = playername, value = player data
--  PlayerListChanges - table, key = playername, value = list of changes
--    this list maintains the audit trail of changes to the PlayerList
--    when syncing...

--for reference
--fRaid.db.global.CurrentRaid
--fRaid.db.global.Player.PlayerList {name => {dkp, attendance}
--fRaid.db.global.Player.ChangeList {myname => {idx => {name, action, note, oldvalue, newvalue}}}
--fRaid.db.global.Player.Count
--fRaid.db.global.Player.LastModified
--fRaid.GUI2.PlayerFrame

fRaid.Player = {}
fRaid.Player.PlayerList = fRaid.db.global.Player.PlayerList
fRaid.Player.ChangeList = fRaid.db.global.Player.ChangeList[UnitName('player')] or {}

local LIST = {} --table to hold functions
fRaid.Player.LIST = LIST

--TODO: find out info about name, class, guild, online
function fRaid.Player.Scan(name)

end

--===================================================================================
--Functions that access PlayerList
--USE ONLY THESE FUNCTIONS TO ACCESS PLAYERLIST--

--returns a copy of playerobj
function LIST.GetPlayer(name, createnew)
    --may want to format name ? fRaid:Capitalize(strlower(strtrim(name)))
    local obj = fRaid.Player.PlayerList[name]
    if createnew and not obj then
        obj = {
            dkp = 0,
            attendance = 0,
            class = '',
            role = '', --dps, heal, tank?                    
        }
        fRaid.Player.PlayerList[name] = obj --add player
        fRaid.db.global.Player.Count = fRaid.db.global.Player.Count + 1
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.Player.ChangeList, {name, 'new'})
        
        fRaid:Print('Added new player ' .. name)
    end
    
    --make copy
    local objcopy = {}
    for key,val in pairs(obj) do
        objcopy[key] = val
    end
    
    return objcopy
end

--removes the player
function LIST.DeletePlayer(name, note)
    local obj = fRaid.Player.PlayerList[name]
    if obj then
        --delete
        fRaid.Player.PlayerList[name] = nil
        --audit
        tinsert(fRaid.Player.ChangeList, {name, 'delete', note, obj})
    end
end

--set the player's dkp
function LIST.SetDkp(name, dkp, note)
    local obj = fRaid.Player.PlayerList[name]
    if obj and obj.dkp ~= dkp then
        local olddkp = obj.dkp
        obj.dkp = dkp
        
        --audit
        tinsert(fRaid.Player.ChageList, {name, 'dkp', note, olddkp, obj.dkp})
    end
end

--===========================================================================================

--Add dkp to a player
--amount can be a positive or negative value
function fRaid.Player.AddDkp(name, amount, note)
    --check args
    if not name then
        fRaid:Print("ERROR: missing arg1 name")
        return
    end
    if not amount then
        fRaid:Print("ERROR: missing arg2 amount")
        return
    end
    if type(amount) ~= 'number' then
        fRaid:Print("ERROR: bad type arg2 needs to be a number")
        return
    end

    --calculate new amount
    local objcopy = LIST.GetPlayer(name, true)
    local newamount = objcopy.dkp + amount
    
    --dkp cap
    if fRaid.db.global.cap > 0 then
        if newamount > fRaid.db.global.cap then
            newamount = fRaid.db.global.cap
        end
    end
    
    --save new amount
    LIST.SetDkp(name, newamount, note)
    
    local objcopy2 = LIST.GetPlayer(name)
    local msg = objcopy2.name .. ' - Prev Dkp: ' .. objcopy.dkp .. ',Amt: ' .. amount .. ',New Dkp:' .. objcopy2.dkp

    fRaid:Print('UPDATE: ' .. msg)
    fRaid:Whisper(objcopy2.name, msg)
end

function fRaid.Player.DeletePlayer(name)
    fRaid:ConfirmDialog2('Are you sure you want to remove ' .. name .. '?', fRaid.Player.DeletePlayerHandler, name)
end
function fRaid.Player.DeletePlayerHandler(name)
    LIST.DeletePlayer(name)
    fRaid:Print('Deleted ' .. name)
end

function fRaid.Player.AddDkpToRaid(amount, includelistedplayers)
    if not amount then
        fRaid:Print('ERROR: missing arg1 amount')
        return
    end
    if type(amount) ~= 'number' then
        fRaid:Print("ERROR: bad type arg1 needs to be a number")
        return
    end
    
    local name
    for i = 1, GetNumRaidMembers() do
        name = GetRaidRosterInfo(i)
        if name then
            fRaid.Player.AddDkp(name, amount, 'bosskill')
        end
    end
    
    fRaid:Print('COMPLETE: ' .. amount .. ' DKP added to raid')
    
    if includelistedplayers then
        if fList and fList.CURRENTLIST.IsListOpen() then
            for idx, info in ipairs(fList.CURRENTLIST.GetPlayers()) do
                name = info.name
                fRaid.AddDkp(name, amount/2)
            end
        end
        fRaid:Print('COMPLETE: ' .. amount/2 .. ' DKP added to waitlist')
    end
end

--cmd is a player name or TODO: one of the keywords
local keywords = {
    priest = true,
    mage = true, 
    warrior = true, 
    warlock = true, 
    deathknight = true, 
    paladin = true, 
    druid = true, 
    shaman = true, 
    hunter = true
}
function fRaid.Player.WhisperDkp(cmd, whispertarget)
    fRaid:Debug("<<WhisperDKP>> cmd = " .. cmd .. ", whispertarget = " .. whispertarget)

    cmd = strlower(strtrim(cmd))

    --check for special keywords
    local iskeyword = false
    if keywords[cmd] then
        iskeyword = true
    end

    local msg = ''
    
    --TODO: make iskeyword message
    local obj = LIST.GetPlayer(cmd)
    if obj then
        msg = cmd .. ' has ' .. obj.dkp .. ' dkp'
    else
        msg = cmd .. ' has 0 dkp'
    end

    if not whispertarget then
        fRaid:Print(msg)
    else
        fRaid:Whisper(whispertarget, msg)
    end
end

--==================================================================================================
local TT = {}
TT.private = {}

--returns a tableobj
--a tableobj is a frame with these properties
--  width
--  height
--  colcount
--  mincolwidth
--  headerheight
--  rowheight
--  separatorheight
--  rowcount - calculated
--  resizebuttonwidth
--  scrollbarwidth
function TT.CreateTable(parentframe, width, height, colcount)
	local t = fLibGUI.CreateClearFrame(parentframe)

	t.width = width
	t.height = height
	
	t.colcount = colcount
	t.mincolwidth = 20
	
	t.headerheight = 12
	t.rowheight = 12
	t.separatorheight = 1
	
	--floor((height - headerheight - separator - bottompadding) / (rowheight + separator))
	t.rowcount = floor((t.height - t.headerheight - t.separatorheight - 4) / (t.rowheight + t.separatorheight))
	
	t.resizebuttonwidth = 4
	t.scrollbarwidth = 10
	
	TT.CreateColumns(t)
	
	TT.CreateRows(t)
	
	return t
end

--columns - list of column frames
function TT.CreateColumns(t)
    t.columns = {}
    
    local currentframe    
    for i = 1, t.colcount do
    	--column frame
        currentframe = fLibGUI.CreateClearFrame(t)
        tinsert(t.columns, currentframe)
        
        currentframe.table = t        
        currentframe.enable = true
        
        currentframe:SetHeight(t.height)
        currentframe:SetResizable(true)
        currentframe:SetMinResize(t.mincolwidth, t.height)
        
        --header button
        ui = fLibGUI.CreateActionButton(currentframe)
        currentframe.headerbutton = ui
        
        ui.table = t
        ui.colnum = i
        
        ui:GetFontString():SetJustifyH('LEFT')
        ui:SetHeight(t.headerheight)
        ui:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 0, 0)
        ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -t.resizebuttonwidth, 0)
        ui:SetScript('OnClick', function()
            this.table:Sort(this.colnum)
        	this.table:LoadRows()
        end)            
        
        --resize button
        ui = fLibGUI.CreateActionButton(currentframe)
        currentframe.resizebutton = ui
        
        ui.table = t
        
        ui:GetFontString():SetJustifyH('LEFT')
        ui:SetWidth(t.resizebuttonwidth)
        ui:SetHeight(t.height)
        ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', 0,0)
        ui:RegisterForDrag('LeftButton')
        
        ui:SetScript('OnDragStart', function(this, button)
            this:GetParent():StartSizing('RIGHT')
            this.highlight:Show()
        end)
        ui:SetScript('OnDragStop', function(this, button)
            this:GetParent():StopMovingOrSizing()
            this.highlight:Hide()
            this.table:ResetColumnFramePoints()
        end)
                
        --cells
        --hmmm... assuming all the cells are labels...
        currentframe.cells = {}
        for j = 1, t.rowcount do
            ui = fLibGUI.CreateLabel(currentframe)
            tinsert(currentframe.cells, ui)
            ui:SetJustifyH('LEFT')
        end
    end
    
    t.ResetColumnFramePoints = TT.private.ResetColumnFramePoints
end

function TT.private.ResetColumnFramePoints(self)
    local t = self
    local enabledcolumns = {}
    for i = 1, #t.columns do
        if t.columns[i].enable then
            tinsert(enabledcolumns, i)
        end
    end
    
    local firstcolumndone = false
    local runningwidth = 0
    local currentcol, currentframe, prevframe, maxw, curw
    for i = 1, #enabledcolumns do
        currentcol = enabledcolumns[i]
        currentframe = t.columns[currentcol]
        if not firstcolumndone then
            currentframe:SetPoint('TOPLEFT', t, 'TOPLEFT', 5, -5)
            firstcolumndone = true
        else
            currentframe:SetPoint('TOPLEFT', prevframe, 'TOPRIGHT', 0,0)
        end
    
        --calculate allowed width, current width
        maxw = t.width - runningwidth - (t.mincolwidth * (#enabledcolumns - i))
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
        currentframe = t.columns[currentcol]
        currentframe:SetPoint('TOPRIGHT', t, 'TOPLEFT', t.width + 5, -5)
    end
end

--rows...
function TT.CreateRows(t)
    --rowbutton for each row
    t.rowbuttons = {}
    local rowoffset = 0
    for i = 1, t.rowcount do
        rowoffset = t.rowheight * i + t.separatorheight * i
        
        --separator
        ui = fLibGUI.CreateSeparator(t)
        ui:SetPoint('TOPLEFT', t, 'TOPLEFT', 5,-6 - rowoffset)
        ui:SetWidth(t.width)
        
        --rowbutton
        ui = fLibGUI.CreateActionButton(t)
        tinsert(t.rowbuttons, ui)
        
        ui.indexnum = 0
        
        ui:SetFrameLevel(4)
        ui:GetFontString():SetJustifyH('LEFT')
        ui:SetHeight(t.rowheight)
        ui:SetWidth(t.width)
        ui:SetPoint('TOPLEFT', t, 'TOPLEFT', 5, -6-rowoffset)
        
        ui.highlightspecial = ui:CreateTexture(nil, "BACKGROUND")
        ui.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        ui.highlightspecial:SetBlendMode("ADD")
        ui.highlightspecial:SetAllPoints(ui)
        ui.highlightspecial:Hide()
        
        ui:SetScript('OnClick', function()
            --unselect all the other rows
            for i = 1, t.rowcount do
                t.rowbuttons[i].highlightspecial:Hide()
            end
            
            --select this row
            this.highlightspecial:Show()
            t.selectedindexnum = this.indexnum
            
            --fill in details
            t:RefreshDetails()
        end)
        
        --cell location for each column
        for j = 1, #t.columnframes do
            currentframe = t.columnframes[j]
            ui = currentframe.cells[i]
            ui:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 5, -rowoffset)
            ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -5, -rowoffset)
        end
    end 
end
--]]
function fRaid.Player.View()
    local mf = fRaid.GUI2.PlayerFrame

    if not mf.viewedonce then
        
        local ui, prevui
        --mf.rowheight = 12
        mf.startingrow = 1
        --mf.availablerows = 15
        
        --mf.mincolwidth = 20
        --mf.mincolheight = mf.rowheight * mf.availablerows + mf.availablerows + mf.rowheight
        --#rows times height of each row plus 1 for each separator plus header row
        --mf.maxwidth = mf:GetWidth() - 25
        
        mf.items = fRaid.db.global.PlayerList
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
        --Name, Dkp, Role, Attendance, Progression Attendance, Id
        
        
        mf.columnframes = CreateColumns(mf, mf:GetWidth() - 25, mf:GetHeight() - 25, 7)
        
        mf.columnframes[1].headerbutton:SetText('Name')
        mf.columnframes[1]:SetWidth(125)
        mf.columnframes[2].headerbutton:SetText('Dkp')
        mf.columnframes[2]:SetWidth(50)
        mf.columnframes[3].headerbutton:SetText('Dkp')
        mf.columnframes[3]:SetWidth(50)
        mf.columnframes[4].headerbutton:SetText('Role')
        mf.columnframes[4]:SetWidth(75)
        mf.columnframes[5].headerbutton:SetText('Att')
        mf.columnframes[5]:SetWidth(50)
        mf.columnframes[6].headerbutton:SetText('Prog')
        mf.columnframes[6]:SetWidth(50)
        mf.columnframes[7].headerbutton:SetText('Id')
        mf.columnframes[7]:SetWidth(50)
                
        --rowbutton for each row
        mf.rowbuttons = {}
        local rowoffset = 0
        for i = 1, mf.availablerows do
            rowoffset = mf.rowheight * i + i
            
            --separator
            ui = fLibGUI.CreateSeparator(mf)
            ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - rowoffset)
            ui:SetWidth(mf.maxwidth)
            
            --rowbutton
            ui = fLibGUI.CreateActionButton(mf)
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
        ui = fLibGUI.CreateSeparator(mf)
        ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.mincolheight)
        ui:SetWidth(mf.maxwidth)
        prevui = ui
        
        --Search box
        ui = fLibGUI.CreateEditBox(mf, 'Search')
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
        
        --Player Details
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', mf.eb_search, 'BOTTOMLEFT', 0, -5)
        ui:SetText('Name: ')
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
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetText('Role:')
        prevui = ui
        
        mf.eb_role = fLibGUI.CreateEditBox2(mf, '#')
        mf.eb_role:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.eb_role:SetText('')
        mf.eb_role:SetScript('OnEnterPressed', function() 
            local itemnum, itemobj = mf:SelectedData()
            if itemobj then
                itemobj.role = this:GetText()
            end
            
            this:ClearFocus()
            this:SetText(itemobj.role)
            
            --refresh row (just going to refresh entire table)
            mf:Refresh()
        end)
        
        --separator
        ui = fLibGUI.CreateSeparator(mf)
        ui:SetWidth(1)
        ui:SetHeight(mf:GetHeight() - mf.mincolheight - 15)
        ui:SetPoint('TOP', mf.eb_search, 'BOTTOM', -25,-1)
        prevui = ui
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, -5)
        ui:SetText('Modify dkp:')
        prevui = ui
        
        mf.eb_dkpchange = fLibGUI.CreateEditBox3(mf, 'amount')
        mf.eb_dkpchange:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, 0)
        mf.eb_dkpchange:SetWidth(100)
        mf.eb_dkpchange.prevtext = ''
        
        mf.eb_dkpnote = fLibGUI.CreateEditBox3(mf, 'note')
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
                if amount then
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

        function mf:RefreshListIndex(force)
            if mf.prevlistcount ~= #mf.items or force then
                table.wipe(mf.ListIndex)
                mf.prevlistcount = #mf.items
                local obj, previ
                for i = 1, #mf.items do
                    obj = mf.items[i]
                    if obj.valid then
                        tinsert(mf.ListIndex, i)
                    end
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

            if SORT == 2 then
                if aobj.dkp == bobj.dkp then
                    ret = aobj.name > bobj.name
                else
                    ret = aobj.dkp < bobj.dkp
                end
            elseif SORT == 6 then
                ret = a > b
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
                    mf.columnframes[5].cells[i]:SetText('')
                    mf.columnframes[6].cells[i]:SetText('')
                    mf.columnframes[7].cells[i]:SetText('')
                    
                    mf.rowbuttons[i]:Hide()
                    mf.rowbuttons[i].indexnum = 0
                else
                    --fill in the cells with stuff
                    --local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemobj.id)
                    mf.columnframes[1].cells[i]:SetText(itemobj.name)
                    mf.columnframes[2].cells[i]:SetText(itemobj.dkp)
                    mf.columnframes[3].cells[i]:SetText(itemobj.rank)
                    mf.columnframes[4].cells[i]:SetText(itemobj.role)
                    mf.columnframes[5].cells[i]:SetText('')
                    mf.columnframes[6].cells[i]:SetText('')
                    mf.columnframes[7].cells[i]:SetText(indexnum)
                    
                    --attach correct indexnum to rowbutton
                    mf.rowbuttons[i]:Show()
                    mf.rowbuttons[i].indexnum = indexnum
    
                    if indexnum == mf.selectedindexnum then
                        mf.rowbuttons[i].highlightspecial:Show()
                        selectedindexfound = true
                    else
                        f.rowbuttons[i].highlightspecial:Hide()
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