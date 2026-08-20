import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property real value: -1
    property color fillColor: Kirigami.Theme.highlightColor

    readonly property real clampedValue: Math.max(0, Math.min(1, value))

    implicitHeight: 6

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Kirigami.Theme.textColor
        opacity: 0.14
    }

    Rectangle {
        width: root.width * root.clampedValue
        height: root.height
        radius: height / 2
        color: root.fillColor
        visible: root.value >= 0

        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
