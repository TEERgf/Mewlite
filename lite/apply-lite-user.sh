#!/usr/bin/env bash
# MewArch Lite >w< — keep the full Caelestia shell, trim everything around it.
# Run as your normal user:   LITE=1 OPTIMUS=0|1 mewarch-lite
#   LITE=1     apply the RAM/GPU trims below
#   OPTIMUS=1  stop Caelestia from waking the sleeping NVIDIA card (always worth it on laptops)
# Undo: delete the "mewarch-lite" blocks in ~/.config/caelestia/hypr-user.lua,
#       restore ~/.config/caelestia/hypr-vars.lua.mewarch-bak, and edit shell.json.
set -uo pipefail
LITE=${LITE:-1}
OPTIMUS=${OPTIMUS:-0}
C="$HOME/.config/caelestia"; mkdir -p "$C"

# ---------------------------------------------------------- shell.json --
python3 - "$C/shell.json" "$LITE" "$OPTIMUS" <<'PY'
import json, os, sys
path, lite, optimus = sys.argv[1], sys.argv[2] == "1", sys.argv[3] == "1"
cfg = {}
if os.path.exists(path):
    try: cfg = json.load(open(path))
    except Exception: os.rename(path, path + ".bak")
def node(*keys):
    d = cfg
    for k in keys: d = d.setdefault(k, {})
    return d
if optimus:
    # "Auto" probes/polls nvidia-smi, which wakes the NVIDIA card every time.
    # "Generic" reads the integrated GPU from sysfs instead.
    node("services")["gpuType"] = "Generic"
if lite:
    node("dashboard").update({"mediaUpdateInterval": 1000, "resourceUpdateInterval": 2000})
    node("services")["visualiserBars"] = 30          # half the audio-visualiser bars
    node("background", "visualiser")["enabled"] = False
    node("background", "desktopClock")["enabled"] = False
json.dump(cfg, open(path, "w"), indent=4, ensure_ascii=False)
PY

[[ $LITE == 1 ]] || { echo "MewArch: Optimus GPU fix applied"; exit 0; }

# ------------------------------------------------- hypr-vars.lua (looks) --
# Blur and shadows need extra framebuffers. On integrated graphics those come
# out of system RAM, so turning them off really does save memory.
VARS="$C/hypr-vars.lua"
if [[ ! -s $VARS ]] || grep -qx 'return {}' "$VARS" || grep -q 'mewarch-lite' "$VARS"; then
  [[ -s $VARS ]] && ! grep -q 'mewarch-lite' "$VARS" && cp "$VARS" "$VARS.mewarch-bak"
  cat > "$VARS" <<'EOF'
-- mewarch-lite: lighter look, same Caelestia layout. Edit freely.
return {
    blurEnabled   = false,
    shadowEnabled = false,
    windowOpacity = 1.0,   -- no transparency = less compositing work
}
EOF
else
  echo "MewArch: you already customised hypr-vars.lua, so I left it alone."
  echo "         For extra savings add:  blurEnabled = false, shadowEnabled = false, windowOpacity = 1.0"
fi

# -------------------------------------- hypr-user.lua (session tweaks) --
HU="$C/hypr-user.lua"; touch "$HU"
sed -i '/-- >>> mewarch-lite >>>/,/-- <<< mewarch-lite <<</d' "$HU"
cat >> "$HU" <<'EOF'
-- >>> mewarch-lite >>>
-- glibc keeps fewer per-thread memory pools -> lower RAM for Qt/Quickshell (tiny CPU cost)
hl.env("MALLOC_ARENA_MAX", "2")

-- Caelestia autostarts a few extras. Lite stops the optional ones:
--   gammastep + geoclue agent (night light), mpris-proxy (Bluetooth headset media keys),
--   image clipboard history (text clipboard history stays).
-- Want night light back? Delete the first pkill line.
hl.on("hyprland.start", function()
    hl.exec_cmd([[sleep 6; pkill -x gammastep; pkill -f geoclue-2.0/demos/agent]])
    hl.exec_cmd([[sleep 6; pkill -x mpris-proxy; pkill -f "wl-paste --type image"]])
end)
-- <<< mewarch-lite <<<
EOF
echo "MewArch Lite applied >w<  (restart Hyprland to see everything)"
