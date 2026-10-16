// Ported from jet_cad_floor_plan/test/wall_grips_test.dart (3a Task 12):
// EG1-EG6, and EG7, EG8 (3a Task 17, R-P8: their door and separator), over
// a PlanController of the architecture kit in PlanEditor, assertions
// unchanged; the provider-direct tails of EG1, EG3, EG4, EG6 and EG8 use
// the kit's WallGrips and run in the kit as EG1-k, EG3-k, EG4-k, EG6-k and
// EG8-k (R-P1, R12-3); the shown grips are the controller's grip cache
// (R-P9). EG9, EG10 (3a Task 21, R-P8): the panel, the Position field and
// the corner drag here; their adapters, band cache, attach, room inputs and
// grips run in the kit as EG9-k, EG10-k.
// WG-refuse-short is new (Review Focus 3's kit half, R-P15).
import 'package:flutter/foundation.dart' show Key;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';
import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

/// A 1:20 page near the far origin with grid snap on at [gridStep], and
/// the walls [build] adds, as a plan with no undo history
/// (wall_grips_test.dart:36-56's `gripDoc`).
String gripPlan(void Function(DraftDocument doc) build) =>
    wallPlanJson(wallPage(), build);

/// The shown grips of wall [h], as (index, x, y): the controller's grip
/// cache (wall_grips_test.dart:127-131's `gripsOf(view, h)`).
List<(int, double, double)> gripsOf(PlanController c, Handle h) => [
      // ignore: invalid_use_of_internal_member
      for (final r in c.grips.grips)
        if (r.key == SelectionKey.root(h)) (r.grip.index, r.grip.x, r.grip.y),
    ];

const Handle wa = Handle(1300), wb = Handle(2600), wc = Handle(3900);

/// An L at the far origin: A (200, centre) runs into [lCorner] and B (115,
/// left) runs out of it at 110 degrees, each in its own rotated group, so
/// their ends at the corner meet within rounding, not bitwise. C (150,
/// right) starts 3 mm from the corner: near it, but not joined.
final Vector2 lStart = plan(0, 0), lCorner = plan(3000, 0);
final Vector2 lEnd = polar(lCorner, 23 + 110, 2500);
final Vector2 cStart = polar(lCorner, 23 - 120, 3);

void addL(DraftDocument doc, {bool withC = true}) {
  doc.commands
      .execute(addWall(doc, wa, lStart, lCorner, 200, Justification.centre));
  doc.commands
      .execute(addWall(doc, wb, lCorner, lEnd, 115, Justification.left));
  if (withC) {
    doc.commands.execute(addWall(doc, wc, cStart, polar(cStart, 23 - 120, 1500),
        150, Justification.right));
  }
}

const Handle shadow = Handle(5500), sep = Handle(5600);

/// fix/live-object-rule: the L, and two root-level groups carrying two
/// registered types each, as only a file brings them in. Each is made as
/// the app makes an object, regenerated through the dispatcher, then given
/// a second component straight through the store:
/// - [shadow], a door on C (so the engine regenerated it as an opening),
///   then `WallParams` 400 thick from the L's corner (on the joint, in
///   world) to [shadowTip], a point of the door's own children. Opening is
///   registered after Wall, so the engine names it an **opening**. With
///   [dangling], its `OpeningParams` is then rewritten to name a host that
///   does not exist (the q12 review's PR2d); otherwise its host is C (PR2).
/// - [sep], a separator (regenerated as one), then `OpeningParams` hosted
///   on B. Separator is registered after Opening, so it is a **separator**.
/// Both groups translated and rotated; neither handle the lowest.
PlanController shadowController({required bool dangling}) {
  final ctrl = wallController(gripPlan((doc) {
    addL(doc);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: shadow,
          parent: doc.rootHandle,
          transform: Transform2.translation(ox + 100.5, oy + 50.25)
              .multiply(Transform2.rotation(-0.4)),
          children: const [])),
      SetComponentCommand<OpeningParams>(
          shadow, const OpeningParams(wc, 700, 800, OpeningKind.door)),
    ], label: 'Add door'));
    final at = Transform2.translation(ox - 610.75, oy + 1720.5)
        .multiply(Transform2.rotation(0.9));
    final toSep = at.invert();
    final s = toSep.transformPoint(plan(600, 1800));
    final e = toSep.transformPoint(plan(2200, 1800));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: sep,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<SeparatorParams>(
          sep, SeparatorParams(s.x, s.y, e.x, e.y)),
    ], label: 'Add separator'));
  }));
  final doc = ctrl.document;
  final toShadow = doc.tree.accumulatedTransform(shadow).invert();
  final s = toShadow.transformPoint(lCorner);
  final tip = shadowTip(doc);
  doc.components
    ..attach<WallParams>(
        shadow, WallParams(s.x, s.y, tip.x, tip.y, 400, Justification.left))
    ..attach<OpeningParams>(
        sep, const OpeningParams(wb, 900, 700, OpeningKind.window));
  if (dangling) {
    doc.components.attach<OpeningParams>(shadow,
        const OpeningParams(Handle(0x7777), 700, 800, OpeningKind.door));
  }
  return ctrl;
}

