-- Author      : Jessica Chen Huang
-- Create Date : 1/1/2009 12:36:55 AM

--Keeps track of instances and information pertaining to them
--like....
--  progression dkp ?
--  maybe a counter of how many times have run this instance?
--      gets calculated and can be refreshed by scanning the RaidList?
--  

--fRaid.db.global.Instance.ZoneList
--  key: zone name
--  value: data
--fRaid.db.global.Instance.Count
--fRaid.db.global.Instance.LastModified
--fRaid.GUI2.InstanceFrame

fRaid.Instance = {}

function fRaid.Instance.Count(recount)
    if recount then
        local count = 0
        for name, obj in pairs(fRaid.db.global.Instance.ZoneList) do
            count = count + 1
        end
        fRaid.db.global.Instance.Count = count
    end
    return fRaid.db.global.Instance.Count
end

function fRaid.Instance.GetObject(zonename, createnew)
    local obj = fRaid.db.global.Instance.ZoneList[zonename]
    if createnew and not obj then
        --create a new one
        obj = {}
        fRaid.db.global.Instance.ZoneList[zonename] = obj
        fRaid.db.global.Instance.Count = fRaid.db.global.Instance.Count + 1
        fRaid.db.global.Instance.LastModified = fLib.GetTimestamp()  
    end
    return obj
end

function fRaid.Instance.PLAYER_ENTERING_WORLD()
    local inInstance, instanceType = IsInInstance()
    if inInstance then-- and instanceType == 'raid' then
        --add to InstanceList if not already in it
        local zonename = GetRealZoneText()
        local instanceobj = fRaid.Instance.GetObject(zonename, true)
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
        --create index table
        mf.index_to_name = {}
        mf.lastmodified = 0
        
        mf.table = fLibGUI.Table.CreateTable(mf, 100, 200, 1) 
        mf.table:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -65)
        
        function mf:RetrieveData(index)
            local name, data
            if not index or index < 1 then
            index = self.table.selectedindex
            end
            
            name = self.index_to_name[index]
            data = fRaid.db.global.Instance.ZoneList[name]
                
            return name, data
        end
                
        function mf:RefreshIndex(force)
            if mf.lastmodified ~= fRaid.db.global.Instance.LastModified or force then
                --print('Refreshing index...')
                table.wipe(mf.index_to_name)
                mf.lastmodified = fRaid.db.global.Instance.LastModified
                
                local obj, previ
                for name,data in pairs(fRaid.db.global.Instanze.ZoneList) do
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
            --print('Loading rows...')
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
                name, data = self:RetrieveData(index)

                if not data then
                    for j = 1, self.table.colcount do
                        self.table.columns[j].cells[i]:SetText('')
                    end
                
                    self.table.rowbuttons[i]:Hide()
                    self.table.rowbuttons[i].index = 0
                else
                    --fill in cells with stuff
                    self.table.columns[1].cells[i]:SetText(name)
                    
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
            --[[
            local name, data = self:RetrieveData()
            if name and data then
                self.title_name:SetText(name)
                self.title_dkp:SetText(data.dkp)
            else
                self.title_name:SetText('')
                self.title_dkp:SetText('')
            end
            --]]
        end

        --a and b are indexes in ListIndex
        mf.sortkeeper = {
        {asc = false, issorted = false, name = 'Name'},
        }
        function mf.lootcomparer(a, b) --a and b are names
            --retrieve data
            local adata = fRaid.db.global.Instance.ZoneList[a]
            local bdata = fRaid.db.global.Instance.ZoneList[b]
        
            --find the sorted column and how it is sorted
            local SORT = mf.table.selectedcolnum
            local SORT_ASC = mf.sortkeeper[SORT].asc
            local SORT_NAME = mf.sortkeeper[SORT].name
        
            local ret = a > b
        
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
        mf.table.columns[i]:SetWidth(100)
        i = i + 1
        
            
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