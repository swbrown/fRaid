fRaidBid = {}
local addon = fRaidBid
local NAME = 'fRaidBid'
local MYNAME = UnitName('player')
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
end

--==================================================================================================
--BIDLIST
--db.bidnumber (used to keep track of the current bid number,
--				which might not match the index of db.bidlist)
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

function BIDLIST.GetItemInfoByNumber(number)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			return info
		end
	end
end

function BIDLIST.GetItemInfoByItemId(itemid)
	for idx,info in ipairs(db.bidlist) do
		if info.id == itemid then
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

--accepts a string or a list of strings
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
		return x > y
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
			sort(info.bids, bidcomparer)
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

function addon.AddBid(playername, number, cmd)
	if not playername then
		fRaid:Whisper(playername,'Invalid bid: missing playername')
		return
	end
	local nums = BIDLIST.GetAvailableNumbers()
	if not number then
		fRaid:Whisper(playername,'Invalid bid: invalid or missing bid number. Available bid numbers are '..strjoin(',', unpack(nums)))
		return
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

function addon.AnnounceBidItems()
	for idx,iteminfo in ipairs(BIDLIST.GetList()) do
		local msg = iteminfo.number .. ' ' .. iteminfo.link .. ' /w ' .. MYNAME .. ' ' .. fRaid.GetBidPrefix() .. ' number amount'
		SendChatMessage(msg, 'RAID')
	end
end

function addon.AnnounceWinningBids()
	for idx,iteminfo in ipairs(BIDLIST.GetList()) do
		for idx2,bidinfo in ipairs(iteminfo.bids) do
			if bidinfo.winner then
				SendChatMessage(bidinfo.name .. ' is winning ' .. iteminfo.link, 'RAID')
			end
		end
	end
end

--==================================================================================================
--Events

--open the bid window if it isn't open
function fRaidBid.LOOT_OPENED()
	addon:ShowGUI()
end

