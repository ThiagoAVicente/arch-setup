#!/bin/bash
# Arch Linux post-installation setup
# Run after base system installation
# by: vcnt
set -e

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
  echo -e "\n${GREEN}==>${NC} ${BLUE}$1${NC}\n"
}

print_error() {
  echo -e "${RED}ERROR:${NC} $1"
  exit 1
}

print_warning() {
  echo -e "${YELLOW}WARNING:${NC} $1"
}

link() {
  target=$1
  source=$2
  name=$3
  [ -L "$target" ] && rm "$target"

  sudo ln -sf "$source" "$target"
  echo -e "${GREEN}Linked ${BLUE}$name${NC} to ${BLUE}$source${NC}"
}

# Check if running as regular user (not root)
if [[ $EUID -eq 0 ]]; then
  print_error "This script should NOT be run as root. Run as your regular user."
fi

# Check internet connection
print_step "Checking internet connection"
if ! ping -c 1 8.8.8.8 &>/dev/null; then
  print_error "No internet connection. Please connect and try again."
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Arch Linux Post-Installation Setup    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

print_step "Configuring pacman"
# Enable multilib repository
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
  echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
fi

# Enable ParallelDownloads (uncomment or add)
if grep -q "^#*ParallelDownloads" /etc/pacman.conf; then
  sudo sed -i 's/^#*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
else
  sudo sed -i '/^\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
fi

# Enable Color (uncomment or add)
if grep -q "^#*Color" /etc/pacman.conf; then
  sudo sed -i 's/^#*Color$/Color/' /etc/pacman.conf
else
  sudo sed -i '/^\[options\]/a Color' /etc/pacman.conf
fi

# Add ILoveCandy (if not present)
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
  sudo sed -i '/^Color$/a ILoveCandy' /etc/pacman.conf
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Verify required directories
if [ ! -d "packages" ]; then
  print_warning "packages directory not found - skipping package installation"
fi

if [ ! -d "dotfiles" ]; then
  print_warning "dotfiles directory not found - skipping dotfiles setup"
fi

# Update system first
print_step "Updating system"
sudo pacman -Syu --noconfirm

# Install official packages
if [ -d "packages" ]; then
  PACKAGE_FILES=""
  [ -f "packages/core.txt" ] && PACKAGE_FILES="$PACKAGE_FILES packages/core.txt"
  [ -f "packages/dev.txt" ] && PACKAGE_FILES="$PACKAGE_FILES packages/dev.txt"
  [ -f "packages/media.txt" ] && PACKAGE_FILES="$PACKAGE_FILES packages/media.txt"
  [ -f "packages/wayland.txt" ] && PACKAGE_FILES="$PACKAGE_FILES packages/wayland.txt"

  if [ -n "$PACKAGE_FILES" ]; then
    print_step "Installing official packages"
    sudo pacman -S --needed --noconfirm $(cat $PACKAGE_FILES)
  fi
fi

# Install yay (AUR helper)
if ! command -v yay &>/dev/null; then
  print_step "Installing yay AUR helper"
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd "$SCRIPT_DIR"
  rm -rf /tmp/yay
fi

# Install AUR packages
if [ -f "packages/yay.txt" ]; then
  print_step "Installing AUR packages (this may take a while)"
  yay -S --needed --noconfirm $(cat packages/yay.txt)
fi

