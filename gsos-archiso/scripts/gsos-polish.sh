#!/usr/bin/env bash
# GSOS final polish bundle: swirl window animation, clean GSOS logo boot/shutdown,
# no post-login splash, distinct icons, clean About GSOS, GSOS app names, Calamares &
# GRUB GSOS branding, screenshot shortcuts, function keys, update app cleanup, full
# open-source store (Flatpak + GNOME Software), automatic post-install shortcut
# removal, and low-end hardware tuning.
# Called with $P (archiso profile) and $A ($P/airootfs) set. Runs after gsos-update.sh.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-polish] start"

for pkg in spectacle kglobalaccel kinfocenter zram-generator flatpak xdg-desktop-portal gnome-software; do
  grep -qx "$pkg" "$P/packages.x86_64" || printf '\n%s\n' "$pkg" >> "$P/packages.x86_64"
done

# ---------- Remove broken Update app & any limited 20-app store ----------
if [ -f "$P/packages.x86_64" ]; then
  sed -i -E '/^(gsos-update|update-manager|plasma-discover|gsos-store|gsos-appstore)$/d' "$P/packages.x86_64"
fi

rm -f \
  "$A"/usr/share/applications/*gsos*update*.desktop \
  "$A"/usr/share/applications/*update*app*.desktop \
  "$A"/usr/share/applications/*gsos*store*.desktop \
  "$A"/etc/xdg/autostart/*gsos*update*.desktop \
  "$A"/etc/xdg/autostart/*update*app*.desktop \
  "$A"/etc/skel/.config/autostart/*gsos*update*.desktop \
  "$A"/usr/local/bin/*gsos*update* \
  "$A"/usr/local/bin/gsos-updater \
  "$A"/usr/local/bin/*gsos*store*

mkdir -p \
  "$A/etc/default" \
  "$A/etc/plymouth" \
  "$A/etc/sysctl.d" \
  "$A/etc/systemd/system" \
  "$A/etc/xdg" \
  "$A/etc/skel/.config" \
  "$A/usr/local/bin" \
  "$A/usr/share/kwin/effects/gsos_swirl/contents/code" \
  "$A/usr/share/plymouth/themes/gsos" \
  "$A/usr/share/icons/hicolor/scalable/apps" \
  "$A/usr/share/applications"

# ---------- Post-install shortcut cleanup (only runs when installed, not on live ISO) ----------
cat > "$A/usr/local/bin/gsos-remove-installer-icon.sh" <<'GSOS_CLEAN_INSTALLER'
#!/usr/bin/env bash
set -u

if grep -qE '(^|[[:space:]])(archiso|boot=live|toram)([[:space:]]|$)' /proc/cmdline 2>/dev/null; then
  exit 0
fi

rm -f \
  /usr/share/applications/*calamares*.desktop \
  /usr/share/applications/*install*gsos*.desktop \
  /usr/share/applications/*gsos*install*.desktop \
  /etc/xdg/autostart/*calamares*.desktop \
  /etc/skel/Desktop/*calamares*.desktop \
  /etc/skel/Desktop/*install*.desktop \
  /home/*/Desktop/*calamares*.desktop \
  /home/*/Desktop/*install*.desktop 2>/dev/null || true

gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
kbuildsycoca6 --noincremental 2>/dev/null || true
GSOS_CLEAN_INSTALLER
chmod +x "$A/usr/local/bin/gsos-remove-installer-icon.sh"

cat > "$A/etc/systemd/system/gsos-post-install-cleanup.service" <<'GSOS_CLEAN_UNIT'
[Unit]
Description=GSOS one-time post-install installer shortcut cleanup
After=local-fs.target
ConditionPathExists=/usr/local/bin/gsos-remove-installer-icon.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gsos-remove-installer-icon.sh
ExecStartPost=/usr/bin/systemctl disable gsos-post-install-cleanup.service

[Install]
WantedBy=multi-user.target
GSOS_CLEAN_UNIT

# ---------- Low-end RAM swap via zram-generator ----------
cat > "$A/etc/systemd/zram-generator.conf" <<'GSOS_ZRAM'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
GSOS_ZRAM

# ---------- 1. Swirl KWin effect (One UI LockStar-inspired open & close) ----------
cat > "$A/usr/share/kwin/effects/gsos_swirl/metadata.json" <<'GSOS_SWIRL_META'
{
    "KPackageStructure": "KWin/Effect",
    "KPlugin": {
        "Authors": [{ "Name": "GSOS" }],
        "Category": "Appearance",
        "Description": "Fluid radial vortex, spring scale & opacity morph for windows",
        "EnabledByDefault": true,
        "Id": "gsos_swirl",
        "License": "MIT",
        "Name": "GSOS Swirl",
        "Version": "1.0"
    },
    "X-KDE-Ordering": 60,
    "X-Plasma-API": "javascript",
    "X-Plasma-MainScript": "code/main.js"
}
GSOS_SWIRL_META

cat > "$A/usr/share/kwin/effects/gsos_swirl/contents/code/main.js" <<'GSOS_SWIRL_JS'
"use strict";

var gsosSwirl = {
    duration: animationTime(280),
    isTarget: function (w) {
        if (!w || w.desktopWindow || w.dock || w.skipSwitcher) {
            return false;
        }
        return Boolean(w.normalWindow || w.dialog);
    },
    onWindowAdded: function (w) {
        if (!gsosSwirl.isTarget(w)) {
            return;
        }
        animate({
            window: w,
            duration: gsosSwirl.duration,
            curve: QEasingCurve.OutBack,
            animations: [
                { type: Effect.Scale, from: 0.84, to: 1.0 },
                { type: Effect.Rotation, from: -6.5, to: 0.0 },
                { type: Effect.Opacity, from: 0.0, to: 1.0 }
            ]
        });
    },
    onWindowClosed: function (w) {
        if (!gsosSwirl.isTarget(w)) {
            return;
        }
        animate({
            window: w,
            duration: Math.round(gsosSwirl.duration * 0.85),
            curve: QEasingCurve.InCubic,
            animations: [
                { type: Effect.Scale, from: 1.0, to: 0.82 },
                { type: Effect.Rotation, from: 0.0, to: 7.5 },
                { type: Effect.Opacity, from: 1.0, to: 0.0 }
            ]
        });
    },
    init: function () {
        effects.windowAdded.connect(gsosSwirl.onWindowAdded);
        effects.windowClosed.connect(gsosSwirl.onWindowClosed);
    }
};

gsosSwirl.init();
GSOS_SWIRL_JS

cat > "$A/etc/xdg/kwinrc" <<'GSOS_KWINRC'
[org.kde.kdecoration2][$i]
library=org.kde.breeze
theme=Breeze
ButtonsOnLeft=
ButtonsOnRight=IAX
CloseOnDoubleClickOnMenu=false

[Plugins]
gsos_swirlEnabled=true
scaleEnabled=false
glideEnabled=false
magiclampEnabled=false
blurEnabled=false
contrastEnabled=false

[Compositing]
LatencyPolicy=Low
AnimationSpeed=3
GSOS_KWINRC
cp "$A/etc/xdg/kwinrc" "$A/etc/skel/.config/kwinrc"

# ---------- 2. GSOS Plymouth Splash & Boot/Shutdown Tuning ----------
cat > "$A/etc/plymouth/plymouthd.conf" <<'GSOS_PLYD'
[Daemon]
Theme=gsos
ShowDelay=0
DeviceTimeout=8
GSOS_PLYD

cat > "$A/usr/share/plymouth/themes/gsos/gsos.plymouth" <<'GSOS_PLY_CONF'
[Plymouth Theme]
Name=GSOS
Description=Clean GSOS logo splash for boot and shutdown
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/gsos
ScriptFile=/usr/share/plymouth/themes/gsos/gsos.script
GSOS_PLY_CONF

cat > "$A/usr/share/plymouth/themes/gsos/gsos.script" <<'GSOS_PLY_SCRIPT'
Window.SetBackgroundTopColor(0.04, 0.05, 0.08);
Window.SetBackgroundBottomColor(0.02, 0.02, 0.04);

w = Window.GetWidth();
h = Window.GetHeight();

logo_img = Image("logo.png");
if (!logo_img) {
    logo_img = Image.Text("GSOS", 0.96, 0.98, 1.0, 1.0, "Sans Bold 44");
}
logo_sprite = Sprite(logo_img);
logo_sprite.SetX(w / 2 - logo_img.GetWidth() / 2);
logo_sprite.SetY(h / 2 - logo_img.GetHeight() / 2);
logo_sprite.SetZ(10);

fun silent_cb(msg) {}
Plymouth.SetUpdateStatusFunction(silent_cb);
Plymouth.SetMessageFunction(silent_cb);

tick = 0;
fun on_refresh() {
    tick++;
    logo_sprite.SetOpacity(0.88 + 0.12 * Math.Sin(tick * 0.06));
}
Plymouth.SetRefreshFunction(on_refresh);
GSOS_PLY_SCRIPT

cat > "$A/etc/sysctl.d/20-quiet-printk.conf" <<'GSOS_PRINTK'
kernel.printk = 3 3 1 3
GSOS_PRINTK

# Prevent post-login KSplash replay after password entry
cat > "$A/etc/xdg/ksplashrc" <<'GSOS_KSPLASH'
[KSplash]
Engine=none
Theme=None
GSOS_KSPLASH
cp "$A/etc/xdg/ksplashrc" "$A/etc/skel/.config/ksplashrc"

# ---------- 3. Distinct icons & About GSOS (no "Powered by Linux") ----------
cat > "$A/usr/share/icons/hicolor/scalable/apps/gsos-launcher.svg" <<'GSOS_HUB_SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="gHub" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1e7fff"/>
      <stop offset="1" stop-color="#3df0ff"/>
    </linearGradient>
  </defs>
  <rect x="6" y="6" width="52" height="52" rx="16" fill="url(#gHub)"/>
  <circle cx="23" cy="23" r="4.5" fill="#ffffff"/>
  <circle cx="41" cy="23" r="4.5" fill="#ffffff" opacity="0.85"/>
  <circle cx="23" cy="41" r="4.5" fill="#ffffff" opacity="0.85"/>
  <rect x="36.5" y="36.5" width="9" height="9" rx="2.5" fill="#ffffff"/>
</svg>
GSOS_HUB_SVG

cat > "$A/usr/share/icons/hicolor/scalable/apps/gsos-about.svg" <<'GSOS_ABOUT_SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="gAbout" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0f172a"/>
      <stop offset="1" stop-color="#1e293b"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="26" fill="url(#gAbout)" stroke="#3df0ff" stroke-width="3"/>
  <circle cx="32" cy="20.5" r="3" fill="#3df0ff"/>
  <rect x="29.5" y="27.5" width="5" height="16.5" rx="2.5" fill="#ffffff"/>
</svg>
GSOS_ABOUT_SVG

cat > "$A/etc/xdg/kcm-about-distrorc" <<'GSOS_ABOUT_RC'
[General]
Name=GSOS
Version=1.0
Variant=Desktop Edition
LogoPath=/usr/share/icons/hicolor/scalable/apps/gsos-about.svg
Website=https://gauravupreti4792-star.github.io/Gsos/
UseOSReleaseVersion=false
HideKernelVersion=true
GSOS_ABOUT_RC

cat > "$A/usr/share/applications/org.gsos.about.desktop" <<'GSOS_ABOUT_DESK'
[Desktop Entry]
Type=Application
Name=About GSOS
Comment=GSOS system overview and version info
Exec=kcmshell6 kcm_about-distro
Icon=gsos-about
Categories=System;Settings;
GSOS_ABOUT_DESK

# ---------- 4. Screenshots & function keys ----------
cat > "$A/etc/xdg/kglobalshortcutsrc" <<'GSOS_SHORTCUTS'
[org.kde.spectacle.desktop]
ActiveWindowScreenShot=Alt+Print,Alt+Print,Capture Current Window
FullScreenScreenShot=Print,Print,Capture Entire Screen
RectangularRegionScreenShot=Meta+Shift+S\tMeta+Shift+Print,Meta+Shift+S\tMeta+Shift+Print,Capture Rectangular Region
_launch=Print,Print,Launch Spectacle

[kwin]
Expose=none,none,Toggle Present Windows (Current desktop)
ExposeAll=none,none,Toggle Present Windows (All desktops)
ExposeClass=none,none,Toggle Present Windows (Window class)
Overview=none,none,Toggle Overview
ShowDesktopGrid=none,none,Toggle Grid View
Switch One Desktop Down=none,none,Switch One Desktop Down
Switch One Desktop Up=none,none,Switch One Desktop Up
Switch One Desktop to the Left=none,none,Switch One Desktop to the Left
Switch One Desktop to the Right=none,none,Switch One Desktop to the Right
GSOS_SHORTCUTS
cp "$A/etc/xdg/kglobalshortcutsrc" "$A/etc/skel/.config/kglobalshortcutsrc"

# ---------- 5. Bootloader silent flags & standard zstd compression ----------
SILENT_FLAGS="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog"
for cfg in "$P"/syslinux/*.cfg "$P"/efiboot/loader/entries/*.conf "$P"/grub/grub.cfg; do
  if [ -f "$cfg" ]; then
    sed -i -E "s/\b(quiet|splash|loglevel=[0-9]+|rd\.systemd\.show_status=[^ ]+|systemd\.show_status=[^ ]+|rd\.udev\.log_level=[0-9]+|udev\.log_level=[0-9]+|vt\.global_cursor_default=[0-9]+|nowatchdog)\b//g" "$cfg"
    sed -i "s|archisobasedir=|${SILENT_FLAGS} archisobasedir=|g" "$cfg"
    sed -i 's/Fancy GNU\/Linux[^"'\'']*/GSOS/g; s/\bArch Linux\b/GSOS/g' "$cfg" || true
  fi
