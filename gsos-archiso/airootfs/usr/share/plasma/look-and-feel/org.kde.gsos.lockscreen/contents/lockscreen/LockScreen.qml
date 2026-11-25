import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore

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
