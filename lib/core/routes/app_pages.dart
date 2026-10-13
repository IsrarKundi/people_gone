import 'package:get/get.dart';

import '../../features/home/binding/home_binding.dart';
import '../../features/home/view/home_view.dart';
import '../../features/processing/binding/processing_binding.dart';
import '../../features/processing/view/processing_view.dart';
import '../../features/result/binding/result_binding.dart';
import '../../features/result/view/result_view.dart';
import 'app_routes.dart';

/// All route wiring (Conventions §1.2). Features join this list as their
/// tasks land.
abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.processing,
      page: () => const ProcessingView(),
      binding: ProcessingBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.result,
      page: () => const ResultView(),
      binding: ResultBinding(),
    ),
  ];
}
