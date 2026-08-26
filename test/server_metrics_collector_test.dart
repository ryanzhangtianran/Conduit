import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/activity_models.dart';
import 'package:conduit/servers/metrics_parsers.dart';
import 'package:conduit/servers/server_metrics_collector.dart';

void main() {
  test('parses macOS sysctl metrics output', () {
    final now = DateTime.fromMillisecondsSinceEpoch(2_000_000_000_000);
    final bootSeconds = now.millisecondsSinceEpoch ~/ 1000 - 86_400;
    final stats = parseMacosMetricsOutput('''
--LOAD--
{ 1.25 0.75 0.50 }
--CPU--
10
--MEMTOTAL--
17179869184
--VMSTAT--
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               100.
Pages inactive:                           200.
Pages speculative:                         50.
--SWAP--
total = 4096.00M  used = 1024.00M  free = 3072.00M
--DISK--
Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/disk3s1 104857600 52428800 52428800 50% /
--GPU--
0, NVIDIA A100, 12.5, 1024, 40960, 45
1, NVIDIA A100, 0, 0, 40960, N/A
--UPTIME--
{ sec = $bootSeconds, usec = 0 } Mon Jan  1 00:00:00 2024
''', now: now);

    expect(stats, isNotNull);
    expect(stats!.collectorId, 'macos-sysctl');
    expect(stats.loadAverage, 1.25);
    expect(stats.loadAverage5, 0.75);
    expect(stats.loadAverage15, 0.5);
    expect(stats.cpuCount, 10);
    expect(stats.memoryTotalKb, 16 * 1024 * 1024);
    expect(stats.memoryAvailableKb, 350 * 16);
    expect(stats.swapTotalKb, 4096 * 1024);
    expect(stats.gpus, hasLength(2));
    expect(stats.swapFreeKb, 3072 * 1024);
    expect(stats.diskTotalKb, 104857600);
    expect(stats.diskAvailableKb, 52428800);
    expect(stats.uptime, const Duration(days: 1));
  });

  test('rejects output without a macOS load average', () {
    expect(parseMacosMetricsOutput('--CPU--\n8\n'), isNull);
  });

  test('parses Windows PowerShell metrics output', () {
    final now = DateTime(2026, 8, 8);
    final stats = parseWindowsMetricsOutput('''
--WINDOWS--
--LOAD--
2.4
--CPU--
8
--MEM--
MemTotal: 16777216
MemAvailable: 8388608
--SWAP--
SwapTotal: 4194304
SwapFree: 3145728
--DISK--
DiskTotal: 52428800
DiskAvailable: 26214400
--UPTIME--
86400
''', now: now);

    expect(stats, isNotNull);
    expect(stats!.collectorId, 'windows-powershell');
    expect(stats.loadAverage, 2.4);
    expect(stats.cpuCount, 8);
    expect(stats.memoryTotalKb, 16777216);
    expect(stats.memoryAvailableKb, 8388608);
    expect(stats.swapTotalKb, 4194304);
    expect(stats.swapFreeKb, 3145728);
    expect(stats.diskTotalKb, 52428800);
    expect(stats.diskAvailableKb, 26214400);
    expect(stats.uptime, const Duration(days: 1));
    expect(stats.updatedAt, now);
  });
  test('parses all NVIDIA GPUs and converts memory to KiB', () {
    final gpus = parseNvidiaGpuMetricsOutput('''
0, NVIDIA A100, 12.5, 1024, 40960, 45
1, NVIDIA A100, 0, 0, 40960, N/A
''');

    expect(gpus, hasLength(2));
    expect(gpus[0].index, 0);
    expect(gpus[0].name, 'NVIDIA A100');
    expect(gpus[0].utilizationPercent, 12.5);
    expect(gpus[0].memoryUsedKb, 1024 * 1024);
    expect(gpus[0].memoryTotalKb, 40960 * 1024);
    expect(gpus[0].temperatureC, 45);
    expect(gpus[1].index, 1);
    expect(gpus[1].temperatureC, isNull);
  });

  test('activity counters preserve direct Windows CPU utilization', () {
    final sample = ActivityCounters(
      at: DateTime(2026, 8, 8),
      cpuPercent: 37.5,
      memoryTotalKb: 100,
      memoryAvailableKb: 25,
    ).toSample();

    expect(sample.cpuPercent, 37.5);
    expect(sample.memoryUsedKb, 75);
  });

  test('parses Linux activity counters from the shared sections', () {
    final now = DateTime(2026, 8, 8);
    final counters = parseHostMetrics('''
--STAT--
cpu  100 5 50 800 20 1 2 0 0 0
--LOAD--
0.52 0.40 0.30 1/512 12345
--CPU--
8
--MEM--
MemTotal:       16384 kB
MemAvailable:    8192 kB
SwapTotal:       2048 kB
SwapFree:        1024 kB
--DISK--
/dev/sda1 100000 60000 40000 60% /
--NET--
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 999 1 0 0 0 0 0 0 999 1 0 0 0 0 0 0
  eth0: 1000 10 0 0 0 0 0 0 2000 20 0 0 0 0 0 0
  eth1: 500 5 0 0 0 0 0 0 700 7 0 0 0 0 0 0
--UPTIME--
3600
--GPU--
0, NVIDIA A100, 10, 1024, 40960, 45
1, NVIDIA A100, 30, 2048, 40960, 50
''', now: now).toActivityCounters(at: now);

    expect(counters.cpuIdle, 820);
    expect(counters.cpuTotal, 978);
    expect(counters.load1, 0.52);
    expect(counters.cpuCount, 8);
    expect(counters.memoryTotalKb, 16384);
    expect(counters.memoryAvailableKb, 8192);
    expect(counters.swapTotalKb, 2048);
    expect(counters.swapFreeKb, 1024);
    expect(counters.diskTotalKb, 100000);
    expect(counters.diskAvailableKb, 40000);
    expect(counters.netRxBytes, 1500);
    expect(counters.netTxBytes, 2700);
    expect(counters.uptime, const Duration(hours: 1));
    expect(counters.gpuPercent, 20);
    expect(counters.gpuMemoryUsedKb, 3072 * 1024);
    expect(counters.gpuMemoryTotalKb, 81920 * 1024);
  });

  test('parses macOS activity counters (kern.cp_time, netstat -ib)', () {
    final now = DateTime.fromMillisecondsSinceEpoch(2_000_000_000_000);
    final boot = now.millisecondsSinceEpoch ~/ 1000 - 600;
    final metrics = parseHostMetrics('''
--STAT--
100 5 50 10 800
--LOAD--
{ 1.25 0.75 0.50 }
--CPU--
10
--MEM--
17179869184
--VMSTAT--
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               100.
Pages inactive:                           200.
Pages speculative:                         50.
--SWAP--
total = 4096.00M  used = 1024.00M  free = 3072.00M
--DISK--
Filesystem 1024-blocks Used Available Capacity Mounted on
/dev/disk3s1 104857600 52428800 52428800 50% /
--NET--
Name  Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0   16384 <Link#1>                          100     0       9999      100     0       9999     0
en0   1500  <Link#4>      aa:bb:cc:dd:ee:ff  1000     0      50000      900     0      40000     0
en0   1500  192.168.1     192.168.1.2        1000     -      50000      900     -      40000     -
--UPTIME--
{ sec = $boot, usec = 0 } Mon Jan  1 00:00:00 2024
''', now: now);

    expect(metrics.cpuIdle, 800);
    expect(metrics.cpuTotal, 965);
    expect(metrics.load1, 1.25);
    expect(metrics.memoryTotalKb, 16 * 1024 * 1024);
    expect(metrics.memoryAvailableKb, 350 * 16);
    expect(metrics.swapTotalKb, 4096 * 1024);
    expect(metrics.swapFreeKb, 3072 * 1024);
    expect(metrics.diskAvailableKb, 52428800);
    expect(metrics.netRxBytes, 50000);
    expect(metrics.netTxBytes, 40000);
    expect(metrics.uptime, const Duration(minutes: 10));
  });

  test('parses Linux collector output with the same parser', () {
    final stats = parseLinuxMetricsOutput('''
--LOAD--
0.10 0.20 0.30 1/100 200
--CPU--
4
--MEM--
MemTotal:       1000 kB
MemAvailable:    400 kB
--DISK--
/dev/root 2000 1500 500 75% /
--GPU--
--UPTIME--
42
''');
    expect(stats, isNotNull);
    expect(stats!.collectorId, 'linux-procfs');
    expect(stats.loadAverage, 0.1);
    expect(stats.loadAverage15, 0.3);
    expect(stats.cpuCount, 4);
    expect(stats.memoryAvailableKb, 400);
    expect(stats.diskTotalKb, 2000);
    expect(stats.diskAvailableKb, 500);
    expect(stats.uptime, const Duration(seconds: 42));
  });

  test('Windows activity counters read swap, disk and network', () {
    final now = DateTime(2026, 8, 8);
    final counters = parseHostMetrics('''
--WINDOWS--
--CPUUSAGE--
37.5
--LOAD--
3
--CPU--
8
--MEM--
MemTotal: 16777216
MemAvailable: 8388608
--SWAP--
SwapTotal: 4194304
SwapFree: 3145728
--DISK--
DiskTotal: 52428800
DiskAvailable: 26214400
--NET--
RxBytes: 123
TxBytes: 456
--GPU--
--UPTIME--
86400
''', now: now).toActivityCounters(at: now);
    expect(counters.cpuPercent, 37.5);
    expect(counters.load1, 3);
    expect(counters.swapTotalKb, 4194304);
    expect(counters.diskAvailableKb, 26214400);
    expect(counters.netRxBytes, 123);
    expect(counters.netTxBytes, 456);
    expect(counters.uptime, const Duration(days: 1));
  });
}
