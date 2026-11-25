#!/usr/bin/env bash
# GSOS update script: disables the broken custom GSOS Update app/tray/launcher
# while preserving first-boot keyring initialization for installed systems.
# Called by the build workflow with $P (archiso profile) and $A ($P/airootfs) set.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-update] start"

mkdir -p "$A/etc/systemd/system/multi-user.target.wants"

# ---------- Remove any leftover custom GSOS Update files ----------
rm -f \
  "$A/usr/local/bin/gsos-update.py" \
  "$A/usr/local/bin/gsos-update-apply" \
  "$A/usr/share/gsos/gsos-update.svg" \
  "$A/usr/share/applications/org.gsos.update.desktop" \
  "$A/etc/xdg/autostart/gsos-update-tray.desktop" \
  "$A/usr/share/polkit-1/actions/org.gsos.update.policy"

# ---------- Package keyring on first start of an installed system ----------
cat > "$A/etc/systemd/system/gsos-keyring-init.service" <<'GSOS_KEYRING'
[Unit]
Description=Set up the GSOS package keyring (first start of an installed system)
ConditionPathExists=!/etc/pacman.d/gnupg/trustdb.gpg
ConditionPathExists=!/run/archiso

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate archlinux
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
GSOS_KEYRING
ln -sf /etc/systemd/system/gsos-keyring-init.service "$A/etc/systemd/system/multi-user.target.wants/gsos-keyring-init.service"

# ---------- Unpin org.gsos.update.desktop from first-login script if present ----------
FIRST="$A/usr/local/bin/gsos-first-login.sh"
if [ -f "$FIRST" ]; then
  sed -i '/"applications:org\.gsos\.update\.desktop",/d; /"applications:org\.gsos\.update\.desktop"/d' "$FIRST"
fi

echo "[gsos-update] done (custom Update app disabled)"
