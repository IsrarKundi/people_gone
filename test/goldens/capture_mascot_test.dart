/// Cam mascot verification harness (MASCOT_EXECUTION_PLAN.md §6,
/// ADR docs/architecture/cam-mascot.md).
///
/// Two kinds of cases:
/// 1. MEASUREMENT tests — always run. They pump the real S1/S6/S8
///    routes with the capture fakes and assert the plan §3 numbers
///    directly from widget rects: avatar centre vs wordmark centre,
///    peek visible fraction and band centring, presenter gap, and a
///    tap-target overlap audit on each screen.
/// 2. CAPTURE cases — only with PG_CAPTURE=1, like the review02
///    harness: golden evidence into test/goldens/mascot/, including
///    the expression sheet (the plan §5 step-3 artefact).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:people_gone/config/app_config.dart';
import 'package:people_gone/core/constants/app_colors.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';
import 'package:people_gone/core/widgets/cam_mascot.dart';
import 'package:people_gone/core/widgets/cam_painter.dart';
import 'package:people_gone/core/widgets/primary_button.dart';
import 'package:people_gone/features/paywall/model/paywall_args.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/processing/widgets/server_working_photo_frame.dart';
import 'package:people_gone/services/processing/processing_api.dart';

import 'capture_review02_test.dart' as review02;

/// The repo's bundled demo photo (the harness photos under /Users/mc
/// are the owner's Mac paths; this file lives in the repo, so the S6
/// case runs on any machine).
String get _demoPath =>
    '${Directory.current.path}/assets/images/demo_original.jpg';

final bool _capture = Platform.environment['PG_CAPTURE'] == '1';

