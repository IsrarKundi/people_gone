import 'package:get/get.dart';

import '../../features/home/binding/home_binding.dart';
import '../../features/home/view/home_view.dart';
import 'app_routes.dart';

/// All route wiring (Conventions §1.2). Features join this list as their
/// tasks land (Task 1.2+: processing/proposal/result/history/settings).
abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
  ];
}
