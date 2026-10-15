# 05 — Sharing to Windows (CUPS IPP + Samba + WS-Discovery)

Two independent mechanisms are involved, and it's worth knowing which is which:

| Layer | Technology | What it gives Windows |
|---|---|---|
| Printing | **CUPS IPP** | driverless print via `http://server:631/printers/<queue>`; Windows 10/11 auto-installs |
| Printing | **SMB (Samba)** | `\\SERVER\<printer-share>`; lets Windows use HP's own driver (raw pass-through) |
| Discovery | **mDNS (Avahi)** | printers show up in "Add device" (IPP/AirPrint/Mopria) |
| Discovery | **WS-Discovery (`wsdd`)** | the *server itself* shows up under Network → so **file shares** appear |

A very common confusion: **the printer shows up in Windows "Add device" but the file shares
don't**, because Windows finds printers via mDNS/IPP while the Network folder is populated by
**WS-Discovery**. Samba does not speak WS-Discovery by itself, so you need `wsdd`.

---

## Part A — Share the printer with CUPS

```bash
sudo cupsctl --share-printers
```

And make CUPS listen on the LAN + allow the local subnet. Edit `/etc/cups/cupsd.conf`:

```text
Listen 0.0.0.0:631
Listen [::]:631
Browsing On
BrowseLocalProtocols dnssd

<Location />
  Order allow,deny
  Allow @LOCAL
</Location>
```

Then:

```bash
sudo systemctl restart cups
```

Verify it's reachable and advertised:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<SERVER_IP>:631/
avahi-browse -rt _ipp._tcp | grep -i 'LaserJet'
# you should see mopria-certified, URF=..., pdl=... -> driverless clients can use it
```

`scripts/restore-printer-and-shares.sh` applies all of this automatically.

---

## Part B — Share the printer via Samba (so Windows can use HP's driver)

Install Samba and configure `/etc/samba/smb.conf` (see `config/smb.conf`):

```ini
[global]
   workgroup = WORKGROUP
   server role = standalone server
   map to guest = bad user
   printing = cups
   printcap name = cups
   load printers = yes
   cups options = raw          ; pass Windows-rendered data straight through

[printers]
   comment = All Printers
   path = /var/spool/samba
   printable = yes
   guest ok = yes
   browseable = yes
   use client driver = yes     ; let Windows use its own HP driver

; Explicit, browsable printer share (the [printers] wildcard is NOT browsable)
[HP-LaserJet-1020]
   comment = HP LaserJet 1020 (USB, shared)
   printer name = HP-LaserJet-1020       ; must match the CUPS queue name
   path = /var/spool/samba
   printable = yes
   browseable = yes
   guest ok = yes
   use client driver = yes
```

Notes:

- **`cups options = raw`** is essential here. The LJ 1020 is host-based, so Windows must
  render with HP's driver and send the raw stream; CUPS must **not** re-filter it.
- **`use client driver = yes`** tells Samba not to attempt point-and-print driver download.
- **The explicit `[HP-LaserJet-1020]` share** is required: Samba forces the special
  `[printers]` wildcard share to `browseable = no`, so without an explicit share the printer
  will not be listed (`smbclient -L` won't show it).

```bash
sudo install -d -m 1777 /var/spool/samba
sudo testparm -s
sudo systemctl restart smbd nmbd
smbclient -L localhost -N          # printer should now be listed
```

### Guest vs credentials

`map to guest = bad user` + `guest ok = yes` gives passwordless access. **Windows 10/11
often blocks passwordless guest SMB** ("your organization's security policies block
unauthenticated guest access"). Two options:

- enable insecure guest logons on each PC (registry/GP), or
- create a fallback SMB account (recommended):

```bash
sudo useradd -M -s /usr/sbin/nologin printer
sudo smbpasswd -a printer          # e.g. password: printer123
```

Windows will prompt once and can "remember" it.

---

## Part C — WS-Discovery so the server shows in Windows Network

The Ubuntu `wsdd` package ships the binary but **no systemd unit**, so create one
(`systemd/wsdd.service` in this repo):

```ini
[Unit]
Description=Web Services Dynamic Discovery (WSD) host daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/wsdd --shortlog --ipv4only
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
sudo apt install -y wsdd
sudo cp systemd/wsdd.service /etc/systemd/system/
sudo systemctl enable --now wsdd
ss -lunp | grep 3702     # should be listening on 239.255.255.250:3702 and <ip>:3702
```

Now Explorer → **Network** shows the server, and its shares appear under it.

---

## Part D — Done. What Windows sees

```text
\\SERVER\HP-LaserJet-1020      <-- printer (use HP LaserJet 1020 driver)
\\SERVER\<FOLDER-SHARE>        <-- any shared folder
\\SERVER\HP1020-Windows-Driver <-- optional: host the Windows driver for clients
```

Fastest access that always works regardless of Network browsing: type the address directly

```text
\\<SERVER_IP>
```

---

## Common pitfalls (all seen in practice)

1. **Printer visible in "Add device", but not in Network.** → mDNS works, WS-Discovery
   doesn't. Install/start `wsdd`.
2. **Server appears, but clicking it asks for a password and fails.** → guest SMB blocked;
   use the fallback account.
3. **Shared printer prints garbage or nothing on Windows.** → `cups options = raw` missing
   (CUPS re-filtered ZJS data), or the Windows client used a PostScript driver against a raw
   share. Match the driver to the mode.
4. **`smbclient -L` doesn't show the printer.** → you relied on the `[printers]` wildcard;
   add the explicit browsable printer share.
5. **Firewall.** On Ubuntu/Mint `ufw` is often inactive; if active:
   `sudo ufw allow 631/tcp && sudo ufw allow samba`.
