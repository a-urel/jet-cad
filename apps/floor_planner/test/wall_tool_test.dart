import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_geometry.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/tool_palette.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
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

/// The unit left normal of the line from [a] to [b].
Vector2 leftOf(Vector2 a, Vector2 b) {
  final d = (b - a).normalized();
  return Vector2(-d.y, d.x);
}

/// Wall [stem]'s end (index 1) is a T on [host], coming from the side of
/// [host]'s left normal given by [fromSign] (+1 left, -1 right): the stem
/// ends on the centreline, and its two cap corners lie on the host's face
/// on that side, far from the other face (WG4's property, in the
/// document).
void expectTee(DraftDocument doc, Handle host, Handle stem,
    {required double fromSign}) {
  final ph = doc.components.get<WallParams>(host)!;
  final ps = doc.components.get<WallParams>(stem)!;
  final wh = worldWallOf(doc, host);
  expect(distToLine(ps.end, wh.s, wh.e), lessThan(wallJoin.linear),
      reason: '${stem.toHex()} ends on the centreline');
  expect(classify(worldWallOf(doc, stem), 1, [wh]), isA<Tee>(),
      reason: stem.toHex());
  final (l, r) = facesOf(ph);
  final (n1, n2) = face(wh, fromSign > 0 ? l : r);
  final (f1, f2) = face(wh, fromSign > 0 ? r : l);
  final cap = [
    for (final q in worldOutline(doc, stem))
      if ((q - ps.end).length < 500) q
  ];
  expect(cap, hasLength(2), reason: stem.toHex());
  for (final q in cap) {
    expect(distToLine(q, n1, n2), lessThan(1e-6), reason: stem.toHex());
    expect(distToLine(q, f1, f2), greaterThan(150), reason: stem.toHex());
  }
}

/// Draws one wall from world [a] to world [b] by two clicks (at those
/// points exactly, plus the raw offsets) and Enter; returns it.
Future<Handle> drawWall(
    WidgetTester tester, PlannerView view, Vector2 a, Vector2 b) async {
  await clickAt(tester, view, a);
  await clickAt(tester, view, b);
  await press(tester, LogicalKeyboardKey.enter);
  return walls(view.document).last;
}

/// The Wall tool driven directly, wired as the shell wires it, over [doc]:
/// a unit camera (a 10 mm aperture), object snap on, no page (no grid).
({WallTool tool, ToolContext ctx}) directRig(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final settings = ValueNotifier<WallSettings>(const WallSettings());
  final tool = WallTool(settings);
  addTearDown(() {
    tool.dispose();
    settings.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc, index: index, camera: camera, selection: selection),
  );
}

ToolPointerEvent pointerAt(Vector2 world, {int buttons = 0}) =>
    ToolPointerEvent(
        screen: Offset.zero,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);

void hoverTo(({WallTool tool, ToolContext ctx}) rig, Vector2 world) =>
    rig.tool.onPointerMove(pointerAt(world), rig.ctx);

void pressAt(({WallTool tool, ToolContext ctx}) rig, Vector2 world) =>
    rig.tool.onPointerDown(pointerAt(world, buttons: kPrimaryButton), rig.ctx);

