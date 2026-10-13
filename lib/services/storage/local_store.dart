import 'dart:typed_data';

import '../../core/utils/result.dart';

/// Local storage (Conventions §1.2). The implementation
/// (`local_store_impl.dart`) is the only file that may import
/// `path_provider` / `flutter_secure_storage` / `gal`.
/// History lives only on this phone (Requirements S9).
///
/// Free-saves note: in production the server ledger is the only source of
/// truth (§7.2); this on-device counter is the display hint (§5 FR-20)
/// and, until the gateway lands (Phase 2), the dev build's counter.
abstract interface class LocalStore {
  /// All history entries, newest first.
  Future<Result<List<HistoryEntry>>> history();

  /// Records a saved result in history.
  Future<Result<void>> addHistory(HistoryEntry entry);

  /// Deletes one history entry's local file + index record.
  Future<Result<void>> deleteHistory(String id);

  /// Copies a session result file into the history folder and returns
  /// the history-owned path (the session file may be cleaned up later;
  /// history files are never shared with the session).
  Future<Result<String>> adoptIntoHistory(String sessionPath, String id);

  /// Writes processed result bytes to a session file and returns its
  /// path. Session files are working copies (share/save source), not
  /// history.
  Future<Result<String>> writeSessionResult(Uint8List bytes);

  /// Saves [localPath] into the device photo library (the platform save
  /// flow: MediaStore on Android, add-only Photos on iOS).
  Future<Result<void>> saveToGallery(String localPath);

  /// Free saves consumed in the current calendar month (UTC).
  Future<Result<int>> freeSavesUsed();

  /// When the free-saves counter resets: the first day of the next
  /// calendar month (UTC) — the moment the counter's period key rolls
  /// over. Settings displays this computed date (Design Direction
  /// §4 S10; Review 02 A6).
  Future<Result<DateTime>> freeSavesResetDate();

  /// Records one consumed free save (called ONLY at the moment of a
  /// successful save — never at processing, FR-16).
  Future<Result<void>> consumeFreeSave();

  /// Consent version the user accepted, or null if never shown.
  Future<Result<int?>> acceptedConsentVersion();

  /// Records acceptance of [version].
  Future<Result<void>> setAcceptedConsentVersion(int version);
}

/// One saved clean photo in on-device history.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.localPath,
    required this.savedAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      localPath: json['localPath'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  final String id;
  final String localPath;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'localPath': localPath,
    'savedAt': savedAt.toIso8601String(),
  };
}
