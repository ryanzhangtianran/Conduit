import 'package:material_ui/material_ui.dart';

import 'file_system_backend.dart';
import 'file_transfer_queue.dart';

/// The two panes of the file manager. The left pane shows either the local
/// disk or another server; the right pane always shows the tab's server.
enum FileSide { left, right }

enum ClipboardMode { copy, cut }

enum ArchiveFormat { zip, tarGzip }

/// A file or folder captured for copy/cut/drag, tagged with where it lives.
class FileClipboardEntry {
  const FileClipboardEntry({
    required this.side,
    required this.endpoint,
    required this.path,
    required this.name,
    required this.isDirectory,
    this.size,
  });

  final FileSide side;
  final TransferEndpoint endpoint;
  final String path;
  final String name;
  final bool isDirectory;
  final int? size;
}

class FileClipboard {
  const FileClipboard({required this.mode, required this.entries});

  final ClipboardMode mode;
  final List<FileClipboardEntry> entries;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
}

class FileDragData {
  const FileDragData({required this.side, required this.entries});

  final FileSide side;
  final List<FileClipboardEntry> entries;
}

/// Everything one pane needs to render and navigate: where it points, what it
/// lists, what is selected, and its text/scroll controllers. The tab owns two
/// of these and every operation is written once against this type.
class FilePaneState {
  FilePaneState({
    required this.side,
    required this.endpoint,
    required String path,
  }) : _path = path,
       pathController = TextEditingController(text: path),
       pathFocusNode = FocusNode(debugLabel: 'file-pane-${side.name}-path'),
       searchController = TextEditingController(),
       searchFocusNode = FocusNode(debugLabel: 'file-pane-${side.name}-search');

  final FileSide side;

  /// Local disk or a server; the left pane can switch at runtime.
  TransferEndpoint endpoint;

  String _path;
  String get path => _path;
  set path(String value) {
    _path = value;
    if (!pathFocusNode.hasFocus) pathController.text = value;
  }

  List<FileEntry> entries = const [];
  Set<String> selectedPaths = {};
  int? anchorIndex;
  var loading = false;
  String? error;

  /// Label of the quick operation (rename, new folder, archive…) currently
  /// running on this pane. Transfers never set this: they live in the queue.
  String? busyLabel;
  bool get busy => busyLabel != null;

  var searchOpen = false;
  final TextEditingController pathController;
  final FocusNode pathFocusNode;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ScrollController scrollController = ScrollController();

  bool get isLocal => endpoint.isLocal;
  int? get serverId => endpoint.serverId;

  String get searchQuery => searchController.text.trim().toLowerCase();

  List<FileEntry> get displayedEntries {
    final query = searchQuery;
    if (query.isEmpty) return entries;
    return [
      for (final entry in entries)
        if (entry.name.toLowerCase().contains(query)) entry,
    ];
  }

  FileEntry? entryAt(String path) =>
      entries.where((entry) => entry.path == path).firstOrNull;

  List<FileEntry> get selectedEntries => [
    for (final entry in entries)
      if (selectedPaths.contains(entry.path)) entry,
  ];

  void clearSelection() {
    selectedPaths = {};
    anchorIndex = null;
  }

  /// Points the pane at a new location, dropping selection and errors.
  void navigate(TransferEndpoint endpoint, String path) {
    this.endpoint = endpoint;
    this.path = path;
    entries = const [];
    error = null;
    clearSelection();
  }

  void dispose() {
    pathController.dispose();
    pathFocusNode.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    scrollController.dispose();
  }
}

/// Quotes [value] for a POSIX shell.
String shellQuote(String value) => "'${value.replaceAll("'", "'\\\"'\\\"'")}'";

bool isSupportedArchive(String filename) {
  final name = filename.toLowerCase();
  return name.endsWith('.zip') ||
      name.endsWith('.tar.gz') ||
      name.endsWith('.tgz');
}
