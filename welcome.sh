#!/usr/bin/env bash
# MewArch >w< welcome screen without a display manager.
# Boot -> auto-login on TTY1 -> Hyprland starts -> Caelestia lock screen appears
# straight away, so you "log in" on Caelestia's own password screen.
#   ./welcome.sh        turn it on   (run as your normal user, after install.sh)
#   ./welcome.sh --off  back to the normal text login
set -euo pipefail
DROPIN=/etc/systemd/system/getty@tty1.service.d/autologin.conf
HU="$HOME/.config/caelestia/hypr-user.lua"
mkdir -p "$(dirname "$HU")"; touch "$HU"
sed -i '/-- >>> mewarch-welcome >>>/,/-- <<< mewarch-welcome <<</d' "$HU"

if [[ ${1:-} == --off ]]; then
  sudo rm -f "$DROPIN"
  sudo systemctl daemon-reload
  echo "Welcome screen off: you'll get the normal text login after reboot."
  exit 0
fi

# 1) auto-login on TTY1 only (other TTYs, Ctrl+Alt+F2..F6, still ask for a password)
sudo mkdir -p "$(dirname "$DROPIN")"
sudo tee "$DROPIN" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
EOF
sudo systemctl daemon-reload

# 2) lock the session as soon as Caelestia is up (retries until the shell answers)
cat >> "$HU" <<'EOF'
-- >>> mewarch-welcome >>>
-- Caelestia lock screen = welcome/login screen
hl.on("hyprland.start", function()
    hl.exec_cmd([[for i in $(seq 1 60); do qs -c caelestia ipc call lock lock >/dev/null 2>&1 && exit 0; sleep 0.5; done; loginctl lock-session]])
end)
-- <<< mewarch-welcome <<<
EOF

# 3) always lock before sleep / lid close (Caelestia default, forced on here)
python3 - "$HOME/.config/caelestia/shell.json" <<'PY2'
import json, os, sys
p = sys.argv[1]; cfg = {}
if os.path.exists(p):
    try: cfg = json.load(open(p))
    except Exception: os.rename(p, p + ".bak")
cfg.setdefault("general", {}).setdefault("idle", {})["lockBeforeSleep"] = True
json.dump(cfg, open(p, "w"), indent=4, ensure_ascii=False)
PY2

echo "Welcome screen on >w<  Reboot to see it:  sudo reboot"
echo "(Turn off again with:  ./welcome.sh --off)"
