import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import "../code/format.js" as Fmt

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

    // pinned repos, persisted as CSV in config; pinned groups sort first
    property var favRepos: parseCsv(Plasmoid.configuration.favoriteRepos)
    function parseCsv(s) {
        var m = {};
        ("" + (s || "")).split(",").forEach(function (x) {
            var t = x.trim(); if (t) m[t] = 1;
        });
        return m;
    }
    function toggleFav(r) {
        var m = Object.assign({}, favRepos);
        if (m[r]) delete m[r]; else m[r] = 1;
        favRepos = m;
        Plasmoid.configuration.favoriteRepos = Object.keys(m).join(",");
        poller.rebuild();
    }

    implicitWidth: Kirigami.Units.gridUnit * 30
    implicitHeight: Kirigami.Units.gridUnit * 32
    Layout.minimumWidth: Kirigami.Units.gridUnit * 24
    Layout.minimumHeight: Kirigami.Units.gridUnit * 24
    Layout.preferredWidth: Kirigami.Units.gridUnit * 30
    Layout.preferredHeight: Kirigami.Units.gridUnit * 32

    // OctoPulse dark palette (banner look). Overriding the Kirigami theme
    // scope recolors every PlasmaComponents/Kirigami child in one place;
    // the config toggle falls back to the system theme.
    readonly property bool sysTheme: Plasmoid.configuration.useSystemTheme
    Kirigami.Theme.inherit: sysTheme
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.backgroundColor: "#0d1526"
    Kirigami.Theme.textColor: "#e6edf3"
    Kirigami.Theme.disabledTextColor: "#8b96a5"
    Kirigami.Theme.highlightColor: "#3b82f6"
    Kirigami.Theme.positiveTextColor: "#3fb950"
    Kirigami.Theme.negativeTextColor: "#f85149"
    Kirigami.Theme.neutralTextColor: "#d29922"

    function bucketColor(b) {
        return b === "running" ? Kirigami.Theme.highlightColor
             : b === "queued" ? Kirigami.Theme.neutralTextColor
             : b === "success" ? Kirigami.Theme.positiveTextColor
             : b === "failure" ? Kirigami.Theme.negativeTextColor
             : Kirigami.Theme.disabledTextColor;
    }

    // navy canvas behind everything when the OctoPulse look is on
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Kirigami.Units.smallSpacing
        visible: !fv.sysTheme
        radius: Kirigami.Units.cornerRadius
        color: "#0d1526"
    }

    function rowVisible(m) {
        if (collapsedRepos[m.repo]) return false;
        if (filterMode === "running" && !Fmt.isActive(m.bucket)) return false;
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

        // --- header: logo + title | account chip | rate | refresh ---------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Image {
                source: Qt.resolvedUrl("../icons/octopulse.png")
                sourceSize.width: 64
                sourceSize.height: 64
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                fillMode: Image.PreserveAspectFit
            }
            PlasmaComponents.Label {
                text: i18n("OctoPulse")
                font.bold: true
            }
            Item { Layout.fillWidth: true }

            // account chip
            Rectangle {
                visible: fv.poller.login !== ""
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, 0.07)
                implicitHeight: accountRow.implicitHeight + 6
                implicitWidth: accountRow.implicitWidth + 14
                RowLayout {
                    id: accountRow
                    anchors.centerIn: parent
                    spacing: 4
                    Image {
                        source: fv.poller.avatarUrl
                        visible: fv.poller.avatarUrl !== ""
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        fillMode: Image.PreserveAspectCrop
                    }
                    PlasmaComponents.Label {
                        text: fv.poller.login
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            // rate-limit: colored dot + remaining/limit
            RowLayout {
                visible: fv.client.rateRemaining >= 0
                spacing: 4
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: fv.client.rateRemaining < 200
                           ? Kirigami.Theme.negativeTextColor
                           : Kirigami.Theme.positiveTextColor
                }
                PlasmaComponents.Label {
                    text: fv.client.rateLimit > 0
                          ? fv.client.rateRemaining + " / " + fv.client.rateLimit
                          : "" + fv.client.rateRemaining
                    opacity: 0.6
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
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
                    { key: "all", label: i18n("All"), count: fv.poller.runsModel.count, bucket: "" },
                    { key: "running", label: i18n("Running"), count: fv.poller.runningCount, bucket: "queued" },
                    { key: "failed", label: i18n("Failed"), count: fv.poller.failedCount, bucket: "failure" }
                ]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: fv.filterMode === modelData.key
                    readonly property color accent: modelData.bucket
                        ? fv.bucketColor(modelData.bucket) : Kirigami.Theme.highlightColor

                    radius: height / 2
                    implicitHeight: chipRow.implicitHeight + 8
                    implicitWidth: chipRow.implicitWidth + 18
                    color: active ? Qt.alpha(accent, 0.22)
                                  : Qt.alpha(Kirigami.Theme.textColor, 0.06)
                    border.width: active ? 1 : 0
                    border.color: Qt.alpha(accent, 0.6)

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5
                        PlasmaComponents.Label {
                            text: chip.modelData.label
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.bold: chip.active
                        }
                        Rectangle {
                            visible: chip.modelData.count > 0
                            radius: height / 2
                            implicitHeight: countLbl.implicitHeight + 2
                            implicitWidth: Math.max(implicitHeight, countLbl.implicitWidth + 8)
                            color: Qt.alpha(chip.accent, 0.35)
                            PlasmaComponents.Label {
                                id: countLbl
                                anchors.centerIn: parent
                                text: chip.modelData.count
                                font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                                font.bold: true
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fv.filterMode = chip.modelData.key
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
            spacing: 0    // rows pad themselves; spacing would leave gaps for collapsed rows
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
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)

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

                        // repo initial in a tinted square, banner-style
                        Rectangle {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            radius: 5
                            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                // initial of the repo name (after the owner/)
                                text: {
                                    var n = section.split("/").pop();
                                    return n ? n[0].toUpperCase() : "?";
                                }
                                font.bold: true
                                color: Kirigami.Theme.highlightColor
                            }
                        }
                        PlasmaComponents.Label {
                            text: section
                            font.bold: true
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.ToolButton {
                            readonly property bool fav: !!fv.favRepos[section]
                            icon.name: fav ? "starred-symbolic" : "non-starred-symbolic"
                            opacity: fav ? 1.0 : 0.45
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            onClicked: fv.toggleFav(section)
                            PlasmaComponents.ToolTip {
                                text: fav ? i18n("Unpin repository") : i18n("Pin repository to top")
                            }
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
                        // total-runs pill
                        Rectangle {
                            visible: !!stats
                            radius: height / 2
                            implicitHeight: totalLbl.implicitHeight + 2
                            implicitWidth: Math.max(implicitHeight, totalLbl.implicitWidth + 10)
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.10)
                            PlasmaComponents.Label {
                                id: totalLbl
                                anchors.centerIn: parent
                                text: stats ? stats.total : ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                                font.bold: true
                                opacity: 0.8
                            }
                        }
                        Kirigami.Icon {
                            source: "arrow-down"
                            rotation: collapsed ? -90 : 0
                            Behavior on rotation { NumberAnimation { duration: 120 } }
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            opacity: 0.6
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

        Kirigami.Separator {
            visible: fv.ctrl.authState === "ready"
            Layout.fillWidth: true
        }

        // --- footer: freshness + GitHub link -------------------------------
        RowLayout {
            visible: fv.ctrl.authState === "ready"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                width: 7; height: 7; radius: 3.5
                color: fv.poller.stale ? Kirigami.Theme.negativeTextColor
                                       : Kirigami.Theme.positiveTextColor
            }
            PlasmaComponents.Label {
                text: fv.poller.stale
                      ? i18n("Offline — last update %1", fv.poller.lastUpdated)
                      : fv.poller.lastUpdated
                        ? i18n("Last updated: %1", fv.poller.lastUpdated) : i18n("Loading…")
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: i18n("Open GitHub") + " ⬀"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: linkArea.containsMouse ? Kirigami.Theme.highlightColor
                                              : Kirigami.Theme.textColor
                opacity: linkArea.containsMouse ? 1.0 : 0.7
                MouseArea {
                    id: linkArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://github.com/" + fv.poller.login)
                }
            }
        }
    }
}
