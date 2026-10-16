# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `docs/09-windows-driver.md` — how to get HP's Windows driver per Windows version.
- `docs/10-other-distros.md` — server setup on Fedora/RHEL, Arch, openSUSE, NixOS, Gentoo, Alpine.
- `docs/11-bsd-and-others.md` — FreeBSD, OpenBSD, NetBSD, and other host OSes.
- `docs/README.md` — documentation index.
- `assets/` — SVG diagrams: banner, print pipeline, firmware flow, sharing overview,
  troubleshooting decision tree.
- Full cross-platform compatibility matrix (Windows/macOS/Linux/iOS/Android/ChromeOS/BSD/...).
- `.github/workflows/lint.yml` — shellcheck + markdownlint + firmware checksum CI.
- Resilient firmware auto-loader (`systemd/hplj1020-firmware.service`, `scripts/hplj1020-firmware-upload.sh`,
  `udev/85-hplj1020-firmware.rules`) to survive modern systemd-udevd process-group teardown.
- `scripts/install-firmware-loader.sh` to deploy the resilient loader and neutralise the
  backgrounded stock foo2zjs helper.

### Fixed

- **Firmware upload regression on modern systemd/udev**: the foo2zjs `hplj1020` helper backgrounds
  its upload subshell (`( ... ) &`) and returns immediately; on recent systemd-udevd
  (>= 255.4-1ubuntu8.18) the worker process group is killed at RUN+= completion, aborting the
  transfer before `FWVER` is written. Added a systemd-driven synchronous uploader (and udev
  trigger) so the upload completes reliably on every USB attach/power cycle. Documentation
  updated (docs/03-firmware.md) and installer scripts now deploy the resilient loader.

## [1.0.0] - 2026-10-15

### Added

- Initial release.
- `docs/01..08` — symptoms, diagnosis, firmware (with the `arm2hpdl` format trap), CUPS queue,
  Windows sharing (CUPS IPP + Samba + `wsdd`), cross-platform use, troubleshooting, migration.
- `scripts/install-firmware.sh` and `scripts/restore-printer-and-shares.sh` (idempotent).
- `config/` — `smb.conf`, reference `cupsd.conf`, working foo2zjs PPD.
- `systemd/` — `wsdd.service` and Samba mount-dependency drop-ins.
- `firmware/sihp1020.dl` — the ACL/PJL firmware (md5 `0cd1ac3a4f6cb7995e99deffff840927`).
- MIT license.

[Unreleased]: https://github.com/Orthodox2000/hp-laserjet-1020-linux/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Orthodox2000/hp-laserjet-1020-linux/releases/tag/v1.0.0
