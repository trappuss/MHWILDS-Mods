-- The settings window, under REFramework > Script Generated UI.
--
--   Enabled, Close stuck menus
--   one section per menu (pause menu, then each camp or handler menu), each with presets
--   folder contents and order, shared by every menu

local catalog = require("MenusEverywhere.Catalog")
local config = require("MenusEverywhere.Config")
local game = require("MenusEverywhere.Game")
local builder = require("MenusEverywhere.Builder")

local public = {}
local this = { dirty = false, titles = {} }

local TAB_MAX = 12 -- app.cGUIStartMenuCategory.MAIN_MENU_MAX
local WARNING = 0xFF4080FF
local COMBO_WIDTH = 170

local tabLabels, tabIndex, groupByKey = {}, {}, {}
for i, tab in ipairs(catalog.Tabs) do
	tabLabels[i] = tab.label
	tabIndex[tab.key] = i
end
for _, group in ipairs(catalog.Groups) do
	groupByKey[group.key] = group
end

-- Saves and rebuilds the menus. With a section, the change was made by hand to one of
-- that section's options, which turns it into the Custom preset.
local function changed(section)
	if section then config.touch(section) end
	config.save()
	this.dirty = true
end

local function title(fixedId)
	local text = this.titles[fixedId]
	if not text or text == "" then
		text = game.title(fixedId)
		this.titles[fixedId] = text
	end
	return text
end

-- Checkbox bound to a boolean field of a section's settings table.
local function fieldCheckbox(label, settings, field, section)
	local didChange, value = imgui.checkbox(label, settings[field] == true)
	if didChange then
		settings[field] = value
		changed(section)
	end
end

local function presetButtons(section, presets, apply)
	imgui.text("Preset:")
	for _, preset in ipairs(presets) do
		imgui.same_line()
		if imgui.button(preset.label .. "##" .. section) then
			apply(preset)
			changed()
		end
	end
	imgui.same_line()
	if imgui.button(config.CUSTOM .. "##" .. section) then
		config.applyCustom(section)
		changed()
	end
	imgui.same_line()
	imgui.text("(now: " .. config.preset(section) .. ")")
end

local function drawVanillaRows()
	for _, tab in ipairs(catalog.Tabs) do
		local shown = false
		for _, row in ipairs(builder.startRows()) do
			local text = row.tabKey == tab.key and title(row.fixedId) or ""
			if text ~= "" then
				if not shown then
					imgui.text(tab.label)
					shown = true
				end
				local didChange, value = imgui.checkbox(text .. "##row" .. tab.key .. row.fixedId, not row.hidden)
				if didChange then
					config.rowHidden(row.fixedId, not value)
					changed(config.START)
				end
			end
		end
	end
end

local function drawStartMenu()
	presetButtons(config.START, catalog.StartPresets, config.applyStartPreset)

	imgui.text("Folders: pick the tab each one appears in, or Off.")
	for _, key in ipairs(config.order()) do
		imgui.push_item_width(COMBO_WIDTH)
		local tabChanged, tab = imgui.combo(groupByKey[key].label .. "##tab" .. key, tabIndex[config.startTab(key)] or 1, tabLabels)
		imgui.pop_item_width()
		if tabChanged then
			config.startTab(key, catalog.Tabs[tab].key)
			changed(config.START)
		end
	end
	for _, tab in ipairs(catalog.Tabs) do
		local count = builder.tabCount(tab.key)
		if count > TAB_MAX then
			imgui.text_colored(string.format("%s has %d rows and shows about %d at once. If rows go missing there, hide or move some.",
				tab.label, count, TAB_MAX), WARNING)
		end
	end

	imgui.text("Layout:")
	imgui.push_item_width(COMBO_WIDTH)
	local nameChanged, name = imgui.input_text("Name of the extra tab (empty = the game's text)", config.extraTabName())
	imgui.pop_item_width()
	if nameChanged then
		config.extraTabName(name)
		changed()
	end
	local didChange, value = imgui.checkbox("Put my folders above the game's entries##" .. config.START, config.startFirst())
	if didChange then
		config.startFirst(value)
		changed(config.START)
	end
	if imgui.tree_node("Hide the game's own entries") then
		imgui.text("Unticked entries disappear from the pause menu.")
		drawVanillaRows()
		imgui.tree_pop()
	end
end

local function drawSurface(surface)
	local section = surface.key
	local settings = config.surface(section)
	presetButtons(section, catalog.FacilityPresets, function(preset)
		config.applyFacilityPreset(section, preset)
	end)

	imgui.text("Folders:")
	for _, key in ipairs(config.order()) do
		local group = groupByKey[key]
		if catalog.surfaceCategory(group, surface) then
			fieldCheckbox(group.label .. "##" .. section .. key, settings.folders, key, section)
		end
	end
	if surface.note then imgui.text(surface.note) end

	imgui.text("Layout:")
	if surface.full then
		fieldCheckbox("Include everything the base camp tent offers##" .. section, settings, "full", section)
	end
	fieldCheckbox("Give my folders their own tab##" .. section, settings, "ownTab", section)
	fieldCheckbox("Put my folders above the game's entries##" .. section, settings, "first", section)
end

local function drawFolders()
	imgui.text("Applies to every menu. Arrows change the order, untick entries you never use.")
	for _, key in ipairs(config.order()) do
		local group = groupByKey[key]
		if imgui.button("^##up" .. key) then
			config.moveGroup(key, -1)
			changed()
		end
		imgui.same_line()
		if imgui.button("v##down" .. key) then
			config.moveGroup(key, 1)
			changed()
		end
		imgui.same_line()
		if imgui.tree_node(group.label .. "##items" .. key) then
			for _, item in ipairs(group.items) do
				local id = item[1]
				local text = title(id)
				if text == "" then text = "Menu " .. tostring(id) end
				local didChange, value = imgui.checkbox(text .. "##" .. key .. id, config.itemShown(key, id))
				if didChange then
					config.itemShown(key, id, value)
					changed()
				end
			end
			imgui.tree_pop()
		end
	end
end

local function draw()
	local didChange, value = imgui.checkbox("Enabled", config.enabled())
	if didChange then
		config.enabled(value)
		changed()
	end
	imgui.same_line()
	imgui.text("(" .. builder.status() .. ")")
	imgui.same_line()
	if imgui.button("Close stuck menus") then this.closeRequested = true end
	if this.closeReport then imgui.text(this.closeReport) end
	imgui.text("Changes apply the next time a menu is opened.")
	imgui.text("Custom is your own setup: it saves itself whenever you change an option.")

	if imgui.tree_node("Player menu (Esc)") then
		drawStartMenu()
		imgui.tree_pop()
	end
	for _, surface in ipairs(catalog.Surfaces) do
		if imgui.tree_node(surface.label .. "##surface" .. surface.key) then
			drawSurface(surface)
			imgui.tree_pop()
		end
	end
	if imgui.tree_node("Folder contents and order") then
		drawFolders()
		imgui.tree_pop()
	end
end

function public.render()
	re.on_draw_ui(function()
		if imgui.tree_node("MenusEverywhere") then
			local ok, err = pcall(draw)
			if not ok then imgui.text("UI error: " .. tostring(err)) end
			imgui.tree_pop()
		end
	end)
end

-- Runs a pending "Close stuck menus" request. Called from the game's update step, where
-- game calls are safe.
function public.runRequests()
	if this.closeRequested then
		this.closeRequested = false
		this.closeReport = game.closeMenus()
	end
end

-- True once after the player changed something.
function public.consumeDirty()
	local dirty = this.dirty
	this.dirty = false
	return dirty
end

return public
