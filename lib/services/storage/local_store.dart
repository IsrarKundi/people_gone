import '../../core/utils/result.dart';

/// Local storage — interface only in Phase 1 (Conventions §1.2). The
/// implementation (`local_store_impl.dart`, the only file that may import
/// `path_provider` / `flutter_secure_storage`) lands with Task 1.2.
/// History lives only on this phone (Requirements S9).
abstract interface class LocalStore {
  /// All history entries, newest first.
  Future<Result<List<HistoryEntry>>> history();

  /// Records a saved result in history.
  Future<Result<void>> addHistory(HistoryEntry entry);

  /// Deletes one history entry's local file + index record.
  Future<Result<void>> deleteHistory(String id);

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

  final String id;
  final String localPath;
  final DateTime savedAt;
}
