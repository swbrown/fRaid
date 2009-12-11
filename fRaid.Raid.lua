-- Author      : Jessica Chen Huang
-- Create Date : 1/7/2009 10:41:06 AM

--fRaid.db.global.Raid.CurrentRaid
--fRaid.db.global.Raid.IsAwardProgressionTimerOn
--fRaid.db.global.Raid.RaidList
--fRaid.db.global.Raid.LastModified
--fRaid.GUI2.RaidFrame

fRaid.Raid = {}
fRaid.Raid.IsInRaid = false
local MYGUILD = GetGuildInfo('player')
local curraidobj = nil

local TIMER_INTERVAL = 300 --secs (5 minutes)

function fRaid.Raid.OnInitialize()
	fRaid:Debug("<<fRaid.Raid.OnInitialize>>")
	if fRaid.db.global.Raid.CurrentRaid then
		if not curraidobj then
			curraidobj = fRaid.Raid.raidobj.new()
			curraidobj:Load(fRaid.db.global.Raid.CurrentRaid)
		end
		--curraidobj:UpdateRaiders()
		--curraidobj:UpdateListed()
		
		if not fRaid.Raid.UpdateTimer then
			fRaid.Raid.UpdateTimer = fRaid:ScheduleRepeatingTimer(fRaid.Raid.TimeUp, TIMER_INTERVAL)
		end
	end
end

--this runs every 5 minutes
--it awards progression dkp (if its on)
--it checks who's listed and updates our list of listed peeps
--since this only runs every 5 minutes, a consequence is that
----people who list < 5 minutes before a boss kill or progression
----dkp awarding will not get dkp, but that's okay, in fact
----that's a good thing
function fRaid.Raid.TimeUp()
	fRaid:Debug("<<fRaid.Raid.TimeUp>>")
	if fRaid.Raid.IsTracking() then
		fRaid.Raid.AwardProgressionDkp()
		--curraidobj:UpdateRaiders()
		curraidobj:UpdateListed()
	end
end

function fRaid.Raid.IsTracking()
	if curraidobj and fRaid.db.global.Raid.CurrentRaid then
		return true
	end
	return false
end

function fRaid.Raid.GetRaidObj()
	return curraidobj
end

function fRaid.Raid.RAID_ROSTER_UPDATE()
	fRaid:Debug("<<fRaid.Raid.RAID_ROSTER_UPDATE>>")
    if fRaid.Raid.IsTracking() then --currently tracking a raid    
        if UnitInRaid('player') then
            --update current raiders
            curraidobj:UpdateRaiders()
            --not updating listed b/c if they haven't been listed
            --for a significant amount of time, they shouldn't get dkp
            --so listed is getting updated every 5 minutes up at TimeUp
        else
            --ask if they want to stop tracking a raid
            --fRaid.Raid.TrackRaiders()
            fRaid:ConfirmDialog2('Would you like to stop raid tracking?', fRaid.Raid.Stop)
            fRaid.Raid.IsInRaid = false
        end
    else
    	fRaid:Debug("fRaid.Raid.RAID_ROSTER_UPDATE", 'not tracking')
        if UnitInRaid('player') then
        	fRaid:Debug("fRaid.Raid.RAID_ROSTER_UPDATE", 'UNIT IN RAID')
            if not fRaid.Raid.IsInRaid then --only the first time join raid
                --ask if they want to start tracking a raid
                fRaid:ConfirmDialog2('Would you like to start raid tracking?', fRaid.Raid.Start)
            end
            fRaid.Raid.IsInRaid = true
        else
            fRaid.Raid.IsInRaid = false
        end
    end
end

function fRaid.Raid.Start()
    if fRaid.Raid.IsTracking() then
        fRaid:Print('You are already tracking a raid.')
    else
        --start tracking
        curraidobj = fRaid.Raid.raidobj.new()
        curraidobj:Start()
        fRaid.db.global.Raid.CurrentRaid = curraidobj.Data
        
        curraidobj:UpdateRaiders()
        curraidobj:UpdateListed()
        
       	fRaid.Raid.UpdateTimer = fRaid:ScheduleRepeatingTimer(fRaid.Raid.TimeUp, TIMER_INTERVAL)

        
        --fRaid.Raid.TrackRaiders()
        
        fRaid:Print('Raid tracking started.')
    end
end

