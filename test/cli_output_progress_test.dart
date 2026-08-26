import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/shared/presentation/cli_output_progress.dart';

void main() {
  group('CliOutputProgressTracker', () {
    test('parses layer size ratios from docker pull lines', () {
      final tracker = CliOutputProgressTracker()
        ..ingest(
          'a1b2c3d4e5f6: Downloading [====>    ]  10MB/40MB\n'
          'b2c3d4e5f6a1: Downloading [========>]  20MB/20MB\n',
        );

      expect(tracker.progress, closeTo(0.625, 0.001)); // (0.25 + 1.0) / 2
      expect(tracker.detail, '1 / 2 layers');
    });

    test('parses layer percentage and carriage-return rewrites', () {
      final tracker = CliOutputProgressTracker()
        ..ingest('deadbeef: Extracting [==>]  10%\r')
        ..ingest('deadbeef: Extracting [====>]  55%\r')
        ..ingest('deadbeef: Extracting [========>]  100%\r\n');

      expect(tracker.progress, closeTo(1.0, 0.001));
    });

    test('marks completed layers as finished', () {
      final tracker = CliOutputProgressTracker()
        ..ingest('aaaaaaaaaaaa: Pulling fs layer\n')
        ..ingest('bbbbbbbbbbbb: Pulling fs layer\n')
        ..ingest('aaaaaaaaaaaa: Pull complete\n');

      expect(tracker.progress, closeTo(0.5, 0.001));
      expect(tracker.detail, '1 / 2 layers');
    });

    test('parses compose pull counters', () {
      final tracker = CliOutputProgressTracker()..ingest('[+] Pulling 3/8\n');

      expect(tracker.progress, closeTo(3 / 8, 0.001));
      expect(tracker.detail, '3 / 8');
    });

    test('strips ANSI before parsing bare percentages', () {
      final tracker = CliOutputProgressTracker()
        ..ingest('\x1B[32mDownloading\x1B[0m  42.5%\n');

      expect(tracker.progress, closeTo(0.425, 0.001));
    });

    test('averages multiple bare percentages in one chunk', () {
      final tracker = CliOutputProgressTracker()
        ..ingest(
          'redis     Pulling  20%\n'
          'postgres  Pulling  40%\n'
          'nginx     Pulling  60%\n',
        );

      // (0.20 + 0.40 + 0.60) / 3
      expect(tracker.progress, closeTo(0.40, 0.001));
      expect(tracker.detail, 'avg 40% (3)');
    });

    test('averages multiple percentages on a single line', () {
      final tracker = CliOutputProgressTracker()
        ..ingest('download 10% extract 30% write 50%\n');

      expect(tracker.progress, closeTo(0.30, 0.001));
      expect(tracker.detail, 'avg 30% (3)');
    });

    test('averages multiple layer percentages', () {
      final tracker = CliOutputProgressTracker()
        ..ingest(
          'aaaaaaaaaaaa: Downloading [=>]  25%\n'
          'bbbbbbbbbbbb: Downloading [=>]  75%\n',
        );

      expect(tracker.progress, closeTo(0.50, 0.001));
      expect(tracker.detail, '0 / 2 layers');
    });

    test('prefers layer average over bare percent when both exist', () {
      final tracker = CliOutputProgressTracker()
        ..ingest('abc123def456: Downloading [=>]  5MB/10MB\n')
        ..ingest('overall 90%\n');

      expect(tracker.progress, closeTo(0.5, 0.001));
    });

    test('markFinished treats all progress as 100%', () {
      final tracker = CliOutputProgressTracker()
        ..ingest(
          'aaaaaaaaaaaa: Downloading [=>]  25%\n'
          'bbbbbbbbbbbb: Downloading [=>]  50%\n',
        )
        ..markFinished();

      expect(tracker.progress, closeTo(1.0, 0.001));
      expect(tracker.detail, '100%');
    });
  });

  test('stripAnsi removes CSI sequences', () {
    expect(stripAnsi('\x1B[31mred\x1B[0m'), 'red');
  });
}
