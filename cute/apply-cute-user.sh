#!/usr/bin/env bash
# MewArch >w< — per-user cute tweaks (run as your normal user).
# Change the kaomoji here if you like, then re-run this script.
WS_ACTIVE=":3"        # active workspace in the bar (keep it 1-2 characters, the bar is narrow)
WS_OCCUPIED="•"       # workspace with windows
WS_EMPTY="·"          # empty workspace
set -uo pipefail

CFG="$HOME/.config/caelestia/shell.json"
mkdir -p "$(dirname "$CFG")"

# 1) Caelestia shell settings (merged into your existing shell.json, nothing else is touched)
python3 - "$CFG" "$WS_ACTIVE" "$WS_OCCUPIED" "$WS_EMPTY" <<'PY'
import json, os, sys
path, act, occ, empty = sys.argv[1:5]
cfg = {}
if os.path.exists(path):
    try: cfg = json.load(open(path))
    except Exception: os.rename(path, path + ".bak")   # broken file -> keep a copy
def deep(d, *keys):
    for k in keys: d = d.setdefault(k, {})
    return d
deep(cfg, "general")["logo"] = "/usr/share/pixmaps/mewarch.png"
ws = deep(cfg, "bar", "workspaces")
ws.update({"displayType": "text", "activeLabel": act, "occupiedLabel": occ, "label": empty})
deep(cfg, "general", "battery")["warnLevels"] = [
    {"level": 20, "title": "battery getting sleepy (｡•́︿•̀｡)", "message": "maybe plug in the charger? :3", "icon": "battery_android_frame_2"},
    {"level": 10, "title": "hewwo?? battery at 10% >w<", "message": "pls plug me in <b>now</b> (╥﹏╥)", "icon": "battery_android_frame_1"},
    {"level": 5,  "title": "CRITICAL BATTERY ;w;", "message": "PLUG THE CHARGER RIGHT NOW!! (ﾉ≧∇≦)ﾉ", "icon": "battery_android_alert", "critical": True},
]
json.dump(cfg, open(path, "w"), indent=4, ensure_ascii=False)
PY

# 2) Profile picture in the dashboard = the cat
cp -f /usr/share/pixmaps/mewarch.png "$HOME/.face" 2>/dev/null || true

# 3) Hello notification when Hyprland starts (Caelestia's Hyprland config is Lua)
HYPR_USER="$HOME/.config/caelestia/hypr-user.lua"; touch "$HYPR_USER"
sed -i '/-- >>> mewarch-cute >>>/,/-- <<< mewarch-cute <<</d' "$HYPR_USER"
cat >> "$HYPR_USER" <<'EOF'
-- >>> mewarch-cute >>>
hl.on("hyprland.start", function()
    hl.exec_cmd([[sleep 4 && notify-send -i /usr/share/pixmaps/mewarch.png "hiii >w<" "MewArch is ready :3"]])
end)
-- <<< mewarch-cute <<<
EOF

# 4) Cute greeting in every new terminal (fish and bash)
mkdir -p "$HOME/.config/fish/conf.d"
cat > "$HOME/.config/fish/conf.d/50-mewarch-greeting.fish" <<'EOF'
if status is-interactive; and test -n "$WAYLAND_DISPLAY"
    set -l faces ">w<" ":3" "owo" "(=^･ω･^=)" "(◕ᴗ◕✿)" "ᓚᘏᗢ" "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧" "uwu"
    set_color f5a9b8; echo "  hiii $USER "(random choice $faces); set_color normal
end
EOF
if ! grep -q 'mewarch-greeting' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'EOF'
# mewarch-greeting
if [[ $- == *i* && -n $WAYLAND_DISPLAY ]]; then
  _f=(">w<" ":3" "owo" "(=^･ω･^=)" "(◕ᴗ◕✿)" "ᓚᘏᗢ" "uwu"); printf '\e[38;2;245;169;184m  hiii %s %s\e[0m\n' "$USER" "${_f[RANDOM % ${#_f[@]}]}"
fi
EOF
fi
echo "MewArch: cute user tweaks applied >w<"
