-- Author      : Jessica Chen Huang
-- Create Date : 1/7/2009 10:41:06 AM

--fRaid.db.global.Raid.CurrentRaid
--fRaid.db.global.Raid.RaidList
--fRaid.db.global.Raid.LastModified
--fRaid.GUI2.RaidFrame

fRaid.Raid = {}
fRaid.Raid.IsInRaid = false
local MYGUILD = GetGuildInfo('player')

function fRaid.Raid.RAID_ROSTER_UPDATE()
    if fRaid.db.global.Raid.CurrentRaid then --currently tracking a raid
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
    if fRaid.db.global.Raid.CurrentRaid then
        fRaid:Print('You are already tracking a raid.')
    else
        --start tracking
        fRaid.db.global.Raid.CurrentRaid = {}
        
        fRaid.db.global.Raid.CurrentRaid.StartTime = fLib.GetTimestamp()
        fRaid.db.global.Raid.CurrentRaid.Owner = UnitName('player')
        
        fRaid.db.global.Raid.CurrentRaid.IsProgression = false
        
        fRaid.db.global.Raid.CurrentRaid.RaiderList = {}
        fRaid.Raid.TrackRaiders()
        
        fRaid:Print('Raid tracking started.')
    end
end

function fRaid.Raid.Stop()
    --stop tracking
    fRaid.db.global.Raid.CurrentRaid.EndTime = fLib.GetTimestamp()

    --archive CurrentRaid
    if not fRaid.db.global.Raid.RaidList[UnitName('player')] then
        fRaid.db.global.Raid.RaidList[UnitName('player')] = {}
    end
    tinsert(fRaid.db.global.Raid.RaidList[UnitName('player')], fRaid.db.global.Raid.CurrentRaid)
    fRaid.db.global.Raid.LastModified = fLib.GetTimestamp()
    
    fRaid.db.global.Raid.CurrentRaid = nil
    
    fRaid:Print('Raid tracking stopped.')
end


--track the raiders who have joined or left the raid
function fRaid.Raid.TrackRaiders()
    print('Tracking raiders...')
    local name, raiderobj, timestampobj
    local newraiderlist = {}
    
    --track players in raid
    for i = 1, GetNumRaidMembers() do
        name = GetRaidRosterInfo(i)
        if name then
            print('Found ' .. name)
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
        print('ending ' .. name)
        timestampobj = raiderobj.timestamplist[#raiderobj.timestamplist]
        timestampobj.endtime = fLib.GetTimestamp()
        
        newraiderlist[name] = raiderobj
        fRaid.db.global.Raid.CurrentRaid.RaiderList[name] = nil
    end
    
    fRaid.db.global.Raid.CurrentRaid.RaiderList = newraiderlist
end

--==================================================================================================

function fRaid.Raid.View()
    local mf = fRaid.GUI2.RaidFrame

    if not mf.viewedonce then
    end
end