/// The first point of [shadow]'s first generated line, group-local: a
/// point of the door's own children.
Vector2 shadowTip(DraftDocument doc) => [
      for (final k in kids(doc, shadow))
        if (kindOf(doc, k) == EntityKind.line) pointsOf(payloadOf(doc, k))[0],
    ].first;

void main() {
  testWidgets(
      'EG1 a free end drags to the resolved point, stored in its own group, '
      'the other end untouched; one undo step; a degenerate drop is refused, '
      'and a drag back onto the grip dispatches nothing', (tester) async {
    final ctrl = wallController(gripPlan((doc) {
      doc.commands.execute(addWall(
          doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.centre));
    }));
    final doc = ctrl.document;
    await pumpEditor(tester, ctrl, centre: plan(1500, 400), scale: 0.15);
    final before = canon(doc);
    final p0 = doc.components.get<WallParams>(wa)!;
    await selectWall(tester, ctrl, wa);
    final q = gridOf(doc, plan(3300, 1200));
    await dragWorld(tester, ctrl, endOf(doc, wa, 1), q);
    expect(doc.commands.undoDepth, 1);
    final p = doc.components.get<WallParams>(wa)!;
    expect(xy(p.start), xy(p0.start), reason: 'the start is untouched');
    final local = doc.tree.accumulatedTransform(wa).invert().transformPoint(q);
    expect(xy(p.end), xy(local), reason: "the group's local space, exactly");
    expect((endOf(doc, wa, 1) - q).length, lessThan(1e-6));
    expect([p.thickness, p.justification], [200, Justification.centre]);
    expectSquare(doc, wa);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);

    // Dropped onto its own start (object snap puts it there): the wall
    // would be degenerate, so the drag is refused and nothing changes.
    await dragWorld(
        tester, ctrl, endOf(doc, wa, 1), endOf(doc, wa, 0) + Vector2(4, -3));
    expect(doc.commands.undoDepth, 0);
    expect(canon(doc), before);
    // Dragged out and back onto itself: the release resolves onto the
    // grip's own point, so the drag is a no-op and dispatches nothing
    // (Task 7 review, m1).
    final end = endOf(doc, wa, 1);
    final a = globalAt(tester, ctrl, end);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(a);
    await gesture.moveTo(a + const Offset(12, 0));
    await gesture.moveTo(globalAt(tester, ctrl, plan(3600, 1500)));
    await tester.pump();
    await gesture.moveTo(a);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(doc.commands.undoDepth, 0);
    expect(canon(doc), before);
    // The provider directly: EG1-k (the kit).
  });

  testWidgets(
      'EG2 a selected wall shows two grips at the world endpoints of its '
      'rotated group; after a drag they sit at the new world endpoints',
      (tester) async {
    final ctrl = wallController(gripPlan((doc) => addL(doc)));
    final doc = ctrl.document;
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    await selectWall(tester, ctrl, wb);
    final w = worldWallOf(doc, wb);
    expect(gripsOf(ctrl, wb), [(0, w.s.x, w.s.y), (1, w.e.x, w.e.y)],
        reason: 'bitwise where WorldWall puts them');
    // ignore: invalid_use_of_internal_member
    expect(ctrl.grips.grips.every((r) => r.object), isTrue);
    final local = doc.components.get<WallParams>(wb)!;
    expect((local.start - w.s).length, greaterThan(1000),
        reason: 'the group is not at the identity');
    final q = gridOf(doc, polar(lEnd, 23 + 20, 600));
    await dragWorld(tester, ctrl, w.e, q);
    final after = worldWallOf(doc, wb);
    expect(xy(after.s), xy(w.s));
    expect((after.e - q).length, lessThan(1e-6));
    expect(gripsOf(ctrl, wb),
        [(0, after.s.x, after.s.y), (1, after.e.x, after.e.y)]);
  });

  testWidgets(
      "EG3 dragging an L's shared end moves both walls' ends in one undo "
      'step, still mitred; a wall 3 mm off stays (Review Focus 3, M-07q)',
      (tester) async {
    final ctrl = wallController(gripPlan((doc) => addL(doc)));
    final doc = ctrl.document;
    expect((endOf(doc, wa, 1) - endOf(doc, wb, 0)).length,
        inExclusiveRange(0, wallJoin.linear),
        reason: 'joined within rounding, not bitwise');
    expectMitre(doc, wa, wb);
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    final before = canon(doc);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    final pc = doc.components.get<WallParams>(wc)!;
    await selectWall(tester, ctrl, wa);
    final q = gridOf(doc, plan(3500, -400));
    await dragWorld(tester, ctrl, endOf(doc, wa, 1), q);
    expect(doc.commands.undoDepth, 1, reason: 'one undo step');
    for (final (h, k) in [(wa, 1), (wb, 0)]) {
      final local = doc.tree.accumulatedTransform(h).invert().transformPoint(q);
      final p = doc.components.get<WallParams>(h)!;
      expect(xy(k == 0 ? p.start : p.end), xy(local),
          reason: "${h.toHex()} in its own group's local space");
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6));
    }
    expect(xy(doc.components.get<WallParams>(wa)!.start), xy(pa.start));
    expect(xy(doc.components.get<WallParams>(wb)!.end), xy(pb.end));
    expect(doc.components.get<WallParams>(wc), pc, reason: 'C is not joined');
    expectMitre(doc, wa, wb);
    expectSquare(doc, wc);
    expect(driftOf(doc), isEmpty);
    expect(diagnosticsOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);
    expectMitre(doc, wa, wb);

    // The provider directly: EG3-k (the kit).
  });

  testWidgets(
      "EG4 a three-way node's end drags all three walls' ends, one undo "
      'step', (tester) async {
    final hub = plan(1500, 1500);
    const spokes = [
      (wa, 20.0, 200.0, Justification.centre, true),
      (wb, 140.0, 115.0, Justification.left, false),
      (wc, 255.0, 150.0, Justification.right, true),
    ];
    final ctrl = wallController(gripPlan((doc) {
      for (final (h, deg, t, j, fromHub) in spokes) {
        doc.commands.execute(
            addSpoke(doc, h, hub, deg + 23, 2000, t, j, fromHub: fromHub));
      }
    }));
    final doc = ctrl.document;
    int hubEnd(bool fromHub) => fromHub ? 0 : 1;
    final far = {
      for (final (h, _, _, _, fromHub) in spokes)
        h: endOf(doc, h, 1 - hubEnd(fromHub)),
    };
    await pumpEditor(tester, ctrl, centre: hub, scale: 0.15);
    final before = canon(doc);
    await selectWall(tester, ctrl, wb);
    final q = gridOf(doc, polar(hub, 23 + 80, 500));
    await dragWorld(tester, ctrl, endOf(doc, wb, 1), q);
    expect(doc.commands.undoDepth, 1);
    for (final (h, _, _, _, fromHub) in spokes) {
      final k = hubEnd(fromHub);
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6),
          reason: '${h.toHex()} follows');
      expect(xy(endOf(doc, h, 1 - k)), xy(far[h]!),
          reason: '${h.toHex()} keeps its far end');
      expect(worldOutline(doc, h), isNotEmpty);
    }
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);
    // The provider directly: EG4-k (the kit).
  });

  testWidgets(
      'EG5 a whole-wall move detaches it: the moved wall and its old '
      'neighbour both square their ends, in one step', (tester) async {
    final ctrl = wallController(gripPlan((doc) => addL(doc, withC: false)));
    final doc = ctrl.document;
    expectMitre(doc, wa, wb);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    await selectWall(tester, ctrl, wb);
    // A body drag from inside B's band, 700 mm away from A.
    final w = worldWallOf(doc, wb);
    final from = w.s + (w.e - w.s) * 0.5;
    await dragWorld(tester, ctrl, from, polar(from, 23 - 30, 700));
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wb), pb,
        reason: 'a move changes the group, not the parameters');
    expect(doc.components.get<WallParams>(wa), pa);
    expect((endOf(doc, wb, 0) - lCorner).length, greaterThan(500));
    expectSquare(doc, wa);
    expectSquare(doc, wb);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expectMitre(doc, wa, wb);
  });

  testWidgets(
      "EG6 (post-11 (e)) an L's corner drag moves the live walls only: a "
      "file's stray WallParams with an end on the joint, on a handle with no "
      'node, on a group nested in a turned group and on a root-level '
      'instance, is left alone and offers no grips; one undo step',
      (tester) async {
    // Built by hand: no tool makes these; only a file brings them in.
    const plain = Handle(5000), nested = Handle(5100), bare = Handle(5200);
    const inst = Handle(5300), def = Handle(5400);
    final ctrl = wallController(gripPlan((doc) {
      addL(doc);
      doc.tree.addDefinition(Definition(
          handle: def,
          name: 'D',
          basePoint: Vector2.zero(),
          children: const []));
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: plain,
            parent: doc.rootHandle,
            transform: Transform2.translation(ox + 700.25, oy - 310.5)
                .multiply(Transform2.rotation(1.1)),
            children: const [])),
        AddNodeCommand(GroupNode(
            handle: nested,
            parent: plain,
            transform: Transform2.translation(-250.5, 480.75)
                .multiply(Transform2.rotation(-0.6)),
            children: const [])),
        AddNodeCommand(InstanceNode(
            handle: inst,
            parent: doc.rootHandle,
            transform: Transform2.translation(ox + 333.5, oy - 222.25)
                .multiply(Transform2.rotation(0.8)),
            definition: def,
            layer: ReservedHandles.layerZero)),
      ], label: 'Add groups'));
    }));
    final doc = ctrl.document;
    // Written straight into the store, as a file brings them in: the bare
    // stray's start, and the nested and the instance strays' ends, sit on
    // the corner in world.
    final toNested = doc.tree.accumulatedTransform(nested).invert();
    final nestedStart = toNested.transformPoint(polar(lCorner, 23 - 60, 1800));
    final nestedEnd = toNested.transformPoint(lCorner);
    final strayBare = WallParams(lCorner.x, lCorner.y, lCorner.x + 900.5,
        lCorner.y - 1200.25, 120, Justification.left);
    final strayNested = WallParams(nestedStart.x, nestedStart.y, nestedEnd.x,
        nestedEnd.y, 90, Justification.right);
    final toInst = doc.tree.accumulatedTransform(inst).invert();
    final instStart = toInst.transformPoint(polar(lCorner, 23 + 150, 1400.5));
    final instEnd = toInst.transformPoint(lCorner);
    final strayInst = WallParams(instStart.x, instStart.y, instEnd.x, instEnd.y,
        100, Justification.left);
    doc.components
      ..attach<WallParams>(bare, strayBare)
      ..attach<WallParams>(nested, strayNested)
      ..attach<WallParams>(inst, strayInst);
    expect(doc.tree[bare], isNull, reason: 'no node');
    expect(doc.tree[nested], isA<GroupNode>());
    expect(doc.tree[inst], isA<InstanceNode>());
    expect(doc.tree[inst]!.parent, doc.rootHandle, reason: 'root-level');
    expect((strayNested.end - lCorner).length, greaterThan(1000),
        reason: 'the nested group is not at the identity');
    expect((strayInst.end - lCorner).length, greaterThan(1000),
        reason: 'the instance is not at the identity');
    final corner = endOf(doc, wa, 1);
    for (final (h, k) in [(bare, 0), (nested, 1), (inst, 1)]) {
      expect((endOf(doc, h, k) - corner).length, lessThan(wallJoin.linear),
          reason: '${h.toHex()} is on the joint in world: only liveness '
              'excludes it');
    }

    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    final before = canon(doc);
    final diagnostics = diagnosticsOf(doc);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    await selectWall(tester, ctrl, wa);
    final q = gridOf(doc, plan(3500, -400));
    await dragWorld(tester, ctrl, corner, q);
    expect(doc.commands.undoDepth, 1, reason: 'the commit succeeds');
    for (final (h, k) in [(wa, 1), (wb, 0)]) {
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6),
          reason: '${h.toHex()} follows');
    }
    expect(xy(doc.components.get<WallParams>(wa)!.start), xy(pa.start));
    expect(xy(doc.components.get<WallParams>(wb)!.end), xy(pb.end));
    expect(doc.components.get<WallParams>(bare), strayBare);
    expect(doc.components.get<WallParams>(nested), strayNested);
    expect(doc.components.get<WallParams>(inst), strayInst);
    expectMitre(doc, wa, wb);
    expect(driftOf(doc), isEmpty);
    expect(diagnosticsOf(doc), diagnostics);
    await undoKey(tester);
    expect(canon(doc), before);
    expect(doc.components.get<WallParams>(bare), strayBare);
    expect(doc.components.get<WallParams>(nested), strayNested);
    expect(doc.components.get<WallParams>(inst), strayInst);

    // The provider directly: EG6-k (the kit).
  });

  testWidgets(
      'WG-refuse-short (Review Focus 3, spec 3a C1.8) a wall-end grip dragged '
      "onto the wall's other end, where the wall would be no longer than the "
      'join tolerance: a drop there commits nothing and reports nothing; a '
      'drag that passes it and ends on an accepted point commits that point '
      'in one undo step; the grips stay usable', (tester) async {
    final ctrl = wallController(gripPlan((doc) {
      doc.commands.execute(addWall(
          doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.left));
    }));
    final doc = ctrl.document;
    await pumpEditor(tester, ctrl, centre: plan(1500, 400), scale: 0.15);
    final before = canon(doc);
    final reports = ctrl.diagnostics.value.length;
    await selectWall(tester, ctrl, wa);

    // Through the start (object snap puts the pointer on it: the wall
    // would be degenerate there) to an accepted grid point: one step.
    final q = gridOf(doc, plan(3400, 1300));
    final from = globalAt(tester, ctrl, endOf(doc, wa, 1));
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(12, 0));
    await gesture
        .moveTo(globalAt(tester, ctrl, endOf(doc, wa, 0) + Vector2(4, -3)));
    await tester.pump();
    await gesture.moveTo(globalAt(tester, ctrl, q));
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1);
    expect((endOf(doc, wa, 1) - q).length, lessThan(1e-6));
    expect(ctrl.diagnostics.value, hasLength(reports));

    // Dropped on the start: refused; nothing committed, nothing reported.
    final moved = canon(doc);
    await dragWorld(
        tester, ctrl, endOf(doc, wa, 1), endOf(doc, wa, 0) + Vector2(4, -3));
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1);
    expect(canon(doc), moved);
    expect(ctrl.diagnostics.value, hasLength(reports));

    // The grips stay usable: the next drag lands, one more step.
    final r = gridOf(doc, plan(2600, -700));
    await dragWorld(tester, ctrl, endOf(doc, wa, 1), r);
    expect(doc.commands.undoDepth, 2);
    expect((endOf(doc, wa, 1) - r).length, lessThan(1e-6));
    expect(ctrl.diagnostics.value, hasLength(reports));
    await undoKey(tester);
    await undoKey(tester);
    expect(canon(doc), before);
  });

  testWidgets(
      'EG7 (fix/live-object-rule, the q12 review\'s PR2d) a file\'s group '
      'carrying WallParams on the joint and OpeningParams naming no host is '
      'an opening, not a wall: the corner drag of A lands one undo step, '
      'throws nothing and leaves the group as loaded', (tester) async {
    final ctrl = shadowController(dangling: true);
    final doc = ctrl.document;
    final wallP = doc.components.get<WallParams>(shadow)!;
    final openingP = doc.components.get<OpeningParams>(shadow)!;
    expect(openingP.host, const Handle(0x7777), reason: 'dangling');
    final corner = endOf(doc, wa, 1);
    expect((endOf(doc, shadow, 0) - corner).length, lessThan(wallJoin.linear),
        reason: 'the shadow\'s WallParams is on the joint in world');
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    final before = canon(doc);
    await selectWall(tester, ctrl, wa);
    final q = gridOf(doc, plan(3500, -400));
    await dragWorld(tester, ctrl, corner, q);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'the commit succeeds');
    for (final (h, k) in [(wa, 1), (wb, 0)]) {
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6),
          reason: '${h.toHex()} follows');
    }
    expect(doc.components.get<WallParams>(shadow), wallP);
    expect(doc.components.get<OpeningParams>(shadow), openingP);
    await undoKey(tester);
    expect(canon(doc), before);
  });

  testWidgets(
      'EG8 (fix/live-object-rule, PR2) the corner drag\'s command and '
      'preview name the real walls only: a file\'s opening carrying '
      'WallParams on the joint does not follow, and a separator carrying '
      'OpeningParams on B is not kept put', (tester) async {
    final ctrl = shadowController(dangling: false);
    final doc = ctrl.document;
    final wallP = doc.components.get<WallParams>(shadow)!;
    final openingP = doc.components.get<OpeningParams>(shadow)!;
    final sepS = doc.components.get<SeparatorParams>(sep)!;
    final sepO = doc.components.get<OpeningParams>(sep)!;
    final corner = endOf(doc, wa, 1);
    expect((endOf(doc, shadow, 0) - corner).length, lessThan(wallJoin.linear),
        reason: 'only the rule separates the shadow from the joint');
    final q = gridOf(doc, plan(3500, -400));

    // The provider directly: EG8-k (the kit).

    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    final before = canon(doc);
    await selectWall(tester, ctrl, wa);
    await dragWorld(tester, ctrl, corner, q);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'the commit succeeds');
    expect(doc.components.get<WallParams>(shadow), wallP);
    expect(doc.components.get<OpeningParams>(shadow), openingP);
    expect(doc.components.get<SeparatorParams>(sep), sepS);
    expect(doc.components.get<OpeningParams>(sep), sepO);
    await undoKey(tester);
    expect(canon(doc), before);
  });

  testWidgets(
      'EG9 (fix/live-object-rule) a file\'s group carrying WallParams and '
      'OpeningParams is an opening everywhere and a wall nowhere; a '
      'separator carrying OpeningParams is a separator everywhere and an '
      'opening nowhere', (tester) async {
    final ctrl = shadowController(dangling: false);
    final doc = ctrl.document;
    // A file's opening hosted on the shadow, which is no wall.
    const orphan = Handle(5700);
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: orphan,
        parent: doc.rootHandle,
        transform: Transform2.translation(ox + 1500.25, oy - 900.5)
            .multiply(Transform2.rotation(1.3)),
        children: const [])));
    doc.commands.clearHistory();
    doc.components.attach<OpeningParams>(
        orphan, const OpeningParams(shadow, 300, 600, OpeningKind.window));
    final m = doc.tree.accumulatedTransform(shadow);
    final tipW = m.transformPoint(shadowTip(doc));
    final ws = worldWallOf(doc, shadow);
    expect((tipW - ws.e).length, lessThan(1e-6),
        reason: 'premise: the shadow\'s WallParams ends on its own child');

    // The adapters, the band cache, the attach, the room inputs and the
    // grips: EG9-k (the kit).

    // The panel: the Opening section for the shadow, no section for the
    // separator.
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    ctrl.activeSelection.replace([SelectionKey.root(shadow)]);
    await tester.pump();
    expect(
        find.byKey(const Key('section-architecture.opening')), findsOneWidget);
    expect(find.byKey(const Key('section-architecture.wall')), findsNothing);
    ctrl.activeSelection.replace([SelectionKey.root(sep)]);
    await tester.pump();
    expect(find.byKey(const Key('section-architecture.opening')), findsNothing);
    expect(find.byKey(const Key('section-architecture.wall')), findsNothing);

    // The Position field: an opening hosted on the shadow has no wall, so
    // no position is valid (the field reverts, nothing is written); the
    // shadow's own position, on C, commits one step.
    Future<void> enter(String text) async {
      await tester.enterText(find.byKey(const Key('property-position')), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    final o2 = doc.components.get<OpeningParams>(orphan)!;
    ctrl.activeSelection.replace([SelectionKey.root(orphan)]);
    await tester.pump();
    expect(
        find.byKey(const Key('section-architecture.opening')), findsOneWidget);
    expect(ws.s.distanceTo(ws.e), greaterThan(50),
        reason: "premise: 50 lies within the shadow's WallParams");
    await enter('50');
    expect(doc.components.get<OpeningParams>(orphan), o2);
    expect(doc.commands.undoDepth, 0);
    ctrl.activeSelection.replace([SelectionKey.root(shadow)]);
    await tester.pump();
    await enter('650');
    expect(doc.components.get<OpeningParams>(shadow)!.position, 650);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets(
      'EG10 (fix/live-object-rule, the L2 review\'s m1) a file\'s dimension '
      'group carrying WallParams on the joint is a dimension, not a wall: '
      'not among the adapter\'s walls, the band cache\'s or the attach\'s, '
      'no wall grips or wall section, and the corner drag leaves it alone',
      (tester) async {
    // Not an opening: a fix that skips only groups carrying OpeningParams
    // leaves this one a wall.
    const dim = Handle(0x1A2B);
    final at = Transform2.translation(ox + 820.5, oy - 1330.25)
        .multiply(Transform2.rotation(0.7));
    final toDim = at.invert();
    // Across the stray's line (below), beyond its far end: the dimension
    // line crosses it.
    final d0 = toDim.transformPoint(plan(4200, 1500));
    final d1 = toDim.transformPoint(plan(6600, 1500));
    final ctrl = wallController(gripPlan((doc) {
      addL(doc);
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: dim,
            parent: doc.rootHandle,
            transform: at,
            children: const [])),
        SetComponentCommand<DimensionParams>(
            dim,
            DimensionParams(FixedEnd(d0.x, d0.y), FixedEnd(d1.x, d1.y),
                DimKind.aligned, 350.5)),
      ], label: 'Add dimension'));
    }));
    final doc = ctrl.document;
    expect(kids(doc, dim), isNotEmpty,
        reason: 'premise: regenerated as a dimension');
    // Written straight into the store, as a file brings it in: 400 thick,
    // from the L's corner (on the joint, in world) out between B and C.
    final ws0 = toDim.transformPoint(lCorner);
    final we0 = toDim.transformPoint(polar(lCorner, 23 + 40, 1800));
    final stray =
        WallParams(ws0.x, ws0.y, we0.x, we0.y, 400, Justification.left);
    doc.components.attach<WallParams>(dim, stray);
    final dimP = doc.components.get<DimensionParams>(dim)!;
    final corner = endOf(doc, wa, 1);
    final ws = worldWallOf(doc, dim);
    expect((ws.s - corner).length, lessThan(wallJoin.linear),
        reason: 'premise: on the joint in world; only the rule excludes it');
    expect((ws.s - Vector2(ox, oy)).length, greaterThan(1000));

    // The adapters, the band cache, the attach, the room inputs and the
    // grips: EG10-k (the kit).

    // The corner drag: A and B only; the dimension group as loaded.
    final q = gridOf(doc, plan(3500, -400));
    // The provider directly: EG10-k (the kit).
    await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);
    final before = canon(doc);
    await selectWall(tester, ctrl, wa);
    await dragWorld(tester, ctrl, corner, q);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1, reason: 'the commit succeeds');
    expect(doc.components.get<WallParams>(dim), stray);
    expect(doc.components.get<DimensionParams>(dim), dimP);
    await undoKey(tester);
    expect(canon(doc), before);

    // The panel: the Dimension section, not the Wall section.
    ctrl.activeSelection.replace([SelectionKey.root(dim)]);
    await tester.pump();
    expect(find.byKey(const Key('section-architecture.dimension')),
        findsOneWidget);
    expect(find.byKey(const Key('section-architecture.wall')), findsNothing);
  });
}
