<div align="center">

# 🖥️ Headless Desktop Manager

**Linux headless desktop deployment, session diagnostics and RustDesk management**

Choose a practical desktop for each host: XFCE/X11 for conventional login-screen access on newer Ubuntu, with GNOME/Wayland and MATE available as alternatives.

[![Version](https://img.shields.io/badge/Version-v4.3.0-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
[![License](https://img.shields.io/badge/License-MIT-378a64?style=for-the-badge)](LICENSE)

[简体中文](README.md) · **English** · [Releases](https://github.com/nljie1103/headless-desktop-manager/releases)

</div>

---

## ✨ Features

| Module | What it does |
|:---|:---|
| Desktops | Install and inspect GNOME, XFCE and MATE, preserving existing environments where possible |
| Virtual displays | Manage Xorg Dummy, Xvfb and VKMS, with protocol-aware checks |
| RustDesk | Install/update the client; manage ID, relay, public key, permissions and service status |
| Diagnostics | Separate packages, system services, actual GNOME sessions and remote display verification |
| Recovery | Installation resume, diagnostic export, configuration snapshots and version rollback |

**Installed packages, running services, a graphical session and a remotely controllable screen are different states.**

---

## 💻 Compatibility and verification

HDM maintains **ten Ubuntu release / architecture / display-stack configuration paths**. These are **not ten fully certified machines**.

| Platform | Current evidence | Remaining validation |
|:---|:---|:---|
| Ubuntu 24.04 x86_64 GNOME / X11 | Two independent Box environments; GNOME core, GDM3 and RustDesk 1.5.1 installed and tested as services | Actual GNOME login, virtual display capture and remote input |
| Ubuntu 24.04 ARM64 GNOME / X11 | Code and package manifests | Native install and end-to-end remote access |
| Ubuntu 24.04 x86_64 GNOME / Xvfb | Logic and unit tests | Live display and RustDesk session |
| Ubuntu 24.04 x86_64 GNOME / VKMS | Detection and unit tests | Kernel, compositor and remote capture |
| Ubuntu 26.04 ARM64 GNOME / Wayland | Earlier real-world GNOME 50.1, GDM3, RustDesk installation; display/session failure observed | Headless Wayland, lock screen and pre-login unattended access |
| Ubuntu 26.04 x86_64 GNOME / Wayland | Compatibility logic | Live Wayland/remote access |
| Ubuntu 26.10 ARM64 GNOME / Wayland | Compatibility logic | Native installation and complete remote access |
| Ubuntu 26.04 ARM64 XFCE / X11 / LightDM | Package path checked, simulated tests | Native login greeter, external remote control and reboot |
| Ubuntu 26.04 x86_64 XFCE / X11 / LightDM | Package path checked, simulated tests | Actual display manager and remote capture |
| Ubuntu 26.10 ARM64 XFCE / X11 / LightDM | Code path ready | Native installation and complete remote access |

**Fully verified headless boot-to-login-screen RustDesk combinations: zero.** The project's CI runs on Ubuntu 24.04 x86_64. Debian, Fedora and RHEL adapter directories are not a guarantee of complete platform support.

### Practical desktop selection

On Ubuntu 26, GNOME itself is Wayland-only but Xorg remains available for desktops such as **XFCE and MATE**. HDM's recommended plan for standard RustDesk login-screen scenarios is now **XFCE + Xorg + LightDM**. GNOME remains optional; existing desktops are never uninstalled automatically.

If DRM reports no connected output, the plan may offer Xorg Dummy behind an explicit configuration confirmation. Installing LightDM does not select it as the default login manager; inspect menu 4.4 and use provider console/SSH for any manual transition. Actual pre-login capture and reboot recovery **still require external tests**.

### Ubuntu 26 GNOME / Wayland

Ubuntu GNOME has been Wayland-only since Ubuntu 25.10; Ubuntu 26.04 ships GNOME 50. XWayland runs legacy X11 applications but **does not bring back a GNOME Xorg session**.

- **Logged-in desktop:** Standard RustDesk may capture through PipeWire and Desktop Portal, subject to user/session permissions.
- **Lock screen:** Distinct from the GDM login screen. Screen capture, input and unlock recovery need separate testing; do not assume success or failure just from the Wayland label.
- **Logged-out / reboot login greeter:** Standard RustDesk does not provide verified unattended capture of the Wayland greeter. RustDesk's newer Wayland unattended preview currently targets **x86_64 Debian/Ubuntu**, not a confirmed ARM64 solution.
- **Do not force `WaylandEnable=false` on Ubuntu 26 GNOME.** Xorg Dummy and Xvfb cannot create a GNOME Wayland display, and VKMS depends on real kernel/compositor support.

On November 7, 2026, the Ubuntu 26.04 ARM64 test host had GNOME 50.1 / GDM3 / RustDesk 1.5.1 installed, but a usable GNOME user session was not demonstrated, and RustDesk reported `cannot open display: :0`.

Sources: [Ubuntu release notes](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/) · [GNOME session changes](https://release.gnome.org/49/developers/) · [RustDesk Linux guide](https://rustdesk.com/docs/en/client/linux/) · [RustDesk Wayland preview](https://rustdesk.com/blog/unattended-remote-access-wayland/) · [ARM64 deployment notes](docs/ubuntu26-arm64.md).

---

## 📥 Install and start

> **Before changing a remotely hosted desktop:** preserve SSH, provider console access and a recoverable snapshot. Modifying a display manager or virtual display can interrupt the only remote session.

Prefer a [pinned GitHub Release](https://github.com/nljie1103/headless-desktop-manager/releases) with archive integrity verification. To install from the mutable `main` branch, inspect the script before running:

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
sudo hdm
```

Installing HDM **does not automatically install GNOME or change the display manager**. In an interactive terminal it opens the menu; `HDM_NO_AUTO_MENU=1` skips that auto-opening.

The CLI now uses **eight main entries**: stages 1–7 follow the seven-node desktop chain, and stage 8 manages the HDM script, logs, diagnostics and resumable installation. Install/uninstall/update/configuration actions live in the relevant submenus; long terminal lines wrap automatically. Existing implementation IDs are preserved through an explicit compatibility routing map. Use `0` to return from a submenu and `0` / `q` to exit at root. List the full structure using `hdm --menu-tree`.

---

## 🔗 Seven-stage desktop dependency graph and matching menu

The main menu now shows **display output → login manager (GDM3/LightDM) → graphics protocol (X11/Wayland) → desktop environment → user session and verified resolution → RustDesk service → device ID**.

Green means the **local** check succeeded, red means a confirmed missing/broken component, and amber means more verification is needed. Green does not prove that an external RustDesk connection works. Wide terminals show a horizontal progress axis; narrow terminals wrap or switch to a vertical flow. Versions, configuration paths and the locally queried RustDesk ID appear below each node where available.

Use `sudo hdm --chain` for full paths and explanations, or `sudo env HDM_HIDE_RUSTDESK_ID=1 hdm` to hide the device ID in screen-sharing demos. [Desktop chain design and limitations](docs/desktop-chain.md).

The main entries are: 1 Display outputs, 2 Display/login managers, 3 X11/Wayland protocols, 4 Desktop environments, 5 User graphical sessions, 6 RustDesk, 7 Device ID and host details, 8 HDM script and logs. **6** groups RustDesk installation, removal, upgrades, ID/relay/key and password configuration. **7** exposes the device ID, CPU architecture and software versions. **8** offers script updates and safe uninstallation (preserving configurations, logs and prior releases), changelog, installation logs, export, troubleshooting, backups and smart setup.

## ⌨️ Diagnostics and day-to-day commands

```bash
hdm --chain                 # Full seven-node desktop status and paths
hdm --preflight             # Desktop and display capability (read-only)
hdm --readiness             # Installed packages, services and sessions
hdm --doctor                # Active desktop/login manager/RustDesk diagnostics
hdm --session-status        # Generic session versus actual GNOME session
sudo hdm --session-start    # Try GDM3 startup and verify GNOME session
sudo hdm --quick-status     # Resumable install status
hdm --check-update         # Available HDM versions
sudo hdm --export-diagnostics
```

A running XFCE X11 session is **not** an active GNOME session, even when GDM3 is running.

---

## 🏗️ Architecture and storage

**Bash** powers the terminal UI, package management, display actions, systemd integration and rollback. **Python 3** implements configuration parsing, release validation, status reporting and diagnostic packaging.

```text
headless-desktop-manager/
├── hdm.sh / install.sh     # CLI and installation
├── ui/                     # Menu and action routing
├── core/                   # Packages, environment, download, backup
├── modules/                # Display, desktop, RustDesk, diagnostics, updater
├── config/                 # Defaults and compatibility
├── scripts/                # Support and validation tools
├── tests/                  # Regression tests
├── docs/                   # Operations and engineering guides
└── release/                # Release metadata
```

| Data | Location |
|:---|:---|
| Version installations and active pointer | `/opt/hdm/releases/`, `/opt/hdm/current` |
| HDM configuration | `/etc/hdm/config.conf` |
| Snapshots, pending rollback, exported reports | `/var/lib/hdm/` |
| Verified asset cache | `/var/cache/hdm/` |
| Operation logs | `/var/log/hdm/` |
| RustDesk per-account configuration | `~/.config/rustdesk/RustDesk2.toml` (including root's profile) |

Sensitive configuration/state folders use restricted permissions. Review exported diagnostic bundles before sharing; best-effort redaction is not a secrecy guarantee.

---

## 🧪 Tests and support

```bash
bash tests/run.sh
```

GitHub Actions additionally runs Bash syntax checks and ShellCheck. These tests **do not** validate remote screen capture, keyboard/mouse control, lock/unlock, pre-login access, or unattended reconnection after reboot.

See [full Chinese documentation](README.md), [production menu audit](docs/production-readiness.md), [test matrix](docs/testing-and-limitations.md), [menu guide](docs/menu-guide.md), [changelog](CHANGELOG.md), [security policy](SECURITY.md) and [issues](https://github.com/nljie1103/headless-desktop-manager/issues).

MIT licensed: [LICENSE](LICENSE).

<div align="center">

Maintained by [nljie1103](https://github.com/nljie1103).

</div>
