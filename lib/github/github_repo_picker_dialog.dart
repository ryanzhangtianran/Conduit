import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'github_models.dart';
import 'github_providers.dart';
import 'github_ui.dart';

/// Opens the repository picker over the account's repositories and returns
/// the one the user chose to pin, or null when the dialog was dismissed.
/// Repositories whose slug is in [pinnedSlugs] are listed but disabled.
Future<GitHubRepo?> showGitHubRepoPickerDialog(
  BuildContext context, {
  required Set<String> pinnedSlugs,
}) => showDialog<GitHubRepo>(
  context: context,
  builder: (_) => GitHubRepoPickerDialog(pinnedSlugs: pinnedSlugs),
);

/// Searchable list of the account's repositories, in the same floating
/// dialog shape as the server editor. Enter pins the highlighted match,
/// the arrow keys move the highlight, Esc closes.
class GitHubRepoPickerDialog extends ConsumerStatefulWidget {
  const GitHubRepoPickerDialog({super.key, required this.pinnedSlugs});

  final Set<String> pinnedSlugs;

  @override
  ConsumerState<GitHubRepoPickerDialog> createState() =>
      _GitHubRepoPickerDialogState();
}

class _GitHubRepoPickerDialogState
    extends ConsumerState<GitHubRepoPickerDialog> {
  final _search = TextEditingController();
  final _highlightKey = GlobalKey();
  String _query = '';

  /// Slug of the keyboard-highlighted repository; null falls back to the
  /// first pinnable match so Enter always has a target while one exists.
  String? _highlightedSlug;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<GitHubRepo> _filter(List<GitHubRepo> repos) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return repos;
    return repos
        .where(
          (repo) =>
              repo.slug.toLowerCase().contains(query) ||
              (repo.description?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  bool _isPinned(GitHubRepo repo) => widget.pinnedSlugs.contains(repo.slug);

  /// The repository Enter or the primary button would pin.
  GitHubRepo? _highlighted(List<GitHubRepo> filtered) {
    final pinnable = filtered.where((repo) => !_isPinned(repo));
    return pinnable
            .where((repo) => repo.slug == _highlightedSlug)
            .firstOrNull ??
        pinnable.firstOrNull;
  }

  void _moveHighlight(List<GitHubRepo> filtered, int delta) {
    final pinnable = filtered.where((repo) => !_isPinned(repo)).toList();
    if (pinnable.isEmpty) return;
    final current = _highlighted(filtered);
    final index = current == null ? 0 : pinnable.indexOf(current);
    final next = (index + delta).clamp(0, pinnable.length - 1);
    setState(() => _highlightedSlug = pinnable[next].slug);
    // The tile only has a context while the list has built it, which is
    // the case for a one-step move from a visible tile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _highlightKey.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: delta > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void _pick(GitHubRepo? repo) {
    if (repo != null) Navigator.pop(context, repo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = ref.watch(githubAvailableReposProvider);
    final repos = available.asData?.value ?? const <GitHubRepo>[];
    final filtered = _filter(repos);
    final highlighted = _highlighted(filtered);

    final Widget body;
    if (available.isLoading && repos.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (available.hasError && repos.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: GithubLoadErrorNotice(
          message: 'githubReposLoadError'.tr(args: ['${available.error}']),
          onRetry: () => ref.invalidate(githubAvailableReposProvider),
        ),
      );
    } else if (filtered.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'githubNoReposFound'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      body = ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final repo = filtered[index];
          final pinned = _isPinned(repo);
          final isHighlighted = !pinned && repo == highlighted;
          return ListTile(
            key: isHighlighted ? _highlightKey : null,
            enabled: !pinned,
            selected: isHighlighted,
            selectedTileColor: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(
              repo.private ? Symbols.lock : Symbols.inventory_2,
              size: 20,
            ),
            title: Text(repo.slug),
            subtitle: repo.description == null
                ? null
                : Text(
                    repo.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: pinned
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Symbols.check_circle, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'githubRepoPinned'.tr(),
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  )
                : null,
            onTap: pinned ? null : () => _pick(repo),
          );
        },
      );
    }

    // A floating dialog rather than a bottom sheet, sized like the server
    // editor: the list hugs its content up to a maximum height and scrolls
    // inside.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveHighlight(filtered, 1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveHighlight(filtered, -1),
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'githubAddRepo'.tr(),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'commonCancel'.tr(),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Symbols.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'githubSearchRepos'.tr(),
                    prefixIcon: const Icon(Symbols.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'commonClearSearch'.tr(),
                            icon: const Icon(Symbols.close, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                    _highlightedSlug = null;
                  }),
                  onSubmitted: (_) => _pick(highlighted),
                ),
              ),
              Flexible(child: body),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('commonCancel'.tr()),
                    ),
                    FilledButton(
                      onPressed: highlighted == null
                          ? null
                          : () => _pick(highlighted),
                      child: Text('githubPinRepo'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
