fRaidBid = {}
local addon = fRaidBid
local NAME = 'fRaidBid'
local MYNAME = UnitName('player')
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

function BIDLIST.GetItemInfoByNumber(number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			return info
		end
	end
end

function BIDLIST.GetItemInfoByItemId(itemid)
	print('getting iteminfo by id')
	for idx,info in ipairs(db.bidlist) do
		print('matching ' .. info.id.. ' with ' .. itemid)
		if info.id == itemid then
			print('matched')
			return info
		end
	end
end

function BIDLIST.GetBidInfo(number,playername)
	local iteminfo = BIDLIST.GetItemInfoByNumber(number)
	for idx,bidinfo in ipairs(iteminfo.bids) do
		if bidinfo.name == playername then
			return bidinfo
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
		
		--check if itemid already in the list
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
	local itemid
	if type(itemlink) == 'string' then
		itemid = fRaid:ExtractItemId(itemlink)
	end

	print('REMOVEITEM')
	for idx,info in ipairs(db.bidlist) do
		print(idx .. '-matching '..info.id .. ' and ' .. itemid)
		if info.id == itemid then
			print('matched')
			if info.count == 1 then
				print('count = 1')
				tremove(db.bidlist, idx)
				--only reset db.bidnumber if db.bidlist is empty
				if #db.bidlist == 0 then
					db.bidnumber = 1
				end
			else
				print('count = ' .. info.count)
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
	
	local x, y
	x = tonumber(a.amount) or 0
	y = tonumber(b.amount) or 0
	
	if x == y then
		return a.name < b.name
	else
		return x < y
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
				amount = tonumber(bidamount),
				winner = false,
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
function addon.Scan()
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

function addon.AnnounceBidItems()
	for idx,iteminfo in ipairs(BIDLIST.GetList()) do
		local msg = iteminfo.number .. ' ' .. iteminfo.link .. ' /w ' .. MYNAME .. ' ' .. fRaid.GetBidPrefix() .. ' number amount'
		SendChatMessage(msg, 'RAID')
	end
end

function addon.AddBid(playername, number, cmd)
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
	
	local iteminfo = BIDLIST.GetItemInfoByNumber(number)
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
		amount = tonumber(cmd)
	else
		if cmd == 'all' then
			if dkpinfo then
				if dkpinfo.dkp > 0 then
					amount = tonumber(dkpinfo.dkp)
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
				amount = tonumber(lootinfo.mindkp)
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

function addon.ToggleWinner(number, playername)
	local iteminfo = BIDLIST.GetItemInfoByNumber(number)
	local bidinfo = nil
	local winnercount = 0
	for idx,bid in ipairs(iteminfo.bids) do
		if bid.winner then
			if bid.name == playername then
				bid.winner = false
				return
			end
			winnercount = winnercount + 1
		end
		if bid.name == playername then
			bidinfo = bid
		end
	end
	
	if winnercount >= iteminfo.count then
		fRaid:Print('Cannot set more than ' .. iteminfo.count .. ' winners')
		return
	end
	
	bidinfo.winner = true
end

function addon.AnnounceWinningBids()
	for idx,biditem in ipairs(BIDLIST.GetList()) do
		for idx2,bidinfo in ipairs(biditem.bids) do
			if bidinfo.winner then
			end
		end
	end
end

--==================================================================================================
--Events

--open the bid window if it isn't open
function fRaidBid.LOOT_OPENED()
	if not addon.GUI:IsVisible() then
		addon.GUI.Toggle()
	end
end

--close the bid window if no bids
function fRaidBid.LOOT_CLOSED()
	if BIDLIST.GetCount() == 0 then
		if addon.GUI:IsVisible() then
			addon.GUI.Toggle()
		end
	end
end

function fRaidBid.CHAT_MSG_LOOT(eventName, msg)
	print(eventName .. '>>' .. msg)
	local name, link
	local starti, endi = strfind(msg, 'You receive loot: ')
	if starti and starti == 1 then
		starti = endi + 1
		_, endi = strfind(msg, '|h|r')
		name = MYNAME
		link = strsub(msg, starti, endi)
		print('i sense that you have looted ' .. link)
	end
	
	local starti, endi = strfind(msg, ' receives loot: ')
	if starti and starti > 1 then
		name = strsub(msg, 1, starti - 1)
		starti = endi + 1
		_, endi = strfind(msg, '|h|r')
		link = strsub(msg, starti, endi)
		print('i sense that ' .. name .. ' has looted ' .. link)
	end
	
	if name and link then
		print('name and link exist')
		local itemid = fRaid:ExtractItemId(link)
		local iteminfo = BIDLIST.GetItemInfoByItemId(itemid)
		if iteminfo then --the item is up for bid
			print('iteminfo exists')
			local bidinfo = BIDLIST.GetBidInfo(iteminfo.number, name)
			if bidinfo then	--player has bid on that item
				--open a window and confirm charging dkp
				
			end
			print('not attemptin to remove item')
			--BIDLIST.RemoveItem(link)
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
	addon.GUI = fLib.GUI.CreateEmptyFrame(2, NAME .. '_MW')
	local mw = addon.GUI
	
	mw:SetWidth(minwidth)
	mw:SetHeight(minheight)
	mw:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', db.gui.x, db.gui.y)
		
	--Title
	fs = fLib.GUI.CreateLabel(mw)
	fs:SetText(NAME)
	fs:SetPoint('TOP', 0, -y)
	y = y + fs:GetHeight() + padding
	
	--Close Button
	button = fLib.GUI.CreateActionButton(mw)
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
	
	--Add Loot button
	--button = fLib.GUI.CreateActionButton('Add Loot', mw, x,-y, addon.Scan)
	button = fLib.GUI.CreateActionButton(mw)
	button:SetText('Add Loot')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() addon:Scan()  end)
	button:SetPoint('TOPLEFT', mw, 'TOPLEFT', x, -y)

	x = x + 80
	
	--Add Inv Loot button
	--button = fLib.GUI.CreateActionButton('Add Inventory', mw, x,-y, nil)
	button = fLib.GUI.CreateActionButton(mw)
	button:SetText('Add Inventory')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()   end)
	button:SetPoint('TOPLEFT', mw, 'TOPLEFT', x, -y)
	x = padding
	y = y + button:GetHeight() + padding
	
	--Separator
	local tex = fLib.GUI.CreateSeparator(mw, -y)
	y = y + tex:GetHeight() + padding
	
	LISTDISPLAY.startx = x
	LISTDISPLAY.starty = y
	addon.RefreshGUI()
	
	--Clear Button
	--button = fLib.GUI.CreateActionButton('Clear', mw, 0, 0, BIDLIST.Clear)
	button = fLib.GUI.CreateActionButton(mw)
	button:SetText('Clear')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() BIDLIST.Clear()  end)
	button:SetPoint('BOTTOMLEFT', mw, 'BOTTOMLEFT', padding+8, padding+8)
	y = button:GetHeight() + padding + 8
	--Announce current winners button
	--button = fLib.GUI.CreateActionButton('Announce Winners', mw, 0,0, nil)
	button = fLib.GUI.CreateActionButton(mw)
	button:SetText('Announce Winners')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()  end)
	button:SetPoint('BOTTOM', mw, 'BOTTOM', 0, y + padding)
	
