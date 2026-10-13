import 'package:get/get.dart';

import '../controller/proposal_controller.dart';

/// Bindings for Proposal (S4). Registered only in bindings (AGENTS.md).
class ProposalBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProposalController>(() => ProposalController());
  }
}
