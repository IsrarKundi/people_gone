/// Cam mascot verification harness, v2 (MASCOT_EXECUTION_PLAN.md §6,
/// ADR docs/architecture/cam-mascot.md).
///
/// Two kinds of cases:
/// 1. MEASUREMENT tests — always run. They pump the real routes with
///    the capture fakes and assert the plan §3 numbers directly from
///    widget rects: avatar centre vs wordmark centre, peek visible
///    fraction and band centring, avatarSmall header positions,
///    Result bottom-right placement, and a tap-target overlap audit
///    on each screen. Paywall asserts the OPPOSITE: no Cam anywhere
///    (the v1 presenter was removed in v2).
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
import 'package:people_gone/core/constants/app_colors.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/core/utils/result.dart';
import 'package:people_gone/core/widgets/cam_art.dart';
import 'package:people_gone/core/widgets/cam_frame.dart';
import 'package:people_gone/core/widgets/cam_mascot.dart';
import 'package:people_gone/core/widgets/primary_button.dart';
import 'package:people_gone/core/widgets/secondary_button.dart';
import 'package:people_gone/features/brush/controller/brush_controller.dart';
import 'package:people_gone/features/brush/model/brush_args.dart';
import 'package:people_gone/features/paywall/model/paywall_args.dart';
import 'package:people_gone/features/picker/controller/picker_controller.dart';
import 'package:people_gone/features/processing/model/processing_args.dart';
import 'package:people_gone/features/processing/widgets/server_working_photo_frame.dart';
import 'package:people_gone/features/proposal/model/proposal_args.dart';
import 'package:people_gone/features/result/widgets/save_receipt_button.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

import 'capture_review02_test.dart' as review02;

