import 'dart:convert';

import 'activity_models.dart';
import 'server_models.dart';

/// Pure parsers for the `--SECTION--` delimited output produced by the host
/// metrics scripts. Both the statistics collectors and the Activity tab run
/// scripts that print a subset of the same sections, so one parser serves
/// every platform and both consumers.
///
/// Sections and the formats each accepts:
/// * `STAT`: `cpu user nice system idle …` (`/proc/stat`) or the five
///   `kern.cp_time` counters (macOS).
/// * `LOAD`: any text containing the load triple (`/proc/loadavg`,
///   `vm.loadavg`, a single Windows number).
/// * `CPUUSAGE`: direct CPU utilization percent (Windows).
/// * `CPU`: logical CPU count.
/// * `MEM` (or `MEMTOTAL`): `/proc/meminfo` labels, `hw.memsize` bytes, or
///   the Windows `MemTotal:`/`MemAvailable:` lines.
/// * `VMSTAT`: macOS `vm_stat`.
/// * `SWAP`: `vm.swapusage` or `SwapTotal:`/`SwapFree:` lines.
/// * `DISK`: `df -Pk` rows or `DiskTotal:`/`DiskAvailable:` lines.
/// * `NET`: `/proc/net/dev`, `netstat -ib`, or `RxBytes:`/`TxBytes:` lines.
/// * `GPU`: `nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,
///   memory.total,temperature.gpu` CSV rows.
/// * `UPTIME`: seconds, or `kern.boottime` (`sec = N`).
class HostMetrics {
  const HostMetrics({
    this.load1,
    this.load5,
    this.load15,
    this.cpuCount,
    this.cpuIdle,
    this.cpuTotal,
    this.cpuPercent,
    this.memoryTotalKb,
    this.memoryAvailableKb,
    this.swapTotalKb,
    this.swapFreeKb,
    this.diskTotalKb,
    this.diskAvailableKb,
    this.netRxBytes,
    this.netTxBytes,
    this.gpus = const [],
    this.uptime,
  });

  final double? load1;
  final double? load5;
  final double? load15;
  final int? cpuCount;

  /// Cumulative CPU tick counters; utilization is the delta between samples.
  final int? cpuIdle;
  final int? cpuTotal;

  /// Direct CPU utilization for platforms without cumulative counters.
  final double? cpuPercent;
  final int? memoryTotalKb;
  final int? memoryAvailableKb;
  final int? swapTotalKb;
  final int? swapFreeKb;
  final int? diskTotalKb;
  final int? diskAvailableKb;

  /// Cumulative bytes over every non-loopback interface.
  final int? netRxBytes;
  final int? netTxBytes;
  final List<ServerGpuStats> gpus;
  final Duration? uptime;

  ServerStats toServerStats({
    required String collectorId,
    required DateTime updatedAt,
  }) => ServerStats(
    collectorId: collectorId,
    updatedAt: updatedAt,
    loadAverage: load1,
    loadAverage5: load5,
    loadAverage15: load15,
    cpuCount: cpuCount,
    memoryTotalKb: memoryTotalKb,
    memoryAvailableKb: memoryAvailableKb,
    swapTotalKb: swapTotalKb,
    swapFreeKb: swapFreeKb,
    diskTotalKb: diskTotalKb,
    diskAvailableKb: diskAvailableKb,
    gpus: gpus,
    uptime: uptime,
  );

  /// Collapses per-GPU readings into the Activity tab's averaged utilization
  /// and summed memory.
  ActivityCounters toActivityCounters({required DateTime at}) {
    final utilizations = gpus
        .map((gpu) => gpu.utilizationPercent)
        .whereType<double>()
        .toList();
    var usedKb = 0;
    var totalKb = 0;
    var hasMemory = false;
    for (final gpu in gpus) {
      final used = gpu.memoryUsedKb;
      final total = gpu.memoryTotalKb;
      if (used == null || total == null) continue;
      usedKb += used;
      totalKb += total;
      hasMemory = true;
    }
    return ActivityCounters(
      at: at,
      cpuIdle: cpuIdle,
      cpuTotal: cpuTotal,
      cpuPercent: cpuPercent,
      load1: load1,
      cpuCount: cpuCount,
      memoryTotalKb: memoryTotalKb,
      memoryAvailableKb: memoryAvailableKb,
      swapTotalKb: swapTotalKb,
      swapFreeKb: swapFreeKb,
      diskTotalKb: diskTotalKb,
      diskAvailableKb: diskAvailableKb,
      netRxBytes: netRxBytes,
      netTxBytes: netTxBytes,
      gpuPercent: utilizations.isEmpty
          ? null
          : utilizations.reduce((a, b) => a + b) / utilizations.length,
      gpuMemoryUsedKb: hasMemory ? usedKb : null,
      gpuMemoryTotalKb: hasMemory ? totalKb : null,
      uptime: uptime,
    );
  }
}

