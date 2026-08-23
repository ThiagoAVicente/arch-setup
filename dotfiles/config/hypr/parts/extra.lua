-- Restrict aquamarine to the Intel iGPU so it never opens the nvidia dGPU.
-- Hyprland holding an fd on /dev/nvidia0 + renderD129 keeps the dGPU in D0
-- (~3.4W, never reaches D3cold) even with no display attached to it.
-- prime-run still works: the game opens nvidia itself and hands Hyprland a
-- dmabuf, which Intel imports. Only nvidia's outputs (DP-2, HDMI-A-2) go dead.
--
-- NOTE: aquamarine splits AQ_DRM_DEVICES on ":", so /dev/dri/by-path/* names
-- cannot be used - they contain colons and get truncated ("Failed to
-- canonicalize path /dev/dri/by-path/pci-0000"). Resolve the cardN node from
-- the stable PCI address instead, since cardN numbering shuffles across boots.
local function card_node(pci)
	local p = io.popen('basename "$(readlink -f /sys/bus/pci/devices/' .. pci .. '/drm/card*)" 2>/dev/null')
	if not p then
		return nil
	end
	local out = (p:read("*a") or ""):gsub("%s+$", "")
	p:close()
	return out:match("^card%d+$") and "/dev/dri/" .. out or nil
end

local intel = card_node("0000:00:02.0")
if intel then
	hl.env("AQ_DRM_DEVICES", intel)
end
