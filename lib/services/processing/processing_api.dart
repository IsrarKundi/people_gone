import 'dart:typed_data';

import '../../core/utils/result.dart';

/// Processing API — the app's ONLY path to photo processing
/// (Requirements §6). The implementation talks to OUR processing server
/// (the dev worker today, the Supabase gateway in Phase 2); the app never
/// calls an AI/GPU vendor directly (AGENTS.md).
///
/// Contract v1 (modal-deploy/API_CONTRACT.md): one call does detection +
/// keeper choice + removal and returns the finished photo plus metadata.
/// The two-step analyse → proposal → confirm flow (§7.3) arrives with
/// the gateway's `/detect` endpoint (contract v1, "Not in v1" #2); until
/// then the proposal is the returned metadata and the keeper correction
/// is a free re-run with [keepIds] (FR-11).
abstract interface class ProcessingApi {
  /// Uploads the photo at [localPath] at full resolution and runs the
  /// full clean. [keepIds] overrides the automatic keeper choice
  /// (person ids to protect); null = automatic.
  /// [onUploadProgress] receives the real upload fraction (0.0–1.0).
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    void Function(double fraction)? onUploadProgress,
  });

  /// Cancels the in-flight [processPhoto] call, if any. Cancelling
  /// consumes nothing (FR-07). The app runs one job at a time.
  void cancelOngoing();
}

/// A finished clean (S7). The result is returned as bytes and written to
/// a session file by the caller — full-resolution bitmaps are never held
/// decoded in Dart memory (NFR-03); the compressed bytes are the file.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.resultBytes,
    required this.personsDetected,
    required this.keeperIds,
    required this.removedIds,
    required this.cropsInpainted,
    required this.totalSeconds,
    required this.engineUsed,
  });

  /// Full-resolution result JPEG bytes; dimensions equal the input's.
  final Uint8List resultBytes;

  /// People the pipeline found in the photo.
  final int personsDetected;

  /// Person ids that were protected (never modified).
  final List<int> keeperIds;

  /// Person ids that were removed.
  final List<int> removedIds;

  final int cropsInpainted;
  final double totalSeconds;
  final String engineUsed;
}
