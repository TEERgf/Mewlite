#!/usr/bin/env bash
# MewArch: reset all screen/resolution changes back to normal.
#   - restores Caelestia's original ~/.config/hypr/hyprland.lua (your edited one is backed up)
#   - removes the screen/custom-resolution block saved by screen.sh / customres / resolution.sh
# Afterwards both screens use their normal resolution. Run from Hyprland (Win+T) or a text screen.
set -uo pipefail
HL="$HOME/.config/hypr/hyprland.lua"
HU="$HOME/.config/caelestia/hypr-user.lua"
ORIG="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/dots/hypr/hyprland.lua"
URL="https://raw.githubusercontent.com/caelestia-dots/caelestia/main/hypr/hyprland.lua"
TS=$(date +%Y%m%d-%H%M%S)

# 1) Caelestia's main Hyprland config
if [[ -f $HL ]]; then
  cp -L "$HL" "$HL.bak-$TS"
  echo "Backed up your edited file to: $HL.bak-$TS"
fi
if [[ -f $ORIG ]]; then
  cat "$ORIG" > "$HL.new"
  echo "Restored hyprland.lua from Caelestia's installed copy."
elif curl -fsSL "$URL" -o "$HL.new"; then
  echo "Restored hyprland.lua from Caelestia on GitHub."
else
  echo "Couldn't get the original hyprland.lua (no internet?). Nothing changed there."
  rm -f "$HL.new"
fi
[[ -f $HL.new ]] && { rm -f "$HL"; mv "$HL.new" "$HL"; }

# 2) saved custom resolution / external-only block
if [[ -f $HU ]]; then
  cp "$HU" "$HU.bak-$TS"
  sed -i '/-- >>> mewarch-screens >>>/,/-- <<< mewarch-screens <<</d' "$HU"
  echo "Removed the saved screen/resolution setting."
fi

# 3) apply now if Hyprland is running
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}
if hyprctl reload >/dev/null 2>&1; then
  sleep 1
  errs=$(hyprctl configerrors 2>/dev/null | grep -v '^$' || true)
  [[ -z $errs ]] && echo "Applied. No config errors :3" || { echo "Applied, but Hyprland still reports:"; echo "$errs"; }
else
  echo "Hyprland isn't running here; changes apply at next login (or: sudo reboot)."
fi
echo
echo "Want the big monitor only again?  customres native     Custom res:  customres 1152 864 120"
