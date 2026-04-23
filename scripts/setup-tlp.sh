#!/bin/bash
# Setup TLP for Lenovo Legion + i7-13650HX + RTX 5060 Mobile
# legiond: fan/power modes/battery | nvidia-powerd: GPU when modules loaded | TLP: everything else

set -e

sudo tee /etc/tlp.conf > /dev/null << 'EOF'
# TLP config — Lenovo Legion, i7-13650HX, RTX 5060 Mobile
# legiond handles: fan curves, power modes, battery conservation
# nvidia-powerd handles: GPU power when NVIDIA modules are loaded
# TLP handles: everything else

TLP_ENABLE=1
TLP_DEFAULT_MODE=AC

# ── CPU ──────────────────────────────────────────────────────────────
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
CPU_HWP_DYN_BOOST_ON_AC=1
CPU_HWP_DYN_BOOST_ON_BAT=0

# ── Platform profile ──────────────────────────────────────────────────
# legiond overrides these when you change power mode — that's fine
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power

# ── PCIe / Runtime PM ────────────────────────────────────────────────
# Covers NVIDIA GPU when nvidia-powerd isn't running
# nvidia-powerd takes over when NVIDIA modules are loaded — no conflict
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# ── NVMe ─────────────────────────────────────────────────────────────
DISK_DEVICES="nvme0n1"
DISK_APM_LEVEL_ON_AC=254
DISK_APM_LEVEL_ON_BAT=128
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# ── WiFi ─────────────────────────────────────────────────────────────
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# ── USB ──────────────────────────────────────────────────────────────
USB_AUTOSUSPEND=1
EOF

sudo systemctl enable --now tlp
sudo tlp start

echo "TLP configured and started."
