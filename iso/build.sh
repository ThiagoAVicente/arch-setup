#!/usr/bin/env bash
# Build the arch-setup installer ISO: the official archiso "releng" profile with
# this repo preloaded at /root/arch-setup, so the live system can run the
# installer without cloning anything.
#
# Usage: sudo ./iso/build.sh [version]
# Needs the archiso package. Output goes to ./out (or $OUT_DIR).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(git -C "$REPO_DIR" describe --tags --always)}"
OUT_DIR="${OUT_DIR:-$REPO_DIR/out}"
WORK_DIR="${WORK_DIR:-/tmp/arch-setup-iso}"
PROFILE="$WORK_DIR/profile"
REPO_URL="https://github.com/ThiagoAVicente/arch-setup.git"

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (mkarchiso needs it)" >&2
  exit 1
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# Committed files only, with history, so `git pull` works later
git clone --quiet "$REPO_DIR" "$PROFILE/airootfs/root/arch-setup"
git -C "$PROFILE/airootfs/root/arch-setup" remote set-url origin "$REPO_URL"

cp -r "$REPO_DIR/iso/airootfs/." "$PROFILE/airootfs/"
cat "$REPO_DIR/iso/motd" >> "$PROFILE/airootfs/etc/motd"
echo "git" >> "$PROFILE/packages.x86_64"

sed -i \
  -e 's|^iso_name=.*|iso_name="arch-setup"|' \
  -e 's|^iso_label=.*|iso_label="ARCH_SETUP"|' \
  -e "s|^iso_version=.*|iso_version=\"$VERSION\"|" \
  "$PROFILE/profiledef.sh"

# mkarchiso copies airootfs without file modes, so restore the executable bits
{
  echo 'file_permissions+=(["/usr/local/bin/arch-setup"]="0:0:755")'
  git -C "$REPO_DIR" ls-files -s | while IFS=$'\t' read -r meta path; do
    if [[ "$meta" == 100755* ]]; then
      echo "file_permissions+=([\"/root/arch-setup/$path\"]=\"0:0:755\")"
    fi
  done
} >> "$PROFILE/profiledef.sh"

mkarchiso -v -w "$WORK_DIR/work" -o "$OUT_DIR" "$PROFILE"

cd "$OUT_DIR"
iso="arch-setup-$VERSION-x86_64.iso"
sha256sum "$iso" > "$iso.sha256"

if [ -n "${SUDO_USER:-}" ]; then
  chown "$SUDO_USER:" "$OUT_DIR" "$iso" "$iso.sha256"
fi
rm -rf "$WORK_DIR"

echo "Built $OUT_DIR/$iso"