end

function addon.RefreshGUI()
	fRaid:Debug('refreshing gui')
	addon.GUI:SetWidth(minwidth)
	addon.GUI:SetHeight(minheight)
	
	local row_idx = 1
	local lstrow = 1
	local bt
	for idx,info in ipairs(BIDLIST.GetList()) do
		bt = LISTDISPLAY.GetRow(row_idx)
		print('setting text to ' .. info.number .. ' ' .. info.link .. 'x' .. info.count)
		bt:SetText(info.number .. ' ' .. info.link .. 'x' .. info.count)
		print('widtn adn height to ' .. bt:GetTextWidth() .. ',' .. bt:GetTextHeight())
		bt:SetWidth(bt:GetTextWidth())
		bt:SetHeight(bt:GetTextHeight())
		
		local width = bt:GetWidth() + padding + padding --its weird, bt:GetWidth() gives a larger value, after the first time...
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
			bt = LISTDISPLAY.GetRow(row_idx)
			local dkpinfo = fDKP.DKPLIST.GetPlayerInfo(bid.name)
			if dkpinfo then
				bt:SetText('    '..bid.name .. ' bid ' .. bid.amount .. '(has ' .. dkpinfo.dkp .. ' dkp)')
			else
				bt:SetText('    '..bid.name .. ' bid ' .. bid.amount .. ' (has no dkp)')
			end
			bt:SetWidth(bt:GetTextWidth())
			bt:SetHeight(bt:GetTextHeight())
			bt:SetScript('OnClick', function() addon.ToggleWinner(info.number, bid.name) end)
			row_idx = row_idx + 1
		end
		
		lstrow = row_idx
	end
	
	LISTDISPLAY.HideRows(lstrow)
	
	--fRaid:Debug('listdisplay height='..(LISTDISPLAY.GetHeight() + LISTDISPLAY.starty +100)..',guiheight='..addon.GUI:GetHeight())
	if LISTDISPLAY.GetHeight() + LISTDISPLAY.starty +100 > addon.GUI:GetHeight() then
		addon.GUI:SetHeight(LISTDISPLAY.GetHeight() + minheight)
		--fRaid:Debug('new guiheight='..addon.GUI:GetHeight())
	end
