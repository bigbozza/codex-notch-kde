import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: compact

    required property var controller

    implicitWidth: content.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: Math.max(content.implicitHeight, Kirigami.Units.iconSizes.smallMedium)

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            source: "office-chart-pie"
            color: compact.controller.quotaColor
        }

        PlasmaComponents3.Label {
            text: compact.controller.compactText
            color: compact.controller.hasSnapshot
                ? compact.controller.quotaColor
                : Kirigami.Theme.disabledTextColor
            font.weight: Font.DemiBold
            font.features: {"tnum": 1}
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: compact.controller.expanded = !compact.controller.expanded
    }
}
