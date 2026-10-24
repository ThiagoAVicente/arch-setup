-- Per-monitor workspaces: every monitor has its own 1–8. The laptop panel
-- owns ids 1–8 and each other monitor a block of ten (11–18, 21–28, …),
-- picked by name so a monitor keeps its block however Hyprland shuffles the
-- monitor ids on hotplug. Mirrored in the bar's workspace strip
-- (quickshell/bar/widgets/HyprlandWorkspaces.qml).
local M = {}

local function is_panel(name)
	return name:match("^eDP") ~= nil
end

-- First workspace id minus one for the monitor called `name`
function M.offset(name)
	if not name or is_panel(name) then
		return 0
	end
	local names = {}
	for _, m in ipairs(hl.get_monitors()) do
		if not is_panel(m.name) then
			table.insert(names, m.name)
		end
	end
	table.sort(names)
	for i, n in ipairs(names) do
		if n == name then
			return i * 10
		end
	end
	return 10
end

-- Workspace `i` (1–8) of the focused monitor
function M.here(i)
	local mon = hl.get_active_monitor()
	return M.offset(mon and mon.name) + i
end

-- Pin each monitor's block to it, its first workspace as the default
function M.pin(name)
	local base = M.offset(name)
	for i = 1, 8 do
		hl.workspace_rule({ workspace = tostring(base + i), monitor = name, default = i == 1 })
	end
end

return M
