// Spec 09c "Testing" and Exit gate, plan 09c-2 Task 5: the wall-aware move
// (D8) and the Symbol section (D7) through the app's real widgets, from a
// placement to a byte-identical save round trip.
//
// Fixtures as plan 09c-1's (P-2): two walls far from the origin, each in
// its own turned group, at 30° and 120°, 150 and 200 mm thick, justified
// differently; a camera at 0.1 px/mm, rotated, so the attach capture is
// 160 mm and the edge capture 100 mm. Every pointer is a mouse gesture on
// the canvas and every section row is tapped or typed into; no tool or
// panel method is called directly. Each move's transform is compared, byte
// for byte, with `attachToWall` computed here for the plain-moved
// back-centre (S-1), whose plain move is the tool's drag chain
// (`resolveDragPoint`) at the press and the release.
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';
import '../support/wall_attach_fixture.dart' show attachGroup, farAt;
import '../support/wall_fixture.dart' show addWall, polar;
import 'wall_attach_end_to_end_test.dart'
    show
        armBySymbolsTab,
        entryOf,
        expectFlush,
        hoverPressRelease,
        instancesOf,
        onRun,
        partsOf,
        pumpSymbolsApp,
        rawAt,
        redoKey,
        runsIn,
        toolsOf;

/// The point the Select tool's drag chain resolves for the raw world point
/// [raw] (spec 03 D8): object snap at the 10 px aperture, then the page's
/// grid, as `SelectTool` asks it, in the current shell.
Vector2 dragPointAt(WidgetTester tester, Vector2 raw) {
  final view = viewOf(tester);
  final scale = view.camera.value.scale;
  final page = view.page.value;
  final out = DragPoint();
  resolveDragPoint(
    raw: raw,
    orthoBase: null,
    index: view.index,
    apertureWorld: kSnapAperturePixels / scale,
    objectSnap: true,
    page: page,
    gridStepMm: dragGridStepMm(page, scale),
    scratch: SnapResult(),
    out: out,
  );
  return out.point.clone();
}

/// A mouse press at world [from], a move halfway, a move to world [to] and
/// a release there. Returns the plain move's delta the tool computes: the
/// drag point at the release less the drag point at the press, read before
/// the gesture (a drag's preview changes no document).
Future<Transform2> dragBody(
    WidgetTester tester, Vector2 from, Vector2 to) async {
  final base = dragPointAt(tester, rawAt(tester, from));
  final target = dragPointAt(tester, rawAt(tester, to));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: globalOf(tester, from));
  await tester.pump();
  await mouse.down(globalOf(tester, from));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, (from + to) / 2));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, to));
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
  return Transform2.translation(target.x - base.x, target.y - base.y);
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

