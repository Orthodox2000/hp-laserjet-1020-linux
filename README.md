# HP LaserJet 1020 on Linux — print, share to Windows/macOS/iOS/Android

Fix and fully document the classic problem:

> The print job says **"completed"** in CUPS, the log says **"Sent N bytes"**, but the
> printer **never puts out a page.**

This repo explains **why** that happens and provides an idempotent script + docs to make the
HP LaserJet 1020 (and close relatives) print reliably on Linux, then share it to Windows,
macOS, iOS and Android on the same LAN.

Tested on: **Linux Mint 22.3 (Ubuntu 24.04 "noble" base), CUPS 2.4.7, foo2zjs 20200505dfsg0,
Samba 4.19.5, HPLIP 3.23.12**, printer on USB.

---

## TL;DR — the 30-second explanation

The HP LaserJet 1020 is a **host-based (GDI) printer with no firmware inside it**.
Every time it is powered on, the PC must upload a firmware blob (`sihp1020.dl`) into the
printer's RAM **before it can render anything**. If the file is missing (or in the wrong
format), the driver happily sends data, the job reports success, and the printer silently
does nothing.

- The **driver** was never the problem. It's the normal open-source `foo2zjs` package.
- The **firmware** was missing. That's the fix.
- A second trap: the `arm2hpdl` tool produces **two different output formats**
  (`beef`/ELF vs `ACL`/PJL). Only **ACL/PJL** works on the 1020. The wrong one is accepted
  by the printer but never runs.

Details: [`docs/03-firmware.md`](docs/03-firmware.md).

---

## Quick start

```bash
git clone https://github.com/Orthodox2000/hp-laserjet-1020-linux
cd hp-laserjet-1020-linux

# 1) Install the driver + firmware for a local USB printer
sudo bash scripts/install-firmware.sh

# 2) Create the CUPS queue and (optionally) share it to the LAN
sudo bash scripts/restore-printer-and-shares.sh
```

Then verify:

```bash
lpstat -p -d
sudo usb_printerid /dev/usb/lp0        # should show  ...FWVER:20080222;
lp -d "$(lpstat -d | awk '{print $NF}')" /usr/share/cups/data/default-testpage.pdf
```

---

## What's in here

| Path | What it is |
|------|------------|
| [`docs/01-symptoms.md`](docs/01-symptoms.md) | What "broken" looks like (and what it does *not* look like) |
| [`docs/02-diagnosis.md`](docs/02-diagnosis.md) | Reading the USB device ID / `FWVER`, finding the real cause |
| [`docs/03-firmware.md`](docs/03-firmware.md) | Host-based printers, `sihp1020.dl`, and the `arm2hpdl` format trap |
| [`docs/04-cups-queue.md`](docs/04-cups-queue.md) | The foo2zjs queue, PPD, device URI and filter chain |
| [`docs/05-windows-sharing.md`](docs/05-windows-sharing.md) | CUPS IPP + Samba + WS-Discovery (`wsdd`) for Windows |
| [`docs/06-cross-platform.md`](docs/06-cross-platform.md) | Windows / macOS / Linux / iOS / Android instructions |
| [`docs/07-troubleshooting.md`](docs/07-troubleshooting.md) | Every symptom we hit and its cause/fix |
| [`docs/08-migration.md`](docs/08-migration.md) | Moving the whole setup to a fresh Linux install |
| `scripts/install-firmware.sh` | Installs/converts the firmware and wires up auto-load |
| `scripts/restore-printer-and-shares.sh` | One-shot: queue + firmware + LAN/SMB sharing |
| `config/` | `smb.conf`, reference `cupsd.conf`, exact working PPD |
| `systemd/` | `wsdd.service` unit + Samba mount dependencies |
| `firmware/sihp1020.dl` | The working firmware (ACL/PJL format, 128999 bytes) |

---

## Cross-platform summary

Once the printer prints on the Linux host and CUPS is sharing it:

| Client OS | How it connects | Driver needed? |
|-----------|-----------------|----------------|
| **Windows 10/11** | IPP (`http://<server>:631/printers/<queue>`) or SMB (`\\<server>\HP-LaserJet-1020`) | IPP: auto. SMB: use HP's LJ1020 Windows driver (pass-through) |
| **macOS** | Auto-discovered (Bonjour/AirPrint, IPP) — "Add Printer" shows it | No |
| **Linux** | IPP Everywhere / the shared queue | No |
| **iOS / iPadOS** | AirPrint (auto) | No |
| **Android** | Mopria / "Add printer" (IPP) | No |
| **ChromeOS** | IPP | No |

Full details: [`docs/06-cross-platform.md`](docs/06-cross-platform.md).

---

## Firmware notice

`firmware/sihp1020.dl` is **HP's proprietary firmware**, redistributed here for
interoperability because it is required to operate hardware you own. It is the same blob
HPLIP ships (`hp_laserjet_1020.fw.gz`) and that `foo2zjs` uploads. If you would rather not
use the bundled copy, [`docs/03-firmware.md`](docs/03-firmware.md) shows how to regenerate
it from your own printer/HPLIP installation.

The scripts and documentation are MIT-licensed (see [`LICENSE`](LICENSE)).
