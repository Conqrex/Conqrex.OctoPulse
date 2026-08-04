import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

// Repositories page: everything the token can see, grouped by owner
// (user/organization), with visibility checkboxes. Owner checkbox hides the
// whole owner (excludedOwners); repo checkboxes hide single repos
// (excludedRepos). Unchecked = hidden from the widget.
ColumnLayout {
    id: page

    property string cfg_excludedOwners: ""
    property string cfg_excludedRepos: ""

    // [{ owner, repos: ["owner/repo", ...] }]
    property var owners: []
    property bool loading: true
    property string error: ""

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

    function csvSet(s) {
        var m = {};
        ("" + (s || "")).split(",").forEach(function (x) {
            var t = x.trim(); if (t) m[t] = 1;
        });
        return m;
    }
    function setToCsv(m) { return Object.keys(m).join(","); }

    function get(token, path, cb) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://api.github.com" + path);
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var d = null;
            try { d = JSON.parse(xhr.responseText); } catch (e) {}
            cb(xhr.status === 200 && d ? d : null);
        };
        xhr.send();
    }

    function load() {
        loading = true; error = "";
        runner.run("bash " + shq(scriptPath) + " secret-get", function (out) {
            var token = out.trim();
            if (!token) { page.loading = false; page.error = i18n("No token stored — set one under Account first."); return; }
            page.get(token, "/user/repos?per_page=100&sort=full_name", function (userRepos) {
                page.get(token, "/user/orgs", function (orgs) {
                    var all = userRepos || [];
                    var pending = (orgs || []).length;
                    if (pending === 0) { page.applyRepos(all); return; }
                    (orgs || []).forEach(function (o) {
                        page.get(token, "/orgs/" + o.login + "/repos?per_page=100&sort=full_name",
                            function (orgRepos) {
                                all = all.concat(orgRepos || []);
                                if (--pending === 0) page.applyRepos(all);
                            });
                    });
                });
            });
        });
    }

    function applyRepos(raw) {
        var byOwner = {}, seen = {};
        (raw || []).forEach(function (r) {
            if (!r || !r.full_name || seen[r.full_name]) return;
            seen[r.full_name] = 1;
            var owner = r.full_name.split("/")[0];
            (byOwner[owner] = byOwner[owner] || []).push(r.full_name);
        });
        var out = [];
        Object.keys(byOwner).sort().forEach(function (o) {
            out.push({ owner: o, repos: byOwner[o].sort() });
        });
        owners = out;
        loading = false;
        if (out.length === 0) error = i18n("The token cannot see any repositories.");
    }

    Component.onCompleted: load()

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.7
        text: i18n("Unchecked owners and repositories are hidden from the widget. "
                 + "Only what the current token can see is listed — a classic PAT "
                 + "with 'repo' + 'read:org' scopes sees all your organizations.")
    }

    QQC2.BusyIndicator {
        visible: page.loading
        Layout.alignment: Qt.AlignHCenter
    }
    QQC2.Label {
        visible: page.error !== ""
        text: page.error
        color: Kirigami.Theme.negativeTextColor
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        ColumnLayout {
            width: parent.parent.width
            spacing: 2

            Repeater {
                model: page.owners

                delegate: ColumnLayout {
                    id: ownerItem
                    required property var modelData
                    readonly property bool ownerHidden:
                        !!page.csvSet(page.cfg_excludedOwners)[modelData.owner]

                    Layout.fillWidth: true
                    spacing: 1

                    QQC2.CheckBox {
                        text: ownerItem.modelData.owner
                              + " (" + ownerItem.modelData.repos.length + ")"
                        font.bold: true
                        checked: !ownerItem.ownerHidden
                        onToggled: {
                            var m = page.csvSet(page.cfg_excludedOwners);
                            if (checked) delete m[ownerItem.modelData.owner];
                            else m[ownerItem.modelData.owner] = 1;
                            page.cfg_excludedOwners = page.setToCsv(m);
                        }
                    }

                    Repeater {
                        model: ownerItem.modelData.repos
                        delegate: QQC2.CheckBox {
                            required property string modelData
                            Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                            text: modelData.split("/")[1]
                            enabled: !ownerItem.ownerHidden
                            checked: !page.csvSet(page.cfg_excludedRepos)[modelData]
                            onToggled: {
                                var m = page.csvSet(page.cfg_excludedRepos);
                                if (checked) delete m[modelData];
                                else m[modelData] = 1;
                                page.cfg_excludedRepos = page.setToCsv(m);
                            }
                        }
                    }
                }
            }
        }
    }

    QQC2.Button {
        text: i18n("Reload list")
        icon.name: "view-refresh"
        enabled: !page.loading
        onClicked: page.load()
    }
}