--close the bid window if no bids
function fRaidBid.LOOT_CLOSED()
	if BIDLIST.GetCount() == 0 then
		addon:HideGUI()
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
function fRaidBid.CreateGUI()
	if addon.GUI then
		return
	end

	local padding = 8
	local x = 8
	local y = 8
	
	local itemrowcount = 5
	local bidrowcount = 8

	--create frames
	addon.GUI = fLib.GUI.CreateEmptyFrame(2, NAME .. '_MW')
	local mw = addon.GUI
	
	mw.subframes = {}
	for i = 1, 3 do
		tinsert(mw.subframes, fLib.GUI.CreateClearFrame(mw))
		--mw.subframes[i]:SetFrameLevel(0)
		mw.subframes[i]:RegisterForDrag('LeftButton')
		mw.subframes[i]:SetScript('OnDragStart', function(this, button)
			mw:StartMoving()
		end)
		mw.subframes[i]:SetScript('OnDragStop', function(this, button)
			mw:StopMovingOrSizing()
		end)
	end
	
	mw:SetWidth(400)
	mw:SetHeight(350)
	mw:SetPoint('CENTER', -200, 100)
	
	local mw_menu = mw.subframes[1]
	mw_menu:SetWidth(100)
	mw_menu:SetHeight(300)
	mw_menu:SetPoint('TOPLEFT', mw, 'TOPLEFT', 0, -24)
	
	local mw_items = mw.subframes[2]
	mw_items:SetWidth(300)
	mw_items:SetHeight(125)
	mw_items:SetPoint('TOPLEFT', mw_menu, 'TOPRIGHT', 0,0)
	
	local mw_bids = mw.subframes[3]
	mw_bids:SetWidth(300)
	mw_bids:SetHeight(150)
	mw_bids:SetPoint('TOP', mw_items, 'BOTTOM', 0,0)

	--4 Title: fRaidBid, Items, Bids
	mw.titles = {}
	for i = 1, 4 do
		tinsert(mw.titles, fLib.GUI.CreateLabel(mw))
	end
	mw.titles[1]:SetText(NAME)
	mw.titles[2]:SetText('Announce')
	mw.titles[3]:SetText('Items')
	mw.titles[4]:SetText('Bids')
	
	mw.titles[1]:SetPoint('TOP', 0, -padding)
	mw.titles[2]:SetPoint('TOPLEFT', mw_menu, 'TOPLEFT', padding, -padding)
	mw.titles[3]:SetPoint('TOPLEFT', mw_items, 'TOPLEFT', padding, -padding)
	mw.titles[4]:SetPoint('TOPLEFT', mw_bids, 'TOPLEFT', padding, -padding)
	
	--6 Buttons: Add Loot, Announce Items, Announce Current Winners, Clear Items, Info, Close
	mw.buttons = {}
	for i = 1, 6 do	
		tinsert(mw.buttons, fLib.GUI.CreateActionButton(mw))
		mw.buttons[i]:SetFrameLevel(3)
	end

	--Add Loot button
	button = mw.buttons[1]
	button:SetText('Add Loot')
	button:GetFontString():SetFontObject(GameFontHighlightLarge)
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() addon:Scan()  end)
	button:SetPoint('TOPRIGHT', mw, 'TOPRIGHT', -padding, -padding)
	
	--Announce items for bid
	button = mw.buttons[2]
	button:SetText('  >Items')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() addon.AnnounceBidItems() end)
	button:SetPoint('TOPLEFT', mw.titles[2], 'BOTTOMLEFT', 0, -4)

	--Announce current winners button
	button = mw.buttons[3]
	button:SetText('  >Winners')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() addon.AnnounceWinningBids()  end)
	button:SetPoint('TOPLEFT', mw.buttons[2], 'BOTTOMLEFT', 0, -4)
	
	--Info button
	button = mw.buttons[4]
	button:SetText('Info >')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()
		--mw:Toggle()
	end)
	button:SetPoint('TOPLEFT', mw.buttons[3], 'BOTTOMLEFT', 0,-padding)
	
	--Clear button
	button = mw.buttons[5]
	button:SetText('Clear')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function() BIDLIST.Clear()  end)
	button:SetPoint('BOTTOMLEFT', mw, 'BOTTOMLEFT', padding+8, padding+8)
	
	--Close button
	button = mw.buttons[6]
	button:SetText('Close')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function()
		mw:Toggle()
	end)
	button:SetPoint('BOTTOMRIGHT', mw, 'BOTTOMRIGHT', -padding-8, padding+8)
	
	--Scripts for mainwindow
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
	
	--Some functions for mainwindow
	function mw:SaveLocation()
		db.gui.x = self:GetLeft()
		db.gui.y = self:GetTop()
	end
	
	mw_items.selecteditemindex = 1 --users click on an item to select which bids are showing in mw_bids
	mw_items.startingindex = 1 --for scrolling, the index of the first item showing in mw_items
	mw_bids.startingindex = 1 --for scrolling, the index of the first bid showing in mw_bids
	
	--reloads the data in mw_items and mw_bids
	function mw:Refresh()
		self:LoadItemRows(mw_items.startingindex)
		self:LoadBidRows(mw_bids.startingindex)
		self.needRefresh = false
	end
	
	--loads data into mw_items
	function mw:LoadItemRows(startingindex)
		mw_items.startingindex= startingindex
		if BIDLIST.GetCount() > itemrowcount then
			mw_items.slider:SetMinMaxValues(1, BIDLIST.GetCount() - itemrowcount + 1)
		else
			mw_items.slider:Hide()
		end
		local items = BIDLIST.GetList()
		local iteminfo
		local z = 1 --current ui row
		for i = startingindex, startingindex + itemrowcount - 1 do
			iteminfo = items[i]
			if iteminfo then
				--fill in this row's ui with data
				mw_items.col1[z]:SetText(iteminfo.number)
				mw_items.col1[z]:Show()
				
				mw_items.col2[z]:SetText(iteminfo.link .. 'x' .. iteminfo.count)
				mw_items.col2[z]:Show()
				mw_items.col2[z].itemindex = i
				mw_items.col2[z].highlightspecial:Hide()
				if i == mw_items.selecteditemindex then
					mw_items.col2[z].highlightspecial:Show()
				end
			else
				--hide this row's ui
				mw_items.col1[z]:Hide()
				mw_items.col2[z]:Hide()
				mw_items.col2[z].highlightspecial:Hide()
			end
			
			z = z + 1
		end
	end
	
	--loads data into mw_bids
	function mw:LoadBidRows(startingindex)
		mw_bids.startingindex= startingindex
		local items = BIDLIST.GetList()
		local iteminfo = items[mw_items.selecteditemindex]
		local bids = {}
		local bidinfo
		if iteminfo then
			bids = iteminfo.bids
		end
		
		if #bids > bidrowcount then
			mw_bids.slider:SetMinMaxValues(1, BIDLIST.GetCount() - itemrowcount + 1)
		else
			mw_bids.slider:Hide()
		end
		
		
		local z = 1 --current ui row
		for i = startingindex, startingindex + bidrowcount - 1 do
			bidinfo = bids[i]
			if bidinfo then
				--fill in this row's ui with data
				if bidinfo.winner then
					mw_bids.col1[z]:Show()
				else
					mw_bids.col1[z]:Hide()
				end
				mw_bids.col2[z]:SetText(bidinfo.name)
				mw_bids.col2[z]:Show()
				mw_bids.col2[z].itemindex = i

				mw_bids.col3[z]:SetText(bidinfo.amount)
				mw_bids.col3[z]:Show()
				mw_bids.col3[z]:ClearFocus()
				mw_bids.col3[z].itemindex = i

				local dkpinfo = fDKP.DKPLIST.GetPlayerInfo(bidinfo.name)
				if dkpinfo then
					mw_bids.col4[z]:SetText(dkpinfo.dkp)
				else
					mw_bids.col4[z]:SetText(0)
				end
				mw_bids.col4[z]:Show()
				
				--TODO: need to fill this column in...
				mw_bids.col5[z]:Hide()
			else
				--hide this row's ui
				mw_bids.col1[z]:Hide()
				mw_bids.col2[z]:Hide()
				mw_bids.col3[z]:Hide()
				mw_bids.col4[z]:Hide()
				mw_bids.col5[z]:Hide()
			end
			
			z = z + 1
		end
	end
	
	local ui
	
	--Items
	----Column Headers
	----2 columns: Number, Link
	mw_items.headers = {} --contains fontstrings
	for i = 1,2 do
		ui = fLib.GUI.CreateLabel(mw_items)
		tinsert(mw_items.headers, ui)
		ui:SetJustifyH('LEFT')
		ui:SetHeight(12)
	end
	
	mw_items.headers[1]:SetPoint('TOPLEFT',mw.titles[3], 'BOTTOMLEFT', 0, -padding)
	mw_items.headers[2]:SetPoint('TOPLEFT', mw_items.headers[1], 'TOPRIGHT', 0,0)
	
	mw_items.headers[1]:SetText('Num')
	mw_items.headers[1]:SetWidth(50)
	mw_items.headers[2]:SetText('Item')
	mw_items.headers[2]:SetWidth(200)
	
	ui = fLib.GUI.CreateSeparator(mw_items)
	ui:SetWidth(mw_items:GetWidth()- 32)
	ui:SetPoint('TOPLEFT', mw_items.headers[1], 'BOTTOMLEFT', 0,-2)
	
	----Column 1: Item Numbers
	mw_items.col1 = {} --contains fontstrings
	for i = 1, itemrowcount do
		ui = fLib.GUI.CreateLabel(mw_items)
		tinsert(mw_items.col1, ui)
		ui:SetText('11')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_items.headers[1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_items.headers[1], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_items.col1[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_items.col1[i-1], 'BOTTOMRIGHT', 0, -4)
		end
	end
	
	----Column 2: Link
	mw_items.col2 = {} --contains buttons
	for i = 1, itemrowcount do
		ui = fLib.GUI.CreateActionButton(mw_items)
		tinsert(mw_items.col2, ui)
		
		ui:GetFontString():SetAllPoints()
		ui:GetFontString():SetJustifyH('LEFT')
		ui:SetText('test')
		ui:SetHeight(ui:GetTextHeight())
		
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_items.headers[2], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_items.headers[2], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_items.col2[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_items.col2[i-1], 'BOTTOMRIGHT', 0, -4)
		end
		
		local highlight = ui:CreateTexture(nil, "BACKGROUND")
		--highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		highlight:SetTexture(0.96, 0.55, 0.73, .2)
		ui.highlightspecial = highlight
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(ui)
		highlight:Hide()
		
		ui.itemindex= 0
		ui:SetScript('OnEnter', function()
			this.highlight:Show()
			GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
			GameTooltip:SetPoint('TOPLEFT', mw, 'TOPRIGHT', 0, 0)
			GameTooltip:SetHyperlink('item:'..BIDLIST.GetList()[this.itemindex].id)
		end)
		ui:SetScript('OnLeave', function()
			this.highlight:Hide()
			GameTooltip:FadeOut()
		end)
		ui:SetScript('OnClick', function()
			mw_items.selecteditemindex = this.itemindex
			mw:LoadItemRows(mw_items.startingindex)
			mw:LoadBidRows(1)
		end)
	end
	
	----Scroll bar
	local slider = CreateFrame('slider', nil, mw_items)
	mw_items.slider = slider
	slider:SetOrientation('VERTICAL')
	slider:SetMinMaxValues(1, 1)
	slider:SetValueStep(1)
	slider:SetValue(1)
	
	slider:SetWidth(12)
	--slider:SetHeight(itemrowcount * 12)
	
	slider:SetPoint('TOPRIGHT', -2, -40)
	slider:SetPoint('BOTTOMRIGHT', -2, 0)
	
	slider:SetThumbTexture('Interface/Buttons/UI-SliderBar-Button-Vertical')
	slider:SetBackdrop({
		  bgFile='Interface/Buttons/UI-SliderBar-Background',
		  edgeFile = 'Interface/Buttons/UI-SliderBar-Border',
		  tile = true,
		  tileSize = 8,
		  edgeSize = 8,
		  insets = {left = 3, right = 3, top = 3, bottom = 3}
		  --insets are for the bgFile
	})

	slider:SetScript('OnValueChanged', function()
		mw:LoadItemRows(this:GetValue())
	end)
	
	mw_items:EnableMouseWheel(true)
	mw_items:SetScript('OnMouseWheel', function(this,delta)
		local current = this.slider:GetValue()
		local min,max = this.slider:GetMinMaxValues()
		if delta < 0 then
			current = current + 3
			if current > max then
				current = max
			end
			this.slider:SetValue(current)
		elseif delta > 0 then
			current = current - 3
			if current < min then
				current = min
			end
			this.slider:SetValue(current)
		end
	end)
	
	--Bids
	----Column Headers
	----5 columns: Check, Name, Bid, Total, Rank
	mw_bids.headers = {} --contains fontstrings
	for i = 1,5 do
		ui = fLib.GUI.CreateLabel(mw_bids)
		tinsert(mw_bids.headers, ui)
		ui:SetJustifyH('LEFT')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw.titles[4], 'BOTTOMLEFT', 0, -padding)
		else
			ui:SetPoint('TOPLEFT', mw_bids.headers[i-1], 'TOPRIGHT', 0,0)
		end
		ui:SetHeight(12)
	end
	
	mw_bids.headers[1]:SetText(' ')
	mw_bids.headers[1]:SetWidth(15)
	mw_bids.headers[2]:SetText('Name')
	mw_bids.headers[2]:SetWidth(120)
	mw_bids.headers[3]:SetText('Bid')
	mw_bids.headers[3]:SetWidth(50)
	mw_bids.headers[4]:SetText('Total')
	mw_bids.headers[4]:SetWidth(50)
	mw_bids.headers[5]:SetText('Rank')
	mw_bids.headers[5]:SetWidth(115)
	
	tex = fLib.GUI.CreateSeparator(mw_bids)
	tex:SetWidth(mw_bids:GetWidth()- 32)
	tex:SetPoint('TOPLEFT', mw_bids.headers[1], 'BOTTOMLEFT', 0,-2)
	
	----Column 1: Checks
	mw_bids.col1 = {} --contains buttons
	for i = 1, bidrowcount do
		ui = fLib.GUI.CreateCheck(mw_bids)
		tinsert(mw_bids.col1, ui)
		ui:SetWidth(12)
		ui:SetHeight(12)		
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[1], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col1[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col1[i-1], 'BOTTOMRIGHT', 0, -4)
		end
	end
	
	----Column 2: Name
	mw_bids.col2 = {} --contains buttons
	for i = 1, bidrowcount do
		ui = fLib.GUI.CreateActionButton(mw_bids)
		tinsert(mw_bids.col2, ui)
		ui:GetFontString():SetAllPoints()
		ui:GetFontString():SetJustifyH('LEFT')
		ui:SetText('test')
		ui:SetHeight(ui:GetTextHeight())

		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[2], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[2], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col2[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col2[i-1], 'BOTTOMRIGHT', 0, -4)
		end
		
		ui.itemindex= 0
		ui:SetScript('OnClick', function()
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bids = iteminfo.bids
				if bids[this.itemindex].winner then
					bids[this.itemindex].winner = false
				else
					local winnercount = 0
					for idx,bid in ipairs(bids) do
						if bid.winner then
							winnercount = winnercount + 1
						end
					end
					if winnercount >= iteminfo.count then
						fRaid:Print('Cannot set more than ' .. iteminfo.count .. ' winners for ' .. iteminfo.link)
					else
						bids[this.itemindex].winner = true
					end
				end					
				mw:LoadBidRows(mw_bids.startingindex)
			end
		end)
	end
	
	----Column 3: Amount
	mw_bids.col3 = {} --contains editboxes
	for i = 1, bidrowcount do
		ui = fLib.GUI.CreateEditBox2(mw_bids, 'dkp')
		tinsert(mw_bids.col3, ui)
		
		ui:SetWidth(100)
		ui:SetNumeric(true)			
		
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[3], 'BOTTOMLEFT', 0, -2)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[3], 'BOTTOMRIGHT', 0, -2)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col3[i-1], 'BOTTOMLEFT', 0, -2)
			ui:SetPoint('TOPRIGHT', mw_bids.col3[i-1], 'BOTTOMRIGHT', 0, -2)
		end
		
		ui.itemindex= 0
		ui:SetScript('OnEnterPressed', function()
			--save new value
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bid = iteminfo.bids[this.itemindex]
				bid.dkp = this:GetNumber()
				this:SetNumber(bid.dkp)
			end
			this:ClearFocus()
		end)
		ui:SetScript('OnEscapePressed', function()
			--restore old value
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bid = iteminfo.bids[this.itemindex]
				this:SetNumber(bid.dkp)
			end
			this:ClearFocus()
		end)
	end
	
	----Column 4: Total
	mw_bids.col4 = {} --contains fontstrings
	for i = 1, bidrowcount do
		ui = fLib.GUI.CreateLabel(mw_bids)
		tinsert(mw_bids.col4, ui)
		ui:SetText('11')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[4], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[4], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col4[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col4[i-1], 'BOTTOMRIGHT', 0, -4)
		end
	end
	
	----Column 5: Rank
	mw_bids.col5 = {} --contains fontstrings
	for i = 1, bidrowcount do
		ui = fLib.GUI.CreateLabel(mw_bids)
		tinsert(mw_bids.col5, ui)
		ui:SetText('11')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[5], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[5], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col5[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col5[i-1], 'BOTTOMRIGHT', 0, -4)
		end
	end

	
	----Scroll bar
	slider = CreateFrame('slider', nil, mw_bids)
	mw_bids.slider = slider
	slider:SetOrientation('VERTICAL')
	slider:SetMinMaxValues(1, 1)
	slider:SetValueStep(1)
	slider:SetValue(1)
	
	slider:SetWidth(12)
	--slider:SetHeight(bidrowcount * 12)
	
	slider:SetPoint('TOPRIGHT', -2, -40)
	slider:SetPoint('BOTTOMRIGHT', -2, 0)
	
	slider:SetThumbTexture('Interface/Buttons/UI-SliderBar-Button-Vertical')
	slider:SetBackdrop({
		  bgFile='Interface/Buttons/UI-SliderBar-Background',
		  edgeFile = 'Interface/Buttons/UI-SliderBar-Border',
		  tile = true,
		  tileSize = 8,
		  edgeSize = 8,
		  insets = {left = 3, right = 3, top = 3, bottom = 3}
		  --insets are for the bgFile
	})

	slider:SetScript('OnValueChanged', function()
		mw:LoadBidRows(this:GetValue())
	end)
	
	mw_bids:EnableMouseWheel(true)
	mw_bids:SetScript('OnMouseWheel', function(this,delta)
		local current = this.slider:GetValue()
		local min,max = this.slider:GetMinMaxValues()
		if delta < 0 then
			current = current + 3
			if current > max then
				current = max
			end
			this.slider:SetValue(current)
		elseif delta > 0 then
			current = current - 3
			if current < min then
				current = min
			end
			this.slider:SetValue(current)
		end
	end)
	
	--load initial rows
	mw:LoadItemRows(1)
	mw:LoadBidRows(1)
end

function fRaidBid.ShowGUI()
	if not addon.GUI then
		addon.CreateGUI()
	end
	addon.GUI:Show()
end
function fRaidBid.HideGUI()
	if addon.GUI then
		addon.GUI:Hide()
	end
end
function fRaidBid.ToggleGUI()
	if not addon.GUI then
		addon.CreateGUI()
	end
	addon.GUI:Toggle()
end
function fRaidBid.RefreshGUI()
	if addon.GUI then
		if addon.GUI:IsVisible() then
			addon.GUI:Refresh()
			addon.GUI.needRefresh = false
		else
			addon.GUI.needRefresh = true
		end
	end
end