# 06 — Cross-platform use (every OS, every device)

![One printer, every platform](../assets/sharing.svg)

Once the LJ 1020 prints on the Linux host and CUPS is sharing it, **every device on the LAN**
can use it. There are two connection styles, and you can offer both at once:

- **Driverless (IPP Everywhere / AirPrint / Mopria)** — the client sends PDF / PWG-Raster /
  Apple Raster and **the server renders with foo2zjs**. Nothing to install. Works on macOS,
  iOS, Android, ChromeOS, Linux, and modern Windows.
- **SMB + vendor driver (raw pass-through)** — Windows renders with **HP's LJ1020 driver**
  and the server passes the bytes straight through. Use only when you specifically want HP's
  renderer. See [`09-windows-driver.md`](09-windows-driver.md).

The host advertises (via Avahi/mDNS) that it speaks both:

```text
_ipp._tcp  ->  "HP LaserJet 1020 @ <server>"
   mopria-certified=1.3
   URF=V1.4,...        (Apple Raster)
   pdl=application/pdf,application/postscript,image/jpeg,image/png,
       image/pwg-raster,image/urf
```

So the same queue serves:

```text
ipp://<SERVER_IP>:631/printers/<QUEUE>
http://<SERVER_IP>:631/printers/<QUEUE>
```

Confirm from the server:

```bash
avahi-browse -rt _ipp._tcp | grep -i laserjet
avahi-browse -rt _printer._tcp | grep -i laserjet
```

---

## Full compatibility matrix

| OS / device | Discovery | URL or path | Renders on | Driver to install |
|---|---|---|---|---|
| **Windows 11** | IPP/mDNS or manual | `http://<ip>:631/printers/<q>` | server | none (IPP class) |
| **Windows 10** | IPP/mDNS or manual | `http://<ip>:631/printers/<q>` | server | none (IPP class) |
| **Windows 8.1/8/7** | manual | `http://<ip>:631/printers/<q>` | server | none / generic PS |
| **Windows (SMB raw)** | WSD/network | `\\<ip>\HP-LaserJet-1020` | Windows | HP LJ1020 |
| **macOS 11+** | Bonjour | auto (AirPrint) | server | none |
| **macOS 10.x** | Bonjour | auto | server | none |
| **iOS / iPadOS** | AirPrint | auto | server | none |
| **visionOS** | AirPrint | auto | server | none |
| **Android** | Mopria / Android print | auto or `ipp://…` | server | none |
| **ChromeOS** | IPP | auto or `ipp://…` | server | generic |
| **Linux (GNOME/KDE)** | IPP/mDNS | auto or `ipp://…` | server | none |
| **Linux (CLI)** | — | `lpadmin -m everywhere` | server | none |
| **FreeBSD / OpenBSD / NetBSD** | IPP | `lpadmin -m everywhere` | server | none |
| **Solaris / illumos** | IPP | `lpadmin` + IPP | server | none |
| **Haiku** | IPP | print dialog | server | none |
| **Any raw IPP client** | — | `ipp://…` | server | none |

> The **only** client that needs a vendor driver is Windows-over-SMB, because we deliberately
> let Windows render host-based data there.

---

## Windows

### Option 1 — IPP (driverless, auto-configures) — recommended

1. Settings → Bluetooth & devices → **Printers & scanners** → **Add device**.
2. It usually appears by itself (mDNS). Select it.
3. Otherwise **Add manually → Select a shared printer by name** →
   `http://<SERVER_IP>:631/printers/<QUEUE>` → Next (installs an IPP class driver).

### Option 2 — SMB with HP's driver (raw)

1. Explorer → `\\<SERVER_IP>` → right-click **HP-LaserJet-1020** → **Connect**.
2. Choose the **HP LaserJet 1020** driver (Windows Update, or the shared driver folder —
   see [`09-windows-driver.md`](09-windows-driver.md)).
3. Guest blocked? Use the fallback account (`printer` / `printer123`) — see
   [`05-windows-sharing.md`](05-windows-sharing.md).

---

## macOS / iPhone / iPad

Nothing to install.

- **Mac:** System Settings → Printers & Scanners → **Add Printer** → pick the Bonjour entry
  (*HP LaserJet 1020 @ <server>*) → Driver: **AirPrint / IPP Everywhere** → Add.
  CLI: `lpadmin -p LJ1020 -E -v 'ipp://<SERVER_IP>:631/printers/<QUEUE>' -m everywhere`
- **iPhone/iPad:** ensure the same Wi-Fi/LAN → Share → Print → the AirPrint printer appears.

---

## Linux (other machines) and BSDs

Driverless on any CUPS machine:

```bash
lpinfo --include-schemes dnssd -v                 # discover
lpadmin -p LJ1020 -E -v 'ipp://<SERVER_IP>:631/printers/<QUEUE>' -m everywhere
lpadmin -d LJ1020
```

`-m everywhere` = IPP Everywhere, so the server does the rendering and the client needs no
foo2zjs. FreeBSD/OpenBSD use the same `lpadmin` (see [`11-bsd-and-others.md`](11-bsd-and-others.md)).

---

## Android

- **Mopria Print Service** (Play Store) or the built-in "Android Print" service → Add printer
  → pick the mDNS/IPP entry, or add by `ipp://<SERVER_IP>:631/printers/<QUEUE>`.

## ChromeOS

Settings → Printers → **Add Printer** → `ipp://<SERVER_IP>:631/printers/<QUEUE>` → uses a
generic IPP driver.

## Solaris / illumos / Haiku / other

Any CUPS client: add an IPP queue pointing at `ipp://<SERVER_IP>:631/printers/<QUEUE>`.
No driver needed (server renders).

---

## Sharing folders (SMB) — also cross-platform

The Samba shares work everywhere:

| OS | How |
|---|---|
| Windows | `\\<SERVER_IP>\<share>` |
| macOS | Finder → Go → Connect to Server → `smb://<SERVER_IP>/<share>` |
| Linux | file manager → `smb://<SERVER_IP>/<share>` |
| Android | a SMB-capable file manager (e.g. Material Files) → `smb://<SERVER_IP>/<share>` |
| iOS | Files app → Connect to Server → `smb://<SERVER_IP>/<share>` |

Guest access works if allowed; otherwise use the fallback account.

---

## Why this is "truly platform independent"

- The **host** is the only machine that needs foo2zjs and the firmware.
- Every other OS speaks **IPP**, a vendor-neutral standard, so no per-OS port of the driver is
  needed.
- Discovery is **mDNS** (Apple Bonjour protocol, supported by Windows/Android/ChromeOS/Linux)
  plus **WS-Discovery** for Windows browsing.
- The SMB layer is optional and mainly for Windows' raw driver mode and for file sharing.
