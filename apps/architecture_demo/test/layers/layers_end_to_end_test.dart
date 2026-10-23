// Ported from apps/floor_planner/test/layers/layers_end_to_end_test.dart
// (audit docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md,
// section "layers/layers_end_to_end_test.dart"): E2E PORT; palette keys
// `tool-plan.line`, `tool-architecture.wall`; the painted-frame check goes
// through the canvas painter.
//
// Layers end to end, in the app, over a scripted `FakeDocumentFiles`: a line
// on layer 0; a new layer through the panel's +, named and recoloured there;
// made current; a line and a wall drawn with the real tools land on it;
// layer 0 made current again and the new layer hidden -- the painted frame
// (the canvas's own painter, `debugOnVisit`) loses both, keeps layer 0's
// line -- and shown; the wall moved to layer 0 with the Selection section's
// picker; the new layer made current again; Save, Open, Save:
// byte-identical, the current layer and every layer kept.
//
// Not degenerate: the camera is rotated and centred far from the origin,
// nothing is drawn at the origin, the new layer is ACI 3 (not 7), and the
// saved current layer is not layer 0.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show DraftCanvas, DraftCanvasState, SelectionKey;
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/app_fakes.dart';
import '../support/app_rig.dart';

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.pump();
}

/// The entity records the parametric object [group] owns.
Set<Handle> childrenOf(DraftDocument doc, Handle group) => {
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    };

Handle layerOf(DraftDocument doc, Handle h) =>
    doc.entities.layerAt(doc.entities.slotOf(h)!);

/// Lines in [doc] owned by the root, ascending.
List<Handle> linesOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.line &&
            doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// One line from [a] to [b] through the Line tool's palette entry, then
/// Escape twice: the chain ended, back to Select.
Future<void> drawLine(
    WidgetTester tester, PlanController c, Vector2 a, Vector2 b) async {
  await tapKey(tester, 'tool-plan.line');
  await clickAt(tester, c, a);
  await clickAt(tester, c, b);
  await press(tester, LogicalKeyboardKey.escape);
  await press(tester, LogicalKeyboardKey.escape);
  expect(c.activeTool.value, 'plan.select', reason: 'premise: back to Select');
}

/// One wall from [a] to [b] through the Wall tool's palette entry (two
/// clicks, Enter), then Escape to Select.
Future<void> drawWallByPalette(
    WidgetTester tester, PlanController c, Vector2 a, Vector2 b) async {
  await tapKey(tester, 'tool-architecture.wall');
  await clickAt(tester, c, a);
  await clickAt(tester, c, b);
  await press(tester, LogicalKeyboardKey.enter);
  await press(tester, LogicalKeyboardKey.escape);
  expect(c.activeTool.value, 'plan.select', reason: 'premise: back to Select');
}

/// Whether layer [h]'s row shows the current mark.
/// Whether row [h]'s mark says it is the current layer: its button is named
/// "Current layer" (a row that is not says "Make current").
bool isCurrentRow(WidgetTester tester, Handle h) =>
    tester.widget<PlanIconButton>(byKey('layer-current-${h.toHex()}')).label ==
    'Current layer';

String nameOfRow(WidgetTester tester, Handle h) => tester
    .widget<Text>(find.descendant(
        of: byKey('layer-name-${h.toHex()}'), matching: find.byType(Text)))
    .data!;

