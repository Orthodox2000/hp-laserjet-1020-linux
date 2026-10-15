# 11 — FreeBSD, OpenBSD, and other non-Linux hosts

The HP LaserJet 1020 story is the same on any OS: the host must upload `sihp1020.dl`
**after every power-on**. What changes is the plumbing. Below are notes for other host
operating systems; if you only want to *print from* a BSD/mobile device to a Linux server,
you don't need any of this — just use IPP (see [`06-cross-platform.md`](06-cross-platform.md)).

## The firmware command is OS-agnostic

If you have any tool that can do an unauthenticated USB bulk/control transfer to the printer
(interface class 7, subclass 1, protocol 2), this is all the "driver" needs:

```text
1. open the USB device
2. claim the printer interface
3. send the entire contents of sihp1020.dl (128999 bytes, ACL/PJL)
4. release
5. read the device ID -> should now contain FWVER:20080222
```

On Linux the CUPS `usb` backend does exactly this. On other systems, use whatever USB
library is native.

---

## FreeBSD

The `foo2zjs` port exists and CUPS/Samba are in the base/pkg tree.

```sh
pkg install foo2zjs cups cups-filters samba419 avahi
sysrc cupsd_enable=YES
sysrc samba_server_enable=YES
sysrc avahi_daemon_enable=YES
service cupsd start
service samba_server start

# firmware directory used by the port (check the helper script):
#   /usr/local/share/foo2zjs/firmware/   (typical)
install -m 644 sihp1020.dl /usr/local/share/foo2zjs/firmware/sihp1020.dl
```

Upload helper (FreeBSD's `usbconfig` + a small transfer tool, or use CUPS directly):

```sh
# the foo2zjs udev-equivalent on FreeBSD is a devd(8) rule; the port usually ships one.
# Manual: use /usr/local/libexec/cups/backend/usb via CUPS, or a python usb call.
```

If you only need to print **to** a Linux server, skip all this and add an IPP queue:

```sh
lpadmin -p LJ1020 -E -v 'ipp://<SERVER_IP>:631/printers/<queue>' -m everywhere
```

## OpenBSD

```sh
pkg_add cups cups-filters samba avahi
rcctl enable cupsd smbd nmbd avahi_daemon
rcctl start cupsd smbd nmbd avahi_daemon
# firmware path is package-dependent; check the foo2zjs files (if available in ports)
```

OpenBSD's strict `pledge`/`unveil` and USB permissions can complicate raw USB uploads; the
IPP-client path (below) is usually the pragmatic choice.

## NetBSD / pkgsrc

`graphics/foo2zjs` and `print/cups` are available in pkgsrc. Same idea; check the helper for
the firmware directory.

## macOS **as a host** (USB printer attached to a Mac)

macOS ships a CUPS-based printing system (`cupsd`), so the concept applies, but Apple's
capture of the printer is different. In practice this printer is best driven by a **Linux
host**; if you must attach it to macOS, HP's driver (which uploads the firmware) is the
supported route.

---

## The universal client answer (any OS)

For **any** operating system that is not the host, the recommended path is **IPP Everywhere**:

```text
ipp://<SERVER_IP>:631/printers/<queue>
```

| Host/client | Add-printer mechanism |
|---|---|
| FreeBSD/OpenBSD/NetBSD | `lpadmin -m everywhere` or the desktop print dialog |
| macOS | Bonjour/AirPrint |
| iOS/iPadOS | AirPrint |
| Android | Mopria |
| Windows | Add printer by URL/IPP |
| ChromeOS | IPP |
| Haiku | CUPS/IppClient in the print dialog |
| Solaris/illumos | `lpadmin` + CUPS or IPP client |

The Linux server renders with foo2zjs for all of them, so **no client-side driver or
firmware logic is needed anywhere except the host.**

---

## Summary: what is truly portable

- **Portable:** the firmware file, the CUPS queue definition, the PPD, the SMB/CUPS/wsdd
  config, and the IPP client story.
- **Host-specific:** how the firmware is uploaded (udev on Linux, `devd` on FreeBSD, a
  scripted USB call elsewhere) and package/service names.
