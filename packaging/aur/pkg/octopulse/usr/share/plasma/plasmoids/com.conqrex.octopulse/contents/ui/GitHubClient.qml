import QtQuick

// Single gateway for all GitHub REST calls: auth header, ETag cache,
// request queue with bounded concurrency, and rate-limit accounting.
// 304 responses are served from the cache at zero rate-limit cost.
QtObject {
    id: client

    property string token: ""
    property string apiBase: "https://api.github.com"

    property int rateRemaining: -1
    property int rateLimit: 0
    property int rateReset: 0          // epoch seconds
    property bool limited: false

    signal unauthorized()
    signal networkError()

    property int maxConcurrent: 4
    property int inFlight: 0
    property var queue: []
    // url -> { etag, data } — parsed JSON bodies reused on 304
    property var etagCache: ({})

    // request("GET", "/user", null, function (r) { ... })
    // r: { ok, status, data, notModified }
    function request(method, path, body, cb) {
        queue.push({ method: method, path: path, body: body, cb: cb });
        pump();
    }

    function pump() {
        if (limited && Date.now() / 1000 < rateReset) return;
        limited = false;
        while (inFlight < maxConcurrent && queue.length > 0)
            send(queue.shift());
    }

    function send(req) {
        if (!token) { if (req.cb) req.cb({ ok: false, status: 0 }); return; }
        inFlight++;
        var url = apiBase + req.path;
        var xhr = new XMLHttpRequest();
        xhr.open(req.method, url);
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        xhr.setRequestHeader("Accept", "application/vnd.github+json");
        xhr.setRequestHeader("X-GitHub-Api-Version", "2022-11-28");
        var cached = etagCache[url];
        if (req.method === "GET" && cached && cached.etag)
            xhr.setRequestHeader("If-None-Match", cached.etag);

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            inFlight--;
            handle(req, url, xhr);
            pump();
        };
        xhr.send(req.body ? JSON.stringify(req.body) : null);
    }

    function handle(req, url, xhr) {
        var rem = xhr.getResponseHeader("x-ratelimit-remaining");
        var lim = xhr.getResponseHeader("x-ratelimit-limit");
        var rst = xhr.getResponseHeader("x-ratelimit-reset");
        if (rem !== null && rem !== "") rateRemaining = parseInt(rem);
        if (lim !== null && lim !== "") rateLimit = parseInt(lim);
        if (rst !== null && rst !== "") rateReset = parseInt(rst);

        if (xhr.status === 0) {
            networkError();
            if (req.cb) req.cb({ ok: false, status: 0 });
            return;
        }
        if (xhr.status === 304) {
            var cached = etagCache[url];
            if (req.cb) req.cb({ ok: true, status: 304, notModified: true,
                                 data: cached ? cached.data : null });
            return;
        }
        if (xhr.status === 401) {
            unauthorized();
            if (req.cb) req.cb({ ok: false, status: 401 });
            return;
        }
        if (xhr.status === 403 || xhr.status === 429) {
            if (rateRemaining === 0) limited = true;
            if (req.cb) req.cb({ ok: false, status: xhr.status, rateLimited: limited });
            return;
        }

        var data = null;
        try { data = xhr.responseText ? JSON.parse(xhr.responseText) : null; }
        catch (e) { data = null; }

        var ok = xhr.status >= 200 && xhr.status < 300;
        if (ok && req.method === "GET") {
            var etag = xhr.getResponseHeader("etag");
            if (etag) {
                var m = etagCache;
                m[url] = { etag: etag, data: data };
                etagCache = m;
            }
        }
        if (req.cb) req.cb({ ok: ok, status: xhr.status, data: data });
    }

    // Follow ?page= pagination up to maxPages; cb gets the concatenated array.
    function getPaged(path, maxPages, cb) {
        var sep = path.indexOf("?") >= 0 ? "&" : "?";
        var acc = [];
        function fetchPage(p) {
            request("GET", path + sep + "page=" + p, null, function (r) {
                if (!r.ok || !r.data) { cb(acc); return; }
                acc = acc.concat(r.data);
                if (r.data.length >= 100 && p < maxPages) fetchPage(p + 1);
                else cb(acc);
            });
        }
        fetchPage(1);
    }
}
