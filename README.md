# Headless Desktop Manager (HDM)

中文说明：[README.zh-CN.md](README.zh-CN.md) · [Development specification](docs/AI_DEVELOPMENT_SPEC.md)

A modular, SSH-friendly, menu-driven installer/manager for Linux headless graphical desktops. **GNOME is the default and primary target**, with Xorg Dummy, RustDesk and recovery safeguards. XFCE, MATE, Xvfb and VKMS are available as options/experimental features. This is a **v0.1.1 preview**, not a validated zero-touch production deployment.

## Quick installation (after this source is pushed to GitHub)

```bash
curl -fsSLo hdm-install.sh https://raw.githubusercontent.com/nljie1103/headless-desktop-manager/main/install.sh && sudo bash hdm-install.sh
```

The installer will disclose that the `main` branch is mutable and require explicit confirmation before downloading source from the canonical GitHub repository. **For safer production installs, use a tagged release plus an independently verified SHA256/signature when one exists.** No stable release has been uploaded as part of this source archive.

To install from a verified local source checkout instead:

```bash
sudo bash install.sh --local
sudo hdm
```

## Default workflow

Use `sudo hdm` then choose **9 → 9.1 → 9.1.6** for the default deployment workflow: Xorg Dummy → GNOME / GDM3 → RustDesk. The tool does not automatically reboot, enable autologin, disable firewalls or turn off SSH. Connection, graphics rendering and cold-boot behavior MUST be confirmed from another machine. For dangerous display changes, HDM stores a snapshot and installs a persistent rollback timer; once verified run `sudo hdm --confirm-display` within the time shown.

Additional commands: `hdm --help`, `hdm --menu-tree`, `hdm --self-test`, `hdm --diagnose`.

## Limits in this development build

- **Only Ubuntu 24.04 x86_64 is writable.** Others display diagnostics only.
- The 10 main menus and 473 nested menu entries are present. Complex experimental items explicitly report unsupported instead of silently changing the OS. They are not all production-validated features.
- GNOME + Xorg Dummy is a proposed engineering configuration; actual virtual Xorg/GDM/RustDesk integration has not been tested on a cloud VM in this environment.
- RustDesk download is selected from official GitHub Release metadata only when a compatible native `.deb` and SHA256 are present. A GitHub backup package is used only if a **real file and verified manifest** are published. The mirror manifest is initially empty.
- HDM self-update requires SHA256 pre-trusted from an independent channel in `/etc/hdm/trusted-releases.tsv`; without that, updates fail safely.
- Password-setting via upstream `rustdesk --password` may expose a password to privileged process-list readers; the menu warns before enabling that route. Prefer the official GUI if the exposure is unacceptable.
- No claim of verified GNOME login capture, software rendering, unattended password login or reboot persistence is made before external testing.

## Security and recovery

- Maintain SSH / cloud rescue console and create cloud snapshots before modifying graphic/login services.
- HDM writes only a specific Xorg Dummy file and a GDM3 setting; backs up approved configuration files; does not replace the complete Xorg directory.
- Display changes can trigger `/etc/systemd/system/hdm-recovery.timer`, which restores the prior snapshot after about 7 minutes unless explicitly confirmed. Check `/var/lib/hdm/pending-rollback` if a rollback is pending.
- `docs/testing-and-limitations.md` describes exact acceptance tests and known limits.

## Repository

https://github.com/nljie1103/headless-desktop-manager

Open source licensing: see [LICENSE](LICENSE). RustDesk is a separate upstream project with its own license and releases.

**Git commit policy:** all commit subjects must start with `vX.Y.Z` followed by a truthful, concrete change description. See [`docs/COMMIT_POLICY.md`](docs/COMMIT_POLICY.md).
