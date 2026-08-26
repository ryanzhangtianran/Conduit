import 'package:material_ui/material_ui.dart';

/// Standard page foundation for Conduit routes.
///
/// Unlike the former window-level safe-area shell, this keeps MediaQuery
/// insets intact until the page that owns the content decides to consume them.
/// The scaffold always paints an opaque Material surface, which keeps iOS
/// gesture-back transitions from revealing a transparent route underneath.
///
/// By default the scaffold consumes the top inset when there is no [appBar].
/// Shells that host other page scaffolds can pass `topSafeArea: false` so the
/// content pages manage the top inset themselves, which keeps their surface
/// painting edge-to-edge behind the status bar.
class ConduitAppScaffold extends StatelessWidget {
  const ConduitAppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.useSafeArea = true,
    this.topSafeArea = true,
    this.backgroundColor,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// Master switch for the scaffold-level safe-area handling.
  final bool useSafeArea;

  /// Whether this scaffold consumes the top inset itself. Set to false for
  /// shells whose body hosts other page scaffolds, so those content pages
  /// control the top safe area.
  final bool topSafeArea;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageColor = backgroundColor ?? scheme.surface;
    final bodyContent = body == null
        ? const SizedBox.shrink()
        // The solid page color is painted by the Scaffold itself; the
        // transparent Material lets ListTile ink and tile backgrounds paint
        // on top of it.
        : Material(
            type: MaterialType.transparency,
            child: useSafeArea
                ? SafeArea(
                    top: topSafeArea && appBar == null,
                    bottom: bottomNavigationBar == null,
                    child: body!,
                  )
                : body!,
          );

    return Scaffold(
      backgroundColor: pageColor,
      appBar: appBar,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
