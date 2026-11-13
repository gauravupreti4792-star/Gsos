import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

// GSOS Profile Widget (v1.1.0)
// Install path: /usr/share/plasma/plasmoids/org.gsos.profilemanager/contents/ui/main.qml
// (Plasma requires the entry file to be named main.qml.)
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    property string activeKey: ""
    property string activeProfile: "Select a profile"
    property string message: "Choose a performance profile"
    property bool busy: false

    readonly property var profiles: [
        { key: "lite",     label: "Lite" },
        { key: "smooth",   label: "Smooth" },
        { key: "balanced", label: "Balanced" },
        { key: "liquid",   label: "Liquid" }
    ]

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            root.busy = false
            if (data["exit code"] === 0) {
                root.message = "Applied. Reboot to apply ZRAM changes."
            } else {
                root.activeKey = ""
                root.activeProfile = "Not applied"
                root.message = "Could not apply profile. Check authorization and logs."
            }
            disconnectSource(sourceName)
        }
    }

    function applyProfile(profile) {
        if (busy) return
        busy = true
        activeKey = profile
        activeProfile = profile === "auto" ? "Automatic detection"
                        : profile.charAt(0).toUpperCase() + profile.slice(1)
        message = "Requesting administrator permission…"
        runner.connectSource("pkexec /usr/local/bin/gsos-profile-switcher --profile " + profile)
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 340
        Layout.minimumHeight: 190
        spacing: 8

        PlasmaExtras.Heading {
            level: 2
            text: "GSP Performance"
            Layout.fillWidth: true
        }
        PlasmaComponents.Label {
            text: "Profile: " + root.activeProfile
            font.bold: true
        }
        PlasmaComponents.Label {
            text: root.message
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        PlasmaComponents.Button {
            Layout.fillWidth: true
            text: "Automatic (detect hardware)"
            enabled: !root.busy
            highlighted: root.activeKey === "auto"
            onClicked: root.applyProfile("auto")
        }

        // One clean horizontal row: Lite | Smooth | Balanced | Liquid
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.profiles
                delegate: PlasmaComponents.Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: modelData.label
                    enabled: !root.busy
                    highlighted: root.activeKey === modelData.key
                    onClicked: root.applyProfile(modelData.key)
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 10
            text: "Lite: no effects, for low-end PCs. ZRAM changes require reboot. Liquid needs ≥8 GiB RAM and hardware OpenGL."
        }
    }
}
