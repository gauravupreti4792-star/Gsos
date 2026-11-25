#!/usr/bin/env bash
# GSOS final polish bundle: swirl window animation, layered Plymouth boot (logo + subtle
# background telemetry), no post-login splash, distinct icons, clean About GSOS, GSOS app names,
# and <2GB ISO compression/trimming.
# Called with $P (archiso profile) and $A ($P/airootfs) set. Runs after gsos-update.sh.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-polish] start"

mkdir -p \
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

# ---------- 2. Layered Plymouth boot (GSOS logo foreground + subtle background telemetry) ----------
cat > "$A/usr/share/plymouth/themes/gsos/gsos.plymouth" <<'GSOS_PLY_CONF'
[Plymouth Theme]
Name=GSOS
Description=GSOS logo with subtle background boot telemetry
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

max_lines = 12;
line_sprites = [];
for (i = 0; i < max_lines; i++) {
    line_sprites[i] = Sprite();
    line_sprites[i].SetZ(1);
}

fun on_update_status(msg) {
    if (msg == "") return;
    for (i = 0; i < max_lines - 1; i++) {
        line_sprites[i].SetImage(line_sprites[i + 1].GetImage());
    }
    // Subtle low-opacity background lines behind the GSOS logo
    txt = Image.Text(msg, 0.55, 0.72, 0.92, 0.14, "Monospace 11");
    line_sprites[max_lines - 1].SetImage(txt);

    top_y = h * 0.24;
    for (i = 0; i < max_lines; i++) {
        img = line_sprites[i].GetImage();
        if (img) {
            line_sprites[i].SetX(w / 2 - img.GetWidth() / 2);
            line_sprites[i].SetY(top_y + i * 22);
        }
    }
}

Plymouth.SetUpdateStatusFunction(on_update_status);

tick = 0;
fun on_refresh() {
    tick++;
    logo_sprite.SetOpacity(0.88 + 0.12 * Math.Sin(tick * 0.06));
}
Plymouth.SetRefreshFunction(on_refresh);
GSOS_PLY_SCRIPT

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

# ---------- 4. GSOS identity & unique app names ----------
mkdir -p "$A/usr/lib"
cat > "$A/usr/lib/os-release" <<'GSOS_OSREL'
NAME="GSOS"
PRETTY_NAME="GSOS"
ID=gsos
ID_LIKE=arch
BUILD_ID=rolling
HOME_URL="https://gauravupreti4792-star.github.io/Gsos/"
LOGO=gsos-launcher
GSOS_OSREL
ln -sf ../usr/lib/os-release "$A/etc/os-release"

# ---------- 5. Bootloader silent flags & <2GB zstd-22 compression ----------
SILENT_FLAGS="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 nowatchdog"
for cfg in "$P"/syslinux/*.cfg "$P"/efiboot/loader/entries/*.conf "$P"/grub/grub.cfg; do
  if [ -f "$cfg" ] && ! grep -q "vt.global_cursor_default=0" "$cfg"; then
    sed -i "s|archisobasedir=|${SILENT_FLAGS} archisobasedir=|g" "$cfg" || true
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
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme gsos || true
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
