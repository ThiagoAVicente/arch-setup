# Arch Linux Installation & Dotfiles

Personal Arch Linux setup with automated installation scripts and dotfiles configuration. Designed for easy deployment on new machines with a focus on Wayland/Hyprland environment.

## Features

- **Automated Base Installation**: Complete Arch Linux installer with LUKS encryption and swap support
- **Post-Installation Automation**: One-command package installation and configuration
- **Wayland Environment**: Hyprland compositor with custom theming via pywal
- **Development Ready**: Pre-configured development tools and environments
- **Location Services**: Configured geoclue with BeaconDB (no rate limits)
- **Custom Utilities**: Sandboxed application launchers and helper scripts

## Repository Structure

```
.
├── arch-install.sh          # Base system installer (run from live ISO)
├── setup.sh                 # Post-installation setup (run after reboot)
│
├── packages/                # Package lists
│   ├── core.txt            # Essential system packages
│   ├── dev.txt             # Development tools
│   ├── media.txt           # Media applications
│   ├── wayland.txt         # Wayland/Hyprland environment
│   └── yay.txt             # AUR packages
│
├── dotfiles/               # Configuration files
│   ├── config/             # ~/.config directory contents
│   │   ├── hypr/           # Hyprland configuration
│   │   ├── waybar/         # Status bar configuration
│   │   ├── rofi/           # Application launcher
│   │   ├── foot/           # Terminal emulator
│   │   ├── nvim/           # Neovim configuration
│   │   ├── swaync/         # Notification daemon
│   │   ├── cava/           # Audio visualizer
│   │   ├── wal/            # Pywal color schemes
│   │   ├── gtk-3.0/        # GTK3 theme settings
│   │   ├── gtk-4.0/        # GTK4 theme settings
│   │   ├── mpv/            # Media player config
│   │   ├── imv/            # Image viewer config
│   │   ├── zed/            # Zed editor config
│   │   ├── rc/             # Shell config
│   │   └── starship.toml   # Shell prompt config
│   └── zshrc               # Zsh shell configuration
│
├── scripts/                # Helper scripts
│   ├── change-wallpaper.sh # Wallpaper changer with pywal integration
│   ├── powermenu.sh        # Power management menu
│   ├── record-toggle.sh    # Screen recording toggle
│   ├── gammastep-toggle.sh # Blue light filter toggle
│   ├── cava-float.sh       # Floating audio visualizer
│   └── toggle_debug.sh     # Debug mode toggle
│
├── bin/                    # Custom executables
│   ├── curd-secure         # Sandboxed curd (bubblewrap)
│   └── curd-secure-dub     # Sandboxed curd with audio
│
├── apps/                   # Desktop application entries
│   ├── curd-secure.desktop
│   ├── curd-secure-dub.desktop
│   └── cava.desktop
│
├── services.txt            # System services to enable
└── groups.txt              # User groups to add
```

## Installation

### Step 1: Base System Installation

Boot from Arch Linux ISO and run:

```bash
# Connect to internet (if needed)
iwctl station wlan0 connect "SSID"

# Install git if not already installed
sudo pacman -S git

# Download this repository
git clone https://github.com/ThiagoAVicente/arch-setup.git
cd arch-setup

# Run the installer
chmod +x arch-install.sh
sudo ./arch-install.sh
```

The installer will:
- Partition your disk (UEFI/GPT)
- Optionally set up LUKS encryption
- Optionally create swap partition
- Install base system with systemd-boot
- Configure locale, timezone, and users
- Copy installation files to `/home/username/installation`

**Reboot after completion.**

### Step 2: Post-Installation Setup

After rebooting into your new system:

```bash
cd ~/installation
chmod +x setup.sh
./setup.sh
```

The setup script automatically handles:
- Pacman configuration (multilib, parallel downloads, color)
- All package installation (official + AUR)
- Yay AUR helper installation
- Dotfiles setup via symlinks
- System services enablement
- Geoclue location services configuration
- User group membership
- Initial wallpaper download and pywal setup
- Directory structure creation

**That's it! Everything is configured automatically.**

## Included Software

### Core System
- **Display Protocol**: Wayland
- **Compositor**: Hyprland
- **Display Manager**: ly (TTY-based)
- **Shell**: Zsh with Starship prompt
- **Terminal**: Foot
- **Editor**: Neovim ([Lazyvim config](https://www.lazyvim.org/))

### Desktop Environment
- **Launcher**: Rofi
- **Status Bar**: Waybar
- **Notifications**: SwayNC
- **File Manager**: Thunar
- **Audio Visualizer**: CAVA
- **Color Scheme**: Pywal 
- **Blue Light Filter**: Gammastep
- **Screenshot**: Grimblast

### Applications
- **Browser**: Firefox 
- **Media Player**: MPV
- **Image Viewer**: imv and chafa(terminal based)
- **PDF Viewer**: Zathura
- **Office**: LibreOffice
- **Music**: Spotify 

### Development Tools
- **Containers**: Docker(-compose)
- **Virtualization**: libvirt/QEMU
- **Version Control**: Git
- **Code Editors**: Neovim, Zed, Claude-code, etc
- **Languages**: Python, Node.js, Go, Rust toolchains

### System Services

Automatically enabled services:
- `NetworkManager` - Network management
- `docker` - Container runtime
- `tlp` - Power management
- `ufw` - Firewall
- `bluetooth` - Bluetooth support
- `systemd-timesyncd` - Time synchronization
- `libvirtd` - Virtualization
- `ly@tty1` - Display manager
- `avahi-daemon` - Network service discovery (required for location services)

See `services.txt` for the complete list.


### Dotfile Modifications

All dotfiles are symlinked from `~/installation/dotfiles/`, so you can:
1. Edit files in the repository
2. Changes take effect immediately (no re-linking needed)
3. Commit and push changes to keep them synced

### Keybindings (Hyprland)

See `dotfiles/config/hypr/hyprland.conf` for full list. Key bindings:

- `SUPER + Q` - Close window
- `SUPER + Return` - Terminal
- `SUPER + D` - Rofi launcher
- `SUPER + T` - Toggle floating
- `SUPER + F` - Toggle fullscreen
- `SUPER + [1-6,9,10]` - Switch workspace
- `SUPER + Shift + [1-6,9,10]` - Move window to workspace
- `SUPER + Esc` - Power menu
- `SUPER + Shift + S` - Screenshot region
- `SUPER + Shift + V` - Start/Stop region recording

## Requirements

- **UEFI system** 
- **Internet connection** during installation
- **2GB+ RAM** recommended
- 
## Additional Resources

**Optional Downloads:**
- **Wallpapers**: Download to `~/Pictures/Wallpapers/` and use `SUPER+ALT+W` to select
- **Cursor Theme**: [Modest Dark Cursors](https://vsthemes.org/en/cursors/black/68239-modest-dark.html) - Extract to `~/.local/share/icons/`

**Useful Links:**
- [Envycontrol](https://github.com/bayasdev/envycontrol) - GPU mode switcher for NVIDIA Optimus laptops
- [NVIDIA on Hyprland](https://wiki.hypr.land/Nvidia/) - Configuration guide for NVIDIA GPUs
- [Looking Glass](https://looking-glass.io/) - Low-latency KVM framebuffer sharing for GPU passthrough
- [Windows 11 Download](https://www.microsoft.com/en-us/software-download/windows11) - For VM setup

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Credits

- Hyprland configuration inspired by the Hyprland community
- Dotfiles structure influenced by various Arch Linux ricing communities

---
