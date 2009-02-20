--AceAddon-3.0
--AceConsole-3.0
--AceEvent-3.0
--AceTimer-3.0
--AceDB-3.0
--AceConfig-3.0
--AceConfigDialog-3.0

fRaid = LibStub("AceAddon-3.0"):NewAddon("fRaid", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "fLib")
local addon = fRaid
local NAME = 'fRaid'
local DBNAME = 'fRaidDB'
local MYNAME = UnitName('player')
local db = {}

local options = {
	type='group',
	name = NAME,
	handler = addon,
	args = {
		debug = {
			order = -1,
			type = "toggle",
			name = 'Debug',
            desc = "Enables and disables debug mode.",
            get = "GetOptions",
            set = "SetOptions",
		},
	    config = {
	    	order = -1,
	    	type = 'execute',
	    	name = 'config',
	    	desc = 'Opens configuration window',
	    	func = 'OpenConfig',
	    	guiHidden = true,
	    },
	    prefix = {
			order = 21,
			type = 'group',
			name = 'Prefixes (for whispers)',
			desc = 'Special words that players can use to whisper you',
			args = {
				warning = {
					order = 0,
					type = 'description',
					name = 'blah blah blah',
				},
				bid = {
					order = 5,
					type = 'input',
					name = 'Bid Prefix',
					desc = 'Special word allowing players to bid',
					get = 'GetOptions',
					set = 'SetOptions',
				},
				dkp = {
					order = 5,
					type = 'input',
					name = 'DKP Prefix',
					desc = 'Special word allowing players to find out a player\'s DKP',
					get = 'GetOptions',
					set = 'SetOptions',
				},
			}
		},
		cap = {
	    	order = -1,
	    	type = 'input',
	    	name = 'DKP cap',
	    	desc = 'DKP cap',
	    	get = 'GetOptions',
	    	set = 'SetOptions',
	    },
		help = {
			order = 40,
			type = 'group',
			name = 'Help',
			desc = 'Info on how to use this addon.',
			args = {
				text1 = {
					order = 0,
					type = 'description',
					name = [[blah blah blah]]
				},
			},
		}
	}
}

local defaults = {
	global = {
		debug = false,
		prefix = {
			bid = 'bid',
			dkp = 'dkp',
		},
		gui = {
			x = 100, --relative to left
			y = 300, --relative to bottom
		},
		fRaidBid = {
			bidlist = {},
			winnerlist = {},
			gui = {
				x = 200,
				y = 300,
				alwaysshow = false,
			},
		},
		fRaidMob = {
			moblist = {},
		},
		cap = 0, --0 should mean no cap
		InstanceList = {},
		BossList = {},
		ItemList = {},
		PlayerList = {},
		DkpHistoryList = {},
		RaidList = {},
		LootList = {},
		AuctionList = {},
	},
}


--incoming messages
local function WhisperFilter(msg)
	addon:Debug("<<Whisperfilter>>")
	msg = strlower(strtrim(msg))
	if strfind(msg, addon.db.global.prefix.bid) == 1 then
		--add a bid
	end
	if strfind(msg, addon.db.global.prefix.dkp) == 1 then
		return true
	end
	
	--you could change the msg also by doing
	--return false, gsub(msg, "lol", "")
end

--outgoing messages
local function WhisperFilter2(msg)
	if strfind(msg, "%[" .. NAME .. "%]") == 1 then
		return true
	end
	
	--you could change the msg also by doing
	--return false, gsub(msg, "lol", "")
end

--Required by AceAddon
function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(DBNAME, defaults)
	self:Debug(DBNAME .. " loaded")
	db = self.db.global
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable(NAME, options, {NAME})
	self.BlizOptionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(NAME, NAME)
	
	self:RegisterEvent("CHAT_MSG_WHISPER")
	self:RegisterEvent('LOOT_OPENED')--, fRaidLoot.Scan)
	self:RegisterEvent('CHAT_MSG_LOOT', fRaidBid.CHAT_MSG_LOOT)
	--self:RegisterEvent('LOOT_SLOT_CLEARED', fRaidLoot.Test)
	--self:RegisterEvent('CANCEL_LOOT_ROLL', fRaidLoot.Test)
	--self:RegisterEvent('CHAT_MSG_MONEY', fRaidLoot.Test)
	--self:RegisterEvent('CONFIRM_LOOT_ROLL', fRaidLoot.Test)
	--self:RegisterEvent('EQUIP_BIND_CONFIRM', fRaidLoot.Test)
	--self:RegisterEvent('LOOT_BIND_CONFIRM', fRaidLoot.Test)
	self:RegisterEvent('LOOT_CLOSED')--, fRaidLoot.Test)
	--self:RegisterEvent('OPEN_MASTER_LOOT_LIST', fRaidLoot.Test)
	--self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', fRaidLoot.Test)
	--self:RegisterEvent('START_LOOT_ROLL', fRaidLoot.Test)
	--self:RegisterEvent('UPDATE_MASTER_LOOT_LIST', fRaidLoot.Test)
	self:RegisterEvent('LOOT_SLOT_CLEARED')
	--self:RegisterEvent('PLAYER_GUILD_UPDATE')
	
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	
	self:RegisterEvent('PLAYER_REGEN_DISABLED')
	self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	
	self:RegisterEvent('RAID_ROSTER_UPDATE')
	--self:RegisterEvent('RAID_TARGET_UPDATE')
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperFilter2)
	
	fRaidBid:OnInitialize()
	fRaidMob:OnInitialize()
	addon:CreateGUI()
	
	self:Debug("<<OnInitialize>> end")
