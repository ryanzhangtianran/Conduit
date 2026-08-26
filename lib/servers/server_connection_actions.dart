import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'server_repository.dart';
import 'ssh_connection_manager.dart';
import 'terminal_tabs_provider.dart';

/// Explains an authentication failure in terms of the credential that was
/// actually offered. [serverAuthMethods] is the `methodsLeft` list from the
/// server's userauth failure, so it names what the server still accepts —
/// not what Conduit tried. The connection manager is handed this function so
/// the transport layer carries no user-facing prose.
String sshAuthFailureMessage({
  required CredentialType credentialType,
  String? serverAuthMethods,
}) {
  final usedKey = credentialType == CredentialType.privateKey;
  final methods = (serverAuthMethods ?? '')
      .split(',')
      .map((method) => method.trim())
      .where((method) => method.isNotEmpty)
      .toList();
  final buffer = StringBuffer(
    usedKey
        ? 'Conduit offered the private key and the server rejected it.'
        : 'Conduit offered the password and the server rejected it.',
  );
  if (methods.isNotEmpty) {
    buffer.write(' The server accepts: ${methods.join(', ')}.');
  }
  if (usedKey && methods.contains('publickey')) {
    buffer.write(
      ' Check that the matching public key is in authorized_keys for this '
      'user and that the home and .ssh directories are not group-writable.',
    );
  } else if (usedKey && methods.isNotEmpty) {
    buffer.write(' This server does not offer public key authentication.');
  } else if (!usedKey && methods.contains('publickey')) {
    buffer.write(
      ' This server also accepts public keys; switch the credential to a '
      'private key if password logins are restricted.',
    );
  }
  return buffer.toString();
}

