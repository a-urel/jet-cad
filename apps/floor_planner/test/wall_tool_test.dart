import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/tool_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/wall_fixture.dart';

// The room of WR12, turned 23° about the far origin: no corner is square,
// no wall is axis-aligned, and every coordinate is irrational.
final Vector2 c0 = plan(0, 0), c1 = plan(4000, 300);
final Vector2 c2 = plan(3600, 3100), c3 = plan(-200, 2700);

/// A point inside the room, off every wall: the T's stem starts here.
final Vector2 s0 = plan(1300, 1900);

final Vector2 _centre = plan(1850, 1500);

/// The camera's scale in pixels per mm: the room is ~600 px across and the
/// snap aperture is 10 / 0.15 ≈ 66.7 mm.
const double _scale = 0.15;

/// A 1:20 page near the far origin, grid snap off, and one survey tick per
/// point of [c0]..[c3] and [s0]: a root LINE from the point, 400 mm
/// outward. A click near a point snaps onto the tick's endpoint, so the
/// snapped point is known exactly and differs from the raw pointer point.
DraftDocument wallShellDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          snapToGrid: false)));
  for (final p in [c0, c1, c2, c3, s0]) {
    final out = (p - _centre).normalized() * 400;
    doc.commands
        .execute(addDrafted(doc, EntityKind.line, linePayload(p, p + out)));
  }
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell, then sets a rotated, **non-reflecting** camera centred
/// on the room at the far origin.
Future<PlannerView> pumpWalls(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(_centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

/// A primary click at world [p] plus the raw offset `(dx, dy)` in mm.
Future<void> clickAt(WidgetTester tester, PlannerView view, Vector2 p,
    [double dx = 0, double dy = 0]) async {
  final s = view.camera.value.worldToScreen(Vector2(p.x + dx, p.y + dy));
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
  await tester.pump();
}

/// A click near [p]: 12 mm and -9 mm off, well inside the aperture.
Future<void> clickNear(WidgetTester tester, PlannerView view, Vector2 p) =>
    clickAt(tester, view, p, 12, -9);

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// The shell's Wall tool, found through its palette entry.
WallTool wallTool(WidgetTester tester) => tester
    .widget<ToolPalette>(find.byType(ToolPalette))
    .entries
    .firstWhere((e) => e.keyName == 'tool-wall')
    .tool as WallTool;

/// Every wall, ascending by handle.
List<Handle> walls(DraftDocument doc) =>
    doc.components.withComponent<WallParams>().toList();

/// [p]'s coordinates, for exact list comparison.
List<double> xy(Vector2 p) => [p.x, p.y];

/// A stored wall's left and right face offsets (spec 07 D2), written out
/// here rather than read from `WorldWall.offsets`.
(double, double) facesOf(WallParams p) => switch (p.justification) {
      Justification.centre => (p.thickness / 2, -p.thickness / 2),
      Justification.left => (p.thickness, 0),
      Justification.right => (0, -p.thickness),
    };

/// Wall [a] runs into a node that wall [b] runs out of: they share exactly
/// two outline corners, each at the Cramer meet of the faces on its side.
void expectMitre(DraftDocument doc, Handle a, Handle b) {
  final wa = worldWallOf(doc, a), wb = worldWallOf(doc, b);
  final ra = worldOutline(doc, a), rb = worldOutline(doc, b);
  final shared = sharedNear(ra, rb);
  expect(shared, hasLength(2), reason: '${a.toHex()} / ${b.toHex()}');
  final (al, ar) = facesOf(doc.components.get<WallParams>(a)!);
  final (bl, br) = facesOf(doc.components.get<WallParams>(b)!);
  final (a1, a2) = face(wa, al);
  final (b1, b2) = face(wb, bl);
  final (a3, a4) = face(wa, ar);
  final (b3, b4) = face(wb, br);
  expect(nearestIn(shared, oracleMeet(a1, a2, b1, b2)), lessThan(1e-6));
  expect(nearestIn(shared, oracleMeet(a3, a4, b3, b4)), lessThan(1e-6));
}

/// Wall [h]'s outline is its plain rectangle: both ends square.
void expectSquare(DraftDocument doc, Handle h) {
  final w = worldWallOf(doc, h);
  final (l, r) = facesOf(doc.components.get<WallParams>(h)!);
  final (a, b) = face(w, l);
  final (c, d) = face(w, r);
  expect(isRectNear(worldOutline(doc, h), [a, b, c, d]), isTrue,
      reason: '${h.toHex()} is square at both ends');
}

void main() {
  testWidgets(
      'WT1 two clicks make one wall at the snapped points, stored exactly, '
      'in a group at the identity', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    await clickNear(tester, view, c0);
    expect(walls(doc), isEmpty);
    await clickNear(tester, view, c1);
    final h = walls(doc).single;
    final p = doc.components.get<WallParams>(h)!;
    expect(xy(p.start), xy(c0));
    expect(xy(p.end), xy(c1));
    expect([p.thickness, p.justification], [200, Justification.centre]);
    expect(doc.tree[h]!.transform, Transform2.identity());
    final w = worldWallOf(doc, h);
    expect(xy(w.s), xy(c0));
    expect(xy(w.e), xy(c1));
    expect(kids(doc, h).map((k) => kindOf(doc, k)),
        [EntityKind.fill, EntityKind.polyline, EntityKind.polyline]);
    expectSquare(doc, h);
    expect(doc.commands.undoDepth, 1);
    expect(wallTool(tester).isPending, isTrue,
        reason: 'the chain continues from the new point');
  });

  testWidgets(
      'WT2 three clicks and Enter: two walls in the current settings, '
      'joined bit for bit and mitred, two undo steps', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    wallTool(tester).settings.value =
        const WallSettings(thickness: 115, justification: Justification.left);
    await clickNear(tester, view, c0);
    await clickNear(tester, view, c1);
    await clickNear(tester, view, c2);
    await press(tester, LogicalKeyboardKey.enter);
    expect(wallTool(tester).isPending, isFalse);
    final [a, b] = walls(doc);
    final pa = doc.components.get<WallParams>(a)!;
    final pb = doc.components.get<WallParams>(b)!;
    expect([xy(pa.start), xy(pa.end)], [xy(c0), xy(c1)]);
    expect([xy(pb.start), xy(pb.end)], [xy(c1), xy(c2)]);
    expect(pa.ex == pb.sx && pa.ey == pb.sy, isTrue, reason: 'bit for bit');
    for (final p in [pa, pb]) {
      expect([p.thickness, p.justification], [115, Justification.left]);
    }
    expectMitre(doc, a, b);
    expect(driftOf(doc), isEmpty);
    expect(doc.commands.undoDepth, 2);
    doc.commands.undo();
    expect(walls(doc), [a]);
    expectSquare(doc, a);
    doc.commands.undo();
    expect(walls(doc), isEmpty);
  });

  testWidgets(
      'WT3 a click on a centreline body makes a T whose stem butts the near '
      'face; a click on a centreline end makes a node', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    // The through wall H.
    await clickNear(tester, view, c0);
    await clickNear(tester, view, c1);
    await press(tester, LogicalKeyboardKey.enter);
    // The stem S, 115 left, from s0 onto H's body: 35% along, and 20 mm
    // off the centreline toward s0 (inside H's band).
    wallTool(tester).settings.value =
        const WallSettings(thickness: 115, justification: Justification.left);
    final foot = c0 + (c1 - c0) * 0.35;
    final side = (s0 - project(s0, c0, c1)).normalized();
    await clickNear(tester, view, s0);
    await clickAt(tester, view, foot + side * 20);
    await press(tester, LogicalKeyboardKey.enter);
    final [h, s] = walls(doc);
    final ps = doc.components.get<WallParams>(s)!;
    expect(xy(ps.start), xy(s0));
    expect(distToLine(ps.end, c0, c1), lessThan(wallJoin.linear),
        reason: 'the stem ends on the centreline, not at the raw point');
    expect((ps.end - foot).length, lessThan(1e-6));
    expect(classify(worldWallOf(doc, s), 1, [worldWallOf(doc, h)]), isA<Tee>());
    // WG4's property, in the document: the stem's cap corners lie on H's
    // near face (s0's side), far from its far face; H stays a rectangle.
    final nearSign = (c1 - c0).cross(s0 - c0) > 0 ? 1.0 : -1.0; // left of H: +
    final (n1, n2) = face(worldWallOf(doc, h), 100 * nearSign);
    final (f1, f2) = face(worldWallOf(doc, h), -100 * nearSign);
    final cap = [
      for (final q in worldOutline(doc, s))
        if ((q - ps.end).length < 500) q
    ];
    expect(cap, hasLength(2));
    for (final q in cap) {
      expect(distToLine(q, n1, n2), lessThan(1e-6));
      expect(distToLine(q, f1, f2), greaterThan(150));
    }
    expectSquare(doc, h);

    // A free wall X from two raw points, then a chain whose first click
    // lands on X's end: the new wall Y starts there bit for bit.
    final q0 = plan(900, 1200), q1 = plan(2600, 1500);
    await clickAt(tester, view, q0);
    await clickAt(tester, view, q1);
    await press(tester, LogicalKeyboardKey.enter);
    final x = walls(doc).last;
    final px = doc.components.get<WallParams>(x)!;
    await clickAt(tester, view, px.end, -14, 11);
    await clickNear(tester, view, c2);
    await press(tester, LogicalKeyboardKey.enter);
    final y = walls(doc).last;
    final py = doc.components.get<WallParams>(y)!;
    expect(xy(py.start), xy(px.end));
    expect(xy(py.end), xy(c2));
    expectMitre(doc, x, y);
    expect(driftOf(doc), isEmpty);
  });

  testWidgets(
      'WT4 a closed room: four clicks and a click on the start make four '
      'walls, four mitres and four undo steps (Review Focus 1)',
      (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    for (final c in [c0, c1, c2, c3]) {
      await clickNear(tester, view, c);
    }
    expect(walls(doc), hasLength(3));
    await clickAt(tester, view, c0, -15, 13);
    expect(wallTool(tester).isPending, isFalse,
        reason: 'the closing click ends the chain');
    final ws = walls(doc);
    expect(ws, hasLength(4));
    final corners = [c0, c1, c2, c3];
    for (var i = 0; i < 4; i++) {
      final p = doc.components.get<WallParams>(ws[i])!;
      expect(
          [xy(p.start), xy(p.end)], [xy(corners[i]), xy(corners[(i + 1) % 4])]);
      expect(worldOutline(doc, ws[i]), hasLength(4));
    }
    for (var i = 0; i < 4; i++) {
      expectMitre(doc, ws[i], ws[(i + 1) % 4]);
    }
    expect(driftOf(doc), isEmpty);
    expect(diagnosticsOf(doc), isEmpty);
    expect(doc.commands.undoDepth, 4);
    for (var i = 3; i >= 0; i--) {
      doc.commands.undo();
      expect(walls(doc), ws.sublist(0, i));
    }
  });

  testWidgets(
      'WT5 a zero-length click is refused and the chain goes on; a click on '
      'the last point ends it', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, view, c0);
    // Both clicks snap onto c0's tick: a zero-length wall.
    await clickAt(tester, view, c0, -10, 14);
    expect(walls(doc), isEmpty);
    expect(doc.commands.undoDepth, 0);
    expect(wallTool(tester).isPending, isTrue);
    await clickNear(tester, view, c1);
    final a = walls(doc).single;
    expect(xy(doc.components.get<WallParams>(a)!.start), xy(c0));
    // A second click on c1 is the chain's last point: it ends the chain,
    // and the next click starts a new one.
    await clickAt(tester, view, c1, 16, 3);
    expect(wallTool(tester).isPending, isFalse);
    await clickNear(tester, view, c2);
    expect(walls(doc), [a]);
    expect(wallTool(tester).isPending, isTrue);
    await clickNear(tester, view, c3);
    final b = walls(doc).last;
    expect(xy(doc.components.get<WallParams>(b)!.start), xy(c2));
    // With one wall down, the chain's first point is an ordinary point:
    // closing needs two walls, so this click adds a wall and goes on.
    await clickAt(tester, view, c2, 9, 12);
    expect(walls(doc), hasLength(3));
    expect(wallTool(tester).isPending, isTrue);
  });

  testWidgets(
      'WT6 cmd+Z mid-chain is swallowed; Escape, then cmd+Z removes the '
      'last wall (Ruling 07-1)', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, view, c0);
    await clickNear(tester, view, c1);
    await clickNear(tester, view, c2);
    final ws = walls(doc);
    final before = enc(doc);
    await undoKey(tester);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 2);
    expect(wallTool(tester).isPending, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(wallTool(tester).isPending, isFalse);
    expect(status(tester), 'Wall');
    await undoKey(tester);
    expect(walls(doc), [ws.first]);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'WT7 W and the palette entry activate the Wall tool; W typed in a '
      'panel field does not', (tester) async {
    await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-wall')));
    await tester.pump();
    expect(status(tester), 'Wall');
    await press(tester, LogicalKeyboardKey.keyV);
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Select');
  });

  testWidgets(
      'RF2 in the shell: draw an L, select one wall, Delete: the survivor\'s '
      'end squares; cmd+Z restores the mitre (Review Focus 2)', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, view, c0);
    await clickNear(tester, view, c1);
    await clickNear(tester, view, c2);
    await press(tester, LogicalKeyboardKey.enter);
    final [a, b] = walls(doc);
    expectMitre(doc, a, b);
    await press(tester, LogicalKeyboardKey.keyV);
    // Inside A's band, 40% along it and 30 mm off its centreline.
    final side = (c2 - project(c2, c0, c1)).normalized();
    await clickAt(tester, view, c0 + (c1 - c0) * 0.4 + side * 30);
    expect(status(tester), 'Select — 1 selected');
    await press(tester, LogicalKeyboardKey.delete);
    expect(walls(doc), [b]);
    expect(doc.tree[a], isNull);
    expect(kids(doc, a), isEmpty);
    expectSquare(doc, b);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(walls(doc), [a, b]);
    expect(kids(doc, a), hasLength(3));
    expectMitre(doc, a, b);
    expect(driftOf(doc), isEmpty);
  });
}
