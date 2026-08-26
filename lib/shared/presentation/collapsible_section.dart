import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A bordered, compact disclosure section used across the workspace.
class ConduitCollapsibleSection extends StatefulWidget {
  const ConduitCollapsibleSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = true,
    this.tilePadding = const EdgeInsets.symmetric(horizontal: 12),
    this.childrenPadding = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  final Widget title;
  final List<Widget> children;
  final Widget? subtitle;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry tilePadding;
  final EdgeInsetsGeometry childrenPadding;

  @override
  State<ConduitCollapsibleSection> createState() =>
      _ConduitCollapsibleSectionState();
}

class _ConduitCollapsibleSectionState extends State<ConduitCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return ExpansionTile(
      initiallyExpanded: _expanded,
      onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
      tilePadding: widget.tilePadding,
      childrenPadding: widget.childrenPadding,
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: Icon(
        _expanded ? Symbols.keyboard_arrow_up : Symbols.keyboard_arrow_down,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: outline),
      ),
      children: widget.children,
    );
  }
}
