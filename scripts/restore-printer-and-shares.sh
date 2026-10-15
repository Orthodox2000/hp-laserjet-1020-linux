#!/usr/bin/env bash
# =============================================================================
#  restore-printer-and-shares.sh
#  One-shot setup for an HP LaserJet 1020 on Linux Mint/Ubuntu:
#    * foo2zjs CUPS queue + the sihp1020.dl firmware (auto-uploaded)
#    * CUPS LAN/IPP sharing (driverless for macOS/iOS/Android/Linux)
#    * Samba sharing so Windows can print with HP's own driver (raw)
#    * wsdd (WS-Discovery) so the server shows up in Windows "Network"
#    * optionally: auto-mount + share an NTFS drive with full write access
#
#  USAGE:
#     sudo bash scripts/restore-printer-and-shares.sh
#
#  OPTIONAL ENVIRONMENT VARIABLES:
#     PRINT_QUEUE=HP-LaserJet-1020
#     SMB_USER=printer  SMB_PASS=printer123
#     ENABLE_DRIVE_SHARE=yes  DRIVE_UUID=XXXX  DRIVE_LABEL=shared
#
#  Idempotent: safe to re-run. Auto-detects the invoking user.
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PRINT_QUEUE="${PRINT_QUEUE:-HP-LaserJet-1020}"
SMB_USER="${SMB_USER:-printer}"
SMB_PASS="${SMB_PASS:-printer123}"
ENABLE_DRIVE_SHARE="${ENABLE_DRIVE_SHARE:-no}"
DRIVE_UUID="${DRIVE_UUID:-}"
DRIVE_LABEL="${DRIVE_LABEL:-shared}"

if [[ $EUID -ne 0 ]]; then
  echo "Run me with sudo:  sudo bash $0" >&2
  exit 1
fi

USER_NAME="${SUDO_USER:-${USER:-root}}"
USER_ID="$(id -u "$USER_NAME" 2>/dev/null || echo 0)"
USER_GID="$(id -g "$USER_NAME" 2>/dev/null || echo 0)"

echo "==> Setup for user: $USER_NAME (uid=$USER_ID)   queue: $PRINT_QUEUE"

echo "==> 1/9 Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y printer-driver-foo2zjs cups cups-client cups-filters \
                   samba samba-common-bin smbclient wsdd avahi-daemon

echo "==> 2/9 Installing firmware (required on every power-up)"
install -d -m 755 /var/lib/foo2zjs/firmware
if [[ -f "$ROOT_DIR/firmware/sihp1020.dl" ]]; then
  install -m 644 "$ROOT_DIR/firmware/sihp1020.dl" /var/lib/foo2zjs/firmware/sihp1020.dl
else
  echo "    WARNING: firmware/sihp1020.dl missing from repo; run install-firmware.sh" >&2
fi

echo "==> 3/9 Neutralising HPLIP's competing udev helper"
RULE="/usr/lib/udev/rules.d/56-hpmud.rules"
if [[ -f "$RULE" ]]; then
  sed -i 's|^\(ENV{hp_test}=="yes", PROGRAM=.*hp-config_usb_printer.*\)$|# disabled for foo2zjs: \1|' "$RULE" || true