end

--Called by AceAddon when addon enabled
function addon:OnEnable()
	self:Debug("<<OnEnable>> start")
	
	self:Debug("<<OnEnable>> end")
end

--Called by AceAddon when addon disabled
function addon:OnDisable()
	self:Debug("<<OnDisable>> start")
end

--==================================================================================================
--Events
--CHAT_MSG_WHISPER handler
function addon:CHAT_MSG_WHISPER(eventName, msg, author, lang, status, ...)
	msg = strlower(strtrim(msg))
	author = strlower(author)
	self:Debug("<<CHAT_MSG_WHISPER>>" .. msg)
	
	local words = self:ParseWords(msg)
	if #words < 1 then
		return
	end
	
	local cmd = words[1];
	self:Debug("cmd=" .. cmd)
	
	if cmd == self.db.global.prefix.bid then
		--BID whisper
		--"bid" number amount
		local playername = author
		local number = nil
		local cmd = nil
		
		if words[2] then
			self:Debug("words[2]=" .. words[2])
			number = tonumber(words[2])
		end
		if words[3] then
			cmd = words[3]
		end
		
		fRaidBid.AddBid(playername, number, cmd)
	elseif cmd == self.db.global.prefix.dkp then
		--DKP whisper
		--"dkp" player = author, whispertarget = author
		--"dkp name" player = name, whispertarget = author
		local player = author
		local whispertarget = author
		
		if words[2] then
			self:Debug("words[2]=" .. words[2])
			player = words[2]
		end
		
		fRaidPlayer:WhisperDKP(player, whispertarget)
	end
end

function addon:LOOT_OPENED(...)
	fRaidBid.LOOT_OPENED(...)
end

function addon:LOOT_CLOSED(...)
	fRaidBid.LOOT_CLOSED(...)
end

function addon:PLAYER_REGEN_DISABLED(...)
	fRaid.Boss.PLAYER_REGEN_DISABLED()
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(...)
	fRaid.Boss.COMBAT_LOG_EVENT_UNFILTERED(...)
end

function addon:LOOT_SLOT_CLEARED(...)
	fRaidBid.LOOT_SLOT_CLEARED(...)
end

function addon:PLAYER_ENTERING_WORLD(...)
	fRaid.Instance.PLAYER_ENTERING_WORLD()
end

function addon:PLAYER_GUILD_UPDATE(...)
	print('<<PLAYER_GUILD_UPDATE>>')
	print(...)
end

function addon:RAID_ROSTER_UPDATE(...)
	print(...)
	fRaid.Raid.RAID_ROSTER_UPDATE()
end

--======================================================================================
--Functions
function addon.GetBidPrefix()
	return db.prefix.bid
end

