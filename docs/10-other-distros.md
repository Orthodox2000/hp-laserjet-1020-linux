# 10 — Server side on other Linux distributions

The concepts are identical everywhere; only **package names** and occasionally the
**firmware path** change. This page maps the Debian/Mint steps to Fedora/RHEL, Arch,
openSUSE and others.

The verification is always the same:

```bash
lpstat -p -d
sudo modprobe usblp; sudo usb_printerid /dev/usb/lp0 | grep -o 'FWVER:[0-9]*'
```

---

## Package names

| Need | Debian/Mint/Ubuntu | Fedora/RHEL | Arch | openSUSE | Alpine |
|---|---|---|---|---|---|
| foo2zjs driver | `printer-driver-foo2zjs` | `foo2zjs` | `foo2zjs` (AUR: `foo2zjs`) | `foo2zjs` | `foo2zjs` (testing) |
| CUPS | `cups cups-client cups-filters` | `cups cups-filters` | `cups cups-filters` | `cups cups-filters` | `cups cups-filters` |
| Samba | `samba samba-common-bin smbclient` | `samba samba-client` | `samba` | `samba samba-client` | `samba` |
| WS-Discovery | `wsdd` | `wsdd` (COPR) | `wsdd` (AUR) | `wsdd` | — (use `wsdd2`) |
| Avahi/mDNS | `avahi-daemon` | `avahi avahi-tools` | `avahi` | `avahi` | `avahi` |
| USB tool | `usbutils` | `usbutils` | `usbutils` | `usbutils` | `usbutils` |

---

## Firmware path

The `foo2zjs` udev helper (`/usr/lib/udev/hplj1000` or `/lib/udev/hplj1000`) defines the
firmware directory. Find it and match it:

```bash
grep -i 'FWDIR=' /usr/lib/udev/hplj1000 /lib/udev/hplj1000 2>/dev/null
```

- Debian/Ubuntu/Mint (patched): **`/var/lib/foo2zjs/firmware`**
- Most other distros (upstream default): **`/usr/share/foo2zjs/firmware`**

Install `sihp1020.dl` (from `../firmware/`) into whichever directory that shows:

```bash
sudo install -m 644 firmware/sihp1020.dl /usr/share/foo2zjs/firmware/sihp1020.dl
# or  /var/lib/foo2zjs/firmware/sihp1020.dl
```

---

## Fedora / RHEL / CentOS Stream

```bash
sudo dnf install -y foo2zjs cups cups-filters samba wsdd avahi
sudo systemctl enable --now cups smb nmb avahi-daemon wsdd
sudo install -m 644 firmware/sihp1020.dl /usr/share/foo2zjs/firmware/sihp1020.dl
```

- Services are `smb` / `nmb` (not `smbd`/`nmbd`).
- Firewall: `sudo firewall-cmd --add-service=ipp --add-service=samba --permanent && sudo firewall-cmd --reload`.
- SELinux: sharing a custom folder may need a label, e.g.
  `sudo semanage fcontext -a -t samba_share_t "/srv/share(/.*)?" && sudo restorecon -Rv /srv/share`.

## Arch Linux / Manjaro

```bash
sudo pacman -S --needed foo2zjs cups cups-filters samba avahi
# wsdd from AUR:
yay -S wsdd    # or wsdd2
sudo systemctl enable --now cups smb nmb avahi-daemon wsdd
sudo install -m 644 firmware/sihp1020.dl /usr/share/foo2zjs/firmware/sihp1020.dl
```

Rocky/Alma: same as Fedora (EPEL for `foo2zjs` / `wsdd`).

## openSUSE / SLES

```bash
sudo zypper install -y foo2zjs cups cups-filters samba avahi
# wsdd may be in a repo or OBS
sudo systemctl enable --now cups smb nmb avahi-daemon
sudo install -m 644 firmware/sihp1020.dl /usr/share/foo2zjs/firmware/sihp1020.dl
```

Firewall: `sudo firewall-cmd --add-service=ipp --add-service=samba --permanent --reload`.

## NixOS

```nix
{ pkgs, ... }: {
  services.printing = {
    enable = true;
    drivers = with pkgs; [ foo2zjs cups-filters ];
    browsing = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    defaultShared = true;
  };
  services.avahi = { enable = true; nssmdns = true; publish.addresses = true; };
  services.samba = {
    enable = true; openFirewall = true;
    settings = { global = { "load printers" = "yes"; "printing" = "cups"; "cups options" = "raw"; }; };
  };
  # firmware: place sihp1020.dl on disk and point foo2zjs at it (see the udev helper)
}
```

## Gentoo

```bash
sudo emerge -av net-print/foo2zjs net-print/cups net-fs/samba net-misc/avahi
sudo rc-update add cupsd default; sudo rc-update add samba default
sudo install -m 644 firmware/sihp1020.dl /usr/share/foo2zjs/firmware/sihp1020.dl
```

---

## CUPS + Samba config is the same everywhere

The queue creation, `cupsd.conf` tweaks and `smb.conf` in this repo are distro-agnostic.
Only the package/service names differ:

```bash
QUEUE=HP-LaserJet-1020
URI="$(/usr/lib/cups/backend/usb | awk '/LaserJet.*1020/{print $2; exit}')"
sudo lpadmin -p "$QUEUE" -E -v "$URI" -P config/HP-LaserJet-1020.ppd -o printer-is-shared=true
sudo lpadmin -d "$QUEUE"
sudo cupsctl --share-printers
sudo cp config/smb.conf /etc/samba/smb.conf
```

---

## Adding firmware without udev (containers, minimal systems)

The udev rule is a convenience. The upload itself is a simple command; see
[`03-firmware.md`](03-firmware.md):

```bash
sudo DEVICE_URI='usb://HP/LaserJet%201020?serial=<SERIAL>' \
     /usr/lib/cups/backend/usb 1 1 1 1 '' /usr/share/foo2zjs/firmware/sihp1020.dl
```

You can wire this into any init system (systemd unit, OpenRC script, runit, s6, a
`cron @reboot`).