function fRaid.Raid.Stop()
	if fRaid.Raid.IsTracking() then
	    --stop tracking
	    fRaid:CancelTimer(fRaid.Raid.UpdateTimer)
	    curraidobj:Stop()
		fRaid.Raid.StopProgressionDkpTimer()
		
		--save listed players who haven't been in the raid already
		--fRaid.Raid.SaveListedPlayers()
		
	    --archive CurrentRaid
	    if not fRaid.db.global.Raid.RaidList[UnitName('player')] then
	        fRaid.db.global.Raid.RaidList[UnitName('player')] = {}
	    end
	    tinsert(fRaid.db.global.Raid.RaidList[UnitName('player')], fRaid.db.global.Raid.CurrentRaid)
	    fRaid.db.global.Raid.LastModified = fLib.GetTimestamp()
	    
	    fRaid.db.global.Raid.CurrentRaid = nil
	    curraidobj = nil
	    
	    fRaid:Print('Raid tracking stopped.')
	    
	    --update attendance last 32 raids
	    fRaid.Player.UpdateAttendance(16)
	    fRaid.Player.PrintAttendance("GUILD")
	    --fLib.Guild.RefreshStatus(fRaid.Player.UpdateRankByAttendance) no longer changing people's ranks
	    --new attendance flag (high/low) gets changed in UpdateAttendance)
	    fRaid.Player.UpdateFlagByAttendance()
	else
		fRaid:Print('No raid is being tracked.')
	end
end

function fRaid.Raid.DkpCheckin(idx, name)
	fRaid:Debug("<<fRaid.Raid.DkpCheckin>>")
	if fRaid.Raid.IsTracking() then
		curraidobj:UpdateDkpCharge(idx, name)
	else
		--TODO: whisper back that there's no raid being tracked
		--fRaid:Whisper(name, "No raid is currently being tracked.")
		fRaid.Whisper2("No raid is currently being tracked.", name)
	end
end
--[[
function fRaid.Raid.SaveListedPlayers()
	--save listed players who haven't been in the raid already
	if fRaid.Raid.IsTracking() then
		local tempp = fList.GetPlayers()
		for idx, name in ipairs(tempp) do
			if not fRaid.db.global.Raid.CurrentRaid.RaiderList[name] then
				if not fLib.ExistsInList(fRaid.db.global.Raid.CurrentRaid.ListedPlayers, name) then
					tinsert(fRaid.db.global.Raid.CurrentRaid.ListedPlayers, name)
				end
			end
		end
	else
		fRaid:Print('No raid is being tracked.')
	end
end
--]]
--[[
--track the raiders who have joined or left the raid
function fRaid.Raid.TrackRaiders()
    --print('Tracking raiders...')
    local name, raiderobj, timestampobj
    local newraiderlist = {}
    
    --track players in raid
    for i = 1, GetNumRaidMembers() do
        name = GetRaidRosterInfo(i)
        if name then
            --print('Found ' .. name)
            local g, _, r = GetGuildInfo('raid' .. i)
            
            raiderobj = fRaid.db.global.Raid.CurrentRaid.RaiderList[name]
            if not raiderobj then
                --create new raiderobj
                raiderobj = {
                    guild = g, --maybe they aren't in our guild
                    rank = r, --maybe their rank changes over time? so should remember what it was
                    timestamplist = {
                        {starttime = fLib.GetTimestamp()}
                    }
                }
            end
            
            --update timestamp if they are rejoining raid
            timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
            if timestampobj.endtime then
                --create a new timestampobj
                timestampobj = {
                    starttime = fLib.GetTimestamp()
                }
                tinsert(raiderobj.timestamplist, timestampobj)
            end
            
            --should we update their guild and rank?... i guess so?...
            raiderobj.guild = g
            raiderobj.rank = r
            
            newraiderlist[name] = raiderobj --add to new list
            fRaid.db.global.Raid.CurrentRaid.RaiderList[name] = nil --remove from old list
        end
    end
    
    --track players that left
    for name, raiderobj in pairs(fRaid.db.global.Raid.CurrentRaid.RaiderList) do
        --print('ending ' .. name)
        timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
        if not timestampobj.endtime then
            timestampobj.endtime = fLib.GetTimestamp()
        end
        
        newraiderlist[name] = raiderobj
        fRaid.db.global.Raid.CurrentRaid.RaiderList[name] = nil
    end
    
    fRaid.db.global.Raid.CurrentRaid.RaiderList = newraiderlist
    
    --TODO: fill in listed players
    --check to see if the listed player was in the raider list
    --if they weren't, then keep t hem in listed players
end
--]]
--should only be called by the scheduled timer
function fRaid.Raid.AwardProgressionDkp()
	if fRaid.Raid.IsTracking() and fRaid.db.global.Raid.IsAwardProgressionTimerOn then
		--check that its time for the next award
		if curraidobj.Data.NextProgDkpAwarded and fLib.GetTimestamp() >= curraidobj.Data.NextProgDkpAwarded then
			--award
			curraidobj:AddDkpCharge(5)
			--update NextProgDkpAwarded
			curraidobj.Data.NextProgDkpAwarded = fLib.GetTimestamp(fLib.AddMinutes(nil, 30))
		end
	end
