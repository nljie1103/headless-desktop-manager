<div align="center">

# 🖥️ Headless Desktop Manager

**HDM · Linux headless desktop and RustDesk management**

Configure XFCE, GNOME or MATE, display outputs, graphical login sessions and remote access.

[![Version](https://img.shields.io/badge/Version-v5.0.0-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
[![License](https://img.shields.io/badge/License-MIT-378a64?style=for-the-badge)](LICENSE)

[简体中文](README.md) · **English** · [Releases](https://github.com/nljie1103/headless-desktop-manager/releases)

</div>

---

## 🚀 Quick start

Run on Ubuntu:

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

Then open the menu:

```bash
sudo hdm
```

The installer deploys **HDM itself**, not an entire desktop without asking. `main` is mutable; review the script or use a [pinned Release](https://github.com/nljie1103/headless-desktop-manager/releases). Keep SSH/provider-console access when configuring a remote host.

## ✨ Features

| Menu | Actions |
|---|---|
| **1 · Display output** | Inspect DRM/KMS, adjust resolution, optionally manage Dummy/Xvfb/VKMS |
| **2 · Login manager** | Install/remove LightDM or GDM3, start/stop, choose default |
| **3 · Graphics protocol** | Inspect X11/Wayland and choose a supported desktop login stack |
| **4 · Desktops** | Independently install, update or remove XFCE, GNOME or MATE |
| **5 · Graphical sessions** | Inspect sessions, prepare login greeter, view details, terminate safely |
| **6 · RustDesk** | Install/update, service control, passwords, **permission management** and diagnostics |
| **7 · Device ID** | View RustDesk ID and configure ID/relay servers |
| **8 · HDM** | Guided setup, readiness, update, diagnostics, logs and removal |

The home screen shows the seven-node dependency axis in the same order as menus 1–7. Green means the corresponding **local** prerequisite is ready, not that RustDesk remote capture or reboot recovery has been externally verified.

## 🔐 RustDesk permissions

Open **`6 → 11 Permission management`** for Full Access, View Only, custom presets, or individual input, clipboard, file transfer, audio, TCP tunnel, remote restart and recording permissions. **`6 → 12`** diagnoses greyed-out GUI settings, Polkit and user/service configuration.

Configuration writes are snapshotted, verified for both root and the logged-in user, and rolled back on errors. Changing permissions on an active service may disconnect RustDesk briefly and requires one safety confirmation. A greyed-out RustDesk GUI can instead be caused by a missing XFCE Polkit authentication agent, missing Unlock authorization, or higher-priority server policies. See [RustDesk security settings](https://rustdesk.com/docs/en/self-host/client-configuration/advanced-settings/).

## 🧭 Compatibility and limitations

| Host | Recommended stack | Verification |
|---|---|---|
| Ubuntu 26.04 ARM64 | **XFCE + X11 + LightDM + RustDesk** | Real-world greeter and XFCE user session reached remotely; reboot and lock screen still require separate testing |
| Ubuntu 26.04 x86_64 | XFCE/X11 or GNOME/Wayland | Depends on graphics output and session support |
| Ubuntu 24.04 x86_64 / ARM64 | XFCE, MATE or GNOME | Code/package verification does not certify every remote host |

**DRM/KMS** is a kernel display interface, not an alternative to X11 or Wayland. Xorg commonly provides X11; the display manager provides the login greeter. Do not install Dummy, Xvfb and VKMS simply because they exist in the menu.

Ubuntu 26 GNOME is Wayland-only. Do not force `WaylandEnable=false` to resurrect a removed GNOME Xorg session. For a traditional RustDesk login screen, XFCE + X11 / LightDM is a practical route, but verify login, keyboard/mouse, **Lock screen**, and cold reboot separately. See [Ubuntu 26 ARM64 notes](docs/ubuntu26-arm64.md) and [testing/limitations](docs/testing-and-limitations.md).

## ⌨️ Commands

| Command | Purpose |
|---|---|
| `sudo hdm` | Menu |
| `hdm --chain` | Seven-node dependency chain |
| `hdm --readiness` | Required packages and service readiness |
| `hdm --doctor` | Read-only checks |
| `hdm --rustdesk-permissions` | Read-only GUI authorization diagnostic |
| `sudo hdm --export-diagnostics` | Export redacted diagnostics |

## 🗂️ Project structure and data storage

```text
hdm.sh       Menu entry point
install.sh   Installer
ui/          Menu definitions and action dispatch
modules/     Display, desktops, RustDesk, sessions, diagnostics
scripts/     Configuration validation and menu generator
config/      Compatibility and version metadata
tests/       Regression suite
docs/        Guides
```

HDM versions live under `/opt/hdm/`, HDM configuration under `/etc/hdm/`, snapshots in `/var/lib/hdm/`, and operational logs in `/var/log/hdm/`.

[Installation](docs/installation.md) · [Menu guide](docs/menu-guide.md) · [Issues](https://github.com/nljie1103/headless-desktop-manager/issues) · [MIT License](LICENSE)
