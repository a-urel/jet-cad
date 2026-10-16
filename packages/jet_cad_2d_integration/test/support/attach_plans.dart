// Today's wall-attachment scenes (jet_cad_floor_plan/test/support/
// wall_attach_fixture.dart, plan P-2) as plan files for the integration
// tests (3a Task 28), and the oracle of ruling IA-R1: the kit's own
// wall-face provider asked through the contract, as plan.symbol and
// plan.select ask it.
import 'dart:io';

import 'package:flutter/material.dart' show Key, TextInputAction;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart'; // kSnapAperturePixels is the engine's (drag_snap.dart:14)
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart'
    show PlanController, PlanSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'canvas_rig.dart' show press;
import 'plans.dart';

/// The attach capture in pixels (plan.symbol's `kAttachPixels`,
/// jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart, not exported).
const double kAttachPixels = 16;

/// The kit's furniture library, read from its committed asset.
final SymbolLibrary furniture = SymbolLibrary.decode(
    File('../jet_cad_2d_kit_architecture/assets/library/furniture.jetlib')
        .readAsBytesSync());

/// The library's entry of today's [key] (`bath.toilet`), under the kit.
SymbolEntry furnitureEntry(String key) =>
    furniture.entries.singleWhere((e) => e.symbol.key == 'architecture.$key');

/// [c]'s loaded symbol of today's [key].
PlanSymbol armable(PlanController c, String key) =>
    c.symbols.singleWhere((s) => s.component.key == 'architecture.$key');

/// The kit's wall-face provider over [doc] at [scale] px/mm (IA-R1).
AttachmentProvider wallFaces(DraftDocument doc, double scale) {
  final services =
      FakePlanServices(document: doc, catalog: kitCatalog(), scale: scale);
  addTearDown(services.dispose);
  return architectureKit.attachments.single(services);
}

/// The provider's answer for [entry] at the raw [pointer], its free
/// placement [current], at [scale] (the query AT-8 pins).
Attachment? attachOf(DraftDocument doc, SymbolEntry entry, Vector2 pointer,
    Transform2 current, double scale,
    {bool mirrored = false, bool mayRotate = true, Attachment? keep}) {
  final box = boxOfEntry(entry)!;
  return wallFaces(doc, scale).attach(AttachmentQuery(
      footprint: footprintOf(box),
      current: current,
      pointer: pointer,
      capture: kAttachPixels / scale,
      edgeCapture: kSnapAperturePixels / scale,
      mirrored: mirrored,
      mayRotate: mayRotate,
      keep: keep));
}

/// The distance from [p] to the face line of wall [h] on its [left] side
/// (or right), from its stored parameters (IA-R1's face test).
double faceDistance(DraftDocument doc, Handle h, Vector2 p,
    {required bool left}) {
  final w = doc.components.get<WallParams>(h)!;
  final (l, r) = facesOf(w);
  final ends = worldEndsOf(doc, h);
  final (a, b) = faceOf(ends.s, ends.e, left ? l : r);
  final d = b - a;
  return ((p - a).x * d.y - (p - a).y * d.x).abs() / d.length;
}

/// A wall's face as today's `FaceRun` frames it (spec 09c D3: `m` the unit
/// normal out of the wall into the room, `t = (−m.y, m.x)`, `a` the end
/// with the smaller `(·)·t`, the length), by hand from wall [h]'s stored
/// parameters for a wall nothing joins, in an unmirrored group: its
/// [left] face (or right). The direction is the stored one taken to world
/// and normalised, as the kit's drawn faces take it (`wall_attach.dart`'s
/// `_drawnFaces`), so `t` and `m` are bit for bit the kit's.
typedef FaceLine = ({Vector2 a, Vector2 t, Vector2 m, double length});

/// [FaceLine] of wall [h] on its [left] side (or right).
FaceLine faceLineOf(DraftDocument doc, Handle h, {required bool left}) {
  final w = doc.components.get<WallParams>(h)!;
  final (l, r) = facesOf(w);
  final ends = worldEndsOf(doc, h);
  final (p, q) = faceOf(ends.s, ends.e, left ? l : r);
  final d = doc.tree
      .accumulatedTransform(h)
      .transformDirection((w.end - w.start).normalized())
      .normalized();
  final n = Vector2(-d.y, d.x);
  final m = left ? n : -n;
  final t = Vector2(-m.y, m.x);
  return (a: p.dot(t) <= q.dot(t) ? p : q, t: t, m: m, length: (q - p).length);
}

