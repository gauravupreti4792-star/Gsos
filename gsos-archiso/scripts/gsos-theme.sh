#!/usr/bin/env bash
# GSOS theme bundle: locked slate-and-blue theme, wallpaper, taskbar, GSOS Store, GSOS About, branding.
# Called by the build workflow with $P (archiso profile) and $A ($P/airootfs) set.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-theme] start"

for pkg in papirus-icon-theme python-pyqt6 pciutils flatpak nbd plymouth noto-fonts qt6-declarative qt6-5compat; do
  grep -qx "$pkg" "$P/packages.x86_64" || printf '\n%s\n' "$pkg" >> "$P/packages.x86_64"
done

G="$A/usr/share/gsos"
S="$A/usr/share/plasma/look-and-feel/org.gsos.splash"
L="$A/usr/share/plasma/look-and-feel/org.kde.gsos.lockscreen"
D="$A/usr/share/sddm/themes/gsos-dark"
PT="$A/usr/share/plymouth/themes/gsos"
mkdir -p \
  "$G" \
  "$S/contents/splash" \
  "$L/contents/lockscreen" \
  "$D" \
  "$PT" \
  "$A/etc/plymouth" \
  "$A/etc/sddm.conf.d" \
  "$A/etc/sysctl.d" \
  "$A/etc/xdg/autostart" \
  "$A/usr/local/bin" \
  "$A/usr/share/applications" \
  "$A/etc/calamares/modules" \
  "$A/root"

# ============================================================ 1) THE LOCKED THEME ([$i] = read-only for users)
colors() {  # name alternate-background normal-background [nested-group]
  printf '[Colors:%s]%s[$i]\n' "$1" "${4:-}"
  printf 'BackgroundAlternate=%s\nBackgroundNormal=%s\n' "$2" "$3"
  printf '%s\n' 'DecorationFocus=30,127,255' 'DecorationHover=64,156,255' 'ForegroundActive=245,166,35' \
    'ForegroundInactive=139,149,163' 'ForegroundLink=90,169,255' 'ForegroundNegative=255,92,92' \
    'ForegroundNeutral=245,166,35' 'ForegroundNormal=230,234,240' 'ForegroundPositive=61,220,132' \
    'ForegroundVisited=167,139,250' ''
}
{
  cat <<'GSOS_KG'
# GSOS system-wide look. Dark slate palette with electric-blue accents, Papirus icons, Firefox as the browser.
# Entries marked [$i] are read-only for users.

[General]
ColorScheme[$i]=GSOSSlate
Name[$i]=GSOS Slate
AccentColor[$i]=30,127,255
LastUsedCustomAccentColor[$i]=30,127,255
BrowserApplication[$i]=firefox.desktop
shadeSortColumn[$i]=true

[Icons][$i]
Theme=Papirus-Dark

[KDE]
widgetStyle[$i]=Breeze
AnimationDurationFactor[$i]=0.6
contrast[$i]=4

[WM][$i]
activeBackground=27,32,39
activeBlend=27,32,39
activeForeground=230,234,240
inactiveBackground=32,38,45
inactiveBlend=32,38,45
inactiveForeground=139,149,163

# Settings pages that change the look are hidden for users.
[KDE Control Module Restrictions][$i]
kcm_colors=false
kcm_icons=false
kcm_desktoptheme=false
kcm_lookandfeel=false
kcm_style=false
kcm_cursortheme=false
kcm_kwindecoration=false
kcm_splashscreen=false

GSOS_KG
  colors Window 38,45,53 32,38,45
  colors View 29,35,42 24,29,35
  colors Button 52,62,73 45,54,64
  colors Complementary 33,39,47 27,32,39
  colors Header 33,39,47 27,32,39
  colors Header 33,39,47 32,38,45 '[Inactive]'
  colors Tooltip 33,39,47 27,32,39
  cat <<'GSOS_SEL'
[Colors:Selection][$i]
BackgroundAlternate=24,110,230
BackgroundNormal=30,127,255
DecorationFocus=30,127,255
DecorationHover=64,156,255
ForegroundActive=255,255,255
ForegroundInactive=205,224,255
ForegroundLink=255,255,255
ForegroundNegative=255,200,200
ForegroundNeutral=255,230,170
ForegroundNormal=255,255,255
ForegroundPositive=190,255,215
ForegroundVisited=220,205,255
GSOS_SEL
} > "$A/etc/xdg/kdeglobals"

cat > "$A/etc/xdg/kwinrc" <<'GSOS_KWIN'
# GSOS window manager: controls on the right (minimize, maximize, close), crisp animations, edge snapping.
[org.kde.kdecoration2][$i]
library=org.kde.breeze
theme=Breeze
ButtonsOnLeft=
ButtonsOnRight=IAX
CloseOnDoubleClickOnMenu=false

