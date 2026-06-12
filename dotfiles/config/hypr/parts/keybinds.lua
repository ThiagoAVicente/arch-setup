local mainMod     = "SUPER"
local terminal    = "foot"
local fileManager = "pcmanfm"
local qs          = os.getenv("HOME") .. "/scripts/qs-cmd.sh"

-- Programs
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + T", hl.dsp.window.float())
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(qs .. " launcher"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(qs .. " bar"))
hl.bind(mainMod .. " + I", hl.dsp.dpms("off", "eDP-1"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(qs .. " todo"))

-- Performance overrides (reverts on hyprctl reload)
hl.bind(mainMod .. " + ALT + O", hl.dsp.exec_cmd(
    "hyprctl keyword decoration:inactive_opacity 0.75 && hyprctl keyword decoration:blur:enabled true"
))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd(
    "hyprctl keyword decoration:screen_shader '~/.config/hypr/shaders/contrast.glsl'"
))

-- Move focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move windows
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Switch workspaces
for i = 1, 6 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + G", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + M", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = 8 }))

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + H", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ workspace = "special:magic", follow = false }))

-- Scroll through workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Scrolling layout column moves
-- NOTE: old config used "alt escape, left" chord — behavior unclear, mapped to CTRL+ALT here
hl.bind("CTRL + ALT + mouse_down", hl.dsp.layout("move -col"))
hl.bind("CTRL + ALT + mouse_up", hl.dsp.layout("move +col"))

-- Scrolling layout column resize
hl.bind(mainMod .. " + ALT + M", hl.dsp.layout("colresize 1.0"))

-- Move/resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Custom commands
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("CTRL + SHIFT + S", hl.dsp.exec_cmd(
    "SLURP_ARGS='-d' grimblast --freeze copysave area ~/Pictures/Screenshots/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/record-toggle.sh"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd("pkill -SIGUSR1 hyprexpose"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("playerctl -p spotify play-pause"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(qs .. " powermenu"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(qs .. " wallpaper"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/gammastep-toggle.sh"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/toggle_debug.sh"))
hl.bind("SUPER + S", hl.dsp.window.pin())

-- Zoom
hl.bind(mainMod .. " + equal", hl.dsp.exec_cmd(
    "hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float * 1.1')"
), { repeating = true })
hl.bind(mainMod .. " + minus", hl.dsp.exec_cmd(
    "hyprctl -q keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '(.float * 0.9) | if . < 1 then 1 else . end')"
), { repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor 1"))
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.exec_cmd("hyprctl -q keyword cursor:zoom_factor 1"))

-- Gaming submap (passes all keys to apps, keeps media keys)
-- Native hl.dsp.submap from a bind callback fails to enter the submap on keypress.
-- Workaround: bypass by spawning hyprctl, which DOES enter when invoked externally.
hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.submap(\"gaming\")'"))
hl.define_submap("gaming", function()
    hl.bind(mainMod .. " + SHIFT + Escape", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.submap(\"reset\")'"))
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
        { locked = true, repeating = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
        { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
end)