/// The point `a + t·u + m·s` of face [r] (today's `onRun`, over a [FaceLine]).
Vector2 onRun(FaceLine r, double u, double s) =>
    Vector2(r.a.x + r.t.x * u + r.m.x * s, r.a.y + r.t.y * u + r.m.y * s);

// Copied from jet_cad_floor_plan/test/support/wall_attach_fixture.dart:
// 16-44, unchanged.

/// The attachment fixtures' far point (P-2).
const double attachX = 1e5, attachY = -7e4;

/// The point `(x, y)` from the far point (1e5, −7e4).
Vector2 farAt(double x, double y) => Vector2(attachX + x, attachY + y);

/// P-2's two wall angles, in degrees anticlockwise from world +x.
const List<double> attachAngles = [30, -112.5];

/// Wall [h]'s group in an attachment scene: a translation near the far
/// point times a rotation that is never a multiple of 90° ([rotation]
/// radians when given, else one picked by [h]), times a mirror
/// (`scale(1, −1)`) when [mirrored], times a uniform [scale].
Transform2 attachGroup(int h,
        {bool mirrored = false, double scale = 1, double? rotation}) =>
    Transform2.translation(
            attachX - 950 + 311.5 * (h % 7), attachY + 420 - 173.25 * (h % 5))
        .multiply(Transform2.rotation(rotation ?? 0.3 + 0.7 * (h % 9)))
        .multiply(Transform2.scale(scale, mirrored ? -scale : scale));

/// One wall of a scene: world start and end, thickness, justification.
typedef SceneWall = (Vector2 s, Vector2 e, double t, Justification j);

/// Today's `attachScene` (wall_attach_fixture.dart:46-63) as a plan file:
/// [walls] each one command in its own [attachGroup], handles ascending.
({String json, List<Handle> walls}) attachPlan(List<SceneWall> walls,
    {bool mirrored = false,
    double scale = 1,
    List<double?> rotations = const [],
    void Function(DraftDocument d)? extra}) {
  late List<Handle> hs;
  final json = planWith((doc) {
    hs = [for (final _ in walls) doc.handleSeed.next()];
    for (final (i, (s, e, t, j)) in walls.indexed) {
      doc.commands.execute(addWall(doc, hs[i], s, e, t, j,
          at: attachGroup(hs[i].value,
              mirrored: mirrored,
              scale: scale,
              rotation: i < rotations.length ? rotations[i] : null)));
    }
    extra?.call(doc);
  });
  return (json: json, walls: hs);
}

/// Today's `freeWallScene` (:65-71): 3600 long, 150 thick, from
/// `farAt(1234.5, 678.25)` along [deg].
({String json, List<Handle> walls}) freeWallPlan(double deg, Justification j,
    {bool mirrored = false,
    double scale = 1,
    void Function(DraftDocument d)? extra}) {
  final s = farAt(1234.5, 678.25);
  return attachPlan([(s, polar(s, deg, 3600), 150, j)],
      mirrored: mirrored, scale: scale, extra: extra);
}

// The apps' symbol tests' editor steps (apps/floor_planner/test/symbols/
// wall_attach_end_to_end_test.dart, symbol_shell_test.dart; 3a Task 28)
// over the plan's editor.

/// Today's `aimCamera` (apps/floor_planner/test/support/document_rig.dart:
/// 84-94) on [c]'s camera: [centre] in the middle of the canvas, turned
/// 0.3 rad, 0.1 px/mm, not reflected.
Future<void> aimCamera(
    WidgetTester tester, PlanController c, Vector2 centre) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.3).multiply(Transform2.scale(0.1, 0.1));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// Today's `armBySymbolsTab` over the plan's gallery: the Symbols tab
/// opened, the gallery filtered to [symbol]'s name (it builds its cells
/// lazily), the focus handed back (the search action) and its cell
/// tapped; [c] then arms it in plan.symbol.
Future<void> armBySymbolsTab(
    WidgetTester tester, PlanController c, PlanSymbol symbol) async {
  await tester.tap(find.byKey(const Key('tab-symbols')));
  await tester.pump();
  await tester.enterText(
      find.byKey(const Key('symbol-search')), symbol.component.name);
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

/// Cmd+Shift+Z: the plan's redo chord (room_plans.dart's `undoKey`'s
/// partner).
Future<void> redoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}
