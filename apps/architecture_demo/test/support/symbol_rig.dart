// The Symbols tab through the app: waiting for the furniture library, the
// gallery's ids, arming a cell, the placed instances. The symbol tests'
// helper set (R-P14, with app_rig.dart's): no copies elsewhere.
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, PaperPalette, SymbolGallery, Tool, ViewportTransform;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'app_rig.dart';

final Finder tabTools = find.byKey(const Key('tab-tools'));
final Finder tabSymbols = find.byKey(const Key('tab-symbols'));
final Finder strip = find.byKey(const Key('left-tabs'));
final Finder searchField = find.byKey(const Key('symbol-search'));

/// Waits, in real time, for the furniture library to load (bounded: 400
/// rounds of 20 ms) and fails the premise when it did not.
Future<void> symbolsReady(WidgetTester tester, PlanController c) async {
  for (var i = 0; i < 400 && c.symbolsState.value != SymbolsState.ready; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(c.symbolsState.value, SymbolsState.ready,
      reason: 'premise: the furniture library loaded');
}

/// The app with its furniture loaded.
Future<AppRig> pumpSymbolsApp(WidgetTester tester) async {
  final rig = await pumpApp(tester);
  await symbolsReady(tester, rig.controller);
  return rig;
}

/// Taps [f], then one frame.
Future<void> tapFinder(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

SymbolGallery galleryOf(WidgetTester tester) =>
    tester.widget<SymbolGallery>(find.byType(SymbolGallery));

/// The gallery's cell ids, in order.
List<String> galleryIdsOf(WidgetTester tester) => [
      for (final c in galleryOf(tester).categories)
        for (final s in c.symbols) s.id,
    ];

/// The gallery's category names, in order.
List<String> categoryNamesOf(WidgetTester tester) =>
    [for (final c in galleryOf(tester).categories) c.name];

/// The ids of the loaded symbols whose stored name, category or a tag
/// carries [word], computed apart from the widget (the library's folding
/// is not needed for the lower-case words the tests use).
List<String> idsMatching(PlanController c, String word) => [
      for (final s in c.symbols)
        if ([s.component.name, s.component.category, ...s.component.tags]
            .any((t) => t.toLowerCase().contains(word)))
          s.id,
    ];

/// The loaded symbol whose stored key is the kit's `architecture.<key>`.
PlanSymbol symbolOf(PlanController c, String key) =>
    c.symbols.singleWhere((s) => s.component.key == 'architecture.$key');

/// Opens the Symbols tab, filters the gallery to [symbol]'s name (the cells
/// are built lazily), hands the focus back with the search action and taps
/// the cell: [c] has it armed and `plan.symbol` is the active tool.
Future<void> armBySymbolsTab(
    WidgetTester tester, PlanController c, PlanSymbol symbol) async {
  await tapFinder(tester, tabSymbols);
  await tester.enterText(searchField, symbol.component.name);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  final cell = find.byKey(Key('symbol-cell-${symbol.id}'));
  await tester.ensureVisible(cell);
  await tester.pump();
  await tester.tap(cell);
  await tester.pump();
  expect(c.activeTool.value, 'plan.symbol', reason: 'premise: armed');
  expect(c.armedSymbol.value, same(symbol), reason: 'premise: armed');
}

/// The document's instances, in tree order.
List<InstanceNode> instancesOf(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().toList();

/// [t]'s six numbers, for exact comparison.
List<double> partsOf(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// The raw world point the canvas reads for a pointer at world [p] (the
/// screen round trip, as the tool receives it).
Vector2 rawWorldAt(WidgetTester tester, PlanController c, Vector2 p) {
  final local =
      globalOf(tester, c, p) - tester.getTopLeft(find.byType(InteractionLayer));
  return c.camera.value.screenToWorld(Vector2(local.dx, local.dy));
}

/// The canvas's focus node: the primary focus, inside the interaction layer.
FocusNode canvasFocus(WidgetTester tester) {
  final node = FocusManager.instance.primaryFocus!;
  expect(
      find
          .descendant(
              of: find.byType(InteractionLayer),
              matching: find.byElementPredicate((e) => e == node.context),
              matchRoot: true)
          .evaluate(),
      isNotEmpty,
      reason: 'premise: the canvas has the focus');
  return node;
}

/// Every focus node whose widget sits under [of].
List<FocusNode> focusNodesUnder(WidgetTester tester, Finder of) => [
      for (final n in FocusManager.instance.rootScope.descendants)
        if (n.context != null &&
            find
                .descendant(
                    of: of,
                    matching: find.byElementPredicate((e) => e == n.context))
                .evaluate()
                .isNotEmpty)
          n,
    ];

/// Cmd+Shift+Z: the editor's redo binding.
Future<void> redoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// As [aimCamera], at [scale] px/mm.
Future<void> aimCameraAt(
    WidgetTester tester, PlanController c, Vector2 centre, double scale) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.3).multiply(Transform2.scale(scale, scale));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// The live line entities' slots, ascending.
List<int> lineSlotsOf(DraftDocument doc) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.kindAt(s) == EntityKind.line) s,
    ]..sort();

// ---------------------------------------------------------------------------
// Walls added through the document's commands, and the symbols placed
// against them (the old wall_attach_fixture.dart and wall_fixture.dart
// helpers, over the kit's `WallParams`; the integration package's
// attach_plans.dart has the same in its own tests).

/// The attachment fixtures' far point.
const double attachX = 1e5, attachY = -7e4;

/// The point `(x, y)` from the far point (1e5, -7e4).
Vector2 farAt(double x, double y) => Vector2(attachX + x, attachY + y);

/// [from] moved [len] along [deg] degrees anticlockwise from +x.
Vector2 polar(Vector2 from, double deg, double len) {
  final r = deg * math.pi / 180;
  return from + Vector2(math.cos(r), math.sin(r)) * len;
}

/// Wall [h]'s group: a translation near the far point times a rotation that
/// is never a multiple of 90 degrees.
Transform2 attachGroup(int h) => Transform2.translation(
        attachX - 950 + 311.5 * (h % 7), attachY + 420 - 173.25 * (h % 5))
    .multiply(Transform2.rotation(0.3 + 0.7 * (h % 9)));

/// One wall from world [s] to world [e], [t] thick, in its own turned group,
/// one command; returns its handle. The wall's stored ends are [s] and [e]
/// taken back through the group.
Handle addWallAt(
    PlanController c, Vector2 s, Vector2 e, double t, Justification j) {
  final doc = c.document;
  final h = doc.handleSeed.next();
  final g = attachGroup(h.value);
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<WallParams>(
        h, WallParams(ls.x, ls.y, le.x, le.y, t, j)),
  ], label: 'Add wall'));
  return h;
}

