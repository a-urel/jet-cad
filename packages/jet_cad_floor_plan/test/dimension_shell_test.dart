// Spec 11 D19, D18 and D11 through the shell, on the sample plan (D17; the
// plan's Ruling 11-1). The real select tool clicks, bands, drags and deletes
// the five dimensions; the real Line tool hovers at an extension line's end.
//
// - Decisions 24 and 25: an extension line is drawn but never takes a
//   click, a band's membership or a snap. A dimension is selected by its
//   line, slashes or text; a wall face under an extension line stays
//   clickable (`SL1`), and a hover at an extension line's end snaps to
//   nothing there (`TL9`, S-14).
// - D11 (R-19): a dimension is movable. Dragged alone its fixed end moves
//   and its attached end stays; dragged with its walls every value stays
//   (decision 12); alone it shows a rotation grip.
// - Decision 3: deleting a wall deletes its dimensions in the same step.
// - D13: the shell wires a dimension's grips; the Hall's offset grip
//   dragged through the select tool moves its line, not its group (`SL2`).
//
// Every clause is a fresh shell over a fresh sample plan, at the sample's
// own placement (off-origin, not symmetric). Clicks use the shell's startup
// camera, as the app opens (a 1440 x 900 window); the band and the hover
// pin a camera of their own, y up, its translation fractional, and state
// their pick radius or aperture. Hand values are worked beside each
// assertion.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left;

/// The sample plan as the app opens it. With [gridSnap] false the page's
/// grid snap is off, so a drag or a hover resolves to its raw point: a page
/// change that no dimension regenerates for (D3's page key is the unit and
/// the scale), made through a system of its own and cleared from the
/// history, as a fresh document has none.
DraftDocument samplePlan({bool gridSnap = true}) {
  final doc = startupPlan(FlutterTextMeasurer());
  if (!gridSnap) {
    final system = installParametric(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, pageOf(doc).copyWith(snapToGrid: false)));
    system.dispose();
    doc.commands.clearHistory();
  }
  expect(driftOf(doc), isEmpty);
  expect(doc.commands.undoDepth, 0);
  return doc;
}

/// The sample's ten walls, ascending: E1–E4, P1–P5, the column.
List<Handle> wallsOf(DraftDocument doc) =>
    doc.components.withComponent<WallParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

/// The sample's five dimensions, ascending (D17's build order): the width,
/// the depth, the Hall, the Kitchen, the Bath diagonal.
List<Handle> dimsOf(DraftDocument doc) =>
    doc.components.withComponent<DimensionParams>().toList()
      ..sort((a, b) => a.value.compareTo(b.value));

/// D17's values at 1:50 m, in the build order.
const List<String> sampleValues = ['14.00', '9.00', '4.69', '4.38', '3.58'];

/// [group]'s children, ascending.
List<Handle> childrenOf(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot)
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Pumps a fresh shell over [doc], keyed by [key] so each clause gets a
/// state of its own, at a 1440 x 900 window. The camera is the one the
/// shell fits at startup.
Future<PlannerView> pumpShell(
    WidgetTester tester, DraftDocument doc, String key) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: PlannerShell(key: ValueKey(key), document: doc)));
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

/// Pins [view]'s camera at [pxPerMm], y up, centred near world [at], its
/// translation fractional (10-28: a stroke centred on an integer device
/// coordinate is the rasteriser's special case, and so is a click there).
Future<void> pinCamera(
    WidgetTester tester, PlannerView view, Vector2 at, double pxPerMm) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2(
          pxPerMm,
          0,
          0,
          -pxPerMm,
          size.width / 2 - pxPerMm * at.x + 0.37,
          size.height / 2 + pxPerMm * at.y + 0.61));
  await tester.pump();
}

