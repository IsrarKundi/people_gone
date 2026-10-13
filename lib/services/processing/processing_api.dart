import '../../core/utils/result.dart';

/// Processing API — the app's ONLY path to photo processing
/// (Requirements §6). The implementation talks to OUR gateway; the app
/// never calls an AI/GPU vendor directly (AGENTS.md).
abstract interface class ProcessingApi {
  /// Uploads the photo at [localPath] and returns the analysis proposal
  /// (detected people + keeper proposal) for the Proposal screen (S4).
  Future<Result<JobProposal>> analysePhoto(String localPath);

  /// Runs removal for [jobId] with the confirmed [removeIds]; returns the
  /// finished job for the Result screen (S7).
  Future<Result<JobResult>> removePeople(String jobId, List<int> removeIds);
}

/// One detected person in a proposal. Coordinates are relative to the
/// photo (0.0–1.0) so masks render in photo coordinates at any size
/// (Design Direction §4, S4).
class DetectedPerson {
  const DetectedPerson({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.proposedKeeper,
  });

  final int id;
  final double left;
  final double top;
  final double width;
  final double height;

  /// True when the pipeline proposes protecting this person (the subject).
  final bool proposedKeeper;
}

/// Analysis proposal for one job (S4).
class JobProposal {
  const JobProposal({required this.jobId, required this.people});

  final String jobId;
  final List<DetectedPerson> people;
}

/// A finished removal job (S7). [resultLocalPath] is the full-resolution
/// result on this device — output dimensions always equal input dimensions.
class JobResult {
  const JobResult({required this.jobId, required this.resultLocalPath});

  final String jobId;
  final String resultLocalPath;
}
