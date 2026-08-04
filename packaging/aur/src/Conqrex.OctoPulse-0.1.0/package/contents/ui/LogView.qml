import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Inline monospace log pane for one job. While the job runs, the log is
// re-fetched on a short cadence; follow mode keeps the view pinned to the end.
ColumnLayout {
    id: lv

    required property var ctrl        // main.qml root (fetchJobLogs)
    required property string repo
    required property string jobId
    property bool jobRunning: false

    property bool follow: true
    property bool loading: true

    spacing: 2

    onVisibleChanged: if (visible && logArea.text === "") reload()
    Component.onCompleted: if (visible) reload()

    Timer {
        interval: 10000
        running: lv.visible && lv.jobRunning
        repeat: true
        onTriggered: lv.reload()
    }

    function reload() {
        loading = true;
        ctrl.fetchJobLogs(repo, jobId, function (text) {
            lv.loading = false;
            logArea.text = text || i18n("(no log output)");
            if (lv.follow) scroller.scrollToEnd();
        });
    }

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.BusyIndicator {
            visible: lv.loading
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        Item { Layout.fillWidth: true }
        PlasmaComponents.ToolButton {
            icon.name: "go-bottom"
            checkable: true
            checked: lv.follow
            onToggled: { lv.follow = checked; if (checked) scroller.scrollToEnd(); }
            PlasmaComponents.ToolTip { text: i18n("Follow log end") }
        }
        PlasmaComponents.ToolButton {
            icon.name: "edit-copy"
            onClicked: { logArea.selectAll(); logArea.copy(); logArea.deselect(); }
            PlasmaComponents.ToolTip { text: i18n("Copy log") }
        }
        PlasmaComponents.ToolButton {
            icon.name: "view-refresh"
            onClicked: lv.reload()
            PlasmaComponents.ToolTip { text: i18n("Reload log") }
        }
    }

    QQC2.ScrollView {
        id: scroller
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 12
        clip: true

        function scrollToEnd() {
            logArea.cursorPosition = logArea.length;
        }

        QQC2.TextArea {
            id: logArea
            readOnly: true
            font.family: "monospace"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            wrapMode: TextEdit.NoWrap
            selectByMouse: true
            background: Rectangle {
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                radius: Kirigami.Units.cornerRadius
            }
        }
    }
}
