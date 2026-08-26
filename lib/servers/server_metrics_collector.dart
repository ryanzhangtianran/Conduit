import 'metrics_parsers.dart';
import 'server_models.dart';

export 'metrics_parsers.dart'
    show encodePowerShellCommand, parseNvidiaGpuMetricsOutput;

/// Runs one non-interactive command on the host and returns its stdout. The
/// connection manager supplies this so every remote command goes through a
/// single execution path.
typedef RemoteRunner = Future<String> Function(String command);

abstract interface class ServerMetricsCollector {
  String get id;

  Future<ServerStats?> collect(RemoteRunner run);
}

/// Selects the first collector that can return a valid result for the host.
class AutoServerMetricsCollector implements ServerMetricsCollector {
  const AutoServerMetricsCollector();

  static const _collectors = <ServerMetricsCollector>[
    LinuxProcfsMetricsCollector(),
    MacosSysctlMetricsCollector(),
    WindowsPowerShellMetricsCollector(),
    UptimeMetricsCollector(),
  ];

  @override
  String get id => 'auto';

  @override
  Future<ServerStats?> collect(RemoteRunner run) async {
    for (final collector in _collectors) {
      try {
        final stats = await collector.collect(run);
        if (stats != null) return stats;
      } catch (_) {
        // Try the next compatible collector.
      }
    }
    return null;
  }
}

class MacosSysctlMetricsCollector implements ServerMetricsCollector {
  const MacosSysctlMetricsCollector();

  @override
  String get id => 'macos-sysctl';

  @override
  Future<ServerStats?> collect(RemoteRunner run) async {
    final output = await run("""sh -c '
if [ "\$(uname -s 2>/dev/null)" != "Darwin" ]; then exit 1; fi
echo --LOAD--
sysctl -n vm.loadavg 2>/dev/null || true
echo --CPU--
sysctl -n hw.ncpu 2>/dev/null || true
echo --MEM--
sysctl -n hw.memsize 2>/dev/null || true
echo --VMSTAT--
vm_stat 2>/dev/null || true
echo --SWAP--
sysctl -n vm.swapusage 2>/dev/null || true
echo --DISK--
df -Pk / 2>/dev/null || true
echo --GPU--
$nvidiaGpuQuery 2>/dev/null || true
echo --UPTIME--
sysctl -n kern.boottime 2>/dev/null || true
'""");
    return parseMacosMetricsOutput(output);
  }
}

class WindowsPowerShellMetricsCollector implements ServerMetricsCollector {
  const WindowsPowerShellMetricsCollector();

  @override
  String get id => 'windows-powershell';

  @override
  Future<ServerStats?> collect(RemoteRunner run) async =>
      parseWindowsMetricsOutput(await run(windowsHostMetricsCommand()));
}

class LinuxProcfsMetricsCollector implements ServerMetricsCollector {
  const LinuxProcfsMetricsCollector();

  @override
  String get id => 'linux-procfs';

  @override
  Future<ServerStats?> collect(RemoteRunner run) async {
    final output = await run(
      "sh -c 'echo --LOAD--; cat /proc/loadavg; echo --CPU--; "
      'getconf _NPROCESSORS_ONLN 2>/dev/null || nproc; echo --MEM--; '
      'cat /proc/meminfo; echo --DISK--; df -Pk / | tail -n 1; echo --GPU--; '
      '$nvidiaGpuQuery 2>/dev/null || true; echo --UPTIME--; '
      "cut -d. -f1 /proc/uptime'",
    );
    return parseLinuxMetricsOutput(output);
  }
}

/// A portable fallback for POSIX-like hosts where procfs is unavailable.
class UptimeMetricsCollector implements ServerMetricsCollector {
  const UptimeMetricsCollector();

  @override
  String get id => 'uptime';

  @override
  Future<ServerStats?> collect(RemoteRunner run) async {
    final output = await run('uptime');
    final match = RegExp(
      r'load averages?:\s*(.*)',
      caseSensitive: false,
    ).firstMatch(output);
    final loads = parseLoadTriple(match?.group(1));
    if (loads.$1 == null) return null;
    return ServerStats(
      collectorId: id,
      updatedAt: DateTime.now(),
      loadAverage: loads.$1,
      loadAverage5: loads.$2,
      loadAverage15: loads.$3,
    );
  }
}

/// Parses the normalized output emitted by [LinuxProcfsMetricsCollector].
ServerStats? parseLinuxMetricsOutput(String output, {DateTime? now}) =>
    _statsFromSections(output, collectorId: 'linux-procfs', now: now);

/// Parses the normalized output emitted by [MacosSysctlMetricsCollector].
ServerStats? parseMacosMetricsOutput(String output, {DateTime? now}) =>
    _statsFromSections(output, collectorId: 'macos-sysctl', now: now);

/// Parses the normalized output emitted by [WindowsPowerShellMetricsCollector].
ServerStats? parseWindowsMetricsOutput(String output, {DateTime? now}) =>
    _statsFromSections(output, collectorId: 'windows-powershell', now: now);

/// A host that could not even report a load average is treated as
/// unsupported by that collector so the next one gets a turn.
ServerStats? _statsFromSections(
  String output, {
  required String collectorId,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final metrics = parseHostMetrics(output, now: currentTime);
  if (metrics.load1 == null) return null;
  return metrics.toServerStats(
    collectorId: collectorId,
    updatedAt: currentTime,
  );
}
