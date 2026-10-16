#!/usr/bin/env bash
# =============================================================================
#  install-firmware-loader.sh
#  Install a resilient HP LaserJet 1020 firmware auto-uploader.
#
#  Modern systemd-udevd (>= 255.4-1ubuntu8.18) reaps the whole worker process
#  group as soon as the udev RUN+= program returns. The stock foo2zjs helper
#  /usr/lib/udev/hplj1020 uploads the firmware in a backgrounded subshell and
#  returns immediately, so the in-flight transfer is killed and the printer
#  ends up with no firmware ("job completed but nothing prints").
#
#  This installer hands the upload to a systemd oneshot unit instead, which is
#  not tied to the udev worker's lifetime:
#
#    /usr/local/sbin/hplj1020-firmware-upload          the uploader (synchronous)
#    /etc/systemd/system/hplj1020-firmware.service     oneshot wrapper
#    /etc/udev/rules.d/85-hplj1020-firmware.rules      triggers the unit on attach
#
#  and disables the stock RUN+="hplj1020" hook (keeping its SYMLINK so
#  /dev/hplj1020-* still appears). Idempotent.
#
#  USAGE:  sudo bash scripts/install-firmware-loader.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STOCK_RULE="/usr/lib/udev/rules.d/85-hplj10xx.rules"

if [[ $EUID -ne 0 ]]; then
  echo "Run me with sudo:  sudo bash $0" >&2
  exit 1
fi

echo "==> Installing the resilient firmware loader (systemd + udev)"
install -d -m 755 /usr/local/sbin
install -m 755 "$ROOT_DIR/scripts/hplj1020-firmware-upload.sh" /usr/local/sbin/hplj1020-firmware-upload
install -m 644 "$ROOT_DIR/systemd/hplj1020-firmware.service" /etc/systemd/system/hplj1020-firmware.service
install -d -m 755 /etc/udev/rules.d
install -m 644 "$ROOT_DIR/udev/85-hplj1020-firmware.rules" /etc/udev/rules.d/85-hplj1020-firmware.rules

echo "==> Disabling the stock foo2zjs RUN hook (its backgrounded upload gets reaped)"
if [[ -f "$STOCK_RULE" ]]; then
  sed -i 's|SYMLINK+="hplj1020-%n", RUN+="hplj1020"|SYMLINK+="hplj1020-%n"|' "$STOCK_RULE" || true
  if grep -q 'RUN+="hplj1020"' "$STOCK_RULE"; then
    echo "    WARNING: could not neutralise $STOCK_RULE; the stock hook may race us" >&2
  else
    echo "    stock RUN+=\"hplj1020\" disabled (SYMLINK kept)"
  fi
else
  echo "    $STOCK_RULE not present; nothing to disable"
fi

systemctl daemon-reload
udevadm control --reload-rules

echo "==> Firmware loader installed."
echo "    The printer will be programmed automatically on the next USB attach."
echo "    To run it now:  sudo /usr/local/sbin/hplj1020-firmware-upload"
