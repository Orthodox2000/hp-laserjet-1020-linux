# 02 — Diagnosis: finding the real cause

Goal: prove whether the printer has firmware loaded, and whether the queue is sane.

## Step 1 — Confirm the printer is seen at all

```bash
lsusb | grep -i 'HP\|LaserJet'
# Bus 001 Device 009: ID 03f0:2b17 HP, Inc LaserJet 1020
```

The LJ 1020 is USB `03f0:2b17`. If it doesn't appear, it's a cable/port/power problem,
not firmware.

## Step 2 — Read the IEEE-1284 device ID (the key diagnostic)

Printers expose a device-ID string containing `FWVER:` **only after firmware is loaded**.

Two ways to read it:

```bash
# (a) via the kernel usblp driver (creates /dev/usb/lp0)
sudo modprobe usblp
sudo usb_printerid /dev/usb/lp0

# (b) without usblp, via the CUPS USB backend (uses libusb)
sudo /usr/lib/cups/backend/usb | grep -i 1020
```

**Broken** (no firmware):

```text
MFG:Hewlett-Packard;MDL:HP LaserJet 1020;CMD:ACL;CLS:PRINTER;DES:HP LaserJet 1020;
```

**Working** (firmware loaded):

```text
MFG:Hewlett-Packard;MDL:HP LaserJet 1020;CMD:ACL;CLS:PRINTER;DES:HP LaserJet 1020;FWVER:20080222;
```

The `CMD:ACL` field is also meaningful: this is an **ACL** (a.k.a. PJL) device, which is
exactly the firmware format the 1020 expects.

## Step 3 — Inspect the CUPS queue

```bash
lpstat -p -d
lpstat -v
lpoptions -p <queue> | tr ' ' '\n' | grep -iE 'device-uri|printer-is-shared'
```

You want:

- a queue using the **foo2zjs** PPD (`HP LaserJet 1020 Foomatic/foo2zjs-z1`),
- a **usb://** device URI,
- **not** the HPLIP `/usr/lib/cups/backend/hp` backend for this printer (that needs the
  version-locked proprietary plugin and tends to stall).

```bash
# which PPD/driver is actually in use
sudo grep -E '\*ShortNickName|FoomaticRIPCommandLine|cupsFilter' /etc/cups/ppd/<queue>.ppd
```

Expected:

```text
*ShortNickName: "HP LaserJet 1020 foo2zjs-z1"
*FoomaticRIPCommandLine: "foo2zjs-wrapper -z1 -P -L0 %A"
*cupsFilter: "application/vnd.cups-postscript 100 foomatic-rip"
*cupsFilter: "application/vnd.cups-pdf 0 foomatic-rip"
```

## Step 4 — Prove the driver pipeline runs

Enable CUPS debug logging and print once:

```bash
cupsctl --debug-logging
lp -d <queue> /usr/share/cups/data/default-testpage.pdf
sleep 10
sudo grep -a 'Job .*' /var/log/cups/error_log | tail -30
cupsctl --no-debug-logging
```

A healthy run shows the whole chain:

```text
universal -> pdftopdf -> gs -> pstops -> foomatic-rip (foo2zjs-wrapper -z1 -P -L0)
-> /usr/lib/cups/backend/usb -> Sent N bytes -> completed
```

If you see all of that **and** Step 2 has no `FWVER`, the diagnosis is conclusive:
**missing/incorrect firmware.** Proceed to [`03-firmware.md`](03-firmware.md).

## Decision guide

| Device ID has `FWVER`? | Queue uses foo2zjs + usb://? | Conclusion |
|---|---|---|
| no  | yes | **Firmware missing** → install it |
| no  | yes, after upload still no `FWVER` | **Wrong firmware format** (ELF vs ACL) → see doc 03 |
| yes | yes | Should print; check backend/log |
| yes | no  | Rebuild the queue (doc 04) |
