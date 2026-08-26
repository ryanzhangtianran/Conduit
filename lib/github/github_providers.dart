import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_providers.dart';

import 'github_api.dart';
import 'github_device_auth.dart';
import 'github_models.dart';
import 'github_repository.dart';
import 'github_token_store.dart';

final githubTokenStoreProvider = Provider<GitHubTokenStorage>((ref) {
  return VaultGitHubTokenStorage(
    ref.watch(databaseProvider),
    ref.watch(vaultServiceProvider),
  );
});

final githubRepositoryProvider = Provider<GitHubRepository>((ref) {
  return GitHubRepository(
    ref.watch(databaseProvider),
    ref.watch(githubTokenStoreProvider),
  );
});

final githubConnectionsProvider = StreamProvider<List<GitHubConnection>>((ref) {
  return ref.watch(githubRepositoryProvider).watchConnections();
});

/// The account this device is signed in with (the first stored connection).
final githubActiveConnectionProvider = Provider<GitHubConnection?>((ref) {
  final connections = ref.watch(githubConnectionsProvider).asData?.value;
  if (connections == null || connections.isEmpty) return null;
  return connections.first;
});

/// The active connection paired with its vault-stored token, or null while
/// signed out or when no token is stored (e.g. a connection imported from a
/// backup written before tokens were vault-backed).
final githubTokenForConnectionProvider =
    FutureProvider<({GitHubConnection connection, String token})?>((ref) async {
      final connection = ref.watch(githubActiveConnectionProvider);
      if (connection == null) return null;
      final token = await ref
          .watch(githubRepositoryProvider)
          .tokenFor(connection.accountLogin);
      if (token == null || token.isEmpty) return null;
      return (connection: connection, token: token);
    });

final githubApiProvider = Provider<GithubApi?>((ref) {
  final cwt = ref.watch(githubTokenForConnectionProvider).asData?.value;
  return cwt == null ? null : GithubApi(token: cwt.token);
});

final githubPinnedReposProvider = StreamProvider<List<GitHubRepoPin>>((ref) {
  final connection = ref.watch(githubActiveConnectionProvider);
  if (connection == null) return Stream.value(const []);
  return ref
      .watch(githubRepositoryProvider)
      .watchRepoPins()
      .map(
        (pins) =>
            pins.where((pin) => pin.connectionId == connection.id).toList(),
      );
});

/// Bumping this counter refetches the GitHub feeds (manual refresh, tab
/// focus, project detail changes).
final githubRefreshTickProvider =
    NotifierProvider<GitHubRefreshTickNotifier, int>(
      GitHubRefreshTickNotifier.new,
    );

class GitHubRefreshTickNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

enum GitHubSignInPhase {
  idle,
  starting,
  awaitingUser,
  signedIn,
  failed,

  /// GitHub answered 401: the stored token was revoked or expired. The
  /// connection and its pins are kept; signing in again restores the token.
  expired,
}

class GitHubSignInState {
  const GitHubSignInState({
    this.phase = GitHubSignInPhase.idle,
    this.userCode,
    this.verificationUri,
    this.error,
  });

  final GitHubSignInPhase phase;
  final String? userCode;
  final String? verificationUri;
  final String? error;
}

final githubSignInProvider =
    NotifierProvider<GitHubSignInNotifier, GitHubSignInState>(
      GitHubSignInNotifier.new,
    );

/// Drives the OAuth device flow: requests a device code, opens the
/// verification page through the UI, and polls until the user authorizes.
class GitHubSignInNotifier extends Notifier<GitHubSignInState> {
  Timer? _pollTimer;
  int _pollInterval = 5;
  bool _cancelled = true;
  bool _polling = false;
  bool _requesting = false;

