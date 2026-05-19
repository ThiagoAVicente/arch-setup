-- Intel iGPU primary (Nvidia blacklisted via kernel cmdline: module_blacklist=nvidia,...)
hl.env("WLR_DRM_DEVICES", "/dev/dri/card2")
hl.env("WLR_RENDERER", "vulkan")
hl.env("LIBVA_DRIVER_NAME", "iHD")

-- Cursor
hl.env("XCURSOR_THEME", "Sweet-cursors")
hl.env("XCURSOR_SIZE", "20")

-- Qt/GTK
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
hl.env("QT6CT_STYLE_OVERRIDE", "Fusion")
hl.env("GTK_THEME", "Adwaita:dark")

-- Wayland
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- SDL_VIDEODRIVER=wayland breaks Source 2 games (Deadlock) — set per-app instead

-- dGPU (nvidia-open RTX5060, currently blacklisted — enable when activating dGPU)
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
