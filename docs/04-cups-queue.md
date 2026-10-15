# 04 — The CUPS queue (driver, PPD, device URI, filter chain)

With the firmware in place, the print path is pure stock Linux. This doc records exactly
what the working queue looks like so you can recreate it.

## Packages

```bash
sudo apt update
sudo apt install -y printer-driver-foo2zjs cups cups-filters
```

`printer-driver-foo2zjs` provides:

- `/usr/bin/foo2zjs` (the actual renderer for ZjStream devices)
- `/usr/bin/foo2zjs-wrapper`
- PPDs under `foo2zjs:...` in `lpinfo -m`
- the firmware udev rule + `hplj1000`/`hplj1020` helper

## Create the queue

Use the exact PPD from this repo (guarantees the same behaviour):

```bash
QUEUE="HP-LaserJet-1020"
URI="usb://HP/LaserJet%201020?serial=<PRINTER_SERIAL>"

sudo lpadmin -p "$QUEUE" -E -v "$URI" -P ./config/HP-LaserJet-1020.ppd \
             -o printer-is-shared=true
sudo lpadmin -d "$QUEUE"           # make it the default
sudo cupsenable "$QUEUE"; sudo cupsaccept "$QUEUE"
```

Or let CUPS pick the PPD by model name:

```bash
sudo lpadmin -p "$QUEUE" -E -v "$URI" \
     -m 'foo2zjs:0/ppd/foo2zjs/HP-LaserJet_1020.ppd' -o printer-is-shared=true
```

> **Find the serial automatically:**
>
> ```bash
> /usr/lib/cups/backend/usb | awk '/LaserJet.*1020/{print $2}'
> ```

## What the working queue looks like

```bash
lpstat -v
# device for HP-LaserJet-1020: usb://HP/LaserJet%201020?serial=<PRINTER_SERIAL>

sudo grep -E '\*ShortNickName|FoomaticRIPCommandLine|cupsFilter' \
     /etc/cups/ppd/HP-LaserJet-1020.ppd
# *ShortNickName: "HP LaserJet 1020 foo2zjs-z1"
# *FoomaticRIPCommandLine: "foo2zjs-wrapper -z1 -P -L0 %A"
# *cupsFilter: "application/vnd.cups-postscript 100 foomatic-rip"
# *cupsFilter: "application/vnd.cups-pdf 0 foomatic-rip"
```

## The filter chain

For a PDF/PostScript job the pipeline is:

```text
application  ─►  pdftopdf  ─►  gs  ─►  pstops  ─►  foomatic-rip  ─►  foo2zjs  ─►  usb backend  ─►  /dev/bus/usb/...
                                                            (foo2zjs-wrapper -z1 -P -L0)
```

- `-z1` selects the LaserJet 1020 model inside foo2zjs.
- `-P` = the printer's page/priority options as encoded by the PPD.
- `-L0` = LED/toner save off.
- `foomatic-rip` is the glue that invokes the wrapper with the user's options.

If this chain appears in `/var/log/cups/error_log` and the printer still does nothing,
the firmware is the problem (doc 03), not the queue.

## Why `usb://` and not HPLIP's `hp:/...`

- The `usb://` URI uses the standard CUPS `usb` backend (libusb). Reliable, no plugin.
- HPLIP's `hp:/usb/...` uses `/usr/lib/cups/backend/hp`, which for this printer **requires
  the version-locked proprietary HPLIP plugin**. Without a matching plugin it stalls or
  errors. Skip it entirely.

## Driverless sharing note

With CUPS sharing enabled, clients can also use the queue through **IPP Everywhere**
(no local driver). In that case CUPS does the rendering with foo2zjs for everyone —
see doc 06.
