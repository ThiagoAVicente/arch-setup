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

# Safety check: must NOT run from live ISO
if grep -q "archiso" /proc/cmdline 2>/dev/null; then
    print_error "This script must NOT be run from Arch Live ISO. Reboot into your installed system first!"
fi

# Check if running as regular user (not root)
if [[ $EUID -eq 0 ]]; then
   print_error "This script should NOT be run as root. Run as your regular user."
fi

# Check internet connection
print_step "Checking internet connection"
if ! ping -c 1 archlinux.org &>/dev/null; then
    print_error "No internet connection. Please connect and try again."
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Arch Linux Post-Installation Setup    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

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

                # Remove old symlink if it exists
                [ -L "$target" ] && rm "$target"

                # Create new symlink
                ln -s "$SCRIPT_DIR/$item" "$target"
                echo "Linked: $name"
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

# Enable services
if [ -f "services.txt" ]; then
    print_step "Enabling services"
    while IFS= read -r service; do
        # Skip empty lines and comments
        [[ -z "$service" || "$service" =~ ^# ]] && continue

        if systemctl list-unit-files | grep -q "^$service"; then
            sudo systemctl enable --now "$service" 2>/dev/null && \
                echo "Enabled: $service" || \
                echo "Service $service exists but couldn't be enabled (may need reboot)"
        else
            echo "Skipping: $service (not found)"
        fi
    done < services.txt
fi

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
    done < groups.txt
fi

# mkdirs
mkdir -p ~/.local/share/icons/
mkdir -p ~/{Desktop,Documents,Downloads,Music,Pictures/{Wallpapers,Screenshots},Public,Templates,Videos}

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
read -p "Reboot now? (y/N): " do_reboot

if [[ "$do_reboot" =~ ^[Yy]$ ]]; then
    sudo reboot
fi
