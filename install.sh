#!/usr/bin/env bash
# =============================================================================
#  MewArch >w< — post-install tuner for Arch Linux (arch-caelestia-lite + cute theme)
#  Hyprland + Caelestia shell, NVIDIA (incl. Optimus laptops), low RAM,
#  network tuning, no display manager.
#
#  Run this on a FRESH, minimal Arch install (archinstall "minimal" profile),
#  logged in as your normal user (with sudo), with internet working.
#
#  Usage:  ./install.sh [--lite] [--zen] [--no-caelestia] [--yes]
#     --lite          MewArch Lite: full Caelestia, trimmed for the lowest RAM/GPU use
#     --zen           install linux-zen kernel (lower latency desktop kernel)
#     --no-caelestia  skip the Caelestia dots (only do the system tuning)
#     --yes           don't ask before each section
# =============================================================================
set -euo pipefail

LITE=0; ZEN=0; CAELESTIA=1; YES=0
for a in "$@"; do
  case "$a" in
    --lite) LITE=1 ;;
    --zen) ZEN=1 ;;
    --no-caelestia) CAELESTIA=0 ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 1 ;;
  esac
done

c_info(){ printf '\e[1;36m==>\e[0m %s\n' "$*"; }
c_warn(){ printf '\e[1;33m!! \e[0m %s\n' "$*"; }
c_err(){  printf '\e[1;31mxx \e[0m %s\n' "$*" >&2; }
ask(){ [[ $YES == 1 ]] && return 0; read -rp "$1 [Y/n] " r; [[ -z $r || $r =~ ^[Yy] ]]; }
pac(){ sudo pacman -S --needed --noconfirm "$@"; }
aur(){ paru -S --needed --noconfirm "$@"; }
write_root(){ sudo install -Dm644 /dev/stdin "$1"; }   # write stdin to a root-owned file

# ----------------------------------------------------------------- preflight --
[[ $EUID -eq 0 ]] && { c_err "Run as your normal user, not root."; exit 1; }
[[ -f /etc/arch-release ]] || { c_err "This script is for Arch Linux."; exit 1; }
ping -c1 -W3 archlinux.org &>/dev/null || { c_err "No internet."; exit 1; }
sudo -v

# --------------------------------------------------------- hardware detection --
GPU_LINES=$(lspci -nn | grep -Ei 'vga|3d|display' || true)
HAS_NVIDIA=0; HAS_INTEL=0; HAS_AMD=0
grep -qi 'nvidia' <<<"$GPU_LINES" && HAS_NVIDIA=1
grep -qi 'intel'  <<<"$GPU_LINES" && HAS_INTEL=1
grep -Eqi 'amd|ati' <<<"$GPU_LINES" && HAS_AMD=1
OPTIMUS=0
[[ $HAS_NVIDIA == 1 && ( $HAS_INTEL == 1 || $HAS_AMD == 1 ) ]] && OPTIMUS=1
LEGACY_NV=0   # Maxwell/Pascal (GTX 9xx/10xx, MX1xx-3xx) are not supported by the 590+ driver
grep -Eqi 'GTX (9[0-9]{2}|10[0-9]{2})|MX ?[1-3][0-9]{2}|Quadro [MP][0-9]|GT 10[0-9]{2}' <<<"$GPU_LINES" && LEGACY_NV=1
CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')

c_info "GPUs found:"; echo "$GPU_LINES" | sed 's/^/    /'
c_info "NVIDIA=$HAS_NVIDIA  Optimus/hybrid=$OPTIMUS  legacy-NVIDIA=$LEGACY_NV  CPU=$CPU_VENDOR"

# ---------------------------------------------------------------- 1. pacman --
if ask "1) Tune pacman/makepkg (parallel downloads, multilib, fast mirrors)?"; then
  sudo sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
  grep -q '^Color' /etc/pacman.conf || sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
  # enable [multilib] (needed for 32-bit NVIDIA libs / Steam)
  sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
  sudo sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j$(nproc)\"/" /etc/makepkg.conf
  # skip compressing AUR packages you build yourself (much faster builds)
  sudo sed -i "s/^PKGEXT=.*/PKGEXT='.pkg.tar'/" /etc/makepkg.conf
  sudo pacman -Sy --needed --noconfirm reflector   # -y: refresh so the newly enabled [multilib] db exists
  # test only mirrors near you (country from your IP), short timeouts, then add the
  # worldwide GeoDNS mirror as a fallback at the top
  CC=$(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null | tr -d '[:space:]')
  RARGS=(--protocol https --age 24 --fastest 5 --download-timeout 3 --connection-timeout 3)
  if [[ $CC =~ ^[A-Z]{2}$ ]]; then RARGS+=(--country "$CC"); else RARGS+=(--latest 10); fi
  sudo reflector "${RARGS[@]}" --save /etc/pacman.d/mirrorlist || c_warn "reflector failed, keeping mirrors"
  sudo sed -i '1i Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' /etc/pacman.d/mirrorlist
  sudo pacman -Syu --noconfirm
