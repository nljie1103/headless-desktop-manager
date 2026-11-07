<div align="center">

# Headless Desktop Manager (HDM)

### An interactive installer and manager for headless Linux desktops

**GNOME first · Virtual displays · RustDesk · Recovery safeguards**

[简体中文](README.md) · **English** · [AI development specification](docs/AI_DEVELOPMENT_SPEC.md)

</div>

> [!WARNING]
> **v0.2.0 is a preview, not a production-validated deployment.** GNOME graphical capture, software rendering without a GPU and cold-boot unattended connections still require validation on a real cloud VM.

## Features

- Terminal menus: 10 main categories and 473 navigable items. Experimental/unsupported actions explicitly say so.
- Default target: Ubuntu 24.04 x86_64, full GNOME, GDM3/X11, Xorg Dummy, RustDesk.
- Optional: XFCE/MATE, isolated Xvfb, VKMS detection (experimental).
- Native distro package management first; trusted Ubuntu mirror fallback for network failures. RustDesk from official releases with checksums where available.
- Backups and a timed configuration rollback for display/login changes.
- Windows automatic publisher, with a version-prefixed, release-specific commit title.

## Install

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
sudo hdm
```

The above command fetches a **mutable development branch**. Inspect the source and prefer independently verified tagged releases for production. Installing HDM does not silently install GNOME or RustDesk. Use menu **9 → 9.1 → 9.1.6** to request the default stack installation.

## Security and acceptance

Keep SSH, a recovery console and a VM snapshot available before changing display services. No automatic firewall or SSH changes, auto-login, or forced reboot. Confirm tested display changes using `sudo hdm --confirm-display` before the rollback timer expires. RustDesk remote capture and authentication must be tested from a separate client after a reboot.

## Repository layout

- [`docs/AI_DEVELOPMENT_SPEC.md`](docs/AI_DEVELOPMENT_SPEC.md): complete requirements and menu specification.
- [`docs/implementation-status.md`](docs/implementation-status.md): implemented features and testing limits.
- [`docs/COMMIT_POLICY.md`](docs/COMMIT_POLICY.md): version-prefixed truthful commit titles.
- [`docs/testing-and-limitations.md`](docs/testing-and-limitations.md): deployment acceptance criteria.

```bash
bash tests/run.sh
```

RustDesk is an independent upstream project. See [LICENSE](LICENSE) for this repository's license.
