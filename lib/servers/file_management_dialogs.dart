import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'file_transfer_queue.dart';

/// Every file-manager prompt goes through the app overlay dialog so they all
/// look the same and sit above the desktop window frame: confirmations use
/// [showConduitConfirmAlert], errors use [showConduitErrorAlert], and the
/// prompts below cover names, conflicts and the left-pane source.

/// Asks the user how to resolve a name conflict during a transfer.
Future<TransferConflictChoice> showTransferConflictDialog(String name) async {
  final choice = await showConduitOverlayDialog<TransferConflictChoice>(
    barrierDismissible: false,
    builder: (context, close) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kConduitDialogMaxWidth),
      child: AlertDialog(
        title: Text('fileManagerOverwriteTitle'.tr()),
        content: Text('fileManagerOverwriteMessage'.tr(args: [name])),
        actions: [
          TextButton(
            onPressed: () => close(TransferConflictChoice.skip),
            child: Text('fileManagerSkip'.tr()),
          ),
          TextButton(
            onPressed: () => close(TransferConflictChoice.keepBoth),
            child: Text('fileManagerKeepBoth'.tr()),
          ),
          FilledButton(
            onPressed: () => close(TransferConflictChoice.overwrite),
            child: Text('fileManagerOverwrite'.tr()),
          ),
        ],
      ),
    ),
  );
  return choice ?? TransferConflictChoice.skip;
}

/// Single-line name prompt used for rename and new folder. Returns the
/// trimmed name, or `null` when dismissed.
Future<String?> showFileNameDialog({
  required String title,
  required String label,
  required String actionLabel,
  String initialName = '',
}) {
  return showConduitOverlayDialog<String>(
    builder: (context, close) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kConduitDialogMaxWidth),
      child: _FileNameDialog(
        title: title,
        label: label,
        actionLabel: actionLabel,
        initialName: initialName,
        onClose: close,
      ),
    ),
  );
}

class _FileNameDialog extends StatefulWidget {
  const _FileNameDialog({
    required this.title,
    required this.label,
    required this.actionLabel,
    required this.initialName,
    required this.onClose,
  });

  final String title;
  final String label;
  final String actionLabel;
  final String initialName;
  final void Function(String? result) onClose;

  @override
  State<_FileNameDialog> createState() => _FileNameDialogState();
}

class _FileNameDialogState extends State<_FileNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-select the stem so typing replaces the name but keeps the extension.
    final dot = widget.initialName.lastIndexOf('.');
    final end = dot > 0 ? dot : widget.initialName.length;
    _name.selection = TextSelection(baseOffset: 0, extentOffset: end);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onClose(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: widget.label),
        validator: validateFileName,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => widget.onClose(null),
        child: Text('commonCancel'.tr()),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
    ],
  );
}

String? validateFileName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'fileManagerNameRequired'.tr();
  if (name == '.' || name == '..' || name.contains('/')) {
    return 'fileManagerInvalidName'.tr();
  }
  return null;
}

/// Result of [showLeftPaneSourceDialog]: local files or a server id.
class LeftPaneSourceChoice {
  const LeftPaneSourceChoice.local() : serverId = null;
  const LeftPaneSourceChoice.server(int this.serverId);

  final int? serverId;
}

/// Lets the user pick what the left pane shows: the local disk or one of
/// [servers]. Returns `null` when dismissed.
Future<LeftPaneSourceChoice?> showLeftPaneSourceDialog(List<Server> servers) {
  return showConduitOverlayDialog<LeftPaneSourceChoice>(
    builder: (context, close) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kConduitDialogMaxWidth),
      child: AlertDialog(
        title: Text('fileManagerUseAnotherServer'.tr()),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: kConduitDialogMaxWidth,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text('fileManagerUseLocalFiles'.tr()),
                onTap: () => close(const LeftPaneSourceChoice.local()),
              ),
              for (final server in servers)
                ListTile(
                  title: Text(server.name),
                  onTap: () => close(LeftPaneSourceChoice.server(server.id)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => close(null),
            child: Text('commonCancel'.tr()),
          ),
        ],
      ),
    ),
  );
}

/// Confirms a delete of [entries] and returns whether the user approved.
Future<bool> confirmDeleteEntries({
  required int count,
  required String firstName,
  required bool firstIsDirectory,
}) {
  final label = count == 1
      ? firstName
      : 'fileManagerItems'.tr(args: ['$count']);
  final message = count == 1 && firstIsDirectory
      ? 'fileManagerDeleteFolderMessage'.tr()
      : count == 1
      ? 'fileManagerDeleteFileMessage'.tr()
      : 'fileManagerDeleteSelectionMessage'.tr();
  return showConduitConfirmAlert(
    message,
    'fileManagerDeleteConfirmTitle'.tr(args: [label]),
    isDanger: true,
  );
}
