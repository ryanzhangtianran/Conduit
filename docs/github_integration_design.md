# GitHub integration

## Purpose

Let a user sign in to one GitHub account and watch the **Actions workflow
runs** of the repositories they pin: the latest run of each workflow, the
jobs and steps of a run, a compact status strip on the Servers dashboard, and
a failure badge on the GitHub rail destination. The integration is read-only.

## What is built

| Surface | Where |
| --- | --- |
| Sign-in (OAuth device flow), sign-out | `GitHubSection` (`github_section.dart`) on the GitHub page |
| Pinned repositories (pin/unpin; search picker dialog over the account's repos) | `GitHubSection`, `showGitHubRepoPickerDialog` (`github_repo_picker_dialog.dart`) |
| Runs feed: latest run per workflow of every pinned repo, with branch, run number, actor, status/conclusion | `GitHubSection` |
| Run detail: header, "Open on GitHub", jobs with steps | `GitHubRunDetailPage` |
| Dashboard strip: one tile per pinned repo showing its newest run, failing count | `GithubWorkflowStatusStrip` (`servers_page.dart`) |
| Failure badge on the rail destination | `githubHasFailuresProvider` |

## What is NOT built

- Pull requests, releases, check runs, commit status, notifications, or any
  other GitHub surface — only Actions runs and jobs.
- Writing to GitHub: re-running or cancelling workflows, comments, merges.
- Multiple accounts or switching between them (the first stored connection
  is the active one).
- GitHub App installation tokens; only the OAuth App device flow.
- Linking runs to servers or deployments; nothing on a server page refers to
  GitHub.
- OS notifications; failures are surfaced passively (badge, strip, feed).
- Agent/MCP tools.

## Auth: OAuth device flow

`github_device_auth.dart` implements GitHub's device flow, which needs no
redirect URI and no client secret (a secret shipped in a desktop binary would
be extractable anyway):

1. `POST https://github.com/login/device/code` with `client_id` and
   `scope` → `device_code`, `user_code`, `verification_uri(_complete)`,
   `interval`.
2. The section shows the user code (selectable, copy button) and opens the
   verification page in the browser.
3. `POST https://github.com/login/oauth/access_token` is polled every
   `interval` seconds. `authorization_pending` keeps polling; `slow_down`
   reschedules with the interval GitHub demands; `expired_token` and
   `access_denied` end the flow with a message.
4. The token is used to fetch `GET /user`; the token is saved first, then
   the connection (login, display name, avatar).

The registered client ID is public by design and is the build default; it can
be overridden with `--dart-define=GITHUB_CLIENT_ID=…`.

Scopes: `repo` and `read:user`. `repo` is what makes the Actions endpoints
return runs and jobs of **private** repositories; public repositories need
no scope. `read:user` reads the profile shown in the account header.

## Storage

Everything lives in the vault database and therefore in encrypted `.conduit`
backups (`database_backup_service.dart`):

- `github_connections` — account identity (login, name, avatar).
- `github_repo_pins` — pinned `owner/name` per connection.
- `github_tokens` — the access token, encrypted with the vault data key
  through `VaultGitHubTokenStorage` (`github_token_store.dart`). The
  ciphertext never leaves the database in clear; the backup service decrypts
  it while assembling the archive (which is itself encrypted with the vault
  password) and re-encrypts it with the destination vault's key on restore.

Archives written before tokens were vault-backed restore the connection
without a token; the section then shows the sign-in card with a "session
expired" note, and signing in again restores the token for the same account.

## API layer and error handling

`github_api.dart` is a dio client against `https://api.github.com` with
`Accept: application/vnd.github+json` and a bearer token. It maps failures to
`GitHubApiException` kinds, and the providers act on them:

| Kind | Cause | Effect |
| --- | --- | --- |
| `auth` | 401, or 403 that is not a rate limit | `GitHubSignInNotifier.expireSession()`: the token row is deleted, the feeds see the account as signed out, the section shows the sign-in card with the expired-session note. Pins and the connection are kept. |
| `rateLimited` | 403 with `X-RateLimit-Remaining: 0` | `resetAt` is parsed from `X-RateLimit-Reset`. The runs feed keeps the previous snapshot stamped with `rateLimitResetAt`; the section shows the reset time, the dashboard strip keeps its tiles and shows an hourglass, and the poller waits until the reset (5 s grace, capped at one hour). |
| `notFound`, `server`, `network` | per repository | The repository keeps its last known runs and the message is listed under the feed. |

Jobs (`githubRunJobsProvider`) and the repository picker
(`githubAvailableReposProvider`) propagate errors as provider errors so the
UI renders "could not load" rather than an empty list.

Endpoints used:

| Purpose | Endpoint |
| --- | --- |
| Account | `GET /user` |
| Repos | `GET /user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=updated` (up to 3 pages) |
| Runs | `GET /repos/{o}/{r}/actions/runs?per_page=20` |
| Jobs | `GET /repos/{o}/{r}/actions/runs/{id}/jobs` |

## Polling

`GitHubRunsPoller` (`github_providers.dart`) fetches every pinned repo once
when the feed is created, on manual refresh, when the GitHub page opens, and
when a repo is pinned. It re-polls every 15 s only while some pinned run is
queued or in progress. Runs are reduced to the latest run of each workflow
(`latestRunPerWorkflow`). Jobs are fetched on demand when a run detail opens.

## Layout

```text
lib/github/
  github_models.dart          account, repo, run, job/step, snapshot models
  github_api.dart             REST client and error mapping
  github_device_auth.dart     device flow
  github_token_store.dart     vault-encrypted token storage
  github_repository.dart      connections and pins (Drift)
  github_providers.dart       Riverpod providers, sign-in notifier, poller
  github_ui.dart              status visuals, status icon, conclusion chip, time labels
  github_section.dart         sign-in card, account, pins, runs feed
  github_run_detail_page.dart run detail with jobs and steps
  github_workflow_strip.dart  dashboard status strip
  github_page.dart            the GitHub tab page
```