/// Median of [xs].
double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

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
      'WT2 three clicks and Enter: two walls, each in the settings current '
      'at its click, joined bit for bit and mitred, two undo steps',
      (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    await clickNear(tester, view, c0);
    await clickNear(tester, view, c1);
    // Mid-chain: the next wall takes the new settings, the first keeps its.
    wallTool(tester).settings.value =
        const WallSettings(thickness: 115, justification: Justification.left);
    await clickNear(tester, view, c2);
    await press(tester, LogicalKeyboardKey.enter);
    expect(wallTool(tester).isPending, isFalse);
    final [a, b] = walls(doc);
    final pa = doc.components.get<WallParams>(a)!;
    final pb = doc.components.get<WallParams>(b)!;
    expect([xy(pa.start), xy(pa.end)], [xy(c0), xy(c1)]);
    expect([xy(pb.start), xy(pb.end)], [xy(c1), xy(c2)]);
    expect(pa.ex == pb.sx && pa.ey == pb.sy, isTrue, reason: 'bit for bit');
    expect([pa.thickness, pa.justification], [200, Justification.centre]);
    expect([pb.thickness, pb.justification], [115, Justification.left]);
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

    // D11: the tool joins a wall wherever its band is clicked. On H (200,
    // centre), clicks nearer a face than the centreline, on both sides:
    // with `nearest` alone each would land on the face.
    wallTool(tester).settings.value = const WallSettings();
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0; // the room's side
    final t1 = await drawWall(tester, view, plan(2300, 1000),
        c0 + (c1 - c0) * 0.6 + nH * (95 * inSign));
    expectTee(doc, h, t1, fromSign: inSign);
    final t2 = await drawWall(tester, view, plan(3100, -1300),
        c0 + (c1 - c0) * 0.8 - nH * (60 * inSign));
    expectTee(doc, h, t2, fromSign: -inSign);
    // Inside H's band within one thickness of its end: the new wall starts
    // at H's end, bit for bit, and the two make a node.
    final len = c0.distanceTo(c1);
    final n = await drawWall(
        tester,
        view,
        c0 + (c1 - c0) * ((len - 120) / len) + nH * (70 * inSign),
        plan(5200, 1100));
    expect(xy(doc.components.get<WallParams>(n)!.start), xy(c1));
    expect(classify(worldWallOf(doc, n), 0, [worldWallOf(doc, h)]),
        isA<NodeJoint>());
    expectMitre(doc, h, n);

    // H2 (240, left) from c3 to c2: its band lies on its left only. From
    // the room (its right), a click in the band beyond the centreline makes
    // a T that butts the centreline face; a click as far off on the right
    // is outside the band and stays where it is.
    wallTool(tester).settings.value =
        const WallSettings(thickness: 240, justification: Justification.left);
    final h2 = await drawWall(tester, view, c3, c2);
    final nH2 = leftOf(c3, c2);
    expect(nH2.dot(s0 - c3), lessThan(0), reason: 'the room is on the right');
    wallTool(tester).settings.value = const WallSettings();
    final t3 = await drawWall(
        tester, view, plan(1500, 2200), c3 + (c2 - c3) * 0.4 + nH2 * 180);
    expectTee(doc, h2, t3, fromSign: -1);
    final t4 = await drawWall(
        tester, view, plan(2500, 2100), c3 + (c2 - c3) * 0.7 - nH2 * 150);
    final p4 = doc.components.get<WallParams>(t4)!;
    expect(distToLine(p4.end, c3, c2), closeTo(150, 1e-3),
        reason: 'outside the band: not joined');
    expect(
        classify(worldWallOf(doc, t4), 1, [worldWallOf(doc, h2)]), isA<Free>());
    expect(driftOf(doc), isEmpty);

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
      'WT8 a denied wall allocates no handle, changes nothing and ends the '
      'chain; structure alone is enough to deny it', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    for (final denied in const [
      DraftPermissions.runtime,
      DraftPermissions(
          transform: true, components: true, geometry: true, structure: false),
    ]) {
      doc.commands.permissions = DraftPermissions.all;
      await clickNear(tester, view, c0);
      await clickNear(tester, view, c1);
      expect(wallTool(tester).isPending, isTrue);
      doc.commands.permissions = denied;
      final seed = doc.handleSeed.current;
      final before = enc(doc);
      final count = walls(doc).length;
      await clickNear(tester, view, c2);
      expect(doc.handleSeed.current, seed);
      expect(enc(doc), before);
      expect(walls(doc), hasLength(count));
      expect(wallTool(tester).isPending, isFalse, reason: 'the chain ends');
    }
  });

  testWidgets(
      'WT9 with object snap off, a click in a wall\'s band joins nothing: it '
      'stays where it was clicked', (tester) async {
    final view = await pumpWalls(tester, wallShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyW);
    final h = await drawWall(tester, view, c0, c1);
    await press(tester, LogicalKeyboardKey.f3);
    expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
        'osnap off');
    final nH = leftOf(c0, c1);
    final inSign = nH.dot(s0 - c0) > 0 ? 1.0 : -1.0;
    final target = c0 + (c1 - c0) * 0.6 + nH * (95 * inSign);
    final t = await drawWall(tester, view, plan(2300, 1000), target);
    final pt = doc.components.get<WallParams>(t)!;
    expect(distToLine(pt.end, c0, c1), closeTo(95, 1e-3));
    expect((pt.end - target).length, lessThan(1e-3),
        reason: 'the raw point: the grid is off');
    expect(classify(worldWallOf(doc, t), 1, [worldWallOf(doc, h)]),
        isNot(isA<Tee>()));
  });

  test(
      'WT10 a hover with no chain pending scans no wall band and leaves the '
      'rubber band alone (review round 2, I2)', () {
    final doc = wallDoc();
    doc.commands.execute(addWall(doc, const Handle(1300), plan(0, 0),
        plan(4000, 0), 200, Justification.centre));
    final rig = directRig(doc);
    final inBand = plan(1200, 60);
    hoverTo(rig, inBand);
    expect(rig.tool.debugBandScans, 0);
    expect(xy(rig.tool.debugBandEnd), [0, 0]);
    pressAt(rig, plan(1500, 1500));
    final scans = rig.tool.debugBandScans;
    hoverTo(rig, inBand);
    expect(rig.tool.debugBandScans, scans + 1);
    expect(distToLine(rig.tool.debugBandEnd, plan(0, 0), plan(4000, 0)),
        lessThan(1e-6));
  });

  test(
      'WT11 after a wall moves, a hover joins its band where it is now, not '
      'where it was: the cache follows the document (review round 2, I2)',
      () async {
    final doc = wallDoc();
    const h = Handle(1300);
    doc.commands.execute(
        addWall(doc, h, plan(0, 0), plan(4000, 0), 200, Justification.centre));
    final rig = directRig(doc);
    pressAt(rig, plan(1500, 2500));
    hoverTo(rig, plan(1200, 60));
    expect(distToLine(rig.tool.debugBandEnd, plan(0, 0), plan(4000, 0)),
        lessThan(1e-6));
    // Move H 700 mm across itself, in world.
    final shift = plan(0, 700) - plan(0, 0);
    doc.commands.execute(TransformNodeCommand(
        h,
        Transform2.translation(shift.x, shift.y)
            .multiply(doc.tree.accumulatedTransform(h))));
    await Future<void>.delayed(Duration.zero);
    final w = worldWallOf(doc, h);
    hoverTo(rig, plan(1200, 760));
    expect(distToLine(rig.tool.debugBandEnd, w.s, w.e), lessThan(1e-6),
        reason: 'joined onto the moved wall');
    final old = plan(1200, 60);
    hoverTo(rig, old);
    expect((rig.tool.debugBandEnd - old).length, lessThan(1e-6),
        reason: 'the old band is empty now');
    // A click there joins the moved wall too.
    pressAt(rig, plan(2600, 640));
    final stem = walls(doc).last;
    expect(distToLine(doc.components.get<WallParams>(stem)!.end, w.s, w.e),
        lessThan(wallJoin.linear));
  });

  test(
      'WT12 the per-hover cost at 600 walls, printed, not asserted (review '
      'round 2, I2)', () {
    final doc = wallDoc();
    var next = 1000;
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < 30; i++)
        for (var j = 0; j < 20; j++)
          addWall(doc, Handle(next += 10), plan(i * 3000.0, j * 3000.0),
              plan(i * 3000.0 + 1000, j * 3000.0), 200, Justification.centre),
    ], label: 'Add 600 walls'));
    expect(walls(doc), hasLength(600));
    final rig = directRig(doc);
    pressAt(rig, plan(-5000, -5000));
    // Between the walls: in no band, so every hover scans all 600.
    final p = plan(1500, 1500);
    final raw = Vector2.zero();
    final hover = <double>[], scan = <double>[];
    const batch = 50;
    for (var k = 0; k < 200; k++) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, p);
      }
      hover.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        rig.tool.hovered(raw);
      }
      scan.add(sw.elapsedMicroseconds / batch);
    }
    expect(xy(rig.tool.debugBandEnd), xy(p), reason: 'in no band');
    // ignore: avoid_print
    print('WT12 n=600: median per hover ${median(hover).toStringAsFixed(2)} '
        'us (whole pointer move), band scan alone '
        '${median(scan).toStringAsFixed(2)} us');
  });

  test(
      'WT13 a click inside two crossing bands joins the lower handle '
      '(review round 2, m4)', () {
    final doc = wallDoc();
    final c = plan(0, 0);
    // Lower handle X1 along the plan's x; X2 crosses it at 60 degrees.
    doc.commands.execute(addWall(doc, const Handle(1300), plan(-2000, 0),
        plan(2000, 0), 200, Justification.centre));
    doc.commands.execute(addWall(doc, const Handle(2600), polar(c, 83, -2000),
        polar(c, 83, 2000), 200, Justification.centre));
    final x1 = worldWallOf(doc, const Handle(1300));
    final x2 = worldWallOf(doc, const Handle(2600));
    final rig = directRig(doc);
    pressAt(rig, plan(-1500, 1500));
    // 40 along X1 and 30 off it: about 20 off X2, inside both bands and
    // outside the 10 mm aperture of either centreline.
    final p = plan(40, 30);
    expect(distToLine(p, x2.s, x2.e), inInclusiveRange(15, 25));
    pressAt(rig, p);
    final end = doc.components.get<WallParams>(walls(doc).last)!.end;
    expect(distToLine(end, x1.s, x1.e), lessThan(wallJoin.linear));
    expect(distToLine(end, x2.s, x2.e), greaterThan(30));
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
