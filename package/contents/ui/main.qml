import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

// Root: loads the token from the keyring, owns the API client and the poller,
// and exposes state to the compact and full representations.
PlasmoidItem {
    id: root

    readonly property url iconSource: Qt.resolvedUrl("../icons/conqrex-octopulse.svg")
    readonly property string scriptPath: Qt.resolvedUrl("../code/octopulse.sh").toString().replace("file://", "")

    // "no-token" | "loading" | "ready" | "unauthorized"
    property string authState: "loading"

    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'"; }

    Plasma5Support.DataSource {
        id: engine
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

    function helper(sub, extra) {
        var c = "bash " + shq(scriptPath) + " " + sub;
        return extra ? (c + " " + extra) : c;
    }

    function notify(summary, body) {
        engine.run(helper("notify", shq(summary) + " " + shq(body) + " " + shq("vcs-normal")));
    }

    // plain-text job log via the helper (curl handles the storage redirect
    // there so the token never reaches the blob host); cb(text)
    function fetchJobLogs(repo, jobId, cb) {
        engine.run(helper("job-logs", shq(repo) + " " + jobId), function (out) { cb(out); });
    }

    function loadToken() {
        authState = "loading";
        engine.run(helper("secret-get"), function (out) {
            var t = out.trim();
            if (t) {
                client.token = t;
                authState = "ready";
                poller.polling = true;
                if (poller.login === "") poller.start();
            } else {
                authState = "no-token";
                poller.polling = false;
            }
        });
    }

    GitHubClient {
        id: client
        onUnauthorized: root.authState = "unauthorized"
    }

    Poller {
        id: poller
        client: client
        notify: root.notify
    }

    Component.onCompleted: loadToken()
    // config page saves a new token then flips tokenSaved; reload it
    Connections {
        target: Plasmoid.configuration
        function onTokenSavedChanged() { root.loadToken() }
    }

    readonly property var pollerRef: poller
    readonly property var clientRef: client

    toolTipMainText: i18n("OctoPulse")
    toolTipSubText: authState === "no-token" ? i18n("No GitHub token configured")
                  : authState === "unauthorized" ? i18n("Token invalid or expired")
                  : poller.failedCount > 0 ? i18n("%1 failing · %2 running", poller.failedCount, poller.runningCount)
                  : poller.runningCount > 0 ? i18n("%1 running", poller.runningCount)
                  : i18n("All workflows green")

    compactRepresentation: CompactView {
        authOk: root.authState === "ready"
        runningCount: poller.runningCount
        failedCount: poller.failedCount
        iconSource: root.iconSource
        onToggleRequested: root.expanded = !root.expanded
    }

    fullRepresentation: FullView { ctrl: root }
}
