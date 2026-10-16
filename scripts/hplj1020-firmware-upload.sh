#!/usr/bin/env bash
# =============================================================================
#  hplj1020-firmware-upload.sh
#  Upload the HP LaserJet 1020 runtime firmware (sihp1020.dl) to the printer.
#
#  This is the systemd-driven replacement for the foo2zjs udev helper
#  /usr/lib/udev/hplj1020, whose backgrounded upload subshell is reaped by
#  modern systemd-udevd (>= 255.4-1ubuntu8.18) before the transfer can finish.
#  See docs/03-firmware.md ("Why the stock udev loader stopped working").
#
#  Safe to run at any time: if the printer already reports FWVER it does
#  nothing. Installed to /usr/local/sbin/hplj1020-firmware-upload and started
#  by hplj1020-firmware.service, which udev triggers on USB attach.
#
#  USAGE:  sudo bash scripts/hplj1020-firmware-upload.sh
# =============================================================================
set -euo pipefail

FWDIR="/var/lib/foo2zjs/firmware"
FW="$FWDIR/sihp1020.dl"
USB_BACKEND="/usr/lib/cups/backend/usb"
TAG="hplj1020-firmware"

ATTEMPTS="${ATTEMPTS:-3}"   # upload attempts before giving up
SETTLE="${SETTLE:-15}"      # seconds to wait for the device to appear each attempt

log() {
  logger -t "$TAG" -- "foo2zjs: $*" 2>/dev/null || true
  printf '%s: %s\n' "$TAG" "$*" >&2
}

if [[ $EUID -ne 0 ]]; then
  log "must run as root"
  exit 1
fi

if [[ ! -x "$USB_BACKEND" ]]; then
  log "CUPS usb backend $USB_BACKEND not found; install the cups package"
  exit 1
fi

if [[ ! -f "$FW" ]]; then
  log "missing firmware $FW; run scripts/install-firmware.sh"
  exit 1
fi

# Lines describing HP LaserJet 1020 devices currently visible to CUPS, e.g.
#   direct usb://HP/LaserJet%201020?serial=JL32RQZ "HP LaserJet 1020" ...
list_devices() {
  "$USB_BACKEND" 2>/dev/null | grep -i 'LaserJet.*1020' || true
}

upload() {
  local uri="$1"
  DEVICE_URI="$uri" "$USB_BACKEND" 1 1 1 1 '' "$FW" >/dev/null 2>&1
}

log "loader starting (firmware $FW)"

for attempt in $(seq 1 "$ATTEMPTS"); do
  # The USB node is often still settling when udev fires; give it a moment.
  for _ in $(seq 1 "$SETTLE"); do
    if [[ -n "$(list_devices)" ]]; then
      break
    fi
    sleep 1
  done

  devices="$(list_devices)"
  if [[ -z "$devices" ]]; then
    log "attempt $attempt/$ATTEMPTS: no HP LaserJet 1020 on USB; nothing to do"
    exit 0
  fi

  # Already running the firmware? Then there is nothing to do.
  if grep -qi 'FWVER' <<<"$devices"; then
    log "firmware already loaded (FWVER present); nothing to do"
    exit 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    uri="$(awk '{print $2}' <<<"$line")"
    log "attempt $attempt/$ATTEMPTS: uploading $FW to $uri"
    if upload "$uri"; then
      sleep 2
      if list_devices | grep -qi 'FWVER'; then
        log "$uri: download successful (FWVER verified)"
        exit 0
      fi
      log "$uri: upload returned success but no FWVER reported yet"
    else
      log "$uri: download failed (usb backend exit status != 0)"
    fi
  done <<<"$devices"

  sleep 3
done

log "giving up after $ATTEMPTS attempts; firmware was NOT uploaded"
exit 1
