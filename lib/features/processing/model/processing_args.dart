import '../../../services/processing/processing_api.dart';

/// Route payloads for the processing flow. These DTOs are the navigation
/// boundary between Home → Processing → Result (and Result → Processing
/// for a keeper re-run); they carry file paths and job metadata only,
/// never photo content.
class ProcessingArgs {
  const ProcessingArgs({
    required this.photoPath,
    this.keepIds,
    this.removeItemIds,
    this.detachedBelongingIds,
    this.peopleToRemove,
    this.distractionsIncluded,
  });

  /// The picked photo on this device (full resolution, untouched).
  final String photoPath;

  /// Keeper override for a re-run (FR-11); null = automatic keeper.
  final List<int>? keepIds;

  /// Contract v3: ambiguous belongings the user included for removal.
  final List<int>? removeItemIds;

  /// Contract v3: attached belongings the user detached (protected).
  final List<int>? detachedBelongingIds;

  /// Confirmed counts for the S6 stage line (design X15): how many
  /// people this job removes and how many distractions the user
  /// included. Null when the job did not come from a confirmed
  /// proposal (direct processing / re-runs) — S6 then keeps the
  /// generic line, never an invented count.
  final int? peopleToRemove;
  final int? distractionsIncluded;
}

/// What a finished clean hands to the Result screen (S7).
class ProcessingOutcome {
  const ProcessingOutcome({
    required this.originalPath,
    required this.resultPath,
    required this.personsDetected,
    required this.keeperIds,
    required this.removedIds,
    required this.totalSeconds,
    required this.engineUsed,
    this.persons = const <DetectedPerson>[],
    this.itemsRemoved = 0,
    this.distractionsRemoved = 0,
  });

  final String originalPath;

  /// Session file holding the full-resolution result.
  final String resultPath;
  final int personsDetected;
  final List<int> keeperIds;
  final List<int> removedIds;
  final double totalSeconds;
  final String engineUsed;
  final List<DetectedPerson> persons;

  /// Ambiguous belongings the user included that were removed
  /// (Contract v3). Attached belongings are part of their person and
  /// are never counted here (design X16).
  final int itemsRemoved;

  /// Distractions the user included that were removed (Contract v3,
  /// Phase B) — named separately in the S7 summary (design X16).
  final int distractionsRemoved;

  /// True when the pipeline found nobody to take out (FR-06): the
  /// result screen shows the plain message and no save is possible.
  bool get nobodyRemoved => removedIds.isEmpty;
}
