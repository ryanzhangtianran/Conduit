import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';

/// Asks for a password in a dialog and returns it, or null when cancelled.
///
/// With [confirm] a second field must match before the dialog closes. The
/// keys name the dialog title, the explanatory line and the action button.
Future<String?> showPasswordPrompt(
  BuildContext context, {
  required String titleKey,
  required String hintKey,
  required String actionKey,
  bool confirm = false,
}) => showDialog<String>(
  context: context,
  useRootNavigator: true,
  builder: (context) => AlertDialog(
    title: Text(titleKey.tr()),
    content: SizedBox(
      width: 400,
      child: PasswordPromptForm(
        hintKey: hintKey,
        actionKey: actionKey,
        confirm: confirm,
        onCancel: () => Navigator.of(context).pop(),
        onSubmit: (password) async {
          Navigator.of(context).pop(password);
          return true;
        },
      ),
    ),
  ),
);

/// The password (and optional confirmation) fields with their submit button.
///
/// [onSubmit] runs with the entered password; when it returns true the
/// fields are cleared, so an inline form can collapse back to its resting
/// state. A mismatched confirmation is reported and never submitted.
class PasswordPromptForm extends StatefulWidget {
  const PasswordPromptForm({
    super.key,
    required this.hintKey,
    required this.actionKey,
    required this.onSubmit,
    this.confirm = false,
    this.cancelLabel,
    this.onCancel,
  });

  final String hintKey;
  final String actionKey;
  final bool confirm;
  final Future<bool> Function(String password) onSubmit;

  /// Shown as a text button before the action when [onCancel] is set.
  final String? cancelLabel;
  final VoidCallback? onCancel;

  @override
  State<PasswordPromptForm> createState() => _PasswordPromptFormState();
}

class _PasswordPromptFormState extends State<PasswordPromptForm> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _password.text;
    if (password.isEmpty) return;
    if (widget.confirm && password != _confirmation.text) {
      showStyledSnackBar(message: 'vaultPasswordsDontMatch'.tr());
      return;
    }
    setState(() => _busy = true);
    final done = await widget.onSubmit(password);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      _password.clear();
      _confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.hintKey.tr()),
      const SizedBox(height: 16),
      TextField(
        controller: _password,
        autofocus: true,
        enabled: !_busy,
        obscureText: true,
        autocorrect: false,
        decoration: InputDecoration(labelText: 'vaultPasswordLabel'.tr()),
        onSubmitted: (_) => _submit(),
      ),
      if (widget.confirm) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _confirmation,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'vaultConfirmPasswordLabel'.tr(),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.onCancel != null) ...[
            TextButton(
              onPressed: widget.onCancel,
              child: Text(widget.cancelLabel ?? 'commonCancel'.tr()),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(widget.actionKey.tr()),
          ),
        ],
      ),
    ],
  );
}
