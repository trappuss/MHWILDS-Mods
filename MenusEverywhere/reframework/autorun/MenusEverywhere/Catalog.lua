-- What MenusEverywhere can add, as data.
--
-- Every id here is a *fixed* menu id (app.Menu.ID_Fixed), the stable id the game's own
-- data files use, so the catalog survives game updates that reshuffle the runtime enum.
--
-- A group becomes ONE folder row in a menu, so adding a whole facility costs a single line.
--   parent  : fixed id of the row. Pool ids are unused blank menu ids that get retitled.
--   pool    : used in place of parent, an index into PoolIds
--   title   : { facility = "TYPE_NAME" } names the folder after that facility menu, in the
--             game's own localized text ("Melding Pot"). nil keeps the parent id's title.
--   items   : { fixedId, exec } with exec one of Catalog.Exec (how the pause menu behaves on pick)
--   tab     : default pause menu tab (app.StartMenu.CATEGORY name) or "OFF"
--   tent    : facility category the folder goes under in camp menus, nil = not offered there
--   handler : same, for menus that lack what a camp already has (the handler's menu)
--   label   : name in the settings window (the menus themselves show the game's text)

local public = {}

-- What the menu does when an entry is picked: stay, step aside and come back after, or
-- close for good.
public.Exec = { NONE = 0, CLOSE = 1, SHUTDOWN = 2 }
local NONE, CLOSE, SHUTDOWN = public.Exec.NONE, public.Exec.CLOSE, public.Exec.SHUTDOWN

-- Blank, unreferenced menu ids. Safe to retitle and use as folder rows. The first is spare.
public.PoolIds = { 77, 78, 79, 80, 153, 41, 11 }

public.Tabs = {
	{ key = "OFF",           label = "Off" },
	{ key = "ITEM_EQUIP",    label = "Items & Equipment" },
	{ key = "QUEST",         label = "Quests" },
	{ key = "INFOMATION",    label = "Info" },
	{ key = "COMMUNICATION", label = "Communication" },
	{ key = "SYSTEM",        label = "System" },
	{ key = "DEBUG",         label = "Extra tab (far right)" },
}

-- The pause menu has no tab for the DEBUG category, the only spare one. A tab is appended
-- while a folder uses it, named by the player or else with the game's own text for `title`.
public.ExtraTab = { key = "DEBUG", title = { facility = "TENT" } }

public.Groups = {
	{
		-- must stay under the game's own "Transfer Items" row: the pouch entries only work there
		key = "item_box", label = "Item Box (Transfer Items)", parent = 97,
		tab = "ITEM_EQUIP", handler = "ITEM",
		-- Coating Pouch (167) is left out: the pause menu already has it under Check Pouches,
		-- and the game returns to whichever copy it finds first.
		items = { { 44, CLOSE }, { 47, CLOSE }, { 48, CLOSE }, { 172, CLOSE }, { 221, CLOSE } },
	},
	{
		key = "equipment", label = "Equipment", parent = 218,
		tab = "ITEM_EQUIP", handler = "EQUIP",
		items = { { 49, CLOSE }, { 194, CLOSE }, { 175, CLOSE }, { 169, CLOSE }, { 176, CLOSE }, { 216, CLOSE }, { 217, CLOSE }, { 219, CLOSE } },
	},
	{
		-- pause menu only: in a camp menu the forge screens open behind the menu, cannot be
		-- used, and most entries do nothing, whichever exec is used
		key = "smithy", label = "Smithy", parent = 145,
		tab = "ITEM_EQUIP",
		items = { { 109, SHUTDOWN }, { 110, CLOSE }, { 289, CLOSE }, { 290, CLOSE }, { 112, CLOSE }, { 226, CLOSE }, { 154, CLOSE }, { 170, CLOSE }, { 213, CLOSE }, { 214, CLOSE } },
	},
	{
		key = "artian", label = "Artian Weapons", parent = 174,
		tab = "ITEM_EQUIP",
		items = { { 173, CLOSE }, { 192, CLOSE }, { 288, CLOSE }, { 42, CLOSE }, { 193, CLOSE } },
	},
	{
		key = "provisions", label = "Provisions Stockpile (shop)", parent = 32,
		tab = "ITEM_EQUIP", tent = "ITEM",
		items = { { 82, CLOSE }, { 83, CLOSE }, { 272, CLOSE } },
	},
	{
		key = "melding", label = "Melding Pot", pool = 2, title = { facility = "MACA_ALCHEMY" },
		tab = "INFOMATION", tent = "ITEM",
		items = { { 201, CLOSE }, { 202, CLOSE }, { 203, CLOSE }, { 280, CLOSE }, { 281, CLOSE } },
	},
	{
		key = "foundry", label = "Smelting Foundry", pool = 3, title = { facility = "WORK_SHOP_SMALL" },
		tab = "INFOMATION", tent = "ITEM",
		items = { { 204, CLOSE }, { 205, CLOSE }, { 29, CLOSE }, { 30, CLOSE } },
	},
	{
		key = "trade", label = "Village Trade", pool = 4, title = { facility = "VILLAGE_HUB" },
		tab = "INFOMATION", tent = "ITEM",
		items = { { 209, CLOSE }, { 210, CLOSE }, { 206, CLOSE } },
	},
	{
		key = "support", label = "Support Desk & Ship", pool = 5, title = { facility = "SUPPORT_CAT_LEADER" },
		tab = "SYSTEM", tent = "ITEM",
		-- Check Endemic Life (268) is left out: away from the ship it fades to black and opens nothing
		items = { { 151, CLOSE }, { 152, CLOSE }, { 231, CLOSE }, { 230, CLOSE }, { 251, CLOSE }, { 211, SHUTDOWN } },
	},
	{
		key = "camp", label = "Camp (Rest, Quests, Appearance)", pool = 6, title = { facility = "TENT" },
		tab = "QUEST", handler = "QUEST",
		items = { { 88, CLOSE }, { 62, CLOSE }, { 228, CLOSE }, { 61, CLOSE }, { 271, CLOSE }, { 144, CLOSE }, { 255, CLOSE }, { 270, CLOSE }, { 269, CLOSE }, { 149, CLOSE }, { 150, CLOSE } },
	},
	{
		key = "lobby", label = "Lobby", pool = 7, title = { facility = "SELECT_LOBBY" },
		tab = "COMMUNICATION",
		items = { { 165, NONE }, { 155, NONE }, { 159, NONE }, { 161, CLOSE }, { 162, CLOSE }, { 163, CLOSE }, { 164, NONE } },
	},
	{
		key = "popup_manage", label = "Manage Pop-up Camps", parent = 180,
		tab = "INFOMATION", tent = "ITEM",
		items = { { 181, CLOSE }, { 182, CLOSE }, { 183, CLOSE }, { 184, CLOSE }, { 185, CLOSE } },
	},
	{
		key = "popup_edit", label = "Edit Pop-up Camps", parent = 186,
		tab = "INFOMATION", tent = "ITEM",
		items = { { 187, CLOSE }, { 188, CLOSE }, { 189, CLOSE }, { 190, CLOSE }, { 191, CLOSE } },
	},
}

-- Facility menus (app.FacilityMenu.TYPE) that can be extended.
--   full    : can be topped up with everything the base camp tent offers
--   handler : also offers the groups a camp has no need for (Item Box, Equipment, Camp)
--   preset  : label of the FacilityPresets entry a fresh config starts on
--   note    : shown under the folder list in the settings window
public.FullCampSource = "TENT"
public.Surfaces = {
	{ key = "TENT",           label = "Main tent menu (base camp)", preset = "Everything" },
	{ key = "SIMPLE_TENT",    label = "Pop-up camp menu",           preset = "Everything", full = true },
	{ key = "TEMPORARY_TENT", label = "Makeshift camp menu",        preset = "Everything", full = true },
	{ key = "QUEST_COUNTER",  label = "Handler menu (Alma)",        preset = "Vanilla", full = true, handler = true,
		note = "The change equipment screens cannot be opened from this menu." },
}

-- Left out of the handler's menu, folders and camp rows alike. For the equipment screens
-- the game closes that menu and then opens nothing, and both ways of opening the screen
-- from a script failed: the Smithy's request gives a screen that cannot be backed out
-- of, and the pause menu's launcher crashes the game there.
public.HandlerBlocked = { [49] = true, [169] = true, [175] = true, [176] = true }

-- Facility category whose tab collects every folder when "own tab" is on. No camp or
-- handler menu uses it, so the tab holds nothing but our folders.
public.OwnTabCategory = "PROCESSING"

-- Presets set every option of their menu. "Custom" is not listed: it is the player's own
-- setup, kept by the config.
public.CustomPreset = "Custom"
public.DefaultStartPreset = "Everything"
public.StartPresets = {
	{ label = "Everything", start = "default" },
	{ label = "Essentials", start = { item_box = "ITEM_EQUIP", equipment = "ITEM_EQUIP", smithy = "ITEM_EQUIP", camp = "QUEST" } },
	{ label = "Vanilla", start = {} },
}

-- folders: true = every folder offered there, false = none, table = just those.
public.FacilityPresets = {
	{ label = "Everything", folders = true, full = true },
	{ label = "Essentials", folders = { item_box = true, equipment = true, provisions = true }, full = false },
	{ label = "Vanilla", folders = false, full = false },
}

function public.parentId(group)
	return group.parent or public.PoolIds[group.pool]
end

-- Fixed ids that must not appear on a surface.
function public.blocked(surface)
	return surface.handler and public.HandlerBlocked or nil
end

-- Facility category name a group's folder uses on a surface, nil when not offered there.
function public.surfaceCategory(group, surface)
	return group.tent or (surface.handler and group.handler) or nil
end

return public
