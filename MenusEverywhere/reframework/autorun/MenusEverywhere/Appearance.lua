-- Lets the camp's Change Appearance screen edit everything.
--
-- The appearance screen holds one option list per way of opening it. From a camp it shows
-- the short "adjust" lists; the lists of the full re-edit sit next to them. While the
-- option is on, the adjust lists are replaced with the full ones as the screen opens, so
-- the rest of the camp flow (opening, saving, coming back) stays the game's own.
--
-- The tabs next to the option list (colors, saved designs) are chosen by the way the
-- screen was opened, not by the list. While they are set up, the screen is made to look
-- like the full re-edit of the character being edited.

local config = require("MenusEverywhere.Config")

local public = {}
local this = {
	registered = false,
	originals = {}, -- the game's adjust lists, by field name, to put back when switched off
	tabsOwner = nil, -- screen whose scene type is changed for the length of a tab setup
}

local SCREEN = "app.GUI010300"
local OPTION_LIST = "app.CharaEditGUIItemSelect"
local SCENE_FIELD = "_SceneType"
local ADJUST_SCENE = 1                        -- app.GUI010300.SCENE_TYPE.HUNTER_PALICO_ADJUST
local FULL_SCENE = { [0] = 2, [1] = 3 }       -- EDIT_CHARA_TYPE HUNTER, OTOMO -> SCENE_TYPE HUNTER, PALICO
-- adjust list -> full list, for the hunter and the Palico
local LISTS = {
	_HunterAdjustEditItemData = "_HunterTicketEditItemData",
	_OtomoAdjustEditItemData = "_OtomoTicketEditItemData",
}

local function swap(screen)
	local wantFull = config.enabled() and config.fullAppearance()
	for adjust, full in pairs(LISTS) do
		local current = screen:get_field(adjust)
		local fullList = screen:get_field(full)
		if current and fullList then
			if not this.originals[adjust] and current:get_address() ~= fullList:get_address() then
				this.originals[adjust] = current:add_ref()
			end
			local wanted = wantFull and fullList or this.originals[adjust]
			if wanted and wanted:get_address() ~= current:get_address() then
				screen:set_field(adjust, wanted)
			end
		end
	end
end

local function tabsBegin(optionList)
	local owner = optionList:get__MyOwner()
	local full = FULL_SCENE[owner:get_field("_EditCharaType")]
	if config.enabled() and config.fullAppearance() and full and owner:get_field(SCENE_FIELD) == ADJUST_SCENE then
		owner:set_field(SCENE_FIELD, full)
		this.tabsOwner = owner:add_ref()
	end
end

local function tabsEnd()
	if this.tabsOwner then
		this.tabsOwner:set_field(SCENE_FIELD, ADJUST_SCENE)
		this.tabsOwner = nil
	end
end

-- Hooks the screen once. Returns false while the game type is not available.
function public.register()
	if this.registered then return true end
	local td = sdk.find_type_definition(SCREEN)
	local open = td and td:get_method("onOpen")
	local listType = sdk.find_type_definition(OPTION_LIST)
	local setupTabs = listType and listType:get_method("setupTabs")
	if not (open and setupTabs) then return false end
	sdk.hook(setupTabs, function(args)
		pcall(tabsBegin, sdk.to_managed_object(args[2]))
	end, function(retval)
		pcall(tabsEnd)
		return retval
	end)
	sdk.hook(open, function(args)
		pcall(swap, sdk.to_managed_object(args[2]))
	end, nil)
	this.registered = true
	return true
end

return public
