-- Author      : Jessica Chen Huang
-- Create Date : 1/1/2009 12:36:55 AM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.InstanceList
--fRaid.db.global.InstanceListIndex
--fRaid.GUI2.InstanceFrame

fRaid.Instance = {}

--retrieves index of the instanceobj with zone name
function fRaid.Instance.ZoneNameToIndex(zonename)
	return fRaid.db.global.InstanceListIndex[zonename]
end

--recreates the InstanceListIndex (maps zone name to index)
function fRaid.Instance.RefreshIndex()
	wipe(fRaid.db.global.InstanceListIndex)
	for idx, obj in ipairs(fRaid.db.global.InstanceList) do
		if obj.isvalid then
			fRaid.db.global.InstanceListIndex[obj.name] = idx
		end
	end
end


function fRaid.Instance.GetObjectByIndex(idx)
	return fRaid.db.global.InstanceList[idx]
end

--returns instanceobj, idx
function fRaid.Instance.GetObjectByName(zonename, createnew)
	local obj, idx
	idx = fRaid.Instance.ZoneNameToIndex(zonename)
	if idx then
		obj = fRaid.db.global.InstanceList[idx]
		if not obj then
			--something is wrong with IndexList
			fRaid.Instance.RefreshIndex()
			idx = fRaid.Instance.ZoneNameToIndex(zonename)
			obj = fRaid.db.global.InstanceList[idx]
		end
	end

	if not obj and createnew then
		--create new instanceobj
		obj = {
			name = zonename,
			bossIdxList = {}, --gets changed when bossobjs are created/removed
			isvalid = true
		}
		tinsert(fRaid.db.global.InstanceList, obj)
		
		--update index
		idx = #fRaid.db.global.InstanceList
		fRaid.db.global.InstanceListIndex[id] = idx
	end
	return obj, idx
end

function fRaid.Instance.RemoveByIndex(idx)
	local obj = fRaid.db.global.InstanceList[idx]
	if obj then
		--check if there are bosses belonging to this instance
		if #obj.bossIdxList > 0 then
			--can't delete
			fRaid:Print('ERROR: cannot remove this instance because bosses belong to it.')
		else
			--can delete
			obj.isvalid = false
			--remove from index
			fRaid.db.global.InstanceListIndex[obj.name] = nil
		end
	end
end

function fRaid.Instance.PLAYER_ENTERING_WORLD()
	local inInstance, instanceType = IsInInstance()
	if inInstance and instanceType == 'raid' then
		--add to InstanceList if not already in it
		local zonename = GetRealZoneText()
		local instanceobj, idx = fRaid.Instance.GetObjectByName(zonename, true)
	
		--if current raid is open / exists?
		--add instance to the current raid instance list
		if fRaid.db.global.CurrentRaid then
			local instancevisitobj = fRaid.db.global.CurrentRaid.instancevisitobjs[#fRaid.db.global.CurrentRaid.instancevisitobjs]
			if not instancevisitobj or instancenum ~= instancevisitobj.instancenum then
				instancevisitobj = {
					instancenum = instancenum,
					timearrived = date("%m/%d/%y %H:%M:%S")
				}
				tinsert(fRaid.db.global.CurrentRaid.instancevisitobjs, instancevisitobj)
			end
		end
	end
end

function fRaid.Instance.View()
	local mf = fRaid.GUI2.InstanceFrame

	if not mf.viewedonce then
		--------------------------------------------------------------
		--Top Section-------------------------------------------------
		--------------------------------------------------------------
		local title = fLib.GUI.CreateLabel(mf)
		title:SetText('Current Zone:')
		title:SetPoint('TOPLEFT', mf, 'TOPLEFT', 5, -5)
		local prevtitle = title
		
		mf.title_curzone = fLib.GUI.CreateLabel(mf)
		mf.title_curzone:SetText('...')
		mf.title_curzone:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLib.GUI.CreateLabel(mf)
		title:SetText('Instance?')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)
		prevtitle = title

		mf.title_isinstance = fLib.GUI.CreateLabel(mf)
		mf.title_isinstance:SetText('...')
		mf.title_isinstance:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		title = fLib.GUI.CreateLabel(mf)
		title:SetText('Instance Type:')
		title:SetPoint('TOPLEFT', prevtitle, 'BOTTOMLEFT', 0, -5)

		mf.title_instancetype = fLib.GUI.CreateLabel(mf)
		mf.title_instancetype:SetText('...')
		mf.title_instancetype:SetPoint('TOPLEFT', title, 'TOPRIGHT', 5, 0)
		
		local tex = fLib.GUI.CreateSeparator(mf)
		tex:SetWidth(mf:GetWidth() - 32)
		tex:SetPoint('TOP', mf, 'TOP', 0,-55)
		
		--------------------------------------------------------------
		--InstanceList Section-------------------------------------------------
		--------------------------------------------------------------
		
		
		
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