/// World [p] as a global position on [view]'s canvas.
Offset globalOf(WidgetTester tester, PlannerView view, Vector2 p) {
  final s = view.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// The world point the canvas reads at global [g] (the layer's inverse
/// camera).
Vector2 worldAt(WidgetTester tester, PlannerView view, Offset g) {
  final local = g - tester.getTopLeft(find.byType(InteractionLayer));
  return view.camera.value.screenToWorld(Vector2(local.dx, local.dy));
}

/// The select tool's pick radius on [view]'s camera, world mm.
double pickRadius(PlannerView view) =>
    kPickRadiusPixels / view.camera.value.scale;

/// A primary click at world [p].
Future<void> tapWorld(WidgetTester tester, PlannerView view, Vector2 p) async {
  await tester.tapAt(globalOf(tester, view, p));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A mouse drag from global [a] to global [b], past the slop at once.
Future<void> dragGlobal(WidgetTester tester, Offset a, Offset b) async {
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 7));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
}

Future<void> pressKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  // The DocChange is asynchronous (the plan's Ruling 11-8): pump twice.
  await tester.pump();
  await tester.pump();
}

/// F3 off, so a drag's base and target snap to nothing (the page's grid
/// snap is off in [samplePlan]'s drag documents).
Future<void> objectSnapOff(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.f3);
  await tester.pump();
  expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
      'osnap off');
}

/// Where the select tool's click lands: the root-level key `pickInto`
/// resolves at [p] within [radius] under [filter].
SelectionKey? pickAt(
    PlannerView view, Vector2 p, double radius, QueryFilter filter) {
  final hit = HitPath();
  if (!view.index.pickInto(p, radius, filter, hit)) return null;
  return resolveHit(hit, view.document);
}

/// [slot]'s bounds in world: its owner-space bounds under its owner's
/// accumulated transform.
Aabb2 worldBoundsOf(DraftDocument doc, int slot) {
  final e = doc.entities;
  final local = entityBounds(
    kind: e.kindAt(slot),
    payload: doc.geometry.read(e.geomIndexAt(slot)),
    measurer: doc.textMeasurer,
    textStyle: doc.textStyleOf(e.textStyleAt(slot)),
    textAttrs: e.textAttrsAt(slot),
    text: e.kindAt(slot) == EntityKind.text ? e.textAt(slot) : '',
  );
  return local.transformedBy(doc.tree.accumulatedTransform(e.ownerAt(slot)));
}

bool inside(Aabb2 inner, Aabb2 outer) =>
    inner.minX >= outer.minX &&
    inner.maxX <= outer.maxX &&
    inner.minY >= outer.minY &&
    inner.maxY <= outer.maxY;

