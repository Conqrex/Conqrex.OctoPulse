import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/format.js" as Fmt

// Jobs and steps for one expanded run, with an inline log pane per job.
// Refetches on a short cadence while any job is still running.
ColumnLayout {
    id: jl

    required property var fullView
    required property string repo
    required property var runId
    property bool anyRunning: false
    property var jobs: []
    property bool loading: true
    property string openLogJob: ""     // job id whose log pane is open

    spacing: 2

    Component.onCompleted: reload()
    Timer {
        interval: 10000
        running: jl.anyRunning && jl.visible
        repeat: true
        onTriggered: jl.reload()
    }

    function reload() {
        fullView.poller.fetchJobs(repo, runId, function (js) {
            jl.loading = false;
            if (!js) return;
            jl.jobs = js;
            jl.anyRunning = js.some(function (j) {
                return j.status === "queued" || j.status === "in_progress";
            });
        });
    }

    PlasmaComponents.BusyIndicator {
        visible: jl.loading
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
    }

    Repeater {
        model: jl.jobs

        delegate: ColumnLayout {
            id: jobItem
            required property var modelData
            readonly property string jobBucket:
                Fmt.bucket(modelData.status, modelData.conclusion)
            readonly property bool logOpen: jl.openLogJob === ("" + modelData.id)

            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Fmt.bucketIcon(jobItem.jobBucket)
                    color: jl.fullView.bucketColor(jobItem.jobBucket)
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                }
                PlasmaComponents.Label {
                    text: jobItem.modelData.name
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: Fmt.duration(jobItem.modelData.started_at,
                                       jobItem.modelData.completed_at || "")
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
                PlasmaComponents.ToolButton {
                    icon.name: "text-x-log"
                    checked: jobItem.logOpen
                    onClicked: jl.openLogJob = jobItem.logOpen ? "" : ("" + jobItem.modelData.id)
                    PlasmaComponents.ToolTip { text: i18n("Show log") }
                }
            }

            // failed / running steps, indented under the job
            Repeater {
                model: (jobItem.modelData.steps || []).filter(function (s) {
                    return s.conclusion === "failure" || s.status === "in_progress";
                })
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: Fmt.bucketIcon(Fmt.bucket(modelData.status, modelData.conclusion))
                        color: jl.fullView.bucketColor(Fmt.bucket(modelData.status, modelData.conclusion))
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    }
                    PlasmaComponents.Label {
                        text: modelData.name
                        opacity: 0.75
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            LogView {
                visible: jobItem.logOpen
                ctrl: jl.fullView.ctrl
                repo: jl.repo
                jobId: "" + jobItem.modelData.id
                jobRunning: jobItem.jobBucket === "running"
                Layout.fillWidth: true
            }
        }
    }
}
