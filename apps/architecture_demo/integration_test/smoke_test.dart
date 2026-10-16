// The smoke run of sub-project 3b, automated (the human declined interactive
// control and chose this test): the real `ArchitectureDemoApp` on the real
// macOS binary, with the real printer, over a `DocumentFiles` that reads and
// writes real files in a temporary directory (the io implementation's native
// panels cannot be driven).
//
// Steps: Open sample (walls, rooms, furniture live); one wall drawn with the
// Wall tool by pointer events; Save As `smoke.jetplan`; New; Open
// `smoke.jetplan`; the reopened plan's `save()` is the written file's text and
// holds the drawn wall; the editor is captured through a `RepaintBoundary`
// and written as a PNG.
//
// Run: cd apps/architecture_demo &&
//   flutter test integration_test/smoke_test.dart -d macos
// The PNG goes to the directory named by `--dart-define=SMOKE_OUT=<dir>`
// when given, else the temporary directory (the macOS sandbox lets the app
// write only inside its container; the path is printed).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:architecture_demo/document_files.dart';
import 'package:architecture_demo/main.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show EntityKind;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart'
    show ensurePlanFonts, registerFontLicences;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../test/support/app_rig.dart'
    show aimCamera, drawWall, liveOfAny, wallsOf;

/// Real files in [dir]: Save As answers `dir/<suggested>`, Open reads the
/// last file written (or [openName] in [dir]), Write writes the bytes.
class DirectoryFiles implements DocumentFiles {
  DirectoryFiles(this.dir);

  final Directory dir;
  final writes = <String>[];

  @override
  bool get writesInPlace => true;

  @override
  Future<({String name, Uint8List bytes, Object? location})?> open() async {
    final file = File('${dir.path}/smoke.jetplan');
    return (
      name: 'smoke.jetplan',
      bytes: await file.readAsBytes(),
      location: file.path
    );
  }

  @override
  Future<({String name, Object location})?> saveLocation(String suggestedName,
          {FileKind kind = FileKind.jetplan}) async =>
      (name: 'smoke.jetplan', location: '${dir.path}/smoke.jetplan');

  @override
  Future<void> write(Object location, String name, Uint8List bytes,
      {FileKind kind = FileKind.jetplan}) async {
    writes.add(location as String);
    await File(location).writeAsBytes(bytes, flush: true);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'smoke: Open sample, draw a wall, Save As, New, Open: the reopened plan '
      'is the written file; the editor is captured', (tester) async {
    await ensurePlanFonts();
    registerFontLicences();
    final dir = Directory.systemTemp.createTempSync('architecture_demo_smoke');
    addTearDown(() => dir.deleteSync(recursive: true));
    final files = DirectoryFiles(dir);
    final shot = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: shot, child: ArchitectureDemoApp(files: files)));
    await tester.pumpAndSettle();
    final app = tester
        .state<ArchitectureDemoAppState>(find.byType(ArchitectureDemoApp));
    final c = app.controller;
    expect(liveOfAny(c, ArchitectureTypes.wall), 0, reason: 'premise: empty');

    // Open sample.
    await tester.tap(find.byKey(const Key('toolbar-open-sample')));
    await tester.pumpAndSettle();
    expect(liveOfAny(c, ArchitectureTypes.wall), 10, reason: 'walls');
    expect(liveOfAny(c, ArchitectureTypes.room), 7, reason: 'rooms');
    expect(liveOfAny(c, ArchitectureTypes.opening), 15, reason: 'openings');
    expect(liveOfAny(c, ArchitectureTypes.dimension), 5, reason: 'dimensions');
    expect([
      for (final slot in c.document.entities.liveSlots)
        if (c.document.entities.kindAt(slot) == EntityKind.fill &&
            c.document.entities.ownerAt(slot) == c.document.rootHandle)
          slot
    ], hasLength(8), reason: 'furniture');
    expect(c.dirty.value, isFalse);

    // One wall drawn with the Wall tool by pointer events, far from the
    // origin under a turned camera.
    final far = Vector2(-43210.5, 31234.75);
    await aimCamera(tester, c, far);
    await drawWall(
        tester, c, far + Vector2(-1500, 200), far + Vector2(1500, -300));
    expect(liveOfAny(c, ArchitectureTypes.wall), 11, reason: 'the drawn wall');
    expect(c.dirty.value, isTrue);

    // Save As smoke.jetplan (real disk write).
    await tester.tap(find.byKey(const Key('toolbar-save-as')));
    await tester.pumpAndSettle();
    expect(files.writes, [File('${dir.path}/smoke.jetplan').path],
        reason: 'one write, to the temp file');
    final written = File('${dir.path}/smoke.jetplan').readAsStringSync();
    expect(c.dirty.value, isFalse, reason: 'saved');
    expect(written, c.save(), reason: 'the file is the plan\'s text');
    final walls = wallsOf(c).length;

    // New, then Open smoke.jetplan.
    await tester.tap(find.byKey(const Key('toolbar-new')));
    await tester.pumpAndSettle();
    expect(liveOfAny(c, ArchitectureTypes.wall), 0, reason: 'New');
    await tester.tap(find.byKey(const Key('toolbar-open')));
    await tester.pumpAndSettle();
    expect(c.save(), written, reason: 'the reopened plan is the written file');
    expect(wallsOf(c), hasLength(walls));
    expect(liveOfAny(c, ArchitectureTypes.wall), 11, reason: 'drawn wall kept');
    expect(c.dirty.value, isFalse);

    // The editor, captured through the repaint boundary.
    await tester.pumpAndSettle();
    final boundary =
        shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final png = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    expect(png, isNotNull);
    expect(png!.length, greaterThan(10000), reason: 'a drawn screen');
    const out = String.fromEnvironment('SMOKE_OUT');
    final target = File('${out.isEmpty ? Directory.systemTemp.path : out}'
        '/2026-10-16-architecture-demo-smoke.png');
    target.writeAsBytesSync(png);
    // ignore: avoid_print
    print('SMOKE_PNG ${target.path} ${png.length} bytes');
    binding.reportData = {'png': target.path, 'walls': walls};
  });
}
