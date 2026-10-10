local catalog = require("MenusEverywhere.Catalog")

local CONFIG_PATH = "MenusEverywhere.json"
local VERSION = 2
local START = "start"                -- section name of the pause menu; camp menus use their surface key
local CUSTOM = catalog.CustomPreset

local public = { START = START, CUSTOM = CUSTOM }

local data = {}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, element in pairs(value) do result[key] = copy(element) end
	return result
end

local function named(presets, label)
	for _, preset in ipairs(presets) do
		if preset.label == label then return preset end
	end
	return presets[1]
end

local function surfaceNamed(surfaceKey)
	for _, surface in ipairs(catalog.Surfaces) do
		if surface.key == surfaceKey then return surface end
	end
	return nil
end

-- Built-in presets set every option of their section, so picking one always gives the
-- same result. Rows of the game the player had hidden are shown again (false, not nil:
-- the builder needs to know which rows to unhide).
local function setStartPreset(preset)
	for _, group in ipairs(catalog.Groups) do
		if preset.start == "default" then
			data.start[group.key] = group.tab
		else
			data.start[group.key] = preset.start[group.key] or "OFF"
		end
	end
	data.startFirst = false
	for id in pairs(data.hiddenRows) do data.hiddenRows[id] = false end
	data.preset[START] = preset.label
end

local function setFacilityPreset(surface, preset)
	local f = data.facility[surface.key]
	for _, group in ipairs(catalog.Groups) do
		if catalog.surfaceCategory(group, surface) then
			if type(preset.folders) == "table" then
				f.folders[group.key] = preset.folders[group.key] == true
			else
				f.folders[group.key] = preset.folders
			end
		end
	end
	f.full = (surface.full and preset.full) or false
	f.ownTab, f.first = false, false
	data.preset[surface.key] = preset.label
end

local function defaults()
	data = {
		_version = VERSION, enabled = true,
		start = {}, startFirst = false, extraTabName = "", order = {}, hidden = {}, hiddenRows = {},
		fullAppearance = false,
		facility = {}, preset = {}, custom = {},
	}
	for i, group in ipairs(catalog.Groups) do
		data.order[i] = group.key
	end
	setStartPreset(named(catalog.StartPresets, catalog.DefaultStartPreset))
	for _, surface in ipairs(catalog.Surfaces) do
		data.facility[surface.key] = { folders = {}, full = false, ownTab = false, first = false }
		setFacilityPreset(surface, named(catalog.FacilityPresets, surface.preset))
	end
end

local function merge(into, from)
	for key, value in pairs(from) do
		if type(value) == "table" and type(into[key]) == "table" then
			merge(into[key], value)
		elseif type(value) == type(into[key]) or into[key] == nil then
			into[key] = value
		end
	end
end

-- Version 1 had one set of camp switches shared by every camp menu.
local function migrate(fileData)
	if fileData._version == 1 then
		fileData.facility = {}
		for _, key in ipairs({ "TENT", "SIMPLE_TENT", "TEMPORARY_TENT" }) do
			local f = { folders = {} }
			for groupKey, value in pairs(type(fileData.tent) == "table" and fileData.tent or {}) do
				f.folders[groupKey] = value == true
			end
			if type(fileData.fullCamp) == "table" and fileData.fullCamp[key] ~= nil then
				f.full = fileData.fullCamp[key] == true
			end
			fileData.facility[key] = f
		end
	end
	fileData.tent, fileData.fullCamp, fileData.rest = nil, nil, nil
end

