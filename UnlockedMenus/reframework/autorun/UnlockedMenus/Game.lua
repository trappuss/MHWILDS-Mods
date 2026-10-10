-- Thin wrappers around the game's menu data, everything resolved by name at runtime.

local public = {}
local this = { enums = {} }

local START_DATA = "app.user_data.StartMenuData.Data"
local START_ITEM = "app.user_data.StartMenuData.ItemBase"
local FACILITY_DATA = "app.user_data.FacilityMenuData.cData"
local FACILITY_ITEM = "app.user_data.FacilityMenuData.cBaseData"

public.START_DATA = START_DATA
public.START_ITEM = START_ITEM
public.FACILITY_DATA = FACILITY_DATA
public.FACILITY_ITEM = FACILITY_ITEM

function public.enum(typeName, name)
	local cache = this.enums[typeName]
	if not cache then
		cache = {}
		local td = sdk.find_type_definition(typeName)
		if td then
			for _, field in ipairs(td:get_fields()) do
				if field:is_static() then cache[field:get_name()] = field:get_data(nil) end
			end
		end
		this.enums[typeName] = cache
	end
	return cache[name]
end

-- app.user_data.VariousDataManagerSetting, nil until the game has loaded it.
function public.setting()
	local manager = sdk.get_managed_singleton("app.VariousDataManager")
	return manager and manager:get_Setting()
end

function public.menuSetting()
	local setting = public.setting()
	return setting and setting:get_Menu()
end

function public.facilityManagerData()
	local setting = public.setting()
	local facility = setting and setting:get_field("_FacilitySetting")
	return facility and facility:get_field("_FacilityMenuManagerData")
end

-- app.user_data.FacilityMenuManagerData.cData for a facility type name such as "TENT".
function public.facility(typeName)
	local manager = public.facilityManagerData()
	local typeId = public.enum("app.FacilityMenu.TYPE", typeName)
	if not manager or typeId == nil then return nil end
	return manager:call("getData(app.FacilityMenu.TYPE)", typeId)
end

function public.newItem(typeName, fixedId, exec)
	local item = sdk.create_instance(typeName):add_ref()
	item:set_field("_MenuId", fixedId)
	item:set_field("_ExecuteType", exec)
	return item
end

-- Runtime app.Menu.ID for a fixed id, converted by the game's own onLoad.
function public.runtimeId(fixedId)
	this.runtimeIds = this.runtimeIds or {}
	local id = this.runtimeIds[fixedId]
	if id == nil then
		local item = public.newItem(START_ITEM, fixedId, 0)
		item:onLoad()
		id = item:get_MenuId()
		this.runtimeIds[fixedId] = id
	end
	return id
end

-- app.user_data.MenuData.cData (title, unlock conditions) for a fixed id.
function public.menuData(fixedId)
	local menu = public.menuSetting()
	local menuData = menu and menu:get_MenuData()
	return menuData and menuData:call("getData(app.Menu.ID)", public.runtimeId(fixedId))
end

function public.message(guid)
	this.getMessage = this.getMessage or sdk.find_type_definition("via.gui.message"):get_method("get(System.Guid)")
	return this.getMessage:call(nil, guid)
end

-- Localized title of a fixed menu id, "" when it has none.
function public.title(fixedId)
	local ok, text = pcall(function()
		local entry = public.menuData(fixedId)
		return entry and public.message(entry:get_Title()) or ""
	end)
	return ok and text or ""
end

-- Every live component of a type in the current scene.
function public.components(typeName)
	local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"),
		sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
	return public.toList(scene and scene:call("findComponents(System.Type)", sdk.typeof(typeName)))
end

local PAUSE_MENU = "app.GUI030000"
local VANILLA_TABS = 8
local ICON_FACILITY = 2     -- app.cGUIStartMenuCategory icon category
local ICON_SOURCE_TAB = 4   -- the extra tab borrows the Items & Equipment tab's icon

-- Adds or removes an extra pause menu tab for a category that has none. The tab list is
-- only read when the menu opens, so this takes effect on the next open.
function public.setExtraTab(wanted, categoryId, title)
	this.pauseMenus = {}
	for _, gui in ipairs(public.components(PAUSE_MENU)) do
		this.pauseMenus[#this.pauseMenus + 1] = gui:add_ref()
		local tabs = public.toList(gui:get_field("CategoryDataTable"))
		if wanted and #tabs == VANILLA_TABS then
			local tab = sdk.create_instance("app.cGUIStartMenuCategory"):add_ref()
			tab:call(".ctor")
			tab:set_MyOwner(gui)
			tab:set_Id(categoryId)
			tab:set_IconCategory(ICON_FACILITY)
			tab:set_IconType(tabs[ICON_SOURCE_TAB]:get_IconType())
			tab:set_Text(title)
			tabs[#tabs + 1] = tab
			gui:set_field("CategoryDataTable", public.toArray("app.cGUIStartMenuCategory", tabs))
		elseif not wanted and #tabs > VANILLA_TABS then
			tabs[#tabs] = nil
			gui:set_field("CategoryDataTable", public.toArray("app.cGUIStartMenuCategory", tabs))
		end
	end
end

-- Replaces the pause menu's tab title with `name` whenever it reads `gameText`. The
-- title control is the reliable signal: the menu's own "open tab" fields do not follow
-- the selection.
function public.renameTab(gameText, name)
	for _, gui in ipairs(this.pauseMenus or {}) do
		local text = gui:get__TextTabName()
		if text and text:get_Message() == gameText then text:set_Message(name) end
	end
end

-- True when a pause menu's tab list does not match what was asked for, as happens when
-- the game recreates the menu.
function public.extraTabStale(wanted)
	for _, gui in ipairs(public.components(PAUSE_MENU)) do
		local tabs = gui:get_field("CategoryDataTable")
		local size = tabs and tabs:get_size() or 0
		if size >= VANILLA_TABS and (size > VANILLA_TABS) ~= wanted then return true end
	end
	return false
end

-- Emergency exit for a menu that stopped taking input: asks the game to close the camp
-- menu and the pause menu. Returns a line per step for the status text.
function public.closeMenus()
	local report = {}
	local function step(label, action)
		local ok, err = pcall(action)
		report[#report + 1] = label .. (ok and " ok" or (" failed: " .. tostring(err)))
	end
	local manager = sdk.get_managed_singleton("app.GUIManager")
	step("camp menu", function() manager:closeCampMenu() end)
	step("facility menu", function()
		for _, menu in ipairs(public.components("app.GUI090001")) do menu:closeRequest() end
	end)
	step("pause menu", function() manager:closeStartMenuAll() end)
	return table.concat(report, ", ")
end

function public.toArray(typeName, list)
	local array = sdk.create_managed_array(typeName, #list):add_ref()
	for i, element in ipairs(list) do
		array:set_Item(i - 1, element)
	end
	return array
end

function public.toList(array)
	local list = {}
	if array then
		for i = 0, array:get_size() - 1 do
			list[#list + 1] = array:get_element(i)
		end
	end
	return list
end

return public
