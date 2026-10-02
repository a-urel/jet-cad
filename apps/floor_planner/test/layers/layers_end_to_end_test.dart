// Spec 12b Exit gate, plan 12b Task 11: layers end to end, in the app.
// `FloorPlannerApp` over a scripted `DocumentFiles`: a line on layer 0;
// a new layer through the panel's +, named and recoloured there; made
// current; a line and a wall drawn with the real tools land on it; layer 0
// made current again and the new layer hidden — the painted frame (the
// canvas's own painter, `debugOnVisit`) loses both, keeps layer 0's line —
// and shown; the wall moved to layer 0 with the Selection section's picker;
// the new layer made current again; Save, Open, Save: byte-identical, the
// current layer and every layer kept.
//
// Not degenerate: the camera is rotated and centred far from the origin,
// nothing is drawn at the origin, the new layer is ACI 3 (not 7), and the
// saved current layer is not layer 0.
import 'package:floor_planner/layers/layer_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(byKey(key));
  await tester.pump();
  await tester.pump();
}

/// The entity records the parametric object [group] owns, and their
/// layers.
Set<Handle> childrenOf(DraftDocument doc, Handle group) => {
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    };

Handle layerOf(DraftDocument doc, Handle h) =>
    doc.entities.layerAt(doc.entities.slotOf(h)!);

/// Lines in [doc], ascending.
List<Handle> linesOf(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.kindAt(slot) == EntityKind.line &&
            doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// One line from [a] to [b] through the Line tool's palette entry, then
/// Escape twice: the chain ended, back to Select.
Future<void> drawLine(WidgetTester tester, Vector2 a, Vector2 b) async {
  await tapKey(tester, 'tool-line');
  await clickAt(tester, a);
  await clickAt(tester, b);
  await press(tester, LogicalKeyboardKey.escape);
  await press(tester, LogicalKeyboardKey.escape);
  expect(viewOf(tester).tools.active, isA<SelectTool>(),
      reason: 'premise: back to Select');
}

/// One wall from [a] to [b] through the Wall tool's palette entry (two
/// clicks, Enter), then Escape to Select.
Future<void> drawWallByPalette(
    WidgetTester tester, Vector2 a, Vector2 b) async {
  await tapKey(tester, 'tool-wall');
  await clickAt(tester, a);
  await clickAt(tester, b);
  await press(tester, LogicalKeyboardKey.enter);
  await press(tester, LogicalKeyboardKey.escape);
  expect(viewOf(tester).tools.active, isA<SelectTool>(),
      reason: 'premise: back to Select');
}

/// What the layer row [h] shows.
LayerRow rowOf(WidgetTester tester, Handle h) =>
    tester.widget<LayerRow>(find.byKey(ValueKey<Handle>(h)));

void main() {
  testWidgets(
      'E2E make a layer, make it current, draw a line and a wall on it, hide '
      'it (both leave the painted frame), show it, move the wall to layer 0 '
      'with the picker, Save, Open, Save: byte-identical, the current layer '
      'and every layer kept', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final doc = sessionOf(tester).document;
    final zero = ReservedHandles.layerZero;
    expect(doc.tables.layers.records.map((r) => r.handle), [zero],
        reason: 'premise: a new document has layer 0 only');
    await aimCamera(tester, Vector2(8400.5, 5300.25));

    // A line on layer 0: what the frame keeps throughout.
    await drawLine(tester, Vector2(6200.5, 4100.25), Vector2(7900.75, 4600.5));
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
    await drawLine(tester, Vector2(7000.25, 5900.5), Vector2(9800.5, 6300.75));
    final line = linesOf(doc).last;
    expect(line, isNot(keep));
    expect(layerOf(doc, line), l);
    await drawWallByPalette(
        tester, Vector2(6500.5, 7300.25), Vector2(10200.75, 7600.5));
    final wall = wallsOf(doc).single;
    expect(doc.components.get<ObjectLayer>(wall)?.layer, l);
    final wallChildren = childrenOf(doc, wall);
    expect(wallChildren, isNotEmpty, reason: 'premise: the wall generated');
    for (final c in wallChildren) {
      expect(layerOf(doc, c), l, reason: 'wall child ${c.toHex()}');
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
    expect(tester.widget<IconButton>(byKey('layer-eye-$hex')).onPressed, isNull,
        reason: 'premise: decision 7');
    await tapKey(tester, 'layer-current-${zero.toHex()}');
    expect(drawingLayer(doc), zero);
    visited.clear();
    await tapKey(tester, 'layer-eye-$hex');
    expect(doc.tables.layers[l]!.visible, isFalse);
    await tester.pump();
    expect(visited, contains(keep), reason: 'the frame was repainted');
    expect(visited, isNot(contains(line)), reason: 'the line is hidden');
    for (final c in wallChildren) {
      expect(visited, isNot(contains(c)), reason: 'wall child ${c.toHex()}');
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
    await clickAt(tester, Vector2(8350.625, 7450.375));
    expect(viewOf(tester).selection.keys, {SelectionKey.root(wall)},
        reason: 'premise: the click selected the wall');
    expect(tester.widget<Text>(byKey('layer-picker-value')).data, 'Furniture');
    await tester.tap(byKey('layer-picker'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('layer-picker-item-${zero.toHex()}'));
    await tester.pumpAndSettle();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(doc.components.get<ObjectLayer>(wall)?.layer, zero);
    for (final c in childrenOf(doc, wall)) {
      expect(layerOf(doc, c), zero, reason: 'wall child ${c.toHex()}');
    }
    expect(layerOf(doc, line), l, reason: 'the line stayed');

    // The new layer current again, so the file's current layer is not 0.
    await tapKey(tester, 'layer-current-$hex');
    expect(doc.header.currentLayer, l);
    final layersBefore = {
      for (final r in doc.tables.layers.records)
        r.handle: (r.name, r.color, r.visible, r.locked),
    };
    expect(layersBefore, hasLength(2));
    expect(sessionOf(tester).dirty.value, isTrue);

    // Save, Open, Save.
    files.scriptSaveLocation(name: 'layers.jetplan', location: '/p/layers');
    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    final first = files.writes.single.bytes;
    expect(sessionOf(tester).dirty.value, isFalse);

    files.scriptOpen(
        name: 'layers.jetplan', bytes: first, location: '/p/layers');
    await host.openFlow();
    await tester.pump();
    await tester.pump();
    noDialog(tester);
    final opened = sessionOf(tester).document;
    expect(identical(opened, doc), isFalse, reason: 'premise: reopened');
    expect(opened.header.currentLayer, l, reason: 'the current layer kept');
    expect(drawingLayer(opened), l);
    expect({
      for (final r in opened.tables.layers.records)
        r.handle: (r.name, r.color, r.visible, r.locked),
    }, layersBefore, reason: 'every layer kept');
    expect(rowOf(tester, l).current, isTrue, reason: 'the panel shows it');
    expect(rowOf(tester, l).record.name, 'Furniture');
    expect(layerOf(opened, line), l);
    expect(opened.components.get<ObjectLayer>(wall)?.layer, zero);

    await tapKey(tester, 'toolbar-save');
    noDialog(tester);
    expect(files.writes, hasLength(2), reason: 'saved in place');
    expect(files.writes[1].bytes, first, reason: 'byte-identical');
  });
}
