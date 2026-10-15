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