Future<bool> connectForStatistics(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  VoidCallback? onHostKeyPrompt,
}) async {
  try {
    final repository = ref.read(serverRepositoryProvider);
    final servers = await repository.all();
    if (!context.mounted) return false;
    await _connectJumpHosts(
      context,
      ref,
      server,
      servers,
      onHostKeyPrompt: onHostKeyPrompt,
    );
    if (!context.mounted) return false;
    await _connectSingleServer(
      context,
      ref,
      server,
      onHostKeyPrompt: onHostKeyPrompt,
    );
  } catch (error) {
    if (context.mounted) {
      showStyledSnackBar(
        message: error.toString(),
        title: 'serverCannotConnect'.tr(),
        icon: Symbols.link_off,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return false;
  }

  return true;
}

/// Brings up every jump host on the way to [server], prompting the user for
/// unknown host keys. The startup path walks the same chain through
/// [SshConnectionManager.connectJumpHosts] but rejects unknown keys silently.
Future<void> _connectJumpHosts(
  BuildContext context,
  WidgetRef ref,
  Server server,
  List<Server> servers, {
  VoidCallback? onHostKeyPrompt,
}) => ref
    .read(connectionManagerProvider)
    .connectJumpHosts(
      server,
      servers,
      connectHop: (hop) {
        if (!context.mounted) {
          throw StateError('The connection request was closed.');
        }
        return _connectSingleServer(
          context,
          ref,
          hop,
          onHostKeyPrompt: onHostKeyPrompt,
        );
      },
    );

/// Opens [server]'s statistics session with the vault's credential and proxy
/// and records the connection. Shared by the interactive and startup paths,
/// which differ only in how [approve] answers a host-key prompt.
Future<void> connectSavedServer(
  ServerRepository repository,
  SshConnectionManager manager,
  Server server,
  HostKeyApproval approve,
) async {
  final credential = await repository.credentialFor(server);
  final proxy = await repository.proxyFor(server);
  await manager.connect(
    server,
    credential,
    approve,
    knownHostKeyFingerprint: server.hostKeyFingerprint,
    proxy: proxy,
  );
  await repository.markConnected(server.id);
}

Future<void> _connectSingleServer(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  VoidCallback? onHostKeyPrompt,
}) async {
  HostKeyPrompt? approvedHostKey;
  final repository = ref.read(serverRepositoryProvider);
  if (!context.mounted) throw StateError('The connection request was closed.');
  await connectSavedServer(
    repository,
    ref.read(connectionManagerProvider),
    server,
    (prompt) async {
      onHostKeyPrompt?.call();
      if (!context.mounted) return false;
      final approved = await _approveHostKey(context, prompt);
      if (approved) approvedHostKey = prompt;
      return approved;
    },
  );
  if (approvedHostKey != null) {
    await repository.rememberHostKey(server.id, approvedHostKey!);
  }
}

Future<bool> shouldReconnectAndRetry(
  BuildContext context,
  Object error,
  Server server,
) {
  if (error is! ServerConnectionRequiredException) {
    return Future.value(false);
  }
  return showConduitReconnectAlert(server.name);
}

Future<bool> openTerminalSession(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  String? initialDirectory,
  List<String>? initialScripts,
}) async {
  HostKeyPrompt? approvedHostKey;
  final loading = showConduitLoadingModal(
    context,
    message: 'serverOpeningTerminal'.tr(args: [server.name]),
  );
  try {
    final repository = ref.read(serverRepositoryProvider);
    final servers = await repository.all();
    if (!context.mounted) return false;
    await _connectJumpHosts(
      context,
      ref,
      server,
      servers,
      onHostKeyPrompt: loading.dismiss,
    );
    if (!context.mounted) return false;
    final credential = await repository.credentialFor(server);
    final proxy = await repository.proxyFor(server);
    if (!context.mounted) return false;
    await ref
        .read(terminalTabsProvider.notifier)
        .open(
          server,
          credential,
          (prompt) async {
            // A host-key prompt must remain interactive, so release the blocking
            // loading overlay before presenting it.
            loading.dismiss();
            if (!context.mounted) return false;
            final approved = await _approveHostKey(context, prompt);
            if (approved) approvedHostKey = prompt;
            return approved;
          },
          knownHostKeyFingerprint: server.hostKeyFingerprint,
          initialDirectory: initialDirectory,
          initialScripts: initialScripts,
          proxy: proxy,
        );
    if (approvedHostKey != null) {
      await ref
          .read(serverRepositoryProvider)
          .rememberHostKey(server.id, approvedHostKey!);
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showStyledSnackBar(
        message: error.toString(),
        title: 'serverCannotOpenTerminal'.tr(),
        icon: Symbols.terminal,
        accentColor: Theme.of(context).colorScheme.error,
      );
    }
    return false;
  } finally {
    loading.dismiss();
  }
}

/// Shows the host-key verification dialog; shared with one-off sessions such
/// as public-key installation.
Future<bool> approveHostKeyPrompt(BuildContext context, HostKeyPrompt prompt) =>
    _approveHostKey(context, prompt);

Future<bool> _approveHostKey(BuildContext context, HostKeyPrompt prompt) async {
  return await showConduitOverlayDialog<bool>(
        barrierDismissible: false,
        builder: (context, close) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Symbols.verified_user,
                    color: Theme.of(context).colorScheme.primary,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'serverVerifyHostKey'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prompt.replacesExisting
                        ? 'serverHostKeyChanged'.tr()
                        : 'serverHostKeyNew'.tr(),
                  ),
                  const SizedBox(height: 16),
                  SelectableText('${prompt.algorithm}\n${prompt.fingerprint}'),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => close(false),
                        child: const Text('serverReject').tr(),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => close(true),
                        child: const Text('serverApprove').tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ) ??
      false;
}

/// Opens a file-management tab for [server], connecting first when no SSH
/// client is available. Shared by the workspace home grid, the terminal
/// context menu and the command palette.
Future<void> openFileManagementFor(
  BuildContext context,
  WidgetRef ref,
  Server server, {
  String? initialPath,
}) async {
  final manager = ref.read(connectionManagerProvider);
  if (manager.clientFor(server.id) == null &&
      !await connectForStatistics(context, ref, server)) {
    return;
  }
  ref
      .read(terminalTabsProvider.notifier)
      .openFileManagement(server, initialPath: initialPath);
}
