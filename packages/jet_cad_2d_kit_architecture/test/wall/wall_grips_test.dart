// Ported from jet_cad_floor_plan/test/wall_grips_test.dart (3a Task 12,
// R-P1): the provider-direct tails of EG1, EG3, EG4 and EG6, and of EG8
// (Task 17, R-P8), whose WallGrips is a kit internal, assertions
// unchanged, each over its case's fixture as the shell case leaves it
// there (the shell part ends undone or
// refused, so the document is the fixture's). The shell parts run in
// jet_cad_2d_integration. Every wall sits at the far origin in its own
// rotated group (`groupAt`, or a spoke's group at its hub).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_grips.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';

/// The walls [build] adds to an empty document with the kit tests' system,
/// with no undo history (wall_grips_test.dart:36-56's `gripDoc`, without
/// the page, which only the shell's snap reads).
DraftDocument gripDoc(void Function(DraftDocument doc) build) {
  final doc = wallDoc();
  build(doc);
  doc.commands.clearHistory();
  return doc;
}

/// The shell case's grid point nearest [p]: its 1:20 page near the far
/// origin, grid at 10 mm (wall_grips_test.dart:42-49, 119-121).
Vector2 gridOf(Vector2 p) => snapToGrid(
    p,
    10,
    PageComponent(
        scaleDenominator: 20,
        originX: ox - 2000,
        originY: oy - 2000,
        gridStepMm: 10));

/// Wall [h]'s end [k] in world.
Vector2 endOf(DraftDocument doc, Handle h, int k) =>
    worldWallOf(doc, h).endpoint(k);

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
DraftDocument shadowDoc({required bool dangling}) {
  final doc = gripDoc((doc) {
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
  });
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
  return doc;
}

/// The first point of [shadow]'s first generated line, group-local: a
/// point of the door's own children.
Vector2 shadowTip(DraftDocument doc) => [
      for (final k in kids(doc, shadow))
        if (kindOf(doc, k) == EntityKind.line) pointsOf(payloadOf(doc, k))[0],
    ].first;

