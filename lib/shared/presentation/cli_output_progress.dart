/// Parses docker/podman-style CLI progress from streamed stdout/stderr.
///
/// Handles:
/// - layer lines: `abc123: Downloading [====>]  12.5MB/40MB`
/// - layer percent: `abc123: Extracting [====>]  42.5%`
/// - layer done: `abc123: Pull complete`
/// - compose counters: `[+] Pulling 3/8`
/// - bare percentages: `65.2%`
class CliOutputProgressTracker {
  final Map<String, double> _layers = {};
  double? _composeRatio;
  double? _barePercent;
  int _barePercentCount = 0;
  String? detail;

  /// Overall progress in `0..1`, or null when still unknown.
  double? get progress {
    if (_layers.isNotEmpty) {
      final sum = _layers.values.fold<double>(0, (a, b) => a + b);
      return (sum / _layers.length).clamp(0.0, 1.0);
    }
    if (_composeRatio != null) return _composeRatio!.clamp(0.0, 1.0);
    if (_barePercent != null) return _barePercent!.clamp(0.0, 1.0);
    return null;
  }

  void reset() {
    _layers.clear();
    _composeRatio = null;
    _barePercent = null;
    _barePercentCount = 0;
    detail = null;
  }

  /// Call when the remote command has exited so the bar fills even if the
  /// stream never reported a final 100% (common for multi-layer pulls).
  void markFinished() {
    if (_layers.isNotEmpty) {
      for (final key in _layers.keys.toList()) {
        _layers[key] = 1;
      }
    }
    _composeRatio = 1;
    _barePercent = 1;
    _barePercentCount = _barePercentCount == 0 ? 1 : _barePercentCount;
    detail = '100%';
  }

  /// Feed a raw CLI chunk (may contain ANSI, CR, partial lines).
  void ingest(String chunk) {
    if (chunk.isEmpty) return;
    final plain = stripAnsi(chunk);
    // CR updates rewrite the current line — split on both newline and CR so
    // each progress rewrite is parsed independently.
    final segments = plain
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    // Bare % values from this chunk are averaged together (multi-service pull
    // frames often print several percentages at once).
    final bareBatch = <double>[];
    for (final segment in segments) {
      _ingestLine(segment, bareBatch);
    }
    if (bareBatch.isNotEmpty) {
      _barePercent = bareBatch.reduce((a, b) => a + b) / bareBatch.length;
      _barePercentCount = bareBatch.length;
    }
    _refreshDetail();
  }

  void _ingestLine(String line, List<double> bareBatch) {
    final done = _layerDone.firstMatch(line);
    if (done != null) {
      _layers[done.group(1)!] = 1;
      return;
    }

    final sized = _layerSized.firstMatch(line);
    if (sized != null) {
      final current = _parseBytes(sized.group(2)!, sized.group(3)!);
      final total = _parseBytes(sized.group(4)!, sized.group(5)!);
      if (total > 0) {
        _layers[sized.group(1)!] = (current / total).clamp(0.0, 1.0);
      }
      return;
    }

    final layeredPct = _layerPercent.firstMatch(line);
    if (layeredPct != null) {
      final pct = double.tryParse(layeredPct.group(2)!);
      if (pct != null) {
        _layers[layeredPct.group(1)!] = (pct / 100).clamp(0.0, 1.0);
      }
      return;
    }

    final seen = _layerSeen.firstMatch(line);
    if (seen != null) {
      _layers.putIfAbsent(seen.group(1)!, () => 0);
      return;
    }

    final compose = _composeCounter.firstMatch(line);
    if (compose != null) {
      final doneCount = int.tryParse(compose.group(1)!);
      final totalCount = int.tryParse(compose.group(2)!);
      if (doneCount != null && totalCount != null && totalCount > 0) {
        _composeRatio = (doneCount / totalCount).clamp(0.0, 1.0);
        detail = '$doneCount / $totalCount';
      }
      return;
    }

    // Collect every bare percentage on the line; [ingest] averages the batch.
    for (final match in _barePercentPattern.allMatches(line)) {
      final pct = double.tryParse(match.group(1)!);
      if (pct == null) continue;
      bareBatch.add((pct / 100).clamp(0.0, 1.0));
    }
  }

  void _refreshDetail() {
    if (_layers.isNotEmpty) {
      final complete = _layers.values.where((v) => v >= 0.999).length;
      detail = '$complete / ${_layers.length} layers';
      return;
    }
    if (_composeRatio != null && detail != null) return;
    if (_barePercent != null) {
      final pct = (_barePercent! * 100).round();
      detail = _barePercentCount > 1
          ? 'avg $pct% ($_barePercentCount)'
          : '$pct%';
    }
  }

  /// Terminal layer states only. Intermediate "Download complete" is not final
  /// because extract can still follow and report a lower percentage.
  static final _layerDone = RegExp(
    r'^([a-f0-9]{6,64}):\s+(Pull complete|Already exists)',
    caseSensitive: false,
  );

  /// Intermediate layer status — registers the layer at 0% if new.
  static final _layerSeen = RegExp(
    r'^([a-f0-9]{6,64}):\s+'
    r'(Pulling fs layer|Waiting|Verifying Checksum|Downloading|Extracting|'
    r'Pull complete|Already exists)',
    caseSensitive: false,
  );

  static final _layerSized = RegExp(
    r'([a-f0-9]{6,64}):\s+[A-Za-z ]+?\s+\[[^\]]*\]\s+'
    r'([\d.]+)\s*([kKmMgGtT]i?[bB])\s*/\s*([\d.]+)\s*([kKmMgGtT]i?[bB])',
  );

  static final _layerPercent = RegExp(
    r'([a-f0-9]{6,64}):\s+[A-Za-z ]+?\s+\[[^\]]*\]\s+([\d.]+)\s*%',
  );

  static final _composeCounter = RegExp(
    r'(?:Pulling|pull|Pulled|Building|build)\s+(\d+)\s*/\s*(\d+)',
    caseSensitive: false,
  );

  static final _barePercentPattern = RegExp(r'(\d+(?:\.\d+)?)\s*%');
}

/// Removes CSI / OSC ANSI sequences so progress parsers see plain text.
String stripAnsi(String input) {
  return input
      .replaceAll(RegExp(r'\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'), '')
      .replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '')
      .replaceAll(RegExp(r'\x1B[()][0-9A-Za-z]'), '')
      .replaceAll(RegExp(r'\x1B.'), '');
}

double _parseBytes(String raw, String unit) {
  final value = double.tryParse(raw) ?? 0;
  final normalized = unit.toLowerCase();
  final multiplier = switch (normalized) {
    'b' => 1.0,
    'kb' || 'k' => 1000.0,
    'kib' => 1024.0,
    'mb' || 'm' => 1e6,
    'mib' => 1024.0 * 1024,
    'gb' || 'g' => 1e9,
    'gib' => 1024.0 * 1024 * 1024,
    'tb' || 't' => 1e12,
    'tib' => 1024.0 * 1024 * 1024 * 1024,
    _ => 1.0,
  };
  return value * multiplier;
}