end

function fRaid.Raid.StartProgressionDkpTimer()
	fRaid.db.global.Raid.IsAwardProgressionTimerOn = true
	curraidobj.Data.NextProgDkpAwarded = fLib.GetTimestamp(fLib.AddMinutes(nil, 30))
	fRaid:Print('Progression Dkp Timer started.')
end

function fRaid.Raid.StopProgressionDkpTimer()
	 fRaid.db.global.Raid.IsAwardProgressionTimerOn = false
	 curraidobj.Data.NextProgDkpAwarded = nil
	 fRaid:Print('Progression Dkp Timer stopped.')
end

--returns a sorted list of {owner,idx}
--max is the maximum number of raids to return
function fRaid.Raid.GetSortedRaidList(max)
	local function raidobjcomparer(data1, data2)
		--data1/2 is a list containing owner and idx
		local time1 = fRaid.db.global.Raid.RaidList[data1[1]][data1[2]].StartTime
		local time2 = fRaid.db.global.Raid.RaidList[data2[1]][data2[2]].StartTime
		return time1 < time2
	end

	local temp = {}
	for owner, ownersection in pairs(fRaid.db.global.Raid.RaidList) do
		for idx, raidobj in ipairs(ownersection) do
			tinsert(temp, {owner, idx})
		end
	end
	
	sort(temp, raidobjcomparer)
	
	if max and max > 0 then
		--keep removing one off the end until we only have max left
		while #temp > max do
			tremove(temp, 1)
		end
	end
	
	return temp
end

------------------------------
--Raid Simulation Functions---

--------------------------------------
--------------------------------------

function fRaid.Raid.MergeRaidLists(l1, l2)
    --merge raidlists...
    
    --compile complete user list
    local names = {}
    for name, data in pairs(l1) do
        names[name] = true
    end
    
    for name, data in pairs(l2) do
        names[name] = true
    end
    
    local l11, l22
    local i11, i22
    local r11, r22
    
    local keepgoing = true
    local keepgoingi = 1
    local keepgoinglimit = 10000
    
    local stoppedmatching = false
    
    for name, _ in pairs(names) do
        print('scanning ' .. name)
        l11 = l1[name]
        l22 = l2[name]
        
        if not l11 or not l22 then
            if l11 then
            l2[name] = l11
            elseif l22 then
            l1[name] = l22
            end
        else
            i11 = 1
            i22 = 1
            keepgoing = true
            keepgoingi = 1
            while keepgoing do
                r11 = l11[i11]
                r22 = l22[i22]
                
                if not r11 or not r22 then
                    if r11 then
                        tinsert(l22, r11)
                        i11 = i11 + 1
                        i22 = i22 + 1
                    elseif r22 then
                        tinsert(l11, r22)
                        i11 = i11 + 1
                        i22 = i22 + 1
                    else
                        keepgoing = false
                        print('l11 ended at i11 = ' .. i11)
                        print('l22 ended at i22 = ' .. i22)
                    end
                else
                    if r11.StartTime == r22.StartTime then
                        if stoppedmatching then
                            stoppedmatching = false
                            print('resumed matching at i11 = ' .. i11 .. ', ' .. 'i22 = ' .. i22)
                        end
                        i11 = i11 + 1
                        i22 = i22 + 1
                    else
                        if not stoppedmatching then
                            stoppedmatching = true
                            print('stopped matching at i11 = ' .. i11 .. ', ' .. 'i22 = ' .. i22)
                        end
                        if r11.StartTime < r22.StartTime then
                            tinsert(l22, i22, r11)
                        else
                            tinsert(l11, i11, r22)
                        end
                    end
                end
                
                keepgoingi = keepgoingi + 1
                if keepgoingi > keepgoinglimit then
                    keepgoing = false
                end
            end
        end
    end
