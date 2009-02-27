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

function LIST.Count(recount)
    if not recount then
        return fRaid.db.global.Player.Count
    else
        --recount
        local count = 0
        for name, data in pairs(fRaid.db.global.Player.PlayerList) do
            count = count + 1
        end
        --update count
        fRaid.db.global.Player.Count = count
        
        --return
        return fRaid.db.global.Player.Count
    end
end

--returns a copy of playerobj
function LIST.GetPlayer(name, createnew)
    if not name or name == '' then
        return nil
    end
    
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))

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
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))
    
    local obj = fRaid.db.global.Player.PlayerList[name]
    if obj then
        --delete
        fRaid.db.global.Player.PlayerList[name] = nil
        fRaid.db.global.Player.Count = fRaid.db.global.Player.Count - 1
        fRaid.db.global.Player.LastModified = fLib.GetTimestamp()
        
        --audit
        tinsert(fRaid.db.global.Player.ChangeList[UnitName('player')], {name, 'delete', note, fRaid.db.global.Player.LastModified, obj})
    end
end

--set the player's dkp
function LIST.SetDkp(name, dkp, note)
    --make sure name is formatted correctly
    name = fRaid:Capitalize(strlower(strtrim(name)))
    
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
    if not name or name == '' then
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
    local msg = name .. ' - Prev Dkp: ' .. objcopy.dkp .. ',Amt: ' .. amount .. ',New Dkp:' .. objcopy2.dkp

    fRaid:Print('UPDATE: ' .. msg)
    fRaid:Whisper(name, msg)
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
                fRaid.Player.AddDkp(name, amount/2)
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

function fRaid.Player.View()
    local mf = fRaid.GUI2.PlayerFrame

    if not mf.viewedonce then
        --create index table
        mf.index_to_name = {}
        mf.lastmodified = 0--fRaid.db.global.Player.LastModified
        
        mf.table = fLibGUI.Table.CreateTable(mf, mf:GetWidth() - 25, 200, 7) 
        --TT.CreateTable(mf, mf:GetWidth() - 25, 200, 7)

        
        function mf:RetrieveData(index)
            local name, data
            if not index or index < 1 then
                index = self.table.selectedindex
            end
            
            name = self.index_to_name[index]
            data = fRaid.db.global.Player.PlayerList[name]
            
            return name, data
        end
        
        function mf:RefreshIndex(force)
            if mf.lastmodified ~= fRaid.db.global.Player.LastModified or force then
                print('Refreshing index...')
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
            print('Loading rows...')
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
            local exactmatchindex = 0
            local exactmatchrow = 0
            
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
                            if strlower(name) == strlower(searchname) then
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
            
            if exactmatchrow > 0 then
                print('exact match at ', exactmatchindex)
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
            --retrieve data
            --local aname, adata = mf:RetrieveData(a)
            local adata = fRaid.db.global.Player.PlayerList[a]
            --local bname, bdata = mf:RetrieveData(b)
            local bdata = fRaid.db.global.Player.PlayerList[b]
            
            --find the sorted column and how it is sorted
            local SORT = mf.table.selectedcolnum
            local SORT_ASC = mf.sortkeeper[SORT].asc
            local SORT_NAME = mf.sortkeeper[SORT].name
            
            local ret = true
            
            if SORT_NAME == 'Dkp' then
                if adata.dkp == bdata.dkp then
                    ret = a > b
                else
                    ret = adata.dkp < bdata.dkp
                end
            else
                ret = a > b
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
        
        local function np(name)
            fRaid.Player.AddDkp(name, 0, 'new player')
            print('add new player complete, refreshing...')
            mf:Refresh()
            print('hiding newbutton')
            mf.eb_search.newbutton:Hide()
        end
        function mf:NewPlayer(name)
            if not name or name == '' then
                name = self.eb_search:GetText()
            end
            fRaid:ConfirmDialog2('Add new player: ' .. name .. '?', np, name)
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
        
        --Search/Name box
        ui = fLibGUI.CreateEditBox(mf, 'Name')
        mf.eb_search = ui
        mf.search = ''
        ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -5)
        ui:SetWidth(mf.table.width)
        ui:SetScript('OnEnterPressed', function()
            this:ClearFocus()
            if mf.table.selectedindex == 0 then
                mf:NewPlayer()
            end
        end)
        ui:SetScript('OnTextChanged', function()
            print('text changed')
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
        ui:SetScript('OnClick', function() mf:NewPlayer() end)
        ui:SetPoint('RIGHT', mf.eb_search, 'RIGHT', -4, 0)
        ui:Hide()
        
        
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
        ui:SetPoint('TOP', mf.eb_search, 'BOTTOM', -30,-1)
        prevui = ui
        
        ui = fLibGUI.CreateLabel(mf)
        ui:SetPoint('TOPLEFT', prevui, 'TOPRIGHT', 5, -5)
        ui:SetText('Add dkp:')
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
            local name, playerobj = mf:RetrieveData()
            if playerobj then
                local amount = tonumber(mf.eb_dkpchange:GetText())
                if amount then
                    --playerobj.dkp = playerobj.dkp + newdkp
                    --TODO: note
                    fRaid.Player.AddDkp(name, amount, mf.eb_dkpnote:GetText())
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