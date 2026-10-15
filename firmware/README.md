# firmware/

## `sihp1020.dl`

This is the **runtime firmware** for the HP LaserJet 1020.

| Property | Value |
|---|---|
| Size | 128999 bytes |
| md5 | `0cd1ac3a4f6cb7995e99deffff840927` |
| Format | ACL/PJL — begins with the PJL header `ESC %-12345X@PJL ENTER LANGUAGE=ACL` |
| Installs to | `/var/lib/foo2zjs/firmware/sihp1020.dl` |

The HP LaserJet 1020 is a **host-based (GDI) printer with no firmware in flash**.
The host must upload this blob into the printer's RAM **after every power-on** before
the printer can render anything. Without it, jobs report success but nothing prints.

The stock `foo2zjs` udev rule (`85-hplj10xx.rules` + `/usr/lib/udev/hplj1020`) uploads
this file automatically on USB attach.

## Provenance / legal

This blob is **HP proprietary firmware**, needed to operate hardware you own. It is the
same firmware HPLIP ships (as `hp_laserjet_1020.fw.gz`) and that `foo2zjs` uploads; it is
redistributed here for interoperability. If you prefer to generate it from your own
sources, see [`../docs/03-firmware.md`](../docs/03-firmware.md):

- Decompress HPLIP's copy:
  `gunzip -c hp_laserjet_1020.fw.gz > sihp1020.dl` (expect md5 above).
- Do **not** wrap a bare ELF with `arm2hpdl` — that yields the wrong `\xbe\xef` ("beef")
  format, which the printer accepts but never runs. (HPLIP's `.fw.gz` is already ACL/PJL and
  needs no conversion.)

## Verify

```bash
md5sum sihp1020.dl          # 0cd1ac3a4f6cb7995e99deffff840927
head -c 32 sihp1020.dl | xxd # begins 1b25 2d31 ... (ESC %-12345X@PJL ENTER LANGUAGE=ACL), not 7f 45 4c 46
```
