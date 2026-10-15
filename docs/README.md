# Documentation index

Start with the [main README](../README.md) for the quickstart. These pages go deep.

| # | Doc | Read it when... |
|---|-----|-----------------|
| 01 | [Symptoms](01-symptoms.md) | jobs "complete" but nothing prints |
| 02 | [Diagnosis](02-diagnosis.md) | you want to confirm it's the firmware |
| 03 | [Firmware](03-firmware.md) | the printer never reports `FWVER` (the real fix) |
| 04 | [CUPS queue](04-cups-queue.md) | building the driver/PPD/URI by hand |
| 05 | [Windows sharing](05-windows-sharing.md) | CUPS IPP + Samba + WS-Discovery (`wsdd`) |
| 06 | [Cross-platform](06-cross-platform.md) | using it from Windows/macOS/Linux/iOS/Android/... |
| 07 | [Troubleshooting](07-troubleshooting.md) | something is still wrong |
| 08 | [Migration](08-migration.md) | moving to a fresh Linux install |
| 09 | [Windows driver](09-windows-driver.md) | you want HP's driver for the SMB path |
| 10 | [Other distros](10-other-distros.md) | Fedora/RHEL/Arch/openSUSE/NixOS/Gentoo server |
| 11 | [BSD & other hosts](11-bsd-and-others.md) | FreeBSD/OpenBSD/NetBSD/other host OSes |

## Diagrams

All in [`../assets/`](../assets/): the print pipeline, the firmware flow, the sharing overview,
and a troubleshooting decision tree.

## The 10-second version

The HP LaserJet 1020 has **no firmware inside it**. The host must upload `sihp1020.dl` after
every power-on. If it's missing (or built in the wrong format), the job "completes" and nothing
prints. Install the firmware, keep using the stock `foo2zjs` driver, then share the CUPS queue
with IPP + Samba + `wsdd`.

## Upstream bug

The reason the firmware is so hard to obtain is tracked upstream:
[OpenPrinting/foo2zjs#33](https://github.com/OpenPrinting/foo2zjs/issues/33) — `getweb`'s only
mirror (`quirinux.org`) is unreachable.
