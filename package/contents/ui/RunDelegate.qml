import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/format.js" as Fmt

// One workflow run row. Click expands to reveal actions. Running rows carry a
// subtle opacity pulse — the OctoPulse heartbeat.
Item {
    id: row

    required property var fullView
    required property var model
    required property int index

    property bool expanded: false

    readonly property bool shown: fullView.rowVisible(model)
    readonly property color stateColor:
        model.bucket === "running" ? Kirigami.Theme.neutralTextColor
      : model.bucket === "success" ? Kirigami.Theme.positiveTextColor
      : model.bucket === "failure" ? Kirigami.Theme.negativeTextColor
      : Kirigami.Theme.disabledTextColor

    visible: shown
    height: shown ? card.implicitHeight : 0

    Behavior on height {
        NumberAnimation { duration: 120; easing.type: Easing.InOutQuad }
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: hoverArea.containsMouse || row.expanded
               ? Qt.alpha(Kirigami.Theme.highlightColor, 0.10)
               : "transparent"

        SequentialAnimation on opacity {
            running: row.model.bucket === "running" && row.shown
            loops: Animation.Infinite
            NumberAnimation { to: 0.65; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutQuad }
            onRunningChanged: if (!running) card.opacity = 1.0
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: row.expanded = !row.expanded
        }

        ColumnLayout {
            id: col
            width: parent.width - Kirigami.Units.smallSpacing * 2
            x: Kirigami.Units.smallSpacing
            y: Kirigami.Units.smallSpacing
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // status icon; spins while running
                Kirigami.Icon {
                    id: statusIcon
                    source: Fmt.bucketIcon(row.model.bucket)
                    color: row.stateColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    RotationAnimation on rotation {
                        running: row.model.bucket === "running" && row.shown
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1500
                        onRunningChanged: if (!running) statusIcon.rotation = 0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: row.model.workflow
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Label {
                            text: "#" + row.model.runNumber
                            opacity: 0.5
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: row.model.branch
                              + (row.model.commitMsg ? " · " + row.model.commitMsg : "")
                        elide: Text.ElideRight
                        opacity: 0.7
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignRight
                    PlasmaComponents.Label {
                        text: Fmt.relTime(row.model.startedAt)
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.alignment: Qt.AlignRight
                    }
                    PlasmaComponents.Label {
                        text: row.model.bucket === "running"
                              ? Fmt.duration(row.model.startedAt, "")
                              : Fmt.duration(row.model.startedAt, row.model.updatedAt)
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            // --- expanded actions -----------------------------------------
            RowLayout {
                visible: row.expanded
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: row.model.actor ? i18n("by %1 · %2", row.model.actor, row.model.event) : row.model.event
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Re-run")
                    display: PlasmaComponents.ToolButton.TextBesideIcon
                    visible: row.model.bucket !== "running"
                    onClicked: row.fullView.poller.rerun(row.model.repo, row.model.runId)
                }
                PlasmaComponents.ToolButton {
                    icon.name: "edit-redo"
                    text: i18n("Failed jobs")
                    display: PlasmaComponents.ToolButton.TextBesideIcon
                    visible: row.model.bucket === "failure"
                    onClicked: row.fullView.poller.rerunFailed(row.model.repo, row.model.runId)
                    PlasmaComponents.ToolTip { text: i18n("Re-run failed jobs only") }
                }
                PlasmaComponents.ToolButton {
                    id: cancelBtn
                    property bool armed: false
                    icon.name: "process-stop"
                    text: armed ? i18n("Sure?") : i18n("Cancel")
                    display: PlasmaComponents.ToolButton.TextBesideIcon
                    visible: row.model.bucket === "running"
                    onClicked: {
                        if (armed) {
                            armed = false;
                            row.fullView.poller.cancel(row.model.repo, row.model.runId);
                        } else {
                            armed = true;
                            disarmTimer.restart();
                        }
                    }
                    Timer {
                        id: disarmTimer
                        interval: 3000
                        onTriggered: cancelBtn.armed = false
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "media-playback-start"
                    onClicked: row.fullView.openDispatch(row.model)
                    PlasmaComponents.ToolTip { text: i18n("Run workflow (workflow_dispatch)") }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "internet-services"
                    onClicked: Qt.openUrlExternally(row.model.url)
                    PlasmaComponents.ToolTip { text: i18n("Open on GitHub") }
                }
            }

            // jobs + steps + inline logs, created only while expanded
            Loader {
                Layout.fillWidth: true
                active: row.expanded
                visible: row.expanded
                sourceComponent: JobList {
                    fullView: row.fullView
                    repo: row.model.repo
                    runId: row.model.runId
                }
            }
        }
    }
}
