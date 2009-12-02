-- Author      : Jessica Chen Huang
-- Create Date : 1/2/2009 2:35:39 PM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.BossList
--fRaid.GUI2.BossFrame

fRaid.Boss = {}

function fRaid.Boss.PLAYER_REGEN_DISABLED()
	
end

--TODO: award dkp to raid if mob is in moblist
function fRaid.Boss.COMBAT_LOG_EVENT_UNFILTERED(eventName, _, event, _, _, _, guid, mob)
	if event ~= 'UNIT_DIED' and event ~= 'PARTY_KILL' then return end
	if guid and mob then
		--fRaid:Print('killed', guid, mob)
	--save it
	--fRaidMob.Add(mob, GetRealZoneText())
	
	
	--award dkp popup if in raid
	
	end
end

function fRaid.Boss.BossNameToIndex(bossname, instanceIdx)
	if not fRaid.db.global.BossListIndex then
		fRaid.db.global.BossListIndex = {}
	else
		return fRaid.db.global.BossListIndex[bossname..instanceIdx]
	end
end
	
--recreates the ListIndex (maps boss name instance index to index)
function fRaid.Boss.RefreshIndex()
	if not fRaid.db.global.BossListIndex then
		fRaid.db.global.BossListIndex = {}
	else
		wipe(fRaid.db.global.BossListIndex)
		fRaid.db.global.BossListIndexCount = 0
	end
	local count = 0
	wipe(fRaid.db.global.BossListIndex)
	for idx, obj in ipairs(fRaid.db.global.BossList) do
		if obj.isvalid then
			if fRaid.db.global.BossListIndex[obj.id] and announceduplicates then
				fRaid:Print('ERROR: duplicate boss found.  ID:', obj.id, ', index:', idx, '.')
			end
			fRaid.db.global.BossListIndex[obj.name..obj.instanceIdx] = idx
			count = count + 1
		end
	end
	fRaid.db.global.BossListIndexCount = count
end

function fRaid.Boss.GetObjectByIndex(idx)
	return fRaid.db.global.BossList[idx]
end

--id - required, index or bossname of a bossobj
--instanceIdx - index or an instanceobj, required unless bossid is an index
--createnew - optional, create new bossobj if id is boss name and location is provided
--returns bossobj, idx
--return nil, nil if bossobj not found and createnew is false
function fRaid.Boss.GetObjectByName(bossname, instanceidx, createnew)
	--check valid instanceidx
	local instanceobj = fRaid.Instance.GetObjectByIndex(instanceidx)
	if not instanceobj then
		fRaid:Print('ERROR: Invalid instance provided for fRaid.Boss.GetObjectByName.')
		return
	end
	
	local obj, idx
	idx = fRaid.Boss.BossNameToIndex(bossname, instanceidx)
	if idx then
		obj = fRaid.db.global.BossList[idx]
		if not obj then
			--something is wrong with IndexList
			fRaid.Boss.RefreshIndex()
			idx = fRaid.Boss.BossNameToIndex(bossname, instanceidx)
			obj = fRaid.db.global.BossList[idx]
		end
	end

	if not obj and createnew then
		--create new bossobj
		obj = {
			name = bossname,
			instanceIdx = instanceidx,
			dkp = 0,
			itemIdxList = {}, --gets affected by changes to itemobj.bossIdxList
			isvalid = true
		}
		tinsert(fRaid.db.global.BossList, obj)
		
		--update index
		idx = #fRaid.db.global.BossList
		fRaid.db.global.BossListIndex[bossname..instanceidx] = idx
			
		--add bossidx to instanceobj
		local alreadyexists = false
		for qidx, qval in ipairs(instanceobj.bossIdxList) do
			if qval == idx then
				alreadyexists = true
				break
			end
		end
		if not alreadyexists then
			tinsert(instanceobj.bossIdxList, idx)
		end	
	end
	return obj, idx
end

function fRaid.Boss.RemoveByIndex(bossidx, instanceidx)
	--check valid instanceidx
	local instanceobj = fRaid.Instance.GetObjectByIndex(instanceidx)
	if not instanceobj then
		fRaid:Print('ERROR: Invalid instance provided for fRaid.Boss.RemoveByIndex.')
		return
	end
	
	local bossobj = fRaid.Boss.GetObjectByIndex(bossidx)
	if bossobj then
		--check if there are items belonging to this boss
		if #obj.itemIdxList > 0 then
			--can't delete
			fRaid:Print('ERROR: cannot remove this boss because items belong to it.')
		else
			--can delete
			obj.isvalid = false
			--remove from index
			fRaid.db.global.BossListIndex[obj.name] = nil
			--remove from instance
			for qidx, qval in ipairs(instanceobj.bossIdxList) do
				if qval == idx then
					tremove(instanceobj.bossIdxList, qidx)
					break
				end
			end
		end
	end
end
	
--event on kill a boss, award dkp


function fRaid.Boss.View()
	local mf = fRaid.GUI2.BossFrame

	if not mf.viewedonce then	
	
		local tex = fLibGUI.CreateSeparator(mf)
		--tex:SetWidth(mf:GetWidth() - 32)
		tex:SetWidth(1)
		tex:SetHeight(mf:GetHeight() - 32)
		tex:SetPoint('TOPLEFT', mf, 'TOPLEFT', 100,-5)

	
		local title = fLibGUI.CreateLabel(mf)
		title:SetText('Name:')
		title:SetPoint('TOPLEFT', mf, 'TOPLEFT', 105, -5)
		local prevtitle = title
		
		mf.title_name = fLibGUI.CreateLabel(mf)
		mf.title_name:SetText('')
		mf.title_name:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLibGUI.CreateLabel(mf)
		title:SetText('Location:')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		prevtitle = title

		mf.title_location = fLibGUI.CreateLabel(mf)
		mf.title_location:SetText('')
		mf.title_location:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLibGUI.CreateLabel(mf)
		title:SetText('Dkp Award')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		
		mf.eb_dkpaward = fLibGUI.CreateEditBox(mf, '#')
		mf.eb_dkpaward:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		mf.eb_dkpaward:SetWidth(60)
		mf.eb_dkpaward:SetNumeric(true)
		mf.eb_dkpaward:SetNumber(0)
		mf.eb_dkpaward:SetScript('OnEnterPressed', function() 
			if this:GetNumber() > 0 then
				--save the dkp for this boss
			end
			this:ClearFocus()
			--this:SetNumber(0)
		end)
		mf.eb_dkpaward:SetScript('OnEscapePressed', function()
			this:ClearFocus()
			--reset text to original value
		end)
		
		mf.viewedonce = true
	end

	mf:Show()
end
--]]