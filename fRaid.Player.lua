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

local LIST = {} --table to hold functions
fRaid.Player.LIST = LIST

function fRaid.Player.OnInitialize()
    if not fRaid.db.global.Player.ChangeList[UnitName('player')] then
        fRaid.db.global.Player.ChangeList[UnitName('player')] = {}
    end
end

--TODO: find out info about name, class, guild, online
function fRaid.Player.Scan(name)

end

--===================================================================================
--Functions that access PlayerList
--USE ONLY THESE FUNCTIONS TO ACCESS PLAYERLIST--

--returns a copy of playerobj
function LIST.GetPlayer(name, createnew)
    --may want to format name ? fRaid:Capitalize(strlower(strtrim(name)))
    local obj = fRaid.db.global.Player.PlayerList[name]
    if createnew and not obj then
        obj = {
            dkp = 0,
            attendance = 0,
            class = '',
            role = '', --dps, heal, tank?                    
        }
        fRaid.db.global.Player.PlayerList[name] = obj --add player
        fRaid.db.global.Player.Count = fRaid.db.global.Player.Count + 1
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'new', '', fRaid.db.global.Player.LastModified})
        
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
    local obj = fRaid.db.global.Player.PlayerList[name]
    if obj then
        --delete
        fRaid.db.global.Player.PlayerList[name] = nil
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'delete', note, fRaid.db.global.Player.LastModified, obj})
    end
end

--set the player's dkp
function LIST.SetDkp(name, dkp, note)
    local obj = fRaid.db.global.Player.PlayerList[name]
    if obj and obj.dkp ~= dkp then
        local olddkp = obj.dkp
        obj.dkp = dkp
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'dkp', note, fRaid.db.global.Player.LastModified, olddkp, obj.dkp})
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
fRaid.Player.TT = TT

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
    
TT.try1 = t

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
	
	t.startingindex = 1
	t.selectedindex = 0
	t.selectedcolnum = 1
	--t.count = 0
	
	t:SetPoint('TOPLEFT', 0, 0)
	t:SetWidth(t.width)
	t:SetHeight(t.height)
	
	--helper funcs to create my table
	TT.CreateColumns(t)
	TT.CreateRows(t)
	TT.CreateSeparators(t)
	TT.CreateCells(t)
	TT.CreateScrollBar(t)
	TT.SetUIPoints(t)
	
	t:ResetColumnFramePoints()
	
	--list of func,args to be called
	t.headerclickactions = {}
	t.rowclickactions = {}
	t.scrollactions = {}
	
	t.AddHeaderClickAction = TT.private.AddHeaderClickAction
	t.AddRowClickAction = TT.private.AddRowClickAction
	t.AddScrollAction = TT.private.AddScrollAction
	
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
        
        currentframe:SetWidth(t.mincolwidth)
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
            this.table.selectedcolnum = this.colnum
            --call extra actions
            for z = 1, #this.table.headerclickactions do
                this.table.headerclickactions[z][1](unpack(this.table.headerclickactions[z][2]))
            end
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

function TT.private.AddHeaderClickAction(self, f, ...)
    local t = self
    tinsert(t.headerclickactions, {f, {...}})
end

function TT.private.AddRowClickAction(self, f, ...)
    local t = self
    tinsert(t.rowclickactions, {f, {...}})
end

function TT.private.AddScrollAction(self, f, ...)
    local t = self
    tinsert(t.scrollactions, {f, {...}})
end

--rows...
function TT.CreateRows(t)
    --rowbutton for each row
    t.rowbuttons = {}
    for i = 1, t.rowcount do
        --rowbutton
        ui = fLibGUI.CreateActionButton(t)
        tinsert(t.rowbuttons, ui)
        
        ui.table = t
        ui.index = 0
        
        ui:SetFrameLevel(4)
        ui:GetFontString():SetJustifyH('LEFT')
        ui:SetHeight(t.rowheight)
        ui:SetWidth(t.width)
        
        ui.highlightspecial = ui:CreateTexture(nil, "BACKGROUND")
        ui.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        ui.highlightspecial:SetBlendMode("ADD")
        ui.highlightspecial:SetAllPoints(ui)
        ui.highlightspecial:Hide()
        
        ui:SetScript('OnClick', function()
            local t = this.table
            
            --unselect all the other rows
            for i = 1, t.rowcount do
                t.rowbuttons[i].highlightspecial:Hide()
            end
            
            --select this row
            this.highlightspecial:Show()
            t.selectedindex = this.index
            
            --call extra actions
            for z = 1, #t.rowclickactions do
                t.rowclickactions[z][1](unpack(t.rowclickactions[z][2]))
            end
            
            --[[
            --fill in details
            t:RefreshDetails()
            --]]
        end)
    end
