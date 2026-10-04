// Spec 09c "Testing" and Exit gate, plan 09c-1 Task 11: wall-aware placement
// through the app's real widgets, from the Symbols tab to a byte-identical
// save round trip, and a plan saved before 09c opened, saved and placed into.
//
// Fixtures (plan P-2): the app over a scripted `DocumentFiles` and a loader
// over the real asset read by `File`; walls added through the document's
// commands, each in its own group with a non-identity transform near
// (1e5, −7e4); a camera at 0.1 px/mm, rotated, so the attach capture is
// 160 mm and the edge capture 100 mm. The L is 100 and 240 mm thick, its two
// walls justified differently, so its inside corner is the drawn faces'
// meet, not the centrelines'. Every pointer is a mouse gesture on the
// canvas; no tool method is called directly. Each placement's transform is
// compared, byte for byte, with `attachToWall` computed here from the
// document (its runs from `faceRunsOf`, its neighbours from the placed
// instances), and its flushness is checked against the definition's own
// drawn vertices, not against `SymbolBox`.
import 'dart:io';
import 'dart:typed_data';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:floor_planner/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Tolerance;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/document_rig.dart';
import '../support/fake_document_files.dart';
import '../support/pre_09c_library.dart';
import '../support/wall_attach_fixture.dart' show attachGroup, farAt;
import '../support/wall_fixture.dart' show addWall, polar;

final Uint8List assetBytes =
    File('../../packages/jet_cad_floor_plan/assets/library/furniture.jetlib')
        .readAsBytesSync();

/// The app over [files] with a loader over the real asset.
Future<SymbolLibrary> pumpSymbolsApp(
    WidgetTester tester, FakeDocumentFiles files) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final loader = SymbolLibraryLoader(read: () async => assetBytes);
  addTearDown(loader.dispose);
  final cache = SymbolThumbnails();
  addTearDown(cache.dispose);
  await tester.pumpWidget(
      FloorPlannerApp(files: files, symbols: loader, thumbnails: cache));
  await tester.pump();
  expect(loader.state, isA<SymbolLibraryReady>(), reason: 'premise: loaded');
  return (loader.state as SymbolLibraryReady).library;
}

ToolController toolsOf(WidgetTester tester) => viewOf(tester).tools;

List<InstanceNode> instancesOf(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

SymbolEntry entryOf(SymbolLibrary library, String key) =>
    library.entries.singleWhere((e) => e.key == key);

/// The raw world point the layer computes for a pointer at world [p] (the
/// screen round trip), as the tool receives it.
Vector2 rawAt(WidgetTester tester, Vector2 p) {
  final local =
      globalOf(tester, p) - tester.getTopLeft(find.byType(InteractionLayer));
  return viewOf(tester).camera.value.screenToWorld(Vector2(local.dx, local.dy));
}

/// The point `a + t·u + m·s` of run [r].
Vector2 onRun(FaceRun r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

/// Opens the Symbols tab, filters the gallery to [entry]'s name (it builds
/// its cells lazily), hands the focus back to the canvas (Enter) and taps
/// the cell: the shell arms the placement tool.
Future<SymbolPlaceTool> armBySymbolsTab(
    WidgetTester tester, SymbolEntry entry) async {
  await tester.tap(find.byKey(const Key('tab-symbols')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('symbol-search')), entry.name);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  final cell = find.byKey(Key('symbol-cell-${symbolIdOf(entry)}'));
  await tester.ensureVisible(cell);
  await tester.pump();
  await tester.tap(cell);
  await tester.pump();
  final tool = toolsOf(tester).active;
  expect(tool, isA<SymbolPlaceTool>(), reason: 'premise: armed');
  tool as SymbolPlaceTool;
  expect(tool.armed.value, same(entry), reason: 'premise: armed');
  return tool;
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

/// A mouse that hovers at world [hover], then presses there, moves and
/// releases at world [release]. Returns the raw world points of the hover
/// and of the release, and whether the ghost was attached on the hover
/// (with the attachment the tool showed).
Future<({Vector2 hoverRaw, Vector2 releaseRaw, WallAttachment? hovered})>
    hoverPressRelease(WidgetTester tester, SymbolPlaceTool tool, Vector2 hover,
        Vector2 release) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(
      location: globalOf(tester, hover) + const Offset(9, 7));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, hover));
  await tester.pump();
  expect(tool.ghostVisible, isTrue, reason: 'premise: the hover shows it');
  final hovered = tool.ghostAttachment;
  await mouse.down(globalOf(tester, hover));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, release));
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
  return (
    hoverRaw: rawAt(tester, hover),
    releaseRaw: rawAt(tester, release),
    hovered: hovered,
  );
}

