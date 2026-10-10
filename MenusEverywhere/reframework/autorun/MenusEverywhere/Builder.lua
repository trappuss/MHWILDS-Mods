-- Rewrites the game's in-memory menu lists from the catalog and the player's config.
-- Nothing on disk is touched; a restart with the mod removed is fully vanilla.

local catalog = require("MenusEverywhere.Catalog")
local config = require("MenusEverywhere.Config")
local game = require("MenusEverywhere.Game")

local public = {}
local this = {
	startArray = nil,  -- address of the Values array we last installed
	facilityArrays = {},
	status = "waiting for game data",
	tabCounts = {},
	startRows = {},
	extraTab = false,  -- whether a folder sits in the extra pause menu tab
	extraTabText = nil, -- the game's text on that tab
}

-- Rows we own in a menu: stripped before every rebuild so applying is idempotent,
-- including after a REFramework script reset. A facility menu only receives the groups
-- offered there, so only those parents are ours in it; the same id can be a vanilla row
-- elsewhere ("Transfer Items" in every camp).
local ownedStart, ownedFacility, groupByKey = {}, {}, {}
for _, id in ipairs(catalog.PoolIds) do ownedStart[id] = true end
for _, group in ipairs(catalog.Groups) do
	groupByKey[group.key] = group
	ownedStart[catalog.parentId(group)] = true
end
for _, surface in ipairs(catalog.Surfaces) do
	local owned = {}
	for _, id in ipairs(catalog.PoolIds) do owned[id] = true end
	for _, group in ipairs(catalog.Groups) do
		if catalog.surfaceCategory(group, surface) then owned[catalog.parentId(group)] = true end
	end
	ownedFacility[surface.key] = owned
end

