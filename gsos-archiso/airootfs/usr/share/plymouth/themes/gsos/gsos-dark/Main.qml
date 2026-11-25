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