/// Every accepted live wall's face runs in [doc], ascending by wall handle,
/// computed here (the shell's `WallFaces` is not read).
List<FaceRun> runsIn(DraftDocument doc) => [
      for (final h in wallsOf(doc)) ...faceRunsOf(doc, h, accept: isUsableHost),
    ];

/// The drawn vertices of [instance]'s definition, in world: every line's
/// two ends and every polyline's points, through the instance's transform.
/// Read from the document's entities, not from `SymbolBox`.
List<Vector2> drawnVertices(DraftDocument doc, InstanceNode instance) {
  final g = doc.tree.accumulatedTransform(instance.handle);
  final e = doc.entities;
  final out = <Vector2>[];
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != instance.definition) continue;
    final p = doc.geometry.read(e.geomIndexAt(slot));
    final kind = e.kindAt(slot);
    final n = kind == EntityKind.line
        ? 2
        : kind == EntityKind.polyline
            ? p.pointCount
            : 0;
    for (var i = 0; i < n; i++) {
      out.add(g.transformPoint(Vector2(p.coords[2 * i], p.coords[2 * i + 1])));
    }
  }
  return out;
}

/// Asserts [instance] stands flush against [run], turned to it: its drawn
/// vertices all on the room side (`s ≥ −tol`), the nearest exactly on the
/// face line (within 1e-9 relative to the coordinates' size), those on the
/// face spanning [width] along it; local `+y` (towards the back) on `−m`
/// (into the wall) and local `+x` on `t` (mirrored: `−t`).
void expectFlush(
    DraftDocument doc, InstanceNode instance, FaceRun run, double width,
    {required bool mirrored, required String why}) {
  final tol = 1e-9 * run.a.length;
  final vs = drawnVertices(doc, instance);
  expect(vs.length, greaterThan(4), reason: '$why: premise: drawn');
  final ss = [for (final v in vs) (v - run.a).dot(run.m)];
  final nearest = ss.reduce((a, b) => a < b ? a : b);
  expect(nearest.abs(), lessThanOrEqualTo(tol),
      reason: '$why: the back on the face line (nearest s $nearest)');
  final onFace = [
    for (var i = 0; i < vs.length; i++)
      if (ss[i].abs() <= tol) (vs[i] - run.a).dot(run.t),
  ];
  final span = onFace.reduce((a, b) => a > b ? a : b) -
      onFace.reduce((a, b) => a < b ? a : b);
  expect(span, closeTo(width, tol),
      reason: '$why: the whole back edge on the face');
  final g = instance.transform;
  final sx = mirrored ? -1.0 : 1.0;
  expect(g.c, closeTo(-run.m.x, 1e-12), reason: '$why: +y into the wall');
  expect(g.d, closeTo(-run.m.y, 1e-12), reason: '$why: +y into the wall');
  expect(g.a, closeTo(sx * run.t.x, 1e-12), reason: '$why: +x along t');
  expect(g.b, closeTo(sx * run.t.y, 1e-12), reason: '$why: +x along t');
}

/// The interval along [run]'s `t`, from its `a`, that [instance]'s back
/// edge covers (its box's back corners through the instance's transform).
({double lo, double hi}) backAlong(
    InstanceNode instance, SymbolBox box, FaceRun run) {
  final g = instance.transform;
  final u1 = (g.transformPoint(Vector2(box.left, box.back)) - run.a).dot(run.t);
  final u2 =
      (g.transformPoint(Vector2(box.right, box.back)) - run.a).dot(run.t);
  return u1 <= u2 ? (lo: u1, hi: u2) : (lo: u2, hi: u1);
}

/// The L's corner, and its two walls' world angles: A (100 thick, right
/// justified) runs 4000 at 30° into the corner, B (240 thick, left
/// justified) runs 3000 out of it at 120°: a left turn, so the left faces
/// are inside.
final Vector2 corner = farAt(-321.75, 987.5);