end


function TT.CreateSeparators(t)
    t.separators = {}
    
    for i = 1, t.rowcount do
        --separator
        ui = fLibGUI.CreateSeparator(t)
        tinsert(t.separators, ui)
        ui:SetWidth(t.width)
    end
end

function TT.CreateCells(t)
    local ui, currentframe
    for i = 1, t.colcount do
        currentframe = t.columns[i]
        currentframe.cells = {}
        for j = 1, t.rowcount do
            ui = fLibGUI.CreateLabel(currentframe)
            tinsert(currentframe.cells, ui)
            ui:SetJustifyH('LEFT')
        end
    end
end

function TT.CreateScrollBar(t)
    --Scroll bar
    ui = CreateFrame('slider', nil, t)
    t.slider = ui
    
    ui.table = t
    
    ui:SetFrameLevel(5)
    ui:SetOrientation('VERTICAL')
    ui:SetMinMaxValues(1, 1)
    ui:SetValueStep(1)
    ui:SetValue(1)
    
    ui:SetWidth(10)
    ui:SetHeight(t.height)
    
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
        this.table.startingindex = this:GetValue()
        --call extra actions
        for z = 1, #this.table.scrollactions do
            this.table.scrollactions[z][1](unpack(this.table.scrollactions[z][2]))
        end
        --this.table:LoadRows(this:GetValue())
    end)
    
    t:EnableMouseWheel(true)
    t:SetScript('OnMouseWheel', function(this,delta)
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
end

function TT.SetUIPoints(t)
    local ui, currentframe
    local rowoffset = t.headerheight + t.separatorheight
    for i = 1, t.rowcount do
        t.rowbuttons[i]:SetPoint('TOPLEFT', t, 'TOPLEFT', 5, -6-rowoffset)
        --attach them on top of each rowbutton
        t.separators[i]:SetPoint('BOTTOMLEFT', t.rowbuttons[i], 'TOPLEFT', 0, 0)
        
        --cells
        for j = 1, t.colcount do
            currentframe = t.columns[j]
            ui = currentframe.cells[i]
            ui:SetPoint('TOPLEFT', currentframe, 'TOPLEFT', 5, -rowoffset)
            ui:SetPoint('TOPRIGHT', currentframe, 'TOPRIGHT', -5, -rowoffset)
        end
        
        --slider
        t.slider:SetPoint('TOPRIGHT', t, 'TOPRIGHT', -5, -5)
        
        rowoffset = rowoffset + t.rowheight + t.separatorheight
    end
end

function fRaid.Player.View()
    local mf = fRaid.GUI2.PlayerFrame

    if not mf.viewedonce then
        --create index table
        mf.index_to_name = {}
        mf.lastmodified = fRaid.db.global.Player.LastModified
        
        mf.table = TT.CreateTable(mf, mf:GetWidth() - 25, 200, 7)
        
        
        
        
        function mf:RetrieveData(index)
            local name, data
            if not index or index < 1 then
                index = 1
            end
            
            name = self.index_to_name[index]
            data = fRaid.db.global.Player.PlayerList[name]
            
            return name, data
        end
        
        function mf:RefreshIndex(force)
            if mf.lastmodified ~= fRaid.db.global.Player.LastModified or force then
                table.wipe(mf.index_to_name)
                mf.lastmodified = fRaid.db.global.Player.LastModified
                
                local obj, previ
                for name,data in pairs(fRaid.db.global.Player.PlayerList) do
                    tinsert(mf.index_to_name, name)
                end
                
                local max = #mf.index_to_name - mf.table.rowcount + 1
                if max < 1 then
                    max = 1
                end
                mf.table.slider:SetMinMaxValues(1, max)
                mf:Sort(mf.table.selectedcolnum)
            end
        end

        --click on a header
        function mf:ClickHeader()
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
            if startingindexnum then
                self.table.startingindex = startingindex
            end

            self:RefreshIndex()
            
            local name, data
            local index = self.table.startingindex
            
            local searchmatch = false
            local searchnum, searchname
            searchnum = tonumber(self.search)
            searchname = strlower(self.search)
            
            local selectedindexfound = false
            
            for i = 1, self.table.rowcount do
                --search
                searchmatch = false
                while not searchmatch do
                    name, data = self:RetrieveData(index)
                    if self.search == '' or not data then
                        searchmatch = true
                    else
                        if data.dkp == searchnum then
                            searchmatch = true
                        elseif strfind(strlower(name), searchname, 1, true) then
                            searchmatch = true
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
                    self.table.columns[1].cells[i]:SetText(name)
                    self.table.columns[2].cells[i]:SetText(data.dkp)
                    self.table.columns[3].cells[i]:SetText(data.rank)
                    self.table.columns[4].cells[i]:SetText(data.role)
                    self.table.columns[5].cells[i]:SetText('')
                    self.table.columns[6].cells[i]:SetText('')
                    self.table.columns[7].cells[i]:SetText(index)
                    
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
            

            if not selectedindexfound then
                self.table.selectedindex = 0
                self:RefreshDetails()
            end
        end
        
        function mf:Refresh()
	        mf:LoadRows()
        end
        
        function mf:RefreshDetails()
            local name, data = self:RetrieveData()
            if name and data then
                self.title_name:SetText(name)
                self.title_dkp:SetText(data.dkp)
            else
                self.title_name:SetText('')
                self.title_dkp:SetText('')
            end
		end
        
        --a and b are indexes in ListIndex
        mf.sortkeeper = {
	        {asc = false, issorted = false, name = 'Name'},
	        {asc = false, issorted = false, name = 'Dkp'},
	        {asc = false, issorted = false, name = 'Rank'},
	        {asc = false, issorted = false, name = 'Role'},
	        {asc = false, issorted = false, name = 'Att'},
	        {asc = false, issorted = false, name = 'Prog'},
	        {asc = false, issorted = false, name = 'Id'}
        }
        function mf.lootcomparer(a, b) --a and b are index's in index_to_name
            if a < 1 or b < 1 then
                return true
            end
            
            --retrieve data
            local aname, adata = mf:RetrieveData(a)
            local bname, bdata = mf:RetrieveData(b)
            
            --find the sorted column and how it is sorted
            local SORT = mf.table.selectedcolnum
            local SORT_ASC = mf.sortkeeper[SORT].asc
            local SORT_NAME = mf.sortkeeper[SORT].name
            
            local ret = true
            
            if SORT_NAME == 'Dkp' then
                if adata.dkp == bdata.dkp then
                    ret = aname > bname
                else
                    ret = adata.dkp < bdata.dkp
                end
            elseif SORT_NAME == 'Id' then
                ret = a > b
            else
                ret = aname > bname
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
            end
            
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
            table.sort(mf.index_to_name, mf.lootcomparer)
        end
        
        
        mf.table:AddHeaderClickAction(mf.ClickHeader, mf)
        mf.table:AddRowClickAction(mf.ClickRow, mf)
        mf.table:AddScrollAction(mf.Scroll, mf)
        
        --fill in headers
        local i = 1
        mf.table.columns[i].headerbutton:SetText('Name')
        mf.table.columns[i]:SetWidth(115)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Dkp')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Rank')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Role')
        mf.table.columns[i]:SetWidth(75)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Att')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Prog')
        mf.table.columns[i]:SetWidth(50)
        i = i + 1
        mf.table.columns[i].headerbutton:SetText('Id')
        mf.table.columns[i]:SetWidth(50)
        
        
        
        --separator
        ui = fLibGUI.CreateSeparator(mf)
        ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5,-6 - mf.table.height)
        ui:SetWidth(mf.table.width)
        prevui = ui
        
        --Search box
        ui = fLibGUI.CreateEditBox(mf, 'Search')
        mf.eb_search = ui
        mf.search = ''
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetWidth(mf.table.width)
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
        ui:SetHeight(mf:GetHeight() - mf.table.height - 15)
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

            
        mf.viewedonce = true
        
    end

    mf:Refresh()
    mf:Show()
end