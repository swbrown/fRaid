-- Author      : Jessica Chen Huang
-- Create Date : 1/2/2009 2:35:39 PM

--fRaid.db.global.CurrentRaid
--fRaid.db.global.BossList
--fRaid.GUI2.BossFrame

fRaidBoss = {}

function fRaidBoss.View()
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