/// The repo's bundled demo photo (the harness photos under /Users/mc
/// are the owner's Mac paths; this file lives in the repo, so the
/// cases run on any machine).
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

  /// The proposal screen held in its analysing state: detectPersons
  /// waits on the fake's detectGate, so the analysing panel (with
  /// Cam's small avatar) stays up.
  Future<void> openAnalyzing(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    api.detectGate = Completer<Result<DetectionProposal>>();
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(
      Routes.proposal,
      arguments: ProposalArgs.forPhoto(photoPath: _demoPath),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> closeAnalyzing(WidgetTester tester) async {
    api.detectGate!.complete(
      Success<DetectionProposal>(
        DetectionProposal(
          photoPath: _demoPath,
          personsDetected: 2,
          keeperIds: const <int>[0],
          removedIds: const <int>[1],
          persons: const <DetectedPerson>[
            DetectedPerson(
              id: 0,
              box: <int>[10, 10, 50, 90],
              score: 0.95,
              isKeeper: true,
            ),
            DetectedPerson(
              id: 1,
              box: <int>[60, 20, 90, 80],
              score: 0.85,
              isKeeper: false,
            ),
          ],
          inputDimensions: const <int>[100, 100],
        ),
      ),
    );
    api.detectGate = null;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openResult(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(
      Routes.result,
      arguments: ProcessingOutcome(
        originalPath: _demoPath,
        resultPath: _demoPath,
        personsDetected: 2,
        keeperIds: const <int>[0],
        removedIds: const <int>[1],
        totalSeconds: 14.2,
        engineUsed: 'mat',
        persons: const <DetectedPerson>[
          DetectedPerson(
            id: 0,
            box: <int>[10, 10, 50, 90],
            score: 0.95,
            isKeeper: true,
          ),
          DetectedPerson(
            id: 1,
            box: <int>[60, 20, 90, 80],
            score: 0.85,
            isKeeper: false,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<BrushController> openBrush(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(
      Routes.brush,
      arguments: BrushArgs(imagePath: _demoPath),
    );
    await tester.pump();
    final controller = Get.find<BrushController>();
    // The controller decodes the photo's size from its bytes off a
    // future started in the fake-async zone; await the decode inside
    // runAsync or imageSize stays null and the canvas renders its
    // no-size fallback (photo only, no stroke layer).
    await tester.runAsync(() async {
      await controller.loadImageSize();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return controller;
  }

  List<HistoryEntry> sampleEntries() => <HistoryEntry>[
    HistoryEntry(
      id: 'h1',
      localPath: _demoPath,
      savedAt: DateTime(2026, 10, 13),
    ),
    HistoryEntry(
      id: 'h2',
      localPath: _demoPath,
      savedAt: DateTime(2026, 10, 12),
    ),
  ];

  Future<void> openHistory(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    store.entries = sampleEntries();
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(Routes.history);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openHistoryDetail(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await primeDemo(tester);
    await pumpApp(tester, mode: mode);
    Get.toNamed<void>(
      Routes.historyDetail,
      arguments: HistoryEntry(
        id: 'hist_1',
        localPath: _demoPath,
        originalPath: _demoPath,
        savedAt: DateTime.utc(2026, 10, 14),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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

  testWidgets('S1 regression: Home settles under pumpAndSettle with '
      'Cam present', (tester) async {
    // Cam's production idle loop repeats forever; in tests he renders
    // a still frame (see CamMascot), so Home must settle completely.
    await pumpApp(tester);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    expect(find.byType(CamMascot), findsOneWidget);
  });

  testWidgets('S6: processing mascot is whole, centred, clear of '
      'the photo and the tray', (tester) async {
    await openProcessing(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    // Whole drawing at its fixed width — never cropped, never half.
    expect(camRect.width, 240);
    expect(
      (camRect.center.dx - 195).abs(),
      lessThanOrEqualTo(1),
      reason: 'processing mascot must be centred horizontally',
    );

    final frameRect = tester.getRect(find.byType(ServerWorkingPhotoFrame));
    expect(camRect.overlaps(frameRect), isFalse);

    final buttonRect = tester.getRect(find.byType(PrimaryButton));
    expect(camRect.overlaps(buttonRect), isFalse);
    final cancelRect = tester.getRect(find.text('Cancel'));
    expect(camRect.overlaps(cancelRect), isFalse);

    await closeProcessing(tester);
  });

  testWidgets('Analyzing: mascot is whole, centred in the panel, '
      'clear of the photo', (tester) async {
    await openAnalyzing(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    // Whole drawing at its fixed width — never cropped, never a
    // small header avatar.
    expect(camRect.width, 200);
    expect(
      (camRect.center.dx - 195).abs(),
      lessThanOrEqualTo(1),
      reason: 'analyzing mascot must be centred horizontally',
    );

    await closeAnalyzing(tester);
  });

  testWidgets('Result: avatar is 44dp, top-right, clear of the '
      'photo and every button', (tester) async {
    await openResult(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    expect(camRect.size, const Size(44, 44));
    // Header right padding (screenPadding 16) sets the edge.
    expect((390 - camRect.right - 16).abs(), lessThanOrEqualTo(4));
    expect(camRect.top, lessThan(120));

    // Every action-zone button must sit below him, never under him.
    var buttonTop = 844.0;
    for (final type in <Type>[
      PrimaryButton,
      SecondaryButton,
      SaveReceiptButton,
    ]) {
      for (final element in tester.elementList(find.byType(type))) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(camRect.overlaps(rect), isFalse);
        if (rect.top < buttonTop) buttonTop = rect.top;
      }
    }
    expect(
      camRect.bottom,
      lessThanOrEqualTo(buttonTop),
      reason: 'Cam must sit above the action zone, never over a button',
    );
  });

  testWidgets('Brush: small header avatar, clear of the Apply button',
      (tester) async {
    await openBrush(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    expect(camRect.size, const Size(32, 32));
    // Header row: Cam is the last item, at the screen's right padding.
    expect((390 - camRect.right - 16).abs(), lessThanOrEqualTo(4));
    expect(camRect.top, lessThan(120));

    final applyRect = tester.getRect(find.byType(PrimaryButton));
    expect(camRect.overlaps(applyRect), isFalse);
  });

  testWidgets('History: small header avatar in the app bar',
      (tester) async {
    await openHistory(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    expect(camRect.size, const Size(32, 32));
    expect((390 - camRect.right - 16).abs(), lessThanOrEqualTo(4));
    expect(camRect.top, lessThan(120));
  });

  testWidgets('History detail: small header avatar, clear of Share '
      'and Delete', (tester) async {
    await openHistoryDetail(tester);
    final cam = find.byType(CamMascot);
    expect(cam, findsOneWidget);
    final camRect = tester.getRect(cam);
    expect(camRect.size, const Size(32, 32));
    expect((390 - camRect.right - 16).abs(), lessThanOrEqualTo(4));
    expect(camRect.top, lessThan(120));

    // Every action-zone button (Share, Delete, and any button the
    // receipt widget renders) must sit below him, never under him.
    for (final type in <Type>[SecondaryButton, OutlinedButton]) {
      for (final element in tester.elementList(find.byType(type))) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(camRect.overlaps(rect), isFalse);
      }
    }
  });

  testWidgets('Paywall: no Cam anywhere (v1 presenter removed)',
      (tester) async {
    await openPaywall(tester);
    expect(find.byType(CamMascot), findsNothing);
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

  testWidgets('capture S6 Processing with Cam, light + dark',
      (tester) async {
    if (!_capture) return;
    await openProcessing(tester);
    await snap(tester, 's6_processing_mascot_light.png');
    await closeProcessing(tester);
    await openProcessing(tester, mode: ThemeMode.dark);
    await snap(tester, 's6_processing_mascot_dark.png');
    await closeProcessing(tester);
  });

  testWidgets('capture Analyzing with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await openAnalyzing(tester);
    await snap(tester, 's4_analyzing_mascot_light.png');
    await closeAnalyzing(tester);
    await openAnalyzing(tester, mode: ThemeMode.dark);
    await snap(tester, 's4_analyzing_mascot_dark.png');
    await closeAnalyzing(tester);
  });

  testWidgets('capture Result with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await openResult(tester);
    await snap(tester, 's7_result_mascot_light.png');
    await openResult(tester, mode: ThemeMode.dark);
    await snap(tester, 's7_result_mascot_dark.png');
  });

  testWidgets('capture Brush with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await openBrush(tester);
    await snap(tester, 's5_brush_mascot_light.png');
    await openBrush(tester, mode: ThemeMode.dark);
    await snap(tester, 's5_brush_mascot_dark.png');
  });

  testWidgets('capture History with Cam, light + dark', (tester) async {
    if (!_capture) return;
    await openHistory(tester);
    await snap(tester, 's9_history_mascot_light.png');
    await openHistory(tester, mode: ThemeMode.dark);
    await snap(tester, 's9_history_mascot_dark.png');
  });

  testWidgets('capture History detail with Cam, light + dark',
      (tester) async {
    if (!_capture) return;
    await openHistoryDetail(tester);
    await snap(tester, 's9_history_detail_mascot_light.png');
    await openHistoryDetail(tester, mode: ThemeMode.dark);
    await snap(tester, 's9_history_detail_mascot_dark.png');
  });

  testWidgets('capture expression sheet (plan §5 step 3)', (tester) async {
    if (!_capture) return;
    // Tall enough for two rows of whole sheet drawings (analyzing
    // alone is ~235dp tall); the old 760px canvas overflowed.
    tester.view.physicalSize = const Size(1200, 1040);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    Widget cell(CamMode mode, Duration at) {
      return Container(
        color: AppPalette.light.background,
        child: CamMascotArt(frame: evaluateCamFrame(at, mode), mode: mode),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppPalette.light.background,
          body: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  cell(CamMode.processing, Duration.zero),
                  cell(CamMode.analyzing, Duration.zero),
                  cell(CamMode.resultsReady, Duration.zero),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  cell(CamMode.avatar, Duration.zero),
                  cell(CamMode.avatarSmall, Duration.zero),
                  cell(CamMode.processing, Duration.zero),
                  cell(CamMode.analyzing, Duration.zero),
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
