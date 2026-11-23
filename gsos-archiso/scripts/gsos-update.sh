#!/usr/bin/env bash
# GSOS update bundle: "GSOS Update" app (tray notice + update window), root helper, keyring first-start.
# Called by the build workflow with $P (archiso profile) and $A ($P/airootfs) set. Runs after gsos-theme.sh.
set -u
: "${P:?P not set}" "${A:?A not set}"
echo "[gsos-update] start"

for pkg in pacman-contrib python-pyqt6; do
  grep -qx "$pkg" "$P/packages.x86_64" || printf '\n%s\n' "$pkg" >> "$P/packages.x86_64"
done
mkdir -p "$A/usr/local/bin" "$A/usr/share/gsos" "$A/usr/share/applications" "$A/etc/xdg/autostart" \
         "$A/usr/share/polkit-1/actions" "$A/etc/systemd/system/multi-user.target.wants"

# ---------- icon ----------
cat > "$A/usr/share/gsos/gsos-update.svg" <<'GSOS_UPD_ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#1e7fff"/>
      <stop offset="1" stop-color="#3df0ff"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="116" fill="url(#bg)"/>
  <path d="M 256 120 L 360 244 H 292 V 360 H 220 V 244 H 152 Z" fill="#ffffff"/>
  <rect x="150" y="394" width="212" height="28" rx="14" fill="#ffffff"/>
</svg>
GSOS_UPD_ICON

# ---------- root helper (runs only through pkexec) ----------
cat > "$A/usr/local/bin/gsos-update-apply" <<'GSOS_APPLY'
#!/usr/bin/env bash
# GSOS Update helper. Runs as root through pkexec and installs all pending updates.
set -u
exec 9>/var/lock/gsos-update.lock
flock -n 9 || { echo "Another update is already running."; exit 1; }
export LANG=C
echo "== Refreshing the package keys"
pacman -Sy --noconfirm --needed archlinux-keyring || exit 1
echo "== Installing updates"
pacman -Su --noconfirm || exit 1
echo "== Done"
exit 0
GSOS_APPLY

cat > "$A/usr/share/polkit-1/actions/org.gsos.update.policy" <<'GSOS_POLICY'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <action id="org.gsos.update.apply">
    <description>Install GSOS updates</description>
    <message>Authentication is required to install GSOS updates</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/gsos-update-apply</annotate>
  </action>
</policyconfig>
GSOS_POLICY

# ---------- package keyring on the first start of an installed system (the live ISO already has one) ----------
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

# ---------- the app ----------
cat > "$A/usr/local/bin/gsos-update.py" <<'GSOS_UPDATE'
#!/usr/bin/env python3
"""GSOS Update v0.1 - checks for system updates in the background and installs them with one click.

It lives in the system tray, checks every few hours, and tells you when updates are ready.
Updates are installed by a small root helper (asked through the normal password prompt).
"""
import re
import shutil
import subprocess
import sys
import time

REFRESH_HOURS = 6
ICON = "/usr/share/gsos/gsos-update.svg"
APPLY = "/usr/local/bin/gsos-update-apply"
SOCKET = "gsos-update-single-instance"
RESTART_HINTS = ("linux-zen", "systemd")
PROGRESS_LINE = re.compile(r"\[[#\-\s.]+\]\s+\d+%")


def parse_updates(text):
    """checkupdates prints lines like: 'linux-zen 7.3.4.zen2-1 -> 7.3.5.zen1-1'."""
    found = []
    for line in text.splitlines():
        m = re.match(r"^(\S+)\s+(\S+)\s+->\s+(\S+)\s*$", line.strip())
        if m:
            found.append(m.groups())
    return found


def needs_restart(updates):
    return any(name in RESTART_HINTS or name.startswith("linux-zen") for name, _old, _new in updates)


def check_updates():
    """Return (ok, updates, message). Blocking; used by the command line check."""
    exe = shutil.which("checkupdates")
    if not exe:
        return False, [], "The update checker is missing."
    try:
        r = subprocess.run([exe], capture_output=True, text=True, timeout=180)
    except Exception as exc:  # noqa: BLE001
        return False, [], str(exc)
    if r.returncode == 2:
        return True, [], ""
    if r.returncode == 0:
        return True, parse_updates(r.stdout), ""
    return False, [], r.stderr.strip() or "Could not check for updates. Are you online?"