void main() {
  test(
      'EG1-k a degenerate drop is refused by the provider: no command, no preview',
      () {
    final doc = gripDoc((doc) {
      doc.commands.execute(addWall(
          doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.centre));
    });
    final g = WallGrips(live: liveOf(doc)).gripsOf(doc, wa)[1];
    expect(WallGrips(live: liveOf(doc)).drag(doc, wa, g, endOf(doc, wa, 0)),
        isNull);
    expect(WallGrips(live: liveOf(doc)).preview(doc, wa, g, endOf(doc, wa, 0)),
        isEmpty);
  });

  test(
      "EG3-k an L's shared end, the provider directly: the command's members ascend by handle, the preview is both moved centrelines in world, another grip moves A's free start alone, a degenerate wall on the corner joins nothing",
      () {
    final doc = gripDoc((doc) => addL(doc));
    final q = gridOf(plan(3500, -400));
    // The provider directly: the command's members ascend by handle, and
    // the preview is both moved centrelines, in world.
    final grips = WallGrips(live: liveOf(doc));
    final g = grips.gripsOf(doc, wa)[1];
    final c = grips.drag(doc, wa, g, q)! as CompoundCommand;
    expect([
      for (final m in c.children) (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb
    ]);
    final pieces = grips.preview(doc, wa, g, q);
    expect(pieces.map((p) => p.$1), [EntityKind.line, EntityKind.line]);
    final [a0, a1] = pointsOf(pieces[0].$2);
    final [b0, b1] = pointsOf(pieces[1].$2);
    expect((a0 - lStart).length, lessThan(1e-6));
    for (final p in [a1, b0]) {
      expect((p - q).length, lessThan(1e-6));
    }
    expect((b1 - lEnd).length, lessThan(1e-6));
    // Another grip of the same wall, through the same provider: A's free
    // start moves alone.
    final g0 = grips.gripsOf(doc, wa)[0];
    expect(grips.preview(doc, wa, g0, q), hasLength(1));

    // A degenerate wall D sitting on the corner joins nothing (D2): the
    // drag still moves A and B, and leaves D where it is.
    const wd = Handle(5200);
    doc.commands
        .execute(addWall(doc, wd, lCorner, lCorner, 90, Justification.centre));
    final d = grips.drag(doc, wa, grips.gripsOf(doc, wa)[1], q);
    expect([
      for (final m in (d! as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb
    ]);
  });

  test(
      "EG4-k a three-way node's end, the provider directly: one command per wall, ascending by handle, whichever end is dragged",
      () {
    final hub = plan(1500, 1500);
    const spokes = [
      (wa, 20.0, 200.0, Justification.centre, true),
      (wb, 140.0, 115.0, Justification.left, false),
      (wc, 255.0, 150.0, Justification.right, true),
    ];
    final doc = gripDoc((doc) {
      for (final (h, deg, t, j, fromHub) in spokes) {
        doc.commands.execute(
            addSpoke(doc, h, hub, deg + 23, 2000, t, j, fromHub: fromHub));
      }
    });
    final q = gridOf(polar(hub, 23 + 80, 500));
    // One command per wall, ascending by handle, whichever end is dragged.
    final grips = WallGrips(live: liveOf(doc));
    final c = grips.drag(doc, wb, grips.gripsOf(doc, wb)[1], q);
    expect([
      for (final m in (c! as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb,
      wc
    ]);
  });

  test(
      "EG6-k an L's corner and a file's strays, the provider directly: a stray offers no grips; a live wall offers its two ends, bitwise; the command and the preview name A and B only",
      () {
    // Built by hand: no tool makes these; only a file brings them in.
    const plain = Handle(5000), nested = Handle(5100), bare = Handle(5200);
    const inst = Handle(5300), def = Handle(5400);
    final doc = gripDoc((doc) {
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
    });
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
    final q = gridOf(plan(3500, -400));
    // The provider directly: a stray offers no grips, as its drag and
    // preview do nothing; a live wall offers its two ends, bitwise.
    final grips = WallGrips(live: liveOf(doc));
    for (final h in [bare, nested, inst]) {
      expect(grips.gripsOf(doc, h), isEmpty,
          reason: '${h.toHex()} is not a live wall');
    }
    expect([
      for (final g in grips.gripsOf(doc, wa)) (g.role, g.index, g.x, g.y)
    ], [
      for (final k in [0, 1])
        (GripRole.stretch, k, endOf(doc, wa, k).x, endOf(doc, wa, k).y)
    ]);
    // The command and the preview name A and B only.
    final g = grips.gripsOf(doc, wa)[1];
    final c = grips.drag(doc, wa, g, q)! as CompoundCommand;
    expect([
      for (final m in c.children) (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb
    ]);
    final pieces = grips.preview(doc, wa, g, q);
    expect(pieces.map((p) => p.$1), [EntityKind.line, EntityKind.line]);
    final [a0, a1] = pointsOf(pieces[0].$2);
    final [b0, b1] = pointsOf(pieces[1].$2);
    expect((a0 - lStart).length, lessThan(1e-6));
    for (final p in [a1, b0]) {
      expect((p - q).length, lessThan(1e-6));
    }
    expect((b1 - lEnd).length, lessThan(1e-6));
  });

  test(
      "EG8-k the corner drag's command and preview, the provider directly: the real walls only (a file's opening carrying WallParams on the joint, a separator carrying OpeningParams on B)",
      () {
    // Today's :616-623 less the four components it reads for the shell
    // part's after-drag checks (EG8, the integration package's): unused here.
    final doc = shadowDoc(dangling: false);
    final corner = endOf(doc, wa, 1);
    expect((endOf(doc, shadow, 0) - corner).length, lessThan(wallJoin.linear),
        reason: 'only the rule separates the shadow from the joint');
    final q = gridOf(plan(3500, -400));

    final grips = WallGrips(live: liveOf(doc));
    final g = grips.gripsOf(doc, wa)[1];
    final c = grips.drag(doc, wa, g, q)! as CompoundCommand;
    // ignore: avoid_dynamic_calls
    expect([for (final m in c.children) (m as dynamic).handle as Handle],
        [wa, wb]);
    final pieces = grips.preview(doc, wa, g, q);
    expect(pieces.map((p) => p.$1), [EntityKind.line, EntityKind.line]);
    final [a0, a1] = pointsOf(pieces[0].$2);
    final [b0, b1] = pointsOf(pieces[1].$2);
    expect((a0 - lStart).length, lessThan(1e-6));
    for (final p in [a1, b0]) {
      expect((p - q).length, lessThan(1e-6));
    }
    expect((b1 - lEnd).length, lessThan(1e-6));
  });
}
