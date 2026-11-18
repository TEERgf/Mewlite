#!/usr/bin/env bash
# Build the MewArch >w< install ISO.
# Run on Arch Linux (or in an archlinux Docker container started with --privileged) as root:
#     sudo pacman -S --needed archiso
#     sudo ./iso/build-iso.sh
# Output: ./out/mewarch-YYYY.MM.DD-x86_64.iso
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root (sudo)"; exit 1; }
command -v mkarchiso >/dev/null || pacman -S --needed --noconfirm archiso

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"; OUT="$ROOT/out"; PROFILE="$WORK/profile"
rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"

# start from the official Arch install-media profile, then layer MewArch on top
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# branding
sed -i \
  -e 's/^iso_name=.*/iso_name="mewarch"/' \
  -e 's/^iso_label=.*/iso_label="MEWARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
  -e 's/^iso_publisher=.*/iso_publisher="MewArch >w<"/' \
  -e 's/^iso_application=.*/iso_application="MewArch install medium"/' \
  "$PROFILE/profiledef.sh"
echo 'file_permissions+=(["/usr/local/bin/mewarch-install"]="0:0:755")' >> "$PROFILE/profiledef.sh"
# boot menu titles
grep -rl 'Arch Linux install medium' "$PROFILE"/{efiboot,syslinux,grub} 2>/dev/null | \
  xargs -r sed -i 's/Arch Linux install medium/MewArch >w< install medium/g'

# extra packages on the live system (installer helpers)
printf '%s\n' git python fish >> "$PROFILE/packages.x86_64"

# live-system files + the whole kit in /root/mewarch
cp -r "$ROOT/iso/airootfs/." "$PROFILE/airootfs/"
mkdir -p "$PROFILE/airootfs/root/mewarch"
cp -r "$ROOT"/{install.sh,memcheck.sh,start.sh,cute,lite,assets,README.md} "$PROFILE/airootfs/root/mewarch/"

mkarchiso -v -w "$WORK/build" -o "$OUT" "$PROFILE"
ls -lh "$OUT"/*.iso
echo "done >w<"