done

if [ -f "$P/profiledef.sh" ]; then
  if grep -q "^airootfs_image_tool_options=" "$P/profiledef.sh"; then
    sed -i "s|^airootfs_image_tool_options=.*|airootfs_image_tool_options=('-comp' 'zstd' '-b' '1M')|" "$P/profiledef.sh"
  else
    printf "\nairootfs_image_tool_options=('-comp' 'zstd' '-b' '1M')\n" >> "$P/profiledef.sh"
  fi
fi

# ---------- 6. Hook into customize_airootfs.sh ----------
CUSTOM="$A/root/customize_airootfs.sh"
if [ -f "$CUSTOM" ] && ! grep -q "# \[gsos-polish\] hook" "$CUSTOM"; then
  cat >> "$CUSTOM" <<'GSOS_CUSTOM_HOOK'

# [gsos-polish] hook
if [ -f /etc/os-release ]; then
  sed -i 's/^NAME=.*/NAME="GSOS"/; s/^PRETTY_NAME=.*/PRETTY_NAME="GSOS"/; s/^ID=.*/ID=gsos/' /etc/os-release || true
fi

if [ -f /etc/default/grub ]; then
  if grep -q '^GRUB_DISTRIBUTOR=' /etc/default/grub; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="GSOS"/' /etc/default/grub
  else
    printf '\nGRUB_DISTRIBUTOR="GSOS"\n' >> /etc/default/grub
  fi
  if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog"/' /etc/default/grub
  fi
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme gsos || true
fi

