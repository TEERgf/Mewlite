#!/usr/bin/env bash
# MewArch >w< — system-wide cute tweaks (run as root).
# Installed as /usr/local/bin/mewarch-cute-system and re-run automatically by a
# pacman hook whenever caelestia-shell or filesystem is upgraded.
set -uo pipefail
SHARE=/usr/local/share/mewarch
ICON=$SHARE/mew-icon.png

# 1) icon in the standard places (icon theme + pixmaps)
if [[ -f $ICON ]]; then
  install -Dm644 "$ICON" /usr/share/pixmaps/mewarch.png
  for s in 16 24 32 48 64 128 256 512; do
    [[ -f $SHARE/mew-icon-$s.png ]] && \
      install -Dm644 "$SHARE/mew-icon-$s.png" "/usr/share/icons/hicolor/${s}x${s}/apps/mewarch.png"
  done
  gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
fi

# 2) OS name shown in the lock screen, dashboard and fastfetch. ID stays "arch",
#    so pacman, the AUR and other tools still see a normal Arch system.
rm -f /etc/os-release
cat > /etc/os-release <<'EOF'
NAME="MewArch"
PRETTY_NAME="MewArch >w<"
ID=arch
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;245;169;184"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://gitlab.archlinux.org/groups/archlinux/-/issues"
LOGO=mewarch
EOF

# 3) Bar launcher button: show the cat in full colour and a bit bigger.
#    (Stock Caelestia tints distro logos with one theme colour, which would
#    turn the cat into a flat blob.)
for f in /etc/xdg/quickshell/caelestia/modules/bar/components/OsIcon.qml \
         /usr/share/quickshell/caelestia/modules/bar/components/OsIcon.qml; do
  [[ -f $f ]] || continue
  grep -q 'mewarch-patched' "$f" && continue
  python3 - "$f" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
if "import Quickshell.Widgets" not in s:
    s = s.replace("import QtQuick\n", "import QtQuick\nimport Quickshell.Widgets\n", 1)
# swap the tinted icon for a plain image
s = re.sub(r"ColouredIcon\s*\{(.*?)\n(\s*)colour:[^\n]*\n", lambda m: "IconImage { // mewarch-patched" + m.group(1) + "\n" + m.group(2) + "asynchronous: true\n", s, count=1, flags=re.S)
# 1.2x font size -> 1.9x so the cat face is readable
s = s.replace("pointSize * 1.2)", "pointSize * 1.9)")
open(p, "w").write(s)
PY
  echo "MewArch: patched $f"
done
exit 0
