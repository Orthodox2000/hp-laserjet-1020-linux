# firmware/

## `sihp1020.dl`

This is the **runtime firmware** for the HP LaserJet 1020.

| Property | Value |
|---|---|
| Size | 128999 bytes |
| md5 | `0cd1ac3a4f6cb7995e99deffff840927` |
| Format | ACL/PJL (starts with an ASCII date, **not** ELF) |
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
- Do **not** build it from an ELF using `arm2hpdl` — that yields the wrong `beef`/ELF
  format which the printer accepts but never runs.

## Verify

```bash
md5sum sihp1020.dl          # 0cd1ac3a4f6cb7995e99deffff840927
head -c 8 sihp1020.dl | xxd # starts with ASCII date, not 7f 45 4c 46
```
