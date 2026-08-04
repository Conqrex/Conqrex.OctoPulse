// Shared formatting helpers for OctoPulse QML views.
.pragma library

// "3m ago", "2h ago", "5d ago" from an ISO timestamp.
function relTime(iso) {
    if (!iso) return "";
    var s = Math.max(0, (Date.now() - Date.parse(iso)) / 1000);
    if (s < 60) return Math.floor(s) + "s ago";
    if (s < 3600) return Math.floor(s / 60) + "m ago";
    if (s < 86400) return Math.floor(s / 3600) + "h ago";
    return Math.floor(s / 86400) + "d ago";
}

// "1m 23s" between two ISO timestamps; open-ended runs use now.
function duration(startIso, endIso) {
    if (!startIso) return "";
    var end = endIso ? Date.parse(endIso) : Date.now();
    var s = Math.max(0, Math.round((end - Date.parse(startIso)) / 1000));
    var m = Math.floor(s / 60);
    if (m >= 60) return Math.floor(m / 60) + "h " + (m % 60) + "m";
    if (m > 0) return m + "m " + (s % 60) + "s";
    return s + "s";
}

function truncate(s, n) {
    s = "" + (s || "");
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

// Map a run's status/conclusion pair to a semantic bucket the UI colors by.
// Buckets: running, queued, success, failure, cancelled, neutral.
function bucket(status, conclusion) {
    if (status === "in_progress") return "running";
    if (status === "queued" || status === "waiting"
        || status === "requested" || status === "pending")
        return "queued";
    switch (conclusion) {
    case "success": return "success";
    case "failure":
    case "timed_out": return "failure";
    case "cancelled": return "cancelled";
    default: return "neutral";
    }
}

// true when the bucket represents an unfinished run
function isActive(b) { return b === "running" || b === "queued"; }

function statusText(b) {
    switch (b) {
    case "running": return "in progress";
    case "queued": return "queued";
    case "success": return "success";
    case "failure": return "failure";
    case "cancelled": return "cancelled";
    default: return "";
    }
}

function bucketIcon(b) {
    switch (b) {
    case "running": return "view-refresh";
    case "queued": return "clock";
    case "success": return "checkmark";
    case "failure": return "dialog-close";
    case "cancelled": return "dialog-cancel";
    default: return "dialog-question";
    }
}
