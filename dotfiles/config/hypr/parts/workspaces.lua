-- layoutopt:direction:right not yet in Lua workspace_rule API — configure via scrolling block in hyprland.lua

-- Keep each monitor's own block of workspaces on it (parts/monitor_ws.lua)
local monitor_ws = require("parts.monitor_ws")
for _, m in ipairs(hl.get_monitors()) do
	monitor_ws.pin(m.name)
end
hl.on("monitor.added", function(m)
	if m and m.name then
		monitor_ws.pin(m.name)
	end
end)