end

--row management
function LISTDISPLAY.OnInitialize()
	LISTDISPLAY.columns = {} --contains frames for the bottons to attach to
	LISTDISPLAY.rows = {} --contains buttons
	LISTDISPLAY.startx = 0
	LISTDISPLAY.starty = 0
	LISTDISPLAY.rowheight = 20
	LISTDISPLAY.showingrows = 0
end

--returns the column frame for column i
function LISTDISPLAY.GetColumn(i)
	if i < 1 then
		return nil
	end
	local cframe = LISTDISPLAY.columns[i]
	if not cframe then
		--create cframe
		cframe = CreateFrame('frame', nil, addon.GUI)
		if i == 1 then
			cframe:SetPoint('TOPLEFT', startx, -starty)
		else
			local prevcframe = LISTDISPLAY.GetColumn(i-1)
			cframe:SetPoint('TOPLEFT', prevcframe, 'TOPRIGHT', 0, 0)
		end
	end
	return cframe
end

function LISTDISPLAY.GetRow(i)
	if i < 1 then
		return nil
	end
	local row = LISTDISPLAY.rows[i]
	if not row then
		--create row
		row = {}
		if i > 1 then
			--check previous row exists
			local prevrow = LISTDISPLAY.GetRow(i-1)
		end
		LISTDISPLAY.rows[i] = row
	end
	return row
end

function LISTDISPLAY.SetRow(i, items)
	if i < 1 then
		return
	end
	
	local row = LISTDISPLAY.GetRow(i)
	
	
	
	local cframe, cell, prevcell
	--for each item, fill in the cell
	--if the cell doens't exist yet, create it
	for cnum = 1, #items do
		cell = row[cnum]
		if not cell then
			--create it
			cframe = LISTDISPLAY.GetColumn(cnum)
			cell = CreateFrame('button', nil, cframe)
			cell:SetFontString(cell:CreateFontString(nil, 'OVERLAY', 'GameFontNormal'))
			if i == 1 then
				--attach it to cframe
				cell:SetPoint('TOPLEFT', cframe, 'TOPLEFT', 0, 0)
				cell:SetPoint('TOPRIGHT', cframe, 'TOPRIGHT', 0, 0)
			else
				--attach it to previous row's cell
				prevcell = prevrow[cnum]
				cell:SetPoint('TOPLEFT', prevcell, 'BOTTOMLEFT', 0, 0)
				cell:SetPoint('TOPRIGHT', prevcell, 'BOTTOMRIGHT', 0, 0)
			end
		end
		--fill in cell
		--fix column's width
	end
end

--items - list of values in a row
function LISTDISPLAY.SetRow(items, row_idx)
	--first column contains checkbox
	local c_idx = 1
	local cframe = LISTDISPLAY.GetColumn(c_idx)
	local check = LISTDISPLAY.rows[1]
	if not check then
		check =	fLib.GUI.CreateCheck(cframe, 0, -(row_idx*LISTDISPLAY.rowheight))
		LISTDISPLAY.rows[1] = check
	end
	c_idx = c_idx + 1
	
	local bt
	for _,val in ipairs(items) do
		cframe = LISTDISPLAY.GetColumn(c_idx)
		bt = f
		c_idx = c_idx + 1
	end
end

function LISTDISPLAY.GetRow(i)
	local bt = LISTDISPLAY.rows[i]
	if not bt then
		fRaid:Debug('making new label')
		--bt = fLib.GUI.CreateLabel(addon.GUI, LISTDISPLAY.startx, -LISTDISPLAY.starty-(LISTDISPLAY.rowheight * (i-1)), '')
		--bt = fLib.GUI.CreateActionButton('', addon.GUI, LISTDISPLAY.startx, -LISTDISPLAY.starty-(LISTDISPLAY.rowheight * (i-1)), nil)
		bt = fLib.GUI.CreateActionButton(addon.GUI)
		bt:SetPoint('TOPLEFT', addon.GUI, 'TOPLEFT', LISTDISPLAY.startx, -LISTDISPLAY.starty-(LISTDISPLAY.rowheight * (i-1)))
		LISTDISPLAY.rows[i] = bt
	end
	bt:Show()
	if i > LISTDISPLAY.showingrows then
		LISTDISPLAY.showingrows = i
	end
	return bt
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