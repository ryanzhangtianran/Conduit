/// App-wide value formatters and path helpers.
///
/// Every page that shows sizes, memory, uptime or remote paths must use these
/// instead of a private copy so the same value renders the same everywhere.
library;

const _units = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Formats a byte count as a human-readable size (`1.5 KB`, `12 MB`).
///
/// Returns `—` for a null count so callers can pass unknown sizes through.
String formatBytes(int? bytes) {
  if (bytes == null) return '—';
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < _units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final precision = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(precision)} ${_units[unit]}';
}

/// Formats a memory figure given in kibibytes as `MB` or `GB`.
String formatKilobytes(int kilobytes) {
  const kbPerGb = 1024 * 1024;
  return kilobytes >= kbPerGb
      ? '${(kilobytes / kbPerGb).toStringAsFixed(1)} GB'
      : '${(kilobytes / 1024).toStringAsFixed(0)} MB';
}

/// Formats an uptime as `3d 4h`, `4h 12m` or `12m`; `—` when unknown.
String formatUptime(Duration? uptime) {
  if (uptime == null || uptime.inSeconds == 0) return '—';
  final days = uptime.inDays;
  final hours = uptime.inHours.remainder(24);
  final minutes = uptime.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// Joins a POSIX directory and entry name without doubling the root slash.
String joinRemotePath(String directory, String name) =>
    directory == '/' ? '/$name' : '$directory/$name';

/// Returns the parent of a POSIX path; the root is its own parent.
String parentRemotePath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final normalized = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final index = normalized.lastIndexOf('/');
  if (index <= 0) return '/';
  return normalized.substring(0, index);
}

/// Lower-cased extension of a file name without the dot, or `''`.
String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}
