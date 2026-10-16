// Ported from apps/floor_planner/test/symbols/symbol_palette_end_to_end_test
// .dart (audit docs/superpowers/specs/2026-10-16-architecture-demo-test-audit
// .md, section "symbols/symbol_palette_end_to_end_test.dart"): E2E PORT.
// `bed.double@1` is `architecture.bed.double@1`.
//
// The symbol palette through the app's real widgets, focus and key path,
// from the Symbols tab to a byte-identical save round trip. No tool method
// is called directly.
//
// Fixtures: the app over a scripted `FakeDocumentFiles`; the kit's furniture
// loaded through the controller. The camera is rotated, at 0.1 px/mm,
// centred far from the origin; `bed.double`'s base point is off its origin
// (checked); the press and the release are far from the origin and from each
// other; the release lands near a line drawn with the Line tool, so the
// snapped point (the line's end) differs from the raw one.
//
// Decided: premise impossible (the old test passed its own recording
// thumbnail cache to the app and matched the cell's image to the cache's
// futures): the app does not inject a cache. The controller's own cache is
// public (`c.thumbnails`), so the cell's image is matched to it instead:
// the same key (symbol id, the cell's size and pixel ratio, the theme's
// foreground) answers the cached entry, and the cell's image is a clone of it.
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/symbol_rig.dart';

const String bedId = 'architecture.bed.double@1';
final Finder bedCell = find.byKey(const Key('symbol-cell-$bedId'));

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