void main() {
  late Directory tempDir;
  late review02.CaptureStore store;
  late review02.CaptureApi api;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final inter = FontLoader('Inter');
    for (final weight in <String>['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    try {
      File? iconFile;
      var dir = File(Platform.resolvedExecutable).parent;
      for (var i = 0; i < 8 && iconFile == null; i++) {
        for (final rel in <String>[
          'artifacts/material_fonts/MaterialIcons-Regular.otf',
          'cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ]) {
          final candidate = File('${dir.path}/$rel');
          if (candidate.existsSync()) {
            iconFile = candidate;
            break;
          }
        }
        dir = dir.parent;
      }
      if (iconFile != null) {
        final bytes = await iconFile.readAsBytes();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
        await icons.load();
      }
    } catch (e) {
      debugPrint('setUpAll: MaterialIcons load failed: $e');
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_mascot');
    store = review02.CaptureStore(tempDir);
    api = review02.CaptureApi();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(780, 1688); // 390x844 @2x
    addTearDown(tester.view.reset);
    final picker = PickerController(
      pickImage: () async => XFile(_demoPath),
      maxBytes: 60 * 1024 * 1024,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        initialBinding: review02.CaptureBinding(store, api, picker),
        initialRoute: Routes.home,
        getPages: AppPages.pages,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final clamped = media.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.30,
          );
          return MediaQuery(
            data: media.copyWith(textScaler: clamped),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> primeDemo(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final context = tester.element(find.byType(MaterialApp));
    await tester.runAsync(() async {
      for (final provider in <ImageProvider>[
        FileImage(File(_demoPath)),
        ResizeImage.resizeIfNeeded(390, null, FileImage(File(_demoPath))),
      ]) {
        try {
          await precacheImage(
            provider,
            context,
          ).timeout(const Duration(seconds: 20));
        } catch (e) {
          debugPrint('primeDemo: $provider did not complete: $e');
        }
      }
    });
  }

  Future<void> openProcessing(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    api.gate = Completer<Result<ProcessedPhoto>>();
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(
      Routes.processing,
      arguments: ProcessingArgs(photoPath: _demoPath),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> closeProcessing(WidgetTester tester) async {
    api.gate!.complete(
      const Failure<ProcessedPhoto>(
        AppFailure(
          code: 'server',
          userMessageKey: AppStrings.errorProcessingFailed,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openPaywall(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(Routes.paywall, arguments: const PaywallArgs());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // -----------------------------------------------------------------
  // 1. Measurement tests (always run) — plan §6.2/§6.3 numbers.
  // -----------------------------------------------------------------

  testWidgets('S1: avatar is 44dp, centred on the wordmark, clear of '
      'the Pick button', (tester) async {
    await pumpApp(tester);
    final avatar = find.byType(CamMascot);
    expect(avatar, findsOneWidget);
    final avatarRect = tester.getRect(avatar);
    expect(avatarRect.size, const Size(44, 44));

    final wordmark = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(SvgPicture),
    );
    final wordmarkRect = tester.getRect(wordmark);
    expect(
      (avatarRect.center.dy - wordmarkRect.center.dy).abs(),
      lessThanOrEqualTo(2),
      reason: 'avatar centre must align with the wordmark centre ±2dp',
    );
    // Trailing slot: right edge sits at the header end-padding (16).
    expect((390 - avatarRect.right - 16).abs(), lessThanOrEqualTo(4));

    final pickRect = tester.getRect(find.byType(PrimaryButton));
    expect(avatarRect.overlaps(pickRect), isFalse);
  });

  testWidgets('S6: peek is the visible half, flush right, centred on '
      'the photo, clear of the tray', (tester) async {
    await openProcessing(tester);
    final peek = find.byType(CamMascot);
    expect(peek, findsOneWidget);
    final peekRect = tester.getRect(peek);
    // 55×110 box = exactly 50% of the square character canvas visible.
    expect(peekRect.size, const Size(55, 110));
    expect(
      (390 - peekRect.right).abs(),
      lessThanOrEqualTo(1),
      reason: 'peek must be flush with the right screen edge',
    );

    final frameRect = tester.getRect(find.byType(ServerWorkingPhotoFrame));
    expect(
      (peekRect.center.dy - frameRect.center.dy).abs(),
      lessThanOrEqualTo(2),
      reason: 'peek centre must align with the photo centre ±2dp',
    );

    final buttonRect = tester.getRect(find.byType(PrimaryButton));
    expect(peekRect.overlaps(buttonRect), isFalse);
    final cancelRect = tester.getRect(find.text('Cancel'));
    expect(peekRect.overlaps(cancelRect), isFalse);

    await closeProcessing(tester);
  });

  testWidgets('S8: presenter is 120dp, centred, ≥24dp below the links '
      'row, clear of the CTA', (tester) async {
    await openPaywall(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    expect(camRect.size, const Size(120, 120));
    expect(
      (camRect.center.dx - 195).abs(),
      lessThanOrEqualTo(2),
      reason: 'presenter must be horizontally centred',
    );

    final restoreRect = tester.getRect(
      find.widgetWithText(TextButton, 'Restore Purchases'),
    );
    final notNowRect = tester.getRect(
      find.widgetWithText(TextButton, 'Not now'),
    );
    final rowBottom = restoreRect.bottom > notNowRect.bottom
        ? restoreRect.bottom
        : notNowRect.bottom;
    expect(
      camRect.top - rowBottom,
      greaterThanOrEqualTo(24),
      reason: 'presenter gap below the links row must be ≥24dp',
    );

    final ctaRect = tester.getRect(find.byType(PrimaryButton));
    expect(camRect.overlaps(ctaRect), isFalse);
  });

  // -----------------------------------------------------------------
  // 2. Capture cases (PG_CAPTURE=1) — golden evidence, plan §6.1.
  // -----------------------------------------------------------------

  Future<void> snap(WidgetTester tester, String name) {
    return expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('mascot/$name'),
    );
  }

  testWidgets('capture S1 Home with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await pumpApp(tester);
    await snap(tester, 's1_home_mascot_light.png');
    await pumpApp(tester, mode: ThemeMode.dark);
    // Let the theme-change lerp finish before snapping, or the
    // "dark" evidence is a grey mid-blend of the two themes.
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, 's1_home_mascot_dark.png');
  });

  testWidgets('capture S6 Processing with Cam, light + dark', (
    tester,
  ) async {
    if (!_capture) return;
    await openProcessing(tester);
    await snap(tester, 's6_processing_mascot_light.png');
    await closeProcessing(tester);
    await openProcessing(tester, mode: ThemeMode.dark);
    await snap(tester, 's6_processing_mascot_dark.png');
    await closeProcessing(tester);
  });

  testWidgets('capture S8 Paywall with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await openPaywall(tester);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, 's8_paywall_mascot_light.png');
    await openPaywall(tester, mode: ThemeMode.dark);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await snap(tester, 's8_paywall_mascot_dark.png');
  });

  testWidgets('capture expression sheet (plan §5 step 3)', (tester) async {
    if (!_capture) return;
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    Widget cell(CamMode mode, Duration at, double w, double h) {
      return Container(
        width: w,
        height: h,
        color: AppPalette.light.background,
        child: CustomPaint(
          size: Size(w, h),
          painter: CamPainter(
            palette: AppPalette.light,
            frame: evaluateCamFrame(at, mode),
            mode: mode,
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  cell(CamMode.presenter, Duration.zero, 190, 190),
                  cell(
                    CamMode.presenter,
                    const Duration(milliseconds: 1580),
                    190,
                    190,
                  ),
                  cell(
                    CamMode.presenter,
                    const Duration(milliseconds: 3400),
                    190,
                    190,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  cell(CamMode.avatar, Duration.zero, 120, 120),
                  cell(
                    CamMode.avatar,
                    const Duration(milliseconds: 3400),
                    120,
                    120,
                  ),
                  cell(CamMode.peek, Duration.zero, 95, 190),
                  cell(
                    CamMode.peek,
                    const Duration(milliseconds: 3400),
                    95,
                    190,
                  ),
                  cell(
                    CamMode.peek,
                    const Duration(milliseconds: 6225),
                    95,
                    190,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('mascot/expression_sheet.png'),
    );
  });
}
