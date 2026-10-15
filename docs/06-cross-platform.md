# 06 — Cross-platform use (Windows, macOS, Linux, iOS, Android, ChromeOS)

Once the LJ 1020 prints on the Linux host and CUPS is sharing it, every other device on the
LAN can use it. There are two connection styles:

- **Driverless (IPP Everywhere / AirPrint / Mopria)** — the client sends PDF/PWG-Raster and
  **CUPS renders with foo2zjs**. No driver to install. Best for macOS/iOS/Android/Linux and
  modern Windows.
- **SMB with the vendor driver** — Windows renders with **HP's LJ1020 driver** and sends raw
  host-based data; the server passes it straight through (`cups options = raw`). Use when
  you specifically want the HP driver.

The host advertises (via Avahi/mDNS) that it supports both:

```
_ipp._tcp  -> "HP LaserJet 1020 @ <server>"
   mopria-certified=1.3
   URF=V1.4,...            (Apple Raster)
   pdl=application/pdf,application/postscript,image/jpeg,image/png,image/pwg-raster,image/urf
```

Confirm from the server:

```bash
avahi-browse -rt _ipp._tcp   | grep -i laserjet
avahi-browse -rt _printer._tcp | grep -i laserjet
```

The queue's IPP URL is:

```
http://<SERVER_IP>:631/printers/<QUEUE>
ipp://<SERVER_IP>:631/printers/<QUEUE>
```

---

## Windows 10 / 11

### Option 1 — IPP (driverless, recommended, auto-configures)

1. Settings → Bluetooth & devices → Printers & scanners → **Add device**.
2. The printer usually appears by itself (mDNS). Select it.
3. If not: **Add manually** → *Select a shared printer by name* → enter
   `http://<SERVER_IP>:631/printers/<QUEUE>` → Next. Windows installs an IPP class driver.
4. Print. CUPS does the rendering.

### Option 2 — SMB with HP's driver (uses raw pass-through)

1. Explorer → `\\<SERVER_IP>` → right-click **HP-LaserJet-1020** → **Connect**.
2. If asked for a driver, choose **HP LaserJet 1020** (Windows Update usually has it, or
   install from the shared `\\<SERVER>\HP1020-Windows-Driver` folder).
3. If prompted for credentials and guest is blocked: user `printer`, password `printer123`.

> Match the mode: SMB share expects a Windows-rendered (HP driver) stream; IPP expects
> PDF/PS. Don't mix (e.g. don't send PostScript to the raw SMB share).

### Troubleshooting Windows
- Not discovered → use the direct `\\<SERVER_IP>` or `http://<SERVER_IP>:631/printers/<QUEUE>`.
- Server missing in Network → WS-Discovery; ensure `wsdd` runs on the host (doc 05).
- "Windows cannot connect" → install the HP driver first (some builds refuse driverless).

---

## macOS

macOS uses IPP/AirPrint and needs **no driver**.

1. System Settings → Printers & Scanners → **Add Printer**.
2. Pick the printer from **Default** (Bonjour) — it shows as *HP LaserJet 1020 @ <server>*.
3. Driver: **AirPrint** or **IPP Everywhere** (auto).
4. Add.

CLI alternative:

```bash
lpadmin -p LJ1020 -E -v 'ipp://<SERVER_IP>:631/printers/<QUEUE>' -m everywhere
```

---

## Linux (other machines)

Driverless with CUPS:

```bash
# auto-discover
lpinfo --include-schemes dnssd -v          # find the URI

# add explicitly
lpadmin -p LJ1020 -E -v 'ipp://<SERVER_IP>:631/printers/<QUEUE>' -m everywhere
lpadmin -d LJ1020
```

`-m everywhere` uses IPP Everywhere, so the server renders with foo2zjs. No foo2zjs needed on
the client.

---

## iOS / iPadOS (AirPrint)

1. Ensure the device and server are on the same Wi-Fi/LAN.
2. In any app → Share/Print → the printer appears under AirPrint automatically.
3. Select it, print.

Nothing to install. iOS sends PDF/Apple Raster; the server renders.

---

## Android

- **Mopria Print Service** (or the built-in Android print service) → Add printer → the
  advertised printer appears (mDNS/IPP). Select and print.
- Or use an app that speaks IPP to `ipp://<SERVER_IP>:631/printers/<QUEUE>`.

---

## ChromeOS

Add printer by IPP:

1. Settings → Printers → Add Printer → enter
   `ipp://<SERVER_IP>:631/printers/<QUEUE>`.
2. ChromeOS installs a generic IPP driver.

---

## Matrix of what each client needs

| Client | URL/scheme | Sends | Server renders? | Driver on client |
|---|---|---|---|---|
| Windows IPP | `http://<ip>:631/printers/<q>` | PDF/PS/PWG | yes (foo2zjs) | auto (IPP class) |
| Windows SMB | `\\<ip>\HP-LaserJet-1020` | raw HP (ZJS) | no (raw) | HP LJ1020 driver |
| macOS | Bonjour/IPP | PDF/Raster | yes | none |
| Linux | `ipp://.../ -m everywhere` | PDF | yes | none |
| iOS | AirPrint | PDF/Raster | yes | none |
| Android | Mopria/IPP | PDF/PWG | yes | none |
| ChromeOS | IPP | PDF | yes | generic |

The only client that needs a vendor driver is Windows-over-SMB, and only because we're
deliberately using HP's host-based renderer there.

---

## File sharing (SMB) to all platforms

Samba shares work for Windows, macOS (Finder → Go → Connect to Server → `smb://<SERVER_IP>/<share>`),
Linux (`smb://` in the file manager), and Android/iOS file apps. Guest works if allowed;
otherwise use the fallback account (doc 05).