def main():
    if "--check" in sys.argv:
        ok, updates, msg = check_updates()
        print("%s: %d updates %s" % ("ok" if ok else "error", len(updates), msg))
        return

    from PyQt6.QtCore import QProcess, QTimer
    from PyQt6.QtGui import QAction, QIcon
    from PyQt6.QtNetwork import QLocalServer, QLocalSocket
    from PyQt6.QtWidgets import (QApplication, QLabel, QMenu, QPlainTextEdit, QPushButton, QSystemTrayIcon,
                                 QVBoxLayout, QHBoxLayout, QWidget)

    tray_only = "--tray" in sys.argv
    app = QApplication(sys.argv)
    app.setApplicationName("GSOS Update")
    app.setDesktopFileName("org.gsos.update")
    app.setQuitOnLastWindowClosed(False)

    # only one copy runs; opening the app again just shows the window of the running copy
    sock = QLocalSocket()
    sock.connectToServer(SOCKET)
    if sock.waitForConnected(300):
        if not tray_only:
            sock.write(b"show")
            sock.flush()
            sock.waitForBytesWritten(300)
        return
    QLocalServer.removeServer(SOCKET)
    server = QLocalServer()
    server.listen(SOCKET)

    class Window(QWidget):
        def __init__(self):
            super().__init__()
            self.setWindowTitle("GSOS Update")
            self.setWindowIcon(QIcon(ICON))
            self.resize(560, 520)
            self.updates = []
            self.last_notified = -1
            self.busy = False
            self.checker = QProcess(self)
            self.checker.finished.connect(self.on_checked)
            self.applier = QProcess(self)
            self.applier.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            self.applier.readyReadStandardOutput.connect(self.on_apply_output)
            self.applier.finished.connect(self.on_applied)
            self.applier.errorOccurred.connect(lambda _e: self.on_applied(1, None))

            lay = QVBoxLayout(self)
            self.headline = QLabel("<h2>GSOS Update</h2>")
            lay.addWidget(self.headline)
            self.status = QLabel("Checking for updates...")
            self.status.setWordWrap(True)
            lay.addWidget(self.status)
            self.log = QPlainTextEdit()
            self.log.setReadOnly(True)
            lay.addWidget(self.log, 1)
            row = QHBoxLayout()
            self.check_btn = QPushButton("Check now")
            self.check_btn.clicked.connect(self.check)
            self.install_btn = QPushButton("Install updates")
            self.install_btn.setEnabled(False)
            self.install_btn.clicked.connect(self.install)
            self.restart_btn = QPushButton("Restart now")
            self.restart_btn.hide()
            self.restart_btn.clicked.connect(lambda: subprocess.Popen(["systemctl", "reboot"]))
            for b in (self.check_btn, self.install_btn, self.restart_btn):
                row.addWidget(b)
            lay.addLayout(row)

            self.tray = None
            if QSystemTrayIcon.isSystemTrayAvailable():
                self.tray = QSystemTrayIcon(QIcon(ICON), self)
                menu = QMenu()
                open_action = QAction("Open GSOS Update", menu)
                open_action.triggered.connect(self.show_window)
                check_action = QAction("Check now", menu)
                check_action.triggered.connect(self.check)
                menu.addAction(open_action)
                menu.addAction(check_action)
                self.tray.setContextMenu(menu)
                self.tray.activated.connect(lambda _r: self.show_window())
                self.tray.setToolTip("GSOS Update")
                self.tray.show()
            self.timer = QTimer(self)
            self.timer.setInterval(REFRESH_HOURS * 3600 * 1000)
            self.timer.timeout.connect(self.check)
            self.timer.start()

        def show_window(self):
            self.show()
            self.raise_()
            self.activateWindow()

        def closeEvent(self, event):  # keep running in the tray so we can keep checking
            if self.tray is not None:
                event.ignore()
                self.hide()
            else:
                event.accept()
                QApplication.quit()

        def check(self):
            if self.busy or self.checker.state() != QProcess.ProcessState.NotRunning:
                return
            self.status.setText("Checking for updates...")
            self.checker.start("checkupdates")

        def on_checked(self, code, _status):
            out = bytes(self.checker.readAllStandardOutput()).decode(errors="replace")
            err = bytes(self.checker.readAllStandardError()).decode(errors="replace").strip()
            if code == 2:
                self.updates = []
                self.status.setText("Your system is up to date. Last checked %s." % time.strftime("%H:%M"))
                self.log.setPlainText("")
            elif code == 0:
                self.updates = parse_updates(out)
                n = len(self.updates)
                self.status.setText("%d update%s ready to install." % (n, "" if n == 1 else "s"))
                self.log.setPlainText("\n".join("%s  %s -> %s" % u for u in self.updates))
                if self.tray is not None and n and n != self.last_notified:
                    self.last_notified = n
                    self.tray.showMessage("GSOS Update", "%d update%s ready. Open GSOS Update to install."
                                          % (n, "" if n == 1 else "s"), QIcon(ICON), 10000)
            else:
                self.status.setText(err or "Could not check for updates. Are you online?")
            self.install_btn.setEnabled(bool(self.updates) and not self.busy)

        def install(self):
            self.busy = True
            self.install_btn.setEnabled(False)
            self.check_btn.setEnabled(False)
            self.restart_btn.hide()
            self.status.setText("Installing updates. Please keep the computer on and plugged in.")
            self.log.setPlainText("")
            self.applier.start("pkexec", [APPLY])

        def on_apply_output(self):
            text = bytes(self.applier.readAllStandardOutput()).decode(errors="replace")
            for line in text.replace("\r", "\n").splitlines():
                line = line.strip()
                if line and not PROGRESS_LINE.search(line):
                    self.log.appendPlainText(line)

        def on_applied(self, code, _status):
            if not self.busy:
                return
            self.busy = False
            self.check_btn.setEnabled(True)
            if code == 0:
                restart = needs_restart(self.updates)
                self.status.setText("Updates installed." + (" Please restart to finish." if restart else ""))
                if restart:
                    self.restart_btn.show()
                self.updates = []
                self.install_btn.setEnabled(False)
                QTimer.singleShot(2000, self.check)
            else:
                self.status.setText("The update did not finish. Nothing was lost; you can try again. "
                                    "Details are in the box above.")
                self.install_btn.setEnabled(bool(self.updates))

    win = Window()

    def on_connection():
        conn = server.nextPendingConnection()
        if conn is not None:
            conn.waitForReadyRead(200)
            win.show_window()

    server.newConnection.connect(on_connection)
    QTimer.singleShot(60000 if tray_only else 500, win.check)
    if not tray_only or win.tray is None:
        win.show_window()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
