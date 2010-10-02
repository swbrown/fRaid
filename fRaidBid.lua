-- vim: set softtabstop=4 tabstop=4 shiftwidth=4 noexpandtab:
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
	db.activebid = nil  --used by Award Button and LOOT_SLOT_CLEARED
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
	playername = strlower(playername)
	local iteminfo = BIDLIST.GetItemInfoByNumber(number)
	for idx,bidinfo in ipairs(iteminfo.bids) do
		if bidinfo.name == playername then
			return bidinfo
		end
	end
end

--accepts an itemlink or a list of itemlinks
function BIDLIST.AddItem(data)
	local itemlink, itemid
	local matched
	if type(data) == 'string' then
		itemlink = strtrim(data)
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
				number = db.bidnumber, --number that tracks the numbered biditems
				id = itemid, --id of the biditem
				link = itemlink, --link to the biditem
				count = 1, --how many there are available for bid (could be more than 1 like tokens, etc)
				countawarded = 0, --how many biditems have been awarded
				type = 'loot', --or 'inventory'
				isopen = true, --whether or not this biditem is still open for bidding/winning?
				bids = {} --list of bidinfos
			})
			
			local obj = fRaid.Item.GetObjectById(itemid, true)
			
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

	--print('REMOVEITEM')
	for idx,info in ipairs(db.bidlist) do
		print(idx .. '-matching '..info.id .. ' and ' .. itemid)
		if info.id == itemid then
			--print('matched')
			if info.count == 1 then
				--print('count = 1')
				tremove(db.bidlist, idx)
				--only reset db.bidnumber if db.bidlist is empty
				if #db.bidlist == 0 then
					db.bidnumber = 1
				end
			else
				--print('count = ' .. info.count)
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
	
	local a_amount, b_amount
	a_amount = tonumber(a.amount) or 0
	b_amount = tonumber(b.amount) or 0
	
	if a_amount == b_amount then
		local a_total, b_total
		a_total = tonumber(a.total) or 0
		b_total = tonumber(b.total) or 0
		if a_total == b_total then
			return a.name < b.name
		else
			return a_total > b_total
		end
	else
		return a_amount > b_amount
	end
end

function BIDLIST.AddBid(playername, number, bidamount)
	playername = strlower(playername)
	for idx,info in ipairs(db.bidlist) do
		if info.number == number then
			local alreadybid = false
			--check if they already bid
			--and refresh their total dkp (who knows, it might change)
			for idx2,bid in ipairs(info.bids) do
				if bid.name == playername then
					bid.amount = bidamount
					alreadybid = true
				end
				
				--refresh dkp
				local dkpinfo = fRaid.Player.LIST.GetPlayer(bid.name)
				local tot = 0
				if dkpinfo then
					tot = dkpinfo.dkp
				end
				bid.total = tot
			end
			
			if not alreadybid then
				--add new bid
				local lootinfo = fRaid.Item.GetObjectById(info.id)
				local x = 0
				if lootinfo then
					x = lootinfo.mindkp
				end
				local dkpinfo = fRaid.Player.LIST.GetPlayer(playername)
				local tot = 0
				if dkpinfo then
					tot = dkpinfo.dkp
				end
				
				tinsert(info.bids, {
					name = playername,
					amount = tonumber(bidamount), --how much they bid
					total = tot, --how much dkp they have available
					actual = x, --how much they will actually be charged if they win
					winner = false, --whether or not they are marked as winning by you
					awarded = false, --whether or not they were awarded the loot
					charged = false, --whether or not they were charged for this loot
					ismanualedit = false, --determines if actual amount is calculated or left alone
				})
			end
			
			--sort bids
			--print('sorting')
			sort(info.bids, bidcomparer)
			
			--refresh gui
			addon.RefreshGUI()
			return
		end
	end
	--invalid number...
end

function BIDLIST.RemoveBid(playername, number)
	playername = strlower(playername)
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

function BIDLIST.RefreshBids()
	for idx,info in ipairs(db.bidlist) do
		for idx2,bid in ipairs(info.bids) do
			--refresh dkp
			local dkpinfo = fRaid.Player.LIST.GetPlayer(bid.name)
			local tot = 0
			if dkpinfo then
				tot = dkpinfo.dkp
			end
			bid.total = tot
		end
		
		--sort bids
		sort(info.bids, bidcomparer)
	end
