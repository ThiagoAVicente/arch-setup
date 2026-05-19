-- Intel iGPU primary (Nvidia blacklisted via kernel cmdline: module_blacklist=nvidia,...)
-- AQ_DRM_DEVICES replaces old WLR_DRM_DEVICES (aquamarine, colon-separated)
hl.env("AQ_DRM_DEVICES", "/dev/dri/card2")
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Cursor
hl.env("XCURSOR_THEME", "Sweet-cursors")
hl.env("XCURSOR_SIZE", "20")

-- XDG (fixes portal malfunctions, ensures correct session detection)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkit — native Wayland reduces XWayland overhead
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- SDL_VIDEODRIVER=wayland breaks Source 2 games (Deadlock) — set per-app instead

-- Qt theming
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
hl.env("QT6CT_STYLE_OVERRIDE", "Fusion")

-- GTK theming
hl.env("GTK_THEME", "Adwaita:dark")

-- dGPU (nvidia-open RTX5060, currently blacklisted — enable when activating dGPU)
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
