# 01 — Symptoms: what "broken" looks like

The failure mode of a host-based HP LaserJet 1020 without firmware is unusually
**quiet and misleading**. Everything reports success. Only the paper is missing.

## The classic symptoms

1. **The job "prints" instantly and reports success.**
   `lpstat` shows the job, then it disappears from the queue. CUPS reports
   `Job completed` / `Job 6 completed`.

2. **The CUPS log looks perfectly healthy.**
   `/var/log/cups/error_log` shows the full filter chain running and the USB backend
   writing bytes:

   ```text
   [Job 6] Started filter ... (pdftopdf)
   [Job 6] Started filter ... (gs)
   [Job 6] Started filter ... (pstops)
   [Job 6] Started filter ... (foomatic-rip)
   [Job 6] Started backend /usr/lib/cups/backend/usb (PID ...)
   [Job 6] Sent 125555 bytes...
   [Job 6] Completed successfully.
   ```

3. **The printer makes no sound, no lights change, nothing comes out.**
   (Or, if an earlier broken firmware attempt was made, the printer's green light may
   blink briefly and stop.)

4. **`usb_printerid` / the device ID has no `FWVER`.**
   This is the smoking gun:

   ```text
   MFG:Hewlett-Packard;MDL:HP LaserJet 1020;CMD:ACL;CLS:PRINTER;DES:HP LaserJet 1020;
   ```

   Compare with a *loaded* printer:

   ```text
   MFG:Hewlett-Packard;MDL:HP LaserJet 1020;CMD:ACL;CLS:PRINTER;DES:HP LaserJet 1020;FWVER:20080222;
   ```

5. **The same printer works on Windows.**
   Because HP's Windows driver uploads the firmware itself as part of every job.
   If you dual-boot, "it works on Windows but not Linux" is expected until you provide
   the firmware.

## What it is *not*

- It is **not** the driver package missing — `printer-driver-foo2zjs` provides the queue.
- It is **not** a permissions problem on `/dev/usb/lp0` — the CUPS `usb` backend talks to
  the device via libusb and doesn't need the usblp node.
- It is **not** a bad cable — if the device ID reads back at all, USB is fine.
- It is **not** Ghostscript/foomatic — those run before the backend and log success.

## Symptoms of the *second* trap (wrong firmware format)

If you generate firmware with `arm2hpdl` using the **ELF** branch, you get a file the
printer **accepts without error but never executes**. Symptoms then are:

- The upload command returns exit code 0.
- The job still doesn't print.
- `FWVER` is **still absent** afterwards.
- Possibly the printer's status light blinks once and returns to idle.

This is why "I uploaded the firmware and it still doesn't work" happens.
See [`03-firmware.md`](03-firmware.md).

## Quick triage checklist

```bash
# 1. Is the queue there and enabled?
lpstat -p -d

# 2. Does the printer report firmware loaded?
sudo modprobe usblp; sudo usb_printerid /dev/usb/lp0 | grep -o 'FWVER:[0-9]*'

# 3. What is the device URI?
lpstat -v

# 4. What does the last job's log say?
sudo grep -a 'Job .*' /var/log/cups/error_log | tail -20
```

If (2) shows no `FWVER`, go straight to [`03-firmware.md`](03-firmware.md).