[Plugins]
blurEnabled[$i]=false
contrastEnabled[$i]=false
magiclampEnabled[$i]=false
wobblywindowsEnabled[$i]=false
squashEnabled[$i]=false
fadeEnabled=true
fadingpopupsEnabled=true
slidingpopupsEnabled=true
slideEnabled=true

[Windows]
ElectricBorderMaximize=true
ElectricBorderTiling=true
ElectricBorderCornerRatio=0.25
ElectricBorders=0
BorderSnapZone=24
WindowSnapZone=24
CenterSnap=false
SnapOnlyWhenOverlapping=false
GSOS_KWIN

# System Settings > About shows the GSOS name and logo
printf '[General]\nName=GSOS\nLogoPath=/usr/share/gsos/gsos-mark.svg\n' > "$A/etc/xdg/kcm-about-distrorc"

# Custom GSOS Lock Screen (org.kde.gsos.lockscreen)
cat > "$L/metadata.json" <<'GSOS_LOCK_META'
{
    "KPackageStructure": "Plasma/LookAndFeel",
    "KPlugin": {
        "Id": "org.kde.gsos.lockscreen",
        "Name": "GSOS Lock Screen",
        "Description": "Custom GSOS lock screen theme",
        "Version": "1.0",
        "EnabledByDefault": true
    }
}
GSOS_LOCK_META

cat > "$L/contents/lockscreen/LockScreen.qml" <<'GSOS_LOCK_QML'
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: lockRoot
    color: "#0c0f14"

    property bool showPasswordPrompt: false

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "GSOS"
            color: "#38bdf8"
            font.pixelSize: 26
            font.bold: true
        }

        Label {
            id: lockClock
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: "#f1f5f9"
            font.pixelSize: 56
            font.weight: Font.Light
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "dddd, dd MMM yyyy")
            color: "#94a3b8"
            font.pixelSize: 16
        }

        Button {
            visible: !lockRoot.showPasswordPrompt
            Layout.alignment: Qt.AlignHCenter
            text: "Unlock"
            onClicked: {
                lockRoot.showPasswordPrompt = true
                unlockField.forceActiveFocus()
            }
        }

        RowLayout {
            visible: lockRoot.showPasswordPrompt
            spacing: 8

            TextField {
                id: unlockField
                placeholderText: "Password"
                echoMode: TextInput.Password
                onAccepted: authenticator.tryUnlock(text)
            }

            Button {
                text: "Unlock"
                onClicked: authenticator.tryUnlock(unlockField.text)
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: lockClock.text = Qt.formatDateTime(new Date(), "hh:mm")
    }

    Connections {
        target: authenticator
        function onSucceeded() {
            unlockField.text = ""
            lockRoot.showPasswordPrompt = false
        }
        function onFailed() {
            unlockField.text = ""
            unlockField.forceActiveFocus()
        }
    }
}
GSOS_LOCK_QML

cat > "$A/etc/xdg/kscreenlockerrc" <<'GSOS_KSCREEN'
[Daemon]
Autolock=true
LockOnResume=true
Timeout=5

[Greeter]
Theme=org.kde.gsos.lockscreen
GSOS_KSCREEN

# Custom GSOS SDDM Login Theme (gsos-dark)
cat > "$D/metadata.desktop" <<'GSOS_SDDM_META'
[SddmGreeterTheme]
Name=GSOS Dark
Description=Custom GSOS login theme
Author=GSOS Project
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
GSOS_SDDM_META

cat > "$D/theme.conf" <<'GSOS_SDDM_CONF'
[General]
backgroundColor=#0c0f14
accentColor=#38bdf8
textColor=#f1f5f9
mutedColor=#94a3b8
GSOS_SDDM_CONF

cat > "$D/Main.qml" <<'GSOS_SDDM_QML'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.backgroundColor || "#0c0f14"

    property string textColor: config.textColor || "#f1f5f9"
    property string mutedColor: config.mutedColor || "#94a3b8"
    property string accentColor: config.accentColor || "#38bdf8"
    property int selectedIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginSucceeded() {}
        function onLoginFailed() {
            statusLabel.text = textConstants.loginFailed
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 12

        ComboBox {
            id: sessionBox
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
        }

        Item { Layout.fillWidth: true }

        Button {
            text: textConstants.reboot
            onClicked: sddm.reboot()
        }
        Button {
            text: textConstants.shutdown
            onClicked: sddm.powerOff()
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 360
        spacing: 16

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "GSOS"
            color: root.accentColor
            font.pixelSize: 34
            font.bold: true
        }

        Label {
            id: clockLabel
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: root.textColor
            font.pixelSize: 48
            font.weight: Font.Light
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "dddd, dd MMM")
            color: root.mutedColor
            font.pixelSize: 15
        }

        ComboBox {
            id: userBox
            Layout.fillWidth: true
            model: userModel
            textRole: "name"
            currentIndex: root.selectedIndex
            onActivated: function(idx) { root.selectedIndex = idx }
        }

        TextField {
            id: passwordInput
            Layout.fillWidth: true
            placeholderText: textConstants.password
            echoMode: TextInput.Password
            focus: true
            onAccepted: submitLogin()
        }

        Button {
            Layout.fillWidth: true
            text: textConstants.login
            highlighted: true
            onClicked: submitLogin()
        }

        Label {
            id: statusLabel
            Layout.alignment: Qt.AlignHCenter
            text: ""
            color: "#f87171"
            font.pixelSize: 13
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "hh:mm")
    }

    function submitLogin() {
        var username = userBox.currentText
        if (!username && userModel.count > 0) {
            username = userModel.data(userModel.index(root.selectedIndex, 0), Qt.UserRole + 1)
        }
        sddm.login(username, passwordInput.text, sessionBox.currentIndex)
    }

    Component.onCompleted: passwordInput.forceActiveFocus()
}
GSOS_SDDM_QML

