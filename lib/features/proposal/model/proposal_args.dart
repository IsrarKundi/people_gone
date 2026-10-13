import '../../../services/processing/processing_api.dart';

/// Navigation payload for Proposal (S4).
///
/// Two entry shapes:
/// - [ProposalArgs.forPhoto]: the golden path (Review 04 F1). Only the
///   picked photo's path travels; the proposal screen itself runs the
///   analysing state (ProcessingApi.detectPersons) on entry.
/// - [ProposalArgs.new]: a proposal that is already computed (golden
///   captures and tests seed a fixture proposal this way). The screen
///   populates immediately and never calls detectPersons.
class ProposalArgs {
  const ProposalArgs({required this.proposal}) : photoPath = null;

  const ProposalArgs.forPhoto({required this.photoPath}) : proposal = null;

  /// An already-computed proposal, or null when only [photoPath] was
  /// handed over and detection still has to run on entry.
  final DetectionProposal? proposal;

  /// The picked photo on this device (full resolution, untouched).
  final String? photoPath;
}
