<div align="center">

# 🖥️ Headless Desktop Manager

**Desktop, virtual display and RustDesk management for Linux**

[![Version](https://img.shields.io/badge/version-v0.3.7-2f81f7)](CHANGELOG.md)

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