cat > "$A/etc/sddm.conf.d/gsos.conf" <<'GSOS_SDDM_CFG'
[Theme]
Current=gsos-dark
CursorTheme=breeze_cursors

[General]
InputMethod=qtvirtualkeyboard
GSOS_SDDM_CFG

# Plymouth GSOS theme (always shows centered "GSOS" text on dark background) & quiet printk
cat > "$A/etc/plymouth/plymouthd.conf" <<'GSOS_PLY_CONF'
[Daemon]
Theme=gsos
ShowDelay=0
DeviceTimeout=8
GSOS_PLY_CONF

cat > "$PT/gsos.plymouth" <<'GSOS_PLY_THEME'
[Plymouth Theme]
Name=GSOS
Description=Centered GSOS text splash on dark background
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/gsos
ScriptFile=/usr/share/plymouth/themes/gsos/gsos.script
GSOS_PLY_THEME

cat > "$PT/gsos.script" <<'GSOS_PLY_SCRIPT'
Window.SetBackgroundTopColor(0.05, 0.06, 0.08);
Window.SetBackgroundBottomColor(0.05, 0.06, 0.08);

screen_w = Window.GetWidth();
screen_h = Window.GetHeight();

title = Image.Text("GSOS", 0.95, 0.96, 0.98, 1, "Sans Bold 42");

x = (screen_w - title.GetWidth()) / 2;
y = (screen_h - title.GetHeight()) / 2;

sprite = Sprite(title);
sprite.SetPosition(x, y, 10);
sprite.SetOpacity(1);
GSOS_PLY_SCRIPT

printf 'kernel.printk = 3 3 3 3\n' > "$A/etc/sysctl.d/20-quiet-printk.conf"

# ============================================================ 2) WALLPAPER AND LOGOS (text SVG)
cat > "$G/wallpaper.svg" <<'GSOS_WP'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1920 1080" width="1920" height="1080">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#12171d"/>
      <stop offset="0.55" stop-color="#232b34"/>
      <stop offset="1" stop-color="#171d24"/>
    </linearGradient>
    <linearGradient id="beam" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="1920" y2="0">
      <stop offset="0" stop-color="#1e7fff" stop-opacity="0"/>
      <stop offset="0.5" stop-color="#1e7fff" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#1e7fff" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#1e7fff" stop-opacity="0.38"/>
      <stop offset="1" stop-color="#1e7fff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <polygon points="0,1080 0,600 780,1080" fill="#3a4654" fill-opacity="0.22"/>
  <polygon points="1920,0 1920,560 1160,0" fill="#3a4654" fill-opacity="0.22"/>
  <polygon points="0,260 520,0 800,0 0,520" fill="#3a4654" fill-opacity="0.14"/>
  <circle cx="1500" cy="980" r="720" fill="url(#glow)"/>
  <line x1="0" y1="1040" x2="1920" y2="120" stroke="url(#beam)" stroke-width="3"/>
  <line x1="0" y1="1000" x2="1920" y2="80" stroke="url(#beam)" stroke-width="1.5" stroke-opacity="0.5"/>
  <g transform="translate(1210 300) scale(0.95)" opacity="0.07">
    <path d="M 440.3 256 A 184.3 184.3 0 1 1 415.6 163.85" fill="none" stroke="#5aa9ff" stroke-width="87" stroke-linecap="round"/>
    <rect x="259.7" y="212.5" width="224.1" height="87" rx="24.4" fill="#5aa9ff"/>
  </g>
</svg>
GSOS_WP

cat > "$G/gsos-mark.svg" <<'GSOS_SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="aurora" gradientUnits="userSpaceOnUse" x1="70" y1="60" x2="450" y2="460">
      <stop offset="0" stop-color="#3df0ff"/>
      <stop offset="0.4" stop-color="#5b8bff"/>
      <stop offset="0.75" stop-color="#a566ff"/>
      <stop offset="1" stop-color="#ff66b8"/>
    </linearGradient>
  </defs>
  <path d="M 440.3 256 A 184.3 184.3 0 1 1 415.6 163.85" fill="none" stroke="url(#aurora)" stroke-width="87" stroke-linecap="round"/>
  <rect x="259.7" y="212.5" width="224.1" height="87" rx="24.4" fill="url(#aurora)"/>
