import 'package:get/get.dart';

import '../../../services/processing/processing_api.dart';
import '../controller/proposal_controller.dart';

/// Bindings for Proposal (S4). Registered only in bindings (AGENTS.md).
/// The controller gets the ProcessingApi interface so its analysing
/// state can run detectPersons on entry (Review 04 F1).
class ProposalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProposalController>(
      () => ProposalController(processingApi: Get.find<ProcessingApi>()),
    );
  }
}
