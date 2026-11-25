#!/usr/bin/env bash
# GSOS final polish bundle: swirl window animation, zero-text GSOS logo boot/shutdown,
# no post-login splash, distinct icons, clean About GSOS, GSOS app names, Calamares GSOS
# branding, screenshot shortcuts, function keys, and <2GB ISO compression/trimming.
# Called with $P (archiso profile) and $A ($P/airootfs) set. Runs after gsos-update.sh.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-polish] start"

for pkg in spectacle kglobalaccel kinfocenter; do
  grep -qx "$pkg" "$P/packages.x86_64" || printf '\n%s\n' "$pkg" >> "$P/packages.x86_64"
done

mkdir -p \
  "$A/etc/plymouth" \
  "$A/etc/sysctl.d" \
  "$A/etc/xdg" \
  "$A/etc/skel/.config" \
  "$A/usr/local/bin" \
  "$A/usr/share/kwin/effects/gsos_swirl/contents/code" \
  "$A/usr/share/plymouth/themes/gsos" \
  "$A/usr/share/icons/hicolor/scalable/apps" \
  "$A/usr/share/applications"

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
blurEnabled=true
contrastEnabled=true

[Compositing]
LatencyPolicy=Low
AnimationSpeed=3
GSOS_KWINRC
cp "$A/etc/xdg/kwinrc" "$A/etc/skel/.config/kwinrc"

# ---------- 2. Strict Zero-Text GSOS Plymouth Boot & Shutdown ----------
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
kernel.printk = 0 0 0 0
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

# ---------- 4. Screenshots & function keys (os-release is written inside customize_airootfs.sh) ----------
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

# ---------- 5. Bootloader silent flags & <2GB zstd-22 compression ----------
SILENT_FLAGS="quiet splash loglevel=0 rd.systemd.show_status=false systemd.show_status=false rd.udev.log_level=0 udev.log_level=0 vt.global_cursor_default=0 nowatchdog"
for cfg in "$P"/syslinux/*.cfg "$P"/efiboot/loader/entries/*.conf "$P"/grub/grub.cfg; do
  if [ -f "$cfg" ]; then
    sed -i -E "s/\b(quiet|splash|loglevel=[0-9]+|rd\.systemd\.show_status=[^ ]+|systemd\.show_status=[^ ]+|rd\.udev\.log_level=[0-9]+|udev\.log_level=[0-9]+|vt\.global_cursor_default=[0-9]+|nowatchdog)\b//g" "$cfg"
    sed -i "s|archisobasedir=|${SILENT_FLAGS} archisobasedir=|g" "$cfg"
  fi
done

if [ -f "$P/profiledef.sh" ]; then
  if grep -q "^airootfs_image_tool_options=" "$P/profiledef.sh"; then
    sed -i "s|^airootfs_image_tool_options=.*|airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '22' '-b' '1M')|" "$P/profiledef.sh"
  else
    printf "\nairootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '22' '-b' '1M')\n" >> "$P/profiledef.sh"
  fi
fi

# ---------- 6. Hook into customize_airootfs.sh ----------
CUSTOM="$A/root/customize_airootfs.sh"
if [ -f "$CUSTOM" ] && ! grep -q "# \[gsos-polish\] hook" "$CUSTOM"; then
  cat >> "$CUSTOM" <<'GSOS_CUSTOM_HOOK'

# [gsos-polish] hook
systemctl mask getty@tty1.service || true

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme gsos || true
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

gtk-update-icon-cache -f -t /usr/share/icons/hicolor || true
kbuildsycoca6 --noincremental || true

rm -rf /usr/lib/firmware/{liquidio,netronome,mellanox,qlogic,bnx2x,cxgb4,qed}
rm -rf /var/cache/pacman/pkg/* /usr/share/doc/* /usr/share/man/* /usr/share/gtk-doc/*
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} +
GSOS_CUSTOM_HOOK
fi

echo "[gsos-polish] done"