  @override
  GitHubSignInState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const GitHubSignInState();
  }

  Future<void> start() async {
    // One flow at a time: a second start while the previous request or poll
    // is still in flight would spawn a duplicate device code and race the
    // timers.
    if (_requesting || _polling) return;
    final clientId = GithubDeviceAuth.configuredClientId;
    if (clientId.isEmpty) {
      state = const GitHubSignInState(
        phase: GitHubSignInPhase.failed,
        error:
            'GITHUB_CLIENT_ID is not configured. Build with '
            '--dart-define=GITHUB_CLIENT_ID=<your OAuth App client id>.',
      );
      return;
    }
    _requesting = true;
    _cancelled = false;
    _polling = false;
    _pollTimer?.cancel();
    // Surface the in-flight request as a loading state so the UI can show a
    // spinner and keep the button disabled; also clears any previous error.
    state = const GitHubSignInState(phase: GitHubSignInPhase.starting);
    final auth = GithubDeviceAuth(clientId: clientId);
    try {
      final code = await auth.requestDeviceCode();
      state = GitHubSignInState(
        phase: GitHubSignInPhase.awaitingUser,
        userCode: code.userCode,
        verificationUri: code.verificationUriComplete ?? code.verificationUri,
      );
      _pollTimer?.cancel();
      _pollInterval = code.interval;
      _pollTimer = Timer.periodic(
        Duration(seconds: code.interval),
        (_) => _poll(auth, code),
      );
    } catch (error) {
      state = GitHubSignInState(
        phase: GitHubSignInPhase.failed,
        error: error.toString(),
      );
    } finally {
      _requesting = false;
    }
  }

  Future<void> _poll(GithubDeviceAuth auth, GitHubDeviceCode code) async {
    if (_cancelled || _polling) return;
    _polling = true;
    try {
      final result = await auth.pollAccessToken(code);
      final token = result.token;
      if (token == null) {
        // GitHub answers `slow_down` with an escalated interval when we poll
        // too fast. Ignore it and GitHub never hands over the token, even
        // after the user authorizes — reschedule with the demanded interval.
        final interval = result.interval;
        if (interval != null && interval > _pollInterval) {
          _pollTimer?.cancel();
          _pollInterval = interval;
          _pollTimer = Timer.periodic(
            Duration(seconds: interval),
            (_) => _poll(auth, code),
          );
        }
        return;
      }
      Logger.root.info('[GitHub] Device flow authorized; fetching account.');
      _pollTimer?.cancel();
      final account = await GithubApi(token: token).currentUser();
      final repository = ref.read(githubRepositoryProvider);
      // Token first: a tokenless connection (if the insert fails) renders as
      // signed-out, while a failed token write still leaves a usable flow.
      await repository.saveToken(account.login, token);
      await repository.saveConnection(account);
      Logger.root.info('[GitHub] Signed in as ${account.login}.');
      state = const GitHubSignInState(phase: GitHubSignInPhase.signedIn);
    } on DeviceFlowException catch (error) {
      _pollTimer?.cancel();
      state = GitHubSignInState(
        phase: GitHubSignInPhase.failed,
        error: error.message,
      );
    } on GitHubApiException catch (error) {
      _pollTimer?.cancel();
      state = GitHubSignInState(
        phase: GitHubSignInPhase.failed,
        error: error.message,
      );
    } catch (error, stackTrace) {
      // Storage or database failures after authorization must surface, not
      // leave the UI waiting forever.
      Logger.root.severe(
        '[GitHub] Sign-in failed after authorization: $error\n$stackTrace',
      );
      _pollTimer?.cancel();
      state = GitHubSignInState(
        phase: GitHubSignInPhase.failed,
        error: 'GitHub sign-in failed: $error',
      );
    } finally {
      _polling = false;
    }
  }

  void cancel() {
    _cancelled = true;
    _polling = false;
    _requesting = false;
    _pollTimer?.cancel();
    state = const GitHubSignInState();
  }

  Future<void> signOut() async {
    final connection = ref.read(githubActiveConnectionProvider);
    if (connection == null) return;
    final repository = ref.read(githubRepositoryProvider);
    await repository.removeToken(connection.accountLogin);
    await repository.removeConnection(connection);
    state = const GitHubSignInState();
  }

  /// A request came back 401: drop the dead token so every feed sees the
  /// account as signed out, and tell the sign-in card why.
  Future<void> expireSession() async {
    final connection = ref.read(githubActiveConnectionProvider);
    if (connection != null) {
      await ref
          .read(githubRepositoryProvider)
          .removeToken(connection.accountLogin);
    }
    _pollTimer?.cancel();
    state = const GitHubSignInState(phase: GitHubSignInPhase.expired);
  }
}

/// Routes a failed API call: an auth failure signs the account out; every
/// other kind is the caller's to show.
void _handleApiFailure(Ref ref, GitHubApiException error) {
  if (error.kind == GitHubApiErrorKind.auth) {
    unawaited(ref.read(githubSignInProvider.notifier).expireSession());
  }
}

/// Polls the runs feed while any pinned run is live. The stream re-emits on
/// every successful fetch; a manual refresh recreates the provider through
/// [githubRefreshTickProvider]. A fetch failure keeps the last snapshot; a
/// rate limit defers the next poll until the limit resets.
class GitHubRunsPoller {
  GitHubRunsPoller(this._fetch) {
    Future.microtask(refresh);
  }

  final Future<GitHubRunsSnapshot> Function(GitHubRunsSnapshot? previous)
  _fetch;
  final StreamController<GitHubRunsSnapshot> _controller =
      StreamController<GitHubRunsSnapshot>.broadcast();
  Timer? _timer;
  GitHubRunsSnapshot? _last;
  bool _disposed = false;

  static const livePollInterval = Duration(seconds: 15);
  static const maxRateLimitWait = Duration(hours: 1);

