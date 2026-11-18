#!/usr/bin/env bash
# MewArch: diagnose (and optionally start) Caelestia on the running Hyprland.
# Run from a text screen (Ctrl+Alt+F2):
#   ./check.sh          diagnose
#   ./check.sh start    start Caelestia on screen 1 right now
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export XDG_RUNTIME_DIR=$RT
export WAYLAND_DISPLAY=$(ls "$RT" | grep -m1 -x 'wayland-[0-9]*')
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$RT/hypr/" 2>/dev/null | head -1)
LOG="$HOME/caelestia-check.txt"

if [[ -z $WAYLAND_DISPLAY ]]; then
  echo "Hyprland is not running on screen 1. Reboot, then try ./check.sh again."
  exit 1
fi

if [[ ${1:-} == start ]]; then
  setsid -f qs -c caelestia -n -d >/dev/null 2>&1
  sleep 3
  pgrep -x qs >/dev/null && echo "Caelestia started :3  Go to screen 1: Ctrl+Alt+F1" \
                         || echo "It didn't stay running ;w;  run ./check.sh and send a photo"
  exit 0
fi

echo "== 1. Hyprland config errors =="
hyprctl configerrors 2>&1 | head -8
echo
echo "== 2. Did Caelestia's Hyprland config load? =="
logo=$(hyprctl getoption misc:disable_hyprland_logo 2>/dev/null | grep -oE '(int|bool): *[a-z0-9]+' | head -1)
echo "disable_hyprland_logo -> ${logo:-unknown}   (1/true = Caelestia config loaded)"
echo
echo "== 3. Is the shell running? =="
pgrep -a qs || echo "NOT running"
echo
echo "== 4. Recent shell crashes =="
ls -t "$HOME/.cache/quickshell/crashes" 2>/dev/null | head -3 || echo "none"
echo
echo "== 5. Test run (20 s) =="
timeout 20 qs -c caelestia -n > "$LOG" 2>&1
[[ $? == 124 ]] && echo "Caelestia RAN fine for 20 seconds" || echo "Caelestia STOPPED early:"
grep -iE "error|fatal|cannot|failed|not found|is not a type|unavailable" "$LOG" | tail -8
echo "(full log: $LOG)"
