#!/usr/bin/env bash
# MewArch: use only the external monitor (laptop screen off) when one is plugged in.
#   ./screen.sh                  external only, 2560x1080 @ 165 Hz
#   ./screen.sh 1920x1080@144    external only, another mode
#   ./screen.sh --both           back to using both screens
#   ./screen.sh custom 1152 864 200   force a custom mode (CVT-RB2 modeline); may show
#                                     "out of range" if the monitor can't do it -> undo
#                                     from a text screen: ./screen.sh 2560x1080@165
# Safe: if no external monitor is connected at login, the laptop screen stays on.
set -euo pipefail
MODE=${1:-2560x1080@165}
HU="$HOME/.config/caelestia/hypr-user.lua"
mkdir -p "$(dirname "$HU")"; touch "$HU"
sed -i '/-- >>> mewarch-screens >>>/,/-- <<< mewarch-screens <<</d' "$HU"

if [[ $MODE == --both ]]; then
  echo "Both screens on again. Log out/in or reboot to apply."
  exit 0
fi
CUSTOM=0
if [[ $MODE == custom ]]; then
  W=${2:?width}; H=${3:?height}; R=${4:?refresh}
  # CVT reduced blanking v2 timings
  MODE=$(python3 - "$W" "$H" "$R" <<'PY2'
import sys, math
w, h, r = int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3])
hfp, hsync, hbp = 8, 32, 40                      # RB2: 80 px horizontal blank
vsync, vbp, min_vblank_us = 8, 6, 460
htotal = w + hfp + hsync + hbp
vtotal = math.ceil(h / (1 - min_vblank_us * r / 1e6))
vfp = vtotal - h - vsync - vbp
clock = htotal * vtotal * r / 1e6
print(f"modeline {clock:.2f} {w} {w+hfp} {w+hfp+hsync} {htotal} {h} {h+vfp} {h+vfp+vsync} {vtotal} +hsync -vsync")
PY2
)
  CUSTOM=1
  echo "Custom mode: $MODE"
elif ! [[ $MODE =~ ^[0-9]+x[0-9]+(@[0-9.]+)?$ ]]; then
  echo "Mode should look like 1152x864@200  (or: ./screen.sh custom 1152 864 200)"; exit 1
fi

# refuse modes the monitor doesn't offer (a wrong mode = black screen)
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}
MODES=$(hyprctl monitors all 2>/dev/null | grep availableModes | grep -v "1920x1200@165" || true)
if [[ -n $MODES && $CUSTOM == 0 ]]; then
  want=${MODE%@*}; hz=${MODE#*@}; [[ $hz == "$MODE" ]] && hz=""
  if ! tr ' ' '\n' <<<"$MODES" | grep -q "^${want}@${hz}"; then
    echo "Your monitor does NOT support $MODE ;w;  Nothing was changed."
    echo "Modes it supports:"
    tr ' ' '\n' <<<"$MODES" | grep -oE '^[0-9]+x[0-9]+@[0-9]+' | sort -t@ -k1,1 -k2,2nr -u | head -20
    exit 1
  fi
fi

cat >> "$HU" <<EOF
-- >>> mewarch-screens >>>
-- Only the external monitor when one is connected (checked at login); laptop screen otherwise.
local MODE = "$MODE"
local ext
local p = io.popen([[for s in /sys/class/drm/card*-*/status; do c=\${s%/status}; c=\${c##*/}; case "\$c" in *eDP*|*LVDS*|*Writeback*) continue;; esac; grep -qx connected "\$s" && { echo "\${c#card*-}"; break; }; done]])
if p then ext = p:read("*l"); p:close() end
if ext and ext ~= "" then
    hl.monitor({ output = ext, mode = MODE, position = "0x0", scale = 1 })
    hl.monitor({ output = "eDP-1", disabled = true })
    hl.monitor({ output = "eDP-2", disabled = true })
end
-- <<< mewarch-screens <<<
EOF

echo "Done >w<  Reboot to apply:  sudo reboot"
