#!/usr/bin/env bash
# MewArch: English + Thai keyboard with a switch key ไทย/ENG
#   ./thai.sh            switch with the ~ key (like Windows in Thailand)
#   ./thai.sh altshift   switch with Alt + Shift
#   ./thai.sh winspace   switch with Win + Space
#   ./thai.sh off        English only again
set -euo pipefail
HU="$HOME/.config/caelestia/hypr-user.lua"
mkdir -p "$(dirname "$HU")"; touch "$HU"
sed -i '/-- >>> mewarch-thai >>>/,/-- <<< mewarch-thai <<</d' "$HU"

case "${1:-grave}" in
  grave|"~")  OPT="grp:grave_toggle";     KEY="the ~ key (top-left, under Esc)";;
  altshift)   OPT="grp:alt_shift_toggle"; KEY="Alt + Shift";;
  winspace)   OPT="grp:win_space_toggle"; KEY="Win + Space";;
  off)        OPT="";;
  *) echo "Use: ./thai.sh [grave|altshift|winspace|off]"; exit 1;;
esac

if [[ -n $OPT ]]; then
  cat >> "$HU" <<EOF
-- >>> mewarch-thai >>>
-- English + Thai (Kedmanee) keyboard, switch with: $KEY
hl.config({ input = { kb_layout = "us,th", kb_options = "$OPT" } })
-- <<< mewarch-thai <<<
EOF
fi

# Thai font so Thai text shows properly everywhere
if ! fc-list :lang=th 2>/dev/null | grep -q .; then
  sudo pacman -S --needed --noconfirm noto-fonts
fi

RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}
hyprctl reload >/dev/null 2>&1 || true
if [[ -n $OPT ]]; then
  echo "Thai keyboard added :3  Switch ENG <-> ไทย with $KEY"
  [[ $OPT == grp:grave_toggle ]] && echo "(To type a real \` or ~ use another switch key: ./thai.sh altshift)"
else
  echo "English only again."
fi