if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/gsos-post-install-cleanup.service ]; then
  systemctl enable gsos-post-install-cleanup.service 2>/dev/null || true
fi

for cal_dir in /etc/calamares /usr/share/calamares; do
  if [ -d "$cal_dir" ]; then
    grep -rl "Fancy GNU/Linux" "$cal_dir" 2>/dev/null \
      | xargs -r sed -i 's/Fancy GNU\/Linux[^"'\'']*/GSOS/g'
    grep -rl "Arch Linux" "$cal_dir" 2>/dev/null \
      | xargs -r sed -i 's/\bArch Linux\b/GSOS/g'
  fi
done

if [ -f /etc/calamares/settings.conf ]; then
  mkdir -p /etc/calamares/branding/gsos
  if [ -d /etc/calamares/branding/default ] && [ -z "$(ls -A /etc/calamares/branding/gsos 2>/dev/null)" ]; then
    cp -r /etc/calamares/branding/default/. /etc/calamares/branding/gsos/ || true
  fi
  sed -i 's/branding:[[:space:]]*.*/branding: gsos/' /etc/calamares/settings.conf || true
  find /etc/calamares/branding/gsos -type f \( -name '*.desc' -o -name '*.conf' -o -name '*.qml' \) \
    -exec sed -i 's/Fancy GNU\/Linux[^"'\'']*/GSOS/g; s/\bArch Linux\b/GSOS/g' {} + || true
