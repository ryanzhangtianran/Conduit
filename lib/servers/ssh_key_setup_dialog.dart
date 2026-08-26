import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:dartssh2/dartssh2.dart';

import 'server_connection_actions.dart';
import 'server_providers.dart';
import 'ssh_key_preferences.dart';
import 'ssh_key_service.dart';

/// Outcome of a successful key setup: the generated pair plus the passphrase
/// the user chose for it, so the editor can switch to key authentication.
class SshKeySetupResult {
  const SshKeySetupResult({required this.keyPair, this.passphrase});

  final GeneratedSshKeyPair keyPair;
  final String? passphrase;
}

/// Generates a key pair with the system `ssh-keygen` and installs the public
/// half on the server using [initialPassword] (editable in the dialog).
Future<SshKeySetupResult?> showSshKeySetupDialog(
  BuildContext context, {
  required String serverName,
  required String host,
  required int port,
  required String username,
  String? initialPassword,
  String? knownHostKeyFingerprint,
  SSHClient? sessionClient,
  Future<SSHSocket> Function()? dialSocket,
}) {
  return showDialog<SshKeySetupResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SshKeySetupDialog(
      serverName: serverName,
      host: host,
      port: port,
      username: username,
      initialPassword: initialPassword ?? '',
      knownHostKeyFingerprint: knownHostKeyFingerprint,
      sessionClient: sessionClient,
      dialSocket: dialSocket,
    ),
  );
}

class _SshKeySetupDialog extends ConsumerStatefulWidget {
  const _SshKeySetupDialog({
    required this.serverName,
    required this.host,
    required this.port,
    required this.username,
    required this.initialPassword,
    this.knownHostKeyFingerprint,
    this.sessionClient,
    this.dialSocket,
  });

  final String serverName;
  final String host;
  final int port;
  final String username;
  final String initialPassword;
  final String? knownHostKeyFingerprint;

  /// Live SSH session for this server, reused for the install step so
  /// jump-host and proxied servers work; null falls back to a direct dial.
  final SSHClient? sessionClient;

  /// Opens the transport for the one-off install connection; used for
  /// unsaved jump-host targets, where the socket is a direct-tcpip channel
  /// through the connected jump host.
  final Future<SSHSocket> Function()? dialSocket;

  @override
  ConsumerState<_SshKeySetupDialog> createState() => _SshKeySetupDialogState();
}

class _SshKeySetupDialogState extends ConsumerState<_SshKeySetupDialog> {
  final _form = GlobalKey<FormState>();
  late final _password = TextEditingController(text: widget.initialPassword);
  final _passphrase = TextEditingController();
  late final _comment = TextEditingController(
    text: '${widget.username}@${widget.host}',
  );
  late SshKeyType _type = ref.read(sshKeyStorageConfigProvider).defaultKeyType;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _passphrase.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final config = ref.read(sshKeyStorageConfigProvider);
    final service = ref.read(sshKeyServiceProvider);
    final passphrase = _passphrase.text.isEmpty ? null : _passphrase.text;
    try {
      final keyPair = await service.generate(
        type: _type,
        fileStem: SshKeyService.fileStemFor(widget.serverName, _type),
        comment: _comment.text.trim(),
        passphrase: passphrase,
        config: config,
      );
      if (!mounted) return;
      await service.installPublicKey(
        host: widget.host,
        port: widget.port,
        username: widget.username,
        password: _password.text,
        publicKey: keyPair.publicKey,
        fileName: SshKeyService.fileStemFor(widget.serverName, _type),
        config: config,
        knownHostKeyFingerprint: widget.knownHostKeyFingerprint,
        approve: (prompt) => approveHostKeyPrompt(context, prompt),
        session: widget.sessionClient,
        dial: widget.dialSocket,
        replacesPublicKey: keyPair.previousPublicKey,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        SshKeySetupResult(keyPair: keyPair, passphrase: passphrase),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(sshKeyStorageConfigProvider);
    final stem = SshKeyService.fileStemFor(widget.serverName, _type);
    return AlertDialog(
      title: Text('sshKeyDialogTitle'.tr()),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'sshKeyDialogHint'.tr(
                    args: ['${widget.username}@${widget.host}:${widget.port}'],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SshKeyType>(
                  initialValue: _type,
                  decoration: InputDecoration(labelText: 'sshKeyType'.tr()),
                  items: [
                    for (final type in SshKeyType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _type = value);
                        },
                ),
                const SizedBox(height: 12),
                if (widget.sessionClient != null)
                  Text(
                    'sshKeySessionReused'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: 'sshKeyServerPassword'.tr(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'serverPortRequired'.tr()
                        : null,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passphrase,
                  obscureText: true,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: 'sshKeyPassphrase'.tr(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _comment,
                  enabled: !_busy,
                  decoration: InputDecoration(labelText: 'sshKeyComment'.tr()),
                ),
                const SizedBox(height: 16),
                _PathSummary(
                  entries: [
                    (
                      'settingsSshKeyLocalPrivateDir',
                      '${config.localPrivateKeyDirectory}/$stem',
                    ),
                    (
                      'settingsSshKeyLocalPublicDir',
                      '${config.localPublicKeyDirectory}/$stem.pub',
                    ),
                    (
                      'settingsSshKeyRemoteDir',
                      '${config.remoteKeyDirectory}/$stem.pub',
                    ),
                    (
                      'settingsSshKeyRemoteAuthorizedKeys',
                      config.remoteAuthorizedKeysPath,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'sshKeyPathsHint'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _run,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Symbols.key),
          label: Text(
            (_busy ? 'sshKeyGenerating' : 'sshKeyGenerateAction').tr(),
          ),
        ),
      ],
    );
  }
}

class _PathSummary extends StatelessWidget {
  const _PathSummary({required this.entries});

  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (labelKey, value) in entries) ...[
              Text(
                labelKey.tr(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SelectableText(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'IBM Plex Mono',
                ),
              ),
              if (labelKey != entries.last.$1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
