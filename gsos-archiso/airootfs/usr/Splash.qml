import QtQuick

Rectangle {
    id: root
    color: "#000000"

    // Plasma updates this from 0 to 6 while the session starts.
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
