fRaidBid = {}
local addon = fRaidBid
local NAME = 'fRaidBid'
local db = {}
local LISTDISPLAY = {}
addon.LISTDISPLAY = LISTDISPLAY

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
	LISTDISPLAY.OnInitialize()
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

function BIDLIST.GetAvailableNumbers()
	local nums = {}
	for idx,info in ipairs(db.bidlist) do
		tinsert(nums, info.number)
	end
	
	return nums
end

function BIDLIST.GetItemLinkByNumber(number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			return info.link
		end
	end
	
	return ''
end

function BIDLIST.GetItemInfo(number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			return info
		end
	end
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

local function bidcomparer(a, b)
	if a== nil or b == nil then
		return true
	end
	
	if a.amount == b.amount then
		return a.name < b.name
	else
		return a.amount < b.amount
	end
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

function BIDLIST.RemoveBid(playername, number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			for idx2,bid in ipairs(info.bids) do
				fRaid:Debug('macthing '..bid.name..' with '..playername)
				if bid.name == playername then
					fRaid:Debug('removing '..bid.name)
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
	if #loots > 0 then
		BIDLIST.AddItem(loots)
	end
end

function fRaidBid.AddBid(playername, number, cmd)
	if not playername then
		fRaid:Whisper(playername,'Invalid bid: missing playername')
		return
	end
	local nums = BIDLIST.GetAvailableNumbers()
	if not number then
		fRaid:Whisper(playername,'Invalid bid: invalid or missing bid number. Available bid numbers are '..strjoin(',', unpack(nums)))
		return
		--TODO: fancy this up by including the available bid numbers
	end
	
	local iteminfo = BIDLIST.GetItemInfo(number)
	if not iteminfo then
		fRaid:Whisper(playername, 'Invalid bid: invalid bid number. Available bid numbers are '..strjoin(',', unpack(nums)))
		return
	end
	
	local dkpinfo = fDKP.DKPLIST.GetPlayerInfo(playername)
	
	if not cmd or (type(tonumber(cmd)) ~= 'number' and type(cmd) ~= 'string') then
		local msg = 'Invalid bid: invalid or missing bid amount or min or all or cancel\n'
		if dkpinfo then
			msg = msg ..'You have ' .. dkpinfo.dkp.. ' dkp available'
		else
			msg = msg .. 'You have no dkp available'
		end
		fRaid:Whisper(playername, msg)
		return
	end
	
	local amount = 0
	if type(tonumber(cmd)) == 'number' then
		fRaid:Debug('is a number')
		amount = cmd
	else
		if cmd == 'all' then
			if dkpinfo then
				if dkpinfo.dkp > 0 then
					amount = dkpinfo.dkp
				elseif dkpinfo.dkp == 0 then
					fRaid:Whisper(playername, 'You have no dkp available, you can still bid min by whispering bid number min')
					return
				else
					fRaid:Whisper(playername, 'You have negative dkp available, you can still bid min by whispering bid number min')
					return
				end
			else
				fRaid:Whisper(playername, 'You have no dkp available, you can still bid min by whispering bid number min')
				return
			end
		elseif cmd == 'min' then
			local lootinfo = fRaidLoot.GetInfo(iteminfo.id)
			if lootinfo then
				amount = lootinfo.mindkp
			else
				amount = 0
			end
		elseif cmd == 'cancel' then
			BIDLIST.RemoveBid(playername, number)
			fRaid:Whisper(playername, 'Your bid on ' .. iteminfo.link..' has been removed')
			return
		end
	end
	
	BIDLIST.AddBid(playername, number, amount)
	fRaid:Whisper(playername, 'Accepted ' .. playername .. '\'s bid on ' .. iteminfo.link .. ' for ' .. amount .. ' DKP.')
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
local minheight = 100
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
	
	--Clear Button
	button = fLib.GUI.CreateActionButton('Clear', mw, 0, 0, BIDLIST.Clear)
	button:ClearAllPoints()
	button:SetPoint('BOTTOMLEFT', mw, 'BOTTOMLEFT', padding+8, padding+8)
	
	LISTDISPLAY.startx = x
	LISTDISPLAY.starty = y
	addon.RefreshGUI()
end

function addon.RefreshGUI()
	fRaid:Debug('refreshing gui')
	addon.GUI:SetWidth(minwidth)
	addon.GUI:SetHeight(minheight)
	
	local row_idx = 1
	local lstrow = 0
	local fs
	for idx,info in ipairs(BIDLIST.GetList()) do
		fs = LISTDISPLAY.GetRow(row_idx)
		fs:SetText(info.number .. ' ' .. info.link .. 'x' .. info.count)
		
		local width = fs:GetWidth() + padding + padding --its weird, fs:GetWidth() gives a larger value, after the first time...
		fRaid:Debug('idx='..idx)--..'width='..width..',guidwidth='..addon.GUI:GetWidth())
		if width > addon.GUI:GetWidth() then
			addon.GUI:SetWidth(width)
			--fRaid:Debug('new guiwidth='..addon.GUI:GetWidth())
		end
		
		row_idx = row_idx + 1
		
		--add bids
		print('this item has '..#info.bids..' bids')
		sort(info.bids, bidcomparer)
		for _,bid in ipairs(info.bids) do
			fs = LISTDISPLAY.GetRow(row_idx)
			local dkpinfo = fDKP.DKPLIST.GetPlayerInfo(bid.name)
			if dkpinfo then
				fs:SetText('    '..bid.name .. ' bid ' .. bid.amount .. '(has ' .. dkpinfo.dkp .. ' dkp)')
			else
				fs:SetText('    '..bid.name .. ' bid ' .. bid.amount .. ' (has no dkp)')
			end
			row_idx = row_idx + 1
		end
		
		lstrow = row_idx
	end
	
	LISTDISPLAY.HideRows(lstrow+1)
	
	fRaid:Debug('listdisplay height='..(LISTDISPLAY.GetHeight() + LISTDISPLAY.starty +100)..',guiheight='..addon.GUI:GetHeight())
	if LISTDISPLAY.GetHeight() + LISTDISPLAY.starty +100 > addon.GUI:GetHeight() then
		addon.GUI:SetHeight(LISTDISPLAY.GetHeight() + minheight)
		fRaid:Debug('new guiheight='..addon.GUI:GetHeight())
	end
end

--row management
function LISTDISPLAY.OnInitialize()
	LISTDISPLAY.rows = {} --contains fontstrings
	LISTDISPLAY.startx = 0
	LISTDISPLAY.starty = 0
	LISTDISPLAY.rowheight = 20
	LISTDISPLAY.showingrows = 0
end
function LISTDISPLAY.GetRow(i)
	local fs = LISTDISPLAY.rows[i]
	if not fs then
		fRaid:Debug('making new label')
		fs = fLib.GUI.CreateLabel(addon.GUI, LISTDISPLAY.startx, -LISTDISPLAY.starty-(LISTDISPLAY.rowheight * (i-1)), '')
		LISTDISPLAY.rows[i] = fs
	end
	fs:Show()
	if i > LISTDISPLAY.showingrows then
		LISTDISPLAY.showingrows = i
	end
	return fs
end

function LISTDISPLAY.HideRows(i)
	LISTDISPLAY.showingrows = i-1
	for idx = i, #LISTDISPLAY.rows do
		fRaid:Debug('hiding '..idx)
		LISTDISPLAY.rows[idx]:Hide()
	end
end

function LISTDISPLAY.GetHeight()
	return LISTDISPLAY.showingrows * LISTDISPLAY.rowheight
end