--==================================================================================================
--GUI Creation
function addon:CreateGUI()
	local padding = 8
	local x = 8
	local y = 8
	local bg, fs, button
	
	local function savecoordshandler(window)
		db.gui.x = window:GetLeft()
		db.gui.y = window:GetTop()
	end
	
	--Main Window
	addon.GUI = fLibGUI.CreateEmptyFrame(2, NAME .. '_MW')
	local mw = addon.GUI
	--mw:RegisterAllEvents()
	--mw:SetScript('OnEvent', function(this, event, ...)
	--	if event ~= 'CHAT_MSG_ADDON' then
	--		print(event .. '>>' .. strjoin(',', unpack({...})))
	--	end
	--end)
	
	mw:SetWidth(300)
	mw:SetHeight(150)
	mw:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', db.gui.x, db.gui.y)
		
	--Title
	fs = fLibGUI.CreateLabel(mw)
	fs:SetText(NAME)
	fs:SetPoint('TOP', 0, -y)
	y = y + fs:GetHeight() + padding
	
	--Close Button
	button = fLibGUI.CreateActionButton(mw)
	button:SetText('Close')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()
		mw:Toggle()
	end)
	button:SetPoint('BOTTOMRIGHT', mw, 'BOTTOMRIGHT', -padding-8, padding+8)
	
	--Initialize tables for storage
	mw.AddLoot = {}
	mw.AddInvLoot = {}
	
	--Some functions for mainwindow
	function mw:SaveLocation()
		db.gui.x = self:GetLeft()
		db.gui.y = self:GetTop()
	end
	--Scripts for mainwindow
	mw:SetScript('OnHide', function()
		this:SaveLocation()
	end)
	
	--Buttons
	button = fLibGUI.CreateActionButton(mw)
	button:SetText('Open Bid Window')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() fRaidBid:ToggleGUI()  end)
	button:SetPoint('TOPLEFT', x, -y)

	x = x + 120
	button = fLibGUI.CreateActionButton(mw)
	button:SetText('Open DKP Window')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()
		fRaid.View()
	end)
	button:SetPoint('TOPLEFT', x, -y)

	x = padding
	y = y + button:GetHeight() + padding
	
	button = fLibGUI.CreateActionButton(mw)
	button:SetText('Configure Loot')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() fRaid:View()  end)
	button:SetPoint('TOPLEFT', x, -y)
	
	y = y + button:GetHeight() + padding
	
	fs = fLibGUI.CreateLabel(mw)
	fs:SetText('Award dkp to raid')
	fs:SetPoint('TOPLEFT', x, -y)
	
	x = x + fs:GetWidth() + padding
	
	local eb = fLibGUI.CreateEditBox(mw, '#')
	eb:SetPoint('TOPLEFT', x, -y)
	eb:SetWidth(60)
	eb:SetNumeric(true)
	eb:SetNumber(0)
	eb:SetScript('OnEnterPressed', function() 
		if eb:GetNumber() > 0 then
			fRaidPlayer:AddDKPToRaid(eb:GetNumber(), true)
		end
		this:ClearFocus()
		eb:SetNumber(0)
	end)
	
	--Separator
	local tex = fLibGUI.CreateSeparator(mw, -y)
	y = y + tex:GetHeight() + padding
end

