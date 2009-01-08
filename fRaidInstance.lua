-- Author      : Jessica Chen Huang
-- Create Date : 1/1/2009 12:36:55 AM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.InstanceList
--fRaid.GUI2.InstanceFrame

fRaidInstance = {}

function fRaidInstance.PLAYER_ENTERING_WORLD()
	local inInstance, instanceType = IsInInstance()
	if inInstance and instanceType == 'raid' then
		--add to InstanceList if not already in it
		local zonename = GetRealZoneText()
		local instancenum = 0
		local alreadyexists = false
		for instanceobj in ipairs(fRaid.db.global.InstanceList) do
			if zonename == instanceobj.name then
				alreadyexists = true
				instancenum = instanceobj.instancenum
				break
			end
		end
		
		if not alreadyexists then
			tinsert(fRaid.db.global.InstanceList, {
				instancenum = #fRaid.db.global.InstanceList + 1,
				name = GetRealZoneText(),
				bossnums = {}
			})
			instancenum = #fRaid.db.global.InstanceList
		end
	
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

function fRaidInstance.View()
	local mf = fRaid.GUI2.InstanceFrame

	if not mf.viewedonce then	
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