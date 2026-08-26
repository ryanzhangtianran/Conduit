import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'file_management_models.dart';
import 'file_system_backend.dart';

/// The operations a context menu can trigger on the file manager. The tab
/// state implements this so the menus stay free of widget internals.
abstract interface class FileManagerMenuHost {
  FilePaneState paneFor(FileSide side);
  FilePaneState otherPane(FilePaneState pane);
  int get tabServerId;
  String get tabServerName;
  String serverNameFor(int serverId);

  Future<void> refresh(FilePaneState pane);
  Future<void> openDirectory(FilePaneState pane, String path);
  bool canGoUp(FilePaneState pane);
  Future<void> goUp(FilePaneState pane);
  Future<void> chooseLocalDirectory();

  void ensureContextSelection(FilePaneState pane, FileEntry entry, int index);
  FileClipboardEntry clipboardEntryFor(FilePaneState pane, FileEntry entry);
  List<FileClipboardEntry> selectionEntries(FilePaneState pane);
  void setClipboard(ClipboardMode mode);
  bool canPasteInto(FilePaneState pane);
  Future<void> pasteInto(FilePaneState pane);
  Future<void> transferSelection(FilePaneState pane);

  Future<void> renameEntry(FileClipboardEntry entry);
  Future<void> createFolder(FilePaneState pane);
  Future<void> deleteSelection();
  Future<void> extractArchive(FilePaneState pane, FileClipboardEntry entry);
  Future<void> archiveEntries(
    FilePaneState pane,
    List<FileClipboardEntry> entries,
    ArchiveFormat format,
  );
  Future<void> editEntry(FilePaneState pane, FileEntry entry);
}

/// Label of the "send to the other pane" action for [count] entries.
String _transferLabel(FileManagerMenuHost host, FilePaneState pane, int count) {
  final other = host.otherPane(pane);
  if (other.isLocal) {
    return count == 1
        ? 'fileManagerDownloadToLocal'.tr()
        : 'fileManagerDownloadItems'.tr(args: ['$count']);
  }
  if (pane.isLocal && other.serverId == host.tabServerId) {
    return count == 1
        ? 'fileManagerUploadToRemote'.tr()
        : 'fileManagerUploadItems'.tr(args: ['$count']);
  }
  final name = other.serverId == host.tabServerId
      ? host.tabServerName
      : host.serverNameFor(other.serverId!);
  return count == 1
      ? 'fileManagerTransferToServer'.tr(args: [name])
      : 'fileManagerTransferItemsToServer'.tr(args: ['$count', name]);
}

/// Right-click menu for one row. Applies to the whole selection when the row
/// is part of it.
Menu buildEntryMenu(
  FileManagerMenuHost host,
  FilePaneState pane,
  FileEntry entry,
  int index,
) {
  final selected = host.selectionEntries(pane);
  final entries = selected.isEmpty
      ? [host.clipboardEntryFor(pane, entry)]
      : selected;
  final onlyThis = entries.length == 1 && entries.first.path == entry.path;
  final busy = pane.busy;
  void prepare() => host.ensureContextSelection(pane, entry, index);

  return Menu(
    children: [
      if (onlyThis && entry.isDirectory)
        MenuAction(
          title: 'fileManagerOpen'.tr(),
          callback: () => host.openDirectory(pane, entry.path),
        ),
      if (onlyThis && entry.isFile)
        MenuAction(
          title: 'fileManagerEdit'.tr(),
          callback: () => host.editEntry(pane, entry),
        ),
      MenuAction(
        title: _transferLabel(host, pane, entries.length),
        callback: () {
          prepare();
          host.transferSelection(pane);
        },
      ),
      if (!pane.isLocal) ...[
        MenuSeparator(),
        if (onlyThis && entry.isFile && isSupportedArchive(entry.name))
          MenuAction(
            title: 'fileManagerUnarchiveHere'.tr(),
            attributes: MenuActionAttributes(disabled: busy),
            callback: () => host.extractArchive(pane, entries.first),
          ),
        MenuAction(
          title: 'fileManagerArchiveAsZip'.tr(),
          attributes: MenuActionAttributes(disabled: busy),
          callback: () => host.archiveEntries(pane, entries, ArchiveFormat.zip),
        ),
        MenuAction(
          title: 'fileManagerArchiveAsTarGz'.tr(),
          attributes: MenuActionAttributes(disabled: busy),
          callback: () =>
              host.archiveEntries(pane, entries, ArchiveFormat.tarGzip),
        ),
      ],
      MenuSeparator(),
      MenuAction(
        title: 'commonCopy'.tr(),
        activator: const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
        callback: () {
          prepare();
          host.setClipboard(ClipboardMode.copy);
        },
      ),
      MenuAction(
        title: 'fileManagerCut'.tr(),
        activator: const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
        callback: () {
          prepare();
          host.setClipboard(ClipboardMode.cut);
        },
      ),
      MenuAction(
        title: 'fileManagerPaste'.tr(),
        attributes: MenuActionAttributes(disabled: !host.canPasteInto(pane)),
        activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
        callback: () => host.pasteInto(pane),
      ),
      if (onlyThis)
        MenuAction(
          title: 'fileManagerRename'.tr(),
          attributes: MenuActionAttributes(disabled: busy),
          callback: () {
            prepare();
            host.renameEntry(host.clipboardEntryFor(pane, entry));
          },
        ),
      MenuSeparator(),
      MenuAction(
        title: entries.length == 1
            ? 'commonDelete'.tr()
            : 'fileManagerDeleteItems'.tr(args: ['${entries.length}']),
        attributes: MenuActionAttributes(destructive: true, disabled: busy),
        activator: const SingleActivator(LogicalKeyboardKey.backspace),
        callback: () {
          prepare();
          host.deleteSelection();
        },
      ),
    ],
  );
}

/// Right-click menu on the empty area of a pane.
Menu buildPaneBackgroundMenu(FileManagerMenuHost host, FilePaneState pane) {
  return Menu(
    children: [
      MenuAction(
        title: 'fileManagerCreateFolder'.tr(),
        attributes: MenuActionAttributes(disabled: pane.busy),
        callback: () => host.createFolder(pane),
      ),
      MenuAction(
        title: 'fileManagerPaste'.tr(),
        attributes: MenuActionAttributes(disabled: !host.canPasteInto(pane)),
        activator: const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
        callback: () => host.pasteInto(pane),
      ),
      MenuSeparator(),
      MenuAction(
        title: 'fileManagerGoUp'.tr(),
        attributes: MenuActionAttributes(disabled: !host.canGoUp(pane)),
        callback: () => host.goUp(pane),
      ),
      if (pane.isLocal)
        MenuAction(
          title: 'fileManagerChooseFolder'.tr(),
          callback: host.chooseLocalDirectory,
        ),
      MenuAction(
        title: 'commonRefresh'.tr(),
        callback: () => host.refresh(pane),
      ),
    ],
  );
}