void main() {
  testWidgets(
      'WE3 the double bed placed on a 30° wall, dragged about 700 mm along it, '
      'then onto a 120° wall: each move attachToWall\'s, bytes, one step; '
      'the Size menu, Rotation and Mirror rows, one step each; undo four, '
      'redo four, bytes equal; Save As -> Open -> Save byte-identical',
      (tester) async {
    final files = FakeDocumentFiles();
    final library = await pumpSymbolsApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;

    final startA = farAt(-321.75, 987.5);
    final hA = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, hA, startA, polar(startA, 30, 3600), 150, Justification.centre,
        at: attachGroup(hA.value)));
    final startB = farAt(2200.25, 3600.5);
    final hB = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, hB, startB, polar(startB, 120, 3600), 200, Justification.left,
        at: attachGroup(hB.value)));
    await aimCamera(tester, farAt(1300, 3300));
    final scale = viewOf(tester).camera.value.scale;
    expect(scale, closeTo(0.1, 1e-12),
        reason: 'premise: capture 160 mm, edge capture 100 mm');
    final runs = runsIn(doc);
    final runA = runs.singleWhere(
        (r) => r.wall == hA && r.side == FaceSide.left,
        orElse: () => throw StateError('$runs'));
    final runB = runs.singleWhere(
        (r) => r.wall == hB && r.side == FaceSide.left,
        orElse: () => throw StateError('$runs'));
    List<List<FaceNeighbour>> none() => [for (final _ in runs) []];
    WallAttachment attachAt(SymbolBox box, Vector2 p) =>
        attachToWall(runs, box, p, 16 / scale,
            mirrored: false, neighbours: none(), edgeCaptureWorld: 10 / scale)!;

    // 1. The double bed, armed from the Symbols tab, placed against A's
    // left face, then Escape to Select.
    final bed = entryOf(library, 'bed.double');
    final bedBox = boxOfEntry(bed)!;
    expect(familyTagOf(bed), 'family:bed-double', reason: 'premise');
    final placeTool = await armBySymbolsTab(tester, bed);
    await hoverPressRelease(
        tester, placeTool, onRun(runA, 1500, 100), onRun(runA, 1500, 100));
    final handle = instancesOf(doc).single.handle;
    InstanceNode node() => doc.tree[handle]! as InstanceNode;
    expectFlush(doc, node(), runA, 1600, mirrored: false, why: 'placed');
    await press(tester, LogicalKeyboardKey.escape);
    expect(toolsOf(tester).active, isA<SelectTool>(), reason: 'premise');

    // 2. Dragged by its front edge about 700 mm along A and 60 mm into the
    // room: the back-centre plain-moved off the face attaches flush again,
    // further along by the drag's own slide.
    var depth = doc.commands.undoDepth;
    var t = node().transform;
    final from1 = t.transformPoint(Vector2(400, 0));
    final delta1 =
        await dragBody(tester, from1, from1 + runA.t * 700 + runA.m * 60);
    final want1 =
        attachAt(bedBox, delta1.multiply(t).transformPoint(bedBox.backCentre));
    expect(want1.run, same(runA), reason: 'premise: along A');
    expect(partsOf(node().transform), partsOf(want1.transform),
        reason: 'the release commits attachToWall\'s transform, bytes');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one step');
    expect(selectionKeysOf(tester), [SelectionKey.root(handle)],
        reason: 'the drag selected it');
    expectFlush(doc, node(), runA, 1600, mirrored: false, why: 'moved');
    final u0 = (t.transformPoint(bedBox.backCentre) - runA.a).dot(runA.t);
    final u1 = (node().transform.transformPoint(bedBox.backCentre) - runA.a)
        .dot(runA.t);
    // The page grid snaps the drag points: the slide is the tool's delta
    // along the face, which is not 700 mm exactly.
    expect(u1 - u0, closeTo(Vector2(delta1.e, delta1.f).dot(runA.t), 1e-6),
        reason: 'slid by the drag along the face');
    expect(u1 - u0, closeTo(700, 100), reason: 'premise: about 700 mm');
    final afterMove = bytesOf(doc);

    // 3. Dragged so its back-centre's plain move ends 50 mm off B's left
    // face: it attaches there, turned to B.
    depth = doc.commands.undoDepth;
    t = node().transform;
    final from2 = t.transformPoint(Vector2(400, 0));
    final delta2 = await dragBody(tester, from2,
        from2 + onRun(runB, 1500, 50) - t.transformPoint(bedBox.backCentre));
    final want2 =
        attachAt(bedBox, delta2.multiply(t).transformPoint(bedBox.backCentre));
    expect(want2.run, same(runB), reason: 'premise: onto B');
    expect(partsOf(node().transform), partsOf(want2.transform),
        reason: 'attachToWall\'s transform on B, bytes');
    expect(doc.commands.undoDepth, depth + 1);
    expectFlush(doc, node(), runB, 1600, mirrored: false, why: 'on B');

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
    await tester.tap(find.byKey(const Key('symbol-size-bed.double.1800')).last);
    await tester.pumpAndSettle();
    expect(doc.commands.undoDepth, depth + 1, reason: 'one Change size step');
    expect(doc.components.get<SymbolComponent>(node().definition)!.key,
        'bed.double.1800');
    final wide = boxOfEntry(entryOf(library, 'bed.double.1800'))!;
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
    expect(rotationDegreesOf(t), isNot(closeTo(45, 1)), reason: 'premise');
    await typeRotation(tester, '45');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one Rotate step');
    expect(rotationDegreesOf(node().transform), closeTo(45, 1e-9));
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
    final edited = bytesOf(doc);

    // 7. Undo four times (mirror, rotate, size, the move to B): the
    // document after the move along A. Redo four times: the edited bytes.
    for (var k = 0; k < 4; k++) {
      await undoKey(tester);
    }
    // Handles are never reissued (plan 2's handle rule): the seed keeps the
    // copied 1800 definition's five handles; nothing else differs.
    final undone = jsonDecode(utf8.decode(bytesOf(doc))) as Map;
    final moved = jsonDecode(utf8.decode(afterMove)) as Map;
    final seed = (jsonDecode(utf8.decode(edited)) as Map)['handleSeed'];
    expect(undone['handleSeed'], seed, reason: 'the seed does not rewind');
    expect(moved['handleSeed'], seed - 5, reason: 'premise: five copied');
    expect({...undone}..remove('handleSeed'), {...moved}..remove('handleSeed'),
        reason: 'undo four restores the document after the move along A');
    for (var k = 0; k < 4; k++) {
      await redoKey(tester);
    }
    expect(bytesOf(doc), edited, reason: 'redo four restores the bytes');

    // 8. Save As -> Open those bytes -> Save: the second bytes are the
    // first.
    final host = hostOf(tester);
    files.scriptSaveLocation(name: 'b.jetplan', location: '/plans/b');
    expect(await host.saveAsStep(), isTrue);
    await tester.pump();
    final first = files.writes.single;
    expect(first.bytes, edited, reason: 'the codec\'s bytes');
    files.scriptOpen(name: 'b.jetplan', bytes: first.bytes, location: '/p/b');
    await host.openFlow();
    await tester.pump();
    noDialog(tester);
    final opened = session.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect([for (final n in instancesOf(opened)) partsOf(n.transform)],
        [partsOf(m)]);
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first.bytes, reason: 'byte-identical');
  });
}

List<SelectionKey> selectionKeysOf(WidgetTester tester) =>
    viewOf(tester).selection.keys.toList();
