-- vim: set softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
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
--local TIMER_INTERVAL = 300 --secs == 5 minutes

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
			attendance = 'att',
			dkpcheckin = 'dkpcheck',
			adjust = 'adjust',
			vote = 'vote',
			abstain = 'abstain',
			votestart = 'votestart',
			voteend = 'voteend',
			votecount = 'votecount',
		},
		gui = {
			x = 100, --relative to left
			y = 300, --relative to bottom
		},
		vote = {
			start = nil,
			title = nil,
			votelist = {},
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
		cap = 0, --0 should mean no cap
		ItemList = {},
		AuctionList = {},
		Item = {
			ItemList = {},
			Count = 0,
			LastModified = 0,
		},
		Player = {
		  PlayerList = {},
		  ChangeList = {},
		  Count = 0,
		  LastModified = 0,
		  AttendanceFlagSnapshots = {}, --list of afsnapshots: {snapshotdate, snapshot}; snapshot maps playername to 
		  AttendanceTotal = 0,
		  MaxAttendanceTotal = 16,
		},
		Raid = {
		  RaidList = {},
		  LastModified = 0,
		},
		Instance = {
		  ZoneList = {},
		  Count = 0,
		  LastModified = 0,
		}
	},
}


--incoming messages
local function WhisperFilter(self, event, msg)
	addon:Debug("<<Whisperfilter>>")
	msg = strlower(strtrim(msg))
	if strfind(msg, addon.db.global.prefix.bid) == 1 then
		--add a bid
		return true
	elseif strfind(msg, addon.db.global.prefix.dkp) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.attendance) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.adjust) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.vote) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.abstain) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.votestart) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.votecount) == 1 then
		return true
	elseif strfind(msg, addon.db.global.prefix.voteend) == 1 then
		return true
	end
	
	--you could change the msg also by doing
	--return false, gsub(msg, "lol", "")
end