local function orderedGroups()
	local groups = {}
	for _, key in ipairs(config.order()) do
		groups[#groups + 1] = groupByKey[key]
	end
	return groups
end

local function shownItems(group, blocked)
	local items = {}
	for _, item in ipairs(group.items) do
		-- ids missing from this game version have no menu data; skip instead of showing a dead row
		if config.itemShown(group.key, item[1]) and game.menuData(item[1]) and not (blocked and blocked[item[1]]) then
			items[#items + 1] = item
		end
	end
	return items
end

local function applyTitle(group)
	if not group.title then return end
	local target = game.menuData(catalog.parentId(group))
	local source = game.facility(group.title.facility)
	if target and source then
		target:set_field("_Title", source:get_Title())
	end
end

local function buildFolder(group, dataType, itemType, subField, blocked)
	local items = shownItems(group, blocked)
	if #items == 0 then return nil end
	local subs = {}
	for _, item in ipairs(items) do
		local sub = game.newItem(itemType, item[1], item[2])
		sub:onLoad()
		subs[#subs + 1] = sub
	end
	local folder = game.newItem(dataType, catalog.parentId(group), catalog.Exec.NONE)
	folder:set_field(subField, game.toArray(itemType, subs))
	applyTitle(group)
	return folder
end

local function joined(first, second)
	local list = {}
	for _, value in ipairs(first) do list[#list + 1] = value end
	for _, value in ipairs(second) do list[#list + 1] = value end
	return list
end

local function applyStart()
	local menu = game.menuSetting()
	local startData = menu and menu:get_StartMenuData()
	if not startData then return false end

	local enabled = config.enabled()
	local kept, added = {}, {}
	local counts, rows = {}, {}
	for _, entry in ipairs(game.toList(startData:get_field("Values"))) do
		local fixedId = entry:get_field("_MenuId")
		if not ownedStart[fixedId] then
			kept[#kept + 1] = entry
			-- The game never shows debug rows, so flagging a row as one hides it. Only rows
			-- the player touched are written, which leaves the real debug rows alone.
			local hidden = config.rowHidden(fixedId)
			if hidden ~= nil then
				entry:set_field("_IsDebugItem", hidden and enabled)
			end
			local tab = entry:get_Category()
			if hidden ~= nil or not entry:get_field("_IsDebugItem") then
				rows[#rows + 1] = { fixedId = fixedId, tab = tab, hidden = hidden == true }
			end
			if not entry:get_field("_IsDebugItem") then
				counts[tab] = (counts[tab] or 0) + 1
			end
		end
	end

	local extraTab = false
	if enabled then
		for _, group in ipairs(orderedGroups()) do
			local tabKey = config.startTab(group.key)
			local tabFixed = game.enum("app.StartMenu.CATEGORY_Fixed", tabKey)
			if tabKey ~= "OFF" and tabFixed ~= nil then
				local folder = buildFolder(group, game.START_DATA, game.START_ITEM, "_SubItems")
				if folder then
					local category = sdk.create_instance("app.StartMenu.CATEGORY_Serializable"):add_ref()
					category:set_field("_Value", tabFixed)
					folder:set_field("_Category", category)
					folder:onLoad()
					added[#added + 1] = folder
					extraTab = extraTab or tabKey == catalog.ExtraTab.key
					local tab = folder:get_Category()
					counts[tab] = (counts[tab] or 0) + 1
				end
			end
		end
	end

	local values = config.startFirst() and joined(added, kept) or joined(kept, added)
	local array = game.toArray(game.START_DATA, values)
	startData:set_field("Values", array)
	menu:createStartMenuDataTable(game.setting())
	this.startArray = array:get_address()
	this.extraTab = extraTab
	local tabId = game.enum("app.StartMenu.CATEGORY", catalog.ExtraTab.key)
	local titleSource = game.facility(catalog.ExtraTab.title.facility)
	if titleSource and tabId ~= nil then
		game.setExtraTab(extraTab, tabId, titleSource:get_Title())
		this.extraTabText = game.message(titleSource:get_Title())
	end

	this.tabCounts, this.startRows = {}, {}
	for _, tab in ipairs(catalog.Tabs) do
		local id = game.enum("app.StartMenu.CATEGORY", tab.key)
		if id ~= nil then
			this.tabCounts[tab.key] = counts[id] or 0
			for _, row in ipairs(rows) do
				if row.tab == id then
					row.tabKey = tab.key
					this.startRows[#this.startRows + 1] = row
				end
			end
		end
	end
	return true
end

-- An existing _Category object for a facility category, borrowed from any vanilla row.
local function facilityCategory(categoryName)
	this.categories = this.categories or {}
	if this.categories[categoryName] then return this.categories[categoryName] end
	local wanted = game.enum("app.FacilityMenu.CATEGORY", categoryName)
	local manager = game.facilityManagerData()
	if wanted == nil or not manager then return nil end
	for _, facility in ipairs(game.toList(manager:get_field("Values"))) do
		local menuSetting = facility:get_MenuSetting()
		for _, entry in ipairs(game.toList(menuSetting and menuSetting:get_field("Values"))) do
			if entry:get_Category() == wanted then
				this.categories[categoryName] = entry:get_field("_Category")
				return this.categories[categoryName]
			end
		end
	end
	return nil
end

local function applyFacility(surface, sourceEntries)
	local facility = game.facility(surface.key)
	local menuSetting = facility and facility:get_MenuSetting()
	local settings = config.surface(surface.key)
	if not menuSetting or not settings then return end

	-- rows copied from the base camp are the very same objects, so they are recognisable
	local borrowed = {}
	if surface.full then
		for _, entry in ipairs(sourceEntries) do borrowed[entry:get_address()] = true end
	end

	local owned = ownedFacility[surface.key]
	local blocked = catalog.blocked(surface)
	local kept, added, present = {}, {}, {}
	for _, entry in ipairs(game.toList(menuSetting:get_field("Values"))) do
		if not owned[entry:get_field("_MenuId")] and not borrowed[entry:get_address()] then
			kept[#kept + 1] = entry
			present[entry:get_field("_MenuId")] = true
		end
	end

	if config.enabled() then
		if surface.full and settings.full then
			for _, entry in ipairs(sourceEntries) do
				local fixedId = entry:get_field("_MenuId")
				if not present[fixedId] and not (blocked and blocked[fixedId]) then
					kept[#kept + 1] = entry
					present[fixedId] = true
				end
			end
		end
		for _, group in ipairs(orderedGroups()) do
			local categoryName = catalog.surfaceCategory(group, surface)
			-- a row the menu already has under the same id would only be duplicated
			if categoryName and settings.folders[group.key] and not present[catalog.parentId(group)] then
				local category = facilityCategory(settings.ownTab and catalog.OwnTabCategory or categoryName)
				local folder = category and buildFolder(group, game.FACILITY_DATA, game.FACILITY_ITEM, "_SubMenus", blocked)
				if folder then
					folder:set_field("_Category", category)
					folder:onLoad()
					added[#added + 1] = folder
				end
			end
		end
	end

	local values = settings.first and joined(added, kept) or joined(kept, added)
	local array = game.toArray(game.FACILITY_DATA, values)
	menuSetting:set_field("Values", array)
	this.facilityArrays[surface.key] = array:get_address()
end

local function applyFacilities()
	local source = game.facility(catalog.FullCampSource)
	local sourceSetting = source and source:get_MenuSetting()
	if not sourceSetting then return false end
	local sourceEntries = {}
	for _, entry in ipairs(game.toList(sourceSetting:get_field("Values"))) do
		if not ownedFacility[catalog.FullCampSource][entry:get_field("_MenuId")] then
			sourceEntries[#sourceEntries + 1] = entry
		end
	end
	for _, surface in ipairs(catalog.Surfaces) do
		applyFacility(surface, sourceEntries)
	end
	return true
end

-- Rebuilds every menu. Returns false while the game data is not loaded yet.
function public.apply()
	local ok, result = pcall(function()
		return applyStart() and applyFacilities()
	end)
	if not ok then
		this.status = "error: " .. tostring(result)
		log.error("[MenusEverywhere] " .. tostring(result))
		return true
	end
	if result then this.status = "active" end
	return result
end

-- True when the game replaced one of the lists behind our back (data reload).
function public.isStale()
	local ok, stale = pcall(function()
		local menu = game.menuSetting()
		local startData = menu and menu:get_StartMenuData()
		if not startData then return false end
		if startData:get_field("Values"):get_address() ~= this.startArray then return true end
		if game.extraTabStale(this.extraTab) then return true end
		for surfaceKey, address in pairs(this.facilityArrays) do
			local facility = game.facility(surfaceKey)
			local menuSetting = facility and facility:get_MenuSetting()
			if menuSetting and menuSetting:get_field("Values"):get_address() ~= address then return true end
		end
		return false
	end)
	return ok and stale
end

-- Once per frame: keeps the player's name on the extra pause menu tab. The game writes
-- its own text whenever the tab is selected.
function public.update()
	local name = config.extraTabName()
	if this.extraTab and this.extraTabText and name ~= "" then
		pcall(game.renameTab, this.extraTabText, name)
	end
end

function public.status()
	return this.status
end

-- Rows per pause menu tab after the last rebuild (hidden rows excluded).
function public.tabCount(tabKey)
	return this.tabCounts[tabKey] or 0
end

-- The game's own pause menu rows as of the last rebuild: { fixedId, tabKey, hidden }.
function public.startRows()
	return this.startRows
end

return public