/// Parses every section present in [output]; absent sections leave their
/// fields null. [now] anchors boot-time based uptime.
HostMetrics parseHostMetrics(String output, {DateTime? now}) {
  final cpu = parseCpuTicks(metricSection(output, 'STAT'));
  final loads = parseLoadTriple(metricSection(output, 'LOAD'));
  final memSection = metricSection(output, 'MEM');
  final memTotalSection = metricSection(output, 'MEMTOTAL');
  final swapSection = metricSection(output, 'SWAP');
  final diskSection = metricSection(output, 'DISK');
  final macSwap = parseMacosSwapKb(swapSection);
  final macMemoryBytes =
      int.tryParse(memTotalSection) ?? int.tryParse(memSection);
  final macAvailableBytes = parseMacosAvailableMemoryBytes(
    metricSection(output, 'VMSTAT'),
  );
  final diskRow = lastDataRowFields(diskSection);
  final net = parseNetworkCounters(metricSection(output, 'NET'));
  return HostMetrics(
    load1: loads.$1,
    load5: loads.$2,
    load15: loads.$3,
    cpuCount: int.tryParse(metricSection(output, 'CPU')),
    cpuIdle: cpu?.$1,
    cpuTotal: cpu?.$2,
    cpuPercent: double.tryParse(metricSection(output, 'CPUUSAGE')),
    memoryTotalKb:
        labeledInt(memSection, 'MemTotal') ??
        (macMemoryBytes == null ? null : macMemoryBytes ~/ 1024),
    memoryAvailableKb:
        labeledInt(memSection, 'MemAvailable') ??
        (macAvailableBytes == null ? null : macAvailableBytes ~/ 1024),
    swapTotalKb:
        labeledInt(memSection, 'SwapTotal') ??
        labeledInt(swapSection, 'SwapTotal') ??
        macSwap.$1,
    swapFreeKb:
        labeledInt(memSection, 'SwapFree') ??
        labeledInt(swapSection, 'SwapFree') ??
        macSwap.$2,
    diskTotalKb:
        labeledInt(diskSection, 'DiskTotal') ??
        (diskRow.length > 1 ? int.tryParse(diskRow[1]) : null),
    diskAvailableKb:
        labeledInt(diskSection, 'DiskAvailable') ??
        (diskRow.length > 3 ? int.tryParse(diskRow[3]) : null),
    netRxBytes: net?.$1,
    netTxBytes: net?.$2,
    gpus: parseNvidiaGpuMetricsOutput(metricSection(output, 'GPU')),
    uptime: parseUptime(
      metricSection(output, 'UPTIME'),
      now: now ?? DateTime.now(),
    ),
  );
}

/// The trimmed text between `--[label]--` and the next `--` marker.
String metricSection(String output, String label) {
  final start = output.indexOf('--$label--');
  if (start < 0) return '';
  final after = start + label.length + 4;
  final next = output.indexOf('--', after);
  return (next < 0 ? output.substring(after) : output.substring(after, next))
      .trim();
}

/// The first three numbers in [output]: 1, 5 and 15 minute load averages.
(double?, double?, double?) parseLoadTriple(String? output) {
  final values = RegExp(r'[0-9]+(?:\.[0-9]+)?')
      .allMatches(output ?? '')
      .map((match) => double.tryParse(match.group(0)!))
      .whereType<double>()
      .toList();
  double? at(int index) => values.length > index ? values[index] : null;
  return (at(0), at(1), at(2));
}

/// `(idle, total)` CPU ticks from a `/proc/stat` `cpu` line or the macOS
/// `kern.cp_time` counters (user nice system interrupt idle).
(int, int)? parseCpuTicks(String statLine) {
  final isProcStat = statLine.startsWith('cpu');
  final rawFields = statLine.split(RegExp(r'\s+'));
  final fields = (isProcStat ? rawFields.skip(1) : rawFields)
      .map(int.tryParse)
      .whereType<int>()
      .toList();
  if (fields.length < 4) return null;
  // Linux: user nice system idle iowait irq softirq steal …; iowait counts
  // as idle. macOS: user nice system interrupt idle.
  final idleIndex = isProcStat ? 3 : fields.length - 1;
  final idle =
      fields[idleIndex] + (isProcStat && fields.length > 4 ? fields[4] : 0);
  return (idle, fields.fold<int>(0, (sum, value) => sum + value));
}

