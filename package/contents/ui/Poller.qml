import QtQuick
import org.kde.plasma.plasmoid
import "../code/format.js" as Fmt

// Polling state machine: repo discovery on a slow cadence, workflow runs on a
// normal cadence that escalates to a fast interval while anything is running.
Item {
    id: poller

    required property var client
    // notify(summary, body) — provided by main.qml (executable engine).
    property var notify: function (s, b) {}

    property bool polling: false

    // account
    property string login: ""
    property string avatarUrl: ""

    // discovery output: [{ fullName, pushedAt }], newest push first
    property var repos: []
    // fullName -> array of raw run objects from the API
    property var runsByRepo: ({})

    property ListModel runsModel: ListModel {}
    // repo -> { running, failed, total } for the group headers
    property var repoStats: ({})
    property int runningCount: 0
    property int failedCount: 0
    property string lastUpdated: ""
    property bool stale: false
    property bool loading: false

    // "repo — workflow" -> last seen conclusion of the newest completed run.
    // Used to fire failure/recovery notifications only on transitions.
    property var lastConclusion: ({})
    property bool initialLoadDone: false

    onPollingChanged: if (polling) start()
    function start() {
        login = ""; avatarUrl = "";
        client.request("GET", "/user", null, function (r) {
            if (r.ok && r.data) {
                login = r.data.login || "";
                avatarUrl = r.data.avatar_url || "";
            }
        });
        discover();
    }

    // --- discovery ---------------------------------------------------------
    Timer {
        interval: Math.max(300, Plasmoid.configuration.discoveryInterval) * 1000
        running: poller.polling
        repeat: true
        onTriggered: poller.discover()
    }

    function discover() {
        client.getPaged("/user/repos?per_page=100&sort=pushed", 3, function (userRepos) {
            client.request("GET", "/user/orgs", null, function (r) {
                var orgs = (r.ok && r.data) ? r.data : [];
                var pending = orgs.length;
                var all = userRepos.slice();
                if (pending === 0) { poller.applyRepos(all); return; }
                orgs.forEach(function (o) {
                    client.getPaged("/orgs/" + o.login + "/repos?per_page=100&sort=pushed", 2,
                        function (orgRepos) {
                            all = all.concat(orgRepos);
                            if (--pending === 0) poller.applyRepos(all);
                        });
                });
            });
        });
    }

    function applyRepos(raw) {
        var seen = {}, out = [];
        raw.forEach(function (r) {
            if (!r || !r.full_name || seen[r.full_name]) return;
            seen[r.full_name] = 1;
            out.push({ fullName: r.full_name, pushedAt: r.pushed_at || "" });
        });
        out.sort(function (a, b) { return a.pushedAt < b.pushedAt ? 1 : -1; });
        repos = out;
        refreshRuns();
    }

    function excludedSet() {
        var m = {};
        ("" + (Plasmoid.configuration.excludedRepos || "")).split(",").forEach(function (x) {
            var t = x.trim(); if (t) m[t] = 1;
        });
        return m;
    }

    function watchedRepos() {
        var cutoff = Date.now() - Plasmoid.configuration.lookbackDays * 86400 * 1000;
        var ex = excludedSet();
        return repos.filter(function (r) {
            return !ex[r.fullName] && r.pushedAt && Date.parse(r.pushedAt) >= cutoff;
        });
    }

    // --- runs loop ---------------------------------------------------------
    Timer {
        interval: (poller.runningCount > 0
                   ? Math.max(5, Plasmoid.configuration.fastPollInterval)
                   : Math.max(15, Plasmoid.configuration.pollInterval)) * 1000
        running: poller.polling
        repeat: true
        onTriggered: poller.refreshRuns()
    }

    function refreshRuns() {
        var watch = watchedRepos();
        if (watch.length === 0) { rebuild(); return; }
        loading = true;
        var pending = watch.length;
        var perRepo = Plasmoid.configuration.runsPerRepo || 10;
        watch.forEach(function (r) {
            client.request("GET",
                "/repos/" + r.fullName + "/actions/runs?per_page=" + perRepo, null,
                function (res) {
                    if (res.ok && res.data && res.data.workflow_runs) {
                        var m = poller.runsByRepo;
                        m[r.fullName] = res.data.workflow_runs;
                        poller.runsByRepo = m;
                        poller.stale = false;
                    } else if (!res.ok && res.status === 0) {
                        poller.stale = true;
                    }
                    if (--pending === 0) {
                        poller.loading = false;
                        poller.lastUpdated = Qt.formatTime(new Date(), "HH:mm");
                        poller.rebuild();
                    }
                });
        });
    }

    // Flatten runsByRepo into the sorted list model (running first, then
    // newest), diffing by run id so rows update in place without list resets.
    function rebuild() {
        var arr = [];
        var watch = {};
        watchedRepos().forEach(function (r) { watch[r.fullName] = 1; });
        for (var repo in runsByRepo) {
            if (!watch[repo]) continue;
            runsByRepo[repo].forEach(function (run) {
                arr.push(rowOf(repo, run));
            });
        }
        arr.sort(function (a, b) {
            var ar = a.bucket === "running" ? 0 : 1;
            var br = b.bucket === "running" ? 0 : 1;
            if (ar !== br) return ar - br;
            return a.startedAt < b.startedAt ? 1 : -1;
        });

        for (var i = 0; i < arr.length; i++) {
            if (i < runsModel.count && runsModel.get(i).runId === arr[i].runId)
                runsModel.set(i, arr[i]);
            else
                runsModel.insert(i, arr[i]);
        }
        while (runsModel.count > arr.length)
            runsModel.remove(runsModel.count - 1);

        var stats = {};
        arr.forEach(function (r) {
            if (!stats[r.repo]) stats[r.repo] = { running: 0, failed: 0, total: 0 };
            var s = stats[r.repo];
            s.total++;
            if (r.bucket === "running") s.running++;
            else if (r.bucket === "failure") s.failed++;
        });
        repoStats = stats;

        recount(arr);
        checkTransitions(arr);
    }

    function rowOf(repo, run) {
        return {
            runId: run.id,
            repo: repo,
            workflowId: run.workflow_id || 0,
            workflowPath: run.path || "",
            workflow: run.name || (run.workflow_id + ""),
            runNumber: run.run_number || 0,
            event: run.event || "",
            branch: run.head_branch || "",
            commitMsg: run.head_commit ? (run.head_commit.message || "").split("\n")[0] : "",
            actor: run.actor ? (run.actor.login || "") : "",
            status: run.status || "",
            conclusion: run.conclusion || "",
            bucket: Fmt.bucket(run.status, run.conclusion),
            startedAt: run.run_started_at || run.created_at || "",
            updatedAt: run.updated_at || "",
            url: run.html_url || ""
        };
    }

    function recount(arr) {
        var running = 0;
        // newest completed run per repo+workflow decides "currently failed"
        var newest = {};
        arr.forEach(function (r) {
            if (r.bucket === "running") { running++; return; }
            var k = r.repo + " — " + r.workflow;
            if (!newest[k] || newest[k].startedAt < r.startedAt) newest[k] = r;
        });
        var failed = 0;
        for (var k in newest)
            if (newest[k].bucket === "failure") failed++;
        runningCount = running;
        failedCount = failed;
    }

    function checkTransitions(arr) {
        var newest = {};
        arr.forEach(function (r) {
            if (!r.conclusion) return;
            var k = r.repo + " — " + r.workflow;
            if (!newest[k] || newest[k].startedAt < r.startedAt) newest[k] = r;
        });
        var prev = lastConclusion;
        var next = {};
        for (var k in newest) {
            var c = newest[k].conclusion;
            next[k] = c;
            if (!initialLoadDone) continue;
            var was = prev[k];
            if (c === "failure" && was !== "failure" && was !== undefined) {
                if (Plasmoid.configuration.notifyFailure)
                    notify("❌ " + k + " failed",
                           newest[k].branch + " · " + Fmt.truncate(newest[k].commitMsg, 80));
            } else if (c === "success" && was === "failure") {
                if (Plasmoid.configuration.notifyRecovery)
                    notify("✅ " + k + " recovered",
                           newest[k].branch + " · " + Fmt.truncate(newest[k].commitMsg, 80));
            }
        }
        lastConclusion = next;
        initialLoadDone = true;
    }

    // --- run actions -------------------------------------------------------
    function rerun(repo, runId, cb)       { post(repo, runId, "rerun", cb); }
    function rerunFailed(repo, runId, cb) { post(repo, runId, "rerun-failed-jobs", cb); }
    function cancel(repo, runId, cb)      { post(repo, runId, "cancel", cb); }
    function post(repo, runId, action, cb) {
        client.request("POST", "/repos/" + repo + "/actions/runs/" + runId + "/" + action,
            null, function (r) {
                if (r.ok) refreshRuns();
                if (cb) cb(r.ok);
            });
    }

    // jobs + steps for one run; cb(jobsArray|null)
    function fetchJobs(repo, runId, cb) {
        client.request("GET",
            "/repos/" + repo + "/actions/runs/" + runId + "/jobs?per_page=50", null,
            function (r) {
                cb(r.ok && r.data && r.data.jobs ? r.data.jobs : null);
            });
    }

    // workflow file text (for dispatch input discovery); cb(text|null)
    function fetchWorkflowFile(repo, path, cb) {
        if (!path) { cb(null); return; }
        client.request("GET", "/repos/" + repo + "/contents/" + path, null, function (r) {
            if (r.ok && r.data && r.data.content) {
                try { cb(Qt.atob(r.data.content.replace(/\n/g, ""))); return; }
                catch (e) {}
            }
            cb(null);
        });
    }

    // cb(ok, message) — 204 on success, 422 when the workflow has no
    // workflow_dispatch trigger or inputs are invalid.
    function dispatch(repo, workflowId, ref, inputs, cb) {
        client.request("POST",
            "/repos/" + repo + "/actions/workflows/" + workflowId + "/dispatches",
            { ref: ref, inputs: inputs || {} },
            function (r) {
                if (r.ok) refreshRuns();
                cb(r.ok, r.ok ? "" :
                   (r.data && r.data.message ? r.data.message : ("HTTP " + r.status)));
            });
    }
}
