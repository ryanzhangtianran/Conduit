import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';

import 'server_providers.dart';
import 'server_editor_dialog.dart';
import 'server_reorder.dart';
import 'ssh_config_bulk.dart';
import 'ssh_config_sync.dart' hide sshConfigAliasFor;

/// Saved servers and the local OpenSSH config as a top-level sidebar page.
@RoutePage()
class ConnectionsPage extends ConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConduitAppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: const [
          SavedServersSection(),
          SizedBox(height: 32),
          LocalSshConfigSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'connections-create-fab',
        onPressed: () => showServerEditor(context, ref),
        icon: const Icon(Symbols.add),
        label: Text('serversAddServer'.tr()),
      ),
    );
  }
}

class SavedServersSection extends ConsumerWidget {
  const SavedServersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'assetsSshTargetsTitle'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'assetsConnectionsDescription'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        servers.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              Text('serversLoadError'.tr(args: [error.toString()])),
          data: (items) => items.isEmpty
              ? Text(
                  'serversEmptyHint'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  onReorderItem: (from, to) => _reorder(ref, items, from, to),
                  children: [
                    for (final (index, server) in items.indexed)
                      _ServerRow(
                        key: ValueKey(server.id),
                        server: server,
                        dragIndex: index,
                        onEdit: () =>
                            showServerEditor(context, ref, server: server),
                        onDelete: () => _delete(context, ref, server),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Drag from a row's grip: same index semantics as the navigation rail.
  void _reorder(WidgetRef ref, List<Server> items, int from, int to) {
    if (from == to) return;
    final ids = [for (final server in items) server.id];
    ids.insert(to, ids.removeAt(from));
    persistServerOrder(ref, ids);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Server server,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('serversDeleteServer'.tr()),
        content: Text(server.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('commonCancel').tr(),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('commonDelete').tr(),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(serverRepositoryProvider).delete(server);
  }
}

class _ServerRow extends ConsumerWidget {
  const _ServerRow({
    super.key,
    required this.server,
    required this.dragIndex,
    required this.onEdit,
    required this.onDelete,
  });

  final Server server;

  /// Index handed to the drag grip; null for rows that cannot be reordered.
  final int? dragIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Symbols.dns),
      title: Text(server.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text('${server.host} · ${server.username} · ${server.port}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (server.collectStats)
                _ServerTag(label: 'assetsTagMetrics'.tr()),
              if (server.collectSystemInfo)
                _ServerTag(label: 'assetsTagSystemInfo'.tr()),
            ],
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'serversEditServer'.tr(),
            onPressed: onEdit,
            icon: const Icon(Symbols.edit),
          ),
          IconButton(
            tooltip: 'commonDelete'.tr(),
            onPressed: onDelete,
            icon: const Icon(Symbols.delete_outline),
          ),
          if (dragIndex case final index?)
            ReorderableDragStartListener(
              index: index,
              child: const ServerDragHandle(),
            ),
        ],
      ),
    );
  }
}

/// Manages the `Host` entries of the local OpenSSH client config: list,
/// add, edit, and delete blocks in the file itself.
class LocalSshConfigSection extends ConsumerStatefulWidget {
  const LocalSshConfigSection({super.key});

  @override
  ConsumerState<LocalSshConfigSection> createState() =>
      _LocalSshConfigSectionState();
}

class _LocalSshConfigSectionState extends ConsumerState<LocalSshConfigSection> {
  /// Alias order shown between a drop and the file being re-read, so the
  /// rows do not snap back while the write and reload are in flight.
  List<String>? _pendingOrder;

  List<SshConfigHost> _ordered(List<SshConfigHost> items) {
    final pending = _pendingOrder;
    if (pending == null) return items;
    final aliases = [for (final host in items) host.alias];
    if (listEquals(aliases, pending)) {
      _pendingOrder = null;
      return items;
    }
    final rank = {for (final (i, alias) in pending.indexed) alias: i};
    return [...items]..sort(
      (a, b) => (rank[a.alias] ?? pending.length).compareTo(
        rank[b.alias] ?? pending.length,
      ),
    );
  }

