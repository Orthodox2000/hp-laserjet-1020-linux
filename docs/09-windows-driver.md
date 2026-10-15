# 09 — Windows driver (HP LaserJet 1020) by Windows version

This repo does **not** bundle HP's proprietary Windows driver (it would be a licensing
problem and it's large). Here is how to get the right one for each Windows version.

> **Do you even need it?** If you connect over **IPP** (`http://<server>:631/printers/<queue>`
> or auto-discovery), Windows installs a class driver and the **Linux server renders** with
> foo2zjs — no HP driver needed. See [`06-cross-platform.md`](06-cross-platform.md).
> You only need HP's driver for the **SMB + raw pass-through** path, which makes Windows do
> the host-based rendering instead.

---

## Official source (recommended)

HP's support page for the printer lists the drivers per OS:

- **HP LaserJet 1020 support / drivers:**
  <https://support.hp.com/us-en/drivers/hp-laserjet-1020-printer/4394233>

Pick your Windows version → **Driver** → download. Typical packages:

| Windows | Driver family | Notes |
|---|---|---|
| Windows 11 | *HP LaserJet 1020* (PCL/PS or host-based) | Windows Update often installs it automatically |
| Windows 10 | HP LaserJet 1020 / "HP LaserJet 1020 Series" | Usually present via Windows Update |
| Windows 8.1 / 8 | HP LaserJet 1020 Series | Use compatibility mode if the installer refuses |
| Windows 7 | HP LaserJet 1020 Series (full solution) | Classic driver |
| Windows Vista/XP | HP LaserJet 1020 full software solution | Legacy; 32-bit mostly |

HP also publishes the **"HP LaserJet 1020 Full Software Solution"** which contains
`drv32.cab` / `drv64.cab` (32-bit and 64-bit INF + DLLs). If you have that folder, see the
next section.

---

## Install by connection method

### A) IPP (no driver needed)

1. Settings → **Printers & scanners** → **Add device**.
2. The printer usually appears by mDNS; otherwise **Add manually → Select a shared printer
   by name** → `http://<SERVER_IP>:631/printers/<queue>`.
3. Windows installs an **IPP class driver**. Done — the server renders.

### B) SMB with HP's raw driver

1. Explorer → `\\<SERVER_IP>` → right-click **HP-LaserJet-1020** → **Connect**.
2. If Windows asks for a driver, choose **HP LaserJet 1020** (from Windows Update) or point
   it at your downloaded INF.
3. If you must install manually:
   **Add printer → The printer I want isn't listed → Add a local/network printer with manual
   settings → Create a new port → Local Port →** `\\<SERVER_IP>\HP-LaserJet-1020` → choose the
   HP LaserJet 1020 driver.

> The SMB share is configured with `cups options = raw` and `use client driver = yes`, so
> Windows must supply the driver and render. See [`05-windows-sharing.md`](05-windows-sharing.md).

### C) Host the driver on the server for clients

If you have the HP driver package, share it read-only so every PC can grab it:

```ini
# /etc/samba/smb.conf
[HP1020-Windows-Driver]
   comment = HP LaserJet 1020 Windows driver
   path = /srv/hp1020-windows-driver
   browseable = yes
   guest ok = yes
   read only = yes
```

```bash
sudo mkdir -p /srv/hp1020-windows-driver
# copy the extracted HP driver folder (drv32.cab, drv64.cab, language dirs, ...) here
sudo cp -r /path/to/hp_LJ1020_*/* /srv/hp1020-windows-driver/
sudo systemctl restart smbd
```

Then on each PC: `\\<SERVER_IP>\HP1020-Windows-Driver`.

---

## Point-and-print (server stores the driver)

Samba *can* act as a point-and-print server so Windows pulls the driver automatically from
`[print$]`. This requires registering the driver into Samba's print driver store, which is
fiddly for GDI drivers (and `cupsaddsmb` was removed from modern CUPS). For this printer the
practical options are:

1. **IPP** (no driver) — simplest, recommended.
2. **Driver on Windows Update** — usually automatic.
3. **Shared driver folder** (section C above) — explicit but reliable.

Trying to do full point-and-print with the host-based driver often fails on 64-bit Windows
because the provided `.cab`s lack an INF suitable for driver-store registration. Prefer 1–3.

---

## "Windows cannot connect to the printer / no driver found"

This is expected with `use client driver = yes` if the client has no driver. Fixes:

- Let Windows search **Windows Update** for "HP LaserJet 1020".
- Install the driver from the shared folder (section C), then reconnect.
- Or switch that client to the **IPP** path (section A), which needs no driver.

## Related

- [`05-windows-sharing.md`](05-windows-sharing.md) — SMB + raw + WSD setup
- [`06-cross-platform.md`](06-cross-platform.md) — IPP/AirPrint/Mopria for every OS
