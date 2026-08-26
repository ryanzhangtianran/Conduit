import 'package:material_ui/material_ui.dart';

/// The app's single-choice picker: a Material 3 [DropdownMenu] that fills its
/// parent's width, opens directly below the field at the same width, and uses
/// the same rounded corners as the rest of the chrome.
class ConduitDropdown<T> extends StatelessWidget {
  const ConduitDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.label,
    this.helperText,
    this.enabled = true,
    this.filterable = false,
    this.decorationTheme,
  });

  final T? value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? helperText;
  final bool enabled;

  /// Lets the user type into the field to narrow long lists (fonts); the
  /// field then takes focus on tap instead of only opening the menu.
  final bool filterable;
  final InputDecorationThemeData? decorationTheme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        return DropdownMenu<T>(
          // Remount when the selection changes from outside so the field
          // text follows: `initialSelection` is only read once.
          key: ValueKey(value),
          initialSelection: value,
          width: width,
          enabled: enabled,
          enableFilter: filterable,
          requestFocusOnTap: filterable,
          label: label == null ? null : Text(label!),
          helperText: helperText,
          inputDecorationTheme: decorationTheme,
          menuStyle: MenuStyle(
            // Standard density: the desktop default (compact) shrinks the
            // panel's minimum width by 8px, leaving the menu narrower than
            // the field it hangs from.
            visualDensity: VisualDensity.standard,
            minimumSize: width == null
                ? null
                : WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: width == null
                ? null
                : WidgetStatePropertyAll(Size(width, double.infinity)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          dropdownMenuEntries: entries,
          onSelected: onChanged,
        );
      },
    );
  }
}
