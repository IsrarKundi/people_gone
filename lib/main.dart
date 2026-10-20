import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/app_config.dart';
import 'core/bindings/initial_binding.dart';
import 'core/constants/app_motion.dart';
import 'core/diagnostics/diagnostics_log.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/page_transitions.dart';
import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';


/// Minimal entry only (Conventions §1.2): binding, config load, services,
/// runApp. No UI, no feature logic.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  diag(
    'app',
    'start gateway=${config.useGateway} '
    'supabaseHost=${Uri.parse(config.supabaseUrl).host}',
  );
  runApp(PeopleGoneApp(config: config));
}

/// App root: GetMaterialApp wired to tokens, strings, and routes.
/// Dark mode follows the system (no in-app toggle in v1, Conventions §6.1);
/// text scaling is clamped 0.85–1.30 (§6.4).
class PeopleGoneApp extends StatelessWidget {
  const PeopleGoneApp({
    super.key,
    required this.config,
    this.initialRoute = Routes.splash,
  });

  final AppConfig config;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'uncrowd',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialBinding: InitialBinding(config),
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      customTransition: PeopleGonePageTransition(),
      transitionDuration: AppMotion.standard,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.30,
        );
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final targetTheme = isDark ? AppTheme.dark() : AppTheme.light();
        final duration = media.disableAnimations
            ? Duration.zero
            : AppMotion.themeCrossfade;
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: AnimatedTheme(
            data: targetTheme,
            curve: AppMotion.standardCurve,
            duration: duration,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
