local config = require("MenusEverywhere.Config")
local builder = require("MenusEverywhere.Builder")
local returns = require("MenusEverywhere.Returns")
local gui = require("MenusEverywhere.Gui")
local appearance = require("MenusEverywhere.Appearance")

local CHECK_INTERVAL = 120 -- frames between checks for missing or replaced game data
local UPDATE_STEP = "UpdateBehavior" -- game logic step; re.on_frame runs with the renderer, where touching menus can crash

config.load()
gui.render()

local applied = false
local returnsHooked = returns.register()
local appearanceHooked = appearance.register()
local frame = 0

re.on_application_entry(UPDATE_STEP, function()
	frame = frame + 1
	gui.runRequests()
	returns.update()
	builder.update()
	if gui.consumeDirty() then
		applied = builder.apply()
	elseif frame % CHECK_INTERVAL == 0 then
		if not applied or builder.isStale() then applied = builder.apply() end
		if not returnsHooked then returnsHooked = returns.register() end
		if not appearanceHooked then appearanceHooked = appearance.register() end
	end
end)
