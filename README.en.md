<div align="center">

# 🖥️ Headless Desktop Manager

**Linux headless desktop deployment, session diagnostics and RustDesk management**

Choose a practical desktop for each host: XFCE/X11 for conventional login-screen access on newer Ubuntu, with GNOME/Wayland and MATE available as alternatives.

[![Version](https://img.shields.io/badge/Version-v4.5.7-2473d1?style=for-the-badge)](https://github.com/nljie1103/headless-desktop-manager/releases)
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

The v4.5.7 menu follows the seven-stage desktop dependency axis exactly: **1 Display output**, **2 Login manager**, **3 Graphics protocol**, **4 Desktop environment**, **5 Graphical sessions**, **6 RustDesk**, **7 Device ID**, and **8 HDM maintenance / quick setup**. There are 74 entries, including 63 actions. All independent desktop and login-manager installation/removal functions are preserved. Explicit menu installs, updates, startup and auto-start toggles avoid redundant y/N prompts; destructive or remote-disruptive actions retain one safety check. The 481 legacy menu declarations remain internal, not presented as duplicate diagnostics.
---

## 🔗 Seven-stage dependency diagnostics (separate from the task menu)

The optional `hdm --chain` command shows **display output → login manager (GDM3/LightDM) → graphics protocol (X11/Wayland) → desktop environment → user session and verified resolution → RustDesk service → device ID**. The daily-use home screen shows the seven-node dependency axis without a redundant component inventory, legend or extra warning paragraphs. Detailed installed/missing package and service states remain available using `hdm --readiness`; other desktops, Dummy and Xvfb remain optional.

Green means the **local** check succeeded, red means a confirmed missing/broken component, and amber means more verification is needed. Green does not prove that an external RustDesk connection works. The main menu renders the compact responsive axis at every return to the home screen; `hdm --chain` provides detailed paths and explanations.

Use `sudo hdm --chain` for full paths and explanations, or `sudo env HDM_HIDE_RUSTDESK_ID=1 hdm` to hide the device ID in screen-sharing demos. [Desktop chain design and limitations](docs/desktop-chain.md).

v4.5.7 fixes the LightDM default-session save failure when an existing HDM-managed `99-zz-hdm-session.conf` was not on the backup allowlist. The authorization is exact-file-only and does not permit arbitrary LightDM configurations. Updating HDM does not modify the host login session.

Day-to-day paths: **2 → 3** start LightDM/GDM3, **3 → 1** inspect X11/Wayland/Xorg, **3 → 2** select a LightDM XFCE/MATE X11 session, **4 → 1** install XFCE without binding a login manager, **5 → 2** prepare the authenticated login greeter, **6 → 9** set the RustDesk password, **7 → 1** view device ID, and **8 → 4** update HDM.
### Graphical sessions and actual protocol management

The **5 Graphical sessions** menu lists authenticated sessions, prepares a new greeter, inspects a selected session and safely terminates it. The separate **3 Graphics protocol** menu reports installed X11/Wayland sessions and selects the matching LightDM X11 or GNOME/GDM3 Wayland login stack, subject to package checks. DRM cannot itself be switched to Wayland. Login-manager logs belong under **2**, and ID/relay settings under **7**.

Desktop environment installs are now **separate from display managers**: installing XFCE/GNOME/MATE does not explicitly reinstall LightDM/GDM3/Xorg; the guided full-stack installer still fills missing prerequisites. A host with many SSH sessions no longer reports graphical-session overflow just because the first 24 logind rows were occupied by SSH.

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

### Real desktop and login-manager removal in v4.4.1

Menu 2 provides both **APT removal previews** and actual guarded removal for GDM3/LightDM, plus an interactive system `dpkg-reconfigure` option to select the default manager. Menu 4 provides guarded GNOME/XFCE/MATE removal. A live replacement desktop/login manager, no conflicting user session, protected dependency checks and one explicit confirmation are required before `apt-get remove -y` runs. These actions never automatically purge configuration, run autoremove or restart the graphical service. On Ubuntu 26, install and verify XFCE/X11/LightDM **before** removing GNOME/GDM3.

### Resilient GitHub Release downloads (v4.4.1)

If the official GitHub Release asset link returns HTTP 504, HDM now retries via the corresponding GitHub Releases API asset ID, downloading **the same binary asset** and checking it against **the exact same SHA256 digest**. A configured locally trusted digest remains required when present. No third-party mirror or unverified source is substituted. Older HDM versions can use `8 → Update HDM → Install update → from main` for a commit-pinned HTTPS snapshot, which has a different trust model from a digest-verified formal Release.

### Simplified menus and uninstall-first workflow (v4.4.1)

Routine actions are direct: **2 → 2 → 1** removes GDM3, **4 → 2 → 1** removes GNOME, **4 → 1 → 2** installs XFCE + Xorg + LightDM; **6 → 1/2/3** installs/removes/updates RustDesk, and **8 → 1** updates HDM to the newest stable Release. A single confirmation is required for potentially disruptive package removal. APT dependency simulation runs automatically, rejecting plans that would remove protected SSH, RustDesk, Xorg, system packages or unrelated login managers. Users may remove the old desktop first and install the replacement afterwards; maintain an independent SSH/provider-console recovery path because a currently running graphical or RustDesk session can disconnect immediately. Older update channels, detailed package options and rollback remain available under Advanced Maintenance rather than being separate routine choices.

### v4.4.1 update permission fix

The official v4.4.0 tar update could install `hdm.sh` without an executable bit under a restrictive root umask, making `sudo hdm` appear missing. v4.4.1 fixes this before atomically switching versions and adds isolated umask-077 regression tests. If affected, run `sudo chmod 755 /opt/hdm/current/hdm.sh && sudo hdm` from SSH/provider console, then use menu **8 → 1** to update to the newest official Release. This does not modify desktop or RustDesk software.

### Fixed menu ID collision (v4.4.2)

Earlier releases v4.4.0/v4.4.1 erroneously compared the IDs `8.1` and `8.10` as equal in awk, making the direct HDM update action open an empty submenu. Use **8 → 10 → 1 → 2 → 2** to update these older installed versions to the latest official Release. With v4.4.2 installed, the normal one-click **8 → 1** action works correctly. All menu identifiers are now compared as exact strings, with an exhaustive menu-routing regression. If `sudo hdm` is unavailable after upgrading to v4.4.0, first repair the executable bit from SSH using `sudo chmod 755 /opt/hdm/current/hdm.sh`.

### v4.5.0: Direct actions, remove or purge, and intuitive Back

Historical note for v4.5.1 (not the current main menu): eight primary stages used the following paths: **2 → 3** removes GDM3, **4 → 4** removes GNOME, **4 → 1** installs XFCE + Xorg + LightDM, **6 → 1/2/3** manages RustDesk, **8 → 1** upgrades HDM. Detailed historical features remain grouped under Advanced Tools. Uninstall displays the APT dependency plan and then asks for just one choice: **1 Keep package configuration (remove)**, **2 Delete package-managed system configuration (purge)**, **0/q Cancel**. Both removal modes simulate their actual dependency plans and reject removal of unrelated protected system, SSH, RustDesk, or Xorg components. Purging does not delete user home directories or run autoremove. Lowercase **q** or **0** goes back one submenu, **Q** exits immediately, and **q** exits from the main menu only.

When `sudo hdm` is missing after upgrading from an older updater, correct the release-directory access permissions via SSH: `sudo chmod -R a+rX "$(sudo readlink -f /opt/hdm/current)" && sudo chmod 755 /opt/hdm/current/hdm.sh && sudo hdm`. That only changes HDM source permissions, not GNOME or RustDesk.

### v4.5.1: Multiple display managers and graphical user sessions

The seven-node chain distinguishes installed display managers, the configured default, and running GDM3/LightDM services. A second **installed** but inactive manager is listed as installed; if **both services** are active, or the configured default differs from the running one, the manager node becomes amber. When multiple graphical user sessions exist, protocol and desktop nodes show combinations such as `X11+Wayland` and `XFCE+GNOME`. The session node reports the count and session IDs rather than arbitrarily selecting the first user. RustDesk capture target is marked unverified: an active service and device ID cannot prove which session it controls. Xrandr resolution is attributed to a user session only when the DISPLAY matches the sole loginctl graphical session and X socket. Logind scans that reach their limit are explicitly inconclusive rather than incorrectly green.
