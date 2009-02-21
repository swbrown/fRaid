-- Author      : Jessica Chen Huang
-- Create Date : 1/7/2009 10:41:06 AM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.RaidList
--fRaid.GUI2.RaidFrame

fRaid.Raid = {}
fRaid.Raid.IsInRaid = false

function fRaid.Raid.RAID_ROSTER_UPDATE()
    if fRaid.db.global.CurrentRaid then --currently tracking a raid
        if UnitInRaid('player') then
            --update attendance
            fRaid.Raid.TrackRaiders()
        else
            --ask if they want to stop tracking a raid
            fRaid:ConfirmDialog2('Would you like to stop raid tracking?', fRaidBid.Raid.Stop())
            fRaid.Raid.IsInRaid = false
        end
    else
        if UnitInRaid('player') then
            if not fRaid.Raid.IsInRaid then --only the first time join raid
                --ask if they want to start tracking a raid
                fRaid:ConfirmDialog2('Would you like to start raid tracking?', fRaidBid.Raid.Start())
            end
            fRaid.Raid.IsInRaid = true
        else
            fRaid.Raid.IsInRaid = false
        end
    end
end

function fRaid.Raid.Start()
    if fRaid.db.global.CurrentRaid then
        fRaid:Print('You are already tracking a raid.')
    else
        --start tracking
        fRaid.db.global.CurrentRaid = {}
        
        fRaid.db.global.StartTime = date("%m/%d/%y %H:%M:%S")
        fRaid.db.global.Owner = UnitName('player')
        
        fRaid.db.global.IsProgression = false
        
        fRaid.db.global.RaiderList = {}
        fRaid.Raid.TrackRaiders()
        
        fRaid:Print('Raid tracking started.')
    end
end

function fRaid.Raid.Stop()
    --archive CurrentRaid
    fRaidBid.db.global.CurrentRaid = nil
    
    fRaid:Print('Raid tracking stopped.')
end


--track the raiders who have joined or left the raid
function fRaid.Raid.TrackRaiders()
    local name, raiderobj, timestampobj
    local newraiderlist = {}
    
    --track players in raid
    for i = 1, GetNumRaidMembers() do
        name = GetRaidRosterInfo(i)
        if name then
            raiderobj = fRaid.db.global.RaiderList[name]
            if not raiderobj then
                --create new raiderobj
                raiderobj = {
                    rank = '', --maybe their rank changes over time? so should remember what it was
                    timestamplist = {
                        {starttime = date("%m/%d/%y %H:%M:%S")}
                    }
                }
            end
            
            --update timestamp if they are rejoining raid
            timestampobj = raiderobj.timestamplist[#timestamplist]
            if timestampobj.endtime then
                --create a new timestampobj
                timestampobj = {
                    starttime = date("%m/%d/%y %H:%M:%S")
                }
                tinsert(raiderobj.timestamplist, timestampobj)
            end
            
            newraiderlist[name] = raiderobj --add to new list
            fRaid.db.global.RaiderList[name] = nil --remove from old list
        end
    end
    
    --track players that left
    for name, raiderobj in pairs(fRaid.db.global.RaiderList) do
        timestampobj = raiderobj.timestamplist[#timestamplist]
        timestampobj.endtime = date("%m/%d/%y %H:%M:%S")
        
        newraiderlist[name] = raiderobj
        fRaid.db.global.RaiderList[name] = nil
    end
    
    fRaid.db.global.RaiderList = newraiderlist
end

function fRaid.Raid.Startx()
    --if CurrentRaid is already started, warn that one is already started
    if fRaid.db.global.CurrentRaid then
        Raid:Print('A raid has already been started.')
    else

        
        --add current raiders to raiders
        for i=1,GetNumRaidMembers() do 
            name = GetRaidRosterInfo(i)
            if name then
                local raiderobj = {
                    id = fRaidPlayer.GetPlayerId(name, true),
                    timestamp = curtimestamp,
                    timestamplist = {},
                }
                tinsert(raidobj.raiders, raiderobj)
            end
        end
        
        fRaid.db.global.CurrentRaid = raidobj
        fRaid:Print('Raid started')
    end
end

function fRaid.Raid.Close()
    if fRaid.db.global.CurrentRaid then
        fRaid.db.global.CurrentRaid.timestamp.endtime = date("%m/%d/%y %H:%M:%S")
        tinsert(fRaid.db.global.RaidList, fRaid.db.global.CurrentRaid)
        fRaid.db.global.CurrentRaid = nil
        fRaid:Print('Raid closed')
    end
end

function fRaid.RAID_ROSTER_UPDATE()
    
end

--==================================================================================================

function fRaid.Raid.View()
    local mf = fRaid.GUI2.RaidFrame

    if not mf.viewedonce then
    end
end
