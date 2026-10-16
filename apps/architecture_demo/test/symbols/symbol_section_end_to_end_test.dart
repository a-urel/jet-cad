// Ported from apps/floor_planner/test/symbols/symbol_section_end_to_end_test
// .dart (audit docs/superpowers/specs/2026-10-16-architecture-demo-test-audit
// .md, section "symbols/symbol_section_end_to_end_test.dart"): WE3 PORT.
//
// The wall-aware move and the Symbol section through the app's real widgets,
// from a placement to a byte-identical save round trip.
//
// Fixtures: two walls far from the origin, each in its own turned group, at
// 30 and 120 degrees, 150 and 200 mm thick, justified differently, added
// through the document's commands (no Wall tool runs); a camera at 0.1 px/mm,
// rotated, so the attach capture is 160 mm and the edge capture 100 mm. Every
// pointer is a mouse gesture on the canvas and every section row is tapped or
// typed into; no tool or panel method is called directly.
//
// Decided: premise impossible (the old test compared each move's transform,
// byte for byte, with `attachToWall` over the plain-moved back-centre): the
// plan's move resolver is internal and its query carries the drag's own
// `keep` and `exclude`; the library pins that the drop commits the resolver's
// answer (jet_cad_2d_integration attach/symbol_move_test.dart MV4). Here the
// committed transform is checked for what the answer is: flush against the
// face the drag ended at (`expectFlush`, the drawn vertices against the face
// line), turned to it, one undo step, and slid along the face by the drag.
// Library halves: jet_cad_2d_integration attach/symbol_move_test.dart MV4,
// jet_cad_2d_plan panels/symbol_section_test.dart SW2, SW3.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolBox, SymbolComponent, boxOfEntry;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/app_fakes.dart';
import '../support/app_rig.dart';
import '../support/symbol_rig.dart';

/// A mouse press at world [from], a move halfway, a move to world [to] and
/// a release there.
Future<void> dragBody(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: globalOf(tester, c, from));
  await tester.pump();
  await mouse.down(globalOf(tester, c, from));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, c, (from + to) / 2));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, c, to));
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
}

