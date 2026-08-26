import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/presentation/app_scaffold.dart';
import 'server_detail_page.dart';
import 'server_providers.dart';

/// Top-level monitoring workspace: the full per-server inspection surface
/// (activity, processes, runtimes, services, …) with a server picker that
/// sits above the overview column, sharing its width.
@RoutePage()
class MonitorPage extends ConsumerWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final selectedId = ref.watch(monitorSelectedServerIdProvider);
    final selected =
        servers.where((server) => server.id == selectedId).firstOrNull ??
        servers.firstOrNull;

    if (selected == null) {
      return ConduitAppScaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.monitoring,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'monitorEmpty'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ConduitAppScaffold(
      // The key remounts the detail workspace when the selection changes so
      // per-server streams and tab state reset cleanly.
      body: ServerDetailPage(
        key: ValueKey(selected.id),
        server: selected,
        embedded: true,
        header: DropdownButtonFormField<int>(
          initialValue: selected.id,
          decoration: InputDecoration(
            labelText: 'monitorServerLabel'.tr(),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kDetailPanelRadius),
            ),
          ),
          items: [
            for (final server in servers)
              DropdownMenuItem(
                value: server.id,
                child: Text(
                  server.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              ref.read(monitorSelectedServerIdProvider.notifier).select(value);
            }
          },
        ),
      ),
    );
  }
}