  Stream<GitHubRunsSnapshot> get stream => _controller.stream;

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final next = await _fetch(_last);
      _last = next;
      if (!_controller.isClosed) _controller.add(next);
    } catch (_) {
      // An auth failure is handled by the fetch callback (sign-out); other
      // failures keep the last snapshot on screen.
    } finally {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed) return;
    final last = _last;
    if (last == null) return;
    final resetAt = last.rateLimitResetAt;
    if (resetAt != null) {
      var wait =
          resetAt.difference(DateTime.now()) + const Duration(seconds: 5);
      if (wait < livePollInterval) wait = livePollInterval;
      if (wait > maxRateLimitWait) wait = maxRateLimitWait;
      _timer = Timer(wait, refresh);
    } else if (last.hasLiveRuns) {
      _timer = Timer(livePollInterval, refresh);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
  }
}

/// Fetches the latest run of every workflow of each pinned repository.
///
/// - A rate limit stops the fetch and returns [previous] (or an empty
///   snapshot) stamped with the reset time, so the last known runs stay
///   visible while polling pauses.
/// - Any other failure of one repository keeps that repository's runs from
///   [previous] and records the message in [GitHubRunsSnapshot.errors].
/// - An auth failure propagates: the caller signs the account out.
Future<GitHubRunsSnapshot> fetchGitHubRunsSnapshot({
  required GithubApi api,
  required List<GitHubRepoPin> pins,
  GitHubRunsSnapshot? previous,
}) async {
  final errors = <String>[];
  final repos = <PinnedRepoRuns>[];
  for (final pin in pins) {
    try {
      final runs = await api.listRuns(pin.owner, pin.name);
      repos.add(
        PinnedRepoRuns(
          owner: pin.owner,
          name: pin.name,
          runs: latestRunPerWorkflow(runs),
        ),
      );
    } on GitHubApiException catch (error) {
      switch (error.kind) {
        case GitHubApiErrorKind.auth:
          rethrow;
        case GitHubApiErrorKind.rateLimited:
          return (previous ?? GitHubRunsSnapshot.empty).withRateLimit(
            error.resetAt ?? DateTime.now().add(const Duration(minutes: 1)),
          );
        case GitHubApiErrorKind.notFound:
        case GitHubApiErrorKind.network:
        case GitHubApiErrorKind.server:
          errors.add('${pin.owner}/${pin.name}: ${error.message}');
          final kept = previous?.repoFor(pin.owner, pin.name);
          if (kept != null) repos.add(kept);
      }
    }
  }
  return GitHubRunsSnapshot(repos: repos, errors: errors);
}

final githubRunsProvider = StreamProvider<GitHubRunsSnapshot>((ref) {
  ref.watch(githubRefreshTickProvider);
  final cwt = ref.watch(githubTokenForConnectionProvider).asData?.value;
  final pins =
      ref.watch(githubPinnedReposProvider).asData?.value ??
      const <GitHubRepoPin>[];
  if (cwt == null || pins.isEmpty) {
    return Stream.value(GitHubRunsSnapshot.empty);
  }
  final api = GithubApi(token: cwt.token);
  var disposed = false;
  final poller = GitHubRunsPoller((previous) async {
    try {
      return await fetchGitHubRunsSnapshot(
        api: api,
        pins: pins,
        previous: previous,
      );
    } on GitHubApiException catch (error) {
      if (!disposed) _handleApiFailure(ref, error);
      rethrow;
    }
  });
  ref.onDispose(() {
    disposed = true;
    poller.dispose();
  });
  return poller.stream;
});

/// True while any pinned repository has a failed, timed-out, cancelled, or
/// action-required run — drives the rail badge and failure banner.
final githubHasFailuresProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(githubRunsProvider).asData?.value;
  return snapshot?.hasFailures ?? false;
});

/// Repositories available for pinning, newest-updated first. Failures
/// surface as the provider's error (the picker renders them); a 401 signs
/// the account out.
final githubAvailableReposProvider = FutureProvider<List<GitHubRepo>>((
  ref,
) async {
  final cwt = ref.watch(githubTokenForConnectionProvider).asData?.value;
  if (cwt == null) return const [];
  try {
    return await GithubApi(token: cwt.token).listRepos();
  } on GitHubApiException catch (error) {
    _handleApiFailure(ref, error);
    rethrow;
  }
});

/// Jobs of one run. A failed fetch is the provider's error state, never an
/// empty list, so the detail page can say "could not load" rather than "no
/// jobs"; a 401 signs the account out.
final githubRunJobsProvider =
    FutureProvider.family<
      List<RunJob>,
      ({String owner, String name, int runId})
    >((ref, key) async {
      final cwt = ref.watch(githubTokenForConnectionProvider).asData?.value;
      if (cwt == null) return const [];
      try {
        return await GithubApi(
          token: cwt.token,
        ).listJobs(key.owner, key.name, key.runId);
      } on GitHubApiException catch (error) {
        _handleApiFailure(ref, error);
        rethrow;
      }
    });