fi

# ------------------------------------------------------------ 2. base + paru --
c_info "2) Base tools + paru (AUR helper)"
pac base-devel git fish curl wget pciutils usbutils
if ! command -v paru &>/dev/null; then
  tmp=$(mktemp -d); git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru"
  (cd "$tmp/paru" && makepkg -si --noconfirm); rm -rf "$tmp"
fi

# --------------------------------------------------------------- 3. kernel --
KERNELS=()
for k in linux linux-zen linux-lts linux-hardened; do pacman -Q "$k" &>/dev/null && KERNELS+=("$k"); done
if [[ $ZEN == 1 ]]; then pac linux-zen linux-zen-headers; KERNELS+=(linux-zen); fi
HEADERS=(); for k in "${KERNELS[@]}"; do HEADERS+=("$k-headers"); done
pac "${HEADERS[@]}"
case "$CPU_VENDOR" in GenuineIntel) pac intel-ucode ;; AuthenticAMD) pac amd-ucode ;; esac

# ---------------------------------------------------------------- 4. NVIDIA --
if [[ $HAS_NVIDIA == 1 ]] && ask "4) Install + configure NVIDIA driver (Optimus-aware)?"; then
  if [[ $LEGACY_NV == 1 ]]; then
    c_warn "Older NVIDIA GPU detected -> using the 580xx legacy branch from the AUR."
    aur nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils
  else
    pac nvidia-open-dkms nvidia-utils lib32-nvidia-utils
  fi
  pac egl-wayland libva-nvidia-driver nvidia-settings
  [[ $OPTIMUS == 1 ]] && pac nvidia-prime     # gives you: prime-run <app>

  # KMS + framebuffer; RTD3 runtime power management so the dGPU sleeps on Optimus
  write_root /etc/modprobe.d/nvidia.conf <<'EOF'
options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_UsePageAttributeTable=1
options nvidia NVreg_DynamicPowerManagement=0x02
EOF
  # let the dGPU power down when idle (RTD3)
  write_root /etc/udev/rules.d/80-nvidia-pm.rules <<'EOF'
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
EOF
  # stable names for each GPU (paths in /dev/dri/by-path contain ':' which breaks AQ_DRM_DEVICES)
  write_root /etc/udev/rules.d/61-gpu-names.rules <<'EOF'
