/// How file transfers handle a destination entry that already exists.
enum TransferConflictMode {
  /// Keep the current behavior: write to `name (1).ext` instead of touching
  /// the existing entry.
  rename,

  /// Replace the existing destination entry.
  overwrite,

  /// Prompt the user per conflict while the transfer runs.
  ask,
}