--GUI Creation
function fRaid.View()
	if not addon.GUI2 then
		local padding = 8
		local x = 8
		local y = 8
		
		--create windows
		addon.GUI2 = fLibGUI.CreateEmptyFrame(2, NAME .. '_main')
		local mw = addon.GUI2
		mw:SetWidth(525)
		mw:SetHeight(350)
		mw:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', db.gui.x, db.gui.y)
		
		mw.subframes = {}
		for i = 1, 8 do
			tinsert(mw.subframes, fLibGUI.CreateClearFrame(mw))
			
			mw.subframes[i]:SetWidth(425)
			mw.subframes[i]:SetHeight(300)
			
			mw.subframes[i]:RegisterForDrag('LeftButton')
			mw.subframes[i]:SetScript('OnDragStart', function(this, button)
				mw:StartMoving()
			end)
			mw.subframes[i]:SetScript('OnDragStop', function(this, button)
				mw:StopMovingOrSizing()
			end)
		end
		
		local bix = 1
		mw.MenuFrame = mw.subframes[bix]
		mw.MenuFrame:SetWidth(100)
		mw.MenuFrame:SetHeight(300)
		mw.MenuFrame:SetPoint('TOPLEFT', mw, 'TOPLEFT', 0, -24)
		bix = bix + 1
		
		mw.InstanceFrame = mw.subframes[bix]
		mw.InstanceFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1

		mw.BossFrame = mw.subframes[bix]
		mw.BossFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1
		
		mw.ItemFrame = mw.subframes[bix]
		mw.ItemFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1
		
		mw.PlayerFrame = mw.subframes[bix]
		mw.PlayerFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1
		
		mw.RaidFrame = mw.subframes[bix]
		mw.RaidFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1
		
		mw.LootFrame = mw.subframes[bix]
		mw.LootFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1
		
		mw.AuctionFrame = mw.subframes[bix]
		mw.AuctionFrame:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPRIGHT', 0,0)
		bix = bix + 1

		---------------------------------------------------------------------
		--Main Window--------------------------------------------------------
		---------------------------------------------------------------------
		--Scripts
		mw:SetScript('OnShow', function()
			--check if we need refreshing
			if this.needRefresh then
				this:Refresh()
			end
			tinsert(UISpecialFrames,this:GetName())
		end)
		mw:SetScript('OnHide', function()
			this:SaveLocation()
		end)
		
		--Functions
		function mw:SaveLocation()
			db.gui.x = self:GetLeft()
			db.gui.y = self:GetTop()
		end
		
		function mw:HideSubFrames()
			for i = 2, #mw.subframes do
				mw.subframes[i]:Hide()
			end
		end
				
		--reloads the data in mw_items and mw_bids
		function mw:Refresh()
			--self:LoadItemRows(mw_items.startingindex)
			--self:LoadBidRows(mw_bids.startingindex)
			self.needRefresh = false
		end
		
		--Titles
		mw.titles = {}
		for i = 1, 1 do
			tinsert(mw.titles, fLibGUI.CreateLabel(mw))
		end
		mw.titles[1]:SetText(NAME)
		mw.titles[1]:SetFontObject(GameFontHighlightLarge)
		mw.titles[1]:SetPoint('TOP', 0, -padding)
		
		--Buttons
		mw.buttons = {}
		for i = 1, 1 do	
			tinsert(mw.buttons, fLibGUI.CreateActionButton(mw))
			mw.buttons[i]:SetFrameLevel(3)
		end
		--Close button
		local button = mw.buttons[1]
		button:SetText('Close')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function() mw:Toggle() end)
		button:SetPoint('BOTTOMRIGHT', mw, 'BOTTOMRIGHT', -padding-8, padding+8)

		
		---------------------------------------------------------------------
		--Menu Frame---------------------------------------------------------
		---------------------------------------------------------------------
		--Functions
		function mw.MenuFrame:UnselectButtons()
			for i = 1, #mw.MenuFrame.buttons do
				mw.MenuFrame.buttons[i].highlightspecial:Hide()
			end
		end

		--Titles
		mw.MenuFrame.titles = {}
		for i = 1, 3 do
			tinsert(mw.MenuFrame.titles, fLibGUI.CreateLabel(mw.MenuFrame))
			mw.MenuFrame.titles[i]:SetFontObject(GameFontHighlightLarge)
		end
		mw.MenuFrame.titles[1]:SetText('Setup')
		mw.MenuFrame.titles[1]:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPLEFT', padding, -padding)
		mw.MenuFrame.titles[2]:SetText('Data')
		mw.MenuFrame.titles[2]:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPLEFT', padding, -100)
		mw.MenuFrame.titles[3]:SetText('Windows')
		mw.MenuFrame.titles[3]:SetPoint('TOPLEFT', mw.MenuFrame, 'TOPLEFT', padding, -225)

		--Buttons
		mw.MenuFrame.buttons = {}
		for i = 1, 9 do
			tinsert(mw.MenuFrame.buttons, fLibGUI.CreateActionButton(mw.MenuFrame))
			mw.MenuFrame.buttons[i]:SetFrameLevel(3)
			mw.MenuFrame.buttons[i].highlightspecial = mw.MenuFrame.buttons[i]:CreateTexture(nil, "BACKGROUND")
			mw.MenuFrame.buttons[i].highlightspecial:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			mw.MenuFrame.buttons[i].highlightspecial:SetBlendMode("ADD")
			mw.MenuFrame.buttons[i].highlightspecial:SetAllPoints(mw.MenuFrame.buttons[i])
			mw.MenuFrame.buttons[i].highlightspecial:Hide()
		end

		local tix = 1 --index of current title
		local bix = 1 --index of current button
		
		--Setup
		local title = mw.MenuFrame.titles[tix]
		local button
		
		--Instances Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Instances')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaid.Instance.View()
		end)
		button:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', padding, -padding)
		bix = bix + 1
		
		--Bosses Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Bosses')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaid.Boss.View()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Items Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Items')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaid.Item.View()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Data
		tix = tix + 1
		title = mw.MenuFrame.titles[tix]
		
		--Players Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Players')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaidPlayer.View()
		end)
		button:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', padding, -padding)
		bix = bix + 1
		
		--Raids Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Raids')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			--fRaid.Raid.Vew()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Loots Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Loots')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Auctions Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Auctions')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function()
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1

		--Windows
		tix = tix + 1
		title = mw.MenuFrame.titles[tix]
		
		--List... Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >List...')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function() print('List... button clicked')  end)
		button:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', padding, -padding)
		bix = bix + 1
		
		-->Auction... Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Auction...')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function() fRaidBid:ToggleGUI()  end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		
		
		
		--Scripts for mw_items
		--drag and drop
		--[[
		mw_items:SetScript('OnReceiveDrag', function()
			local infoType, id, link = GetCursorInfo()
			if infoType == 'item' then
				BIDLIST.AddItem(link)
				ClearCursor()
			end
		end)
		--]]
		
		
	end
	addon.GUI2:Toggle()
end
function fRaid.Refresh()
	if addon.GUI2 then
		if addon.GUI2:IsVisible() then
			addon.GUI2:Refresh()
			needRefresh = false
			return
		end
	end
	needRefresh = true
end