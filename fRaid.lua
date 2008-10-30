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
			}
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
		},
		gui = {
			x = 100, --relative to left
			y = 300, --relative to bottom
		},
		fRaidBid = {
			gui = {
				x = 200,
				y = 300,
			},
		},
		bidlist = {},
		items = {},
		mobs = {},
	},
}


--incoming messages
local function WhisperFilter(msg)
	msg = strlower(strtrim(msg))
	if strfind(msg, addon.db.global.prefix.bid) == 1 then
		--add a bid
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
	self:RegisterEvent('LOOT_OPENED', fRaidLoot.Scan)
	self:RegisterEvent('CHAT_MSG_LOOT', fRaidLoot.Test)
	--self:RegisterEvent('LOOT_SLOT_CLEARED', fRaidLoot.Test)
	--self:RegisterEvent('CANCEL_LOOT_ROLL', fRaidLoot.Test)
	--self:RegisterEvent('CHAT_MSG_MONEY', fRaidLoot.Test)
	--self:RegisterEvent('CONFIRM_LOOT_ROLL', fRaidLoot.Test)
	--self:RegisterEvent('EQUIP_BIND_CONFIRM', fRaidLoot.Test)
	--self:RegisterEvent('LOOT_BIND_CONFIRM', fRaidLoot.Test)
	--self:RegisterEvent('LOOT_CLOSED', fRaidLoot.Test)
	--self:RegisterEvent('LOOT_OPENED', fRaidLoot.Test)
	self:RegisterEvent('OPEN_MASTER_LOOT_LIST', fRaidLoot.Test)
	self:RegisterEvent('PARTY_LOOT_METHOD_CHANGED', fRaidLoot.Test)
	self:RegisterEvent('START_LOOT_ROLL', fRaidLoot.Test)
	self:RegisterEvent('UPDATE_MASTER_LOOT_LIST', fRaidLoot.Test)
	
	
	
	self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', fRaidMob.Scan)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", WhisperFilter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", WhisperFilter2)
	
	fRaidBid:OnInitialize()
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
		local number = 0
		local amount = 0
		
		if words[2] then
			self:Debug("words[2]=" .. words[2])
			number = tonumber(words[2])
		end
		if words[3] then
			amount = tonumber(words[3])
		end
		
		--addbid(author, number, amount)
	end
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
	addon.GUI,y = fLib.GUI.CreateMainWindow(NAME, db.gui.x, db.gui.y, 300, 150, padding, savecoordshandler)
	local mw = addon.GUI
	
	--Initialize tables for storage
	mw.AddLoot = {}
	mw.AddInvLoot = {}
	
	--Some functions for mainwindow
	
	--Scripts for mainwindow
	
	button = fLib.GUI.CreateActionButton('Open Bid Window', mw, x,-y, fRaidBid.GUI.Toggle)
	x = x + 120
	button = fLib.GUI.CreateActionButton('Open DKP Window', mw, x,-y, fDKP.GUI.Toggle)
	x = padding
	y = y + button:GetHeight() + padding
	
	--Separator
	local tex = fLib.GUI.CreateSeparator(mw, -y)
	y = y + tex:GetHeight() + padding
end