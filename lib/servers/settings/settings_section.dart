import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';

import 'package:conduit/shared/presentation/password_prompt.dart';

/// Horizontal inset of list tiles inside a [SettingsSection] card.
const settingsTilePadding = EdgeInsets.symmetric(horizontal: 16);

/// Reports the outcome of a settings action.
void showSettingsMessage(String message) =>
    showStyledSnackBar(message: message);

/// The scrolling column every settings category renders into: centred,
/// capped at a readable width.
class SettingsPageBody extends StatelessWidget {
  const SettingsPageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: children,
      ),
    ),
  );
}

/// A titled card grouping related settings.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.titleKey,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String titleKey;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titleKey, style: Theme.of(context).textTheme.titleMedium).tr(),
      const SizedBox(height: 8),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    ],
  );
}

/// A settings row that expands in place to ask for a password (and its
/// confirmation) before running [onSubmit]; collapses again on success.
class SettingsPasswordTile extends StatefulWidget {
  const SettingsPasswordTile({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.hintKey,
    required this.actionKey,
    required this.onSubmit,
  });

  final IconData icon;
  final String titleKey;
  final String hintKey;
  final String actionKey;
  final Future<bool> Function(String password) onSubmit;

  @override
  State<SettingsPasswordTile> createState() => _SettingsPasswordTileState();
}

class _SettingsPasswordTileState extends State<SettingsPasswordTile> {
  final _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    controller: _controller,
    tilePadding: settingsTilePadding,
    leading: Icon(widget.icon),
    title: Text(widget.titleKey).tr(),
    subtitle: Text(widget.hintKey).tr(),
    childrenPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    children: [
      PasswordPromptForm(
        hintKey: widget.hintKey,
        actionKey: widget.actionKey,
        confirm: true,
        onSubmit: (password) async {
          final done = await widget.onSubmit(password);
          if (done && mounted) _controller.collapse();
          return done;
        },
      ),
    ],
  );
}
