# API fixtures

Synthetic GitHub API responses matching the shapes OctoPulse consumes
(no real account data). Use them to exercise model logic without network:

| File | Endpoint |
| --- | --- |
| `workflow_runs.json` | `GET /repos/{owner}/{repo}/actions/runs` |
| `run_jobs.json` | `GET /repos/{owner}/{repo}/actions/runs/{id}/jobs` |
| `user.json` | `GET /user` |
| `user_repos.json` | `GET /user/repos` (trimmed to the fields the widget reads) |

Covered states: `in_progress`, `completed/success`, `completed/failure`,
running job with an in-progress step, and a repo outside the lookback
window (`example/dormant`).
