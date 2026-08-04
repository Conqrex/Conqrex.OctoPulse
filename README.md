# OctoPulse

OctoPulse is a KDE Plasma 6 widget that follows **all** your GitHub Actions —
every repository you own, collaborate on, or can see through your
organizations — from a single panel popup. No more hopping between repos and
clicking the Actions tab.

## Highlights

- Auto-discovers every repo your token can see (user + organizations) and
  watches the ones with recent pushes.
- Panel icon with a live state dot: green (all passing), pulsing orange
  (runs in progress), red with a count (failures).
- Popup feed grouped by repository: workflow, branch, commit, actor,
  duration — running runs bubble to the top and pulse.
- Search plus All / Running / Failed filters.
- Act without a browser: re-run, re-run failed jobs only, cancel, and
  launch `workflow_dispatch` workflows with parsed input forms.
- Inline job logs with live follow while a job runs.
- Desktop notifications on failure and on recovery (first green after red).
- Gentle on the API: ETag conditional requests (304s are free), adaptive
  polling that only speeds up while runs are active, and a rate-limit meter
  with automatic back-off.
- Token stored in your keyring (KWallet / Secret Service), never in a file.

## Install

```sh
git clone https://github.com/Conqrex/Conqrex.OctoPulse.git
cd Conqrex.OctoPulse
./install.sh
```

Right-click your desktop or panel → **Add Widgets** → search **OctoPulse**.

Reload after changing local code:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

Package id:

```text
com.conqrex.octopulse
```

## Setup

1. Create a token at GitHub → Settings → Developer settings:
   - **Classic PAT:** `repo` scope (private repos + run actions), or
     `public_repo` for public repos only.
   - **Fine-grained PAT:** select the repositories, grant **Actions:
     Read and write** (read-only works for viewing; write enables
     re-run/cancel/dispatch).
2. Widget settings → **Account** → paste the token → **Save & Test**.
3. Tune polling, lookback window, excluded repos, and notifications under
   **General**.

The token is stored via `secret-tool` (Secret Service / KWallet) under
`service cnq-octopulse` and is read back only at widget start.

## Requirements

- KDE Plasma 6
- `libsecret` (`secret-tool`) or `kwallet-query` for token storage
- `curl` for job log download
- `libnotify` (`notify-send`) for notifications (optional)

## Sibling project

[Conqrex.Dockswain](https://github.com/Conqrex/Conqrex.Dockswain) — manage
Docker hosts over SSH from your panel.

## Development

Design and roadmap live in [docs/DESIGN.md](docs/DESIGN.md) and
[docs/MILESTONES.md](docs/MILESTONES.md).

Quick test loop:

```sh
plasmoidviewer -a package
```

## License

MIT — see [LICENSE](LICENSE).
