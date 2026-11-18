# MewArch >w<

Arch Linux + Hyprland + Caelestia, tuned for low RAM, fast networking and NVIDIA / Optimus laptops, with a cute theme.

<img src="assets/mew-icon-128.png" width="96"> ← the bar's launcher button

## Get the ISO

My build workspace can't reach the Arch package mirrors, so the ISO has to be built on your side. There are two ways to do it:

**A. On GitHub (no Arch machine needed)**
1. Create a new GitHub repo and upload everything in this folder, including the hidden `.github` folder.
2. Go to **Actions → Build MewArch ISO → Run workflow**.
3. After about 10–15 minutes, download **mewarch-iso** from the finished run. It's a .zip containing `mewarch-…-x86_64.iso`.

**B. On an existing Arch install**
```bash
sudo pacman -S --needed archiso
sudo ./iso/build-iso.sh          # ISO ends up in ./out/
```

Flash it with Ventoy, Rufus (DD mode), balenaEtcher or `dd`.

## Install

1. Boot the USB. Turn off Secure Boot, the same as with regular Arch.
2. Connect to the internet. For Wi-Fi, run `iwctl` and then `station wlan0 connect "name"`.
3. Type **`mewarch-install`**. It opens archinstall and shows you what to pick: **Minimal** profile, **NetworkManager**, a **sudo user** and **Pipewire**.
4. Reboot and log in on TTY1. MewArch then finishes setting itself up (it needs internet and takes a while because some AUR packages compile), and reboots into Hyprland + Caelestia.

Already running Arch? Skip the ISO and run `./install.sh --lite` as your user (leave out `--lite` for the full edition).

## Cute stuff

| Where | What |
|---|---|
| Bar launcher button | The cat icon (transparent background, full colour, slightly bigger). Click it to open the launcher |
| Workspaces | `:3` active · `•` has windows · `·` empty |
| Lock screen / dashboard / fastfetch | OS name **MewArch >w<**. The dashboard profile picture is the cat |
| Login | Notification: *"hiii >w< — MewArch is ready :3"* |
| Terminal | A random kaomoji greeting (`>w<`, `:3`, `owo`, `(=^･ω･^=)` …) |
| Low battery | Kaomoji warnings: *"hewwo?? battery at 10% >w<"* |

To change the kaomoji, edit the top of `~/.local/bin/mewarch-cute` and run it again. The bar is narrow, so keep workspace labels to 1–2 characters.

The launcher-button change edits one Caelestia file (`OsIcon.qml`). A pacman hook re-applies it automatically after each Caelestia update. `ID=arch` stays unchanged, so pacman, paru and the AUR still work normally.

## MewArch Lite (recommended, the installer's default)

Lite keeps the **full Caelestia shell**: bar, dashboard, launcher, notifications, lock screen and session menu. It trims everything around it:

| Lite change | Why it saves |
|---|---|
| Blur + shadows off, windows fully opaque | Blur uses extra frame buffers. On integrated graphics those come out of system RAM |
| Night light (gammastep + geoclue), Bluetooth media-key proxy and image clipboard history stopped | About 30–60 MB of background programs. Text clipboard history stays |
| `MALLOC_ARENA_MAX=2` for the session | Qt/Quickshell hold on to less unused memory |
| Fewer visualiser bars, slower dashboard refresh, desktop clock and background visualiser off | Less work for the shell |
| zram as big as your RAM (max 8 GB) | More room before anything slows down |
| Bluetooth service off when there's no Bluetooth adapter | One less service |

Animations stay on, since they barely use RAM and they're part of how Caelestia feels.

**Realistic idle RAM** (estimates, not yet measured on real hardware):

| Setup | Idle RAM |
|---|---|
| Arch, text console only, tuned | 150–250 MB |
| MewArch (full) | 650 MB – 1.1 GB |
| **MewArch Lite** | **roughly 500–800 MB** |

Most of what's left is Caelestia itself (Qt6 + Quickshell), and no setting removes that. Run `memcheck` after installing to see your real numbers.

Already installed without Lite? Run `LITE=1 mewarch-lite`, then log out and back in.

## What it does (both editions)

| Area | Changes |
|---|---|
| **pacman** | 10 parallel downloads, multilib, fastest mirrors (reflector), `-j$(nproc)` builds, paru |
| **NVIDIA** | `nvidia-open-dkms` (Turing / RTX and newer) or `nvidia-580xx` from the AUR (GTX 9xx/10xx), KMS + fbdev, suspend services, nouveau kept out |
| **Optimus** | Desktop runs on the iGPU and the NVIDIA card sleeps (RTD3). Caelestia's GPU monitor is switched to the iGPU, so it doesn't wake the NVIDIA card. Use `prime-run <app>` for games |
| **RAM** | zram (zstd), swappiness tuned for zram, journald capped at 50 MB, watchdogs off, no display manager, cups/avahi/ModemManager disabled |
| **Performance** | Per-disk I/O schedulers, weekly TRIM, power-profiles-daemon (Caelestia uses it), irqbalance, optional `linux-zen` |
| **Network** | BBR + fq, larger TCP buffers, TCP Fast Open, MTU probing, NetworkManager on **iwd**, Wi-Fi power-save off, DNS-over-TLS (Cloudflare + Quad9) |
| **Hyprland** | `vfr` on, NVIDIA / Optimus settings in `~/.config/caelestia/hypr-user.lua` |

## Useful commands

- `memcheck` shows RAM use by program, zram stats, and whether the NVIDIA card is asleep.
- `prime-run <app>` runs an app on the NVIDIA GPU (Optimus laptops).
- `mewarch-cute` re-applies the cute user settings.
- `LITE=1 mewarch-lite` applies (or re-applies) the Lite trims.
- Put your own Hyprland tweaks in `~/.config/caelestia/hypr-user.lua`. Caelestia's Hyprland config is Lua now; the old `.conf` file is ignored.

## Caveats

- This isn't tested on real hardware yet. The scripts are syntax-checked and the Caelestia patch was tested against Caelestia's current source.
- Black screen on Optimus: run `ls -l /dev/dri/` and swap the order in the `AQ_DRM_DEVICES` line of `hypr-user.lua`.
- Older NVIDIA cards (GTX 9xx/10xx, MX1xx–3xx) use the AUR `nvidia-580xx` driver. Detection is a name match, so check that it picked correctly.
- If a Caelestia update changes `OsIcon.qml` a lot, the patch skips itself and you get the stock tinted icon, not a crash.
