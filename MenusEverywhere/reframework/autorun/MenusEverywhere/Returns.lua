-- Keeps screens that normally live inside a camp menu working when the pause menu
-- launches them.
--
-- Those screens (item transfer and its pouch variants) do two things that assume a camp
-- menu is open behind them: they close themselves when it is not visible, and they ask
-- the GUI manager to reopen it when they close. Opened from the pause menu that leaves a
-- camp menu nobody asked for holding the input. Both are suppressed, but only between
-- picking a pause menu entry and the pause menu coming back.
--
-- A launched screen can also hand over to a child screen (item pouch -> manage loadouts)
-- by closing itself and reopening when the child closes. The pause menu only knows "come
-- back when the launched screen closes", so it would return while the child is open and
-- close it. That return is held back until the launched screen is open again.

local public = {}
local this = {
	registered = false,
	fromPause = false,
	launched = nil,    -- GUI id the pause menu waits on, with the arguments of that request
	child = nil,       -- GUI id of a child screen the launched one handed over to
	idleSince = nil,   -- since when neither the child nor the launched screen was open
	reopenSince = nil, -- the launched screen is reopening and does not count as open yet
	reRegister = false,
}

local MANAGER = "ace.GUIManagerBase`2<app.GUIID.ID,app.GUIFunc.TYPE>"
local FACILITY_MENU = "UI090001"
local PAUSE_MENU = "UI030000"
local CHILD_LOST = 2.0      -- seconds without either screen before the hold is given up
local REOPEN_LIMIT = 2.0    -- seconds the launched screen gets to reappear
local SELF_CLOSING = { "app.GUI030202", "app.GUI030203", "app.GUI030205" }

local function method(typeName, name)
	local td = sdk.find_type_definition(typeName)
	return td and td:get_method(name)
end

local function guiId(name)
	local td = sdk.find_type_definition("app.GUIID.ID")
	local field = td and td:get_field(name)
	return field and field:get_data(nil)
end

local function int(arg)
	return sdk.to_int64(arg) & 0xFFFFFFFF
end

local function object(arg)
	if sdk.to_int64(arg) == 0 then return nil end
	local managed = sdk.to_managed_object(arg)
	return managed and managed:add_ref()
end

local function reset()
	this.fromPause, this.launched, this.child, this.reRegister = false, nil, nil, false
	this.idleSince, this.reopenSince = nil, nil
end

local function childActive()
	local manager = sdk.get_managed_singleton("app.GUIManager")
	if not manager then return false end
	if this.reopenSince then
		if manager:call("isOpenGUI(app.GUIID.ID)", this.launched.id) or os.clock() - this.reopenSince > REOPEN_LIMIT then
			this.reopenSince = nil
		end
		return true
	end
	if not this.child then return false end
	-- The hold normally ends when the game reopens the launched screen. Between the two
	-- screens neither is open for a moment, so only a longer gap counts as the child
	-- having gone away some other way.
	if manager:call("isOpenGUI(app.GUIID.ID)", this.child) or manager:call("isOpenGUI(app.GUIID.ID)", this.launched.id) then
		this.idleSince = nil
		return true
	end
	this.idleSince = this.idleSince or os.clock()
	return os.clock() - this.idleSince < CHILD_LOST
end

-- Hooks everything once. Returns false while a game type is not available.
function public.register()
	if this.registered then return true end
	local facilityMenu = guiId(FACILITY_MENU)
	local pauseMenu = guiId(PAUSE_MENU)
	local reopen = method(MANAGER, "openGUIByOnClosed")
	local execute = method("app.GUI030000", "executeItem")
	local pauseOpen = method("app.GUI030000", "onOpen")
	local facilityOpen = method("app.GUI090001", "openMenu")
	local chain = method(MANAGER, "onClosedOpenGUI")
	if not (facilityMenu and pauseMenu and execute and pauseOpen and facilityOpen and chain and reopen) then return false end

	sdk.hook(execute, function()
		reset()
		this.fromPause = true
	end, nil)
	sdk.hook(pauseOpen, reset, nil)
	sdk.hook(facilityOpen, reset, nil)

	-- onClosedOpenGUI(closedId, owner, openId, check, func)
	sdk.hook(chain, function(args)
		if not this.fromPause then return sdk.PreHookResult.CALL_ORIGINAL end
		local closedId, openId = int(args[3]), int(args[5])
		if openId == facilityMenu then
			-- drop "reopen the camp menu"
			return sdk.PreHookResult.SKIP_ORIGINAL
		elseif openId == pauseMenu and not (this.launched and this.launched.id == closedId) then
			-- (our own repeats of the request arrive here too and change nothing)
			this.launched = { id = closedId, owner = object(args[4]), check = object(args[6]), func = object(args[7]) }
		elseif this.launched and openId == this.launched.id then
			this.child, this.idleSince = closedId, nil
		end
		return sdk.PreHookResult.CALL_ORIGINAL
	end, nil)

	-- openGUIByOnClosed(openId, ...): the game acting on one of the requests above
	sdk.hook(reopen, function(args)
		if not (this.fromPause and this.launched) then return sdk.PreHookResult.CALL_ORIGINAL end
		local openId = int(args[3])
		if openId == pauseMenu and childActive() then
			-- the request is used up either way, so it is made again on the next frame
			this.reRegister = true
			return sdk.PreHookResult.SKIP_ORIGINAL
		elseif openId == this.launched.id then
			this.child = nil
			this.reopenSince = os.clock()
		end
		return sdk.PreHookResult.CALL_ORIGINAL
	end, nil)

	for _, typeName in ipairs(SELF_CLOSING) do
		local visibleUpdate = method(typeName, "guiVisibleUpdate")
		if visibleUpdate then
			sdk.hook(visibleUpdate, function()
				if this.fromPause then return sdk.PreHookResult.SKIP_ORIGINAL end
				return sdk.PreHookResult.CALL_ORIGINAL
			end, nil)
		end
	end

	this.pauseMenu = pauseMenu
	this.registered = true
	return true
end

-- Once per frame: repeats a held-back "return to the pause menu" request. Done here and
-- not in the hook, where the game is still walking its list of requests.
function public.update()
	if not this.reRegister then return end
	this.reRegister = false
	local launched = this.launched
	local manager = sdk.get_managed_singleton("app.GUIManager")
	if not (this.fromPause and launched and manager) then return end
	local ok, err = pcall(function()
		manager:onClosedOpenGUI(launched.id, launched.owner, this.pauseMenu, launched.check, launched.func)
	end)
	if not ok then log.error("[MenusEverywhere] " .. tostring(err)) end
end

return public