</svg>
GSOS_SVG
cp "$G/gsos-mark.svg" "$S/contents/splash/gsos-g.svg"

cat > "$G/gsos-store.svg" <<'GSOS_STORE_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1e7fff"/>
      <stop offset="1" stop-color="#3df0ff"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="116" fill="url(#bg)"/>
  <path d="M 200 200 L 200 150 A 56 56 0 0 1 312 150 L 312 200" fill="none" stroke="#ffffff" stroke-width="26" stroke-linecap="round"/>
  <path d="M150 190 h212 a20 20 0 0 1 20 22 l-22 190 a24 24 0 0 1 -24 21 h-160 a24 24 0 0 1 -24 -21 l-22 -190 a20 20 0 0 1 20 -22 z" fill="#ffffff"/>
</svg>
GSOS_STORE_ICON

# ============================================================ 3) STARTUP SPLASH
cat > "$S/metadata.json" <<'GSOS_META'
{
  "KPlugin": {
    "Id": "org.gsos.splash",
    "Name": "GSOS Splash",
    "Description": "GSOS startup screen",
    "Authors": [ { "Name": "Gaurav" } ],
    "Version": "1.0",
    "License": "GPL-3.0-or-later"
  },
  "KPackageStructure": "Plasma/LookAndFeel"
}
GSOS_META
cat > "$S/contents/splash/Splash.qml" <<'GSOS_QML'
import QtQuick

Rectangle {
    id: root
    color: "#000000"
    property int stage

    Image {
        id: logo
        anchors.centerIn: parent
        source: "gsos-g.svg"
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 512
        sourceSize.height: 512
        width: Math.min(root.width, root.height) * 0.12
        height: width
        opacity: 0
    }

    SequentialAnimation {
        id: intro
        NumberAnimation { target: logo; property: "opacity"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutQuad }
        SequentialAnimation {
            loops: Animation.Infinite
            NumberAnimation { target: logo; property: "opacity"; to: 0.78; duration: 1100; easing.type: Easing.InOutSine }
            NumberAnimation { target: logo; property: "opacity"; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
        }
    }
    Component.onCompleted: intro.start()
}
GSOS_QML
printf '[KSplash]\nEngine=KSplashQML\nTheme[$i]=org.gsos.splash\n' > "$A/etc/xdg/ksplashrc"

# ============================================================ 4) FIRST LOGIN: profile, store source, taskbar, wallpaper
cat > "$A/usr/local/bin/gsos-first-login.sh" <<'GSOS_FIRST'
#!/usr/bin/env bash
# GSOS first-login setup (once per user): performance profile, app-store source, taskbar layout, wallpaper.
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

# 1) performance profile (passwordless on the live ISO, asks for a password on an installed system)
pkexec /usr/local/bin/gsos-profile-switcher --profile auto && echo "profile: auto applied" || {
  echo "profile: failed"; notify "Open 'GSP Performance Manager' to choose Lite, Smooth, Balanced or Liquid."; }

# 2) app-store source for GSOS Store (keeps retrying in the background until the network is up)
( for _ in $(seq 1 30); do
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && break
    sleep 10
  done ) &

# 3) one solid dark taskbar at the bottom: launcher and apps centred, tray and clock on the right
LAYOUT_JS="$(mktemp --suffix=.js)"
cat > "$LAYOUT_JS" <<'JS'
panels().forEach(function (p) { p.remove(); });
var bar = new Panel;
bar.location = "bottom";
bar.height = Math.round(gridUnit * 2.8);
bar.floating = false;
bar.lengthMode = "fill";
bar.hiding = "none";
bar.opacity = "opaque";
bar.addWidget("org.kde.plasma.panelspacer");
var start = bar.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "/usr/share/gsos/gsos-mark.svg");
var tasks = bar.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("fill", false);
tasks.writeConfig("launchers", [
  "applications:org.kde.dolphin.desktop",
  "applications:firefox.desktop",
  "applications:org.gsos.store.desktop",
  "applications:org.kde.konsole.desktop",
  "applications:systemsettings.desktop",
  "applications:org.gsos.about.desktop"
]);
bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");
bar.addWidget("org.kde.plasma.digitalclock");
JS
if wait_for_plasma; then
  "$QDBUS" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$LAYOUT_JS")" \
    && echo "layout: applied" || echo "layout: failed"
  command -v plasma-apply-wallpaperimage >/dev/null 2>&1 \
    && plasma-apply-wallpaperimage /usr/share/gsos/wallpaper.svg && echo "wallpaper: applied" || echo "wallpaper: not applied"