GSOS_UPDATE

cat > "$A/usr/share/applications/org.gsos.update.desktop" <<'GSOS_DESK'
[Desktop Entry]
Type=Application
Name=GSOS Update
GenericName=Software Update
Comment=Check for updates and install them
Exec=python3 /usr/local/bin/gsos-update.py
Icon=/usr/share/gsos/gsos-update.svg
Terminal=false
Categories=System;Settings;
Keywords=update;upgrade;software;system;
GSOS_DESK

printf '[Desktop Entry]\nType=Application\nName=GSOS Update (tray)\nComment=Checks for updates in the background\nExec=python3 /usr/local/bin/gsos-update.py --tray\nIcon=/usr/share/gsos/gsos-update.svg\nTerminal=false\nNoDisplay=true\nX-KDE-autostart-phase=2\n' \
  > "$A/etc/xdg/autostart/gsos-update-tray.desktop"

# ---------- hook into the theme bundle's files (safe if a pattern is not found) ----------
CUSTOM="$A/root/customize_airootfs.sh"
if [ -f "$CUSTOM" ]; then
  sed -i 's|^echo "\[GSOS\] customize_airootfs.sh finished"|chmod 0755 /usr/local/bin/gsos-update.py /usr/local/bin/gsos-update-apply\n&|' "$CUSTOM"
fi
FIRST="$A/usr/local/bin/gsos-first-login.sh"
if [ -f "$FIRST" ]; then
  sed -i 's|^  "applications:org.gsos.about.desktop"$|  "applications:org.gsos.about.desktop",\n  "applications:org.gsos.update.desktop"|' "$FIRST"
fi

echo "[gsos-update] done"