void main() {
  testWidgets(
      'WE1 an L of 100 and 240 mm walls, one at 30°, far from the origin, '
      'at 0.1 px/mm: the double bed armed from the Symbols tab lands flush '
      'and turned on the outside face; three base units from the inside '
      'corner, each against the previous; undo three, redo three, bytes '
      'equal; Save As -> Open -> Save byte-identical', (tester) async {
    final files = FakeDocumentFiles();
    final library = await pumpSymbolsApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;

    final hA = doc.handleSeed.next();
    doc.commands.execute(addWall(doc, hA, polar(corner, 30 + 180, 4000), corner,
        100, Justification.right,
        at: attachGroup(hA.value)));
    final hB = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, hB, corner, polar(corner, 120, 3000), 240, Justification.left,
        at: attachGroup(hB.value)));
    await aimCamera(tester, polar(corner, 30 + 180, 1500));
    final scale = viewOf(tester).camera.value.scale;
    expect(scale, closeTo(0.1, 1e-12),
        reason: 'premise: capture 160 mm, edge capture 100 mm');
    expect(wallsOf(doc), [hA, hB]);
    for (final h in [hA, hB]) {
      final g = doc.tree.accumulatedTransform(h);
      expect(g.a == 1 || g.b == 0 || g.e == 0, isFalse,
          reason: 'premise: a turned, translated group');
    }

    final runs = runsIn(doc);
    final outside = runs.singleWhere(
        (r) => r.wall == hA && r.side == FaceSide.right,
        orElse: () => throw StateError('$runs'));
    final inside = runs.singleWhere(
        (r) => r.wall == hA && r.side == FaceSide.left,
        orElse: () => throw StateError('$runs'));
    final insideB = runs.singleWhere(
        (r) => r.wall == hB && r.side == FaceSide.left,
        orElse: () => throw StateError('$runs'));
    final d = polar(Vector2.zero(), 30, 1);
    expect(outside.m.dot(Vector2(-d.y, d.x)), closeTo(-1, 1e-9),
        reason: 'premise: the outside face looks away from the L');
    // The inside run starts at the drawn inside corner: on B's inside face
    // line, which the centreline end is not (B is 240 thick, left
    // justified).
    expect((inside.a - insideB.a).dot(insideB.m).abs(), lessThan(1e-6),
        reason: 'premise: the inside run starts on B\'s drawn inside face');
    expect((corner - inside.a).length, greaterThan(100),
        reason: 'premise: the drawn corner is not the centrelines\' meet');
    expect(inside.t.dot(d), closeTo(-1, 1e-9),
        reason: 'premise: along the inside face, u grows away from it');

    // 1. The double bed, armed from the Symbols tab, hovered 120 mm off the
    // outside face, pressed there and released 40 mm further along.
    final bed = entryOf(library, 'bed.double');
    expect(bed.tags, contains(againstWallTag), reason: 'premise');
    final bedBox = boxOfEntry(bed)!;
    expect(bedBox.backCentre.y, isNot(bed.definition.basePoint.y),
        reason: 'premise: the back is not the base point');
    var tool = await armBySymbolsTab(tester, bed);
    final depth0 = doc.commands.undoDepth;
    final bedAt = await hoverPressRelease(
        tester, tool, onRun(outside, 1500, 120), onRun(outside, 1540, 100));
    List<List<FaceNeighbour>> none() => [for (final _ in runs) []];
    final hoverWant = attachToWall(runs, bedBox, bedAt.hoverRaw, 16 / scale,
        mirrored: false, neighbours: none(), edgeCaptureWorld: 10 / scale)!;
    expect(bedAt.hovered, isNotNull, reason: 'the hover attaches');
    expect(partsOf(bedAt.hovered!.transform), partsOf(hoverWant.transform),
        reason: 'the ghost on the hover is attachToWall\'s, bytes');
    final bedWant = attachToWall(runs, bedBox, bedAt.releaseRaw, 16 / scale,
        mirrored: false, neighbours: none(), edgeCaptureWorld: 10 / scale)!;
    expect(bedWant.run, same(outside), reason: 'premise: the outside face');
    final placedBed = instancesOf(doc).single;
    expect(partsOf(placedBed.transform), partsOf(bedWant.transform),
        reason: 'the release commits attachToWall\'s transform, bytes');
    expect(doc.commands.undoDepth, depth0 + 1, reason: 'one undo step');
    expectFlush(doc, placedBed, outside, 1600, mirrored: false, why: 'bed');

    // 2. Three base units along the inside face from the drawn corner: the
    // first's left side snaps to the run's start (60 mm away), the second's
    // to the first's right side (70 mm), the third's to the second's
    // (55 mm the other way).
    final unit = entryOf(library, 'kitchen.base.600');
    expect(unit.tags, contains(againstWallTag), reason: 'premise');
    final unitBox = boxOfEntry(unit)!;
    tool = await armBySymbolsTab(tester, unit);
    final units = <InstanceNode>[];
    final iInside = runs.indexOf(inside);
    for (final (i, (u, s))
        in [(360.0, 110.0), (970.0, 90.0), (1445.0, 130.0)].indexed) {
      final at = await hoverPressRelease(
          tester, tool, onRun(inside, u, s), onRun(inside, u, s));
      final neighbours = none();
      for (final n in units) {
        final (:lo, :hi) = backAlong(n, unitBox, inside);
        neighbours[iInside].add((lo: lo, hi: hi, instance: n.handle));
      }
      final want = attachToWall(runs, unitBox, at.releaseRaw, 16 / scale,
          mirrored: false,
          neighbours: neighbours,
          edgeCaptureWorld: 10 / scale)!;
      expect(want.run, same(inside), reason: 'premise: unit $i inside');
      final placed = instancesOf(doc).last;
      expect(instancesOf(doc), hasLength(2 + i));
      expect(partsOf(placed.transform), partsOf(want.transform),
          reason: 'unit $i: attachToWall\'s transform, bytes');
      expectFlush(doc, placed, inside, 600, mirrored: false, why: 'unit $i');
      units.add(placed);
    }
    expect(doc.commands.undoDepth, depth0 + 4, reason: 'one step each');
    final spans = [for (final n in units) backAlong(n, unitBox, inside)];
    expect(spans[0].lo, closeTo(0, 1e-9),
        reason: 'the first starts at the drawn corner');
    expect(spans[1].lo, closeTo(spans[0].hi, 1e-9),
        reason: 'the second\'s left end on the first\'s right end');
    expect(spans[2].lo, closeTo(spans[1].hi, 1e-9),
        reason: 'the third\'s left end on the second\'s right end');
    expect(spans[2].hi, closeTo(1800, 1e-9));
    expect(doc.tree.definitions.where((x) => x.name.contains('#')), isEmpty,
        reason: 'one definition per symbol');

    // 3. Undo three times (the three units go), redo three times: the same
    // bytes as before the undo.
    final before = bytesOf(doc);
    final unitTransforms = [for (final n in units) partsOf(n.transform)];
    for (var k = 0; k < 3; k++) {
      await undoKey(tester);
    }
    expect([for (final n in instancesOf(doc)) n.handle], [placedBed.handle],
        reason: 'three undo steps took the three units only');
    expect(doc.tree.definitions, hasLength(1),
        reason: 'and the unit\'s definition');
    expect(toolsOf(tester).active, same(tool), reason: 'still armed');
    for (var k = 0; k < 3; k++) {
      await redoKey(tester);
    }
    expect([for (final n in instancesOf(doc).skip(1)) partsOf(n.transform)],
        unitTransforms);
    expect(bytesOf(doc), before, reason: 'redo restores the bytes');

    // 4. Save As -> Open those bytes -> Save: the second bytes are the
    // first.
    final host = hostOf(tester);
    files.scriptSaveLocation(name: 'l.jetplan', location: '/plans/l');
    expect(await host.saveAsStep(), isTrue);
    await tester.pump();
    final first = files.writes.single;
    expect(first.bytes, before, reason: 'the codec\'s bytes');
    files.scriptOpen(name: 'l.jetplan', bytes: first.bytes, location: '/p/l');
    await host.openFlow();
    await tester.pump();
    noDialog(tester);
    final opened = session.document;
    expect(identical(opened, doc), isFalse, reason: 'premise: swapped');
    expect([for (final n in instancesOf(opened)) partsOf(n.transform)],
        [partsOf(placedBed.transform), ...unitTransforms]);
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes, hasLength(2));
    expect(files.writes.last.bytes, first.bytes, reason: 'byte-identical');
  });

  testWidgets(
      'WE2 a plan saved before 09c (its definitions from the pre-09c '
      'library): open and save are byte-identical; the current library\'s '
      'double bed, wardrobe, base unit and desk reuse its definitions (no '
      '#2), and the wardrobe, mirrored, attaches to a −112.5° wall',
      (tester) async {
    // The plan: a wall at −112.5° in a turned group far from the origin,
    // and the four old symbols placed by the placer away from it, turned
    // and mirrored.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final old = newDocument(measurer);
    final system = installParametric(old);
    final wallStart = farAt(1234.5, 678.25);
    final hw = old.handleSeed.next();
    old.commands.execute(addWall(old, hw, wallStart,
        polar(wallStart, -112.5, 3600), 150, Justification.centre,
        at: attachGroup(hw.value)));
    final oldLibrary = pre09cLibrary();
    const keys = [
      'bed.double',
      'bed.wardrobe',
      'kitchen.base.600',
      'office.desk'
    ];
    for (final (i, key) in keys.indexed) {
      final e = entryOf(oldLibrary, key);
      expect(e.tags, isNot(contains(againstWallTag)), reason: 'premise: old');
      old.commands.execute(placeSymbol(old, e,
          at: farAt(-5200.5 + 2600.25 * i, 4100.75 - 310.5 * i),
          quarterTurns: i + 1,
          mirrored: i.isOdd));
    }
    system.dispose();
    final oldDefinitions = {
      for (final x in old.tree.definitions)
        old.components.get<SymbolComponent>(x.handle)!.key: x.handle,
    };
    expect(oldDefinitions.keys, unorderedEquals(keys));
    expect([for (final x in old.tree.definitions) x.name],
        unorderedEquals([for (final k in keys) '$k@1']),
        reason: 'premise: one definition each, under its plain name');
    final saved = bytesOf(old);

    final files = FakeDocumentFiles();
    final library = await pumpSymbolsApp(tester, files);
    final host = hostOf(tester);
    files.scriptOpen(name: 'old.jetplan', bytes: saved, location: '/p/old');
    await host.openFlow();
    await tester.pump();
    noDialog(tester);
    final session = sessionOf(tester);
    final doc = session.document;
    expect(instancesOf(doc), hasLength(4), reason: 'premise: opened');
    expect(await host.saveStep(), isTrue);
    await tester.pump();
    expect(files.writes.single.bytes, saved,
        reason: 'open and save change no byte, the symbols\' included');

    // The current library's entries of the same keys, placed through the
    // shell: free ones well away from the wall, the wardrobe mirrored on
    // the wall's face.
    final wall = wallsOf(doc).single;
    final runs = runsIn(doc);
    final face = runs.firstWhere((r) => r.wall == wall);
    await aimCamera(tester, onRun(face, 1800, 900));
    final scale = viewOf(tester).camera.value.scale;
    for (final (i, key) in keys.indexed) {
      final e = entryOf(library, key);
      expect(e.tags, contains(againstWallTag), reason: 'premise: $key now');
      final tool = await armBySymbolsTab(tester, e);
      final count = instancesOf(doc).length;
      if (key == 'bed.wardrobe') {
        await press(tester, LogicalKeyboardKey.keyM);
        expect(tool.mirrored, isTrue, reason: 'premise: M mirrors');
        final at = await hoverPressRelease(
            tester, tool, onRun(face, 2100, 130), onRun(face, 2050, 120));
        final want = attachToWall(
            runs, boxOfEntry(e)!, at.releaseRaw, 16 / scale,
            mirrored: true,
            neighbours: [for (final _ in runs) []],
            edgeCaptureWorld: 10 / scale)!;
        expect(want.run, same(face), reason: 'premise');
        final placed = instancesOf(doc).last;
        expect(partsOf(placed.transform), partsOf(want.transform),
            reason: 'the wardrobe attaches, mirrored, bytes');
        expectFlush(doc, placed, face, 1800, mirrored: true, why: key);
        await press(tester, LogicalKeyboardKey.keyM);
      } else {
        // 1500 to 2400 mm into the room: no face within capture.
        final p = onRun(face, 600 + 900.0 * i, 1500 + 300.0 * i);
        await hoverPressRelease(tester, tool, p, p);
        expect(tool.ghostAttachment, isNull, reason: 'premise: $key free');
      }
      expect(instancesOf(doc), hasLength(count + 1), reason: key);
      expect(instancesOf(doc).last.definition, oldDefinitions[key],
          reason: '$key reuses the pre-09c definition');
    }
    expect([for (final x in doc.tree.definitions) x.name],
        unorderedEquals([for (final k in keys) '$k@1']),
        reason: 'no #2 copy: the pre-09c definitions are leaf-equal');
  });
}