  /// Stable per-row key: the alias, disambiguated for repeated `Host` lines.
  String _rowKey(List<SshConfigHost> items, int index) {
    final alias = items[index].alias;
    var repeat = 0;
    for (var i = 0; i < index; i++) {
      if (items[i].alias == alias) repeat++;
    }
    return repeat == 0 ? alias : '$alias#$repeat';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(sshKeyStorageConfigProvider);
    final hosts = ref.watch(sshConfigHostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'assetsSshConfigTitle'.tr(),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'assetsSshConfigDescription'.tr(
                      args: [config.sshConfigPath],
                    ),
                    child: Icon(
                      Symbols.help,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'commonRefresh'.tr(),
              onPressed: () => ref.invalidate(sshConfigHostsProvider),
              icon: const Icon(Symbols.refresh),
            ),
            IconButton(
              tooltip: 'assetsSshConfigSyncServers'.tr(),
              onPressed: () => syncServersToSshConfig(context, ref),
              icon: const Icon(Symbols.sync),
            ),
            IconButton(
              tooltip: 'assetsSshConfigAdd'.tr(),
              onPressed: () => _editHost(context, ref, null),
              icon: const Icon(Symbols.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        hosts.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              Text('assetsSshConfigLoadError'.tr(args: ['$error'])),
          data: (items) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'assetsSshConfigEmpty'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            _headerRow(theme),
                            ReorderableListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                    color: Colors.transparent,
                                    child: child,
                                  ),
                              onReorderItem: (from, to) => _reorderHosts(
                                context,
                                ref,
                                _ordered(items),
                                from,
                                to,
                              ),
                              children: [
                                for (final (index, host) in _ordered(
                                  items,
                                ).indexed)
                                  Column(
                                    key: ValueKey(
                                      _rowKey(_ordered(items), index),
                                    ),
                                    children: [
                                      const Divider(height: 1),
                                      _hostRow(
                                        context,
                                        ref,
                                        theme,
                                        host,
                                        index,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Column flexes shared by the header and every row.
  static const _columnFlexes = [2, 3, 2, 1, 4, 2];

  Widget _headerRow(ThemeData theme) {
    final style = theme.textTheme.labelMedium;
    // OpenSSH option names are left untranslated on purpose.
    final labels = [
      'Host',
      'HostName',
      'User',
      'Port',
      'IdentityFile',
      'portForwardingColumnActions'.tr(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          for (final (index, label) in labels.indexed)
            Expanded(
              flex: _columnFlexes[index],
              child: Center(child: Text(label, style: style)),
            ),
        ],
      ),
    );
  }

  Widget _hostRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    SshConfigHost host,
    int index,
  ) {
    final text = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
    );
    Widget cell(String? value, {bool tooltip = false}) {
      final label = Text(
        value ?? '—',
        style: text,
        overflow: TextOverflow.ellipsis,
      );
      return tooltip && value != null
          ? Tooltip(message: value, child: label)
          : label;
    }

    final cells = <Widget>[
      cell([host.alias, ...host.extraPatterns].join(' '), tooltip: true),
      cell(host.hostName, tooltip: true),
      cell(host.user),
      cell(host.port?.toString()),
      cell(host.identityFile, tooltip: true),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'assetsSshConfigEdit'.tr(),
              onPressed: host.isWildcard
                  ? null
                  : () => _editHost(context, ref, host),
              icon: const Icon(Symbols.edit),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'commonDelete'.tr(),
              onPressed: () => _deleteHost(context, ref, host),
              icon: const Icon(Symbols.delete_outline),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
            ),
            ReorderableDragStartListener(
              index: index,
              child: const ServerDragHandle(),
            ),
          ],
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final (index, widget) in cells.indexed)
            Expanded(
              flex: _columnFlexes[index],
              child: Center(child: widget),
            ),
        ],
      ),
    );
  }

  /// Moves a `Host` block within the config file; same index semantics as
  /// the navigation rail.
  Future<void> _reorderHosts(
    BuildContext context,
    WidgetRef ref,
    List<SshConfigHost> items,
    int from,
    int to,
  ) async {
    if (from == to) return;
    final aliases = [for (final host in items) host.alias];
    aliases.insert(to, aliases.removeAt(from));
    setState(() => _pendingOrder = aliases);
    try {
      await reorderSshConfigHostsFile(
        aliases,
        configPath: ref.read(sshKeyStorageConfigProvider).sshConfigPath,
      );
      ref.invalidate(sshConfigHostsProvider);
    } catch (error) {
      if (mounted) setState(() => _pendingOrder = null);
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _editHost(
    BuildContext context,
    WidgetRef ref,
    SshConfigHost? host,
  ) async {
    final config = ref.read(sshKeyStorageConfigProvider);
    final entry = await showDialog<SshConfigEntry>(
      context: context,
      builder: (_) => _SshConfigHostDialog(host: host),
    );
    if (entry == null) return;
    try {
      final path = await syncSshConfigFile(
        entry,
        configPath: config.sshConfigPath,
      );
      ref.invalidate(sshConfigHostsProvider);
      showStyledSnackBar(
        message: 'assetsSshConfigSaved'.tr(args: [path]),
        icon: Symbols.check_circle,
      );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _deleteHost(
    BuildContext context,
    WidgetRef ref,
    SshConfigHost host,
  ) async {
    final config = ref.read(sshKeyStorageConfigProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('assetsSshConfigDelete'.tr()),
        content: Text('assetsSshConfigDeleteConfirm'.tr(args: [host.alias])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('commonCancel').tr(),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('commonDelete').tr(),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await removeSshConfigHostFile(
        host.alias,
        configPath: config.sshConfigPath,
      );
      ref.invalidate(sshConfigHostsProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }
}

/// Add/edit dialog for one `Host` block. Pops the [SshConfigEntry] to merge.
class _SshConfigHostDialog extends StatefulWidget {
  const _SshConfigHostDialog({this.host});

  final SshConfigHost? host;

  @override
  State<_SshConfigHostDialog> createState() => _SshConfigHostDialogState();
}

class _SshConfigHostDialogState extends State<_SshConfigHostDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _alias = TextEditingController(text: widget.host?.alias ?? '');
  late final _hostName = TextEditingController(
    text: widget.host?.hostName ?? '',
  );
  late final _user = TextEditingController(text: widget.host?.user ?? '');
  late final _port = TextEditingController(text: '${widget.host?.port ?? 22}');
  late final _identityFile = TextEditingController(
    text: widget.host?.identityFile ?? '',
  );

  @override
  void dispose() {
    _alias.dispose();
    _hostName.dispose();
    _user.dispose();
    _port.dispose();
    _identityFile.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final identityFile = _identityFile.text.trim();
    Navigator.pop(
      context,
      SshConfigEntry(
        alias: _alias.text.trim(),
        hostName: _hostName.text.trim(),
        user: _user.text.trim(),
        port: int.parse(_port.text.trim()),
        identityFile: identityFile.isEmpty ? null : identityFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.host != null;
    return AlertDialog(
      title: Text(
        (editing ? 'assetsSshConfigEdit' : 'assetsSshConfigAdd').tr(),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _alias,
                enabled: !editing,
                decoration: InputDecoration(
                  labelText: 'assetsSshConfigAliasLabel'.tr(),
                ),
                validator: (value) {
                  final alias = value?.trim() ?? '';
                  if (alias.isEmpty || RegExp(r'[\s*?!]').hasMatch(alias)) {
                    return 'assetsSshConfigAliasInvalid'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hostName,
                decoration: const InputDecoration(labelText: 'HostName'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'commonRequired'.tr()
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'User'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'commonRequired'.tr()
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _port,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final port = int.tryParse(value?.trim() ?? '');
                  return port == null || port < 1 || port > 65535
                      ? 'commonRequired'.tr()
                      : null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identityFile,
                decoration: InputDecoration(
                  labelText: 'IdentityFile',
                  hintText: 'assetsSshConfigIdentityFileHint'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('commonCancel').tr(),
        ),
        FilledButton(onPressed: _save, child: const Text('commonSave').tr()),
      ],
    );
  }
}

class _ServerTag extends StatelessWidget {
  const _ServerTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.labelSmall);
}

void _showError(BuildContext context, Object error) {
  showStyledSnackBar(message: '$error', icon: Symbols.error);
}
