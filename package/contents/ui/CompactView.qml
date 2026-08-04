import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Panel view: icon with a state ring — green when all workflows pass, pulsing
// orange while runs are active, red with a count badge on failures.
MouseArea {
    id: ca

    property bool authOk: false
    property int runningCount: 0
    property int failedCount: 0
    property url iconSource

    signal toggleRequested()

    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property color stateColor:
        !authOk ? Kirigami.Theme.disabledTextColor
      : failedCount > 0 ? Kirigami.Theme.negativeTextColor
      : runningCount > 0 ? Kirigami.Theme.neutralTextColor
      : Kirigami.Theme.positiveTextColor

    hoverEnabled: true
    onClicked: ca.toggleRequested()

    Layout.minimumWidth: horizontal ? row.implicitWidth : Kirigami.Units.iconSizes.small
    Layout.preferredWidth: horizontal ? row.implicitWidth : height

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            Layout.alignment: Qt.AlignCenter

            Image {
                anchors.fill: parent
                anchors.margins: 1
                source: ca.iconSource
                sourceSize.width: 128
                sourceSize.height: 128
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: ca.authOk ? 1.0 : 0.55
            }

            // state dot, bottom-right; pulses while runs are active
            Rectangle {
                id: dot
                width: Math.max(6, parent.width * 0.28)
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: ca.stateColor
                border.width: Math.max(1, width * 0.12)
                border.color: Kirigami.Theme.backgroundColor

                SequentialAnimation on opacity {
                    running: ca.runningCount > 0 && ca.failedCount === 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutQuad }
                    onRunningChanged: if (!running) dot.opacity = 1.0
                }
            }
        }

        PlasmaComponents.Label {
            visible: ca.horizontal && ca.authOk
                     && (ca.failedCount > 0 || ca.runningCount > 0)
                     && ca.width > Kirigami.Units.gridUnit * 3
            text: ca.failedCount > 0 ? ("✗" + ca.failedCount)
                : ("▶" + ca.runningCount)
            font.bold: true
            color: ca.stateColor
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
