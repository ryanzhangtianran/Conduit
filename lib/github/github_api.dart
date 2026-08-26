import 'package:dio/dio.dart';

import 'github_models.dart';

enum GitHubApiErrorKind { auth, rateLimited, notFound, network, server }

class GitHubApiException implements Exception {
  const GitHubApiException(this.kind, this.message, {this.statusCode});

  final GitHubApiErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Read-only client for the GitHub REST API, authenticated with a device-flow
/// access token. Maps 401/403-rate-limit responses to distinct error kinds so
/// the UI can drive sign-out and polling pauses.
class GithubApi {
  GithubApi({required this.token, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.github.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'maidkit-github',
                'Authorization': 'Bearer $token',
              },
            ),
          );

  final String token;
  final Dio _dio;

  static const _maxReposPages = 3;

  Future<GitHubAccount> currentUser() async {
    final data = await _get('/user');
    return GitHubAccount.fromJson(_asMap(data, 'user'));
  }

  /// Repositories the account can pin, newest-updated first. Paginated up to
  /// [maxReposPages] pages so the picker never hammers the API. The
  /// affiliation list must keep `organization_member`: without it GitHub
  /// hides repos the user can access through organization membership.
  Future<List<GitHubRepo>> listRepos() async {
    final repos = <GitHubRepo>[];
    for (var page = 1; page <= _maxReposPages; page++) {
      final data = await _get(
        '/user/repos',
        query: {
          'per_page': 100,
          'affiliation': 'owner,collaborator,organization_member',
          'sort': 'updated',
          'page': page,
        },
      );
      final items = _asList(data, 'repositories');
      for (final item in items) {
        repos.add(GitHubRepo.fromJson(item));
      }
      if (items.length < 100) break;
    }
    return repos;
  }

  Future<List<GitHubWorkflow>> listWorkflows(String owner, String name) async {
    final data = await _get('/repos/$owner/$name/actions/workflows');
    return [
      for (final item in _asList(data['workflows'], 'workflows'))
        GitHubWorkflow.fromJson(item),
    ];
  }

  Future<List<WorkflowRun>> listRuns(
    String owner,
    String name, {
    String? workflowName,
  }) async {
    final data = await _get(
      '/repos/$owner/$name/actions/runs',
      query: {
        'per_page': 20,
        if (workflowName != null && workflowName.isNotEmpty)
          'workflow_id': workflowName,
      },
    );
    return [
      for (final item in _asList(data['workflow_runs'], 'workflow_runs'))
        WorkflowRun.fromJson(item),
    ];
  }

  Future<WorkflowRun?> latestRunForWorkflow(
    String owner,
    String name,
    String workflowName,
  ) async {
    final runs = await listRuns(owner, name, workflowName: workflowName);
    return runs.firstOrNull;
  }

  Future<List<RunJob>> listJobs(String owner, String name, int runId) async {
    final data = await _get('/repos/$owner/$name/actions/runs/$runId/jobs');
    return [
      for (final item in _asList(data['jobs'], 'jobs')) RunJob.fromJson(item),
    ];
  }

  Future<dynamic> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  GitHubApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const GitHubApiException(
        GitHubApiErrorKind.network,
        'Could not reach GitHub. Check your connection and try again.',
      );
    }
    if (status == 401) {
      return const GitHubApiException(
        GitHubApiErrorKind.auth,
        'GitHub authentication failed. Sign in again on the GitHub tab.',
        statusCode: 401,
      );
    }
    if (status == 403) {
      final remaining = error.response?.headers.value('x-ratelimit-remaining');
      if (remaining == '0') {
        return const GitHubApiException(
          GitHubApiErrorKind.rateLimited,
          'GitHub API rate limit reached. Polling pauses until the limit resets.',
          statusCode: 403,
        );
      }
      return const GitHubApiException(
        GitHubApiErrorKind.auth,
        'GitHub rejected the request. Sign in again on the GitHub tab.',
        statusCode: 403,
      );
    }
    if (status == 404) {
      return GitHubApiException(
        GitHubApiErrorKind.notFound,
        'GitHub resource not found.',
        statusCode: 404,
      );
    }
    if (status != null && status >= 500) {
      return GitHubApiException(
        GitHubApiErrorKind.server,
        'GitHub server error ($status). Try again later.',
        statusCode: status,
      );
    }
    return GitHubApiException(
      GitHubApiErrorKind.network,
      'GitHub request failed: ${error.message}',
      statusCode: status,
    );
  }

  Map<String, dynamic> _asMap(dynamic data, String what) {
    if (data is! Map<String, dynamic>) {
      throw const GitHubApiException(
        GitHubApiErrorKind.network,
        'Unexpected GitHub response shape.',
      );
    }
    return data;
  }

  List<Map<String, dynamic>> _asList(dynamic data, String what) {
    if (data is! List) {
      throw const GitHubApiException(
        GitHubApiErrorKind.network,
        'Unexpected GitHub response shape.',
      );
    }
    return [
      for (final item in data)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
}
