#!/usr/bin/env bash
# MewArch: start Caelestia on the running Hyprland for 20 s and show why it fails.
# Run from a text screen (Ctrl+Alt+F2):   ./check.sh
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export XDG_RUNTIME_DIR=$RT
export WAYLAND_DISPLAY=$(ls "$RT" | grep -m1 -x 'wayland-[0-9]*')
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$RT/hypr/" 2>/dev/null | head -1)
LOG="$HOME/caelestia-check.txt"

if [[ -z $WAYLAND_DISPLAY ]]; then
  echo "Hyprland is not running on screen 1. Reboot, then try ./check.sh again."
  exit 1
fi
echo "Testing Caelestia on $WAYLAND_DISPLAY for 20 seconds, please wait..."
timeout 20 qs -c caelestia > "$LOG" 2>&1
code=$?
echo
if [[ $code == 124 ]]; then
  echo "Caelestia RAN fine for 20 seconds :3  (look at screen 1: Ctrl+Alt+F1)"
fi
echo "---- important lines ----"
grep -iE "error|fatal|cannot|failed|not found|is not a type|unavailable" "$LOG" | grep -v "^$" | tail -15
echo "-------------------------"
echo "Full log saved in: $LOG"
