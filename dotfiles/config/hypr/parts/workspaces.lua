-- layoutopt:direction:right not yet in Lua workspace_rule API, so configure via scrolling block in hyprland.lua

-- Keep each monitor's own block of workspaces on it (parts/monitor_ws.lua)
local monitor_ws = require("parts.monitor_ws")
for _, m in ipairs(hl.get_monitors()) do
	monitor_ws.pin(m.name)
end
hl.on("monitor.added", function(m)
	if not (m and m.name) then
		return
	end
	monitor_ws.pin(m.name)
	-- Hyprland has already opened the next free workspace (often 9) on the new
	-- monitor before the rules above exist. Open its own first workspace there
	-- instead, so the stray one empties and goes away, then hand focus back
	local prev = hl.get_active_monitor()
	hl.timer(function()
		hl.dispatch(hl.dsp.focus({ monitor = m.name }))
		hl.dispatch(hl.dsp.focus({ workspace = monitor_ws.offset(m.name) + 1 }))
		if prev and prev.name ~= m.name then
			hl.dispatch(hl.dsp.focus({ monitor = prev.name }))
		end
	end, { timeout = 150, type = "oneshot" })
end)
