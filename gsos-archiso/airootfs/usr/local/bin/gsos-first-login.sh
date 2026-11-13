#!/usr/bin/env bash
# GSOS first-login setup. Runs once per user (autostart entry:
# /etc/xdg/autostart/gsos-first-login.desktop).
#   1. auto performance profile   2. macOS theme   3. floating dock + top menu bar
#   4. launches Calamares when running from the live ISO
set -u

FLAG="$HOME/.config/gsos/first-login-done"
LOG="$HOME/.cache/gsos-first-login.log"
mkdir -p "$(dirname "$FLAG")" "$(dirname "$LOG")"
[[ -f "$FLAG" ]] && exit 0
exec >>"$LOG" 2>&1
echo "=== GSOS first login $(date) ==="

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "GSOS" "$1" || true; }
is_live() { grep -qw 'archisobasedir' /proc/cmdline 2>/dev/null; }

# Plasma scripting needs the shell to be up on D-Bus.
QDBUS="$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)"
wait_for_plasma() {
  [[ -n "$QDBUS" ]] || return 1
  for _ in $(seq 1 60); do
    "$QDBUS" org.kde.plasmashell /PlasmaShell >/dev/null 2>&1 && { sleep 4; return 0; }
    sleep 1
  done
  return 1
}

# --- 1) Performance profile (passwordless on the live ISO via a polkit rule; prompts on an installed system)
if pkexec /usr/local/bin/gsos-profile-switcher --profile auto; then
  echo "profile: auto applied"
else
  echo "profile: auto failed"
  notify "Open 'GSP Performance Manager' to choose Lite, Smooth, Balanced or Liquid."
fi

# --- 2) macOS theme (themes were installed system-wide at build time)
/usr/local/bin/gsos-theme-installer --apply-only || echo "theme: apply-only failed"

# --- 3) Floating macOS-style dock + top global menu bar
LAYOUT_JS="$(mktemp --suffix=.js)"
cat > "$LAYOUT_JS" <<'JS'
// Remove existing panels, then build: top menu bar + floating bottom dock.
panels().forEach(function (p) { p.remove(); });

var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.7);
top.floating = false;
top.lengthMode = "fill";
top.hiding = "none";
top.addWidget("org.kde.plasma.kickoff");
top.addWidget("org.kde.plasma.appmenu");        // global menu
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
