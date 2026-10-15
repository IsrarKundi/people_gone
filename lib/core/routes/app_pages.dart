import 'package:get/get.dart';

import '../../features/brush/binding/brush_binding.dart';
import '../../features/brush/view/brush_view.dart';
import '../../features/history/binding/history_binding.dart';
import '../../features/history/view/history_detail_view.dart';
import '../../features/history/view/history_view.dart';
import '../../features/home/binding/home_binding.dart';
import '../../features/home/view/home_view.dart';
import '../../features/picker/binding/picker_binding.dart';
import '../../features/processing/binding/processing_binding.dart';
import '../../features/processing/view/processing_view.dart';
import '../../features/proposal/binding/proposal_binding.dart';
import '../../features/proposal/view/proposal_view.dart';
import '../../features/result/binding/result_binding.dart';
import '../../features/result/view/result_view.dart';
import '../../features/settings/binding/settings_binding.dart';
import '../../features/settings/view/diagnostics_view.dart';
import '../../features/settings/view/settings_view.dart';
import '../../features/splash/binding/splash_binding.dart';
import '../../features/splash/view/splash_view.dart';
import 'app_routes.dart';

/// The Home route's composed binding: PickerBinding runs first because
/// HomeController takes its PickerController from that registration.
class _HomeRouteBinding extends Bindings {
  @override
  void dependencies() {
    PickerBinding().dependencies();
    HomeBinding().dependencies();
  }
}

/// All route wiring (Conventions §1.2).
abstract final class AppPages {
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.home,
      page: () => const HomeView(),
      binding: _HomeRouteBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.proposal,
      page: () => const ProposalView(),
      binding: ProposalBinding(),
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
    GetPage<dynamic>(
      name: Routes.brush,
      page: () => const BrushView(),
      binding: BrushBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.history,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.historyDetail,
      page: () => const HistoryDetailView(),
      binding: HistoryDetailBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage<dynamic>(
      name: Routes.diagnostics,
      page: () => const DiagnosticsView(),
    ),
  ];
}