else
  echo "layout: plasmashell not reachable"
  notify "Could not build the taskbar automatically. See ~/.cache/gsos-first-login.log"
fi
rm -f "$LAYOUT_JS"
touch "$FLAG"

# 4) live ISO only: open the installer
if is_live && command -v calamares >/dev/null 2>&1; then
  echo "launching calamares"
  sudo -n -E calamares >/dev/null 2>&1 &
fi
exit 0
GSOS_FIRST
printf '[Desktop Entry]\nType=Application\nName=GSOS First Login Setup\nComment=Sets up the GSOS desktop once per user\nExec=/usr/local/bin/gsos-first-login.sh\nIcon=preferences-system\nTerminal=false\nNoDisplay=true\nX-KDE-autostart-phase=2\n' \
  > "$A/etc/xdg/autostart/gsos-first-login.desktop"

# ============================================================ 5) GSOS STORE
cat > "$A/usr/local/bin/gsos-store.py" <<'GSOS_STORE'
#!/usr/bin/env python3
"""GSOS Store v0.1 - a curated app store. Apps are installed from Flathub with Flatpak."""
import subprocess
import sys

REMOTE_URL = "https://dl.flathub.org/repo/flathub.flatpakrepo"
CATEGORIES = ["All", "Internet", "Office", "Media", "Creative", "Games", "Developer", "Tools"]
CATALOG = [  # name, category, Flathub id, short description
    ("Brave", "Internet", "com.brave.Browser", "Fast, private web browser."),
    ("Thunderbird", "Internet", "org.mozilla.Thunderbird", "Email, calendar and contacts."),
    ("Telegram", "Internet", "org.telegram.desktop", "Messaging with friends and groups."),
    ("Discord", "Internet", "com.discordapp.Discord", "Voice, video and text chat."),
    ("Signal", "Internet", "org.signal.Signal", "Private messaging."),
    ("Zoom", "Internet", "us.zoom.Zoom", "Video meetings."),
    ("qBittorrent", "Internet", "org.qbittorrent.qBittorrent", "Download manager for torrents."),
    ("LibreOffice", "Office", "org.libreoffice.LibreOffice", "Documents, spreadsheets and slides."),
    ("OnlyOffice", "Office", "org.onlyoffice.desktopeditors", "Office suite that opens Microsoft files."),
    ("Okular", "Office", "org.kde.okular", "PDF and document viewer."),
    ("VLC", "Media", "org.videolan.VLC", "Plays almost any video or audio file."),
    ("Spotify", "Media", "com.spotify.Client", "Music streaming."),
    ("OBS Studio", "Media", "com.obsproject.Studio", "Screen recording and live streaming."),
    ("Audacity", "Media", "org.audacityteam.Audacity", "Record and edit audio."),
    ("Kodi", "Media", "tv.kodi.Kodi", "Media center for your library."),
    ("GIMP", "Creative", "org.gimp.GIMP", "Photo editing."),
    ("Krita", "Creative", "org.kde.krita", "Digital painting and illustration."),
    ("Inkscape", "Creative", "org.inkscape.Inkscape", "Vector graphics and logos."),
    ("Blender", "Creative", "org.blender.Blender", "3D modelling, animation and rendering."),
    ("Kdenlive", "Creative", "org.kde.kdenlive", "Video editor."),
    ("Shotcut", "Creative", "org.shotcut.Shotcut", "Simple video editor."),
    ("Steam", "Games", "com.valvesoftware.Steam", "Game store and launcher."),
    ("Heroic Games Launcher", "Games", "com.heroicgameslauncher.hgl", "Epic, GOG and Amazon games."),
    ("Visual Studio Code", "Developer", "com.visualstudio.code", "Code editor."),
    ("Bottles", "Tools", "com.usebottles.bottles", "Manage Windows apps and games."),
    ("HandBrake", "Tools", "fr.handbrake.ghb", "Convert video files."),
]


def run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout + r.stderr).strip()
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


def installed_apps():
    ok, out = run(["flatpak", "list", "--app", "--columns=application"])
    return {line.strip() for line in out.splitlines() if "." in line} if ok else set()


def filter_catalog(query, category):
    q = query.strip().lower()
    return [a for a in CATALOG
            if (category == "All" or a[1] == category) and (not q or q in a[0].lower() or q in a[3].lower())]


def commands_for(action, app_id):
    add = ["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", REMOTE_URL]
    if action == "install":
        return [add, ["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", app_id]]
    if action == "remove":
        return [["flatpak", "uninstall", "--user", "-y", "--noninteractive", app_id]]
    return []


