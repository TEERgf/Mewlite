#!/usr/bin/env bash
# Run this from the official Arch ISO when the mewarch folder is on the USB stick:
#     bash /run/archiso/bootmnt/mewarch/start.sh
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
rm -rf /root/mewarch && cp -r "$SRC" /root/mewarch
sed -i 's/\r$//' /root/mewarch/*.sh /root/mewarch/cute/*.sh /root/mewarch/lite/*.sh /root/mewarch/iso/airootfs/usr/local/bin/mewarch-install  # undo Windows line endings, just in case
chmod +x /root/mewarch/*.sh /root/mewarch/cute/*.sh /root/mewarch/lite/*.sh /root/mewarch/iso/airootfs/usr/local/bin/mewarch-install
exec /root/mewarch/iso/airootfs/usr/local/bin/mewarch-install
