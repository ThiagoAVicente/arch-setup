-- Quickshell overlays (launcher, todo, powermenu, osd, notifications,
-- wallpaper selector) — frosted glass: blur behind translucent surfaces only
hl.layer_rule({ match = { namespace = "qs-overlay" }, blur = true, ignore_alpha = 0.2 })

-- Launcher grows out of the bar: match the bar (no blur), and let QML own the motion
hl.layer_rule({ match = { namespace = "qs-launcher" }, no_anim = true })
