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

    Layout.minimumWidth: Kirigami.Units.gridUnit * 24
    Layout.minimumHeight: Kirigami.Units.gridUnit * 24
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32

    function rowVisible(m) {
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

            Image {
                source: fv.poller.avatarUrl
                visible: fv.poller.avatarUrl !== ""
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                fillMode: Image.PreserveAspectFit
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

        // --- search + filters ----------------------------------------------
        RowLayout {
            visible: fv.ctrl.authState === "ready"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.TextField {
                Layout.fillWidth: true
                placeholderText: i18n("Search repo, workflow, branch…")
                onTextChanged: fv.searchText = text
            }
            PlasmaComponents.TabBar {
                id: filterBar
                currentIndex: 0
                onCurrentIndexChanged:
                    fv.filterMode = ["all", "running", "failed"][currentIndex]
                PlasmaComponents.TabButton { text: i18n("All") }
                PlasmaComponents.TabButton {
                    text: fv.poller.runningCount > 0
                          ? i18n("Running (%1)", fv.poller.runningCount) : i18n("Running")
                }
                PlasmaComponents.TabButton {
                    text: fv.poller.failedCount > 0
                          ? i18n("Failed (%1)", fv.poller.failedCount) : i18n("Failed")
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
            section.delegate: PlasmaComponents.Label {
                required property string section
                width: list.width
                text: section
                font.bold: true
                opacity: 0.7
                topPadding: Kirigami.Units.smallSpacing * 2
                bottomPadding: 2
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
