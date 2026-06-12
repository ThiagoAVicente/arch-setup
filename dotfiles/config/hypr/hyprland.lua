-- Hyprland 0.55+ Lua config

require("parts.env")

-----------------
-- AUTOSTART   --
-----------------

hl.on("hyprland.start", function()
	hl.exec_cmd("sh -c '[ -f ~/.config/hypr/monitors.lua ] || touch ~/.config/hypr/monitors.lua'")
	hl.exec_cmd("sh -c '[ -f ~/.config/hypr/parts/extra.lua ] || touch ~/.config/hypr/parts/extra.lua'")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("foot --server")
	hl.exec_cmd("hyprexpose --no-preview")
	hl.exec_cmd("quickshell -d")
	hl.exec_cmd("wl-clip-persist --clipboard regular")
	hl.exec_cmd("eval $(/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh)")
	hl.exec_cmd("numlockx on")
	hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
end)

-----------------
-- LOOK & FEEL --
-----------------

hl.config({
	general = {
		gaps_in = 10,
		gaps_out = 20,

		border_size = 1,

		col = {
			active_border = { colors = { "rgba(ffffffee)", "rgba(aaaaaaee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},

		allow_tearing = true,
		layout = "dwindle",

		snap = {
			enabled = true,
			respect_gaps = true,
		},
	},

	binds = {
		movefocus_cycles_fullscreen = true,
	},

	render = {
		new_render_scheduling = true,
		-- direct_scanout        = true,
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = false,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},

		blur = {
			enabled = false,
			size = 3,
			passes = 2,
			new_optimizations = true,
			ignore_opacity = true,
		},
	},

	ecosystem = {
		no_update_news = true,
		no_donation_nag = true,
	},

	master = {
		new_status = "master",
	},

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		key_press_enables_dpms = true,
		mouse_move_enables_dpms = false,
	},

	input = {
		kb_layout = "pt",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = false,
			disable_while_typing = true,
		},
	},

	cursor = {
		inactive_timeout = 3,
		enable_hyprcursor = true,
	},

	scrolling = {
		fullscreen_on_one_column = false,
		column_width = 0.5,
		focus_fit_method = 0,
	},
})

-----------------
-- ANIMATIONS  --
-----------------

require("parts.animations")

-----------------
-- GESTURES    --
-----------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical", action = "resize" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "fullscreen" })
hl.gesture({ fingers = 4, direction = "up", action = "special", workspace_name = "magic" })

-----------------
-- DEVICES     --
-----------------

hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

-----------------
-- RULES       --
-----------------

require("parts.window_rules")
require("parts.layer_rules")

-----------------
-- WORKSPACES  --
-----------------

require("parts.workspaces")

-----------------
-- KEYBINDS    --
-----------------

require("parts.keybinds")

-----------------------
-- MACHINE-SPECIFIC  --
-----------------------

require("monitors")
require("parts.extra")
