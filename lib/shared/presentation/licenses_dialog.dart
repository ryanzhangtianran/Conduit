import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Opens the open-source licenses as a flat two-pane dialog: package names
/// down the left, the selected package's license text on the right.
Future<void> showLicensesDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _LicensesDialog());

class _LicensesDialog extends StatefulWidget {
  const _LicensesDialog();

  @override
  State<_LicensesDialog> createState() => _LicensesDialogState();
}

class _LicensesDialogState extends State<_LicensesDialog> {
  /// Package name → its license entries, in registry order.
  final _byPackage = <String, List<LicenseEntry>>{};
  var _loading = true;
  String? _selected;
  final _contentScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _collect();
  }

  @override
  void dispose() {
    _contentScroll.dispose();
    super.dispose();
  }

  Future<void> _collect() async {
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        _byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }
    if (!mounted) return;
    final names = _byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    setState(() {
      _loading = false;
      _selected = names.firstOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = _byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'aboutOpenSourceLicenses'.tr(),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (!_loading)
                    Text(
                      'aboutLicenseCount'.tr(args: ['${names.length}']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'commonClose'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Symbols.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 260,
                          child: ListView.builder(
                            itemCount: names.length,
                            itemBuilder: (context, index) {
                              final name = names[index];
                              final selected = name == _selected;
                              return ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor: scheme.secondaryContainer,
                                selectedColor: scheme.onSecondaryContainer,
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  '${_byPackage[name]!.length}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: selected
                                        ? scheme.onSecondaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () => setState(() {
                                  _selected = name;
                                  _contentScroll.jumpTo(0);
                                }),
                              );
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _selected == null
                              ? const SizedBox.shrink()
                              : _LicenseContent(
                                  package: _selected!,
                                  entries: _byPackage[_selected!]!,
                                  controller: _contentScroll,
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LicenseContent extends StatelessWidget {
  const _LicenseContent({
    required this.package,
    required this.entries,
    required this.controller,
  });

  final String package;
  final List<LicenseEntry> entries;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'IBM Plex Mono',
      height: 1.5,
    );
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Text(package, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) ...[
            const SizedBox(height: 16),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 16),
          ],
          for (final paragraph in entry.paragraphs)
            Padding(
              padding: EdgeInsets.only(
                left: paragraph.indent == LicenseParagraph.centeredIndent
                    ? 0
                    : paragraph.indent * 16.0,
                bottom: 8,
              ),
              child: Text(
                paragraph.text,
                textAlign: paragraph.indent == LicenseParagraph.centeredIndent
                    ? TextAlign.center
                    : TextAlign.start,
                style: body,
              ),
            ),
        ],
      ],
    );
  }
}
