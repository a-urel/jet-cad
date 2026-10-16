// Slice 4 Task 4 review's killers (R-1 to R-4): the symbol tool's stored
// turn and mirror bounded by the capabilities, a runtime rulers change with
// a tool active, the reviewer's probes RV4 to RV9, the Symbols tab, the
// grips' snapping, the empty toolbar, a host's own tools set and a filter
// offering nothing. Through `FloorPlanView` on the editor fixture under
// `editorCamera()`, with `editor_tools_test.dart`'s host and helpers.
//
// Ported to jet_cad_2d_integration (3a Task 28, D-05; ruling IA-R5) from
// jet_cad_floor_plan/test/host/editor_tools_review_test.dart: the
// north-wall case (:199-231), O13a (:413-446) and O13b (:448-475), over
// Task 26's editor fixture (`mountEditor`: the sample flat with 2b's
// units, `PlanEditor`, `editorCamera()`); assertions unchanged. The
// capabilities are the controller's permissions (`h.caps.value = X` →
// `c.permissions = X` and a pump); `Caps.snapping` is `PlanEditor`'s
// `snapping` (2a: snapping is the editor's option); `view.selection` is
// `c.activeSelection`, `view.grips!` the canvas's grip cache
// (`gripsOf`, IT-R12); `bath.toilet` is `architecture.bath.toilet` (C7
// class 1). The helpers `place`, `hover` and `drag` are the source's
// (:35-76), over the fixture's `screenOf`; `activeTool` is the rig's.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/canvas_rig.dart'
    show byKey, gripsOf, mouseClick, pressKey, symbolsReady;
import '../support/editor_fixture.dart' hide drag;
import '../support/plans.dart' show pageOf;

double det(Transform2 m) => m.a * m.d - m.b * m.c;

/// The instances of the design, by handle (today's `t.instancesOf`).
Set<Handle> instancesOf(DraftDocument d) =>
    {for (final n in d.tree.nodes.whereType<InstanceNode>()) n.handle};

/// Clicks world [w] and answers the one instance it placed.
Future<InstanceNode> place(
    WidgetTester tester, PlanController c, Vector2 w) async {
  final before = instancesOf(c.document);
  await mouseClick(tester, screenOf(tester, c, w));
  final added = instancesOf(c.document).difference(before);
  expect(added, hasLength(1), reason: 'one placement at $w');
  return c.document.tree[added.single]! as InstanceNode;
}

/// A mouse resting at world [w] (a hover, no press).
Future<TestGesture> hover(
    WidgetTester tester, PlanController c, Vector2 w) async {
  final at = screenOf(tester, c, w);
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  return g;
}

/// A mouse drag from world [from] to world [to], through a move off it.
Future<void> drag(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to) async {
  final g = await tester.startGesture(screenOf(tester, c, from),
      kind: ui.PointerDeviceKind.mouse);
  await tester.pump();
  await g.moveTo(screenOf(tester, c, to) + const Offset(0, 0.5));
  await tester.pump();
  await g.moveTo(screenOf(tester, c, to));
  await tester.pump();
  await g.up();
  await tester.pump();
}

/// The page's grid snap off, outside the history: a drop is the raw point.
void gridSnapOff(DraftDocument d) {
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, pageOf(d).copyWith(snapToGrid: false)));
  d.commands.clearHistory();
}

/// The root group carrying a component [T] that [test] accepts.
Handle groupWith<T extends Component>(DraftDocument d, bool Function(T) test) =>
    d.tree.nodes.whereType<GroupNode>().singleWhere((n) {
      final p = d.components.get<T>(n.handle);
      return p != null && test(p);
    }).handle;

/// Today's `t.openSymbols`: the Symbols tab, the libraries loaded.
Future<void> openSymbols(WidgetTester tester, PlanController c) async {
  await tester.tap(byKey('tab-symbols'));
  await tester.pump();
  expect(await symbolsReady(tester, c), isTrue,
      reason: 'premise: the libraries loaded');
  await tester.pump();
}