fi
rm -f /usr/share/hplip/data/firmware/*.fw.gz 2>/dev/null || true
udevadm control --reload-rules 2>/dev/null || true

echo "==> 4/9 Creating the CUPS print queue"
URI="$(/usr/lib/cups/backend/usb 2>/dev/null | awk '/LaserJet.*1020/{print $2; exit}')"
if [[ -z "${URI:-}" ]]; then
  if [[ -f /etc/cups/printers.conf ]] && grep -q "DeviceURI" /etc/cups/printers.conf; then
    URI="usb://HP/LaserJet%201020"
  else
    URI="usb://HP/LaserJet%201020"
  fi
fi
echo "    device uri: $URI"
lpadmin -p "$PRINT_QUEUE" -E -v "$URI" -P "$ROOT_DIR/config/HP-LaserJet-1020.ppd" \
        -o printer-is-shared=true
lpadmin -d "$PRINT_QUEUE"
cupsenable "$PRINT_QUEUE" 2>/dev/null || true
cupsaccept  "$PRINT_QUEUE" 2>/dev/null || true

echo "==> 5/9 Sharing the printer on the LAN (CUPS)"
cupsctl --share-printers
[[ -f /etc/cups/cupsd.conf && ! -f /etc/cups/cupsd.conf.bak ]] && \
  cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak || true
python3 - <<'PY'
p = "/etc/cups/cupsd.conf"
s = open(p).read()
if "Listen 0.0.0.0:631" not in s:
    s = s.replace("Listen localhost:631", "Listen 0.0.0.0:631\nListen [::]:631", 1)
s = s.replace("Browsing No", "Browsing On", 1)
if "Allow @LOCAL" not in s:
    s = s.replace("<Location />\n  Order allow,deny\n</Location>",
                  "<Location />\n  Order allow,deny\n  Allow @LOCAL\n</Location>", 1)
open(p, "w").write(s)
PY
systemctl restart cups

echo "==> 6/9 Configuring Samba (Windows sharing)"
install -d -m 1777 /var/spool/samba
install -d -m 755  /var/lib/samba/printers
cp "$ROOT_DIR/config/smb.conf" /etc/samba/smb.conf
# Make the explicit printer share name match the queue.
sed -i "s|^\\(\\s*printer name = \\).*|\\1$PRINT_QUEUE|" /etc/samba/smb.conf
testparm -s >/dev/null
# Fallback SMB login (used when Windows blocks passwordless guest access).
if ! id "$SMB_USER" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "$SMB_USER"
fi
printf '%s\n%s\n' "$SMB_PASS" "$SMB_PASS" | smbpasswd -a -s "$SMB_USER"

echo "==> 7/9 Optional shared drive"
if [[ "$ENABLE_DRIVE_SHARE" == "yes" ]]; then
  if [[ -z "$DRIVE_UUID" ]]; then
    echo "    ENABLE_DRIVE_SHARE=yes but DRIVE_UUID is empty; skipping" >&2
  else
    MOUNT_POINT="/media/$USER_NAME/$DRIVE_LABEL"
    if ! grep -q "$DRIVE_UUID" /etc/fstab; then
      mkdir -p "$MOUNT_POINT"
      printf 'UUID=%s %s ntfs-3g defaults,nofail,uid=%s,gid=%s,umask=000,x-gvfs-show 0 0\n' \
             "$DRIVE_UUID" "$MOUNT_POINT" "$USER_ID" "$USER_GID" >> /etc/fstab
    fi
    systemctl daemon-reload
    mount -a || true
    if ! grep -q "^\[$DRIVE_LABEL\]" /etc/samba/smb.conf; then
      cat >> /etc/samba/smb.conf <<EOF

[$DRIVE_LABEL]
   comment = Shared folder ($DRIVE_LABEL)
   path = $MOUNT_POINT
   browseable = yes
   guest ok = yes
   read only = no
   writable = yes
   force user = $USER_NAME
   force group = $USER_NAME
   create mask = 0777
   directory mask = 0777
EOF
    fi
    echo "    shared $MOUNT_POINT as \\\\$HOSTNAME\\$DRIVE_LABEL"
  fi
else
  echo "    skipped (set ENABLE_DRIVE_SHARE=yes, DRIVE_UUID=... to enable)"
fi

echo "==> 8/9 WSD discovery + Samba mount dependencies"
install -m 644 "$ROOT_DIR/systemd/wsdd.service" /etc/systemd/system/wsdd.service
install -d /etc/systemd/system/smbd.service.d /etc/systemd/system/nmbd.service.d
if [[ "$ENABLE_DRIVE_SHARE" == "yes" && -n "$DRIVE_UUID" ]]; then
  printf '[Unit]\nRequiresMountsFor=/media/%s/%s\nAfter=network-online.target\n' \
         "$USER_NAME" "$DRIVE_LABEL" > /etc/systemd/system/smbd.service.d/override.conf
  cp /etc/systemd/system/smbd.service.d/override.conf /etc/systemd/system/nmbd.service.d/override.conf
else
  printf '[Unit]\nAfter=network-online.target\n' > /etc/systemd/system/smbd.service.d/override.conf
  cp /etc/systemd/system/smbd.service.d/override.conf /etc/systemd/system/nmbd.service.d/override.conf
fi
systemctl daemon-reload
systemctl enable --now cups smbd nmbd wsdd
systemctl restart smbd nmbd 2>/dev/null || true

echo "==> 9/9 Uploading firmware now (so it prints without a power cycle)"
SUBSYSTEM=usb /usr/lib/udev/hplj1020 2>/dev/null || true
udevadm trigger --action=add --sysname-match='1-9' 2>/dev/null || true
sleep 1

IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
cat <<EOF

============================================================
 DONE.
   Print queue : $PRINT_QUEUE  (system default)
   IPP URL     : http://$IP:631/printers/$PRINT_QUEUE
   SMB printer : \\\\$HOSTNAME\\$PRINT_QUEUE
   Windows login (if guest is blocked): $SMB_USER / $SMB_PASS
 On Windows: open  \\\\$IP  in Explorer.
============================================================
EOF
