import 'package:get/get.dart';

import '../../config/app_config.dart';
import '../../services/processing/processing_api.dart';
import '../../services/processing/processing_api_impl.dart';

/// Registers global services (interfaces → implementations), permanent.
/// The ONLY place global `Get.put` lives (Conventions §1.2 / §7 rule 2).
/// Other services join as their implementations land (storage: Task 1.2,
/// purchases: Task 3.1).
class InitialBinding extends Bindings {
  InitialBinding(this.config);

  final AppConfig config;

  @override
  void dependencies() {
    Get.put<ProcessingApi>(
      ProcessingApiImpl(config: config),
      permanent: true,
    );
  }
}
