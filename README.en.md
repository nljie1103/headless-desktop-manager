<div align="center">

# 🖥️ Headless Desktop Manager

**Desktop, virtual display and RustDesk management for Linux**

[![Version](https://img.shields.io/badge/version-v0.3.9-2f81f7)](CHANGELOG.md)

[简体中文](README.md) · **English**

</div>

HDM provides a terminal menu for installing and managing GNOME, XFCE, MATE, virtual display drivers, RustDesk, ID/relay settings, updates, and diagnostics. Existing desktop and display configuration is preserved whenever possible.

## Install

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

The installer opens the menu automatically in an interactive terminal; automated runs do not block on a menu. To open it later, run `sudo hdm`. Set `HDM_NO_AUTO_MENU=1` to skip automatic menu entry.

## Main menu

| Number | Function | Number | Function |
|---|---|---|---|
| 1 | Install virtual display | 6 | Update RustDesk |
| 2 | Manage virtual display | 7 | ID / relay settings |
| 3 | Install desktop | 8 | Update HDM |
| 4 | Manage desktop | 9 | One-click setup |
| 5 | Install RustDesk | 10 | Diagnostics |

The interface uses two columns on wide terminals and one column on narrow terminals. The status header displays desktop, DRM output, X11/Wayland session, and RustDesk version.

## Capabilities and precautions

- **Desktop-first deployment:** prefer GNOME while detecting and retaining existing desktops and display outputs.
- **RustDesk:** enter, review, apply and read back the ID server, relay and complete server public key; passwords remain protected.
- **Recovery:** configuration backups, integrity checks and installation progress tracking.
- **Diagnostics:** `sudo hdm --preflight`, `sudo hdm --doctor`, `sudo hdm --check-update`.
- **Compatibility:** GNOME on Ubuntu 26 uses Wayland. Disabling GDM Wayland is not a screen-off switch, and legacy Xorg Dummy configurations do not automatically create a Wayland display. A live RustDesk service does not prove remote desktop capture is working.

Keep SSH and provider console access before changing remote display settings. The `main` installer follows a mutable branch; use a pinned archive hash when independent artifact integrity is required.

See the [Chinese main documentation](README.md), [changelog](CHANGELOG.md), and [menu guide](docs/menu-guide.md).

## Host sizing and display options

HDM preserves any installed desktop. On a new host it recommends XFCE below 4 GiB RAM and GNOME for 4 GiB or more; MATE is an optional manual choice. Typical idle RAM estimates: GNOME 1.2–2.0 GB, MATE 0.5–0.9 GB, XFCE 0.4–0.8 GB. Display drivers: Xorg Dummy (~40–200 MB, X11), Xvfb (~20–120 MB, separate X server), and VKMS (kernel DRM and compositor-dependent). These are rough planning estimates, not verified benchmarks. RustDesk permissions are configurable via menu `7 → 13`, including the remote-configuration toggle.

## Session troubleshooting and full diagnostics

The manager checks installed packages, DRM connectivity, GDM3 service state, logged-in user graphical sessions, and RustDesk service state separately. These results **do not verify remote screen capture**. Use:

```bash
sudo hdm --session-status
sudo hdm --session-start
sudo hdm --session-repair
sudo hdm --export-diagnostics
```

A diagnostics archive contains captured HDM operation logs and available apt/dpkg and GDM3/RustDesk journal evidence. It is stored in a root-only location with best-effort secret redaction; review before sharing. RustDesk local `.deb` installation now runs an APT dependency-resolution dry run before installing.

## Deployment readiness checklist

Run `sudo hdm --readiness` for an itemized overview of installed and missing desktop packages, running display services, graphical sessions, RustDesk installation, saved server settings, and the next required action. This check is read-only. See the [Chinese README](README.md) for the complete workflow.