--outgoing messages
local function WhisperFilter2(self, event, msg)
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
	
	fRaidBid:OnInitialize()
	--fRaidMob:OnInitialize()
	fRaid.Player.OnInitialize()
	fRaid.Raid.OnInitialize()
	
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
	
	self:RegisterEvent('PLAYER_ENTERING_WORLD')
	
	self:RegisterEvent('PLAYER_REGEN_DISABLED')
	self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	
	self:RegisterEvent('GROUP_ROSTER_UPDATE')
	--self:RegisterEvent('RAID_TARGET_UPDATE')
	
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperFilter2)
	
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
--handles incoming whispers
function addon:CHAT_MSG_WHISPER(eventName, msg, author, lang, status, ...)
	msg = strlower(strtrim(msg))
	local cardinalAuthor = addon:CardinalName(author)
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
		local playername = cardinalAuthor
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

	elseif cmd == self.db.global.prefix.voteend then

		if self.db.global.vote.start == nil then
			fRaid.Whisper2("no vote is currently pending", cardinalAuthor)
			return
		end

		-- Check restrictions.
		if fRaid.Player.GetRank(cardinalAuthor) ~= "Officer" and fRaid.Player.GetRank(cardinalAuthor) ~= "Officer Alt" and fRaid.Player.GetRank(cardinalAuthor) ~= "Guild Master" then
			fRaid.Whisper2("unauthorized; command restricted to Officer, Officer Alt, Guild Master", cardinalAuthor)
			return
		end

		-- LUA sucks and something as simple as a sorted dictionary by 
		-- value is too hard for it.  So, we'll transpose the votelist 
		-- array, then sort the keys using a custom sort function, then 
		-- walk the result.
		local playerVotes = {}
		for voter, vote in pairs(self.db.global.vote.votelist) do
			if not playerVotes[vote] then
				playerVotes[vote] = {}
			end
			table.insert(playerVotes[vote], voter)
		end
		local rankedPlayerVoteKeys = {}
		for player, _ in pairs(playerVotes) do
			-- Filter abstain votes from the ranking.
			if player ~= "*abstain*" then
				table.insert(rankedPlayerVoteKeys, player)
			end
		end
		table.sort(rankedPlayerVoteKeys, function(left, right)
			return #playerVotes[left] > #playerVotes[right]
		end)

		-- If there was some result (winner or tie), announce it.
		if #rankedPlayerVoteKeys > 0 then
			local winningVotes = #playerVotes[rankedPlayerVoteKeys[1]]

			-- Check for ties.
			local tied = {}
			for i = 2, #rankedPlayerVoteKeys do
				local player = rankedPlayerVoteKeys[i]
				if #playerVotes[player] == winningVotes then
					table.insert(tied, player)
				end
			end

			-- Handle a tie.
			if #tied > 0 then
				fList:AnnounceInChat("[fRaid] Voting ended; there was a tie at " .. winningVotes .. " vote(s) each; tied players: " .. rankedPlayerVoteKeys[1] .. ", " .. table.concat(tied, ", "), "RAID")
				self.db.global.vote.result = tied
				table.insert(self.db.global.vote.result, rankedPlayerVoteKeys[1])

			-- Otherwise, handle a normal win.
			else
				fList:AnnounceInChat("[fRaid] Voting ended; with " .. winningVotes .. " vote(s), " .. rankedPlayerVoteKeys[1] .. " wins!", "RAID")
				self.db.global.vote.result = rankedPlayerVoteKeys[1]
			end
		end

		-- Display the vote totals to officers, abstain votes as well.
		local voteTexts = {}
		for _, player in pairs(rankedPlayerVoteKeys) do
			table.insert(voteTexts, #playerVotes[player] .. ":" .. player .. "{" .. table.concat(playerVotes[player], ",") .. "}")
		end
		if playerVotes["*abstain*"] then
			table.insert(voteTexts, #playerVotes["*abstain*"] .. ":*abstain*{" .. table.concat(playerVotes["*abstain*"], ",") .. "}")
		end
		fList:AnnounceInChat("[fRaid] Vote results (count:name:voters): " .. table.concat(voteTexts, ", "), "OFFICER")

		-- Archive this vote, announce it closed.
		if not self.db.global.oldvote then
			self.db.global.oldvote = {}
		end
		table.insert(self.db.global.oldvote, self.db.global.vote)
		self.db.global.vote = {
			start = nil,
			title = "(no title)",
			votelist = {},
		}

	elseif cmd == self.db.global.prefix.votecount then

		if self.db.global.vote.start == nil then
			fRaid.Whisper2("no vote is currently pending", cardinalAuthor)
			return
		end

		local votes = 0
		for _, _ in pairs(self.db.global.vote.votelist) do
			votes = votes + 1
		end

		fRaid.Whisper2("number of players who have voted: " .. votes, cardinalAuthor)

	elseif cmd == self.db.global.prefix.votestart then

		-- Check restrictions.
		if fRaid.Player.GetRank(cardinalAuthor) ~= "Officer" and fRaid.Player.GetRank(cardinalAuthor) ~= "Officer Alt" and fRaid.Player.GetRank(cardinalAuthor) ~= "Guild Master" then
			fRaid.Whisper2("unauthorized; command restricted to Officer, Officer Alt, Guild Master", cardinalAuthor)
			return
		end

		-- If we have the reason for the vote, set it up and announce.
		-- XXX Set the title from votestart's argument.
		self.db.global.vote = {
			start = fLib.GetTimestamp(),
			title = "(no title)",
			votelist = {},
		}

		fList:AnnounceInChat("[fRaid] voting started; send tells to me to vote like 'vote playername' or 'abstain'; if voting for someone with stupid alt codes, target them and send a tell like 'vote % t' (with no space between % and t)", "RAID")

	elseif cmd == self.db.global.prefix.vote then

		if self.db.global.vote.start == nil then
			fRaid.Whisper2("no vote is currently pending", cardinalAuthor)
			return
		end

		-- They must be in the raid to be allowed to vote.
		if not fRaid:NameInRaid(cardinalAuthor) then
			fRaid.Whisper2("you must be in the raid to be allowed to vote", cardinalAuthor)
			self:Print(cardinalAuthor .. " attempted to vote for " .. words[2] .. " while not in the raid")
			return
		end


		-- Register their vote.
		if words[2] then
			local cardinalName = fRaid:CardinalName(words[2])

			-- They must be voting for someone in the raid (especially 
			-- to catch misspellings).
			if not fRaid:NameInRaid(cardinalName) then
				fRaid.Whisper2("no player by that name is in the raid", cardinalAuthor)
				return
			end

			-- They must not be voting for themself.
			if cardinalAuthor == cardinalName then
				fRaid.Whisper2("you can't vote for yourself", cardinalAuthor)
				return
			end

			self.db.global.vote.votelist[cardinalAuthor] = cardinalName
		end

		-- Acknowledge their vote.
		if self.db.global.vote.votelist[cardinalAuthor] then
			fRaid.Whisper2("you have voted for " .. self.db.global.vote.votelist[cardinalAuthor], cardinalAuthor)
		else
			fRaid.Whisper2("you have not voted", cardinalAuthor)
		end

	elseif cmd == self.db.global.prefix.abstain then

		if self.db.global.vote.start == nil then
			fRaid.Whisper2("no vote is currently pending", cardinalAuthor)
			return
		end

		-- They must be in the raid to be allowed to vote.
		if not fRaid:NameInRaid(cardinalAuthor) then
			fRaid.Whisper2("you must be in the raid to be allowed to abstain on a vote", cardinalAuthor)
			return
		end

		-- Register their vote.
		self.db.global.vote.votelist[cardinalAuthor] = "*abstain*"

		-- Acknowledge their vote.
		if self.db.global.vote.votelist[cardinalAuthor] then
			fRaid.Whisper2("you have voted for " .. self.db.global.vote.votelist[cardinalAuthor], cardinalAuthor)
		else
			fRaid.Whisper2("you have not voted", cardinalAuthor)
		end

	elseif cmd == self.db.global.prefix.dkp then
		--DKP whisper
		--"dkp" player = author, whispertarget = author
		--"dkp name" player = name, whispertarget = author
		local player = cardinalAuthor
		local whispertarget = cardinalAuthor
		if words[2] then
			player = fRaid:CardinalName(words[2])
		end
		
		--fRaid.Player.WhisperDkp(player, whispertarget)
		fRaid.Player.WhisperCommand("dkp", player, whispertarget)
	elseif cmd == self.db.global.prefix.attendance then
		--Attendance whisper
		--"att" player = author, whispertarget = author
		--"att name" player = name, whispertarget = author
		local player = cardinalAuthor
		local whispertarget = cardinalAuthor
		if words[2] then
			player = fRaid:CardinalName(words[2])
		end
		
		fRaid.Player.WhisperCommand("att", player, whispertarget)
	elseif cmd == self.db.global.prefix.dkpcheckin then
		local name = cardinalAuthor
		local idx = 0
		if words[2] then
			idx = tonumber(words[2])
		end
		
		fRaid.Raid.DkpCheckin(idx, name)

	elseif cmd == self.db.global.prefix.adjust then
		--"adjust" player amount

		-- Restrict to officers.
		if fRaid.Player.GetRank(cardinalAuthor) ~= "Officer" and fRaid.Player.GetRank(cardinalAuthor) ~= "Officer Alt" and fRaid.Player.GetRank(cardinalAuthor) ~= "Guild Master" then
			fRaid.Whisper2("unauthorized; command restricted to Officer, Officer Alt, Guild Master", cardinalAuthor)
			return
		end

		-- Get player name and amount.
		local player = nil
		local amount = nil
		if words[2] then
			player = fRaid:CardinalName(words[2])
		end
		if words[3] then
			amount = tonumber(words[3])
		end
		if player == nil or amount == nil then
			fRaid.Whisper2("'adjust' requires a player name and an amount of dkp", cardinalAuthor)
			return
		end

		-- Get old DKP of the player.
		local obj = fRaid.db.global.Player.PlayerList[player]
		if obj == nil then
			fRaid.Whisper2("no such player '" .. player .. "'", cardinalAuthor)
			return
		end
		oldDkp = obj.dkp

		-- Adjust and inform about the adjustment.
		message = cardinalAuthor .. " manually adjusted " .. player .. " by " .. amount .. " dkp; dkp previously was " .. oldDkp
		fRaid.Player.AddDkp(player, amount, message)
		fList:AnnounceInChannels(message, {strsplit("\n", fList.db.global.printlist.channels)})
		fList:AnnounceInChat(message, fList:CreateChatList(fList.db.global.printlist.officer, fList.db.global.printlist.guild, fList.db.global.printlist.raid))
	end
end

function addon:LOOT_OPENED(...)
	fRaidBid.LOOT_OPENED(...)
end

function addon:LOOT_CLOSED(...)
	fRaidBid.LOOT_CLOSED(...)
end

function addon:PLAYER_REGEN_DISABLED(...)
	--fRaid.Boss.PLAYER_REGEN_DISABLED()
end

function addon:COMBAT_LOG_EVENT_UNFILTERED(...)
	--fRaid.Boss.COMBAT_LOG_EVENT_UNFILTERED(...)
end

function addon:LOOT_SLOT_CLEARED(...)
	fRaidBid.LOOT_SLOT_CLEARED(...)
end

function addon:PLAYER_ENTERING_WORLD(...)
	fRaid.Instance.PLAYER_ENTERING_WORLD()
end

function addon:GROUP_ROSTER_UPDATE(...)
	--print(...)
	fRaid.Raid.GROUP_ROSTER_UPDATE()
end

--======================================================================================
--Functions
function addon.GetBidPrefix()
	return db.prefix.bid
end


--Send a whisper
function fRaid.Whisper2(msg, name)
	fLib.Com.Whisper("[" .. NAME .. "] " .. msg, name)
end


--==================================================================================================

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
		mw:SetScript('OnShow', function(this)
			--check if we need refreshing
			if this.needRefresh then
				this:Refresh()
			end
			tinsert(UISpecialFrames,this:GetName())
		end)
		mw:SetScript('OnHide', function(this)
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
		button:SetScript('OnClick', function(this) mw:Toggle() end)
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
		for i = 1, 10 do
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
		button:SetScript('OnClick', function(this)
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
		button:SetScript('OnClick', function(this)
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			--fRaid.Boss.View()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Items Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Items')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function(this)
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
		button:SetScript('OnClick', function(this)
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaid.Player.View()
		end)
		button:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', padding, -padding)
		bix = bix + 1
		
		--Raids Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Raids')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function(this)
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
			fRaid.Raid.View()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		--Loots Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Loots')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function(this)
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
		button:SetScript('OnClick', function(this)
			mw:HideSubFrames()
			mw.MenuFrame:UnselectButtons()
			this.highlightspecial:Show()
		end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1

		--Purge Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Purge')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function(this)
			fRaid:ConfirmDialog2('Delete old history? (back up fRaid.lua first!)', fRaid.Player.LIST.Purge)
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
		button:SetScript('OnClick', function(this) fList.GUI:Toggle() end)
		button:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', padding, -padding)
		bix = bix + 1
		
		-->Auction... Button
		button = mw.MenuFrame.buttons[bix]
		button:SetText('  >Auction...')
		button:SetWidth(button:GetTextWidth())
		button:SetHeight(button:GetTextHeight())
		button:SetScript('OnClick', function(this) fRaidBid:ToggleGUI()  end)
		button:SetPoint('TOPLEFT', mw.MenuFrame.buttons[bix-1], 'BOTTOMLEFT', 0, -padding)
		bix = bix + 1
		
		
		
		
		--Scripts for mw_items
		--drag and drop
		--[[
		mw_items:SetScript('OnReceiveDrag', function(this)
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
