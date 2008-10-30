fRaidBid = {}
local addon = fRaidBid
local NAME = 'fRaidBid'
local db = {}

function addon:OnInitialize()
	db = fRaid.db.global.fRaidBid
	addon.CreateGUI()
end


--==================================================================================================
--GUI Creation
function addon.CreateGUI()
	local padding = 8
	local x = 8
	local y = 8
	local bg, fs, button, eb, cb
	
	local function savecoordshandler(window)
		db.gui.x = window:GetLeft()
		db.gui.y = window:GetTop()
	end
	
	--Main Window
	addon.GUI,y = fLib.GUI.CreateMainWindow(NAME, db.gui.x, db.gui.y, 250, 300, padding, savecoordshandler)
	local mw = addon.GUI
	
	--Initialize tables for storage
	mw.AddLoot = {}
	mw.AddInvLoot = {}
	
	--Some functions for mainwindow
	
	--Scripts for mainwindow
	
	--Add Loot button
	button = fLib.GUI.CreateActionButton('Add Loot', mw, x,-y, nil)
	x = x + 80
	
	--Add Inv Loot button
	button = fLib.GUI.CreateActionButton('Add Inventory', mw, x,-y, nil)
	x = padding
	y = y + button:GetHeight() + padding
	
	--Separator
	local tex = fLib.GUI.CreateSeparator(mw, -y)
	y = y + tex:GetHeight() + padding
end