<div align="center">

# Headless Desktop Manager (HDM)

### An interactive installer and manager for headless Linux desktops

**GNOME first · Virtual displays · RustDesk · Recovery safeguards**

[简体中文](README.md) · **English** · [AI development specification](docs/AI_DEVELOPMENT_SPEC.md)

</div>

> [!WARNING]
> **v0.3.6 is a preview, not a production-validated deployment.** GNOME graphical capture, software rendering without a GPU and cold-boot unattended connections still require validation on a real cloud VM.

## Features

- Terminal menus: 10 main categories and 473 navigable items. Experimental/unsupported actions explicitly say so.
- Default target: Ubuntu 24.04 x86_64, full GNOME, GDM3/X11, Xorg Dummy, RustDesk.
- Optional: XFCE/MATE, isolated Xvfb, VKMS detection (experimental).
- Native distro package management first; trusted Ubuntu mirror fallback for network failures. RustDesk from official releases with checksums where available.
- Backups and a timed configuration rollback for display/login changes.

## Install

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
sudo hdm
```

The above command fetches a **mutable development branch**. Inspect the source and prefer independently verified tagged releases for production. Installing HDM does not silently install GNOME or RustDesk. Use menu **9 → 9.1 → 9.1.6** to request the default stack installation.

## Resumable installation & diagnosis

The recommended GNOME/Xorg Dummy/RustDesk installer records step status and verifies real package/config state before skipping a step on retry. It does not infer GUI usability from an installation receipt. A failed step can be safely retried without manually redoing previously verified packages.

```bash
sudo hdm --doctor          # Read-only Chinese guidance and targeted menu actions
hdm --doctor-json          # Sanitized, machine-readable findings
sudo hdm --quick-status    # Installation ledger vs current state
sudo hdm --quick-resume    # Confirm and retry missing steps
```

See [resumable installer design](docs/resumable-install.md). On Ubuntu 24.04, the write path is deliberately restricted to x86_64; real GNOME capture and cold-boot unattended access still require independent validation.

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

> **Ubuntu 26 ARM64 testing:** The platform allowlist is removed for Linux test hosts. GNOME 49+ is Wayland-only; HDM will not force Xorg or `WaylandEnable=false`. Standard RustDesk ARM64 builds do not guarantee unattended pre-login capture. See [Ubuntu 26 ARM64 testing](docs/ubuntu26-arm64.md).

### Environment-aware preflight

Run `sudo hdm --preflight` to detect installed desktop packages, connected DRM outputs and live graphical sessions before installation. Existing desktops and display outputs are preserved by the quick install plan; uncertain detection never authorizes forcing Xorg/GDM changes. `sudo hdm --rustdesk-permissions` helps diagnose disabled Security/Network controls without bypassing Polkit. `WaylandEnable=false` is not a screen-blanking fix and must not be forced on Ubuntu 26 GNOME. Remote capture still requires real-world testing.


## Online updates

Use `sudo hdm --check-update` to inspect both published Releases and the pinned GitHub `main` preview. On test systems, run `sudo hdm --update-preview` or menu `8 → 2 → 5` to install a newer version of the manager from an immutable commit snapshot. Existing desktop/RustDesk packages are unaffected; previous HDM versions remain available for rollback. Preview downloads rely on GitHub HTTPS and commit pinning, not an independent signature.