void main() {
  testWidgets(
      'E2E make a layer, make it current, draw a line and a wall on it, hide '
      'it (both leave the painted frame), show it, move the wall to layer 0 '
      'with the picker, Save, Open, Save: byte-identical, the current layer '
      'and every layer kept', (tester) async {
    final files = FakeDocumentFiles();
    final rig = await pumpApp(tester, files: files);
    final c = rig.controller;
    final doc = c.document;
    final zero = ReservedHandles.layerZero;
    expect(doc.tables.layers.records.map((r) => r.handle), [zero],
        reason: 'premise: a new document has layer 0 only');
    await aimCamera(tester, c, Vector2(8400.5, 5300.25));

    // A line on layer 0: what the frame keeps throughout.
    await drawLine(
        tester, c, Vector2(6200.5, 4100.25), Vector2(7900.75, 4600.5));
    final keep = linesOf(doc).single;
    expect(layerOf(doc, keep), zero);

    // + adds `Layer 1` and opens its name field: name it, recolour it.
    await tapKey(tester, 'layers-add');
    final l =
        doc.tables.layers.records.singleWhere((r) => r.handle != zero).handle;
    final hex = l.toHex();
    expect(doc.tables.layers[l]!.name, 'Layer 1');
    await tester.enterText(byKey('layer-name-field-$hex'), 'Furniture');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    await tester.tap(byKey('layer-colour-$hex'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('layer-colour-item-3'));
    await tester.pumpAndSettle();
    expect(doc.tables.layers[l]!.name, 'Furniture');
    expect(doc.tables.layers[l]!.color, const IndexedColor(3));

    // Make it current; the tools draw on it.
    await tapKey(tester, 'layer-current-$hex');
    expect(doc.header.currentLayer, l);
    expect(drawingLayer(doc), l);
    await drawLine(
        tester, c, Vector2(7000.25, 5900.5), Vector2(9800.5, 6300.75));
    final line = linesOf(doc).last;
    expect(line, isNot(keep));
    expect(layerOf(doc, line), l);
    await drawWallByPalette(
        tester, c, Vector2(6500.5, 7300.25), Vector2(10200.75, 7600.5));
    final wall = wallsOf(c).single;
    expect(doc.components.get<ObjectLayer>(wall)?.layer, l);
    final wallChildren = childrenOf(doc, wall);
    expect(wallChildren, isNotEmpty, reason: 'premise: the wall generated');
    for (final k in wallChildren) {
      expect(layerOf(doc, k), l, reason: 'wall child ${k.toHex()}');
    }

    // The painted frame: the canvas's own painter reports every leaf it
    // hands the sink.
    final canvas = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final visited = <Handle>{};
    canvas.painter.debugOnVisit = visited.add;
    addTearDown(() => canvas.painter.debugOnVisit = null);
    RenderCustomPaint paintBox() => tester
        .renderObjectList<RenderCustomPaint>(find.descendant(
            of: find.byType(DraftCanvas), matching: find.byType(CustomPaint)))
        .first;
    paintBox().markNeedsPaint();
    await tester.pump();
    expect(visited, containsAll({keep, line, ...wallChildren}),
        reason: 'not vacuous: everything draws first');

    // The current layer cannot be hidden: make layer 0 current, then hide.
    expect(tester.widget<PlanIconButton>(byKey('layer-eye-$hex')).onPressed,
        isNull,
        reason: 'premise: decision 7');
    await tapKey(tester, 'layer-current-${zero.toHex()}');
    expect(drawingLayer(doc), zero);
    visited.clear();
    await tapKey(tester, 'layer-eye-$hex');
    expect(doc.tables.layers[l]!.visible, isFalse);
    await tester.pump();
    expect(visited, contains(keep), reason: 'the frame was repainted');
    expect(visited, isNot(contains(line)), reason: 'the line is hidden');
    for (final k in wallChildren) {
      expect(visited, isNot(contains(k)), reason: 'wall child ${k.toHex()}');
    }

    // Show it: both come back.
    visited.clear();
    await tapKey(tester, 'layer-eye-$hex');
    expect(doc.tables.layers[l]!.visible, isTrue);
    await tester.pump();
    expect(visited, containsAll({keep, line, ...wallChildren}),
        reason: 'shown again');

    // Move the wall to layer 0 with the picker: select it by a click on
    // its middle, open the menu, choose 0.
    final depth = doc.commands.undoDepth;
    await clickAt(tester, c, Vector2(8350.625, 7450.375));
    expect(c.activeSelection.keys, {SelectionKey.root(wall)},
        reason: 'premise: the click selected the wall');
    expect(tester.widget<Text>(byKey('layer-picker-value')).data, 'Furniture');
    await tester.tap(byKey('layer-picker'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('layer-picker-item-${zero.toHex()}'));
    await tester.pumpAndSettle();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(doc.components.get<ObjectLayer>(wall)?.layer, zero);
    for (final k in childrenOf(doc, wall)) {
      expect(layerOf(doc, k), zero, reason: 'wall child ${k.toHex()}');
    }
    expect(layerOf(doc, line), l, reason: 'the line stayed');

    // The new layer current again, so the file's current layer is not 0:
    // nothing selected first, so the right column shows the Layers section.
    c.select({});
    await tester.pump();
    await tapKey(tester, 'layer-current-$hex');
    expect(doc.header.currentLayer, l);
    final layersBefore = {
      for (final r in doc.tables.layers.records)
        r.handle: (r.name, r.color, r.visible, r.locked),
    };
    expect(layersBefore, hasLength(2));
    expect(c.dirty.value, isTrue);

    // Save, Open, Save.
    files.scriptSaveLocation(name: 'layers.jetplan', location: '/p/layers');
    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    final first = files.writes.single.bytes;
    expect(c.dirty.value, isFalse);

    files.scriptOpen(
        name: 'layers.jetplan', bytes: first, location: '/p/layers');
    await rig.host.openFlow();
    await tester.pump();
    await tester.pump();
    noDialog(tester);
    final opened = c.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: reopened');
    expect(opened.header.currentLayer, l, reason: 'the current layer kept');
    expect(drawingLayer(opened), l);
    expect({
      for (final r in opened.tables.layers.records)
        r.handle: (r.name, r.color, r.visible, r.locked),
    }, layersBefore, reason: 'every layer kept');
    expect(isCurrentRow(tester, l), isTrue, reason: 'the panel shows it');
    expect(nameOfRow(tester, l), 'Furniture');
    expect(layerOf(opened, line), l);
    expect(opened.components.get<ObjectLayer>(wall)?.layer, zero);

    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(2), reason: 'saved in place');
    expect(files.writes[1].bytes, first, reason: 'byte-identical');
  });
}
