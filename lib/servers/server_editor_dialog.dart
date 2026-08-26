import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/collapsible_section.dart';
import 'package:conduit/shared/presentation/conduit_dropdown.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'server_repository.dart';
import 'ssh_key_setup_dialog.dart';
import 'ssh_key_setup_service.dart';

/// Opens the server editor to add a server, or to edit [server], and saves
/// the result. Returns the saved server (the same [server] after an edit),
/// or null when the user cancelled or saving failed (a message has been
/// shown).
Future<Server?> showServerEditor(
  BuildContext context,
  WidgetRef ref, {
  Server? server,
}) async {
  final repository = ref.read(serverRepositoryProvider);
  final editing = server != null;
  try {
    final servers = await repository.all();
    final initial = editing ? await loadServerDraft(repository, server) : null;
    if (!context.mounted) return null;
    final draft = await showDialog<ServerDraft>(
      context: context,
      builder: (_) => ServerEditorDialog(
        servers: servers,
        serverId: server?.id,
        initial: initial,
      ),
    );
    if (draft == null) return null;
    if (editing) {
      await repository.update(server, draft);
      return server;
    }
    return await repository.create(draft);
  } catch (error) {
    if (context.mounted) {
      showStyledSnackBar(
        message: '$error',
        title: (editing ? 'serversEditError' : 'serversSaveError').tr(),
        icon: Symbols.error,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return null;
  }
}

/// The editable draft for a saved server: its row plus the vaulted
/// credential and proxy the repository stores beside it.
Future<ServerDraft> loadServerDraft(
  ServerRepository repository,
  Server server,
) async => ServerDraft(
  name: server.name,
  host: server.host,
  port: server.port,
  username: server.username,
  credential: server.credentialId == null
      ? null
      : await repository.credentialFor(server),
  credentialId: server.credentialId,
  collectStats: server.collectStats,
  collectSystemInfo: server.collectSystemInfo,
  proxy: await repository.proxyFor(server),
  jumpHostServerId: server.jumpHostServerId,
  environment: decodeEnvironmentMap(server.environment),
  tags: decodeStringList(server.tags),
);

/// Sentinel entry value for "no jump host" in the editor's picker.
const _noJumpHost = -1;

class ServerEditorDialog extends ConsumerStatefulWidget {
  const ServerEditorDialog({
    super.key,
    this.servers = const [],
    this.serverId,
    this.initial,
  });

  final ServerDraft? initial;
  final int? serverId;
  final List<Server> servers;
  @override
  ConsumerState<ServerEditorDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends ConsumerState<ServerEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _host = TextEditingController();
  late final _port = TextEditingController(text: 'serverDefaultPort'.tr());
  final _user = TextEditingController();
  // Password and private key keep separate controllers: sharing one made
  // switching the credential type carry the password over into the key
  // field, which was then saved and later failed to parse as a PEM.
  final _password = TextEditingController();
  var _showPassword = false;
  final _privateKey = TextEditingController();
  final _passphrase = TextEditingController();
  CredentialType _type = CredentialType.password;

  /// True while the user pastes a private key by hand; otherwise a set key is
  /// shown masked.
  bool _pastingKey = false;

  /// On-disk path of the current private key, once generated or exported in
  /// this editing session, so "sync to ssh config" can reference it.
  String? _localPrivateKeyPath;
  bool _collectStats = true;
  bool _collectSystemInfo = true;

  // Per-server proxy configuration.
  ServerProxyType _proxyType = ServerProxyType.none;
  final _proxyHost = TextEditingController();
  late final _proxyPort = TextEditingController(
    text: 'serverDefaultProxyPort'.tr(),
  );
  final _proxyUsername = TextEditingController();
  final _proxyPassword = TextEditingController();
  int? _jumpHostServerId;

  // Per-server environment variables and tags.
  final _envRows =
      <({TextEditingController name, TextEditingController value})>[];
  final _tags = <String>[];
  final _tagInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _name.text = initial.name;
    _host.text = initial.host;
    _port.text = initial.port.toString();
    _user.text = initial.username;
    final credential = initial.credential;
    if (credential != null) {
      _type = credential.type;
      _password.text = credential.password ?? '';
      // A stored key that is not a PEM block cannot be used; show the field
      // empty rather than a masked card claiming a key is set.
      final storedKey = credential.privateKey ?? '';
      _privateKey.text = storedKey.trimLeft().startsWith('-----BEGIN')
          ? storedKey
          : '';
      _passphrase.text = credential.keyPassphrase ?? '';
    }
    _jumpHostServerId = initial.jumpHostServerId;
    _collectStats = initial.collectStats;
    _collectSystemInfo = initial.collectSystemInfo;
    final proxy = initial.proxy;
    if (proxy != null) {
      _proxyType = proxy.type;
      _proxyHost.text = proxy.host;
      _proxyPort.text = proxy.port.toString();
      _proxyUsername.text = proxy.username ?? '';
      // The stored password is not decrypted into the form; leaving the field
      // blank keeps the existing password when saving.
    }
    _tags.addAll(initial.tags);
    for (final entry in initial.environment.entries) {
      _envRows.add((
        name: TextEditingController(text: entry.key),
        value: TextEditingController(text: entry.value),
      ));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _password,
      _privateKey,
      _passphrase,
      _proxyHost,
      _proxyPort,
      _proxyUsername,
      _proxyPassword,
      _tagInput,
    ]) {
      controller.dispose();
    }
    for (final row in _envRows) {
      row.name.dispose();
      row.value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.pickFiles(withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes != null) {
      setState(() {
        _privateKey.text = String.fromCharCodes(bytes);
        _pastingKey = false;
      });
    }
  }

  void _addEnvRow() {
    setState(() {
      _envRows.add((
        name: TextEditingController(),
        value: TextEditingController(),
      ));
    });
  }

  void _removeEnvRow(
    ({TextEditingController name, TextEditingController value}) row,
  ) {
    setState(() => _envRows.remove(row));
    row.name.dispose();
    row.value.dispose();
  }

  void _addTag() {
    final candidates = _tagInput.text
        .split(RegExp(r'[,;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return;
    setState(() {
      for (final tag in candidates) {
        if (!_tags.contains(tag)) _tags.add(tag);
      }
      _tagInput.clear();
    });
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'serverPortRequired'.tr() : null;

  /// Rejects anything that is not a PEM block before it reaches the vault:
  /// a bad key otherwise only surfaces at connect time as a FormatException.
  String? _privateKeyPem(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'serverPortRequired'.tr();
    return text.startsWith('-----BEGIN')
        ? null
        : 'serverPrivateKeyInvalid'.tr();
  }

  String? _validPort(String? value) {
    final port = int.tryParse(value ?? '');
    return port != null && port > 0 && port < 65536
        ? null
        : 'serverPortInvalid'.tr();
  }

  String _jumpHostSummary() {
    if (_jumpHostServerId == null) return 'serverJumpHostNone'.tr();
    final names = <String>[];
    final visited = <int>{};
    var current = _jumpHostServerId;
    while (current != null && visited.add(current)) {
      final host = widget.servers
          .where((server) => server.id == current)
          .firstOrNull;
      if (host == null) {
        names.add('serverJumpHostMissing'.tr());
        break;
      }
      names.add(host.name);
      current = host.jumpHostServerId;
    }
    return names.reversed.join(' → ');
  }

  ServerEndpoint? _endpoint() {
    final host = _host.text.trim();
    final username = _user.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (host.isEmpty || username.isEmpty || port == null) return null;
    final name = _name.text.trim();
    return (
      name: name.isEmpty ? host : name,
      host: host,
      port: port,
      username: username,
    );
  }

  /// Generates a key pair and installs it on the server described by the
  /// form, then switches the form to private-key authentication.
  Future<void> _setUpKeyPair() async {
    final endpoint = _endpoint();
    if (endpoint == null) {
      _showError('sshKeyDialogTitle', 'sshKeyNeedHost'.tr(), Symbols.key);
      return;
    }
    final SshKeySetupResult? result;
    try {
      result = await SshKeySetupService(ref).setUpKeyPair(
        context,
        endpoint: endpoint,
        serverId: widget.serverId,
        jumpHostServerId: _jumpHostServerId,
        proxied: _proxyType != ServerProxyType.none,
        initialPassword: _password.text.isEmpty ? null : _password.text,
      );
    } on SshKeySetupException catch (error) {
      if (mounted) _showError('sshKeyDialogTitle', '$error', Symbols.key);
      return;
    }
    if (result == null || !mounted) return;
    final keyPair = result.keyPair;
    final passphrase = result.passphrase ?? '';
    setState(() {
      _type = CredentialType.privateKey;
      _privateKey.text = keyPair.privateKey;
      _passphrase.text = passphrase;
      _pastingKey = false;
      _localPrivateKeyPath = keyPair.privateKeyPath;
    });
    showStyledSnackBar(
      message: 'sshKeyInstalled'.tr(args: [keyPair.privateKeyPath]),
      title: 'sshKeyDialogTitle'.tr(),
      icon: Symbols.check_circle,
    );
  }

  /// Writes or updates this server's `Host` entry in the local ssh config.
  Future<void> _syncToSshConfig() async {
    final endpoint = _endpoint();
    if (endpoint == null) {
      _showError(
        'sshConfigSyncEntry',
        'sshKeyNeedHost'.tr(),
        Symbols.description,
      );
      return;
    }
    try {
      final (alias, written) = await SshKeySetupService(ref).syncToSshConfig(
        endpoint: endpoint,
        privateKey: _type == CredentialType.privateKey
            ? _privateKey.text
            : null,
        localPrivateKeyPath: _localPrivateKeyPath,
        onKeyExported: (path) => _localPrivateKeyPath = path,
      );
      if (!mounted) return;
      showStyledSnackBar(
        message: 'sshKeyConfigSynced'.tr(args: [alias, written, alias]),
        title: 'sshConfigSyncEntry'.tr(),
        icon: Symbols.check_circle,
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        'sshConfigSyncEntry',
        'sshKeyConfigSyncFailed'.tr(args: ['$error']),
        Symbols.warning,
      );
    }
  }

  void _showError(String titleKey, String message, IconData icon) {
    showStyledSnackBar(
      message: message,
      title: titleKey.tr(),
      icon: icon,
      accentColor: Theme.of(context).colorScheme.error,
    );
  }

  bool _hasJumpHostCycle() {
    if (_jumpHostServerId == null) return false;
    var current = _jumpHostServerId;
    final visited = <int>{};
    while (current != null) {
      if (!visited.add(current) || current == widget.serverId) return true;
      current = widget.servers
          .where((server) => server.id == current)
          .firstOrNull
          ?.jumpHostServerId;
    }
    return false;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_hasJumpHostCycle()) {
      showStyledSnackBar(
        message: 'serverJumpHostCycle'.tr(),
        title: 'serverJumpHostLabel'.tr(),
        icon: Symbols.account_tree,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    // The masked key card has no form field, so the PEM check runs here too.
    if (_type == CredentialType.privateKey &&
        _privateKeyPem(_privateKey.text) != null) {
      showStyledSnackBar(
        message: 'serverPrivateKeyInvalid'.tr(),
        title: 'serverAuthPrivateKey'.tr(),
        icon: Symbols.key_off,
        accentColor: Theme.of(context).colorScheme.error,
      );
      return;
    }
    // The credential is part of the server itself: always saved from the
    // inline fields, never picked from a shared pool.
    final credential = _type == CredentialType.password
        ? ServerCredential.password(_password.text)
        : ServerCredential.privateKey(
            privateKey: _privateKey.text,
            keyPassphrase: _passphrase.text.isEmpty ? null : _passphrase.text,
          );
    Navigator.pop(
      context,
      ServerDraft(
        name: _name.text,
        host: _host.text,
        port: int.parse(_port.text),
        jumpHostServerId: _jumpHostServerId,
        username: _user.text,
        credential: credential,
        credentialName: _name.text,
        collectStats: _collectStats,
        collectSystemInfo: _collectSystemInfo,
        proxy: _proxyType == ServerProxyType.none
            ? null
            : ServerProxy(
                type: _proxyType,
                host: _proxyHost.text.trim(),
                port: int.parse(_proxyPort.text),
                username: _proxyUsername.text.trim().isEmpty
                    ? null
                    : _proxyUsername.text.trim(),
                password: _proxyPassword.text.isEmpty
                    ? null
                    : _proxyPassword.text,
              ),
        environment: {
          for (final row in _envRows)
            if (row.name.text.trim().isNotEmpty)
              row.name.text.trim(): row.value.text,
        },
        tags: List.of(_tags),
        connectionType: ServerConnectionType.ssh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A floating dialog rather than a bottom sheet: the form hugs its
    // content up to a maximum height and scrolls inside.
    return Dialog(
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
                      (widget.serverId == null
                              ? 'serversAddSheetTitle'
                              : 'serversEditServer')
                          .tr(),
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
            Flexible(
              child: Form(
                key: _form,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'serverNameLabel'.tr(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _host,
                            decoration: InputDecoration(
                              labelText: 'serverHostLabel'.tr(),
                            ),
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: _port,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'serverPortLabel'.tr(),
                            ),
                            validator: _validPort,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _user,
                      decoration: InputDecoration(
                        labelText: 'serverUsernameLabel'.tr(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    ConduitCollapsibleSection(
                      initiallyExpanded: _jumpHostServerId != null,
                      title: Text('serverJumpHostLabel'.tr()),
                      subtitle: Text(_jumpHostSummary()),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ConduitDropdown<int>(
                            value: _jumpHostServerId ?? _noJumpHost,
                            label: 'serverJumpHostLabel'.tr(),
                            helperText: 'serverJumpHostHint'.tr(),
                            entries: [
                              DropdownMenuEntry(
                                value: _noJumpHost,
                                label: 'serverJumpHostNone'.tr(),
                              ),
                              if (_jumpHostServerId != null &&
                                  !widget.servers.any(
                                    (server) => server.id == _jumpHostServerId,
                                  ))
                                DropdownMenuEntry(
                                  value: _jumpHostServerId!,
                                  label: 'serverJumpHostMissing'.tr(),
                                ),
                              for (final candidate in widget.servers)
                                if (candidate.id != widget.serverId)
                                  DropdownMenuEntry(
                                    value: candidate.id,
                                    label: candidate.name,
                                  ),
                            ],
                            onChanged: (value) => setState(
                              () => _jumpHostServerId =
                                  value == null || value == _noJumpHost
                                  ? null
                                  : value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      title: Text('serverProxyLabel'.tr()),
                      subtitle: Text(switch (_proxyType) {
                        ServerProxyType.none => 'serverProxyNone'.tr(),
                        ServerProxyType.http => 'serverProxyHttp'.tr(),
                        ServerProxyType.socks5 => 'serverProxySocks5'.tr(),
                      }),
                      children: [
                        SegmentedButton<ServerProxyType>(
                          segments: [
                            ButtonSegment(
                              value: ServerProxyType.none,
                              label: Text('serverProxyNone'.tr()),
                            ),
                            ButtonSegment(
                              value: ServerProxyType.http,
                              label: Text('serverProxyHttp'.tr()),
                            ),
                            ButtonSegment(
                              value: ServerProxyType.socks5,
                              label: Text('serverProxySocks5'.tr()),
                            ),
                          ],
                          selected: {_proxyType},
                          onSelectionChanged: (value) =>
                              setState(() => _proxyType = value.first),
                        ),
                        if (_proxyType != ServerProxyType.none) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _proxyHost,
                                  decoration: InputDecoration(
                                    labelText: 'serverProxyHostLabel'.tr(),
                                  ),
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  controller: _proxyPort,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'serverProxyPortLabel'.tr(),
                                  ),
                                  validator: _validPort,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _proxyUsername,
                            decoration: InputDecoration(
                              labelText: 'serverProxyUsernameLabel'.tr(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _proxyPassword,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'serverProxyPasswordLabel'.tr(),
                              helperText: widget.initial?.proxy != null
                                  ? 'serverProxyPasswordKeepHint'.tr()
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<CredentialType>(
                      segments: [
                        ButtonSegment(
                          value: CredentialType.password,
                          label: Text('serverAuthPassword'.tr()),
                        ),
                        ButtonSegment(
                          value: CredentialType.privateKey,
                          label: Text('serverAuthPrivateKey'.tr()),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (value) =>
                          setState(() => _type = value.first),
                    ),
                    const SizedBox(height: 12),
                    if (_type == CredentialType.password)
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          labelText: 'serverPasswordLabel'.tr(),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Symbols.visibility_off
                                  : Symbols.visibility,
                            ),
                          ),
                        ),
                        validator: _required,
                      )
                    else ...[
                      // A stored or generated key is never echoed back: only
                      // a masked card with replace actions. The editable text
                      // field appears when no key is set or the user opts to
                      // paste one.
                      if (_privateKey.text.isNotEmpty && !_pastingKey)
                        _PrivateKeyCard(
                          onPickFile: _pickKey,
                          onPaste: () => setState(() {
                            _privateKey.clear();
                            _pastingKey = true;
                          }),
                        )
                      else
                        TextFormField(
                          controller: _privateKey,
                          minLines: 4,
                          maxLines: 8,
                          validator: _privateKeyPem,
                          decoration: InputDecoration(
                            labelText: 'serverPrivateKeyLabel'.tr(),
                            suffixIcon: IconButton(
                              onPressed: _pickKey,
                              icon: const Icon(Symbols.upload_file),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passphrase,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'serverKeyPassphraseLabel'.tr(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Both actions share the row so their outer edges line up
                    // with the fields and the private key card above.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _setUpKeyPair,
                            icon: const Icon(Symbols.key, size: 18),
                            label: Text('sshKeyGenerateEntry'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _syncToSshConfig,
                            icon: const Icon(Symbols.description, size: 18),
                            label: Text('sshConfigSyncEntry'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      title: Text('serverEnvironmentLabel'.tr()),
                      subtitle: Text('serverEnvironmentHint'.tr()),
                      children: [
                        for (final row in _envRows) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: row.name,
                                  decoration: InputDecoration(
                                    labelText: 'serverEnvNameLabel'.tr(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: row.value,
                                  decoration: InputDecoration(
                                    labelText: 'serverEnvValueLabel'.tr(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'serverRemoveVariable'.tr(),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _removeEnvRow(row),
                                icon: const Icon(Symbols.close, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addEnvRow,
                            icon: const Icon(Symbols.add, size: 18),
                            label: Text('serverAddEnvVar'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConduitCollapsibleSection(
                      initiallyExpanded: false,
                      title: Text('serverTagsLabel'.tr()),
                      subtitle: Text('serverTagsAddHint'.tr()),
                      children: [
                        if (_tags.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in _tags)
                                  InputChip(
                                    label: Text(tag),
                                    onDeleted: () =>
                                        setState(() => _tags.remove(tag)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _tagInput,
                                decoration: InputDecoration(
                                  labelText: 'serverTagAdd'.tr(),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _addTag(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _addTag,
                              icon: const Icon(Symbols.add, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('serverCollectStats'.tr()),
                      subtitle: Text('serverCollectStatsHint'.tr()),
                      value: _collectStats,
                      onChanged: (value) =>
                          setState(() => _collectStats = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('serverDiscoverSystemInfo'.tr()),
                      subtitle: Text('serverDiscoverSystemInfoHint'.tr()),
                      value: _collectSystemInfo,
                      onChanged: (value) =>
                          setState(() => _collectSystemInfo = value),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('commonCancel'.tr()),
                        ),
                        FilledButton(
                          onPressed: _save,
                          child: Text('serverSaveAndConnect'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Masked stand-in for a private key that is already set. The key material
/// itself is never rendered; the user can replace it from a file or paste a
/// new one.
class _PrivateKeyCard extends StatelessWidget {
  const _PrivateKeyCard({required this.onPickFile, required this.onPaste});

  final VoidCallback onPickFile;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.lock, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'serverPrivateKeySet'.tr(),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '••••••••••••••••••••••••',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: onPickFile,
                  icon: const Icon(Symbols.upload_file, size: 18),
                  label: Text('serverPrivateKeyReplaceFile'.tr()),
                ),
                TextButton.icon(
                  onPressed: onPaste,
                  icon: const Icon(Symbols.content_paste, size: 18),
                  label: Text('serverPrivateKeyPaste'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
