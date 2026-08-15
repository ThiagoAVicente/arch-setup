-- VA-API driver, auto-selected by BIOS MUX mode.
--
-- The MUX decides which GPU owns the connected displays, and a VA-API driver
-- only binds to its own GPU's DRM node. Pick the wrong one and libva errors
-- with "unsupported drm device" and everything silently falls back to CPU
-- decode (~2 cores burned on a 1080p video).
--
--   Discrete -> displays on nvidia -> nvidia/NVDEC
--   Hybrid/UMA -> displays on Intel -> iHD (more power-efficient)
--
-- Detect by asking which PCI device owns a *connected* connector.
-- 0000:01:00.0 = nvidia dGPU, 0000:00:02.0 = Intel iGPU.
local function display_gpu()
	local probe = [[
		for f in /sys/class/drm/card*-*/status; do
			[ "$(cat "$f")" = connected ] || continue
			case "$(readlink -f "$f")" in *0000:01:00.0*) echo nvidia; exit 0;; esac
		done
		echo intel
	]]
	local p = io.popen(probe)
	if not p then
		return "intel"
	end
	local out = p:read("*a") or ""
	p:close()
	return out:match("nvidia") and "nvidia" or "intel"
end

if display_gpu() == "nvidia" then
	-- Default DRM device is already nvidia, so no device override is needed.
	-- (MOZ_DRM_DEVICE would not help anyway: Firefox's RDD sandbox does not
	-- inherit it, so the decoder process ignores it.)
	hl.env("LIBVA_DRIVER_NAME", "nvidia")
	hl.env("NVD_BACKEND", "direct")
else
	hl.env("LIBVA_DRIVER_NAME", "iHD")
end

-- Multi-GPU / HDMI: HDMI-A-2 hangs off the nvidia dGPU while Intel is the
-- primary render device, so every HDMI frame is blitted across GPUs.
-- These keep that blit path sane on nvidia.
hl.env("AQ_MGPU_NO_EXPLICIT", "1")
hl.env("AQ_FORCE_LINEAR_BLIT", "1")

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
