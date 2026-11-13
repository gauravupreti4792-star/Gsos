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

# --- Your two scripts (copied into airootfs/usr/local/bin by BUILD_GSOS.md) ---
for f in gsos-profile-switcher gsos-theme-installer gsos-profile-menu gsos-first-login.sh; do
  if [[ -f "/usr/local/bin/$f" ]]; then
    chmod 0755 "/usr/local/bin/$f"
  else
    echo "[GSOS] WARNING: /usr/local/bin/$f is missing"
  fi
done

# --- macOS-style theme, installed system-wide ------------------------------
# Needs network inside the chroot; a failure is logged but does not abort the ISO build.
if [[ -x /usr/local/bin/gsos-theme-installer ]]; then
  /usr/local/bin/gsos-theme-installer --system || echo "[GSOS] WARNING: theme installer failed; ISO will build without the theme"
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
# Prevent conflicts with archiso's default networkd/iwd setup; NetworkManager owns networking.
systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl disable iwd.service 2>/dev/null || true
systemctl set-default graphical.target
# Ollama stays disabled by default (keeps RAM free on low-end PCs); GSPI starts it on demand.

# --- Waydroid needs these directories to exist ----------------------------------
install -d /var/lib/waydroid

# --- Flatpak: Bottles/Heroic can be added later from the live or installed system -------
# (flathub is added at first network use: flatpak remote-add --if-not-exists flathub ...)

echo "[GSOS] customize_airootfs.sh finished"
