fRaidHistory = {}
local addon = fRaidHistory
local NAME = 'fRaidHistory'
local db = {}

function addon:OnInitialize()
	db = fRaid.db.global.fRaidHistory
end