# 08 — Migrating the whole setup to a fresh Linux install

If you move to a new Mint/Ubuntu machine, three things carry the setup:

1. the **firmware** `sihp1020.dl`,
2. the **CUPS PPD** (the foo2zjs queue definition),
3. the **configs** (cupsd.conf tweaks, smb.conf, systemd units) — plus this repo itself,
   which contains all of the above.

You do **not** need to carry over any custom driver — there isn't one. The driver is the
stock `printer-driver-foo2zjs` package.

## One-command restore

```bash
git clone https://github.com/Orthodox2000/hp-laserjet-1020-linux
cd hp-laserjet-1020-linux
sudo bash scripts/restore-printer-and-shares.sh
```

The script:

1. installs `printer-driver-foo2zjs`, `cups`, `cups-filters`, `samba`, `wsdd`, `avahi-daemon`;
2. installs `firmware/sihp1020.dl` to `/var/lib/foo2zjs/firmware/`;
3. neutralises HPLIP's competing `hp-config_usb_printer` udev line;
4. creates the CUPS queue (auto-detects the USB URI, uses `config/HP-LaserJet-1020.ppd`);
5. enables CUPS LAN sharing (`Listen 0.0.0.0:631`, `Browsing On`, `Allow @LOCAL`);
6. writes `smb.conf`, creates the fallback SMB account, stages nothing you didn't ask for;
7. optionally adds an auto-mount + Samba share for a drive (configure via env vars);
8. installs the `wsdd` unit and Samba mount dependencies and enables everything;
9. uploads the firmware immediately so it prints without a power cycle.

It is **idempotent** (safe to re-run) and **auto-detects your username** from `sudo`, so it
rewrites `force user =` and `/home/<user>`, `/media/<user>` paths for you.

## What to know before you run it

- **Internet is required** during setup (packages).
- **Same printer model.** This kit is 1020-specific: it uses the 1020 firmware and PPD.
  A different model needs its own `sihpXXXX.dl` and PPD (the process is identical).
- **Non-Debian distro?** The script targets apt-based systems. On Fedora/Arch/openSUSE the
  packages differ (`foo2zjs`, `cups`, `samba`, `wsdd`, `avahi`), but the manual steps in the
  other docs map 1:1.
- **Stable address.** For a fixed `\\<server>` name, give the machine a static IP or a DHCP
  reservation. Otherwise use `\\<SERVER_IP>` which always works.

## Manual checklist (if not using the script)

```bash
# packages
sudo apt install -y printer-driver-foo2zjs cups cups-filters samba samba-common-bin wsdd avahi-daemon

# firmware
sudo install -d -m 755 /var/lib/foo2zjs/firmware
sudo install -m 644 firmware/sihp1020.dl /var/lib/foo2zjs/firmware/sihp1020.dl

# disable HPLIP's competing rule
sudo sed -i 's|^\(ENV{hp_test}=="yes", PROGRAM=.*hp-config_usb_printer.*\)$|# disabled for foo2zjs: \1|' \
     /usr/lib/udev/rules.d/56-hpmud.rules
sudo udevadm control --reload-rules

# queue
URI="$(/usr/lib/cups/backend/usb | awk '/LaserJet.*1020/{print $2; exit}')"
sudo lpadmin -p HP-LaserJet-1020 -E -v "$URI" -P config/HP-LaserJet-1020.ppd -o printer-is-shared=true
sudo lpadmin -d HP-LaserJet-1020

# share
sudo cupsctl --share-printers
#   edit /etc/cups/cupsd.conf: Listen 0.0.0.0:631, Browsing On, Allow @LOCAL
sudo systemctl restart cups

# samba
sudo install -d -m 1777 /var/spool/samba
sudo cp config/smb.conf /etc/samba/smb.conf
sudo systemctl enable --now smbd nmbd

# ws-discovery
sudo cp systemd/wsdd.service /etc/systemd/system/
sudo systemctl enable --now wsdd
```

## Post-migration verification

```bash
lpstat -p -d
sudo modprobe usblp; sudo usb_printerid /dev/usb/lp0 | grep -o 'FWVER:[0-9]*'
lp -d HP-LaserJet-1020 /usr/share/cups/data/default-testpage.pdf
smbclient -L localhost -N            # printer + shares listed
avahi-browse -rt _ipp._tcp | grep -i laserjet
```

## Rolling your own on a non-apt system

The essential artifacts are: `sihp1020.dl`, the PPD, and the knowledge in
[`03-firmware.md`](03-firmware.md) (format trap) and
[`05-windows-sharing.md`](05-windows-sharing.md) (the `[printers]`/WSD gotchas).
Everything else is package-specific plumbing.
