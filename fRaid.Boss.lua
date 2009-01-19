-- Author      : Jessica Chen Huang
-- Create Date : 1/2/2009 2:35:39 PM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.BossList
--fRaid.GUI2.BossFrame

fRaid.Boss = {}

function fRaid.Boss.BossNameToIndex(bossname, instanceIdx)
	return fRaid.db.global.BossListIndex[bossname..instanceIdx]
end
	
--recreates the ListIndex (maps boss name instance index to index)
function fRaid.Boss.RefreshIndex()
	wipe(fRaid.db.global.BossListIndex)
	for idx, obj in ipairs(fRaid.db.global.BossList) do
		if obj.isvalid then
			fRaid.db.global.BossListIndex[obj.name..obj.instanceIdx] = idx
		end
	end
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
	
		local tex = fLib.GUI.CreateSeparator(mf)
		--tex:SetWidth(mf:GetWidth() - 32)
		tex:SetWidth(1)
		tex:SetHeight(mf:GetHeight() - 32)
		tex:SetPoint('TOPLEFT', mf, 'TOPLEFT', 100,-5)

	
		local title = fLib.GUI.CreateLabel(mf)
		title:SetText('Name:')
		title:SetPoint('TOPLEFT', mf, 'TOPLEFT', 105, -5)
		local prevtitle = title
		
		mf.title_name = fLib.GUI.CreateLabel(mf)
		mf.title_name:SetText('')
		mf.title_name:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLib.GUI.CreateLabel(mf)
		title:SetText('Location:')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		prevtitle = title

		mf.title_location = fLib.GUI.CreateLabel(mf)
		mf.title_location:SetText('')
		mf.title_location:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLib.GUI.CreateLabel(mf)
		title:SetText('Dkp Award')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		
		mf.eb_dkpaward = fLib.GUI.CreateEditBox(mf, '#')
		mf.eb_dkpaward:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		mf.eb_dkpaward:SetWidth(60)
		mf.eb_dkpaward:SetNumeric(true)
		mf.eb_dkpaward:SetNumber(0)
		mf.eb_dkpaward:SetScript('OnEnterPressed', function() 
			if this:GetNumber() > 0 then
				--fRaidPlayer:AddDKPToRaid(eb_dkpaward:GetNumber())
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