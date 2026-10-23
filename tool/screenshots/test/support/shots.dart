// The screenshots' harness (package READMEs spec D4): real fonts, a fixed
// logical size and ratio, a capture of the scene's boundary, and a write
// only under UPDATE_SCREENSHOTS=1. No pixel is ever compared.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size kWide = Size(1280, 800);
const Size kPanel = Size(480, 800);

/// Device pixels per logical pixel (spec D6): 1.5 unless a file exceeds
/// the budget; Task 3 measures and records the choice.
const double kRatio = 1.5;

const Key _shot = ValueKey('screenshot');

bool get updating => Platform.environment['UPDATE_SCREENSHOTS'] == '1';

/// Every family of the test bundle's font manifest, Roboto and
/// MaterialIcons among them, through [FontLoader]: flutter_test draws Ahem
/// otherwise.
Future<void> loadManifestFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      // The manifest lists an asset URL-encoded (shadcn_ui's
      // `Geist[wght].ttf` as `Geist%5Bwght%5D.ttf`); the bundle encodes the
      // key itself.
      loader.addFont(rootBundle.load(Uri.decodeFull(font['asset'] as String)));
    }
    await loader.load();
  }
}

/// Pumps [scene] alone in a boundary of [size] at [kRatio].
Future<void> pumpScene(WidgetTester tester, Widget scene,
    {Size size = kWide}) async {
  tester.view.physicalSize = size * kRatio;
  tester.view.devicePixelRatio = kRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shot, child: scene));
}

/// Lets real asynchronous work (asset reads, thumbnails) finish, frame by
/// frame, until [until] holds or ten seconds of real time pass (one second
/// without an [until]), then past animations.
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  final limit = Duration(seconds: until == null ? 1 : 10);
  final clock = Stopwatch()..start();
  while (clock.elapsed < limit && !(until?.call() ?? false)) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  if (until != null) expect(until(), isTrue, reason: 'the scene settled');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The scene as PNG bytes; written to the package's doc/screenshots/ only
/// when [updating].
Future<Uint8List> shoot(WidgetTester tester,
    {required String package, required String file, Size size = kWide}) async {
  expect(tester.takeException(), isNull, reason: 'the scene threw');
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final png = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kRatio);
    expect(image.width, (size.width * kRatio).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  if (updating) {
    await tester.runAsync(() async {
      final out = File('../../packages/$package/doc/screenshots/$file');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(png);
    });
  }
  return png;
}