fi

if [ -f /etc/calamares/modules/shellprocess.conf ]; then
  if ! grep -q "gsos-remove-installer-icon.sh" /etc/calamares/modules/shellprocess.conf; then
    printf '\n    - command: "/usr/local/bin/gsos-remove-installer-icon.sh"\n      timeout: 30\n' >> /etc/calamares/modules/shellprocess.conf
  fi
fi

declare -A GSOS_APP_RENAMES=(
  ["org.kde.dolphin.desktop"]="GSOS Files"
  ["org.kde.konsole.desktop"]="GSOS Shell"
  ["org.kde.kate.desktop"]="GSOS Notes"
  ["org.kde.spectacle.desktop"]="GSOS Snap"
  ["org.kde.ark.desktop"]="GSOS Archive"
  ["org.kde.plasma-systemmonitor.desktop"]="GSOS Monitor"
  ["systemsettings.desktop"]="GSOS Settings"
)
for app_file in "${!GSOS_APP_RENAMES[@]}"; do
  if [ -f "/usr/share/applications/$app_file" ]; then
    sed -i "s|^Name=.*|Name=${GSOS_APP_RENAMES[$app_file]}|" "/usr/share/applications/$app_file"
  fi
done

rm -f \
  /usr/share/applications/*gsos*update*.desktop \
  /usr/share/applications/*update*app*.desktop \
  /etc/xdg/autostart/*gsos*update*.desktop \
  /etc/xdg/autostart/*update*app*.desktop \
  /usr/local/bin/*gsos*update* \
  /usr/local/bin/gsos-updater \
  /usr/local/bin/*gsos*store*

gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
kbuildsycoca6 --noincremental || true

rm -rf /usr/lib/firmware/{liquidio,netronome,mellanox,qlogic,bnx2x,cxgb4,qed}
rm -rf /var/cache/pacman/pkg/* /usr/share/doc/* /usr/share/man/* /usr/share/gtk-doc/*
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} +
GSOS_CUSTOM_HOOK
fi

echo "[gsos-polish] done"
