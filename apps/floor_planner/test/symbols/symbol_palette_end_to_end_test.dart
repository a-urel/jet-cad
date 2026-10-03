// Spec 09b "Testing: End to end", plan 09b Task 10: the symbol palette
// through the app's real widgets, focus and key path, from the Symbols tab
// to a byte-identical save round trip. No tool method is called directly.
//
// Fixtures (plan P-2, P-3, P-4): the app over a scripted `DocumentFiles`, a
// loader over the real asset read by `File`, the real thumbnail cache (a
// subclass that only records the futures it hands out, so the test can
// wait for them under `tester.runAsync`). The camera is rotated, at
// 0.1 px/mm, centred far from the origin; `bed.double`'s base point is off
// its origin (checked); the press and the release are far from the origin
// and from each other; the release lands near a line drawn with the Line
// tool, so the snapped point (the line's end) differs from the raw one.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:floor_planner/main.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';

final Uint8List assetBytes =
    File('../../packages/jet_cad_floor_plan/assets/library/furniture.jetlib')
        .readAsBytesSync();

/// Far from the origin and from the page.
final Vector2 far = Vector2(41234.5, 27345.25);

const String bedId = 'bed.double@1';
final Finder bedCell = find.byKey(const Key('symbol-cell-$bedId'));

/// The real cache, recording every future it hands out.
class RecordingThumbnails extends SymbolThumbnails {
  final List<Future<ui.Image>> requests = [];

  @override
  Future<ui.Image> imageFor({
    required Object key,
    required DraftDocument Function() document,
    required ui.Size logicalSize,
    required double devicePixelRatio,
    required int foreground,
  }) {
    final f = super.imageFor(
        key: key,
        document: document,
        logicalSize: logicalSize,
        devicePixelRatio: devicePixelRatio,
        foreground: foreground);
    requests.add(f);
    return f;
  }

  /// Waits, in real time, for every request so far, errors included.
  Future<void> settle() => Future.wait([
        for (final r in requests) r.then((_) {}, onError: (Object _) {}),
      ]);
}

ToolController toolsOf(WidgetTester tester) => viewOf(tester).tools;

List<InstanceNode> instancesOf(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

/// The model's live line entities' slots, ascending.
List<int> lineSlotsOf(DraftDocument doc) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.kindAt(s) == EntityKind.line) s,
    ]..sort();

GeometryPayload payloadAt(DraftDocument doc, int slot) =>
    doc.geometry.read(doc.entities.geomIndexAt(slot));

/// The world point under the global position [g] in the current shell.
Vector2 worldAt(WidgetTester tester, Offset g) {
  final local = g - tester.getTopLeft(find.byType(InteractionLayer));
  return viewOf(tester).camera.value.screenToWorld(Vector2(local.dx, local.dy));
}

/// The point a release at world [raw] resolves to: the snap chain (F-5)
/// computed here from the shell's own index, page, camera and snap state
/// ([objectSnap] overrides the shell's F3 state).
Vector2 resolvedAt(WidgetTester tester, Vector2 raw, {bool? objectSnap}) {
  final view = viewOf(tester);
  final cam = view.camera.value;
  final out = DragPoint();
  resolveDragPoint(
    raw: raw,
    orthoBase: null,
    index: view.index,
    apertureWorld: kSnapAperturePixels / cam.scale,
    objectSnap: objectSnap ?? hostOf(tester).snap.objectSnap,
    page: view.page.value,
    gridStepMm: dragGridStepMm(view.page.value, cam.scale),
    scratch: SnapResult(),
    out: out,
  );
  return out.point.clone();
}

/// Whether the primary focus sits inside the canvas's interaction layer.
bool canvasFocused(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus;
  if (node?.context == null) return false;
  return find
      .descendant(
          of: find.byType(InteractionLayer),
          matching: find.byElementPredicate((e) => e == node!.context),
          matchRoot: true)
      .evaluate()
      .isNotEmpty;
}

/// As `aimCamera`, at [scale] px/mm.
Future<void> aimCameraAt(
    WidgetTester tester, Vector2 centre, double scale) async {
  final view = viewOf(tester);
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.3).multiply(Transform2.scale(scale, scale));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// Cmd+Shift+Z: the shell's redo binding.
Future<void> redoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