/// The integer after a `Label:` line such as `/proc/meminfo`'s `MemTotal:`
/// or the `DiskTotal:` lines printed by the Windows script.
int? labeledInt(String text, String label) {
  final match = RegExp('\\b$label:\\s*(\\d+)').firstMatch(text);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Free, inactive and speculative pages from `vm_stat`, in bytes.
int? parseMacosAvailableMemoryBytes(String vmStat) {
  final pageSize = int.tryParse(
    RegExp(r'page size of (\d+) bytes').firstMatch(vmStat)?.group(1) ?? '',
  );
  if (pageSize == null) return null;
  int? pages(String label) => int.tryParse(
    RegExp('$label:\\s+(\\d+)').firstMatch(vmStat)?.group(1) ?? '',
  );
  final available = [
    pages('Pages free'),
    pages('Pages inactive'),
    pages('Pages speculative'),
  ].whereType<int>().toList();
  if (available.isEmpty) return null;
  return available.fold<int>(0, (sum, value) => sum + value) * pageSize;
}

/// `(total, free)` in KiB from `vm.swapusage`
/// (`total = 4096.00M  used = 1024.00M  free = 3072.00M`).
(int?, int?) parseMacosSwapKb(String swapUsage) {
  int? value(String label) {
    final match = RegExp(
      '$label\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)([KMGT])',
      caseSensitive: false,
    ).firstMatch(swapUsage);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return null;
    final multiplier = switch (match.group(2)!.toUpperCase()) {
      'K' => 1,
      'M' => 1024,
      'G' => 1024 * 1024,
      'T' => 1024 * 1024 * 1024,
      _ => 1,
    };
    return (amount * multiplier).round();
  }

  return (value('total'), value('free'));
}

/// Whitespace-split fields of the last non-empty line, e.g. the data row of
/// `df -Pk /` after its header.
List<String> lastDataRowFields(String output) {
  final lines = output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.isEmpty ? const [] : lines.last.split(RegExp(r'\s+'));
}

/// `(rx, tx)` cumulative bytes summed over non-loopback interfaces from
/// `/proc/net/dev`, `netstat -ib`, or the Windows `RxBytes:`/`TxBytes:`
/// lines. Null when the section carries no interface data.
(int, int)? parseNetworkCounters(String netSection) {
  final windowsRx = labeledInt(netSection, 'RxBytes');
  final windowsTx = labeledInt(netSection, 'TxBytes');
  if (windowsRx != null && windowsTx != null) return (windowsRx, windowsTx);

  var rx = 0;
  var tx = 0;
  var found = false;
  for (final line in netSection.split('\n')) {
    final trimmed = line.trim();
    // /proc/net/dev: `eth0: rx_bytes … (8 more) tx_bytes …`. Only the
    // interface name is followed by a colon; a netstat row's MAC address
    // carries colons too but never in its first field.
    final procRow = RegExp(r'^([^\s:]+):\s*(.*)$').firstMatch(trimmed);
    if (procRow != null) {
      if (procRow.group(1) == 'lo') continue;
      final cols = procRow.group(2)!.split(RegExp(r'\s+'));
      if (cols.length < 9) continue;
      final lineRx = int.tryParse(cols[0]);
      final lineTx = int.tryParse(cols[8]);
      if (lineRx == null || lineTx == null) continue;
      rx += lineRx;
      tx += lineTx;
      found = true;
      continue;
    }
    // netstat -ib: only the `<Link#n>` row of each interface carries totals.
    final fields = trimmed.split(RegExp(r'\s+'));
    if (fields.length < 10 ||
        fields[0] == 'Name' ||
        fields[0] == 'lo0' ||
        !fields[2].startsWith('<Link#')) {
      continue;
    }
    final lineRx = int.tryParse(fields[6]);
    final lineTx = int.tryParse(fields[9]);
    if (lineRx == null || lineTx == null) continue;
    rx += lineRx;
    tx += lineTx;
    found = true;
  }
  return found ? (rx, tx) : null;
}

/// Uptime from a plain seconds value or from `kern.boottime`
/// (`{ sec = 1700000000, usec = 0 } …`) relative to [now]. Null when the
/// value is missing or the clock says the host booted in the future.
Duration? parseUptime(String uptimeSection, {required DateTime now}) {
  var seconds = int.tryParse(uptimeSection);
  if (seconds == null) {
    final boot = int.tryParse(
      RegExp(r'sec\s*=\s*(\d+)').firstMatch(uptimeSection)?.group(1) ?? '',
    );
    if (boot != null) seconds = now.millisecondsSinceEpoch ~/ 1000 - boot;
  }
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// Parses `nvidia-smi --query-gpu=... --format=csv,noheader,nounits` rows.
///
/// NVIDIA reports memory in MiB; the app's resource model stores memory in
/// KiB. A row is retained when its index and name are valid, even if an
/// individual sensor returns `N/A`.
List<ServerGpuStats> parseNvidiaGpuMetricsOutput(String output) {
  final gpus = <ServerGpuStats>[];
  for (final line in output.split('\n')) {
    final fields = line.trim().split(',').map((field) => field.trim()).toList();
    if (fields.length < 6) continue;
    final index = int.tryParse(fields[0]);
    final name = fields[1];
    if (index == null || name.isEmpty) continue;
    int? memoryKb(String value) {
      final mib = int.tryParse(value);
      return mib == null ? null : mib * 1024;
    }

    gpus.add(
      ServerGpuStats(
        index: index,
        name: name,
        utilizationPercent: double.tryParse(fields[2]),
        memoryUsedKb: memoryKb(fields[3]),
        memoryTotalKb: memoryKb(fields[4]),
        temperatureC: double.tryParse(fields[5]),
      ),
    );
  }
  return gpus;
}

/// The `nvidia-smi` query whose rows [parseNvidiaGpuMetricsOutput] reads.
const nvidiaGpuQuery =
    'nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,'
    'memory.total,temperature.gpu --format=csv,noheader,nounits';

/// One PowerShell script reports everything Windows can offer; the stats
/// collector and the Activity tab each read the sections they need.
String windowsHostMetricsCommand() => encodePowerShellCommand(r'''
$ErrorActionPreference = 'Stop'
$os = Get-CimInstance Win32_OperatingSystem
$processors = @(Get-CimInstance Win32_Processor)
$cpuCount = [int](($processors | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
$loadPercent = [double](($processors | Measure-Object LoadPercentage -Average).Average)
$load = if ($cpuCount -gt 0) { $loadPercent * $cpuCount / 100 } else { $null }
$pageFiles = @(Get-CimInstance Win32_PageFileUsage)
$swapTotalKb = [int64](($pageFiles | Measure-Object AllocatedBaseSize -Sum).Sum)
$swapUsedKb = [int64](($pageFiles | Measure-Object CurrentUsage -Sum).Sum)
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$net = @(Get-NetAdapterStatistics -ErrorAction SilentlyContinue)
$rx = [int64](($net | Measure-Object ReceivedBytes -Sum).Sum)
$tx = [int64](($net | Measure-Object SentBytes -Sum).Sum)
Write-Output '--WINDOWS--'
Write-Output '--CPUUSAGE--'
$loadPercent.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture)
Write-Output '--LOAD--'
if ($null -ne $load) { $load.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) }
Write-Output '--CPU--'
$cpuCount
Write-Output '--MEM--'
"MemTotal: $($os.TotalVisibleMemorySize)"
"MemAvailable: $($os.FreePhysicalMemory)"
Write-Output '--SWAP--'
"SwapTotal: $swapTotalKb"
"SwapFree: $([math]::Max(0, $swapTotalKb - $swapUsedKb))"
Write-Output '--DISK--'
if ($null -ne $disk) {
  "DiskTotal: $([int64]($disk.Size / 1KB))"
  "DiskAvailable: $([int64]($disk.FreeSpace / 1KB))"
}
Write-Output '--NET--'
"RxBytes: $rx"
"TxBytes: $tx"
Write-Output '--GPU--'
if (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) {
  & nvidia-smi.exe '--query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu' '--format=csv,noheader,nounits' 2>$null
}
Write-Output '--UPTIME--'
[int64](([DateTime]::UtcNow - $os.LastBootUpTime.ToUniversalTime()).TotalSeconds)
''');

/// Encodes an ASCII PowerShell script for OpenSSH's Windows shell.
///
/// `-EncodedCommand` requires UTF-16LE rather than UTF-8.
String encodePowerShellCommand(String script) {
  final bytes = <int>[];
  for (final codeUnit in script.codeUnits) {
    bytes
      ..add(codeUnit & 0xff)
      ..add((codeUnit >> 8) & 0xff);
  }
  return 'powershell.exe -NoLogo -NoProfile -NonInteractive '
      '-ExecutionPolicy Bypass -EncodedCommand ${base64.encode(bytes)}';
}
