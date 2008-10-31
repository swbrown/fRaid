fRaidBid = {}
local addon = fRaidBid
local NAME = 'fRaidBid'
local db = {}

function addon:OnInitialize()
	db = fRaid.db.global.fRaidBid
	if db.bidnumber == nil then
		db.bidnumber = 1
	end
	if db.bidlist == nil then
		db.bidlist = {}
	end
	if db.winnerlist == nil then
		db.winnerlist = {}
	end
	addon.CreateGUI()
end

--==================================================================================================
--BIDLIST
--db.bidnumber
--db.bidlist (idx => {number, itemlink, count, bids})
--bids (idx => {playername, bidamount})
local BIDLIST = {}
addon.BIDLIST = BIDLIST
function BIDLIST.GetCount()
	return #db.bidlist
end

function BIDLIST.GetList()
	return db.bidlist
end

function BIDLIST.Clear()
	fRaid:Debug('clearing BIDLIST')
	db.bidlist = {}
	db.bidnumber = 1
	addon.RefreshGUI()
end

function BIDLIST.GetItemLinkByNumber(number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			return info.link
		end
	end
	
	return ''
end

--accepts a stringn or a list of strings
function BIDLIST.AddItem(data)
	local itemlink, itemid
	local matched
	if type(data) == 'string' then
		itemlink = data
		data = {itemlink}
	end
	
	for idx,itemlink in ipairs(data) do
		matched = false
		--extract id
		itemid = fRaid:ExtractItemId(itemlink)
		
		--check if itemlink already in the list
		for idx,info in ipairs(db.bidlist) do
			if info.id == itemid then
				--increment count
				matched = true
				info.count = info.count + 1
				break
			end
		end
		
		if not matched then
			--add new itemlink
			tinsert(db.bidlist, {
				number = db.bidnumber,
				id = itemid,
				link = itemlink,
				count = 1,
				bids = {}
			})
			db.bidnumber = db.bidnumber + 1
		end
	end
	--refresh gui
	addon.RefreshGUI()

end

function BIDLIST.RemoveItem(itemlink)
	for idx,info in ipairs(db.bidlist) do
		if info.link == itemlink then
			if info.count == 0 then
				tremove(db.bidlist, idx)
				--only reset db.bidnumber if db.bidlist is empty
				if #db.bidlist == 0 then
					db.bidnumber = 1
				end
			else
				info.count = info.count - 1
			end
			----refresh gui
			addon.RefreshGUI()
			return
		end
	end
	--invalid itemlink...
end

function BIDLIST.AddBid(playername, number, bidamount)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			--check if they already bid
			for idx2,bid in ipairs(info.bids) do
				if bid.name == playername then
					bid.amount = bidamount
					--refresh gui
					addon.RefreshGUI()
					return
				end
			end
			--add new bid
			tinsert(info.bids, {
				name = playername,
				amount = bidamount,
			})
			--refresh gui
			addon.RefreshGUI()
			return
		end
	end
	--invalid number...
end

function BIDLIST.RemoveBid(number, playername)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			for idx2,bid in ipairs(info.bids) do
				if bid.name == playername then
					tremove(info.bids, idx2)
					--refresh gui
					addon.RefreshGUI()
					return
				end
			end
		end
	end
	--invalid number, playername...
end

--==================================================================================================
--Functions for stuff

--add items in the currently open loot window
function fRaidBid.Scan()
	local link
	local loots = {}
	for i = 1, GetNumLootItems() do
		if LootSlotIsItem(i) then
			link = GetLootSlotLink(i)
			fRaid:Debug('fRaidBid.Scan() found slot ' .. i .. ' ' .. link)
			tinsert(loots, link)
		end
	end
	if #link > 0 then
		BIDLIST.AddItem(loots)
	end
end

function fRaidBid.AddBid(playername, number, amount)
	if not playername then
		fRaid:Whisper('Invalid bid: missing playername')
		return
	end
	if not number then
		fRaid:Whisper('Invalid bid: invalid or missing bid number')
		return
		--TODO: fancy this up by including the available bid numbers
	end
	if not amount then
		fRaid:Whisper('Invalid bid: invalid or missing bid amount')
		return
		--TODO: fancy this up by including their dkp amount
	end

	local link = BIDLIST.GetItemLinkByNumber(number)
	if not link or link == '' then
		fRaid:Whisper('Invalid bid: invalid bid number')
		return
	end
	
	BIDLIST.AddBid(playername, number, amount)
	fRaid:Whisper('Accepted ' .. playername .. '\'s bid on ' .. link .. ' for ' .. amount .. ' DKP.')
end

--==================================================================================================
--Events

--open the bid window if it isn't open
function fRaidBid:LOOT_OPENED()
	if not addon.GUI:IsVisible() then
		addon.GUI.Toggle()
	end
end

--close the bid window if no bids
function fRaidBid:LOOT_CLOSED()
	if BIDLIST.GetCount() == 0 then
		if addon.GUI:IsVisible() then
			addon.GUI.Toggle()
		end
	end
end

--==================================================================================================
--GUI Creation
local padding = 8
local x = 8
local y = 8
local minwidth = 225
local minheight = 150
local startrowsy = 8

function addon.CreateGUI()
	local bg, fs, button, eb, cb
	
	local function savecoordshandler(window)
		db.gui.x = window:GetLeft()
		db.gui.y = window:GetTop()
	end
	
	--Main Window
	addon.GUI,y = fLib.GUI.CreateMainWindow(NAME, db.gui.x, db.gui.y, minwidth, minheight, padding, savecoordshandler)
	local mw = addon.GUI
	
	--Initialize tables for storage
	mw.AddLoot = {}
	mw.AddInvLoot = {}
	
	--Some functions for mainwindow
	
	--Scripts for mainwindow
	
	--Add Loot button
	button = fLib.GUI.CreateActionButton('Add Loot', mw, x,-y, addon.Scan)
	x = x + 80
	
	--Add Inv Loot button
	button = fLib.GUI.CreateActionButton('Add Inventory', mw, x,-y, nil)
	x = padding
	y = y + button:GetHeight() + padding
	
	--Separator
	local tex = fLib.GUI.CreateSeparator(mw, -y)
	y = y + tex:GetHeight() + padding
	
	startrowsy = y
	addon.RefreshGUI()
	
	--Clear Button
	button = fLib.GUI.CreateActionButton('Clear', mw, 0, 0, BIDLIST.Clear)
	button:ClearAllPoints()
	button:SetPoint('BOTTOMLEFT', mw, 'BOTTOMLEFT', padding+8, padding+8)
	
end

local rows = {}
function addon.RefreshGUI()
	fRaid:Debug('refreshing gui')
	addon.GUI:SetWidth(minwidth)
	addon.GUI:SetHeight(minheight)
	
	y = startrowsy
	local rows_idx = 1
	local fs
	for idx,info in ipairs(BIDLIST.GetList()) do
		fRaid:Debug('idx='..idx)
		fs = rows[rows_idx]
		if fs then
			fRaid:Debug('fsexists')
			fs:SetText(info.number .. ' ' .. info.link .. ' ' .. info.count)
			fs:Show()
		else
			fRaid:Debug('making new fs')
			fs = fLib.GUI.CreateLabel(addon.GUI, x, -y, info.number .. ' ' .. info.link .. ' ' .. info.count)
			rows[rows_idx] = fs
		end
		rows_idx = rows_idx + 1
		y = y + fs:GetHeight() + padding
		
		if fs:GetWidth() + padding + padding > addon.GUI:GetWidth() then
			addon.GUI:SetWidth(fs:GetWidth() + padding + padding)
		end
	end
	
	for i = rows_idx, #rows do
		fRaid:Debug('clearing '..i)
		fs = rows[i]
		fs:Hide()
	end
	
	if y > addon.GUI:GetHeight() then
		addon.GUI:SetHeight(y +100)
	end
end