def main():
    from PyQt6.QtCore import QProcess
    from PyQt6.QtGui import QIcon
    from PyQt6.QtWidgets import (QApplication, QComboBox, QFrame, QHBoxLayout, QLabel, QLineEdit,
                                 QPushButton, QScrollArea, QVBoxLayout, QWidget)

    class Store(QWidget):
        def __init__(self):
            super().__init__()
            self.setWindowTitle("GSOS Store")
            self.setWindowIcon(QIcon("/usr/share/gsos/gsos-store.svg"))
            self.resize(920, 660)
            self.installed = installed_apps()
            self.queue = []
            self.current = None
            self.label = ""
            self.proc = QProcess(self)
            self.proc.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            self.proc.readyReadStandardOutput.connect(self.on_output)
            self.proc.finished.connect(self.on_finished)
            self.proc.errorOccurred.connect(lambda _e: self.finish(False))

            outer = QVBoxLayout(self)
            outer.addWidget(QLabel("<h2>GSOS Store</h2><p>Apps for GSOS. One click to install.</p>"))
            bar = QHBoxLayout()
            self.search = QLineEdit()
            self.search.setPlaceholderText("Search apps...")
            self.search.textChanged.connect(self.render)
            self.cat = QComboBox()
            self.cat.addItems(CATEGORIES)
            self.cat.currentIndexChanged.connect(self.render)
            bar.addWidget(self.search, 1)
            bar.addWidget(self.cat)
            outer.addLayout(bar)
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setFrameShape(QFrame.Shape.NoFrame)
            outer.addWidget(scroll, 1)
            body = QWidget()
            self.items = QVBoxLayout(body)
            scroll.setWidget(body)
            self.status = QLabel("Ready.")
            self.status.setWordWrap(True)
            outer.addWidget(self.status)
            self.render()

        def render(self, *_):
            while self.items.count():
                item = self.items.takeAt(0)
                if item.widget():
                    item.widget().deleteLater()
            busy = self.current is not None
            for name, cat, app_id, desc in filter_catalog(self.search.text(), self.cat.currentText()):
                card = QFrame()
                card.setObjectName("card")
                card.setStyleSheet("#card { border: 1px solid palette(mid); border-radius: 12px; }")
                row = QHBoxLayout(card)
                text = QVBoxLayout()
                text.addWidget(QLabel("<b>%s</b>  <small>%s</small>" % (name, cat)))
                blurb = QLabel(desc)
                blurb.setWordWrap(True)
                text.addWidget(blurb)
                row.addLayout(text, 1)
                have = app_id in self.installed
                main_btn = QPushButton("Open" if have else "Install")
                main_btn.setEnabled(have or not busy)
                main_btn.clicked.connect(
                    lambda _=False, i=app_id, h=have: self.open_app(i) if h else self.start("install", i))
                row.addWidget(main_btn)
                if have:
                    remove = QPushButton("Remove")
                    remove.setEnabled(not busy)
                    remove.clicked.connect(lambda _=False, i=app_id: self.start("remove", i))
                    row.addWidget(remove)
                self.items.addWidget(card)
            self.items.addStretch(1)

        def open_app(self, app_id):
            subprocess.Popen(["flatpak", "run", app_id], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)

        def start(self, action, app_id):
            self.queue = commands_for(action, app_id)
            self.label = ("Installing " if action == "install" else "Removing ") + app_id
            self.status.setText(self.label + "...")
            self.current = app_id
            self.render()
            self.next_step()

        def next_step(self):
            if not self.queue:
                self.finish(True)
                return
            cmd = self.queue.pop(0)
            self.proc.start(cmd[0], cmd[1:])

        def on_output(self):
            text = bytes(self.proc.readAllStandardOutput()).decode(errors="replace")
            lines = [ln.strip() for ln in text.replace("\r", "\n").splitlines() if ln.strip()]
            if lines:
                self.status.setText("%s: %s" % (self.label, lines[-1][:120]))

        def on_finished(self, code, _status):
            if code != 0:
                self.finish(False)
            else:
                self.next_step()

        def finish(self, ok):
            if self.current is None:
                return
            self.queue = []
            self.current = None
            self.installed = installed_apps()
            self.status.setText("Done." if ok else "That did not work. Check your internet connection and try again.")
            self.render()

    app = QApplication(sys.argv)
    app.setDesktopFileName("org.gsos.store")
    window = Store()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
GSOS_STORE
cat > "$A/usr/share/applications/org.gsos.store.desktop" <<'GSOS_DESK'
[Desktop Entry]
Type=Application
Name=GSOS Store
GenericName=App Store
Comment=Find and install apps
Exec=python3 /usr/local/bin/gsos-store.py
Icon=/usr/share/gsos/gsos-store.svg
Terminal=false
Categories=System;PackageManager;
Keywords=store;apps;install;download;software;
GSOS_DESK

# ============================================================ 6) GSOS ABOUT (OS name, device name, device configuration)
cat > "$A/usr/local/bin/gsos-about.py" <<'GSOS_ABOUT'
#!/usr/bin/env python3
"""GSOS About v0.1 - the OS name, this device's name and its configuration."""
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path


