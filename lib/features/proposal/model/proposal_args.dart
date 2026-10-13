import '../../../services/processing/processing_api.dart';

/// Navigation payload for Proposal (S4).
class ProposalArgs {
  const ProposalArgs({required this.proposal});

  final DetectionProposal proposal;
}
