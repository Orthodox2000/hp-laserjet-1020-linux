# 07 — Troubleshooting: every symptom we hit, and its cause/fix

A field guide. Each entry: **symptom → cause → fix**.

---

## Printing

### 1. Job says "completed", "Sent N bytes", but nothing prints
**Cause:** printer firmware not loaded (`FWVER` absent).
**Fix:** install `sihp1020.dl` (doc 03) and re-upload. Verify:
`sudo usb_printerid /dev/usb/lp0 | grep -o FWVER:[0-9]*`

### 2. Firmware upload returns success (exit 0) but `FWVER` never appears
**Cause:** wrong firmware **format**. `arm2hpdl` converted an **ELF** input into the
`beef`/ELF format instead of the **ACL/PJL** format.
**Fix:** use the ACL-format blob (HPLIP's decompressed `hp_laserjet_1020.fw.gz`, or the one
in this repo). `arm2hpdl` picks the format from the input's first bytes — ASCII date → ACL,
`\x7fELF` → beef. See doc 03.

### 3. `usb_printerid: can't open /dev/usb/lp0`
**Cause:** the `usblp` kernel driver isn't bound (CUPS' `usb` backend uses libusb and
detaches it), so `/dev/usb/lp0` may not exist.
**Fix:** don't rely on it. Use the libusb path instead:
`sudo /usr/lib/cups/backend/usb | grep 1020`. Or temporarily `sudo modprobe usblp` to read
the ID.

### 4. Printer stops printing after every power cycle
**Cause:** firmware is volatile and must be re-uploaded at each power-on.
**Fix:** ensure the udev rule (doc 03) is present and HPLIP isn't hijacking the device.
To force it: `sudo udevadm trigger --action=add --sysname-match='<usb-path>'` or re-plug USB.

### 5. The `hplj1020` loader runs but logs nothing / "No entries"
**Cause:** it **intentionally skips** devices that already report `FWVER`
(`grep -v FWVER`). Silence is normal when firmware is already loaded.
**Fix:** none — this is not a bug. It only acts when firmware is missing.

### 6. HPLIP's `hp:/usb/...` queue stalls or errors
**Cause:** the HPLIP `hp` backend needs the **proprietary plugin**, and the plugin version is
locked to the HPLIP version (e.g. plugin 3.24.4 won't work with HPLIP 3.23.12). Errors like
`Exception: 4 (Unknown/invalid device-uri field)` / `No device found that support this feature`.
**Fix:** don't use HPLIP for this printer. Use the `usb://...` URI + foo2zjs PPD (doc 04).

### 7. `hp-config_usb_printer` grabs the printer and the firmware upload fails
**Cause:** HPLIP's udev rule `56-hpmud.rules` runs `hp-config_usb_printer`, which tries to
download firmware (needs the plugin), holding the USB device.
**Fix:** comment out that RUN line and remove HPLIP's `.fw.gz` copies (doc 03). Done by
`scripts/install-firmware.sh`.

### 8. `getweb 1020` (foo2zjs) hangs / times out
**Cause:** it downloads `sihp1020.tar.gz` from a third-party host (`quirinux.org`) which may
be unreachable.
**Fix:** don't use `getweb`. Obtain the firmware from HPLIP/your backup (doc 03).

---

## LAN / CUPS sharing

### 9. Other machines can't reach CUPS at all
**Cause:** cupsd only listens on `localhost:631`.
**Fix:** set `Listen 0.0.0.0:631` and `Allow @LOCAL`, then restart CUPS (doc 05).

### 10. Printer not discovered by Windows/macOS/iOS
**Cause:** mDNS (Avahi) not running/advertising.
**Fix:** `sudo systemctl enable --now avahi-daemon`; check
`avahi-browse -rt _ipp._tcp | grep -i laserjet`.

---

## Windows sharing

### 11. Printer appears in Windows "Add device", but the server/file shares don't appear in Network
**Cause:** mDNS finds printers; the **Network** folder is populated by **WS-Discovery**, which
Samba doesn't provide.
**Fix:** install and run `wsdd` (doc 05; Ubuntu ships no unit — use `systemd/wsdd.service`).
Meanwhile, `\\<SERVER_IP>` always works.

### 12. `smbclient -L` / Windows doesn't list the printer
**Cause:** Samba forces the `[printers]` wildcard share to `browseable = no`.
**Fix:** add an **explicit** browsable printer share whose name matches a CUPS queue
(`[HP-LaserJet-1020]` with `printer name = <queue>`) — see doc 05.

### 13. Windows connects to the SMB printer, then prints garbage or nothing
**Cause:** mode mismatch. The host-based printer needs **raw** pass-through
(`cups options = raw`) plus HP's Windows driver. Without `raw`, CUPS re-filters ZJS data as
if it were PostScript. Conversely, sending PostScript to the raw share also fails.
**Fix:** set `cups options = raw`, use HP's LJ1020 driver on Windows. Or use the IPP queue
instead and let CUPS render (doc 06).

### 14. Windows can't connect: "blocked by security policies ... unauthenticated guest access"
**Cause:** Windows 10/11 blocks passwordless guest SMB by default.
**Fix:** create the fallback SMB account (`useradd -M -s /usr/sbin/nologin printer` +
`smbpasswd -a printer`) and log in with it; or enable insecure guest logons on the PC.

### 15. Windows shows the printer but "no driver found"
**Cause:** `use client driver = yes` means the server won't supply a driver.
**Fix:** install HP's LJ1020 driver on the client (Windows Update or the shared driver
folder), or use the IPP path which auto-installs a class driver.

---

## Samba / mounts

### 16. Shared NTFS folder is read-only for Windows users
**Cause:** the NTFS mount's `umask` restrict perms, and/or no `force user`.
**Fix:** in `smb.conf` use `force user = <you>` and mount with
`uid=<you>,gid=<you>,umask=000` (or `umask=002`); see `config/smb.conf`.

### 17. Unmounting a udisks-mounted drive deletes the mountpoint
**Cause:** `udisks`, not `fstab`, created/removed `/media/<user>/<label>`.
**Fix:** create the mountpoint and add a proper `/etc/fstab` entry so it always exists:
`UUID=<uuid> /media/<user>/<label> ntfs-3g defaults,nofail,uid=...,gid=...,umask=000 0 0`.

### 18. Samba share sometimes empty after boot
**Cause:** smbd started before the drive mounted.
**Fix:** add a systemd drop-in with `RequiresMountsFor=/media/<user>/<label>` (see
`systemd/smbd.service.d/override.conf`).

### 19. `wsdd` won't start: "Unit wsdd.service does not exist"
**Cause:** the Ubuntu package ships only `/usr/bin/wsdd`, no unit.
**Fix:** install the unit from `systemd/wsdd.service` (doc 05).

---

## Miscellaneous

### 20. Huge `/var/log/cups/error_log` after debugging
**Cause:** `cupsctl --debug-logging` was left on.
**Fix:** `sudo cupsctl --no-debug-logging` (and set `LogLevel warn`).

### 21. Different printer serial / path
The `?serial=` in the device URI and the USB path (`1-9`) are machine-specific.
Auto-detect the URI with `/usr/lib/cups/backend/usb` and the path with `lsusb`.
