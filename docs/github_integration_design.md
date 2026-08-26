# GitHub integration design

## Purpose

Add a top-level GitHub tab where users authenticate once and monitor CI/CD and
repository activity: Actions run status and deploy linkage from Conduit
deployment projects to the workflows that ship them. v1 (Actions monitoring) and v2 (the surrounding surfaces) are
delivered together in one build.

## Scope

In scope:

- OAuth device-flow sign-in, one GitHub account at a time.
- Pinned repository list, persisted per device.
- Actions: workflow runs with live status, per-run jobs, open on GitHub.
- Deploy linkage: `githubWorkflow` deployment resources that show the latest
  run on the project detail page.
- A compact workflow-status card on the Servers dashboard (one tile per pinned
  repo) and a failure badge on the Assets rail destination.

Out of scope (future):

- Writing to GitHub: re-run workflows, PR comments, merge. Re-running a
  workflow needs the `workflow` scope; this build is read-only.
- Multi-account switching and org-wide dashboards.
- GitHub App installation tokens.

## Auth: OAuth device flow

GitHub's device flow is the desktop-friendly grant: no redirect URI, no
embedded client secret. The client shows a verification URL and user code and
polls for the token. Only OAuth Apps support device flow — not GitHub Apps.

Flow:

1. `POST https://github.com/login/device/code` with `client_id` and
   `scope: "repo read:user"` → `device_code`, `user_code`, `verification_uri`,
   `expires_in` (900 s), `interval` (5 s).
2. Show `verification_uri` (deep link to `verification_uri_complete`) and the
   `user_code`; open the browser via `url_launcher`.
3. Poll `POST https://github.com/login/oauth/access_token` with `client_id`,
   `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code`.
   Error handling: `authorization_pending` → keep polling; `slow_down` → poll
   interval + 5 s; `expired_token` → restart flow; `access_denied` → cancel.
4. The returned access token is long-lived with no refresh; it is revoked from
   GitHub settings. A 401 marks the connection signed-out and the user
   re-authenticates.

The client secret is intentionally never embedded: the device flow does not
require it, and a secret shipped in a desktop binary is extractable. The
registered client ID is public by design and is the build default; it can be
overridden with `--dart-define=GITHUB_CLIENT_ID=…`.

Scopes: `repo` (reads Actions runs and jobs) and `read:user` (account
profile).

## Storage

**Tokens are local-only.** The access token lives in the OS keychain through
`flutter_secure_storage` under `conduit_github_token_<accountLogin>` and never
enters the vault database, backups, or cloud sync — a device-local secret, the
same policy as learned SSH host-key fingerprints. A synced connection whose
token is absent on this device renders as signed-out.

**Metadata syncs with the vault.** Connection identity (login, display name,
avatar), repo pins, and project-workflow links are non-secret and are added to
the syncable payload in `database_backup_service.dart`, so they travel with
the user's vault. The payload stays backward compatible: archives without the
GitHub keys import as empty.

```dart
class GitHubConnections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get accountLogin => text().unique()();
  TextColumn get accountName => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
}

class GitHubRepoPins extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get connectionId => integer().references(GitHubConnections, #id)();
  TextColumn get owner => text()();
  TextColumn get name => text()();
  DateTimeColumn get pinnedAt => dateTime()();
}

class GitHubProjectWorkflowLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(DeploymentProjects, #id)();
  TextColumn get owner => text()();
  TextColumn get name => text()();
  TextColumn get workflowName => text()();
  DateTimeColumn get linkedAt => dateTime()();
}
```

`projectId` mirrors `DeploymentResources.projectId`; integer ids are stable
across devices because the whole blob syncs as one archive with ids preserved.

## API layer

`github_api.dart`: dio-based, base `https://api.github.com`, headers
`Accept: application/vnd.github+json` and `Authorization: Bearer <token>`.
Central error mapping: 401 → signed-out state; 403 + rate limit → pause
polling until `X-RateLimit-Reset` and surface in the UI; network errors →
retry with backoff. Authenticated limit is 5000 requests/hour — far above the
polling budget.

Endpoints used:

| Purpose | Endpoint |
| --- | --- |
| Account | `GET /user` |
| Repos | `GET /user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=updated` (paginate) |
| Runs | `GET /repos/{o}/{r}/actions/runs?per_page=20` |
| Runs by workflow | `GET /repos/{o}/{r}/actions/runs?workflow_id={name}` |
| Jobs | `GET /repos/{o}/{r}/actions/runs/{id}/jobs` |
| Logs | `GET /repos/{o}/{r}/actions/runs/{id}/logs` (open in browser) |

## Polling budget

Only live things are polled: runs with `status ∈ {queued, in_progress}` every
15 s per pinned repo. Completed runs and jobs are fetched on demand (tab
focus, pull-to-refresh). Polling stops after repeated failures (exponential
backoff) and pauses on rate-limit 403. Worst case ≈ 4 pinned repos × 4
req/min ≈ 960 req/hr, leaving headroom.

## Notifications

None: failing runs are surfaced passively — a failure badge on the Assets
rail destination and the failing count in the dashboard workflow card. No OS
or in-app alerts.

## UI

GitHub content lives **inside the Assets tab** (`assets_page.dart`) as a
`GitHubSection` — no separate top-level tab. The Servers dashboard
(`servers_page.dart`) shows a **compact workflow-status strip** above the
server grid: one pill per pinned workflow (its latest run), colored by status,
tap → run detail. A failure badge sits on the Assets rail destination, and
a failure badge sits on the Assets rail destination. All strings in
`assets/translations/en-US.json` + `zh-CN.json`.

Sections (single scrollable page, desktop-friendly):

- Account card: avatar, login, sign out, re-authenticate on 401.
- Pinned repos: search-picker over `GET /user/repos`, pin/unpin.
- Runs feed per pinned repo: the latest run of each workflow, with branch,
  head commit, actor, status chip (queued / in_progress / success / failure /
  cancelled); tap → run detail with jobs and steps, "Open on GitHub".

GitHub workflow links are a **deployment resource kind** (`githubWorkflow`) in
the regular add/edit-resource sheet on the project detail page. The resource's
configuration stores `{owner, name, workflow}`; its tile shows the latest run
with status, trigger message, and timestamp, plus quick actions to open the
run detail or the GitHub page.

Agent tools on the local MCP server, read-only, named `github_*`:
`github_list_runs`, `github_get_run`, `github_list_jobs`, `github_open_prs`,
`github_get_release`. They go through the same approval dialogs as existing
tools.

## Layout

Keep it flat under `lib/github/` per repo rules:

```text
lib/github/
  github_models.dart
  github_api.dart
  github_device_auth.dart
  github_repository.dart
  github_providers.dart
  github_section.dart        (embedded in the Assets tab)
  github_workflow_strip.dart  (Servers dashboard)
  github_run_detail_page.dart
  github_notifications.dart
  github_mcp_tools.dart
```

(Workflow links live as `githubWorkflow` deployment resources; the standalone
`github_project_workflow_links` table was removed in schema 21.)

## Build order (single delivery)

1. Drift tables + `dart run build_runner build` (schema, then `app_router.gr.dart`).
2. Device-flow auth + encrypted token storage (mirror `SavedCredentials`).
3. dio API client with rate-limit and 401 handling.
4. Tab scaffold: route, rail destinations, localization keys.
5. Runs/jobs UI + live polling.
6. PRs + releases sections.
7. Project → workflow linkage on the project detail page.
8. Notifications (badge, in-app banner, OS) + agent MCP tools.
9. `flutter analyze` + tests + manual smoke run.
