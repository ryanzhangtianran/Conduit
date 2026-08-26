import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/github/github_section.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';

import 'server_models.dart';
import 'server_providers.dart';
import 'servers_page.dart';
import 'ssh_config_bulk.dart';
import 'ssh_config_sync.dart';

/// Saved server connections as a top-level sidebar page.
@RoutePage()
class ConnectionsPage extends ConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConduitAppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: const [
          ServerAssetsSection(),
          SizedBox(height: 32),
          LocalSshConfigSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'connections-create-fab',
        onPressed: () => _addServer(context, ref),
        icon: const Icon(Symbols.add),
        label: Text('serversAddServer'.tr()),
      ),
    );
  }
}

/// GitHub connections, pinned repositories and workflow runs as a top-level
/// sidebar page. Sign-in and pin controls live inside the section, so no FAB.
@RoutePage()
class GithubPage extends StatelessWidget {
  const GithubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConduitAppScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: const [GitHubSection(showHeader: false)],
      ),
    );
  }
}

Future<void> _addServer(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(serverRepositoryProvider);
  final servers = await repository.all();
  if (!context.mounted) return;
  final draft = await showDialog<ServerDraft>(
    context: context,
    builder: (_) => ServerEditorDialog(servers: servers),
  );
  if (draft == null) return;
  try {
    await ref.read(serverRepositoryProvider).create(draft);
  } catch (error) {
    if (context.mounted) _showError(context, error);
  }
}

class ServerAssetsSection extends ConsumerWidget {
  const ServerAssetsSection({super.key});

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
              : Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _ServerAssetRow(
                        server: items[index],
                        onEdit: () => _edit(context, ref, items[index]),
                        onDelete: () => _delete(context, ref, items[index]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Server server) async {
    try {
      final repository = ref.read(serverRepositoryProvider);
      final credential = server.credentialId == null
          ? null
          : await repository.credentialFor(server);
      final proxy = await repository.proxyFor(server);
      final servers = await repository.all();
      if (!context.mounted) return;
      final draft = await showDialog<ServerDraft>(
        context: context,
        builder: (_) => ServerEditorDialog(
          servers: servers,
          serverId: server.id,
          initial: ServerDraft(
            name: server.name,
            host: server.host,
            port: server.port,
            username: server.username,
            credential: credential,
            credentialId: server.credentialId,
            collectStats: server.collectStats,
            collectSystemInfo: server.collectSystemInfo,
            proxy: proxy,
            jumpHostServerId: server.jumpHostServerId,
            environment: decodeEnvironmentMap(server.environment),
            tags: decodeStringList(server.tags),
            connectionType:
                ServerConnectionType.values
                    .asNameMap()[server.connectionType] ??
                ServerConnectionType.ssh,
          ),
        ),
      );
      if (draft != null) await repository.update(server, draft);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
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

class _ServerAssetRow extends ConsumerWidget {
  const _ServerAssetRow({
    required this.server,
    required this.onEdit,
    required this.onDelete,
  });

  final Server server;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideAddresses = ref.watch(hideServerAddressesProvider);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const Icon(Symbols.dns),
      title: Text(server.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            hideAddresses
                ? server.username
                : '${server.host} · ${server.username} · ${server.port}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _AssetTag(label: 'SSH'),
              if (server.collectStats)
                _AssetTag(label: 'assetsTagMetrics'.tr()),
              if (server.collectSystemInfo)
                _AssetTag(label: 'assetsTagSystemInfo'.tr()),
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
        ],
      ),
    );
  }
}

/// Manages the `Host` entries of the local OpenSSH client config: list,
/// add, edit, and delete blocks in the file itself.
class LocalSshConfigSection extends ConsumerWidget {
  const LocalSshConfigSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(sshKeyStorageConfigProvider);
    final hosts = ref.watch(sshConfigHostsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'assetsSshConfigTitle'.tr(),
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'commonRefresh'.tr(),
              onPressed: () => ref.invalidate(sshConfigHostsProvider),
              icon: const Icon(Symbols.refresh),
            ),
            IconButton(
              tooltip: 'assetsSshConfigSyncServers'.tr(),
              onPressed: () => _syncServers(context, ref),
              icon: const Icon(Symbols.sync),
            ),
            IconButton(
              tooltip: 'assetsSshConfigAdd'.tr(),
              onPressed: () => _editHost(context, ref, null),
              icon: const Icon(Symbols.add),
            ),
          ],
        ),
        Text(
          'assetsSshConfigDescription'.tr(args: [config.sshConfigPath]),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        hosts.when(
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
                            for (final host in items) ...[
                              const Divider(height: 1),
                              _hostRow(context, ref, theme, host),
                            ],
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

  /// Writes every saved SSH server into the config.
  Future<void> _syncServers(BuildContext context, WidgetRef ref) async {
    try {
      final (count, path) = await writeServersToSshConfig(
        repository: ref.read(serverRepositoryProvider),
        keyService: ref.read(sshKeyServiceProvider),
        config: ref.read(sshKeyStorageConfigProvider),
      );
      ref.invalidate(sshConfigHostsProvider);
      showStyledSnackBar(
        message: 'assetsSshConfigSyncDone'.tr(args: ['$count', path]),
        icon: Symbols.check_circle,
      );
    } catch (error) {
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

class _AssetTag extends StatelessWidget {
  const _AssetTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.labelSmall);
}

void _showError(BuildContext context, Object error) {
  showStyledSnackBar(message: '$error', icon: Symbols.error);
}
