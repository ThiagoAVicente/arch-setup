-- Quickshell overlays (launcher, todo, powermenu, calendar, osd, notifications,
-- wallpaper selector) — frosted glass: blur behind translucent surfaces only
hl.layer_rule({ match = { namespace = "qs-overlay" }, blur = true, ignore_alpha = 0.2 })
