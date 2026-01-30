# Arch Linux Installation & Dotfiles

Personal Arch Linux setup with automated installation scripts and dotfiles configuration. Designed for easy deployment on new machines.

## Features

- **Automated Arch Linux Installation**: Base system installer with LUKS encryption support
- **Post-Installation Setup**: Automated package installation and dotfiles configuration
- **Wayland Environment**: Hyprland compositor with custom configurations
- **Complete Development Setup**: Pre-configured development tools and environments

## Structure

```
.
├── arch-install.sh      # Base Arch Linux installer (run from live ISO)
├── setup.sh             # Post-installation setup (run after reboot)
├── packages/            # Package lists for pacman and AUR
│   ├── core.txt        # Essential system packages
│   ├── dev.txt         # Development tools
│   ├── media.txt       # Media applications
│   ├── wayland.txt     # Wayland/Hyprland environment
│   └── yay.txt         # AUR packages
├── dotfiles/            # Configuration files
│   ├── config/         # ~/.config directory contents
│   └── zshrc           # Zsh configuration
├── assets/              # Binary assets
│   ├── cursor.tar.gz   # Cursor theme
│   └── wallpapers.tar.gz # Wallpaper collection
└── services.txt         # System services to enable
```

## Installation

### Step 1: Base System Installation

Boot from Arch Linux ISO and run:

```bash
# Download this repository
git clone https://github.com/ThiagoAVicente/arch-setup.git
cd installation

# Run the installer
chmod +x arch-install.sh
sudo ./arch-install.sh
```

### Step 2: Post-Installation Setup

After rebooting into your new system:

```bash
cd ~/installation
chmod +x setup.sh
./setup.sh
```

## Configuration Details

### Included Software

- **Display Server**: Wayland
- **Compositor**: Hyprland
- **Terminal**: Foot
- **Shell**: Zsh with Starship prompt
- **Editor**: Neovim (with custom config)
- **Application Launcher**: Rofi
- **Bar**: Waybar
- **Notifications**: Mako
- **File Manager**: Thunar
- **Browser**: Firefox
- **Development**: Docker, Git, various language toolchains

See `packages/*.txt` for complete lists.

### Custom Scripts

Located in `dotfiles/config/scripts/`:
- `change-wallpaper.sh` - Random wallpaper selector
- `gammastep-toggle.sh` - Blue light filter toggle
- `lock.sh` - Screen lock with hyprlock
- `powermenu.sh` - Power options menu
- `cava-float.sh` - Floating audio visualizer

### Shell Aliases

Notable aliases (see `dotfiles/config/rc/alias.sh`):
- `nv` - nvim
- `pacup` - sudo pacman -Syu
- `docc` - docker compose
- `revive` - reboot
- `fall` - shutdown now

### Key Bindings

Hyprland keybindings configured in `dotfiles/config/hypr/parts/keybinds.conf`.

## Customization

### Before Running on a New Machine

1. **Update user-specific settings** in `arch-install.sh`:
   - Timezone (default: Europe/Lisbon)
   - Locale (default: en_US.UTF-8)
   - Keymap (default: us)

2. **Review packages**: Edit files in `packages/` to add/remove software

3. **Adjust dotfiles**: Customize configs in `dotfiles/config/` as needed

### Modifying Package Lists

Each `.txt` file in `packages/` contains one package per line:
- Lines starting with `#` are ignored
- Empty lines are ignored
- Just add/remove package names

## Assets Attribution

### Wallpapers
Wallpapers sourced from Wallpaper Cave. See `WALLPAPERS.md` for details.

### Cursor Theme
Modified "modest-dark" cursor theme included.

## Requirements

- UEFI system (not BIOS)
- Internet connection
- At least 20GB disk space
- 2GB+ RAM recommended

## Safety Features

- Multiple confirmations before disk operations
- Safety checks to prevent running installer on wrong system
- Automatic backups of existing dotfiles
- Non-destructive symlinking

## Troubleshooting

### Installation fails with "disk not found"
Verify disk path with `lsblk` before running installer.

### Services fail to enable
Some services require reboot before they can start. Reboot and check with:
```bash
systemctl status <service-name>
```

### Dotfiles not loading
Ensure you're using zsh as your shell:
```bash
chsh -s /bin/zsh
```

## License

MIT License - See [LICENSE](LICENSE) file for details.

Note: Assets (wallpapers, cursor themes) may have different licenses. See `WALLPAPERS.md`.

## Credits

- Hyprland configuration inspired by the Hyprland community
- Various shell utilities from the Arch Linux ecosystem
- Wallpapers from Wallpaper Cave contributors

---

**Note**: This is a personal configuration. Review and test in a VM before deploying to production systems.