void main() {
  testWidgets(
      'E2E the Symbols tab, search "bed", a tap on the double bed, a press '
      'far from the origin, R mid-press, a release near a line: one '
      'instance at the snapped release point, one quarter turn; undo and '
      'redo through the shell; Save As -> Open -> Save byte-identical',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final files = FakeDocumentFiles();
    final loader = SymbolLibraryLoader(read: () async => assetBytes);
    addTearDown(loader.dispose);
    final cache = RecordingThumbnails();
    addTearDown(cache.dispose);
    await tester.pumpWidget(
        FloorPlannerApp(files: files, symbols: loader, thumbnails: cache));
    await tester.pump();
    expect(loader.state, isA<SymbolLibraryReady>(), reason: 'premise: loaded');
    final entry = (loader.state as SymbolLibraryReady)
        .library
        .entries
        .singleWhere((e) => e.key == 'bed.double');
    final base = entry.definition.basePoint;
    expect(base.x != 0 && base.y != 0, isTrue,
        reason: 'P-3: the base point is off the origin on both axes');

    final session = sessionOf(tester);
    final doc = session.document;
    // A short line through the Line tool, drawn zoomed in (a fine grid),
    // so its end is off the coarse grid of the placement's zoom: the
    // release then snaps onto that end by the object snap alone.
    final lineStart = far + Vector2(-1820.3, 960.7);
    await aimCameraAt(tester, lineStart + Vector2(45, 24), 2.5);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(toolsOf(tester).active, isA<LineTool>(), reason: 'premise');
    await clickAt(tester, lineStart);
    await clickAt(tester, lineStart + Vector2(90.35, 47.85));
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.escape);
    expect(toolsOf(tester).active, isA<SelectTool>(), reason: 'premise');

    await aimCamera(tester, far);
    final cam = viewOf(tester).camera.value;
    expect(cam.scale, isNot(1.0), reason: 'P-3: a non-unit scale');
    final line = lineSlotsOf(doc).single;
    final coords = payloadAt(doc, line).coords;
    final lineEnd = Vector2(coords[2], coords[3]);
    expect(lineEnd.length, greaterThan(40000), reason: 'premise: far');

    // The Symbols tab; "bed" typed in the search field; Enter hands the
    // focus back to the canvas.
    await tester.tap(find.byKey(const Key('tab-symbols')));
    await tester.pump();
    final field = find.byKey(const Key('symbol-search'));
    await tester.enterText(field, 'bed');
    await tester.pump();
    expect(canvasFocused(tester), isFalse, reason: 'premise: the field');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(canvasFocused(tester), isTrue, reason: 'Enter hands focus back');
    final shownIds = [
      for (final c in tester
          .widget<SymbolGallery>(find.byType(SymbolGallery))
          .categories)
        for (final s in c.symbols) s.id,
    ];
    expect(shownIds, contains(bedId));
    expect(shownIds, isNot(contains('dining.chair@1')),
        reason: 'the search filtered');
    expect(shownIds.length,
        lessThan((loader.state as SymbolLibraryReady).library.entries.length),
        reason: 'the search filtered');

    // The thumbnails come from the app's cache (P-4: under runAsync).
    await tester.ensureVisible(bedCell);
    await tester.pump();
    expect(cache.requests, isNotEmpty, reason: 'the cells asked the cache');
    await tester.runAsync(cache.settle);
    await tester.pump();
    final shown = tester
        .widget<RawImage>(
            find.descendant(of: bedCell, matching: find.byType(RawImage)))
        .image;
    expect(shown, isNotNull, reason: 'the double bed\'s cell shows an image');
    final cached = <ui.Image>[];
    for (final r in cache.requests) {
      final image = await tester.runAsync(() => r);
      if (image != null) cached.add(image);
    }
    expect(cached.any(shown!.isCloneOf), isTrue,
        reason: 'a clone of an image of the cache the app was given');

    // The tap arms the placement tool, through the shell.
    expect(toolsOf(tester).active, isA<SelectTool>(), reason: 'premise');
    await tester.tap(bedCell);
    await tester.pump();
    final tool = toolsOf(tester).active;
    expect(tool, isNot(isA<SelectTool>()));
    expect(tool, isA<SymbolPlaceTool>());
    tool as SymbolPlaceTool;
    expect(tool.armed.value, same(entry));
    expect(canvasFocused(tester), isTrue, reason: 'the cell took no focus');
    expect(instancesOf(doc), isEmpty, reason: 'premise');
    final undoDepth = doc.commands.undoDepth;

    // Press far from the origin and from the line; R mid-press; move;
    // release near the line's end.
    final pressAt = far + Vector2(900.5, -650.25);
    final releaseRaw = lineEnd + Vector2(62.5, -55.25);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.down(globalOf(tester, pressAt));
    await tester.pump();
    expect(tool.isMidShape, isTrue, reason: 'premise: pressed');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(toolsOf(tester).active, same(tool),
        reason: 'R reached the tool, not the Rectangle binding');
    await mouse.moveTo(globalOf(tester, pressAt) + const Offset(-25, 18));
    await tester.pump();
    final releaseAt = globalOf(tester, releaseRaw);
    await mouse.moveTo(releaseAt);
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();

    final raw = worldAt(tester, releaseAt);
    final snapped = resolvedAt(tester, raw);
    expect(snapped, lineEnd, reason: 'the release snaps onto the line\'s end');
    expect(snapped.distanceTo(raw), greaterThan(50),
        reason: 'premise: snapped != raw');
    expect(snapped.distanceTo(resolvedAt(tester, raw, objectSnap: false)),
        greaterThan(10),
        reason: 'premise: the grid alone resolves elsewhere: the object '
            'snap (at 10 px over the camera scale) decides');
    expect(snapped.distanceTo(resolvedAt(tester, pressAt)), greaterThan(1000),
        reason: 'premise: the press resolves elsewhere');

    final placed = instancesOf(doc).single;
    expect(doc.commands.undoDepth, undoDepth + 1, reason: 'one undo step');
    final definition = placed.definition;
    expect(doc.tree.definition(definition)!.basePoint, base);
    final want = placementTransform(
        at: snapped, basePoint: base, quarterTurns: 1, mirrored: false);
    final t = placed.transform;
    expect([t.a, t.b, t.c, t.d], [want.a, want.b, want.c, want.d],
        reason: 'one quarter turn, not mirrored: exact');
    expect([want.a, want.b, want.c, want.d], [0.0, 1.0, -1.0, 0.0],
        reason: 'premise: a counter-clockwise quarter turn');
    expect(
        Tolerance.standard.eq(t.e, want.e) &&
            Tolerance.standard.eq(t.f, want.f),
        isTrue,
        reason: 'translation ${[t.e, t.f]} vs ${[want.e, want.f]}');
    expect(
        doc.components.withComponent<SymbolComponent>(), contains(definition));
    final placedHandle = placed.handle;
    final placedTransform = [t.a, t.b, t.c, t.d, t.e, t.f];

    // Undo and redo through the shell's chords; the tool is armed, idle.
    await undoKey(tester);
    expect(instancesOf(doc), isEmpty, reason: 'undo removes the instance');
    expect(doc.tree.definition(definition), isNull,
        reason: 'and its definition');
    expect(doc.components.withComponent<SymbolComponent>(), isEmpty);
    expect(toolsOf(tester).active, same(tool), reason: 'still armed');
    await redoKey(tester);
    final again = instancesOf(doc).single;
    expect(again.handle, placedHandle);
    expect(again.definition, definition);
    expect(doc.tree.definition(definition), isNotNull);
    final r = again.transform;
    expect([r.a, r.b, r.c, r.d, r.e, r.f], placedTransform);

    // Save As -> Open those bytes -> Save: the second bytes are the first.
    final host = hostOf(tester);
    files.scriptSaveLocation(name: 'beds.jetplan', location: '/plans/beds');
    expect(await host.saveAsStep(), isTrue);
    await tester.pump();
    final first = files.writes.single;
    expect(first.bytes, bytesOf(doc), reason: 'the codec\'s bytes');
    files.scriptOpen(
        name: 'beds.jetplan', bytes: first.bytes, location: '/plans/beds');
    await host.openFlow();
    await tester.pump();
    noDialog(tester);
    final opened = session.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    final back = instancesOf(opened).single;
    final o = back.transform;
    expect([o.a, o.b, o.c, o.d, o.e, o.f], placedTransform);
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first.bytes, reason: 'byte-identical');
  });
}