# Setup dotfiles
if [ -d "dotfiles" ]; then
  print_step "Setting up dotfiles"
  mkdir -p ~/.config/

  # Link config directories
  if [ -d "dotfiles/config" ]; then
    for item in dotfiles/config/*; do
      if [ -e "$item" ]; then
        name=$(basename "$item")
        target="$HOME/.config/$name"

        # Backup existing config
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          echo "Backing up existing $name to $name.backup"
          mv "$target" "${target}.backup"
        fi

        link "$target" "$SCRIPT_DIR/$item" "$name"
      fi
    done
  fi

  # Link zshrc
  if [ -f "dotfiles/zshrc" ]; then
    if [ -e "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
      echo "Backing up existing .zshrc to .zshrc.backup"
      mv "$HOME/.zshrc" "$HOME/.zshrc.backup"
    fi
    [ -L "$HOME/.zshrc" ] && rm "$HOME/.zshrc"
    ln -s "$SCRIPT_DIR/dotfiles/zshrc" "$HOME/.zshrc"
    echo "Linked: .zshrc"
  fi
fi

# link bin
if [ -d "bin" ]; then
  mkdir -p "$HOME/.local/bin"

  for item in bin/*; do
    name=$(basename "$item")
    target="$HOME/.local/bin/$name"

    # Backup existing config
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "Backing up existing $name to $name.backup"
      mv "$target" "${target}.backup"
    fi

    link "$target" "$SCRIPT_DIR/$item" "$name"
  done
fi

# link apps
if [ -d "apps" ]; then
  mkdir -p "$HOME/.local/share/applications"

  for item in apps/*; do
    name=$(basename "$item")
    target="$HOME/.local/share/applications/$name"

    # Backup existing config
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "Backing up existing $name to $name.backup"
      mv "$target" "${target}.backup"
    fi

    link "$target" "$SCRIPT_DIR/$item" "$name"
  done
fi

#symlink scripts
ln -s "$SCRIPT_DIR/scripts" "$HOME/scripts"

# Enable services
sudo systemctl disable getty@tty1
sudo systemctl mask getty@tty1

if [ -f "services.txt" ]; then
  print_step "Enabling services"
  while IFS= read -r service; do
    # Skip empty lines and comments
    [[ -z "$service" || "$service" =~ ^# ]] && continue

    sudo systemctl enable --now "$service" 2>/dev/null &&
      echo "Enabled: $service" ||
      echo "Service $service exists but couldn't be enabled (may need reboot)"
  done <services.txt
fi

# Configure geoclue for location services
print_step "Configuring geoclue location service"
# Switch to BeaconDB to avoid Google API rate limits
sudo sed -i 's|#url=https://api.beacondb.net/v1/geolocate|url=https://api.beacondb.net/v1/geolocate|' /etc/geoclue/geoclue.conf
echo "Configured geoclue to use BeaconDB geolocation service"

# Install groups
if [ -f "groups.txt" ]; then
  print_step "Installing groups"
  while IFS= read -r group; do
    [[ -z "$group" || "$group" =~ ^# ]] && continue

    if ! groups | grep -q "\b$group\b"; then
      sudo usermod -aG "$group" "$USER"
      echo "Added user to group: $group"
    else
      echo "User already in group: $group"
    fi
  done <groups.txt
fi

# mkdirs
mkdir -p ~/.local/share/icons/
mkdir -p ~/{Desktop,Documents,Downloads,Music,Pictures/{Wallpapers,Screenshots},Public,Templates,Videos/Recordings}

# install wallpaper and a cursor
print_step "Installing wallpaper and setup wal"
wget --user-agent="Mozilla/5.0" -O ~/Pictures/Wallpapers/wallpaper.jpg https://wallpapercave.com/wp/wp16055214.jpg
wal -i ~/Pictures/Wallpapers/wallpaper.jpg

# mako setup
mkdir -p ~/.config/mako
ln -sf ~/.cache/wal/colors-mako ~/.config/mako/config

# Final message
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Setup Complete!                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "Additional steps:"
echo "1. Install wallpapers to ~/.local/share/icons/Wallpapers"
echo "2. Install cursors (recommend https://vsthemes.org/en/cursors/black/68239-modest-dark.html) to ~/.local/share/icons/"
echo ""

# Skip reboot prompt if called from arch-install.sh (inside chroot)
if [ -z "$SKIP_REBOOT_PROMPT" ]; then
  read -p "Reboot now? (y/N): " do_reboot

  if [[ "$do_reboot" =~ ^[Yy]$ ]]; then
    sudo reboot
  fi
fi
