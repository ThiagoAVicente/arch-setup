#!/bin/bash
# Arch Linux base system installer
# by: vcnt
set -e

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper functions
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

# Safety check: only run on live ISO
if [ -f /etc/hostname ] && [ "$(cat /etc/hostname)" != "archiso" ]; then
    print_error "This script must ONLY be run from Arch Live ISO, not on an installed system!"
fi

if ! grep -q "archiso" /proc/cmdline 2>/dev/null; then
    print_warning "Not running from archiso - are you sure you want to continue?"
    read -p "Type 'YES' to override: " override
    if [ "$override" != "YES" ]; then
        print_error "Installation cancelled"
    fi
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
fi

# Check internet connection
print_step "Checking internet connection"
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    print_error "No internet connection. Connect using 'iwctl' or 'ip' and try again."
fi

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Arch Linux Base System Installer     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Configuration variables
DISK=""
HOSTNAME=""
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
LUKS_PASSWORD=""
TIMEZONE="Europe/Lisbon"
LOCALE="en_US.UTF-8"
KEYMAP="us"
USE_ENCRYPTION=false
USE_SWAP=false
SWAP_SIZE="8G"

# Disk selection
print_step "Available disks:"
lsblk -d -n -o NAME,SIZE,TYPE,MODEL | grep disk | nl
echo ""
read -p "Select disk number: " disk_number
DISK="/dev/$(lsblk -d -n -o NAME,TYPE | grep disk | sed -n "${disk_number}p" | awk '{print $1}')"

if [ ! -b "$DISK" ]; then
    print_error "Invalid disk selected: $DISK"
fi

echo ""
echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo -e "${RED}  WARNING: ALL DATA ON $DISK WILL BE DESTROYED!${NC}"
echo -e "${RED}═══════════════════════════════════════════════════${NC}"
echo ""
lsblk "$DISK"
echo ""
read -p "Type 'YES' to continue: " confirm
if [ "$confirm" != "YES" ]; then
    print_error "Installation cancelled"
fi

# System configuration
echo ""
print_step "System Configuration"
read -p "Hostname: " HOSTNAME
read -p "Username: " USERNAME
read -p "Keymap [us]: " keymap_input
if [ -n "$keymap_input" ]; then
    KEYMAP="$keymap_input"
fi

