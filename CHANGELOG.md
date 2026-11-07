# Changelog

## 0.1.1 — 2026-11-07

- Fix Windows PowerShell 5.1 upload script parsing by writing a BOM-marked UTF-8 script with ASCII-only source.
- Fix Git wrapper argument passing and handle empty remote main branches safely.
- Show actual staged changes; require a human-reviewed, descriptive commit message prefixed with the exact version from `VERSION`.
- Add repository-wide commit-message policy, CI checks, and unit tests.
- Update the Windows upload command, docs and ZIP checksum for this patch release.


## 0.1.0 — 2026-11-07

- Initial modular Bash project with full menu specification and 473 navigable entries.
- Ubuntu 24.04 x86_64 guardrails; GNOME/Xorg Dummy/RustDesk orchestration.
- System APT preferred, temporary trusted Ubuntu mirror on recognized network errors.
- GitHub Release digest verification; no fabricated binary mirror assets.
- Snapshot and reboot-persistent recovery timer for hazardous display config changes.
- Windows PowerShell Git upload helper; static tests and GitHub Actions.
- Experimental / non-validated functionality is clearly labeled.
