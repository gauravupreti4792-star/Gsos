#!/usr/bin/env bash
# Runs inside the airootfs chroot during `mkarchiso` (the file is deleted afterwards).
# Note: archiso marks customize_airootfs.sh as deprecated but still runs it.
set -uo pipefail

echo "[GSOS] customize_airootfs.sh starting"

# --- Locale / time -------------------------------------------------------
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "gsos" > /etc/hostname

# --- Your scripts (copied into airootfs/usr/local/bin by the build) ---
for f in gsos-profile-switcher gsos-theme-installer gsos-profile-menu gsos-first-login.sh; do
  if [[ -f "/usr/local/bin/$f" ]]; then
    chmod 0755 "/usr/local/bin/$f"
  else
    echo "[GSOS] WARNING: /usr/local/bin/$f is missing"
  fi
done

# --- macOS-style theme, installed system-wide ------------------------------
if [[ -x /usr/local/bin/gsos-theme-installer ]]; then
  /usr/local/bin/gsos-theme-installer --system || echo "[GSOS] WARNING: theme installer failed; ISO will build without the theme"
fi

# --- GSOS branding: what System Settings > About and the login screens show ---
cat > /usr/lib/os-release <<'OSR'
NAME="GSOS"
PRETTY_NAME="GSOS 1.1 (powered by Linux)"
ID=gsos
ID_LIKE=arch
VERSION="1.1"
VERSION_ID=1.1
BUILD_ID=rolling
ANSI_COLOR="38;2;228;226;221"
OSR
ln -sf ../usr/lib/os-release /etc/os-release
printf 'GSOS \\r (\\l)\n\n' > /etc/issue

# --- Installer branding: show "GSOS" instead of "Arch Linux" (only switches if the copy works) ---
if [[ -d /usr/share/calamares/branding/default && -f /etc/calamares/settings.conf ]]; then
  mkdir -p /etc/calamares/branding
  cp -r /usr/share/calamares/branding/default /etc/calamares/branding/gsos
  sed -i 's/Arch Linux/GSOS/g; s/^componentName:.*/componentName: gsos/' /etc/calamares/branding/gsos/branding.desc
  sed -i 's/^branding:.*/branding: gsos/' /etc/calamares/settings.conf
fi

# --- GSOS login screen background (shown on installed systems) ---
if [[ -d /usr/share/sddm/themes/breeze ]]; then
  printf '[General]\nbackground=/usr/share/gsos/wallpaper.jpg\ntype=image\n' \
    > /usr/share/sddm/themes/breeze/theme.conf.user
fi

# --- Live user + passwordless sudo (live session only) ---------------------
if ! id liveuser >/dev/null 2>&1; then
  useradd -m -G wheel,video,audio,input,storage,optical,network -s /bin/bash liveuser
fi
passwd -d liveuser
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/g_wheel
chmod 0440 /etc/sudoers.d/g_wheel

# Desktop icon for the installer must be executable to be trusted by Plasma.
install -d -o liveuser -g liveuser /home/liveuser/Desktop
cp -f /etc/skel/Desktop/install-gsos.desktop /home/liveuser/Desktop/
chmod 0755 /home/liveuser/Desktop/install-gsos.desktop
chown -R liveuser:liveuser /home/liveuser

# --- Services ----------------------------------------------------------------
systemctl enable sddm.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable waydroid-container.service
systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl disable iwd.service 2>/dev/null || true
systemctl set-default graphical.target

install -d /var/lib/waydroid

echo "[GSOS] customize_airootfs.sh finished"
