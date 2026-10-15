#!/usr/bin/env bash
# =============================================================================
#  install-firmware.sh
#  Install (and verify) the HP LaserJet 1020 runtime firmware sihp1020.dl and
#  wire up automatic upload on USB attach. Also stops HPLIP from competing.
#
#  This fixes the classic "job completed but nothing prints" symptom, which is
#  caused by missing/wrong firmware, NOT by a missing driver.
#
#  USAGE:  sudo bash scripts/install-firmware.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FWDIR="/var/lib/foo2zjs/firmware"
FWFILE="$FWDIR/sihp1020.dl"
KNOWN_MD5="0cd1ac3a4f6cb7995e99deffff840927"

if [[ $EUID -ne 0 ]]; then
  echo "Run me with sudo:  sudo bash $0" >&2
  exit 1
fi

echo "==> Installing packages (foo2zjs provides the driver + udev loader)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y printer-driver-foo2zjs usbutils

echo "==> Installing firmware"
install -d -m 755 "$FWDIR"

if [[ -f "$ROOT_DIR/firmware/sihp1020.dl" ]]; then
  install -m 644 "$ROOT_DIR/firmware/sihp1020.dl" "$FWFILE"
  echo "    used bundled firmware: $ROOT_DIR/firmware/sihp1020.dl"
else
  # Fall back to regenerating from an HPLIP copy if present.
  SRC=""
  for cand in /usr/share/hplip/data/firmware/hp_laserjet_1020.fw.gz \
              /usr/share/hplip/data/firmware/hp_laserjet_1020.fw; do
    [[ -f "$cand" ]] && { SRC="$cand"; break; }
  done
  if [[ -z "$SRC" ]]; then
    echo "ERROR: no firmware source found (no bundled file, no HPLIP .fw)." >&2
    echo "       Provide firmware/sihp1020.dl or install HPLIP's firmware." >&2
    exit 1
  fi
  case "$SRC" in
    *.gz) gunzip -c "$SRC" > "$FWFILE" ;;
    *)    cp "$SRC" "$FWFILE" ;;
  esac
  chmod 644 "$FWFILE"
  echo "    generated firmware from: $SRC"
fi

# --- sanity checks ----------------------------------------------------------
MD5="$(md5sum "$FWFILE" | awk '{print $1}')"
SIZE="$(stat -c %s "$FWFILE")"
MAGIC="$(head -c 2 "$FWFILE" | tr -d '\0')"
echo "    size=$SIZE  md5=$MD5  magic='$MAGIC'"
[[ "$MD5" == "$KNOWN_MD5" ]] && echo "    OK: matches known-good 1020 firmware" \
                             || echo "    WARNING: md5 differs from known-good ($KNOWN_MD5)"
[[ "$MAGIC" == "20" ]] && echo "    OK: ACL/PJL format (starts with an ASCII date)" \
                       || echo "    WARNING: not ACL/PJL (should start with '20'), printer may accept it but ignore it"

echo "==> Preventing HPLIP from competing with the foo2zjs loader"
RULE="/usr/lib/udev/rules.d/56-hpmud.rules"
if [[ -f "$RULE" ]]; then
  sed -i 's|^\(ENV{hp_test}=="yes", PROGRAM=.*hp-config_usb_printer.*\)$|# disabled for foo2zjs: \1|' "$RULE" || true
  echo "    disabled hp-config_usb_printer in $RULE"
fi
rm -f /usr/share/hplip/data/firmware/*.fw.gz 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true

echo "==> Uploading firmware now (if the printer is connected)"
URI="$(/usr/lib/cups/backend/usb 2>/dev/null | awk '/LaserJet.*1020/{print $2; exit}')" || true
if [[ -n "${URI:-}" ]]; then
  echo "    device: $URI"
  DEVICE_URI="$URI" /usr/lib/cups/backend/usb 1 1 1 1 '' "$FWFILE" >/dev/null 2>&1 \
    && echo "    upload command returned success" \
    || echo "    upload command failed (will retry automatically on next plug-in)"
else
  echo "    no LJ 1020 on USB right now; the udev rule uploads it when connected."
fi

echo "==> Verifying (expect to see FWVER:... if firmware loaded)"
modprobe usblp 2>/dev/null || true
sleep 1
if [[ -e /dev/usb/lp0 ]] && command -v usb_printerid >/dev/null 2>&1; then
  usb_printerid /dev/usb/lp0 || true
else
  /usr/lib/cups/backend/usb 2>/dev/null | grep -i 1020 || true
fi

echo
echo "Done. If FWVER is still absent, see docs/03-firmware.md (wrong-format trap)."
