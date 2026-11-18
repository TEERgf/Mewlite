#!/usr/bin/env bash
# MewArch custom resolution tester >w<
#   ./resolution.sh                 try 1152x864 @ 120 Hz
#   ./resolution.sh 1152 864 144    try another size / refresh rate
#
# Run it in a terminal INSIDE Hyprland (Win+T). For every candidate timing it:
#   1. switches the monitor live (no reboot)
#   2. waits 15 s for you to type  y + Enter
#   3. no answer (e.g. black screen)? it switches back by itself and tries the next one
# When you confirm one, it's saved and used at every login (laptop screen off while
# the monitor is plugged in, same as screen.sh).
set -uo pipefail
W=${1:-1152}; H=${2:-864}; R=${3:-120}
DIR="$(cd "$(dirname "$0")" && pwd)"
RT=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t "$RT/hypr/" 2>/dev/null | head -1)}

hyprctl monitors >/dev/null 2>&1 || { echo "Run this inside Hyprland (open a terminal with Win+T)."; exit 1; }

OUT=$(hyprctl monitors all -j | python3 -c '
import json, sys
names = [m["name"] for m in json.load(sys.stdin) if not m["name"].startswith(("eDP", "LVDS"))]
print(names[0] if names else "")')
[[ -n $OUT ]] || { echo "No external monitor found. Plug it in and try again."; exit 1; }

# ---- build candidate timings (different monitors accept different ones) ----
cands=()
to_hypr(){ sed -nE 's/^Modeline +"[^"]*" +/modeline /p'; }
if command -v cvt >/dev/null; then
  (( R % 60 == 0 )) && cands+=("$(cvt -r "$W" "$H" "$R" 2>/dev/null | to_hypr)")   # reduced blanking
  cands+=("$(cvt "$W" "$H" "$R" 2>/dev/null | to_hypr)")                           # standard CVT
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

echo "Monitor: $OUT   Target: ${W}x${H} @ ${R} Hz   (${#cands[@]} timings to try)"
echo
n=0
for ML in "${cands[@]}"; do
  [[ -n $ML ]] || continue
  n=$((n+1))
  echo "== Try $n: $ML"
  hyprctl eval "hl.monitor({ output = '$OUT', mode = '$ML', position = '0x0', scale = 1 })" >/dev/null 2>&1
  sleep 2
  echo "   Can you read this? Type  y  and press Enter within 15 seconds to KEEP it."
  echo "   (Black screen? Just wait, it switches back by itself.)"
  if read -r -t 15 ans && [[ ${ans,,} == y* ]]; then
    "$DIR/screen.sh" "$ML" >/dev/null
    echo
    echo "Saved :3  ${W}x${H} @ ${R} Hz is now used at every login."
    echo "Undo any time:  ~/mewarch/screen.sh 2560x1080@165"
    exit 0
  fi
  echo "   Not confirmed -> switching back..."
  hyprctl reload >/dev/null 2>&1
  sleep 3
done
echo
echo "Your monitor refused every timing for ${W}x${H} @ ${R} Hz ;w;"
echo "Try a lower refresh rate, e.g.  ./resolution.sh $W $H 100  or  ./resolution.sh $W $H 60"
echo "For stretched res at full speed, use gamescope instead (see README)."