-- Every group exactly once, in the saved order, new groups at the end.
local function orderFrom(saved)
	local order, seen, known = {}, {}, {}
	for _, group in ipairs(catalog.Groups) do known[group.key] = true end
	for _, key in ipairs(type(saved) == "table" and saved or {}) do
		if known[key] and not seen[key] then
			order[#order + 1] = key
			seen[key] = true
		end
	end
	for _, group in ipairs(catalog.Groups) do
		if not seen[group.key] then order[#order + 1] = group.key end
	end
	return order
end

-- Everything a preset of the section decides, as a detached copy.
local function sectionState(section)
	if section == START then
		return { start = copy(data.start), startFirst = data.startFirst, hiddenRows = copy(data.hiddenRows) }
	end
	return copy(data.facility[section])
end

local function sections()
	local list = { START }
	for _, surface in ipairs(catalog.Surfaces) do list[#list + 1] = surface.key end
	return list
end

function public.save()
	json.dump_file(CONFIG_PATH, data)
end

function public.load()
	defaults()
	local fileData = json.load_file(CONFIG_PATH)
	if type(fileData) == "table" then
		migrate(fileData)
		local savedOrder = fileData.order
		fileData.order = nil
		-- a file from before presets were tracked holds the player's own setup
		local tracked = type(fileData.preset) == "table"
		merge(data, fileData)
		data.order = orderFrom(savedOrder)
		if not tracked then
			for _, section in ipairs(sections()) do data.preset[section] = CUSTOM end
		end
	end
	for _, section in ipairs(sections()) do
		if type(data.custom[section]) ~= "table" then data.custom[section] = sectionState(section) end
	end
	data._version = VERSION
	-- written back so new options show up in the file and the first run leaves one behind
	public.save()
end

function public.enabled(value)
	if value ~= nil then data.enabled = value end
	return data.enabled
end

-- Pause menu tab key for a group, "OFF" when it is not shown there.
function public.startTab(groupKey, value)
	if value ~= nil then data.start[groupKey] = value end
	return data.start[groupKey] or "OFF"
end

-- Whether our folders go above the game's own rows in the pause menu.
function public.startFirst(value)
	if value ~= nil then data.startFirst = value end
	return data.startFirst == true
end

-- The player's name for the extra pause menu tab, "" to keep the game's text.
function public.extraTabName(value)
	if value ~= nil then data.extraTabName = value end
	return data.extraTabName
end

-- Whether the camp's Change Appearance screen offers every option of the full re-edit.
function public.fullAppearance(value)
	if value ~= nil then data.fullAppearance = value end
	return data.fullAppearance == true
end

-- Group keys in the order their folders are added to every menu.
function public.order()
	return data.order
end

function public.moveGroup(groupKey, delta)
	for i, key in ipairs(data.order) do
		if key == groupKey then
			local j = i + delta
			if j >= 1 and j <= #data.order then
				data.order[i], data.order[j] = data.order[j], data.order[i]
			end
			return
		end
	end
end

-- Individual entries inside a folder can be hidden; stored sparsely as hidden[group][id] = true.
function public.itemShown(groupKey, fixedId, value)
	local id = tostring(fixedId)
	if value ~= nil then
		data.hidden[groupKey] = data.hidden[groupKey] or {}
		data.hidden[groupKey][id] = (not value) or nil
		if next(data.hidden[groupKey]) == nil then data.hidden[groupKey] = nil end
	end
	return not (data.hidden[groupKey] and data.hidden[groupKey][id])
end

-- Hidden state of one of the game's own pause menu rows: true, false, or nil when the
-- player never touched it. false is kept on purpose, it marks rows we may have to unhide.
function public.rowHidden(fixedId, value)
	local id = tostring(fixedId)
	if value ~= nil then data.hiddenRows[id] = value end
	return data.hiddenRows[id]
end

-- Settings table of a facility surface: { folders = { group = bool }, full, ownTab, first }.
function public.surface(surfaceKey)
	return data.facility[surfaceKey]
end

-- Label of the preset a section is on. Sections: Config.START or a surface key.
function public.preset(section)
	return data.preset[section] or CUSTOM
end

-- The player changed an option of the section by hand: that is the Custom preset now,
-- and its saved copy follows along.
function public.touch(section)
	data.preset[section] = CUSTOM
	data.custom[section] = sectionState(section)
end

function public.applyStartPreset(preset)
	setStartPreset(preset)
end

function public.applyFacilityPreset(surfaceKey, preset)
	local surface = surfaceNamed(surfaceKey)
	if surface then setFacilityPreset(surface, preset) end
end

-- Brings back the player's own setup of the section.
function public.applyCustom(section)
	local saved = data.custom[section]
	if type(saved) == "table" and section == START then
		local tabs = type(saved.start) == "table" and saved.start or {}
		for _, group in ipairs(catalog.Groups) do
			data.start[group.key] = tabs[group.key] or "OFF"
		end
		data.startFirst = saved.startFirst == true
		for id in pairs(data.hiddenRows) do data.hiddenRows[id] = false end
		for id, hidden in pairs(type(saved.hiddenRows) == "table" and saved.hiddenRows or {}) do
			data.hiddenRows[id] = hidden == true
		end
	elseif type(saved) == "table" then
		local f = data.facility[section]
		local folders = type(saved.folders) == "table" and saved.folders or {}
		for key in pairs(f.folders) do f.folders[key] = folders[key] == true end
		f.full, f.ownTab, f.first = saved.full == true, saved.ownTab == true, saved.first == true
	end
	public.touch(section)
end

return public
