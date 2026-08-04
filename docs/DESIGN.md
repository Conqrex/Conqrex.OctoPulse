# OctoPulse — Design Document

**Date:** 2026-08-04
**Status:** Approved
**Package id:** `com.conqrex.octopulse`

## Problem

Developers with many repositories (personal and organization) have no single
place to watch GitHub Actions progress. Following CI means switching between
repos in the browser and clicking into the Actions tab of each one. OctoPulse
is a KDE Plasma 6 widget that surfaces every workflow run the user cares about
in one panel popup, with the ability to act on runs (re-run, cancel, dispatch,
read logs) without opening a browser.

Sibling project [Conqrex.Dockswain](https://github.com/SancaK9/Conqrex.Dockswain)
provides the proven project skeleton: Plasma 6 applet package, KWallet secret
storage, install script, and AUR packaging.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Authentication | Personal Access Token stored in KWallet; direct GitHub REST API calls |
| Repo scope | Auto-discover all repos (user + orgs the token can see); optional exclude list |
| Actions on runs | Re-run all, re-run failed jobs, cancel, `workflow_dispatch` with inputs |
| Logs | Inline per-job log view with live follow |
| Notifications | On failure and on first success after failure; configurable off |
| Accounts | Single account, `api.github.com` only in v1 (multi-account and Enterprise later) |
| Architecture | Pure QML + REST polling (Approach A below) |

## Approaches Considered

- **A. Pure QML + REST polling (chosen).** All logic in QML/JS using
  `XMLHttpRequest`; an executable data source is used only for KWallet access
  and desktop notifications. No build step, trivial install, same model as
  Dockswain. Rate-limit pressure is handled with conditional requests
  (`If-None-Match`/ETag — a `304 Not Modified` response does not count against
  the rate limit).
- **B. Helper daemon + cache file.** A background service polls and writes
  JSON that the widget reads. Better rate-limit control but two moving parts,
  a systemd user service, and a worse install story for an open-source widget.
- **C. C++ Plasma plugin.** Native code buys little: GitHub offers no push
  channel for Actions without server-side webhooks, so polling is required
  regardless. A build step kills the easy install.

## Architecture

```
package/
  metadata.json                 # KPlugin, Plasma/Applet, API >= 6.0
  contents/
    ui/
      main.qml                  # plasmoid root, state wiring
      CompactView.qml           # panel icon + badge
      FullView.qml              # popup: header, filters, run list
      RunDelegate.qml           # one workflow run row (expandable)
      JobList.qml               # jobs + steps for an expanded run
      LogView.qml               # inline monospace log pane with follow
      DispatchDialog.qml        # workflow_dispatch input form
      GitHubClient.qml          # API layer: auth, ETag cache, queue, rate limit
      Poller.qml                # discovery + runs polling state machine
      configGeneral.qml         # intervals, lookback, notifications, excludes
      configAccount.qml         # PAT entry -> KWallet, connection test
    config/
      config.qml, main.xml
    code/
      format.js                 # durations, relative times, truncation
      octopulse.sh              # KWallet get/set, notify-send wrapper
    icons/
      conqrex-octopulse.svg
install.sh
packaging/aur/
docs/
```

### GitHubClient.qml

Single API gateway. Responsibilities:

- Adds `Authorization: Bearer <token>` and `Accept: application/vnd.github+json`.
- Keeps an in-memory ETag map keyed by URL; sends `If-None-Match`; treats 304
  as "no change" at zero rate-limit cost.
- Tracks `x-ratelimit-remaining` / `x-ratelimit-reset` from every response and
  exposes them to the UI (rate-limit meter).
- Serializes requests through a small queue so a refresh burst cannot exceed a
  configurable concurrency (default 4).
- Maps HTTP errors to typed signals: `unauthorized` (401), `rateLimited`
  (403/429 with reset time), `networkError`.

### Poller.qml — polling pipeline

Two loops with different cadences:

1. **Discovery loop** (default every 15 min):
   `GET /user/repos?per_page=100&sort=pushed` (paginated) plus
   `GET /user/orgs` → `GET /orgs/{org}/repos?per_page=100&sort=pushed`.
   Produces the candidate repo set. ETag-cached.
2. **Runs loop** (default every 60 s): for each repo whose `pushed_at` falls
   within the lookback window (default 7 days) and is not excluded:
   `GET /repos/{owner}/{repo}/actions/runs?per_page=10`. ETag-cached, so
   quiet repos cost nothing.
   While any run is `queued` or `in_progress`, that repo is polled on a fast
   interval (default 10 s) and its jobs endpoint is polled for step progress.

### RunsModel

`ListModel` of flattened runs across all repos. Roles: repo, workflow name,
run number, event, branch, commit message, actor, status, conclusion,
timestamps, duration, URL, run id. Sort: running first, then newest. The
model diffs incoming data against existing rows (keyed by run id) so the UI
updates in place without list resets.

### Secrets

PAT never touches config files. `contents/code/octopulse.sh` wraps
`kwallet-query` (fallback: `secret-tool`) for get/set, invoked through the
Plasma executable data source — the same pattern Dockswain uses for SSH
passwords. Config stores only a boolean "token saved" marker.

### Run actions

- `POST /repos/{o}/{r}/actions/runs/{id}/rerun`
- `POST /repos/{o}/{r}/actions/runs/{id}/rerun-failed-jobs`
- `POST /repos/{o}/{r}/actions/runs/{id}/cancel`
- `POST /repos/{o}/{r}/actions/workflows/{workflow_id}/dispatches`
  with `ref` and `inputs` collected by `DispatchDialog.qml` (inputs read from
  the workflow file's `on.workflow_dispatch.inputs` via the contents API).

### Logs

`GET /repos/{o}/{r}/actions/runs/{id}/jobs` lists jobs and steps with status.
Per-job logs come from `GET /repos/{o}/{r}/actions/jobs/{job_id}/logs`
(plain text after redirect). For running jobs, the log endpoint is re-fetched
on the fast interval and the view auto-scrolls (follow mode, toggleable).

### Notifications

On transition to `conclusion: failure` → notification "❌ {repo} · {workflow}
failed on {branch}". On first success after a failure of the same workflow →
"✅ {repo} · {workflow} recovered". Sent with `notify-send` through the
executable data source. Global on/off plus per-event toggles in config.

## UI Design

Open-source project — visual quality is a feature. Kirigami/Plasma theme
colors throughout so the widget looks native in light and dark themes.

- **Compact (panel):** OctoPulse icon with state ring — green (all green),
  animated orange pulse (runs in progress), red with failure count badge.
  Hover tooltip shows the three most recent runs.
- **Full popup:**
  - Header: account avatar + login, rate-limit meter, last-updated stamp,
    manual refresh button.
  - Search field (repo/workflow/branch) and filter chips: All · Running ·
    Failed.
  - Run list grouped by repository, collapsible groups. Each run row: status
    icon (spinner animation while running), workflow name, branch, short
    commit message, actor, relative start time, duration.
  - Expanding a row reveals jobs and steps with per-step status, plus action
    buttons: re-run, re-run failed, cancel, logs, open in browser.
  - Log pane opens inline below the job, monospace, dark background, follow
    toggle, copy button.
- Motion: smooth height animations on expand/collapse; subtle opacity pulse
  on running rows — the "pulse" of OctoPulse.

## Error Handling

| Condition | Behavior |
|---|---|
| 401 Unauthorized | Persistent banner "Token invalid or expired" with link to Account config; polling paused |
| 403/429 rate limited | Back off until `x-ratelimit-reset`; meter turns red; countdown shown |
| Network down | Keep last data, show stale indicator + last-updated time; retry with backoff |
| Repo disappeared (404) | Drop from model silently on next discovery pass |
| KWallet unavailable | Banner explaining secret storage requirement; `secret-tool` fallback attempted |

## Testing

- Manual testing on Plasma 6 with `plasmoidviewer -a package` and full
  plasmashell reload (`kquitapp6 plasmashell && kstart plasmashell`).
- Model/formatting logic exercised against recorded JSON fixtures of the
  GitHub API responses (stored under `docs/fixtures/`) so RunsModel diffing,
  sorting, and status mapping can be verified without network.
- Rate-limit behavior verified by forcing low-limit responses via fixture
  replay.

## Out of Scope (v1)

- Multiple GitHub accounts, GitHub Enterprise base URLs.
- Webhooks or any server-side component.
- Artifact downloads.
- Non-Linux ports (Dockswain-style macOS/MAUI companions may come later).