/// Today's `t.arm(tester, key)`: the gallery's cell of today's [key]
/// under the kit (`symbol-cell-architecture.<key>@1`) tapped.
Future<void> arm(WidgetTester tester, String key) async {
  final cell = byKey('symbol-cell-architecture.$key@1');
  expect(cell, findsOneWidget, reason: key);
  await tester.tap(cell);
  await tester.pump();
}

void main() {
  testWidgets(
      'a symbol against the north wall: M under full, then mirror false: '
      'it attaches as an unmirrored one does; full: mirrored', (tester) async {
    final c = await mountEditor(tester);
    final d = c.document;
    await openSymbols(tester, c);
    await tester.enterText(byKey('symbol-search'), 'toilet');
    await tester.pump();
    await arm(tester, 'bath.toilet');
    // 20 mm below the north wall's inner face (16,750), clear of 1 and 2.
    final at = Vector2(24200, 16730);
    final control = await place(tester, c, at);
    final want = control.transform;
    // Attached: its base point is not the click's, as a free one's is.
    expect(Vector2(want.e, want.f).distanceTo(at), greaterThan(1),
        reason: 'premise: the control attaches');
    d.commands.undo();
    await tester.pump();
    await pressKey(tester, LogicalKeyboardKey.keyM);
    c.permissions = PlanPermissions.full.copyWith(mirror: false);
    await tester.pump();
    final kept = await place(tester, c, at);
    expect(kept.transform.toJson(), want.toJson());
    d.commands.undo();
    await tester.pump();
    c.permissions = PlanPermissions.full;
    await tester.pump();
    final mirrored = await place(tester, c, at);
    expect(det(mirrored.transform), lessThan(0));
    expect(det(want), greaterThan(0));
  });

  testWidgets(
      'O13a snapping false: a dimension\'s end grip dropped exactly on a '
      'wall\'s end corner stays a fixed end; under full it attaches',
      (tester) async {
    for (final snapping in [false, true]) {
      final c = await mountEditor(tester, snapping: snapping);
      final d = c.document;
      gridSnapOff(d);
      // The overall depth, beyond the east wall: its north end at the
      // flat's outer corner (26,000, 17,000).
      final dim = groupWith<DimensionParams>(
          d, (p) => p.offset == -300 && p.a is AttachedEnd);
      c.activeSelection.replace([SelectionKey.root(dim)]);
      await tester.pump();
      expect(
          gripsOf(tester)
              .grips
              .any((r) => r.grip.x == 26000 && r.grip.y == 17000),
          isTrue,
          reason: 'premise: the end grip');
      await drag(tester, c, Vector2(26000, 17000), editorColumnCorner);
      final end = d.components.get<DimensionParams>(dim)!.b;
      if (snapping) {
        expect(end, isA<AttachedEnd>());
      } else {
        expect(end, isA<FixedEnd>());
        final p = (end as FixedEnd).point;
        expect(p.distanceTo(editorColumnCorner), lessThan(1e-6));
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
      'O13b snapping false: the east window\'s slide grip dropped 15 mm '
      'short of its stretch\'s end stores the projection; under full it '
      'snaps to the end', (tester) async {
    for (final snapping in [false, true]) {
      final c = await mountEditor(tester, snapping: snapping);
      final d = c.document;
      gridSnapOff(d);
      // The east wall runs north from y 8,125; its window, 1,800 wide,
      // centred 6,075 along it. Its north stretch ends at the inner
      // face's corner (y 16,750): a centre of at most 7,725.
      final win = groupWith<OpeningParams>(
          d, (p) => p.position == 6075 && p.width == 1800);
      c.activeSelection.replace([SelectionKey.root(win)]);
      await tester.pump();
      final grip = gripsOf(tester).grips.single.grip;
      expect((grip.x, grip.y), (25875.0, 14200.0), reason: 'premise');
      // The centre 7,710: its north jamb 15 mm short of the end, inside
      // the 27 mm aperture (10 px at 0.37 px/mm).
      await drag(tester, c, Vector2(grip.x, grip.y), Vector2(25878, 15835));
      final stored = d.components.get<OpeningParams>(win)!.position;
      expect(stored, closeTo(snapping ? 7725 : 15835 - 8125, 1e-6));
      await tester.pumpWidget(const SizedBox());
    }
  });
}
