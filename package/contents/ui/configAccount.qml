import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

// Account page: store the GitHub Personal Access Token in the keyring and
// verify it against /user. The token itself never touches the config file —
// only the tokenSaved marker changes (which also tells main.qml to reload).
Kirigami.FormLayout {
    id: page

    property bool cfg_tokenSaved: false
    // unused config keys must still exist as properties for the dialog
    property int cfg_pollInterval
    property int cfg_fastPollInterval
    property int cfg_discoveryInterval
    property int cfg_lookbackDays
    property string cfg_excludedRepos
    property bool cfg_notifyFailure
    property bool cfg_notifyRecovery
    property int cfg_runsPerRepo

    property string testResult: ""
    property bool testing: false

    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'"; }
    readonly property string scriptPath:
        Qt.resolvedUrl("../code/octopulse.sh").toString().replace("file://", "")

    Plasma5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        property var cbs: ({})
        onNewData: (source, data) => {
            var cb = cbs[source];
            if (cb) { delete cbs[source]; cb(("" + (data["stdout"] || "")), data["exit code"]); }
            disconnectSource(source);
        }
        function run(cmd, cb) { if (cmd) { cbs[cmd] = cb || function () {}; connectSource(cmd); } }
    }

    function saveToken() {
        var t = tokenField.text.trim();
        if (!t) return;
        runner.run("printf %s " + shq(t) + " | bash " + shq(scriptPath) + " secret-set",
            function (out, code) {
                if (code === 0) {
                    // toggle so main.qml's onTokenSavedChanged always fires
                    cfg_tokenSaved = false;
                    cfg_tokenSaved = true;
                    testToken(t);
                } else {
                    testResult = i18n("Could not store the token (is secret-tool or kwallet-query installed?)");
                }
            });
    }

    function testToken(t) {
        testing = true;
        testResult = "";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.github.com/user");
        xhr.setRequestHeader("Authorization", "Bearer " + t);
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            testing = false;
            if (xhr.status === 200) {
                try {
                    var u = JSON.parse(xhr.responseText);
                    testResult = i18n("✔ Connected as %1", u.login);
                } catch (e) { testResult = i18n("✔ Connected"); }
            } else if (xhr.status === 401) {
                testResult = i18n("✘ Token rejected (401)");
            } else {
                testResult = i18n("✘ Connection failed (%1)", xhr.status);
            }
        };
        xhr.send();
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("GitHub Personal Access Token")
    }

    QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.7
        text: i18n("Create a token at github.com → Settings → Developer settings. "
                 + "Classic: 'repo' scope. Fine-grained: Actions read/write on the "
                 + "repositories you want to control. The token is stored in your "
                 + "keyring, never in a file.")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Token:")
        QQC2.TextField {
            id: tokenField
            echoMode: TextInput.Password
            placeholderText: page.cfg_tokenSaved ? i18n("(saved — enter to replace)") : "ghp_…"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
        }
        QQC2.Button {
            text: i18n("Save && Test")
            enabled: tokenField.text.trim() !== "" && !page.testing
            onClicked: page.saveToken()
        }
    }

    RowLayout {
        Kirigami.FormData.label: " "
        QQC2.BusyIndicator {
            visible: page.testing
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
        }
        QQC2.Label {
            text: page.testResult
            color: page.testResult.indexOf("✔") === 0
                   ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }
    }

    QQC2.Button {
        Kirigami.FormData.label: " "
        text: i18n("Forget token")
        icon.name: "edit-delete"
        visible: page.cfg_tokenSaved
        onClicked: {
            runner.run("bash " + page.shq(page.scriptPath) + " secret-clear");
            page.cfg_tokenSaved = false;
            page.testResult = "";
        }
    }
}
