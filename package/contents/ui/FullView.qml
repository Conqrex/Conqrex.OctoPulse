import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

// Popup: header (account, rate limit, refresh), search + filter chips, and
// the run list grouped by repository.
Item {
    id: fv

    required property var ctrl
    readonly property var poller: ctrl.pollerRef
    readonly property var client: ctrl.clientRef

    property string filterMode: "all"     // all | running | failed
    property string searchText: ""
    // repo -> true when its group is collapsed
    property var collapsedRepos: ({})
    function toggleRepo(r) {
        var m = Object.assign({}, collapsedRepos);
        if (m[r]) delete m[r]; else m[r] = true;
        collapsedRepos = m;
    }

    implicitWidth: Kirigami.Units.gridUnit * 30
    implicitHeight: Kirigami.Units.gridUnit * 32
    Layout.minimumWidth: Kirigami.Units.gridUnit * 24
    Layout.minimumHeight: Kirigami.Units.gridUnit * 24
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32

    function rowVisible(m) {
        if (collapsedRepos[m.repo]) return false;
        if (filterMode === "running" && m.bucket !== "running") return false;
        if (filterMode === "failed" && m.bucket !== "failure") return false;
        if (searchText) {
            var q = searchText.toLowerCase();
            if (m.repo.toLowerCase().indexOf(q) < 0
                && m.workflow.toLowerCase().indexOf(q) < 0
                && m.branch.toLowerCase().indexOf(q) < 0)
                return false;
        }
        return true;
    }

    DispatchDialog {
        id: dispatchDialog
        poller: fv.poller
        parent: fv
    }
    function openDispatch(m) { dispatchDialog.openFor(m); }

    // ticks each second while rate limited so the countdown label updates
    property int nowSec: Math.floor(Date.now() / 1000)
    Timer {
        interval: 1000
        running: fv.client.limited
        repeat: true
        onTriggered: fv.nowSec = Math.floor(Date.now() / 1000)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            visible: fv.client.limited
            text: i18n("GitHub API rate limit reached — resuming in %1 s",
                       Math.max(0, fv.client.rateReset - fv.nowSec))
        }

        // --- header --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Avatar {
                source: fv.poller.avatarUrl
                name: fv.poller.login
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            ColumnLayout {
                spacing: 0
                PlasmaComponents.Label {
                    text: fv.poller.login || i18n("OctoPulse")
                    font.bold: true
                }
                PlasmaComponents.Label {
                    text: fv.poller.stale ? i18n("offline — last update %1", fv.poller.lastUpdated)
                        : fv.poller.lastUpdated ? i18n("updated %1", fv.poller.lastUpdated) : ""
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: fv.poller.stale ? Kirigami.Theme.negativeTextColor
                                           : Kirigami.Theme.textColor
                }
            }
            Item { Layout.fillWidth: true }

            // rate-limit meter
            PlasmaComponents.Label {
                visible: fv.client.rateRemaining >= 0
                text: i18n("API %1", fv.client.rateRemaining)
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: fv.client.rateRemaining < 200 ? Kirigami.Theme.negativeTextColor
                                                     : Kirigami.Theme.textColor
            }
            PlasmaComponents.BusyIndicator {
                visible: fv.poller.loading
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                onClicked: fv.poller.refreshRuns()
                PlasmaComponents.ToolTip { text: i18n("Refresh now") }
            }
        }

        // --- auth banners ---------------------------------------------------
        PlasmaExtras.PlaceholderMessage {
            visible: fv.ctrl.authState === "no-token"
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "user-identity"
            text: i18n("No GitHub token")
            explanation: i18n("Open the widget settings and add a Personal Access Token under Account.")
        }
        PlasmaExtras.PlaceholderMessage {
            visible: fv.ctrl.authState === "unauthorized"
            Layout.fillWidth: true
            Layout.fillHeight: true
            iconName: "dialog-error"
            text: i18n("Token invalid or expired")
            explanation: i18n("Update the token in the widget settings under Account.")
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // --- search + filter chips -----------------------------------------
        RowLayout {
            visible: fv.ctrl.authState === "ready"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                placeholderText: i18n("Search repo, workflow, branch…")
                onTextChanged: fv.searchText = text
            }

            Repeater {
                model: [
                    { key: "all", label: i18n("All"), count: 0, color: "" },
                    { key: "running", label: i18n("Running"), count: fv.poller.runningCount, color: "neutral" },
                    { key: "failed", label: i18n("Failed"), count: fv.poller.failedCount, color: "negative" }
                ]
                delegate: PlasmaComponents.Button {
                    required property var modelData
                    readonly property bool active: fv.filterMode === modelData.key
                    text: modelData.count > 0
                          ? modelData.label + " " + modelData.count : modelData.label
                    checkable: true
                    checked: active
                    flat: !active
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    onClicked: fv.filterMode = modelData.key
                    // colored hint dot for running/failed chips
                    leftPadding: modelData.count > 0 ? Kirigami.Units.gridUnit : undefined
                    Rectangle {
                        visible: parent.modelData.count > 0
                        width: 7; height: 7; radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        color: parent.modelData.color === "negative"
                               ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.neutralTextColor
                    }
                }
            }
        }

        // --- run list -------------------------------------------------------
        ListView {
            id: list
            visible: fv.ctrl.authState === "ready"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: fv.poller.runsModel

            section.property: "repo"
            section.delegate: Item {
                required property string section
                readonly property var stats: fv.poller.repoStats[section] || null
                readonly property bool collapsed: !!fv.collapsedRepos[section]
                width: list.width
                height: hdrCard.height + Kirigami.Units.smallSpacing

                Rectangle {
                    id: hdrCard
                    width: parent.width
                    height: hdrRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                    anchors.bottom: parent.bottom
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fv.toggleRepo(section)
                    }

                    RowLayout {
                        id: hdrRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "arrow-down"
                            rotation: collapsed ? -90 : 0
                            Behavior on rotation { NumberAnimation { duration: 120 } }
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            text: section
                            font.bold: true
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        // running badge
                        RowLayout {
                            visible: stats && stats.running > 0
                            spacing: 2
                            PlasmaComponents.BusyIndicator {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }
                            PlasmaComponents.Label {
                                text: stats ? stats.running : ""
                                color: Kirigami.Theme.neutralTextColor
                                font.bold: true
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                        }
                        // failed badge
                        PlasmaComponents.Label {
                            visible: stats && stats.failed > 0
                            text: "✗ " + (stats ? stats.failed : "")
                            color: Kirigami.Theme.negativeTextColor
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                        // all-green badge
                        Kirigami.Icon {
                            visible: stats && stats.failed === 0 && stats.running === 0
                            source: "dialog-ok-apply"
                            color: Kirigami.Theme.positiveTextColor
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        // hidden-count hint while collapsed
                        PlasmaComponents.Label {
                            visible: collapsed && stats
                            text: stats ? i18n("%1 runs", stats.total) : ""
                            opacity: 0.5
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
            }

            delegate: RunDelegate {
                width: list.width
                fullView: fv
            }

            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: list.count === 0 && !fv.poller.loading
                iconName: "checkbox"
                text: i18n("No workflow runs")
                explanation: i18n("Runs from repositories pushed in the last %1 days appear here.",
                                  Plasmoid.configuration.lookbackDays)
            }
        }
    }
}
