import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:people_gone/core/routes/app_pages.dart';
import 'package:people_gone/core/routes/app_routes.dart';
import 'package:people_gone/core/strings/app_strings.dart';
import 'package:people_gone/core/theme/app_theme.dart';
import 'package:people_gone/features/brush/controller/brush_controller.dart';
import 'package:people_gone/features/brush/model/brush_args.dart';
import 'package:people_gone/features/brush/widgets/brush_canvas.dart';
import 'package:people_gone/services/processing/processing_api.dart';
import 'package:people_gone/services/storage/local_store.dart';

import 'brush_controller_test.dart' show FakeLocalStore, FakeProcessingApi;

class TestBinding extends Bindings {
  TestBinding(this.store, this.api);
  final LocalStore store;
  final ProcessingApi api;

  @override
  void dependencies() {
    Get.put<LocalStore>(store);
    Get.put<ProcessingApi>(api);
  }
}

Future<File> makeSquareImage(Directory dir, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF336699),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/square.png');
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file;
}

void main() {
  late Directory tempDir;
  late File photo;
  late FakeProcessingApi api;
  late FakeLocalStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pg_brush_view');
    photo = await makeSquareImage(tempDir, 100);
    api = FakeProcessingApi();
    store = FakeLocalStore();
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<BrushController> pumpBrush(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        theme: AppTheme.light(),
        initialBinding: TestBinding(store, api),
        initialRoute: Routes.home,
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: Routes.home,
            page: () => const Scaffold(body: Text('HOME')),
          ),
          ...AppPages.pages.where((p) => p.name != Routes.home),
        ],
      ),
    );
    await tester.pump();
    Get.toNamed<void>(
      Routes.brush,
      arguments: BrushArgs(imagePath: photo.path),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final controller = Get.find<BrushController>();
    // The codec load does real file IO: finish it in the real zone.
    await tester.runAsync(() async {
      await controller.loadImageSize();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    return controller;
  }

  testWidgets('sanctioned hint shows; Apply disabled until a stroke', (
    tester,
  ) async {
    final controller = await pumpBrush(tester);
    expect(
      find.text(
        'Paint over anything that should also be removed — including its shadow.',
      ),
      findsOneWidget,
    );
    expect(find.text('Touch up'), findsOneWidget);
    expect(find.text('Remove painted area'), findsOneWidget);
    expect(controller.canApply, isFalse);
    expect(controller.imageSize.value, const Size(100, 100));
  });

  testWidgets('drag on the photo lands a stroke at the expected region', (
    tester,
  ) async {
    final controller = await pumpBrush(tester);
    final canvasRect = tester.getRect(find.byType(BrushCanvas));
    // The canvas centre is the fitted band's centre for a square photo,
    // so the stroke must start at the image centre (50, 50) — the
    // pan-down point, not the post-slop pan-start point.
    final centre = canvasRect.center;
    await tester.dragFrom(centre, const Offset(80, 0));
    await tester.pump();
    expect(controller.strokes, isNotEmpty);
    final first = controller.strokes.first.first;
    expect(first.dx, closeTo(50, 4));
    expect(first.dy, closeTo(50, 4));
    expect(controller.canApply, isTrue);
  });

  testWidgets('slider changes the brush size', (tester) async {
    final controller = await pumpBrush(tester);
    final before = controller.brushSizeDisplay.value;
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(controller.brushSizeDisplay.value, isNot(equals(before)));
    expect(controller.brushSizeDisplay.value, greaterThan(before));
    expect(controller.brushSizeDisplay.value, lessThanOrEqualTo(64));
  });
}
