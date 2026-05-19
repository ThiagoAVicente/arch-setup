hl.window_rule({
    name    = "xwayland-current-monitor",
    match   = { xwayland = true },
    monitor = "current",
})

hl.window_rule({
    name   = "float-apps",
    match  = { class = "^(spotify|pcmanfm|R.float|protonvpn-app|xdg-desktop-portal-gtk|org.pulseaudio.pavucontrol|blueman-manager)$" },
    float  = true,
    center = true,
    size   = "800 500",
})

hl.window_rule({
    name      = "games",
    match     = { class = "^steam_app_" },
    monitor   = "current",
    immediate = true,
})

hl.window_rule({
    name    = "no-opacity-firefox",
    match   = { class = "^(firefox)$" },
    opacity = "1 override 1 override",
})
