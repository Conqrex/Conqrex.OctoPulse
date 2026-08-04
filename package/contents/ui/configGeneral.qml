import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property bool cfg_tokenSaved
    property alias cfg_pollInterval: pollSpin.value
    property alias cfg_fastPollInterval: fastSpin.value
    property alias cfg_discoveryInterval: discoverySpin.value
    property alias cfg_lookbackDays: lookbackSpin.value
    property alias cfg_excludedRepos: excludeField.text
    property alias cfg_notifyFailure: notifyFailBox.checked
    property alias cfg_notifyRecovery: notifyRecoverBox.checked
    property alias cfg_runsPerRepo: runsSpin.value

    QQC2.Label { Kirigami.FormData.isSection: true; text: i18n("Polling") }

    QQC2.SpinBox {
        id: pollSpin
        Kirigami.FormData.label: i18n("Refresh interval (s):")
        from: 15; to: 3600
    }
    QQC2.SpinBox {
        id: fastSpin
        Kirigami.FormData.label: i18n("While runs are active (s):")
        from: 5; to: 600
    }
    QQC2.SpinBox {
        id: discoverySpin
        Kirigami.FormData.label: i18n("Repo discovery interval (s):")
        from: 300; to: 86400
        stepSize: 60
    }
    QQC2.SpinBox {
        id: runsSpin
        Kirigami.FormData.label: i18n("Runs per repository:")
        from: 1; to: 30
    }

    QQC2.Label { Kirigami.FormData.isSection: true; text: i18n("Scope") }

    QQC2.SpinBox {
        id: lookbackSpin
        Kirigami.FormData.label: i18n("Watch repos pushed within (days):")
        from: 1; to: 90
    }
    QQC2.TextField {
        id: excludeField
        Kirigami.FormData.label: i18n("Exclude repos:")
        placeholderText: i18n("owner/repo, owner/other")
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    }

    QQC2.Label { Kirigami.FormData.isSection: true; text: i18n("Notifications") }

    QQC2.CheckBox {
        id: notifyFailBox
        Kirigami.FormData.label: i18n("Notify:")
        text: i18n("when a workflow run fails")
    }
    QQC2.CheckBox {
        id: notifyRecoverBox
        text: i18n("when a workflow recovers after a failure")
    }
}
