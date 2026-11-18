#!/usr/bin/env bash
# customres >w< - custom resolutions for Hyprland (MewArch)
#
#   customres 1152 864 120   create a custom resolution: tries it live, you type y to keep it
#   customres native         back to the monitor's normal resolution (highest refresh)
#   customres list           show the monitor's built-in modes and your saved one
#
# Run inside Hyprland (Win+T). Nothing is saved unless you confirm, and an unconfirmed
# mode switches back by itself after 15 s, so a black screen can't get you stuck.
# Saved modes apply at every login; the laptop screen is turned off while the external
# monitor is plugged in (and stays on when you use the laptop alone).
set -uo pipefail
HU="$HOME/.config/caelestia/hypr-user.lua"
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}
hyprctl monitors >/dev/null 2>&1 || { echo "Run this inside Hyprland (open a terminal with Win+T)."; exit 1; }

OUT=$(hyprctl monitors all -j | python3 -c '
import json, sys
n = [m["name"] for m in json.load(sys.stdin) if not m["name"].startswith(("eDP", "LVDS"))]
print(n[0] if n else "")')
[[ -n $OUT ]] || { echo "No external monitor found. Plug it in and try again."; exit 1; }

save(){   # $1 = mode string to use at every login
  mkdir -p "$(dirname "$HU")"; touch "$HU"
  sed -i '/-- >>> mewarch-screens >>>/,/-- <<< mewarch-screens <<</d' "$HU"
  cat >> "$HU" <<EOF
-- >>> mewarch-screens >>>
-- saved by customres: external monitor only (when plugged in), laptop screen otherwise
local MODE = "$1"
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
}

case "${1:-help}" in
  list)
    echo "Built-in modes of $OUT:"
    hyprctl monitors all -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m["name"] == sys.argv[1]:
        for x in m["availableModes"]: print("  " + x)
        print(f"Now: {m[\"width\"]}x{m[\"height\"]} @ {m[\"refreshRate\"]:.0f} Hz")' "$OUT"
    echo -n "Saved: "; grep -m1 'local MODE' "$HU" 2>/dev/null | cut -d'"' -f2 || echo "(nothing)"
    exit 0 ;;
  native|reset)
    save "highrr"
    hyprctl reload >/dev/null
    echo "Back to the monitor's normal resolution at its highest refresh rate."
    exit 0 ;;
  help|-h|--help)
    sed -n '2,13p' "$0"; exit 0 ;;
esac

W=${1:?width}; H=${2:?height}; R=${3:-60}
[[ $W =~ ^[0-9]+$ && $H =~ ^[0-9]+$ && $R =~ ^[0-9.]+$ ]] || { echo "Usage: customres 1152 864 120"; exit 1; }

# 1) the monitor already supports it? use the normal mode, no tricks needed
if hyprctl monitors all -j | python3 -c '
import json, sys
w, h, r, out = sys.argv[1:5]
for m in json.load(sys.stdin):
    if m["name"] == out and any(x.startswith(f"{w}x{h}@") and abs(float(x.split("@")[1][:-2]) - float(r)) < 1 for x in m["availableModes"]):
        sys.exit(0)
sys.exit(1)' "$W" "$H" "$R" "$OUT"; then
  cands=("${W}x${H}@${R}")
else
  # 2) build custom timings (different monitors accept different ones)
  cands=()
  to_hypr(){ sed -nE 's/^Modeline +"[^"]*" +/modeline /p'; }
  if command -v cvt >/dev/null; then
    [[ $R =~ ^[0-9]+$ ]] && (( R % 60 == 0 )) && cands+=("$(cvt -r "$W" "$H" "$R" 2>/dev/null | to_hypr)")
    cands+=("$(cvt "$W" "$H" "$R" 2>/dev/null | to_hypr)")
  fi
  cands+=("$(python3 - "$W" "$H" "$R" <<'PY'
import sys, math
w, h, r = int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3])
hfp, hs, hbp, vs, vbp = 8, 32, 40, 8, 6          # CVT reduced blanking v2
ht = w + hfp + hs + hbp
vt = math.ceil(h / (1 - 460e-6 * r))
vfp = vt - h - vs - vbp
print(f"modeline {ht*vt*r/1e6:.2f} {w} {w+hfp} {w+hfp+hs} {ht} {h} {h+vfp} {h+vfp+vs} {vt} +hsync -vsync")
PY
)")
fi

echo "Monitor: $OUT   Target: ${W}x${H} @ ${R} Hz"
n=0
for M in "${cands[@]}"; do
  [[ -n $M ]] || continue
  n=$((n+1))
  echo; echo "== Try $n: $M"
  res=$(hyprctl eval "hl.monitor({ output = '$OUT', mode = '$M', position = '0x0', scale = 1 })" 2>&1)
  [[ $res == ok ]] || echo "   Hyprland said: $res"
  sleep 2
  now=$(hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m["name"] == sys.argv[1]: print(f"{m[\"width\"]}x{m[\"height\"]} @ {m[\"refreshRate\"]:.0f} Hz")' "$OUT")
  echo "   Monitor is now: ${now:-unknown}"
  echo "   Can you read this? Type  y  + Enter within 15 s to KEEP it (black screen? just wait)."
  if read -r -t 15 ans && [[ ${ans,,} == y* ]]; then
    save "$M"
    echo; echo "Saved :3  ${W}x${H} @ ${R} Hz is used at every login."
    echo "Black bars at the sides? Set Aspect Ratio to Full/Wide in your MONITOR's own menu."
    echo "Undo:  customres native"
    exit 0
  fi
  echo "   Not kept -> switching back..."
  hyprctl reload >/dev/null 2>&1
  sleep 3
done
echo; echo "Your monitor refused every timing for ${W}x${H} @ ${R} Hz ;w;  Try a lower refresh rate."