def read(path):
    try:
        return Path(path).read_text()
    except Exception:  # noqa: BLE001
        return ""


def sh(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout
    except Exception:  # noqa: BLE001
        return ""


def os_name():
    m = re.search(r'^PRETTY_NAME="?([^"\n]+)"?', read("/etc/os-release"), re.M)
    return m.group(1) if m else "GSOS"


def device_name():
    return platform.node() or "gsos"


def cpu_info():
    names = re.findall(r"^model name\s*:\s*(.+)$", read("/proc/cpuinfo"), re.M)
    name = re.sub(r"\s+", " ", names[0]).strip() if names else "Unknown processor"
    return "%s (%d threads)" % (name, len(names) or os.cpu_count() or 0)


def memory_info():
    m = re.search(r"^MemTotal:\s+(\d+) kB", read("/proc/meminfo"), re.M)
    return "%.1f GiB" % (int(m.group(1)) / 1048576) if m else "Unknown"


def gpu_info():
    exe = shutil.which("lspci")
    if exe:
        lines = [ln.split(": ", 1)[-1].strip() for ln in sh([exe]).splitlines() if re.search(r"VGA|3D|Display", ln)]
        if lines:
            return "; ".join(lines)
    return "Unknown graphics"


def storage_info():
    exe = shutil.which("lsblk")
    if exe:
        rows = [re.sub(r"\s+", " ", ln).strip() for ln in sh([exe, "-dno", "NAME,SIZE,MODEL", "-e", "7,11"]).splitlines()]
        rows = [r for r in rows if r and not r.startswith(("zram", "loop"))]
        if rows:
            return "\n".join(rows)
    return "%.0f GiB" % (shutil.disk_usage("/").total / 2 ** 30)


def battery_info():
    for bat in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        cap, status = read(bat / "capacity").strip(), read(bat / "status").strip()
        if cap:
            return "%s%% (%s)" % (cap, status or "unknown")
    return "No battery"


def uptime_info():
    try:
        secs = int(float(read("/proc/uptime").split()[0]))
    except Exception:  # noqa: BLE001
        return "Unknown"
    return "%dh %dm" % (secs // 3600, secs % 3600 // 60)


def rename_device(name):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,31}", name):
        return False, "Use letters, numbers and dashes only (up to 32 characters)."
    pk, hc = shutil.which("pkexec"), shutil.which("hostnamectl")
    if not (pk and hc):
        return False, "Renaming is not available on this system."
    r = subprocess.run([pk, hc, "set-hostname", name], capture_output=True, text=True)
    if r.returncode == 0:
        return True, "Device renamed to %s." % name
    return False, r.stderr.strip() or "Renaming failed."


def rows(display="Unknown"):
    return [("Operating system", os_name()), ("Processor", cpu_info()), ("Memory", memory_info()),
            ("Graphics", gpu_info()), ("Storage", storage_info()), ("Display", display),
            ("Battery", battery_info()), ("Kernel", platform.release()), ("Uptime", uptime_info())]


def main():
    from PyQt6.QtGui import QIcon
    from PyQt6.QtWidgets import (QApplication, QGridLayout, QHBoxLayout, QLabel, QLineEdit, QPushButton,
                                 QVBoxLayout, QWidget)

    app = QApplication(sys.argv)
    app.setDesktopFileName("org.gsos.about")
    screen = app.primaryScreen()
    display = "%dx%d" % (screen.size().width(), screen.size().height()) if screen else "Unknown"

    win = QWidget()
    win.setWindowTitle("About GSOS")
    win.setWindowIcon(QIcon("/usr/share/gsos/gsos-mark.svg"))
    win.resize(560, 560)
    outer = QVBoxLayout(win)

    head = QHBoxLayout()
    logo = QLabel()
    logo.setPixmap(QIcon("/usr/share/gsos/gsos-mark.svg").pixmap(72, 72))
    head.addWidget(logo)
    head.addWidget(QLabel("<h1>GSOS</h1><p>%s</p>" % os_name()), 1)
    outer.addLayout(head)

    name_row = QHBoxLayout()
    name_row.addWidget(QLabel("<b>Device name</b>"))
    name_edit = QLineEdit(device_name())
    name_row.addWidget(name_edit, 1)
    rename = QPushButton("Rename")
    name_row.addWidget(rename)
    outer.addLayout(name_row)
    status = QLabel("")
    status.setWordWrap(True)
    outer.addWidget(status)

    grid = QGridLayout()
    data = rows(display)
    for i, (key, value) in enumerate(data):
        grid.addWidget(QLabel("<b>%s</b>" % key), i, 0)
        v = QLabel(value)
        v.setWordWrap(True)
        v.setTextInteractionFlags(v.textInteractionFlags() | v.textInteractionFlags().TextSelectableByMouse)
        grid.addWidget(v, i, 1)
    grid.setColumnStretch(1, 1)
    outer.addLayout(grid)
    outer.addStretch(1)

    def do_rename():
        ok, msg = rename_device(name_edit.text().strip())
        status.setText(msg)

    def copy_details():
        text = "Device name: %s\n" % name_edit.text().strip() + "\n".join("%s: %s" % kv for kv in data)
        QApplication.clipboard().setText(text)
        status.setText("Details copied.")

    rename.clicked.connect(do_rename)
    copy = QPushButton("Copy details")
    copy.clicked.connect(copy_details)
    outer.addWidget(copy)
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
GSOS_ABOUT
cat > "$A/usr/share/applications/org.gsos.about.desktop" <<'GSOS_DESK'
[Desktop Entry]
Type=Application
Name=About GSOS
GenericName=Device information
Comment=OS name, device name and configuration
Exec=python3 /usr/local/bin/gsos-about.py
Icon=/usr/share/gsos/gsos-mark.svg
Terminal=false
Categories=Settings;System;
Keywords=about;device;name;system;information;hardware;
GSOS_DESK

# ============================================================ 7) BRANDING, LIVE USER, SERVICES (runs inside the ISO chroot)
cat > "$A/root/customize_airootfs.sh" <<'GSOS_CUSTOM'
#!/usr/bin/env bash
# Runs inside the airootfs chroot during mkarchiso (deprecated by archiso but still supported).
set -uo pipefail
echo "[GSOS] customize_airootfs.sh starting"

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
echo "gsos" > /etc/hostname

for f in gsos-profile-switcher gsos-theme-installer gsos-profile-menu gsos-first-login.sh gsos-store.py gsos-about.py; do
  [[ -f "/usr/local/bin/$f" ]] && chmod 0755 "/usr/local/bin/$f"
done

# OS name shown in System Settings > About and on the console
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

# installer says "GSOS" instead of "Arch Linux" (only switches if the copy works)
if [[ -d /usr/share/calamares/branding/default && -f /etc/calamares/settings.conf ]]; then
  mkdir -p /etc/calamares/branding
  cp -r /usr/share/calamares/branding/default /etc/calamares/branding/gsos
  sed -i 's/Arch Linux/GSOS/g; s/^componentName:.*/componentName: gsos/' /etc/calamares/branding/gsos/branding.desc
  sed -i 's/^branding:.*/branding: gsos/' /etc/calamares/settings.conf
fi

# Plymouth theme, initramfs, and GRUB setup
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme gsos || true
fi

if command -v mkinitcpio >/dev/null 2>&1; then
  mkinitcpio -P || true
fi

if command -v grub-mkconfig >/dev/null 2>&1 && [[ -d /boot/grub ]]; then
  grub-mkconfig -o /boot/grub/grub.cfg || true
fi

# live user (passwordless sudo, live session only)
id liveuser >/dev/null 2>&1 || useradd -m -G wheel,video,audio,input,storage,optical,network -s /bin/bash liveuser
passwd -d liveuser
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/g_wheel
chmod 0440 /etc/sudoers.d/g_wheel
install -d -o liveuser -g liveuser /home/liveuser/Desktop
cp -f /etc/skel/Desktop/install-gsos.desktop /home/liveuser/Desktop/
chmod 0755 /home/liveuser/Desktop/install-gsos.desktop
chown -R liveuser:liveuser /home/liveuser

systemctl enable sddm.service NetworkManager.service bluetooth.service waydroid-container.service
systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl disable iwd.service 2>/dev/null || true
systemctl set-default graphical.target
install -d /var/lib/waydroid
echo "[GSOS] customize_airootfs.sh finished"
GSOS_CUSTOM

# installer fix (no dollar signs: Calamares would treat them as its own variables)
cat > "$A/etc/calamares/modules/shellprocess-gsos-prep.conf" <<'GSOS_SP'
# Turns the copied live system into a normal installed system (runs inside the target chroot).
---
dontChroot: false
timeout: 300
script:
  - "cp /usr/lib/modules/*zen*/vmlinuz /boot/vmlinuz-linux-zen"
  - "rm -f /etc/mkinitcpio.conf.d/archiso.conf"
  - command: "printf '%s\\n' \"ALL_config='/etc/mkinitcpio.conf'\" \"ALL_kver='/boot/vmlinuz-linux-zen'\" \"PRESETS=('default' 'fallback')\" \"default_image='/boot/initramfs-linux-zen.img'\" \"fallback_image='/boot/initramfs-linux-zen-fallback.img'\" \"fallback_options='-S autodetect'\" > /etc/mkinitcpio.d/linux-zen.preset"
  - "rm -f /etc/sddm.conf.d/autologin.conf /etc/sudoers.d/g_wheel /etc/polkit-1/rules.d/49-gsos-live.rules"
  - "sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
  - "userdel -r liveuser || true"
  - "rm -f /root/.automated_script.sh /root/.zlogin"
GSOS_SP

echo "[gsos-theme] done"