KERNEL=="card*", SUBSYSTEM=="drm", ATTRS{vendor}=="0x10de", SYMLINK+="dri/gpu-nvidia"
KERNEL=="card*", SUBSYSTEM=="drm", ATTRS{vendor}=="0x8086", SYMLINK+="dri/gpu-intel"
KERNEL=="card*", SUBSYSTEM=="drm", ATTRS{vendor}=="0x1002", SYMLINK+="dri/gpu-amd"
EOF
  sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
  if [[ $OPTIMUS == 0 ]]; then
    # desktop with NVIDIA only: early-load the driver
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/MODULES=( /MODULES=(/' /etc/mkinitcpio.conf
  fi
  # 'kms' hook loads nouveau early – remove it so it never fights the NVIDIA driver
  sudo sed -i 's/ kms / /' /etc/mkinitcpio.conf
  sudo mkinitcpio -P
fi

# -------------------------------------------------------- 5. low RAM tuning --
if ask "5) Low-RAM tuning (zram, sysctl, journald, no display manager)?"; then
  pac zram-generator
  write_root /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
  write_root /etc/sysctl.d/90-memory.conf <<'EOF'
# tuned for zram swap (from the Arch wiki / Pop!_OS defaults)
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
vm.vfs_cache_pressure = 50
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 67108864
EOF
  sudo mkdir -p /etc/systemd/journald.conf.d
  write_root /etc/systemd/journald.conf.d/size.conf <<'EOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=20M
EOF
  # disable hardware watchdogs (saves a little RAM/CPU, faster shutdown)
  write_root /etc/modprobe.d/nowatchdog.conf <<'EOF'
blacklist iTCO_wdt
blacklist sp5100_tco
EOF
  write_root /etc/sysctl.d/91-misc.conf <<'EOF'
kernel.nmi_watchdog = 0
EOF
  # turn off things a minimal desktop doesn't need, if present
  for s in cups.service cups.socket avahi-daemon.service avahi-daemon.socket \
           ModemManager.service sddm.service gdm.service lightdm.service; do
    systemctl list-unit-files "$s" &>/dev/null && sudo systemctl disable --now "$s" 2>/dev/null || true
  done
fi

# --------------------------------------------------------- 6. performance --
if ask "6) Performance tuning (I/O schedulers, TRIM, power profiles, irqbalance)?"; then
  pac power-profiles-daemon irqbalance
  sudo systemctl enable power-profiles-daemon irqbalance fstrim.timer
  write_root /etc/udev/rules.d/60-ioschedulers.rules <<'EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
EOF
fi

# ------------------------------------------------------------- 7. network --
if ask "7) Network tuning (BBR, fq, buffers, iwd backend, DNS-over-TLS)?"; then
  pac networkmanager iwd systemd-resolvconf
  write_root /etc/sysctl.d/92-network.conf <<'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 131072
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 131072 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
EOF
  echo tcp_bbr | write_root /etc/modules-load.d/bbr.conf
  # iwd backend: lighter than wpa_supplicant, faster Wi-Fi connects
  write_root /etc/NetworkManager/conf.d/10-iwd.conf <<'EOF'
[device]
wifi.backend=iwd
EOF
  # Wi-Fi power saving off = lower latency / fewer drops
  write_root /etc/NetworkManager/conf.d/20-wifi-powersave.conf <<'EOF'
[connection]
wifi.powersave = 2
EOF
  write_root /etc/NetworkManager/conf.d/30-dns.conf <<'EOF'
[main]
dns=systemd-resolved
EOF
  sudo mkdir -p /etc/systemd/resolved.conf.d
  write_root /etc/systemd/resolved.conf.d/dns.conf <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 9.9.9.9#dns.quad9.net
FallbackDNS=1.0.0.1#cloudflare-dns.com 149.112.112.112#dns.quad9.net
DNSOverTLS=opportunistic
DNSSEC=no
Cache=yes
EOF
  sudo systemctl disable --now wpa_supplicant.service 2>/dev/null || true
  sudo systemctl enable systemd-resolved NetworkManager
  sudo systemctl disable iwd.service 2>/dev/null || true   # NM starts iwd itself
fi

# ----------------------------------------------- 8. Hyprland + Caelestia --
if [[ $CAELESTIA == 1 ]] && ask "8) Install Hyprland + Caelestia dots?"; then
  pac hyprland xdg-desktop-portal-hyprland pipewire pipewire-pulse wireplumber
  DOTS="$HOME/.local/share/caelestia"
  [[ -d $DOTS ]] || git clone https://github.com/caelestia-dots/caelestia.git "$DOTS"
  (cd "$DOTS" && fish ./install.fish --noconfirm) || c_warn "Caelestia installer reported an error – check output above."
fi

# ---------------------------------------- 9. Hyprland GPU / perf user config --
# Caelestia's Hyprland config is Lua now: user overrides live in ~/.config/caelestia/hypr-user.lua
c_info "9) Writing Hyprland GPU + performance overrides (hypr-user.lua)"
HYPR_USER="$HOME/.config/caelestia/hypr-user.lua"
mkdir -p "$(dirname "$HYPR_USER")"; touch "$HYPR_USER"
sed -i '/-- >>> mewarch-gpu >>>/,/-- <<< mewarch-gpu <<</d' "$HYPR_USER"
{
  echo "-- >>> mewarch-gpu >>>"
  if [[ $HAS_NVIDIA == 1 && $OPTIMUS == 1 ]]; then
    IGPU=gpu-intel; [[ $HAS_INTEL == 0 ]] && IGPU=gpu-amd
    cat <<EOF
-- Optimus: desktop runs on the integrated GPU, NVIDIA sleeps. Games: prime-run <app>
hl.env("AQ_DRM_DEVICES", "/dev/dri/$IGPU:/dev/dri/gpu-nvidia")
hl.env("NVD_BACKEND", "direct")
EOF
  elif [[ $HAS_NVIDIA == 1 ]]; then
    cat <<'EOF'
-- NVIDIA-only desktop
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("NVD_BACKEND", "direct")
EOF
  fi
  cat <<'EOF'
-- only redraw when something changes
hl.config({ misc = { vfr = true, disable_splash_rendering = true } })
EOF
  echo "-- <<< mewarch-gpu <<<"
} >> "$HYPR_USER"
# old-format file from earlier MewArch versions is ignored by Caelestia now
rm -f "$HOME/.config/caelestia/hypr-user.conf.mewarch-old"
[[ -f $HOME/.config/caelestia/hypr-user.conf ]] && mv "$HOME/.config/caelestia/hypr-user.conf" "$HOME/.config/caelestia/hypr-user.conf.mewarch-old"

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -Dm755 "$KIT_DIR/lite/apply-lite-user.sh" "$HOME/.local/bin/mewarch-lite"
LITE=$LITE OPTIMUS=$OPTIMUS "$HOME/.local/bin/mewarch-lite"   # Optimus GPU fix always, trims only with --lite
if [[ $LITE == 1 ]]; then
  c_info "9b) MewArch Lite: trimming the system around Caelestia"
  # bigger zram for low-RAM machines (compressed, so this costs little)
  sudo sed -i 's/^zram-size = .*/zram-size = min(ram, 8192)/' /etc/systemd/zram-generator.conf 2>/dev/null || true
  # no Bluetooth adapter -> don't run the Bluetooth service
  if [[ -z $(ls /sys/class/bluetooth 2>/dev/null) ]]; then sudo systemctl disable --now bluetooth.service 2>/dev/null || true; fi
fi

# ----------------------------------------- 10. start Hyprland from TTY1 --
# No display manager = ~60-150 MB less RAM than SDDM/GDM.
c_info "10) Auto-start Hyprland on TTY1 login (no display manager)"
START='if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  if command -v start-hyprland >/dev/null; then exec start-hyprland; else exec Hyprland; fi
fi'
grep -q 'arch-caelestia-lite' "$HOME/.bash_profile" 2>/dev/null || \
  printf '\n# arch-caelestia-lite\n%s\n' "$START" >> "$HOME/.bash_profile"
mkdir -p "$HOME/.config/fish/conf.d"
cat > "$HOME/.config/fish/conf.d/00-hyprland-autostart.fish" <<'EOF'
# arch-caelestia-lite
if status is-login; and test -z "$WAYLAND_DISPLAY"; and test (tty) = /dev/tty1
    if command -q start-hyprland; exec start-hyprland; else; exec Hyprland; end
end
EOF

# --------------------------------------------- 11. MewArch cute theme >w< --
c_info "11) MewArch cute theme (cat launcher button, kaomoji, OS name) >w<"
KIT="$(cd "$(dirname "$0")" && pwd)"
pac libnotify python
sudo install -d /usr/local/share/mewarch
sudo install -m644 "$KIT"/assets/mew-icon*.png /usr/local/share/mewarch/
sudo install -Dm755 "$KIT/cute/apply-cute-system.sh" /usr/local/bin/mewarch-cute-system
sudo install -Dm644 "$KIT/cute/mewarch-cute.hook" /etc/pacman.d/hooks/mewarch-cute.hook
sudo /usr/local/bin/mewarch-cute-system
install -Dm755 "$KIT/cute/apply-cute-user.sh" "$HOME/.local/bin/mewarch-cute"
"$HOME/.local/bin/mewarch-cute"

# first-boot helper from the ISO installer may have raised sudo's timeout; undo it
sudo rm -f /etc/sudoers.d/00-mewarch-firstboot

# ------------------------------------------------------------- done --
mkdir -p "$HOME/.local/bin"
cp "$(dirname "$0")/memcheck.sh" "$HOME/.local/bin/memcheck" 2>/dev/null && chmod +x "$HOME/.local/bin/memcheck" || true
c_info "All done. Reboot, log in on TTY1 and Hyprland + Caelestia will start."
[[ $OPTIMUS == 1 ]] && c_info "Optimus: run games with 'prime-run <app>'. Check dGPU sleep: cat /sys/bus/pci/devices/*/power/runtime_status"
c_info "Check RAM after login with:  memcheck"
