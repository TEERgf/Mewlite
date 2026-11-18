#!/usr/bin/env bash
# MewArch: use only the external monitor (laptop screen off) when one is plugged in.
#   ./screen.sh                  external only, 1152x864 @ 200 Hz
#   ./screen.sh 1920x1080@144    external only, another mode
#   ./screen.sh --both           back to using both screens
# Safe: if no external monitor is connected at login, the laptop screen stays on.
set -euo pipefail
MODE=${1:-1152x864@200}
HU="$HOME/.config/caelestia/hypr-user.lua"
mkdir -p "$(dirname "$HU")"; touch "$HU"
sed -i '/-- >>> mewarch-screens >>>/,/-- <<< mewarch-screens <<</d' "$HU"

if [[ $MODE == --both ]]; then
  echo "Both screens on again. Log out/in or reboot to apply."
  exit 0
fi
[[ $MODE =~ ^[0-9]+x[0-9]+(@[0-9.]+)?$ ]] || { echo "Mode should look like 1152x864@200"; exit 1; }

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

# show what the monitor supports, so you can check the mode exists
if command -v hyprctl >/dev/null; then
  RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}
  if hyprctl monitors all 2>/dev/null | grep -q availableModes; then
    want=${MODE%@*}; hz=${MODE#*@}
    if hyprctl monitors all | grep availableModes | grep -q "${want}@${hz}"; then
      echo "Your monitor supports $MODE :3"
    else
      echo "Heads-up: $MODE is not in the monitor's list. Supported modes with $want:"
      hyprctl monitors all | grep availableModes | tr ' ' '\n' | grep "^${want}@" | sort -u || true
      echo "(If it's wrong, run ./screen.sh with one of those, e.g. ./screen.sh ${want}@60)"
    fi
  fi
fi
echo "Done >w<  Reboot to apply:  sudo reboot"