# User password
while true; do
    read -sp "User password: " USER_PASSWORD
    echo ""
    read -sp "Confirm password: " USER_PASSWORD_CONFIRM
    echo ""
    if [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
        break
    fi
    echo -e "${RED}Passwords do not match. Try again.${NC}"
done

# Root password
while true; do
    read -sp "Root password: " ROOT_PASSWORD
    echo ""
    read -sp "Confirm password: " ROOT_PASSWORD_CONFIRM
    echo ""
    if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
        break
    fi
    echo -e "${RED}Passwords do not match. Try again.${NC}"
done

# Encryption
echo ""
read -p "Enable disk encryption? (y/N): " encrypt
if [[ "$encrypt" =~ ^[Yy]$ ]]; then
    USE_ENCRYPTION=true
    read -p "Use different password for LUKS? (y/N): " diff_luks
    if [[ "$diff_luks" =~ ^[Yy]$ ]]; then
        while true; do
            read -sp "LUKS password: " LUKS_PASSWORD
            echo ""
            read -sp "Confirm password: " LUKS_PASSWORD_CONFIRM
            echo ""
            if [ "$LUKS_PASSWORD" = "$LUKS_PASSWORD_CONFIRM" ]; then
                break
            fi
            echo -e "${RED}Passwords do not match. Try again.${NC}"
        done
    else
        LUKS_PASSWORD="$USER_PASSWORD"
    fi
fi

# Swap
read -p "Create swap partition? (y/N): " use_swap
if [[ "$use_swap" =~ ^[Yy]$ ]]; then
    USE_SWAP=true
    read -p "Swap size [8G]: " swap_input
    if [ -n "$swap_input" ]; then
        SWAP_SIZE="$swap_input"
    fi
fi

# Confirm configuration
echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo "Disk: $DISK"
echo "Hostname: $HOSTNAME"
echo "Username: $USERNAME"
echo "Timezone: $TIMEZONE"
echo "Locale: $LOCALE"
echo "Keymap: $KEYMAP"
echo "Encryption: $([ "$USE_ENCRYPTION" = true ] && echo "Yes" || echo "No")"
echo "Swap: $([ "$USE_SWAP" = true ] && echo "Yes ($SWAP_SIZE)" || echo "No")"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
read -p "Proceed with installation? (yes/no): " proceed
if [ "$proceed" != "yes" ]; then
    print_error "Installation cancelled"
fi

# Update system clock
print_step "Updating system clock"
timedatectl set-ntp true

# Partition the disk
print_step "Partitioning disk $DISK"
wipefs -af "$DISK"
sgdisk -Z "$DISK"

if [ "$USE_SWAP" = true ]; then
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
    sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"SWAP" "$DISK"
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"ROOT" "$DISK"
else
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$DISK"
    sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "$DISK"
fi

partprobe "$DISK"
sleep 2

# Determine partition names
if [[ "$DISK" =~ "nvme" ]] || [[ "$DISK" =~ "mmcblk" ]]; then
    EFI_PART="${DISK}p1"
    if [ "$USE_SWAP" = true ]; then
        SWAP_PART="${DISK}p2"
        ROOT_PART="${DISK}p3"
    else
        ROOT_PART="${DISK}p2"
    fi
else
    EFI_PART="${DISK}1"
    if [ "$USE_SWAP" = true ]; then
        SWAP_PART="${DISK}2"
        ROOT_PART="${DISK}3"
    else
        ROOT_PART="${DISK}2"
    fi
fi

# Setup encryption if requested
if [ "$USE_ENCRYPTION" = true ]; then
    print_step "Setting up LUKS encryption"
    LUKS_KEY_FILE="/tmp/luks.key"
    echo -n "$LUKS_PASSWORD" > "$LUKS_KEY_FILE"
    chmod 600 "$LUKS_KEY_FILE"
    cryptsetup luksFormat --type luks2 "$ROOT_PART" "$LUKS_KEY_FILE"
    cryptsetup open "$ROOT_PART" cryptroot --key-file "$LUKS_KEY_FILE"
    shred -u "$LUKS_KEY_FILE"
    ROOT_PART_DECRYPT="/dev/mapper/cryptroot"
else
    ROOT_PART_DECRYPT="$ROOT_PART"
fi

# Format partitions
print_step "Formatting partitions"
mkfs.fat -F32 "$EFI_PART"
if [ "$USE_SWAP" = true ]; then
    mkswap "$SWAP_PART"
fi
mkfs.ext4 -F "$ROOT_PART_DECRYPT"

# Mount filesystems
print_step "Mounting filesystems"
mount "$ROOT_PART_DECRYPT" /mnt
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot
if [ "$USE_SWAP" = true ]; then
    swapon "$SWAP_PART"
fi

# Select fastest mirrors
print_step "Updating mirrorlist"
reflector --country Portugal,Spain,France --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Install base system
print_step "Installing base system (this will take a few minutes)"
pacstrap -K /mnt base base-devel linux linux-firmware \
    intel-ucode amd-ucode \
    networkmanager git vim sudo zsh

# Generate fstab
print_step "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Create chroot configuration script
cat > /mnt/root/chroot-setup.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

# Timezone and locale
ln -sf /usr/share/zoneinfo/TIMEZONE /etc/localtime
hwclock --systohc
echo "LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=LOCALE" > /etc/locale.conf
echo "KEYMAP=KEYMAP" > /etc/vconsole.conf

# Hostname
echo "HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   HOSTNAME.localdomain HOSTNAME
EOF

# Create user
useradd -m -G wheel,audio,video,optical,storage -s /bin/zsh USERNAME
chpasswd <<PWDEOF
USERNAME:USER_PASSWORD
root:ROOT_PASSWORD
PWDEOF

# Configure sudo
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Enable NetworkManager
systemctl enable NetworkManager

# Install bootloader
bootctl install

# Configure bootloader
cat > /boot/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF

# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value ROOT_PART_DECRYPT)

# Create boot entry
cat > /boot/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw quiet splash
EOF

CHROOT_EOF

# Replace placeholders
sed -i "s|TIMEZONE|$TIMEZONE|g" /mnt/root/chroot-setup.sh
sed -i "s|LOCALE|$LOCALE|g" /mnt/root/chroot-setup.sh
sed -i "s|KEYMAP|$KEYMAP|g" /mnt/root/chroot-setup.sh
sed -i "s|HOSTNAME|$HOSTNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|USERNAME|$USERNAME|g" /mnt/root/chroot-setup.sh
sed -i "s|USER_PASSWORD|$USER_PASSWORD|g" /mnt/root/chroot-setup.sh
sed -i "s|ROOT_PASSWORD|$ROOT_PASSWORD|g" /mnt/root/chroot-setup.sh
sed -i "s|ROOT_PART_DECRYPT|$ROOT_PART_DECRYPT|g" /mnt/root/chroot-setup.sh

# Add encryption support if needed
if [ "$USE_ENCRYPTION" = true ]; then
    cat >> /mnt/root/chroot-setup.sh << 'CHROOT_EOF'
# Configure mkinitcpio for encryption
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Update boot entry with cryptdevice
ROOT_PART_UUID=$(blkid -s UUID -o value ROOT_PART)
sed -i "s|root=UUID=|cryptdevice=UUID=$ROOT_PART_UUID:cryptroot root=UUID=|" /boot/loader/entries/arch.conf
CHROOT_EOF
    sed -i "s|ROOT_PART|$ROOT_PART|g" /mnt/root/chroot-setup.sh
else
    cat >> /mnt/root/chroot-setup.sh << 'CHROOT_EOF'
# Configure mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P
CHROOT_EOF
fi

chmod +x /mnt/root/chroot-setup.sh

# Execute chroot configuration
print_step "Configuring system"
arch-chroot /mnt /root/chroot-setup.sh
rm /mnt/root/chroot-setup.sh

# Copy installation repo to new system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR" ]; then
    print_step "Copying installation files"
    cp -r "$SCRIPT_DIR" /mnt/home/$USERNAME/installation
    arch-chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME/installation
    echo -e "${GREEN}Installation repo copied to /home/$USERNAME/installation${NC}"
fi

# Installation complete
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Base System Installation Complete!     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
read -p "Unmount and reboot now? (y/N): " do_reboot

if [[ "$do_reboot" =~ ^[Yy]$ ]]; then
    umount -R /mnt
    reboot
fi
