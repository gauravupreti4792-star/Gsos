#!/usr/bin/env bash
# GSOS first-login setup. Runs once per user (autostart entry:
# /etc/xdg/autostart/gsos-first-login.desktop).
#   1. auto performance profile   2. macOS-style theme + GSOS look defaults
#   3. top menu bar + floating dock + GSOS wallpaper   4. launches the installer on the live ISO
set -u

FLAG="$HOME/.config/gsos/first-login-done"
LOG="$HOME/.cache/gsos-first-login.log"
mkdir -p "$(dirname "$FLAG")" "$(dirname "$LOG")"
[[ -f "$FLAG" ]] && exit 0
exec >>"$LOG" 2>&1
echo "=== GSOS first login $(date) ==="

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "GSOS" "$1" || true; }
is_live() { grep -qw 'archisobasedir' /proc/cmdline 2>/dev/null; }

QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)"
wait_for_plasma() {
  [[ -n "$QDBUS" ]] || return 1
  for _ in $(seq 1 60); do
    "$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && { sleep 4; return 0; }
    sleep 1
  done
  return 1
}

# --- 1) Performance profile
if pkexec /usr/local/bin/gsos-profile-switcher --profile auto; then
  echo "profile: auto applied"
else
  echo "profile: auto failed"
  notify "Open 'GSP Performance Manager' to choose Lite, Smooth, Balanced or Liquid."
fi

# --- 2) Theme, then GSOS look defaults (applied after the theme so they win)
/usr/local/bin/gsos-theme-installer --apply-only || echo "theme: apply-only failed"

KW="$(command -v kwriteconfig6 || true)"
if [[ -n "$KW" ]]; then
  # macOS-style window buttons on the LEFT: Close, Minimize, Maximize
  "$KW" --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
  "$KW" --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
  # GSOS startup splash
  "$KW" --file ksplashrc --group KSplash --key Engine KSplashQML
  "$KW" --file ksplashrc --group KSplash --key Theme org.gsos.splash
  # GSOS lock screen wallpaper
  "$KW" --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
        --key Image "file:///usr/share/gsos/wallpaper.jpg"
  [[ -n "$QDBUS" ]] && "$QDBUS" org.kde.KWin /KWin reconfigure || true
fi

# --- 3) Top menu bar + floating dock (GSOS "G" as the launcher button)
LAYOUT_JS="$(mktemp --suffix=.js)"
cat > "$LAYOUT_JS" <<'JS'
panels().forEach(function (p) { p.remove(); });

var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.7);
top.floating = false;
top.lengthMode = "fill";
top.hiding = "none";
var launcher = top.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "/usr/share/gsos/gsos-mark.svg");
top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");
top.addWidget("org.kde.plasma.digitalclock");

var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.4);
dock.floating = true;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
  "applications:org.kde.dolphin.desktop",
  "applications:firefox.desktop",
  "applications:org.kde.konsole.desktop",
  "applications:systemsettings.desktop",
  "applications:org.gsos.profilemanager.desktop"
]);
JS

if wait_for_plasma; then
  "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$LAYOUT_JS")" \
    && echo "layout: applied" || echo "layout: evaluateScript failed"
  # GSOS wallpaper (after the theme, so it replaces the theme's own wallpaper)
  command -v plasma-apply-wallpaperimage >/dev/null 2>&1 \
    && plasma-apply-wallpaperimage /usr/share/gsos/wallpaper.jpg \
    && echo "wallpaper: applied" || echo "wallpaper: not applied"
else
  echo "layout: plasmashell not reachable; skipped"
  notify "Could not build the dock layout automatically. See ~/.cache/gsos-first-login.log"
fi
rm -f "$LAYOUT_JS"

touch "$FLAG"

# --- 4) Live ISO only: open the installer
if is_live && command -v calamares >/dev/null 2>&1; then
  echo "launching calamares"
  sudo -n -E calamares >/dev/null 2>&1 &
fi
exit 0