void main() {
  testWidgets(
      'SL1 through the select tool on the sample plan: a click on a '
      'dimension line selects it; a click on E4\'s face under the Hall\'s '
      'extension line selects E4; a window band around the Hall\'s line, '
      'slashes and text selects it; dimensions move and turn by their fixed '
      'ends only; deleting E1 deletes three dimensions in one step',
      (tester) async {
    // ---- 1. The clicks, on the startup camera.
    {
      final doc = samplePlan();
      final [_, _, hall, _, _] = dimsOf(doc);
      final view = await pumpShell(tester, doc, 'click-line');
      // The camera the shell fits at 1440 x 900: the page, 297 mm x 50
      // wide, fitted into the drawing area; about 0.0573 px/mm, a pick
      // radius of 6 / 0.0573 = 104.7 mm.
      final radius = pickRadius(view);
      // ignore: avoid_print
      print('SL1 startup camera ${view.camera.value.scale} px/mm, pick '
          'radius $radius mm');
      expect(radius, inInclusiveRange(90, 120), reason: 'premise');
      // The Hall's line runs y = 8,250 + 900 = 9,150 from x 12,250 to
      // 16,940; (14,000, 9,150) is on it, 238 mm left of its text (x from
      // 14,595 − 357 = 14,238 in the test font).
      final (q0, q1) = dimLines(doc, hall)[0];
      expect([q0.x, q0.y, q1.x, q1.y], [12250, 9150, 16940, 9150],
          reason: 'premise: the Hall\'s line');
      await tapWorld(tester, view, Vector2(14000, 9150));
      expect(view.selection.keys, [SelectionKey.root(hall)],
          reason: 'a click on the Hall\'s line selects the Hall');
    }
    {
      final doc = samplePlan();
      final [_, _, _, e4, ..._] = wallsOf(doc);
      final [_, _, hall, _, _] = dimsOf(doc);
      final view = await pumpShell(tester, doc, 'click-e4');
      final radius = pickRadius(view);
      // The Hall's extension line at a runs up E4's inner face, x = 12,250,
      // from the corner (12,250, 8,250) + 75 (the gap, 1.5 paper mm at
      // 1:50) to the line + 100 (the overshoot): y 8,325 to 9,250. The
      // click at (12,250, 8,800) lies on both.
      final (e0, e1) = dimLines(doc, hall)[1];
      expect([e0.x, e0.y, e1.x, e1.y], [12250, 8325, 12250, 9250],
          reason: 'premise: the Hall\'s extension line on E4\'s face');
      final click = Vector2(12250, 8800);
      // Premise: were the extension line pickable -- the picking filter
      // without the not-pickable test -- that click would select the Hall,
      // drawn above E4 (D18's R-35, superseded).
      expect(
          pickAt(view, click, radius,
              const QueryFilter(visibleOnly: true, excludeLocked: true)),
          SelectionKey.root(hall),
          reason: 'premise: the extension line would win the click');
      await tapWorld(tester, view, click);
      expect(view.selection.keys, [SelectionKey.root(e4)],
          reason: 'decisions 24, 25: the click selects E4, not the Hall');
    }

    // ---- 2. A window band around the Hall's line, slashes and text.
    {
      final doc = samplePlan();
      final [_, _, hall, _, _] = dimsOf(doc);
      final view = await pumpShell(tester, doc, 'band');
      // 0.15 px/mm: a pick radius of 6 / 0.15 = 40 mm. The band's press
      // is its left corner (a window is dragged left to right on this y-up
      // camera). The plan's (12,050, 9,000) lies inside E4's band (x
      // 12,000–12,250), and a wall is picked anywhere inside its outline, so
      // that press would drag E4 (the plan corrected, with its arithmetic):
      // the press is at (11,950, 9,000), 50 mm west of E4's outer face, past
      // the 40 mm radius, and lands on no object, so the drag is a band. It
      // still takes the Hall's left slash, which reaches x 12,197.
      await pinCamera(tester, view, Vector2(14550, 9250), 0.15);
      final radius = pickRadius(view);
      expect(radius, closeTo(40, 1e-9));
      final a = Vector2(11950, 9000), b = Vector2(17100, 9500);
      expect(
          pickAt(
              view, Vector2(12050, 9000), radius, const QueryFilter.picking()),
          SelectionKey.root(wallsOf(doc)[3]),
          reason: 'premise: the plan\'s corner picks E4');
      expect(pickAt(view, a, radius, const QueryFilter.picking()), isNull,
          reason: 'premise: no object in the pick radius at the press');
      // Premise, by coordinates: the band x 11,950–17,100, y 9,000–9,500
      // takes the line (y 9,150, x 12,250–16,940), the slashes (75 mm
      // either side of each end at 45°: x 12,197–12,303 and 16,887–16,993,
      // y 9,097–9,203) and the text (from 50 mm above the line) wholly, and
      // cuts both extension lines, y 8,325–9,250.
      final band = Aabb2.raw(a.x, a.y, b.x, b.y);
      final kids = childrenOf(doc, hall);
      expect(kids, hasLength(6));
      final boxes = [
        for (final k in kids) worldBoundsOf(doc, doc.entities.slotOf(k)!)
      ];
      for (final i in [0, 3, 4, 5]) {
        expect(inside(boxes[i], band), isTrue,
            reason: 'premise: child $i ${boxes[i]} inside the band');
      }
      for (final i in [1, 2]) {
        expect(boxes[i].minY, 8325, reason: 'premise: extension line $i');
        expect(boxes[i].minY < band.minY && boxes[i].maxY > band.minY, isTrue,
            reason: 'premise: the band cuts extension line $i');
      }
      final ga = globalOf(tester, view, a), gb = globalOf(tester, view, b);
      expect(gb.dx > ga.dx, isTrue, reason: 'left to right: a window');
      await dragGlobal(tester, ga, gb);
      expect(view.selection.keys, [SelectionKey.root(hall)],
          reason: 'the band selects the Hall and nothing else');
    }

    // ---- 3. A body drag of the diagonal: its fixed end moves, its attached
    // end stays.
    {
      final doc = samplePlan(gridSnap: false);
      final [e1, ..._] = wallsOf(doc);
      final [_, _, _, _, diag] = dimsOf(doc);
      final params = doc.components.get<DimensionParams>(diag)!;
      expect(params.a, AttachedEnd(e1, 1, l), reason: 'premise: E1/1/left');
      final fixed = params.b as FixedEnd;
      expect([fixed.x, fixed.y], [22300, 9200], reason: 'premise: the basin');
      final view = await pumpShell(tester, doc, 'drag-diagonal');
      await objectSnapOff(tester);
      // A quarter of the way along the diagonal from (25,750, 8,250) to
      // (22,300, 9,200): (24,887.5, 8,487.5).
      final (d0, d1) = dimLines(doc, diag)[0];
      final grab = d0 + (d1 - d0) * 0.25;
      await tapWorld(tester, view, grab);
      expect(view.selection.keys, [SelectionKey.root(diag)]);
      final mv = Vector2(-612.5, 437.5);
      final ga = globalOf(tester, view, grab);
      final gb = globalOf(tester, view, grab + mv);
      final moved = worldAt(tester, view, gb) - worldAt(tester, view, ga);
      expect((moved - mv).length, lessThan(1e-6), reason: 'premise');
      await dragGlobal(tester, ga, gb);
      expect(doc.commands.undoDepth, 1, reason: 'one undo step');
      // The fixed end moved with the group: (22,300 − 612.5, 9,200 +
      // 437.5) = (21,687.5, 9,637.5).
      final f1 = oracleEnd(doc, diag, fixed)!;
      expect((f1 - (Vector2(22300, 9200) + moved)).length, lessThan(1e-6),
          reason: 'the fixed end moves by the drag');
      expect((f1 - Vector2(21687.5, 9637.5)).length, lessThan(1e-6));
      // The attached end stayed at E1/1/left, (25,750, 8,250).
      expect(
          (oracleEnd(doc, diag, AttachedEnd(e1, 1, l))! - Vector2(25750, 8250))
              .length,
          lessThan(1e-9),
          reason: 'the attached end stays');
      final (n0, n1) = dimLines(doc, diag)[0];
      expect((n0 - Vector2(25750, 8250)).length, lessThan(1e-6));
      expect((n1 - f1).length, lessThan(1e-6));
      // By hand: (25,750 − 21,687.5, 9,637.5 − 8,250) = (4,062.5, 1,387.5);
      // √(16,503,906.25 + 1,925,156.25) = √18,429,062.5 = 4,292.9 → 4.29.
      expect(4062.5 * 4062.5 + 1387.5 * 1387.5, 18429062.5);
      expect(math.sqrt(18429062.5), closeTo(4292.90, 0.01));
      expect(dimText(doc, diag), '4.29');
      expect(driftOf(doc), isEmpty);
      expect(oracleFailures(doc), isEmpty);
    }

    // ---- 4. The Hall selected alone shows a rotation grip.
    {
      final doc = samplePlan();
      final [_, _, hall, _, _] = dimsOf(doc);
      final view = await pumpShell(tester, doc, 'rotation-grip');
      await tapWorld(tester, view, Vector2(14000, 9150));
      expect(view.selection.keys, [SelectionKey.root(hall)]);
      expect(view.grips.rotatable, isTrue,
          reason: 'D11: a dimension alone rotates like a box');
      expect(view.grips.pivot, isNotNull);
    }

    // ---- 5. The walls and their dimensions dragged together: every value
    // stays (decision 12's together-move; Task 13's carried clause).
    {
      final doc = samplePlan(gridSnap: false);
      final [e1, e2, e3, e4, p1, _, _, _, p5, _] = wallsOf(doc);
      final dims = dimsOf(doc);
      final [_, _, hall, _, diag] = dims;
      expect([for (final d in dims) dimText(doc, d)], sampleValues);
      final linesBefore = [for (final d in dims) dimLines(doc, d)];
      final fixedBefore =
          oracleEnd(doc, diag, doc.components.get<DimensionParams>(diag)!.b)!;
      final view = await pumpShell(tester, doc, 'together');
      await objectSnapOff(tester);
      view.selection.replace([
        for (final w in [e1, e2, e3, e4, p1, p5]) SelectionKey.root(w),
        for (final d in dims) SelectionKey.root(d),
      ]);
      await tester.pump();
      await tester.pump();
      // Pressed on the Hall's line, a selected body, 595 mm from its offset
      // grip at the line's middle (34 px on this camera).
      final grab = Vector2(14000, 9150);
      expect(pickAt(view, grab, pickRadius(view), const QueryFilter.picking()),
          SelectionKey.root(hall),
          reason: 'premise: the press lands on the Hall');
      final mv = Vector2(1234.5, -500.25);
      final ga = globalOf(tester, view, grab);
      final gb = globalOf(tester, view, grab + mv);
      final moved = worldAt(tester, view, gb) - worldAt(tester, view, ga);
      expect((moved - mv).length, lessThan(1e-6), reason: 'premise');
      await dragGlobal(tester, ga, gb);
      expect(doc.commands.undoDepth, 1, reason: 'one undo step');
      expect([for (final d in dims) dimText(doc, d)], sampleValues,
          reason: 'every value unchanged');
      // Every line moved by the drag: the attached ends with their walls,
      // the diagonal's fixed end with its group.
      for (final (i, d) in dims.indexed) {
        final after = dimLines(doc, d);
        for (var j = 0; j < 5; j++) {
          expect((after[j].$1 - (linesBefore[i][j].$1 + moved)).length,
              lessThan(1e-6),
              reason: 'dimension $i line $j start');
          expect((after[j].$2 - (linesBefore[i][j].$2 + moved)).length,
              lessThan(1e-6),
              reason: 'dimension $i line $j end');
        }
      }
      expect(
          (oracleEnd(doc, diag, doc.components.get<DimensionParams>(diag)!.b)! -
                  (fixedBefore + moved))
              .length,
          lessThan(1e-6));
      expect(driftOf(doc), isEmpty);
      expect(oracleFailures(doc), isEmpty);
    }

    // ---- 6. Deletion: one dimension, then E1 with its three.
    {
      final doc = samplePlan();
      final [e1, _, _, _, p1, ..._] = wallsOf(doc);
      final dims = dimsOf(doc);
      final [_, _, hall, _, _] = dims;
      final view = await pumpShell(tester, doc, 'delete-one');
      await tapWorld(tester, view, Vector2(14000, 9150));
      expect(view.selection.keys, [SelectionKey.root(hall)]);
      final live = doc.entities.liveCount;
      await pressKey(tester, LogicalKeyboardKey.delete);
      expect(doc.tree[hall], isNull, reason: 'the Hall is deleted');
      expect(doc.commands.undoDepth, 1, reason: 'one step');
      expect(doc.entities.liveCount, live - 6, reason: 'its six children');
      for (final d in dims.where((d) => d != hall)) {
        expect(doc.tree[d], isA<GroupNode>(), reason: 'dimension $d stays');
      }
      expect(doc.tree[e1], isA<GroupNode>(), reason: 'its walls stay');
      expect(doc.tree[p1], isA<GroupNode>());
    }
    {
      final doc = samplePlan();
      final [e1, ..._] = wallsOf(doc);
      final dims = dimsOf(doc);
      final [width, depth, hall, kitchen, diag] = dims;
      final view = await pumpShell(tester, doc, 'delete-e1');
      // E1's outer face 3,000 mm along, (15,000, 8,000): 500 mm above the
      // width's line (y 7,500) and far from every corner and opening.
      await tapWorld(tester, view, Vector2(15000, 8000));
      expect(view.selection.keys, [SelectionKey.root(e1)]);
      final kids = {for (final d in dims) d: childrenOf(doc, d)};
      final live = doc.entities.liveCount;
      await pressKey(tester, LogicalKeyboardKey.delete);
      expect(doc.commands.undoDepth, 1, reason: 'one step');
      expect(doc.tree[e1], isNull);
      for (final d in [width, hall, diag]) {
        expect(doc.tree[d], isNull, reason: 'dimension $d goes with E1');
        for (final k in kids[d]!) {
          expect(doc.entities.slotOf(k), isNull, reason: 'child $k');
        }
      }
      for (final d in [depth, kitchen]) {
        expect(doc.tree[d], isA<GroupNode>(), reason: 'dimension $d stays');
      }
      expect(doc.entities.liveCount, lessThan(live - 3 * 6));
      await undoKey(tester);
      expect(doc.commands.undoDepth, 0);
      expect(doc.entities.liveCount, live);
      for (final d in dims) {
        expect(doc.tree[d], isA<GroupNode>(), reason: 'dimension $d');
        expect(childrenOf(doc, d), kids[d], reason: 'its handles, $d');
      }
      expect([for (final d in dims) dimText(doc, d)], sampleValues,
          reason: 'its strings');
      expect(driftOf(doc), isEmpty);
    }
  });

  testWidgets(
      'SL2 (rvF-mainNoIndex) through the select tool, the Hall\'s offset '
      'grip dragged 250 mm up moves its line, not its group, in one undo '
      'step: the shell hands its index to ObjectGrips (D13)', (tester) async {
    final doc = samplePlan(gridSnap: false);
    final [_, _, hall, _, _] = dimsOf(doc);
    final before = doc.components.get<DimensionParams>(hall)!;
    expect(before.offset, 900, reason: 'premise: the Hall\'s offset');
    expect(before.kind, DimKind.horizontal, reason: 'premise');
    final m0 = doc.tree.accumulatedTransform(hall);
    final view = await pumpShell(tester, doc, 'offset-grip');
    await objectSnapOff(tester);
    // 0.15 px/mm, centred on the grip. The Hall's line runs y = 8,250 +
    // 900 = 9,150 from x 12,250 to 16,940; its offset grip sits at the
    // line's midpoint, x (12,250 + 16,940) / 2 = 14,595.
    await pinCamera(tester, view, Vector2(14595, 9150), 0.15);
    final (q0, q1) = dimLines(doc, hall)[0];
    expect([q0.x, q0.y, q1.x, q1.y], [12250, 9150, 16940, 9150],
        reason: 'premise: the Hall\'s line');
    await tapWorld(tester, view, Vector2(14000, 9150));
    expect(view.selection.keys, [SelectionKey.root(hall)]);
    final grip = Vector2(14595, 9150);
    final ga = globalOf(tester, view, grip);
    final gb = globalOf(tester, view, grip + Vector2(0, 250));
    final moved = worldAt(tester, view, gb) - worldAt(tester, view, ga);
    expect((moved - Vector2(0, 250)).length, lessThan(1e-6), reason: 'premise');
    await dragGlobal(tester, ga, gb);
    // The drop at y 9,400 stores 9,400 − 8,250 = 1,150, the kind and ends
    // kept; without the shell's index the press drags the whole group and
    // the offset stays 900.
    final after = doc.components.get<DimensionParams>(hall)!;
    expect(after.offset, closeTo(900 + moved.y, 1e-6),
        reason: 'the offset moves by the drag');
    expect(after.offset, closeTo(1150, 1e-6));
    expect([after.a, after.b, after.kind], [before.a, before.b, before.kind],
        reason: 'the ends and the kind are kept');
    final m1 = doc.tree.accumulatedTransform(hall);
    expect([
      m1.a,
      m1.b,
      m1.c,
      m1.d,
      m1.e,
      m1.f
    ], [
      m0.a,
      m0.b,
      m0.c,
      m0.d,
      m0.e,
      m0.f
    ], reason: 'the group does not move');
    final (n0, n1) = dimLines(doc, hall)[0];
    expect((n0 - Vector2(12250, 9400)).length, lessThan(1e-6));
    expect((n1 - Vector2(16940, 9400)).length, lessThan(1e-6));
    expect(dimText(doc, hall), '4.69', reason: 'its value is kept');
    expect(doc.commands.undoDepth, 1, reason: 'one undo step');
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(doc.commands.undoDepth, 0);
    expect(doc.components.get<DimensionParams>(hall), before,
        reason: 'the undo restores 900');
  });

  testWidgets(
      'TL9 at 0.3 px/mm with the grid snap off, a hover 5 mm off the Hall\'s '
      'extension line\'s far end gets no object snap and resolves to the raw '
      'point', (tester) async {
    final doc = samplePlan(gridSnap: false);
    final [_, _, hall, _, _] = dimsOf(doc);
    expect(pageOf(doc).snapToGrid, isFalse, reason: 'premise: no grid snap');
    final view = await pumpShell(tester, doc, 'tl9');
    await pressKey(tester, LogicalKeyboardKey.keyL);
    final tool = view.tools.active;
    expect(tool, isA<LineTool>(), reason: 'the Line tool, a PlacementTool');
    tool as PlacementTool;
    final raw = Vector2(12253, 9254);
    await pinCamera(tester, view, raw, 0.3);
    // A 10 px aperture at 0.3 px/mm: 10 / 0.3 = 33.3 mm.
    final aperture = kSnapAperturePixels / view.camera.value.scale;
    expect(aperture, closeTo(33.33, 0.01));
    // The Hall's extension line at a ends at the line (9,150) + the
    // overshoot (100): (12,250, 9,250), √(3² + 4²) = 5 mm from the hover.
    final far = Vector2(12250, 9250);
    expect(dimLines(doc, hall)[1].$2, far, reason: 'premise: the far end');
    expect((raw - far).length, 5);
    // Premise (S-14): were snapping to ignore the flag -- `rendering()` --
    // the hover would snap onto that end.
    final scratch = SnapResult();
    view.index.snapInto(raw, aperture, kDragSnapMask, scratch,
        filter: const QueryFilter.rendering());
    expect(scratch.found, isTrue, reason: 'premise: rendering() snaps');
    expect([scratch.point.x, scratch.point.y], [far.x, far.y],
        reason: 'premise: onto the extension line\'s end');
    // The hover, through the shell's pointer.
    final g = globalOf(tester, view, raw);
    expect((worldAt(tester, view, g) - raw).length, lessThan(1e-6));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: g + const Offset(40, 30));
    await gesture.moveTo(g);
    await tester.pump();
    expect(tool.hoverVisible, isTrue, reason: 'premise: the hover arrived');
    expect(tool.hoverKind, isNull, reason: 'no object snap');
    expect((tool.hoverPoint - worldAt(tester, view, g)).length, lessThan(1e-9),
        reason: 'the raw point');
    expect((tool.hoverPoint - far).length, closeTo(5, 1e-6),
        reason: 'not the extension line\'s end');
    await gesture.removePointer();
  });
}
