/// Route payloads for the processing flow. These DTOs are the navigation
/// boundary between Home → Processing → Result (and Result → Processing
/// for a keeper re-run); they carry file paths and job metadata only,
/// never photo content.
class ProcessingArgs {
  const ProcessingArgs({required this.photoPath, this.keepIds});

  /// The picked photo on this device (full resolution, untouched).
  final String photoPath;

  /// Keeper override for a re-run (FR-11); null = automatic keeper.
  final List<int>? keepIds;
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
  });

  final String originalPath;

  /// Session file holding the full-resolution result.
  final String resultPath;
  final int personsDetected;
  final List<int> keeperIds;
  final List<int> removedIds;
  final double totalSeconds;
  final String engineUsed;

  /// True when the pipeline found nobody to take out (FR-06): the
  /// result screen shows the plain message and no save is possible.
  bool get nobodyRemoved => removedIds.isEmpty;
}