void main() {
  testWidgets(
      'E2E the Symbols tab, search "bed", a tap on the double bed, a press '
      'far from the origin, R mid-press, a release near a line: one '
      'instance at the snapped release point, one quarter turn; undo and '
      'redo through the editor; Save As -> Open -> Save byte-identical',
      (tester) async {
    final files = FakeDocumentFiles();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rig = await pumpApp(tester, files: files);
    final c = rig.controller;
    await symbolsReady(tester, c);
    final bed = symbolOf(c, 'bed.double');
    expect(bed.id, bedId);
    final base = bed.entry.definition.basePoint;
    expect(base.x != 0 && base.y != 0, isTrue,
        reason: 'the base point is off the origin on both axes');

    final doc = c.document;
    // A short line through the Line tool, drawn zoomed in (a fine grid),
    // so its end is off the coarse grid of the placement's zoom: the
    // release then snaps onto that end by the object snap alone.
    final lineStart = kFar + Vector2(-1820.3, 960.7);
    await aimCameraAt(tester, c, lineStart + Vector2(45, 24), 2.5);
    await press(tester, LogicalKeyboardKey.keyL);
    expect(c.activeTool.value, 'plan.line', reason: 'premise');
    await clickAt(tester, c, lineStart);
    await clickAt(tester, c, lineStart + Vector2(90.35, 47.85));
    await press(tester, LogicalKeyboardKey.escape);
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, 'plan.select', reason: 'premise');

    await aimCamera(tester, c, kFar);
    expect(c.camera.value.scale, isNot(1.0), reason: 'a non-unit scale');
    final line = lineSlotsOf(doc).single;
    final coords = doc.geometry.read(doc.entities.geomIndexAt(line)).coords;
    final lineEnd = Vector2(coords[2], coords[3]);
    expect(lineEnd.length, greaterThan(40000), reason: 'premise: far');

    // The Symbols tab; "bed" typed in the search field; the search action
    // hands the focus back to the canvas.
    await tapFinder(tester, tabSymbols);
    await tester.enterText(searchField, 'bed');
    await tester.pump();
    expect(canvasFocused(tester), isFalse, reason: 'premise: the field');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(canvasFocused(tester), isTrue, reason: 'Enter hands focus back');
    final shownIds = galleryIdsOf(tester);
    expect(shownIds, contains(bedId));
    expect(shownIds, isNot(contains('architecture.dining.chair@1')),
        reason: 'the search filtered');
    expect(shownIds.length, lessThan(c.symbols.length),
        reason: 'the search filtered');
    expect(shownIds, idsMatching(c, 'bed'));

    // The thumbnails come from the controller's cache (rendered in real
    // time, under runAsync).
    await tester.ensureVisible(bedCell);
    await tester.pump();
    ui.Image? shown;
    for (var i = 0; i < 400 && shown == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      shown = tester
          .widget<RawImage>(
              find.descendant(of: bedCell, matching: find.byType(RawImage)))
          .image;
    }
    expect(shown, isNotNull, reason: 'the double bed\'s cell shows an image');
    expect(shown!.width, greaterThan(0));
    // The image is the controller's cache's (T7-M2): asked for under the
    // key the gallery used -- the symbol's id, the cell's size and pixel
    // ratio, and the foreground of the theme -- the cache answers the same
    // entry, whose image `shown` is a clone of. A cell fed by another cache
    // or by another symbol's picture is not a clone; a request the cache
    // had not seen would call the builder and throw.
    final cellImage = tester.widget<RawImage>(
        find.descendant(of: bedCell, matching: find.byType(RawImage)));
    final size = Size(cellImage.width!, cellImage.height!);
    final cache = c.thumbnails;
    final entries = cache.length;
    final cached = await tester.runAsync(() => cache.imageFor(
        key: bedId,
        document: () => throw StateError('the cell used another key'),
        logicalSize: size,
        devicePixelRatio: cellImage.scale,
        foreground: 0x000000));
    expect(cache.length, entries, reason: 'a hit: no new entry');
    expect(shown.isCloneOf(cached!), isTrue,
        reason: 'the cell shows the controller cache\'s image');

    // The tap arms the placement tool, through the editor.
    expect(c.activeTool.value, 'plan.select', reason: 'premise');
    await tester.tap(bedCell);
    await tester.pump();
    expect(c.activeTool.value, 'plan.symbol');
    expect(c.armedSymbol.value, same(bed));
    expect(canvasFocused(tester), isTrue, reason: 'the cell took no focus');
    expect(instancesOf(doc), isEmpty, reason: 'premise');
    final undoDepth = doc.commands.undoDepth;

    // Press far from the origin and from the line; R mid-press; move;
    // release near the line's end.
    final pressAt = kFar + Vector2(900.5, -650.25);
    final releaseRaw = lineEnd + Vector2(62.5, -55.25);
    final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.down(globalOf(tester, c, pressAt));
    await tester.pump();
    expect(activeTool(tester).isMidShape, isTrue, reason: 'premise: pressed');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(c.activeTool.value, 'plan.symbol',
        reason: 'R reached the tool, not the Rectangle binding');
    await mouse.moveTo(globalOf(tester, c, pressAt) + const Offset(-25, 18));
    await tester.pump();
    final releaseAt = globalOf(tester, c, releaseRaw);
    await mouse.moveTo(releaseAt);
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();

    // The release resolves to the line's end by the object snap alone: the
    // raw point is far from it, and so is where the page's grid would put
    // it (the snap chain is internal to the library; the line's end is the
    // oracle).
    final raw = rawWorldAt(tester, c, releaseRaw);
    final snapped = lineEnd;
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle);
    final scale = c.camera.value.scale;
    expect(snapped.distanceTo(raw), greaterThan(50),
        reason: 'premise: snapped != raw');
    expect(page, isNotNull, reason: 'premise: the plan has a page');
    final step = dragGridStepMm(page, scale);
    final gridOnly = step == null ? raw : snapToGrid(raw, step, page!);
    expect(snapped.distanceTo(gridOnly), greaterThan(10),
        reason: 'premise: the grid alone resolves elsewhere: the object '
            'snap (at ${kSnapAperturePixels / scale} mm) decides');
    expect(
        snapped.distanceTo(rawWorldAt(tester, c, pressAt)), greaterThan(1000),
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
    final placedHandle = placed.handle;
    final placedTransform = partsOf(t);

    // Undo and redo through the editor's chords; the tool is armed, idle.
    await undoKey(tester);
    expect(instancesOf(doc), isEmpty, reason: 'undo removes the instance');
    expect(doc.tree.definition(definition), isNull,
        reason: 'and its definition');
    expect(c.activeTool.value, 'plan.symbol', reason: 'still armed');
    await redoKey(tester);
    final again = instancesOf(doc).single;
    expect(again.handle, placedHandle);
    expect(again.definition, definition);
    expect(doc.tree.definition(definition), isNotNull);
    expect(partsOf(again.transform), placedTransform);

    // Save As -> Open those bytes -> Save: the second bytes are the first.
    files.scriptSaveLocation(name: 'beds.jetplan', location: '/plans/beds');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    final first = files.writes.single;
    expect(first.bytes, bytesOf(c), reason: 'the codec\'s bytes');
    files.scriptOpen(
        name: 'beds.jetplan', bytes: first.bytes, location: '/plans/beds');
    await rig.host.openFlow();
    await tester.pump();
    noDialog(tester);
    final opened = c.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect(partsOf(instancesOf(opened).single.transform), placedTransform);
    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first.bytes, reason: 'byte-identical');
  });
}