/// A wall's face as the kit frames it: `m` the unit normal out of the wall
/// into the room, `t = (-m.y, m.x)`, `a` the end with the smaller `.t`.
typedef FaceLine = ({Vector2 a, Vector2 t, Vector2 m, double length});

/// Wall [h]'s [left] face (or right), by hand from its stored parameters
/// for a wall nothing joins in an unmirrored group.
FaceLine faceLineOf(DraftDocument doc, Handle h, {required bool left}) {
  final w = doc.components.get<WallParams>(h)!;
  final (l, r) = switch (w.justification) {
    Justification.centre => (w.thickness / 2, -w.thickness / 2),
    Justification.left => (w.thickness, 0.0),
    Justification.right => (0.0, -w.thickness),
  };
  final g = doc.tree.accumulatedTransform(h);
  final s = g.transformPoint(w.start), e = g.transformPoint(w.end);
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final offset = left ? l : r;
  final nx = -dy / len * offset, ny = dx / len * offset;
  final p = Vector2(s.x + nx, s.y + ny), q = Vector2(e.x + nx, e.y + ny);
  final d = g.transformDirection((w.end - w.start).normalized()).normalized();
  final n = Vector2(-d.y, d.x);
  final m = left ? n : -n;
  final t = Vector2(-m.y, m.x);
  return (a: p.dot(t) <= q.dot(t) ? p : q, t: t, m: m, length: (q - p).length);
}

/// The point `a + t*u + m*s` of face [r].
Vector2 onRun(FaceLine r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

/// The drawn vertices of [instance]'s definition, in world: every line's
/// two ends and every polyline's points, through the instance's transform.
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
/// vertices all on the room side, the nearest exactly on the face line, those
/// on the face spanning [width] along it; local `+y` (towards the back) on
/// `-m` (into the wall) and local `+x` on `t` (mirrored: `-t`).
void expectFlush(
    DraftDocument doc, InstanceNode instance, FaceLine run, double width,
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

/// A mouse that hovers at world [hover], presses there, moves and releases
/// at world [release].
Future<void> hoverPressRelease(WidgetTester tester, PlanController c,
    Vector2 hover, Vector2 release) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(
      location: globalOf(tester, c, hover) + const Offset(9, 7));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, c, hover));
  await tester.pump();
  await mouse.down(globalOf(tester, c, hover));
  await tester.pump();
  await mouse.moveTo(globalOf(tester, c, release));
  await tester.pump();
  await mouse.up();
  await tester.pump();
  await mouse.removePointer();
  await tester.pump();
}

/// A canvas that only counts the calls made on it.
class _CountingCanvas implements Canvas {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return null;
  }
}

/// How many canvas calls [tool]'s overlays make under [c]'s camera, the
/// screen one and the world one: 0 when the tool shows nothing (a placement
/// ghost, its base-point cross and its snap marker are all overlay paints).
int overlayCalls(Tool tool, PlanController c, Size viewport) {
  final canvas = _CountingCanvas();
  final camera = c.camera.value;
  tool.paintWorldOverlay(
      canvas, Vector2.zero(), camera.scale, PaperPalette.light);
  tool.paintOverlay(canvas, camera, viewport, PaperPalette.light);
  return canvas.calls;
}
