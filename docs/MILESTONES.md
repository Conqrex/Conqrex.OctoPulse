# OctoPulse — Milestones

Roadmap for `com.conqrex.octopulse`. Each milestone is independently
shippable and testable with `plasmoidviewer`. See
[DESIGN.md](DESIGN.md) for the full design.

## M0 — Skeleton

Goal: widget installs and shows placeholder content in panel and popup.

- [x] `package/metadata.json` (KPlugin, `Plasma/Applet`, API ≥ 6.0)
- [x] `contents/ui/main.qml` with compact/full representation wiring
- [x] `CompactView.qml` stub (static icon) and `FullView.qml` stub
- [x] `contents/config/config.qml` + `main.xml` skeleton
- [x] `contents/icons/conqrex-octopulse.svg` first-pass icon
- [x] `install.sh` (copy of Dockswain pattern, adjusted id)
- [x] Loads without errors in `plasmoidviewer` and in plasmashell

**Done when:** widget can be added to a panel and opens an empty popup.

## M1 — Auth + Discovery

Goal: token stored securely; widget knows all watchable repos.

- [x] `configAccount.qml`: PAT entry field, save to KWallet, connection test
      (`GET /user`, show avatar + login on success)
- [x] `octopulse.sh`: KWallet get/set via `kwallet-query`, `secret-tool`
      fallback, `notify-send` wrapper
- [x] `GitHubClient.qml`: auth headers, ETag cache, request queue,
      rate-limit tracking, typed error signals
- [x] Discovery loop: user repos + org repos, paginated, ETag-cached,
      15-minute cadence
- [x] 401 banner + polling pause behavior

**Done when:** popup lists discovered repo names with `pushed_at` dates.

## M2 — Runs Feed

Goal: the core product — live view of all workflow runs.

- [x] Runs loop with lookback window filter and per-repo ETag caching
- [x] Fast-poll escalation while runs are queued/in progress
- [x] `RunsModel` with in-place diffing keyed by run id
- [x] `FullView.qml`: repo-grouped run list, `RunDelegate.qml` rows
      (status icon, workflow, branch, commit message, actor, times, duration)
- [x] Compact view states: green / orange pulse (running) / red + count
- [x] Tooltip with last three runs
- [x] Stale indicator + last-updated stamp on network loss
- [ ] JSON fixtures under `docs/fixtures/` for model verification

**Done when:** panel badge reflects real CI state across all repos and the
popup updates live while a run progresses.

## M3 — Run Actions

Goal: act on runs without a browser.

- [x] Re-run all / re-run failed jobs / cancel buttons with optimistic
      status update and error rollback
- [x] `DispatchDialog.qml`: read `workflow_dispatch` inputs from workflow
      file, render input form, POST dispatch with `ref` + `inputs`
- [x] Open-in-browser action on every run row
- [x] Confirmation on cancel

**Done when:** a failed run can be re-run and a dispatch workflow started
entirely from the widget.

## M4 — Logs

Goal: read CI output inline.

- [x] `JobList.qml`: jobs + steps with per-step status on row expand
- [x] `LogView.qml`: per-job plain-text logs, monospace pane, copy button
- [x] Live follow for running jobs (re-fetch on fast interval, auto-scroll,
      follow toggle)

**Done when:** a running job's log can be watched to completion inside the
popup.

## M5 — Notifications + Polish

Goal: feels finished; ready to show publicly.

- [x] Failure and recovery notifications with per-event toggles
- [x] `configGeneral.qml`: poll intervals, lookback window, exclude list,
      notification settings
- [x] Search field and filter chips (All / Running / Failed)
- [x] Rate-limit meter in header with back-off countdown when limited
- [x] Expand/collapse height animations, running-row pulse animation
- [x] Light/dark theme pass — no hardcoded colors

**Done when:** widget survives a week of daily use with no manual restarts
and looks native in both themes.

## M6 — Release

Goal: public open-source release.

- [ ] README with screenshots/GIF, install instructions, PAT scope guide
      (`repo` or fine-grained `actions:read/write`)
- [x] LICENSE (MIT, matching Dockswain)
- [ ] `packaging/aur/` PKGBUILD + repo publishing (Dockswain pattern)
- [ ] KDE Store (store.kde.org) submission
- [ ] Version 0.1.0 tag, GitHub release

**Done when:** a stranger can install from AUR or KDE Store and get to a
working feed in under five minutes.

## Later (post-v1 backlog)

- Multiple accounts (tabs, like Dockswain servers)
- GitHub Enterprise base URL support
- Artifact download/browse
- Per-repo notification rules
- Workflow run history charts (duration trends, failure rates)
