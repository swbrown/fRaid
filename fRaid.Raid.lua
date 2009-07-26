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

function fRaid.Raid.IsTracking()
	if fRaid.db.global.Raid.CurrentRaid then
		return true
	end
	return false
end

function fRaid.Raid.RAID_ROSTER_UPDATE()
    if fRaid.Raid.IsTracking() then --currently tracking a raid
        if UnitInRaid('player') then
            --update attendance
            fRaid.Raid.TrackRaiders()
        else
            --ask if they want to stop tracking a raid
            fRaid.Raid.TrackRaiders()
            fRaid:ConfirmDialog2('Would you like to stop raid tracking?', fRaid.Raid.Stop)
            fRaid.Raid.IsInRaid = false
        end
    else
        if UnitInRaid('player') then
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
        fRaid.db.global.Raid.CurrentRaid = {}
        
        fRaid.db.global.Raid.CurrentRaid.StartTime = fLib.GetTimestamp()
        fRaid.db.global.Raid.CurrentRaid.Owner = UnitName('player')
        
        fRaid.db.global.Raid.CurrentRaid.IsProgression = false
        
        fRaid.db.global.Raid.CurrentRaid.RaiderList = {}
        fRaid.db.global.Raid.CurrentRaid.ListedPlayers = {}
        fRaid.Raid.TrackRaiders()
        
        fRaid:Print('Raid tracking started.')
    end
end

function fRaid.Raid.Stop()
	if fRaid.Raid.IsTracking() then
	    --stop tracking
	    fRaid.db.global.Raid.CurrentRaid.EndTime = fLib.GetTimestamp()
		fRaid.Raid.StopProgressionDkpTimer()
		
		--save listed players
		
		
	    --archive CurrentRaid
	    if not fRaid.db.global.Raid.RaidList[UnitName('player')] then
	        fRaid.db.global.Raid.RaidList[UnitName('player')] = {}
	    end
	    tinsert(fRaid.db.global.Raid.RaidList[UnitName('player')], fRaid.db.global.Raid.CurrentRaid)
	    fRaid.db.global.Raid.LastModified = fLib.GetTimestamp()
	    
	    fRaid.db.global.Raid.CurrentRaid = nil
	    
	    fRaid:Print('Raid tracking stopped.')
	else
		fRaid:Print('No raid is being tracked.')
	end
end


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

--should only be called by the scheduled timer
function fRaid.Raid.AwardProgressionDkp()
	if fRaid.Raid.IsTracking() and fRaid.db.global.Raid.IsAwardProgressionTimerOn then
		fRaid.Player.AddDkpToRaid(5, true)
	end
end

function fRaid.Raid.StartProgressionDkpTimer()
	fRaid.db.global.Raid.IsAwardProgressionTimerOn = true
	fRaid:Print('Progression Dkp Timer started.')
end

function fRaid.Raid.StopProgressionDkpTimer()
	 fRaid.db.global.Raid.IsAwardProgressionTimerOn = false
	 fRaid:Print('Progression Dkp Timer stopped.')
end

function fRaid.Raid.CalculatePlayerAttendance(name)

end

------------------------------
--Raid Simulation Functions---

function fRaid.Raid.CreateRaid(starttime, owner)
	print('creating raid...')
	local raid = {}
	raid.StartTime = starttime
	raid.Owner = owner
	
	raid.IsProgression = false
	
	raid.RaiderList = {}
	raid.ListedPlayers = {}
	
	return raid
end

function fRaid.Raid.SaveRaid(raid, endtime, owner)
	print('saving raid...')
	--stop tracking
	raid.EndTime = endtime
	
	--archive CurrentRaid
	if not fRaid.db.global.Raid.RaidList[owner] then
		fRaid.db.global.Raid.RaidList[owner] = {}
	end
	tinsert(fRaid.db.global.Raid.RaidList[owner], raid)
	fRaid.db.global.Raid.LastModified = fLib.GetTimestamp()
end

function fRaid.Raid.SetRaiders(raid, time, raiderlist, listedlist)
	print('setting raiders...')
	local name, raiderobj, timestampobj
	local newraiderlist = {}
	
	for idx,name in ipairs(raiderlist) do
		print(idx,name)
		raiderobj = raid.RaiderList[name]
		if not raiderobj then
			raiderobj = {
				guild = '', --maybe they aren't in our guild
				rank = '', --maybe their rank changes over time? so should remember what it was
				timestamplist = {
					{starttime = time}
				}
			}
		end
		
		--update timestamp if they are rejoining raid
		timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
		if timestampobj.endtime then
			--create a new timestampobj
				timestampobj = {
				starttime = time
			}
			tinsert(raiderobj.timestamplist, timestampobj)
		end
		
		newraiderlist[name] = raiderobj --add to new list
		raid.RaiderList[name] = nil --remove from old list
	end
	
	--track players that left
	for name, raiderobj in pairs(raid.RaiderList) do
		timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
		if not timestampobj.endtime then
			timestampobj.endtime = time
		end
	
		newraiderlist[name] = raiderobj
		raid.RaiderList[name] = nil
	end
	
	raid.RaiderList = newraiderlist
	
	--TODO: fill in listed players
	--check to see if the listed player was in the raider list
	--if they weren't, then keep t hem in listed players
end




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
    			fRaid.Player.AddDkpToRaid(this:GetNumber(), true)
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