/// Types [text] into the Rotation row and presses Enter.
Future<void> typeRotation(WidgetTester tester, String text) async {
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(find.byKey(const Key('symbol-rotation')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('symbol-rotation')), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// [box]'s four corners through [t].
List<Vector2> cornersOf(Transform2 t, SymbolBox box) => [
      for (final (x, y) in [
        (box.left, box.back),
        (box.right, box.back),
        (box.right, box.front),
        (box.left, box.front),
      ])
        t.transformPoint(Vector2(x, y)),
    ];

/// The turn of the (unmirrored) [t]'s x axis, in degrees from 0 up to 360.
double rotationOf(Transform2 t) =>
    (math.atan2(t.b, t.a) * 180 / math.pi + 360) % 360;

void main() {
  testWidgets(
      'WE3 the double bed placed on a 30 degree wall, dragged about 700 mm '
      'along it, then onto a 120 degree wall: each move flush, one step; the '
      'Size menu, Rotation and Mirror rows, one step each; undo four, redo '
      'four, bytes equal; Save As -> Open -> Save byte-identical',
      (tester) async {
    final files = FakeDocumentFiles();
    final rig = await pumpApp(tester, files: files);
    final c = rig.controller;
    await symbolsReady(tester, c);
    final doc = c.document;

    final startA = farAt(-321.75, 987.5);
    final hA = addWallAt(
        c, startA, polar(startA, 30, 3600), 150, Justification.centre);
    final startB = farAt(2200.25, 3600.5);
    final hB =
        addWallAt(c, startB, polar(startB, 120, 3600), 200, Justification.left);
    await aimCamera(tester, c, farAt(1300, 3300));
    expect(c.camera.value.scale, closeTo(0.1, 1e-12),
        reason: 'premise: capture 160 mm, edge capture 100 mm');
    final runA = faceLineOf(doc, hA, left: true);
    final runB = faceLineOf(doc, hB, left: true);

    // 1. The double bed, armed from the Symbols tab, placed against A's
    // left face, then Escape to Select.
    final bed = symbolOf(c, 'bed.double');
    final bedBox = boxOfEntry(bed.entry)!;
    await armBySymbolsTab(tester, c, bed);
    await hoverPressRelease(
        tester, c, onRun(runA, 1500, 100), onRun(runA, 1500, 100));
    final handle = instancesOf(doc).single.handle;
    InstanceNode node() => doc.tree[handle]! as InstanceNode;
    expectFlush(doc, node(), runA, 1600, mirrored: false, why: 'placed');
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, 'plan.select', reason: 'premise');

    // 2. Dragged by its front edge about 700 mm along A and 60 mm into the
    // room: the back-centre plain-moved off the face attaches flush again,
    // further along by the drag's own slide.
    var depth = doc.commands.undoDepth;
    var t = node().transform;
    final from1 = t.transformPoint(Vector2(400, 0));
    await dragBody(tester, c, from1, from1 + runA.t * 700 + runA.m * 60);
    expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
    expect(c.activeSelection.keys, {SelectionKey.root(handle)},
        reason: 'the drag selected it');
    expectFlush(doc, node(), runA, 1600, mirrored: false, why: 'moved');
    final u0 = (t.transformPoint(bedBox.backCentre) - runA.a).dot(runA.t);
    final u1 = (node().transform.transformPoint(bedBox.backCentre) - runA.a)
        .dot(runA.t);
    // The page grid snaps the drag points: the slide is the tool's delta
    // along the face, which is not 700 mm exactly.
    expect(u1 - u0, closeTo(700, 100), reason: 'premise: about 700 mm');
    expect(u1 - u0, isNot(closeTo(0, 100)), reason: 'it slid');
    final afterMove = jsonDecode(c.save()) as Map;

    // 3. Dragged so its back-centre's plain move ends 50 mm off B's left
    // face: it attaches there, turned to B.
    depth = doc.commands.undoDepth;
    t = node().transform;
    final from2 = t.transformPoint(Vector2(400, 0));
    await dragBody(tester, c, from2,
        from2 + onRun(runB, 1500, 50) - t.transformPoint(bedBox.backCentre));
    expect(doc.commands.undoDepth, depth + 1);
    expectFlush(doc, node(), runB, 1600, mirrored: false, why: 'on B');
    final uB = (node().transform.transformPoint(bedBox.backCentre) - runB.a)
        .dot(runB.t);
    // The drop point is 1500 mm along B; the page grid snaps the drag
    // points, so the committed position is the drop's projection within a
    // grid step (the run reads 1682 with the grid at its default here), not
    // anywhere flush on B's face (T7-M1).
    expect(uB, closeTo(1500, 250), reason: 'at the drop point along B');
    expect(partsOf(node().transform).take(4), isNot(partsOf(t).take(4)),
        reason: 'turned from A\'s direction to B\'s');

    // 4. The Size menu: 1800 wide, one step; the back-left corner stays,
    // the back stays on B's face.
    expect(find.byKey(const Key('symbol-section')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('symbol-size'))).data,
        '1600 × 2000');
    depth = doc.commands.undoDepth;
    t = node().transform;
    final corner = t.transformPoint(Vector2(bedBox.left, bedBox.back));
    await tester.tap(find.byKey(const Key('symbol-size-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const Key('symbol-size-architecture.bed.double.1800')).last);
    await tester.pumpAndSettle();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one Change size step');
    expect(doc.components.get<SymbolComponent>(node().definition)!.key,
        'architecture.bed.double.1800');
    final wide = boxOfEntry(symbolOf(c, 'bed.double.1800').entry)!;
    expect(partsOf(node().transform).take(4), partsOf(t).take(4),
        reason: 'the linear part kept');
    final corner2 =
        node().transform.transformPoint(Vector2(wide.left, wide.back));
    expect((corner2 - corner).length, lessThan(1e-6),
        reason: 'the back-left corner stays');
    expectFlush(doc, node(), runB, 1800, mirrored: false, why: 'resized');
    expect(tester.widget<Text>(find.byKey(const Key('symbol-size'))).data,
        '1800 × 2000');

    // 5. Rotation 45, about the insertion point: one step.
    depth = doc.commands.undoDepth;
    t = node().transform;
    final basePoint = doc.tree.definition(node().definition)!.basePoint;
    expect(rotationOf(t), isNot(closeTo(45, 1)), reason: 'premise');
    await typeRotation(tester, '45');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one Rotate step');
    expect(rotationOf(node().transform), closeTo(45, 1e-9));
    expect(
        (node().transform.transformPoint(basePoint) -
                t.transformPoint(basePoint))
            .length,
        lessThan(1e-6),
        reason: 'about the insertion point');

    // 6. Mirror: one step, the footprint kept, the handedness flipped.
    depth = doc.commands.undoDepth;
    t = node().transform;
    await tester.tap(find.byKey(const Key('symbol-mirror')));
    await tester.pump();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one Mirror step');
    final m = node().transform;
    expect(m.a * m.d - m.b * m.c, closeTo(-1, 1e-12), reason: 'mirrored');
    final before = cornersOf(t, wide), after = cornersOf(m, wide);
    for (final p in before) {
      expect(after.any((q) => (q - p).length < 1e-6), isTrue,
          reason: 'the footprint kept');
    }
    final edited = bytesOf(c);

    // 7. Undo four times (mirror, rotate, size, the move to B): the
    // document after the move along A. Redo four times: the edited bytes.
    for (var k = 0; k < 4; k++) {
      await undoKey(tester);
    }
    // Handles are never reissued: the seed keeps the copied 1800
    // definition's handles; nothing else differs.
    final undone = jsonDecode(c.save()) as Map;
    final seed = (jsonDecode(utf8.decode(edited)) as Map)['handleSeed'];
    expect(undone['handleSeed'], seed, reason: 'the seed does not rewind');
    expect(afterMove['handleSeed'], isNot(seed),
        reason: 'premise: the size copy allocated handles');
    expect(
        {...undone}..remove('handleSeed'), {...afterMove}..remove('handleSeed'),
        reason: 'undo four restores the document after the move along A');
    for (var k = 0; k < 4; k++) {
      await redoKey(tester);
    }
    expect(bytesOf(c), edited, reason: 'redo four restores the bytes');

    // 8. Save As -> Open those bytes -> Save: the second bytes are the
    // first.
    files.scriptSaveLocation(name: 'b.jetplan', location: '/plans/b');
    expect(await rig.host.saveAsStep(), isTrue);
    await tester.pump();
    final first = files.writes.single;
    expect(first.bytes, edited, reason: 'the codec\'s bytes');
    files.scriptOpen(name: 'b.jetplan', bytes: first.bytes, location: '/p/b');
    await rig.host.openFlow();
    await tester.pump();
    noDialog(tester);
    final opened = c.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect([for (final n in instancesOf(opened)) partsOf(n.transform)],
        [partsOf(m)]);
    expect(await rig.host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first.bytes, reason: 'byte-identical');
  });
}
