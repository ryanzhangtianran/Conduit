import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/routing/app_router.dart';
import 'package:conduit/shared/presentation/task_progress_model.dart';
import 'file_management_dialogs.dart';
import 'file_system_backend.dart';
import 'file_transfer_queue.dart';
import 'server_models.dart';
import 'server_providers.dart';

/// The app-wide transfer queue. Not auto-disposed: transfers keep running
/// after the tab that queued them closes.
final fileTransferQueueProvider = Provider<FileTransferQueue>((ref) {
  return FileTransferQueue(
    progress: () => ref.read(taskProgressProvider.notifier),
    conflictMode: () => ref.read(transferConflictModeProvider),
    openBackend: (endpoint) async {
      final serverId = endpoint.serverId;
      if (serverId == null) return LocalFileSystemBackend();
      final client = ref.read(connectionManagerProvider).clientFor(serverId);
      if (client == null) throw const ServerConnectionRequiredException();
      return SftpFileSystemBackend(await client.sftp());
    },
    askConflict: showTransferConflictDialog,
    notify: (notification) {
      final context = conduitNavigatorKey.currentContext;
      final scheme = context == null ? null : Theme.of(context).colorScheme;
      showStyledSnackBar(
        message: notification.message,
        title: notification.title,
        icon: notification.isError ? Symbols.error : Symbols.check_circle,
        accentColor: notification.isError ? scheme?.error : scheme?.primary,
      );
    },
  );
});