end

--==================================================================================================

function fRaid.Raid.View()
    local mf = fRaid.GUI2.RaidFrame

    if not mf.viewedonce then
    	local ui
    	
    	--Award Dkp
    	ui = fLibGUI.CreateLabel(mf)
    	ui:SetText('Award dkp to raid')
    	ui:SetPoint('TOPLEFT', 5, -5)
    	
    	local x = ui:GetWidth() + 13
    	
    	ui = fLibGUI.CreateEditBox(mf, '#')
    	ui:SetPoint('TOPLEFT', x, -4)
    	ui:SetWidth(60)
    	ui:SetNumeric(true)
    	ui:SetNumber(0)
    	ui:SetScript('OnEnterPressed', function() 
    		if this:GetNumber() > 0 then
    			if fRaid.Raid.IsTracking() then
    				curraidobj:AddDkpCharge(this:GetNumber())
    			else
    				fRaid:Print("No raid is being tracked.")
    			end
    		end
    		this:ClearFocus()
    		this:SetNumber(0)
    	end)
    	
    	--Start/Stop Tracking
    	ui = fLibGUI.CreateActionButton(mf)
    	mf.ButtonTracking = ui
    	ui:SetFrameLevel(3)
    	ui.highlightspecial = ui:CreateTexture(nil, "BACKGROUND")
    	ui.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    	ui.highlightspecial:SetBlendMode("ADD")
    	ui.highlightspecial:SetAllPoints(ui)
    	ui.highlightspecial:Hide()
    	ui:SetText('Start Raid Tracking')
    	ui:SetWidth(ui:GetTextWidth())
    	ui:SetHeight(ui:GetTextHeight())
    	ui:SetScript('OnClick', function()
    		if fRaid.Raid.IsTracking() then
    			fRaid.Raid.Stop()
    			this.highlightspecial:Hide()
    			this:SetText('Start Raid Tracking')
    			mf.ButtonProgression.highlightspecial:Hide()
    			mf.ButtonProgression:SetText('Stop Progression Dkp Timer')
    		else
    			fRaid.Raid.Start()
    			this.highlightspecial:Show()
    			this:SetText('Stop Raid Tracking')
    		end
	    end)
	    ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -30)
    	
    	--Start/Stop Progression Dkp Timer
    	ui = fLibGUI.CreateActionButton(mf)
    	mf.ButtonProgression = ui
    	ui:SetFrameLevel(3)
    	ui.highlightspecial = ui:CreateTexture(nil, "BACKGROUND")
    	ui.highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    	ui.highlightspecial:SetBlendMode("ADD")
    	ui.highlightspecial:SetAllPoints(ui)
    	ui.highlightspecial:Hide()
    	ui:SetText('Start Progression Dkp Timer')
    	ui:SetWidth(ui:GetTextWidth())
    	ui:SetHeight(ui:GetTextHeight())
    	ui:SetScript('OnClick', function()
    		if fRaid.db.global.Raid.CurrentRaid then
    			if not fRaid.db.global.Raid.IsAwardProgressionTimerOn then
    				fRaid.Raid.StartProgressionDkpTimer()
    				this.highlightspecial:Show()
    				this:SetText('Stop Progression Dkp Timer')
    			else
    				fRaid.Raid.StopProgressionDkpTimer()
    				this.highlightspecial:Hide()
    				this:SetText('Start Progression Dkp Timer')
    			end
    		else
    			fRaid:Print('Raid tracking is not on.')
    		end
    	end)
    	ui:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -50)
    	
    	mf.viewedonce = true
    end
    
    --Fix the start/stop buttons to show the right text and highlights
    if fRaid.Raid.IsTracking() then
    	mf.ButtonTracking.highlightspecial:Show()
    	mf.ButtonTracking:SetText('Stop Raid Tracking')
    else
    	mf.ButtonTracking.highlightspecial:Hide()
    	mf.ButtonTracking:SetText('Start Raid Tracking')
    end
    if fRaid.db.global.Raid.IsAwardProgressionTimerOn then
	    mf.ButtonProgression.highlightspecial:Show()
	    mf.ButtonProgression:SetText('Stop Progression Dkp Timer')
	else
		mf.ButtonProgression.highlightspecial:Hide()
		mf.ButtonProgression:SetText('Start Progression Dkp Timer')
	end
    
    
    mf:Show()
end
