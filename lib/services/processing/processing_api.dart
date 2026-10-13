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
  /// Stage A analysis: uploads the photo at [localPath] at full resolution
  /// and runs person detection + keeper heuristic. Returns the detected
  /// person instances, bounding boxes, and initial keep/remove proposal.
  Future<Result<DetectionProposal>> detectPersons({
    required String localPath,
    void Function(double fraction)? onUploadProgress,
  });

  /// Uploads the photo at [localPath] at full resolution and runs the
  /// full clean. [keepIds] overrides the automatic keeper choice
  /// (person ids to protect); null = automatic.
  /// [onUploadProgress] receives the real upload fraction (0.0–1.0).
  Future<Result<ProcessedPhoto>> processPhoto({
    required String localPath,
    List<int>? keepIds,
    void Function(double fraction)? onUploadProgress,
  });

  /// Brush touch-up (FR-09 / S5): inpaints ONLY the region painted in
  /// [maskPng] (a PNG the size of the photo at [localPath]) on that
  /// photo and returns the updated photo. Pixels outside the mask are
  /// returned identical (composite-only paste, §6.4 step 6 pattern).
  /// A touch-up never consumes a save (it repairs the current result).
  Future<Result<TouchupOutcome>> touchupPhoto({
    required String localPath,
    required Uint8List maskPng,
    void Function(double fraction)? onUploadProgress,
  });

  /// The save-time credit gate (§7.3): atomically consumes ONE save
  /// credit for the result the user is saving, in the SERVER ledger.
  /// Processing, cancelling and failed jobs never consume (§9.1).
  /// [idempotencyKey] makes a retried Save consume at most once.
  /// Only the gateway implementation has a ledger; the direct dev
  /// implementation fails loudly so a misconfigured build can never
  /// silently skip the gate.
  Future<Result<SaveCreditDecision>> consumeSaveCredit({
    required String idempotencyKey,
  });

  /// Compensates a credit consumed by [consumeSaveCredit] when the
  /// local save it paid for could not be completed (§7.2: a failed
  /// delivery refunds automatically). Idempotent on the same key.
  Future<Result<void>> refundSaveCredit({required String idempotencyKey});

  /// Cancels the in-flight processing or detection call, if any.
  /// Cancelling consumes nothing (FR-07). The app runs one job at a time.
  void cancelOngoing();
}

/// A person instance detected in the photo (S4 / S7).
class DetectedPerson {
  const DetectedPerson({
    required this.id,
    required this.box,
    required this.score,
    required this.isKeeper,
  });

  /// Person index in the detection list.
  final int id;

  /// Bounding box in pixel coordinates [x1, y1, x2, y2].
  final List<int> box;

  final double score;

  /// True if classified as keeper / subject, false if proposed for removal.
  final bool isKeeper;

  DetectedPerson copyWith({bool? isKeeper}) => DetectedPerson(
    id: id,
    box: box,
    score: score,
    isKeeper: isKeeper ?? this.isKeeper,
  );
}

/// Initial proposal returned by Stage A (/detect).
class DetectionProposal {
  const DetectionProposal({
    required this.photoPath,
    required this.personsDetected,
    required this.keeperIds,
    required this.removedIds,
    required this.persons,
    required this.inputDimensions,
  });

  final String photoPath;
  final int personsDetected;
  final List<int> keeperIds;
  final List<int> removedIds;
  final List<DetectedPerson> persons;
  final List<int> inputDimensions;
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
    this.persons = const <DetectedPerson>[],
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

  /// Detected person instances with bounding boxes, if returned by server.
  final List<DetectedPerson> persons;
}

/// Outcome of a brush touch-up (S5 / FR-09): the updated photo bytes,
/// written over the current result by the caller (session file pattern,
/// same as [ProcessedPhoto]).
class TouchupOutcome {
  const TouchupOutcome({
    required this.resultBytes,
    required this.engineUsed,
    required this.totalSeconds,
  });

  /// Full-resolution result JPEG bytes; dimensions equal the input's.
  final Uint8List resultBytes;
  final String engineUsed;
  final double totalSeconds;
}

/// The server ledger's answer at Save time (§7.3): the credit was
/// consumed ([allowed]) or the user must pay first
/// ([paymentRequired] -> S8). [savesLeft] is the server's free-tier
/// count AFTER the decision; null for Pro (fair-use governed, §9.4).
class SaveCreditDecision {
  const SaveCreditDecision({
    required this.allowed,
    required this.paymentRequired,
    required this.isPro,
    this.savesLeft,
  });

  final bool allowed;
  final bool paymentRequired;
  final bool isPro;
  final int? savesLeft;
}