end

function BIDLIST.MergeWinnerLists(l1, l2)
    fRaid:Print('starting list 1 contains ' .. #l1 .. ' items')
    fRaid:Print('starting list 2 contains ' .. #l2 .. ' items')

    --winnerlist compare...
    local keepgoing = true
    local keepgoingi = 1
    local keepgoinglimit = 2000
    
    local w1, w2
    local i1 = 1
    local i2 = 1
    
    local stoppedmatching = false
    
    while keepgoing do
        w1 = l1[i1]
        w2 = l2[i2]
        
        if not w1 or not w2 then
            if w1 then
                tinsert(l2, w1)
                i1 = i1 + 1
                i2 = i2 + 1
            elseif w2 then
                tinsert(l1, w2)
                i1 = i1 + 1
                i2 = i2 + 1
            else
                keepgoing = false
                print('w1 ended at i1 = ' .. i1)
                print('w2 ended at i2 = ' .. i2)
            end
        elseif w1.name == w2.name and w1.time == w2.time then
            if stoppedmatching then
                stoppedmatching = false
                print('resumed matching at i1 = ' .. i1 .. ' , i2 = ' .. i2)
            end
            i1 = i1 + 1
            i2 = i2 + 1
        else
            if not stoppedmatching then
                stoppedmatching = true
                print('stopped matching at i1 = ' .. i1 .. ' , i2 = ' .. i2)
                print(w1.name, w1.time, w2.name, w2.time)
            end
            if w1.time < w2.time then
                tinsert(l2, i2, w1)
            else
                tinsert(l1, i1, w2)
            end
        end
        
        keepgoingi = keepgoingi + 1
        if keepgoingi > keepgoinglimit then
            keepgoing = false
        end
    end
end

--==================================================================================================
--Functions for stuff

--add items in the currently open loot window
function addon.Scan()
	fRaid.Item.Scan()

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

function addon.Search(searchstr)
	for idx,data in ipairs(fRaid.db.global.fRaidBid.winnerlist) do
		if strfind(data.link, searchstr) then
			fRaid:Print(data.link)
		end
	end
end

function addon.AddBid(playername, number, cmd)
	if not playername then
		--fRaid:Whisper(playername,'Invalid bid: missing playername')
		fRaid.Whisper2('Invalid bid: missing playername', playername)
		return
	end
	local nums = BIDLIST.GetAvailableNumbers()
	if not number then
		--fRaid:Whisper(playername,'Invalid bid: invalid or missing bid number. Available bid numbers are '..strjoin(',', unpack(nums)))
		fRaid.Whisper2('Invalid bid: invalid or missing bid number. Available bid numbers are '..strjoin(',', unpack(nums)), playername)
		return
	end
	
	local iteminfo = BIDLIST.GetItemInfoByNumber(number)
	if not iteminfo then
		--fRaid:Whisper(playername, 'Invalid bid: invalid bid number. Available bid numbers are '..strjoin(',', unpack(nums)))
		fRaid.Whisper2('Invalid bid: invalid bid number. Available bid numbers are '..strjoin(',', unpack(nums)), playername)
		return
	end
	
	local dkpinfo = fRaid.Player.LIST.GetPlayer(playername)
	
	if not cmd or (type(tonumber(cmd)) ~= 'number' and type(cmd) ~= 'string') then
		local msg = 'Invalid bid: invalid or missing bid amount or min or all or cancel\n'
		if dkpinfo then
			msg = msg ..'You have ' .. dkpinfo.dkp.. ' dkp available'
		else
			msg = msg .. 'You have no dkp available'
		end
		--fRaid:Whisper(playername, msg)
		fRaid.Whisper2(msg, playername)
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
					--fRaid:Whisper(playername, 'You have no dkp available, you can still bid min by whispering bid number min')
					fRaid.Whisper2('You have no dkp available, you can still bid min by whispering bid number min', playername)
					return
				else
					--fRaid:Whisper(playername, 'You have negative dkp available, you can still bid min by whispering bid number min')
					fRaid.Whisper2('You have negative dkp available, you can still bid min by whispering bid number min', playername)
					return
				end
			else
				--fRaid:Whisper(playername, 'You have no dkp available, you can still bid min by whispering bid number min')
				fRaid.Whisper2('You have no dkp available, you can still bid min by whispering bid number min', playername)
				return
			end
		elseif cmd == 'min' then
			local lootinfo = fRaid.Item.GetObjectById(iteminfo.id)
			if lootinfo then
				amount = tonumber(lootinfo.mindkp)
			else
				amount = 0
			end
		elseif cmd == 'cancel' then
			BIDLIST.RemoveBid(playername, number)
			--fRaid:Whisper(playername, 'Your bid on ' .. iteminfo.link..' has been removed')
			fRaid.Whisper2('Your bid on ' .. iteminfo.link..' has been removed', playername)
			return
		end
	end
	
	amount = ceil(amount)
	
	if amount < 0 then
		--fRaid:Whisper(playername, 'Negative bid amount rejected.')
		fRaid.Whisper2('Negative bid amount rejected.', playername)
		return
	end
	
	if amount > 10000 then
		--fRaid:Whisper(playername, 'Outrageous bid amount rejected.')
		fRaid.Whisper2('Outrageous bid amount rejected.', playername)
		return
	end
	
	local lootinfo = fRaid.Item.GetObjectById(iteminfo.id)
	if lootinfo and lootinfo.mindkp > 0 then
		local xdkp = 0
		if dkpinfo then
			xdkp = dkpinfo.dkp
		end
		if amount > lootinfo.mindkp and xdkp < lootinfo.mindkp then
			--amount = min(amount, max(dkpinfo.dkp, lootinfo.mindkp))
			--amount = lootinfo.mindkp
			--fRaid:Whisper(playername, 'Capping your bid at mindkp since you have less than mindkp.')		
		elseif amount < lootinfo.mindkp then
			amount = lootinfo.mindkp
			--fRaid:Whisper(playername, 'Raising your bid to mindkp.')
			fRaid.Whisper2( 'Raising your bid to mindkp.', playername)
		end
	end
	
	--cap bids based on ranks
	--TODO: implement new attendance flags
	if (dkpinfo.rank == "Member") and amount > 120 then
		amount = 120
		fRaid.Whisper2('Capping your bid at Tier 2: 120dkp', playername)
	elseif (dkpinfo.rank == "Initiate") and amount > 60 then
		amount = 60
		fRaid.Whisper2('Capping your bid at Tier 3: 60dkp', playername)
	elseif (dkpinfo.rank == "F&F" or dkpinfo.rank == "Alt" or dkpinfo.rank == "" or not dkpinfo.rank) and amount > 20 then
		amount = 20
		fRaid.Whisper2('Capping your bid at Tier 4: 20dkp', playername)
	elseif (dkpinfo.attflag == "low") and amount > 120 then
		amount = 120
		fRaid.Whisper2('Capping your bid at Tier 2: 120dkp', playername)
	end
	
	BIDLIST.AddBid(playername, number, amount)
	--fRaid:Whisper(playername, 'Accepted ' .. playername .. '\'s bid on ' .. iteminfo.link .. ' for ' .. amount .. ' DKP.')
	fRaid.Whisper2('Accepted ' .. playername .. '\'s bid on ' .. iteminfo.link .. ' for ' .. amount .. ' DKP.', playername)
end

function addon.AnnounceBidItems()
	for idx,iteminfo in ipairs(BIDLIST.GetList()) do
		local msg = iteminfo.number .. ' ' .. iteminfo.link .. ' /w ' .. MYNAME .. ' ' .. fRaid.GetBidPrefix() .. ' ' .. iteminfo.number .. ' amount'
		SendChatMessage(msg, 'RAID')
	end
end

function addon.AnnounceWinningBids()
	local nobodywon = true
	for idx,iteminfo in ipairs(BIDLIST.GetList()) do
		nobodywon = true
		for idx2,bidinfo in ipairs(iteminfo.bids) do
			if bidinfo.winner then
				nobodywon = false
				SendChatMessage(iteminfo.number .. ' ' .. bidinfo.name .. ' has won ' .. iteminfo.link .. ' for ' .. bidinfo.actual, 'RAID')
				--print(iteminfo.number .. ' ' .. bidinfo.name .. ' is winning ' .. iteminfo.link, 'RAID')
			end
		end
		if nobodywon then
			SendChatMessage(iteminfo.number .. ' nobody wants ' .. iteminfo.link, 'RAID')
		end
	end
end


--==================================================================================================
--Events

--open the bid window if it isn't open
function fRaidBid.LOOT_OPENED()
	if db.alwaysshow or UnitInRaid('player') then
		--addon:ShowGUI()
	end
end

--close the bid window if no bids
function fRaidBid.LOOT_CLOSED()
	if BIDLIST.GetCount() == 0 then
		addon:HideGUI()
	end
end

function fRaidBid.CHAT_MSG_LOOT(eventName, msg)
	--print(eventName .. '>>' .. msg)
	local name, link
	local starti, endi = strfind(msg, 'You receive loot: ')
	if starti and starti == 1 then
		starti = endi + 1
		_, endi = strfind(msg, '|h|r')
		name = MYNAME
		link = strsub(msg, starti, endi)
		--print('i sense that you have looted ' .. link)
	end
	
	local starti, endi = strfind(msg, ' receives loot: ')
	if starti and starti > 1 then
		name = strsub(msg, 1, starti - 1)
		starti = endi + 1
		_, endi = strfind(msg, '|h|r')
		link = strsub(msg, starti, endi)
	end
	
	if name and link then
		local itemid = fRaid:ExtractItemId(link)
		local iteminfo = BIDLIST.GetItemInfoByItemId(itemid)
		if iteminfo and iteminfo.isopen then --the item is up for bid and open
			local bidinfo = BIDLIST.GetBidInfo(iteminfo.number, name)
			if bidinfo and bidinfo.winner and not bidinfo.awarded then	--player has bid on that item
				--charge dkp
				fRaidBid.ChargeDKP(iteminfo, bidinfo)
				
				bidinfo.awarded = true
				iteminfo.countawarded = iteminfo.countawarded + 1
				--close biditem
				if iteminfo.countawarded >= iteminfo.count then
					iteminfo.isopen = false
				end
				
				--TODO maybe: open a window and confirm charging dkp
				addon.RefreshGUI()
			else
				--TODO maybe: if nobody has a bid on the item open popup requesting dkp to charge
			end
		end
	end
end

function fRaidBid.LOOT_SLOT_CLEARED(eventName, slotnumber)
--	print(eventName .. ' slotnumber = ' .. slotnumber)
	if db.activeiteminfo and db.activebidinfo and db.activelootlinks then
		if db.activelootlinks[slotnumber] == db.activeiteminfo.link then
			db.activebidinfo.awarded = true
			
			db.activeiteminfo.countawarded = db.activeiteminfo.countawarded + 1
			--close biditem
			if db.activeiteminfo.countawarded >= db.activeiteminfo.count then
			db.activeiteminfo.isopen = false
			end
			
			db.activeiteminfo = nil
			db.activebidinfo = nil
			db.activelootlinks = nil
			
			addon.RefreshGUI()
		end
	end
end

function fRaidBid.ChargeDKP(iteminfo, bidinfo)
	if not bidinfo.charged then
		--charge dkp
		fRaid:Print('Charging ' .. bidinfo.name .. ' ' .. bidinfo.actual .. ' dkp for ' .. iteminfo.link)
		fRaid.Player.AddDkp(bidinfo.name, -bidinfo.actual, iteminfo.link)
		
		local winnerinfo = {
			id = iteminfo.id,
			link = iteminfo.link,
			name = bidinfo.name,
			amount = bidinfo.actual,
			time = date("%m/%d/%y %H:%M:%S")
		}
		tinsert(db.winnerlist, winnerinfo)
		bidinfo.charged = true
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

	local button, ui, prevui

	--create frames
	addon.GUI = fLibGUI.CreateEmptyFrame(2, NAME .. '_MW')
	local mw = addon.GUI
	
	mw.subframes = {}
	for i = 1, 3 do
		tinsert(mw.subframes, fLibGUI.CreateClearFrame(mw))
		mw.subframes[i]:RegisterForDrag('LeftButton')
		mw.subframes[i]:SetScript('OnDragStart', function(this, button)
			mw:StartMoving()
		end)
		mw.subframes[i]:SetScript('OnDragStop', function(this, button)
			mw:StopMovingOrSizing()
		end)
	end
	
	mw:SetWidth(525)
	mw:SetHeight(350)
	mw:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', db.gui.x, db.gui.y)
	
	local mw_menu = mw.subframes[1]
	mw_menu:SetWidth(100)
	mw_menu:SetHeight(300)
	mw_menu:SetPoint('TOPLEFT', mw, 'TOPLEFT', 0, -24)
	
	local mw_items = mw.subframes[2]
	mw_items:SetWidth(425)
	mw_items:SetHeight(125)
	mw_items:SetPoint('TOPLEFT', mw_menu, 'TOPRIGHT', 0,0)
	
	local mw_bids = mw.subframes[3]
	mw_bids:SetWidth(425)
	mw_bids:SetHeight(150)
	mw_bids:SetPoint('TOP', mw_items, 'BOTTOM', 0,0)

	--4 Titles: fRaidBid, Announce, Items, Bids
	mw.titles = {}
	for i = 1, 4 do
		tinsert(mw.titles, fLibGUI.CreateLabel(mw))
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
		tinsert(mw.buttons, fLibGUI.CreateActionButton(mw))
		mw.buttons[i]:SetFrameLevel(3)
	end

	--Add Loot button
	button = mw.buttons[1]
	button:SetText('Add Loot')
	button:GetFontString():SetFontObject(GameFontHighlightLarge)
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this) addon:Scan()  end)
	button:SetPoint('TOPRIGHT', mw, 'TOPRIGHT', -padding, -padding)
	
	--Announce items for bid
	button = mw.buttons[2]
	button:SetText('  >Items')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this) addon.AnnounceBidItems() end)
	button:SetPoint('TOPLEFT', mw.titles[2], 'BOTTOMLEFT', 0, -4)

	--Announce current winners button
	button = mw.buttons[3]
	button:SetText('  >Winners')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this) addon.AnnounceWinningBids()  end)
	button:SetPoint('TOPLEFT', mw.buttons[2], 'BOTTOMLEFT', 0, -4)
	
	--Info button
	button = mw.buttons[4]
	button:SetText('Info >')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this)
	end)
	button:SetPoint('TOPLEFT', mw.buttons[3], 'BOTTOMLEFT', 0,-padding)
	
	ui = fLibGUI.CreateLabel(mw)
	ui:SetText('  Id:')
	ui:SetPoint('TOPLEFT', mw.buttons[4], 'BOTTOMLEFT', 0, -padding)
	prevui = ui
	
	mw.title_id = fLibGUI.CreateLabel(mw)
	mw.title_id:SetPoint('TOPLEFT', ui, 'TOPRIGHT', padding, 0)
	
	ui = fLibGUI.CreateLabel(mw)
	ui:SetText('  Min Dkp:')
	ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -padding)
	prevui = ui
	
	ui = fLibGUI.CreateEditBox2(mw, '#')
	mw.eb_mindkp = ui
	ui:SetPoint('TOPLEFT', prevui, 'BOTTOMLEFT', 0, -padding)
	ui:SetFrameLevel(3)
	ui:SetWidth(60)
	ui:SetNumeric(true)
	ui:SetNumber(0)
	ui:SetScript('OnEnterPressed', function(this) 
		
		local items = BIDLIST.GetList()
		local iteminfo = items[mw_items.selecteditemindex]
		local obj = fRaid.Item.GetObjectById(iteminfo.id)
		if obj then
			obj.mindkp = this:GetNumber()
		end
		
		this:ClearFocus()
		this:SetNumber(obj.mindkp)
		
		--refresh row (just going to refresh entire table)
		mw:Refresh()
	end)
	
	--Clear button
	button = mw.buttons[5]
	button:SetText('Clear')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this) BIDLIST.Clear()  end)
	button:SetPoint('BOTTOMLEFT', mw, 'BOTTOMLEFT', padding+8, padding+8)
	
	--Close button
	button = mw.buttons[6]
	button:SetText('Close')
	button:SetWidth(button:GetTextWidth())
	button:SetHeight(button:GetTextHeight())
	button:SetScript('OnClick', function(this)
		mw:Toggle()
	end)
	button:SetPoint('BOTTOMRIGHT', mw, 'BOTTOMRIGHT', -padding-8, padding+8)
	
	--Scripts for mainwindow
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
	
	--Scripts for mw_items
	--drag and drop
	mw_items:SetScript('OnReceiveDrag', function(this)
		local infoType, id, link = GetCursorInfo()
		if infoType == 'item' then
			BIDLIST.AddItem(link)
			ClearCursor()
		end
	end)
	
	--Some functions for mainwindow
	function mw:SaveLocation()
		db.gui.x = self:GetLeft()
		db.gui.y = self:GetTop()
	end
	
	mw_items.selecteditemindex = 1 --click on an item to select which bids are showing in mw_bids
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
		BIDLIST.RefreshBids()
		
		mw_bids.startingindex= startingindex
		local items = BIDLIST.GetList()
		local iteminfo = items[mw_items.selecteditemindex]
		local bids = {}
		local bidinfo
		if iteminfo then
			bids = iteminfo.bids
		end
		
		if #bids > bidrowcount then
			--mw_bids.slider:SetMinMaxValues(1, BIDLIST.GetCount() - itemrowcount + 1)
			mw_bids.slider:SetMinMaxValues(1, #bids - bidrowcount + 1)
		else
			mw_bids.slider:Hide()
		end
		
		
		local z = 1 --current ui row
		for i = startingindex, startingindex + bidrowcount - 1 do
			bidinfo = bids[i]
			if bidinfo then
				--fill in this row's ui with data
				
				--1 Win check
				if bidinfo.winner then
					mw_bids.col1[z]:Show()
				else
					mw_bids.col1[z]:Hide()
				end
				
				--2 Name
				mw_bids.col2[z]:SetText(bidinfo.name)
				mw_bids.col2[z]:Show()
				mw_bids.col2[z].itemindex = i
				if bidinfo.awarded and bidinfo.charged then
					mw_bids.col2[z].highlightspecial:Show()
				else
					mw_bids.col2[z].highlightspecial:Hide()
				end
				
				--3 Rank
				--TODO: need to fill this column in...
				--mw_bids.col3[z]:SetText(fRaid.Player.GetRank(bidinfo.name))
				mw_bids.col3[z]:SetText(fRaid.Player.GetAttendanceFlag(bidinfo.name))
				mw_bids.col3[z]:Show()
				
				--4 Bid
				mw_bids.col4[z]:SetText(bidinfo.amount)
				mw_bids.col4[z]:Show()
				
				
				--5 Total
				mw_bids.col5[z]:SetText(bidinfo.total)
				mw_bids.col5[z]:Show()
				
				if bidinfo.amount > bidinfo.total then
					mw_bids.col4[z]:SetTextColor(1,0,0)
				else
					mw_bids.col4[z]:SetTextColor(
					mw_bids.col4[z].r,
					mw_bids.col4[z].g,
					mw_bids.col4[z].b,
					mw_bids.col4[z].a
					)
				end
				
				--6 Actual
				mw_bids.col6[z]:SetNumber(tonumber(bidinfo.actual))
				mw_bids.col6[z]:Show()
				mw_bids.col6[z]:ClearFocus()
				mw_bids.col6[z].itemindex = i
				
				--7 Award
				mw_bids.col7[z]:Show()
				mw_bids.col7[z].itemindex = i
				if not bidinfo.charged and not bidinfo.awarded  then
					mw_bids.col7[z]:SetText('Charge|Award')
				elseif bidinfo.charged and not bidinfo.awarded then
					mw_bids.col7[z]:SetText('Award')
				elseif not bidinfo.charged and bidinfo.awarded then
					mw_bids.col7[z]:SetText('Charge')
				else
					mw_bids.col7[z]:SetText('Done')
				end
			else
				--hide this row's ui
				mw_bids.col1[z]:Hide()
				mw_bids.col2[z]:Hide()
				mw_bids.col3[z]:Hide()
				mw_bids.col4[z]:Hide()
				mw_bids.col5[z]:Hide()
				mw_bids.col6[z]:Hide()
				mw_bids.col7[z]:Hide()
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
		ui = fLibGUI.CreateLabel(mw_items)
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
	
	ui = fLibGUI.CreateSeparator(mw_items)
	ui:SetWidth(mw_items:GetWidth()- 32)
	ui:SetPoint('TOPLEFT', mw_items.headers[1], 'BOTTOMLEFT', 0,-2)
	
	----Column 1: Item Numbers
	mw_items.col1 = {} --contains fontstrings
	for i = 1, itemrowcount do
		ui = fLibGUI.CreateLabel(mw_items)
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
		ui = fLibGUI.CreateActionButton(mw_items)
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
		highlight:SetTexture(0.96, 0.55, 0.73, 0.2)
		ui.highlightspecial = highlight
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(ui)
		highlight:Hide()
		
		ui.itemindex= 0
		ui:SetScript('OnEnter', function(this)
			this.highlight:Show()
			GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
			GameTooltip:SetPoint('TOPLEFT', mw, 'TOPRIGHT', 0, 0)
			GameTooltip:SetHyperlink('item:'..BIDLIST.GetList()[this.itemindex].id)
		end)
		ui:SetScript('OnLeave', function(this)
			this.highlight:Hide()
			GameTooltip:FadeOut()
		end)
		ui:SetScript('OnClick', function(this)
			mw_items.selecteditemindex = this.itemindex
			
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			local obj = fRaid.Item.GetObjectById(iteminfo.id, true)
			if obj then
				mw.title_id:SetText(iteminfo.id)
				mw.eb_mindkp:SetNumber(obj.mindkp)
			end
			
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

	slider:SetScript('OnValueChanged', function(this)
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
	----7 columns: Check, Name, Bid, Total, Rank, Actual, Award button
	mw_bids.headers = {} --contains fontstrings
	for i = 1,7 do
		ui = fLibGUI.CreateLabel(mw_bids)
		tinsert(mw_bids.headers, ui)
		ui:SetJustifyH('LEFT')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw.titles[4], 'BOTTOMLEFT', 0, -padding)
		else
			ui:SetPoint('TOPLEFT', mw_bids.headers[i-1], 'TOPRIGHT', 0,0)
		end
		ui:SetHeight(12)
	end
	
	mw_bids.headers[1]:SetText('Win')
	mw_bids.headers[1]:SetWidth(30)
	mw_bids.headers[2]:SetText('Name')
	mw_bids.headers[2]:SetWidth(85)
	mw_bids.headers[3]:SetText('Rank')
	mw_bids.headers[3]:SetWidth(50)
	mw_bids.headers[4]:SetText('Bid')
	mw_bids.headers[4]:SetWidth(50)
	mw_bids.headers[5]:SetText('Total')
	mw_bids.headers[5]:SetWidth(50)
	mw_bids.headers[6]:SetText('Actual')
	mw_bids.headers[6]:SetWidth(50)
	mw_bids.headers[7]:SetText('Action')
	mw_bids.headers[7]:SetWidth(95)
	
	tex = fLibGUI.CreateSeparator(mw_bids)
	tex:SetWidth(mw_bids:GetWidth()- 32)
	tex:SetPoint('TOPLEFT', mw_bids.headers[1], 'BOTTOMLEFT', 0,-2)
	
	----Column 1: Checks
	mw_bids.col1 = {} --contains buttons
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateCheck(mw_bids)
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
		ui = fLibGUI.CreateActionButton(mw_bids)
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
		
		local highlight = ui:CreateTexture(nil, "BACKGROUND")
		highlight:SetTexture(0.96, 0.55, 0.73, 0.2)
		ui.highlightspecial = highlight
		highlight:SetBlendMode("ADD")
		highlight:SetAllPoints(ui)
		highlight:Hide()
		
		ui.itemindex= 0
		ui:SetScript('OnClick', function(this)
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bids = iteminfo.bids
				if bids[this.itemindex].winner then
					if bids[this.itemindex].awarded or bids[this.itemindex].charged then
						fRaid:Print('Cannot set this bid to win because bidder has already been charged and/or awarded loot.')
					else
						bids[this.itemindex].winner = false
					end
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
	
	----Column 3: Rank
	mw_bids.col3 = {} --contains fontstrings
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateLabel(mw_bids)
		tinsert(mw_bids.col3, ui)
		ui:SetText('11')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[3], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[3], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col3[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col3[i-1], 'BOTTOMRIGHT', 0, -4)
		end
	end
	
	----Column 4: Amount
	mw_bids.col4 = {} --contains fontstrings
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateLabel(mw_bids)
		tinsert(mw_bids.col4, ui)
		ui:SetText('11')
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[4], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[4], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col4[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col4[i-1], 'BOTTOMRIGHT', 0, -4)
		end
		
		ui.r,ui.g,ui.b,ui.a = ui:GetTextColor()
	end
	
	----Column 5: Total
	mw_bids.col5 = {} --contains fontstrings
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateLabel(mw_bids)
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
	
	
	
	----Column 6: Actual
	mw_bids.col6 = {} --contains editboxes
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateEditBox2(mw_bids, 'dkp')
		tinsert(mw_bids.col6, ui)
		
		ui:SetWidth(100)
		ui:SetNumeric(true)			
		
		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[6], 'BOTTOMLEFT', 0, -2)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[6], 'BOTTOMRIGHT', 0, -2)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col6[i-1], 'BOTTOMLEFT', 0, -2)
			ui:SetPoint('TOPRIGHT', mw_bids.col6[i-1], 'BOTTOMRIGHT', 0, -2)
		end
		
		ui.itemindex= 0
		ui:SetScript('OnEnterPressed', function(this)
			--save new value
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bid = iteminfo.bids[this.itemindex]
				bid.actual = this:GetNumber()
				bid.ismanualedit = true
				--this:SetNumber(bid.actual)
				addon.RefreshGUI()
			end
			this:ClearFocus()
		end)
		ui:SetScript('OnEscapePressed', function(this)
			--restore old value
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bid = iteminfo.bids[this.itemindex]
				this:SetNumber(tonumber(bid.actual))
			end
			this:ClearFocus()
		end)
		ui:SetScript('OnEditFocusGained', function(this)
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bid = iteminfo.bids[this.itemindex]
				if bid.awarded then
					this:ClearFocus()
					return
				end
			end
			this:HighlightText()
		end)
	end


	----Column 7: Action
	mw_bids.col7 = {} --contains buttons
	for i = 1, bidrowcount do
		ui = fLibGUI.CreateActionButton(mw_bids)
		tinsert(mw_bids.col7, ui)
		ui:GetFontString():SetAllPoints()
		ui:GetFontString():SetJustifyH('LEFT')
		ui:SetText('Charge|Award')
		ui:SetHeight(ui:GetTextHeight())

		if i == 1 then
			ui:SetPoint('TOPLEFT', mw_bids.headers[7], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.headers[7], 'BOTTOMRIGHT', 0, -4)
		else
			ui:SetPoint('TOPLEFT', mw_bids.col7[i-1], 'BOTTOMLEFT', 0, -4)
			ui:SetPoint('TOPRIGHT', mw_bids.col7[i-1], 'BOTTOMRIGHT', 0, -4)
		end
		
		ui.itemindex= 0
		ui:SetScript('OnClick', function(this)
			local items = BIDLIST.GetList()
			local iteminfo = items[mw_items.selecteditemindex]
			if iteminfo then
				local bids = iteminfo.bids
				local bidinfo = bids[this.itemindex]
				
				if bidinfo.winner then
					--charge dkp if they haven't been charged
					--add to winnerlist
					fRaidBid.ChargeDKP(iteminfo, bidinfo)
					
					--try to award loot if they haven't been awarded and loot window is open
					--set a global activebid to be used by LOOT_SLOT_CLEARED event  handler
					if not bidinfo.awarded and GetNumLootItems() > 0 then
						print('attempting to loot')
						local slot = 0
						--saving info to be used by LOOT_SLOT_CLEARED
						db.activeiteminfo = iteminfo
						db.activebidinfo = bidinfo
						db.activelootlinks = {}
						for k = 1, GetNumLootItems() do
							tinsert(db.activelootlinks, GetLootSlotLink(k))
							if GetLootSlotLink(k) == iteminfo.link then
								slot = k
							end
						end
						
						--find idx of master loot candidate
						local candidateindex = 0
						local candidatename
						for k = 1, 40 do
							candidatename = GetMasterLootCandidate(k)
							if candidatename and strlower(candidatename) == strlower(bidinfo.name) then
								candidateindex = k
								break
							end
						end
						
						--Master loot item to bidder
						print('slot=' .. slot .. ',candidate='..candidateindex)
						if slot > 0 and candidateindex > 0 then
							fRaid:Print('Looting ' .. iteminfo.link .. ' to ' .. bidinfo.name .. '.')
							GiveMasterLoot(slot, candidateindex)
						end
					end
				else
					fRaid:Print(bidinfo.name .. ' is not set to win.  Click on their name to set them as a winner.')
				end
						
				mw:LoadBidRows(mw_bids.startingindex)
			end
		end)
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

	slider:SetScript('OnValueChanged', function(this)
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
