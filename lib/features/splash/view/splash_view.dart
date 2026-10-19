import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_motion.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/theme_ext.dart';
import '../controller/splash_controller.dart';

/// Framora Splash Screen.
/// Clean, minimal, and brand-first:
/// 1. Prominent Framora wordmark logo with an elegant fade & scale entrance.
/// 2. Punchy, memorable subtext: "Clear the crowd. Keep your moment."
/// 3. Minimal footer: "POWERED BY ARTIVO"
/// 4. Tap anywhere to skip instantly, or auto-advances to Home.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SplashBody();
  }
}

class _SplashBody extends StatefulWidget {
  const _SplashBody();

  @override
  State<_SplashBody> createState() => _SplashBodyState();
}

class _SplashBodyState extends State<_SplashBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 1. Logo entrance (0ms -> 450ms)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.50, curve: AppMotion.enterCurve),
      ),
    );

    // 2. Punchy tagline entrance (350ms -> 800ms)
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.80, curve: AppMotion.enterCurve),
      ),
    );

    // 3. Footer fade (500ms -> 950ms)
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.50, 0.95, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.sizes;
    final controller = Get.find<SplashController>();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      backgroundColor: p.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.complete,
        child: Stack(
          children: <Widget>[
            // Ambient soft radial gradient in center
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      p.primary.withValues(alpha: 0.06),
                      p.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Spacer(flex: 3),

                    // 1. Framora Wordmark Logo
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        if (disableAnimations) return child!;
                        return FadeTransition(
                          opacity: _logoFade,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/framora_logo.svg',
                          height: 48,
                          theme: SvgTheme(currentColor: p.textPrimary),
                        ),
                      ),
                    ),

                    SizedBox(height: s.md),

                    // 2. Punchy, Clear Subtext
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        if (disableAnimations) return child!;
                        return SlideTransition(
                          position: _taglineSlide,
                          child: FadeTransition(
                            opacity: _taglineFade,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: s.lg),
                        child: Text(
                          AppStrings.splashTagline.tr,
                          textAlign: TextAlign.center,
                          style: context.textStyles.bodyMd.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // 3. Footer: "POWERED BY ARTIVO"
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        if (disableAnimations) return child!;
                        return FadeTransition(
                          opacity: _footerFade,
                          child: child,
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(bottom: s.md),
                        child: Text(
                          AppStrings.splashFooter.tr,
                          style: context.textStyles.overline.copyWith(
                            color: p.textSecondary.withValues(alpha: 0.5),
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
