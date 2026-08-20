import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

FocusScope {
    id: full

    required property var controller

    implicitWidth: Kirigami.Units.gridUnit * 19
    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                source: "office-chart-pie"
                color: full.controller.quotaColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Kirigami.Heading {
                    text: "Codex quota"
                    level: 3
                    font.weight: Font.DemiBold
                }

                PlasmaComponents3.Label {
                    text: "ChatGPT plan"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            Rectangle {
                implicitWidth: planLabel.implicitWidth + Kirigami.Units.largeSpacing
                implicitHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Kirigami.Theme.alternateBackgroundColor

                PlasmaComponents3.Label {
                    id: planLabel
                    anchors.centerIn: parent
                    text: full.controller.plan
                    font.weight: Font.DemiBold
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: "Weekly remaining"
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: full.controller.compactText
                    color: full.controller.quotaColor
                    font.weight: Font.Bold
                    font.features: {"tnum": 1}
                }
            }

            MetricBar {
                Layout.fillWidth: true
                value: full.controller.weeklyRemaining < 0
                    ? -1
                    : full.controller.weeklyRemaining / 100
                fillColor: full.controller.quotaColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: "Until weekly reset"
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: full.controller.resetRemainingText
                    font.weight: Font.DemiBold
                    font.features: {"tnum": 1}
                }
            }

            MetricBar {
                Layout.fillWidth: true
                value: full.controller.weeklyResetProgress
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: full.controller.weeklyResetAt > 0
                text: "Resets: " + full.controller.formatDate(full.controller.weeklyResetAt)
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: full.controller.hasCredits || full.controller.hasResetCredits
        }

        RowLayout {
            Layout.fillWidth: true
            visible: full.controller.hasCredits

            PlasmaComponents3.Label {
                text: "Credits remaining"
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents3.Label {
                text: full.controller.creditsRemaining
                font.weight: Font.DemiBold
                font.features: {"tnum": 1}
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: full.controller.hasResetCredits
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents3.Label {
                    text: "Reset credits"
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents3.Label {
                    text: full.controller.resetCredits + " available"
                    font.weight: Font.DemiBold
                    font.features: {"tnum": 1}
                }
            }

            MetricBar {
                Layout.fillWidth: true
                visible: full.controller.resetCreditProgress >= 0
                value: full.controller.resetCreditProgress
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: full.controller.resetCreditExpiry > 0
                text: (full.controller.resetCredits === 1 ? "Expires: " : "Next expires: ")
                    + full.controller.formatDate(full.controller.resetCreditExpiry)
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: !full.controller.hasSnapshot || full.controller.status === "stale"
            text: full.controller.statusMessage
            color: full.controller.status === "sign_in_required"
                ? Kirigami.Theme.neutralTextColor
                : Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                text: "Refresh"
                icon.name: "view-refresh"
                enabled: !full.controller.refreshing
                onClicked: full.controller.refresh()
            }

            PlasmaComponents3.Button {
                text: "Open ChatGPT"
                icon.name: "internet-web-browser"
                onClicked: Qt.openUrlExternally("https://chatgpt.com")
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents3.BusyIndicator {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                running: full.controller.refreshing
                visible: running
            }
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: full.controller.updatedText
            color: Kirigami.Theme.disabledTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            horizontalAlignment: Text.AlignRight
        }
    }
}
