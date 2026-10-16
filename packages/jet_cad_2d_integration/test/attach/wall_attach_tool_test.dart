// Spec 09c D6 (plan 09c-1 Task 7): the wall attachment. A rig with walls
// adds them through the parametric system, each in its own rotated group
// near (1e5, −7e4) (`wall_attach_fixture.dart`, plan P-2), at 30° and
// −112.5°, non-centre justified; the pointer rests on either face; the
// symbol is the toilet (its back the cistern, its base point off its back
// edge) and the kitchen base units, mirrored and not, turned and not. The
// expected transforms are `attachToWall`'s over the rig's own runs (pinned
// by `wall_attach_test.dart`) and checked against hand arithmetic along the
// run (`q = a + u·t`, the rotation `t`).
//
// Ported to jet_cad_2d_integration (3a Task 28, D-02; rulings IA-R1,
// IA-R4) from jet_cad_floor_plan/test/symbols/symbol_place_tool_test.dart's
// group "the wall attachment (spec 09c D6)" (:1368-1740), 12 of its 13
// cases, and the rig parts they use. The plan's plan.symbol is internal, so
// each case is driven on the canvas: `c.armSymbol`, a mouse click, the keys
// R, M and Shift+R, F3. A ghost read (`ghostPlacement`, `ghostAttachment`,
// `ghostAt`, `quarterTurns`) that follows a pointer event is the instance
// one click commits at that pointer (2a's AT-9 pins that the release uses
// the ghost's attachment), read and then undone, so the document, the undo
// depth and the instance count stay the source's; an attached ghost is a
// commit equal to the provider's answer, a free one a commit equal to the
// free placement. A click re-resolves the ghost, so a read that must see
// what a key, a camera change or a re-arm did with NO pointer event is
// read from the resting ghost's own drawing instead (review fix 1):
// `restingPlacement` (the matrix the tool's world overlay draws the ghost
// under) and `restingMarker` (the hourglass its screen overlay draws at the
// attachment's marker), with the mouse resting on the canvas. The
// oracle is the kit's provider through the contract (IA-R1): `want.q` is
// `want.marker`, `want.run` the marker on that face's line. The symbols
// are the kit's furniture (C7 classes 1 and 2: `architecture.*`, the tag
// against-wall is `attachTo: ['wall-face']`).
//
// Fixture changes: the camera is centred on the wall's middle at 0.05 px/mm
// (every click lands on the canvas); the source's pA, 20 m from the wall
// and off the canvas, is [away], 2 m into the room from the face.
//
// Not ported: "a tool given no wall faces never attaches (09b's
// behaviour)": its premise (a tool built without faces) cannot be built,
// plan.symbol always has the registry (C7, premise impossible).
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, kSnapMarkerPixels;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_plans.dart' hide attachOf;
import '../support/attach_plans.dart' as support show attachOf;
import '../support/canvas_rig.dart';
import '../support/plans.dart' show polar, worldEndsOf;

/// The camera's pixels per mm: the aperture is 200 mm.
const double scale = 0.05;

/// The line's start: the object snap target, off the grid.
final Vector2 e0 = Vector2(73250.5, -41810.25);

/// The page grid: 25 mm from an origin off every round number.
const double gridStep = 25;
const double gridOriginX = 70000.3, gridOriginY = -40000.7;

Vector2 gridOf(Vector2 p) => Vector2(
    gridOriginX + ((p.x - gridOriginX) / gridStep).roundToDouble() * gridStep,
    gridOriginY + ((p.y - gridOriginY) / gridStep).roundToDouble() * gridStep);

void expectAt(Vector2 actual, Vector2 expected, String reason) {
  expect(actual.x, expected.x, reason: '$reason (x)');
  expect(actual.y, expected.y, reason: '$reason (y)');
}

/// The rig's edge capture: 10 / 0.05 = 200 mm.
const double edgeWorld = kSnapAperturePixels / scale;

/// A free wall at [deg], 3600 long and 150 thick, justified [j], from
/// `farAt(1234.5, 678.25)`.
SceneWall attachWall(double deg, Justification j) {
  final s = farAt(1234.5, 678.25);
  return (s, polar(s, deg, 3600), 150, j);
}

/// Which face of the wall (today's `FaceSide`, the kit's, not exported).
enum FaceSide { left, right }

/// P-2's two angles, each with a non-centre justification and the face the
/// pointer rests on.
const List<(double, Justification, FaceSide)> attachCases = [
  (30, Justification.left, FaceSide.left),
  (-112.5, Justification.right, FaceSide.right),
];

/// The box's four corners under [t].
List<Vector2> footprint(SymbolBox b, Transform2 t) => [
      for (final (x, y) in [
        (b.left, b.front),
        (b.right, b.front),
        (b.right, b.back),
        (b.left, b.back),
      ])
        t.transformPoint(Vector2(x, y)),
    ];

/// A point away from the wall, beyond the capture (the source's pA, which
/// is off this camera's canvas): 2 m into the room at 0.37 along [r].
Vector2 away(FaceLine r) => onRun(r, r.length * 0.37, 2000);

/// The one mouse of a test: a second mouse on the same device trips the
/// mouse tracker, so every hover, click and drag goes through this one,
/// which stays on the canvas (the ghost rests) until the next rig or the
/// test's end.
TestGesture? _mouse;

/// Today's `Rig(walls: [...])` over the editor: the walls in their groups,
/// the rig's page (its 25 mm grid off every round number) and its line
/// `e0`, the camera on the wall at [scale], the canvas focused.
final class Rig {
  Rig._(this.tester, this.c, this.wallHandles);

  static Future<Rig> mount(WidgetTester tester,
      {required List<SceneWall> walls, bool objectSnap = true}) async {
    await _mouse?.removePointer();
    _mouse = null;
    final plan = attachPlan(walls, extra: (d) {
      d.commands.execute(SetComponentCommand<PageComponent>(
          d.rootHandle,
          PageComponent(
              originX: gridOriginX,
              originY: gridOriginY,
              gridStepMm: gridStep)));
      d.commands.execute(addDrafted(
          d, EntityKind.line, linePayload(e0, e0 + Vector2(1200, 700)),
          layer: ReservedHandles.layerZero));
    });
    final c = architectureController(json: plan.json);
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    expect(await symbolsReady(tester, c), isTrue,
        reason: 'premise: the furniture library loaded');
    final ends = worldEndsOf(c.document, plan.walls.first);
    await frameOn(tester, c, (ends.s + ends.e) / 2, scale: scale);
    await focusCanvas(tester);
    if (!objectSnap) {
      expect(await pressKey(tester, LogicalKeyboardKey.f3), isTrue,
          reason: 'premise: F3 toggled object snap off');
    }
    return Rig._(tester, c, plan.walls);
  }

  final WidgetTester tester;
  final PlanController c;
  final List<Handle> wallHandles;

  DraftDocument get document => c.document;

  List<InstanceNode> get instances =>
      document.tree.nodes.whereType<InstanceNode>().toList()
        ..sort((a, b) => a.handle.value.compareTo(b.handle.value));

  /// Today's `rig.armed.value = e`.
  Future<void> arm(PlanSymbol e) async {
    expect(c.armSymbol(e), isTrue, reason: 'premise: ${e.id} armed');
    await tester.pump();
  }

  /// Today's `rig.key(kR)`, `rig.key(kM)`.
  Future<void> key(LogicalKeyboardKey k) => pressKey(tester, k);

  /// Today's `rig.key(kR, held: [kShift])`.
  Future<void> shiftR() async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await pressKey(tester, LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  /// The rig's one wall's face on [side].
  FaceLine runOn(FaceSide side) =>
      faceLineOf(document, wallHandles.single, left: side == FaceSide.left);

  /// The world point the canvas reads for the pointer at world [p].
  Vector2 worldOf(Vector2 p) => worldAt(tester, c, globalAt(tester, c, p));

  /// The free placement of [e] at the pointer [p]: its resolved point, the
  /// rig's grid (today's `freeOf`, at `tool.ghostAt`).
  Transform2 freeOf(PlanSymbol e, Vector2 p,
          {int turns = 0, bool mirrored = false}) =>
      placementTransform(
          at: gridOf(worldOf(p)),
          basePoint: e.entry.definition.basePoint,
          quarterTurns: turns,
          mirrored: mirrored);

  /// The provider's answer for [e] at the pointer [p] at the camera scale
  /// [k] (IA-R1; today's `attachToWall` over the rig's runs).
  Attachment? attachOf(PlanSymbol e, Vector2 p,
          {bool mirrored = false, int turns = 0, double k = scale}) =>
      attachAt(e, worldOf(p), mirrored: mirrored, turns: turns, k: k);

  /// The provider's answer for [e] at the world pointer [w].
  Attachment? attachAt(PlanSymbol e, Vector2 w,
          {bool mirrored = false, int turns = 0, double k = scale}) =>
      support.attachOf(
          document,
          e.entry,
          w,
          placementTransform(
              at: gridOf(w),
              basePoint: e.entry.definition.basePoint,
              quarterTurns: turns,
              mirrored: mirrored),
          k,
          mirrored: mirrored);

  /// The mouse moved to rest at global [g] (a hover).
  Future<void> restAt(Offset g) async {
    final m = _mouse;
    if (m == null) {
      final added = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await added.addPointer(location: g - const Offset(3, 3));
      _mouse = added;
      addTearDown(() async {
        await _mouse?.removePointer();
        _mouse = null;
      });
    }
    await _mouse!.moveTo(g);
    await tester.pump();
  }

  /// The mouse resting at world [p]: today's `rig.hover(p)`.
  Future<void> rest(Vector2 p) => restAt(globalAt(tester, c, p));

  /// A press and a release of the resting mouse at global [g].
  Future<void> clickAt(Offset g) async {
    await restAt(g);
    await _mouse!.down(g);
    await tester.pump();
    await _mouse!.up();
    await tester.pump();
  }

  /// A press at world [from], eight moves, a release at world [to]: today's
  /// `rig.down(from); rig.up(to)` with the pointer moving between.
  Future<void> drag(Vector2 from, Vector2 to) async {
    final a = globalAt(tester, c, from), b = globalAt(tester, c, to);
    await restAt(a);
    await _mouse!.down(a);
    await tester.pump();
    for (var i = 1; i <= 8; i++) {
      await _mouse!.moveTo(Offset.lerp(a, b, i / 8)!);
      await tester.pump();
    }
    await _mouse!.up();
    await tester.pump();
  }

  /// A click at global [g]: the placement one click commits there, read and
  /// undone (IA-R4: today's ghost read at that pointer).
  Future<Transform2> ghostAtGlobal(Offset g) async {
    final n = instances.length, depth = document.commands.undoDepth;
    await clickAt(g);
    expect(instances, hasLength(n + 1),
        reason: 'premise: the click placed one instance');
    final t = instances.last.transform;
    c.undo();
    await tester.pump();
    expect(document.commands.undoDepth, depth, reason: 'premise: undone');
    return t;
  }

  /// [ghostAtGlobal] at world [p].
  Future<Transform2> ghostAt(Vector2 p) =>
      ghostAtGlobal(globalAt(tester, c, p));

  /// A placement at [p]: today's `rig.down(p); rig.up(p)`.
  Future<void> click(Vector2 p) => clickAt(globalAt(tester, c, p));

  /// The resting ghost's placement, read with no pointer event (today's
  /// `rig.tool.ghostPlacement!`).
  Transform2 resting() {
    final t = restingPlacement(tester, c);
    expect(t, isNotNull, reason: 'premise: the ghost is drawn');
    return t!;
  }

  /// The resting ghost's marker on the canvas, null when free (today's
  /// `rig.tool.ghostAttachment` through the camera).
  Offset? marker() => restingMarker(tester, c);

  /// [w] on the canvas.
  Offset screen(Vector2 w) => screenAt(c, w);

  /// Where an instance put its symbol's base point: its `at`.
  Vector2 placedAt(InstanceNode n) => n.transform
      .transformPoint(document.tree.definition(n.definition)!.basePoint);
}

void main() {
  group('the wall attachment (spec 09c D6)', () {
    /// A point 0.37 along [r] and 160 mm (half the capture) into the room.
    Vector2 nearFace(FaceLine r) => onRun(r, r.length * 0.37, 160);

    testWidgets('the fixtures are not degenerate', (tester) async {
      for (final (deg, j, side) in attachCases) {
        final rig = await Rig.mount(tester, walls: [attachWall(deg, j)]);
        final toilet = armable(rig.c, 'bath.toilet');
        final base600 = armable(rig.c, 'kitchen.base.600');
        final island = armable(rig.c, 'kitchen.island');
        expect(toilet.component.attachTo, contains('wall-face'));
        expect(base600.component.attachTo, contains('wall-face'));
        expect(island.component.attachTo, isNot(contains('wall-face')));
        final b = boxOfEntry(toilet.entry)!;
        expect(toilet.entry.definition.basePoint == b.backCentre, isFalse,
            reason: 'the toilet\'s base point is not its back-centre');
        final r = rig.runOn(side);
        expect(r.t.x.abs(), greaterThan(0.1),
            reason: '$deg°: not axis-aligned');
        expect(r.t.y.abs(), greaterThan(0.1),
            reason: '$deg°: not axis-aligned');
        expect(r.a.length, greaterThan(1e5), reason: 'far from the origin');
        expect(rig.c.camera.value.scale, isNot(1));
      }
    });

    testWidgets(
        'a tagged symbol attaches on hover and on release: the ghost and the '
        'instance take attachToWall\'s transform byte for byte (30° and '
        '−112.5°, either face, mirrored and not, turned)', (tester) async {
      for (final (deg, j, side) in attachCases) {
        for (final mirrored in [false, true]) {
          final why = '$deg° ${side.name}${mirrored ? ' mirrored' : ''}';
          final rig = await Rig.mount(tester, walls: [attachWall(deg, j)]);
          final toilet = armable(rig.c, 'bath.toilet');
          await rig.arm(toilet);
          await rig.key(LogicalKeyboardKey.keyR);
          if (mirrored) await rig.key(LogicalKeyboardKey.keyM);
          final run = rig.runOn(side);
          final u = run.length * 0.37;
          final p = onRun(run, u, 160);
          final want = rig.attachOf(toilet, p, mirrored: mirrored, turns: 1)!;
          // Hand arithmetic: the back-centre on the face at the pointer's
          // `u`, turned to `t`, mirrored about the box's centre.
          expect(
              faceDistance(rig.document, rig.wallHandles.single, want.marker,
                  left: side == FaceSide.left),
              lessThan(1e-6),
              reason: why);
          expect(want.marker.distanceTo(onRun(run, u, 0)), lessThan(1e-6),
              reason: why);
          expect(
              partsOf(want.transform),
              partsOf(placementTransform(
                  at: want.marker,
                  basePoint: boxOfEntry(toilet.entry)!.backCentre,
                  rotation: (run.t.x, run.t.y),
                  mirrored: mirrored)),
              reason: why);

          final ghost = await rig.ghostAt(p);
          expect(partsOf(ghost), partsOf(want.transform),
              reason: '$why: the ghost');
          expect(
              partsOf(ghost),
              isNot(
                  partsOf(rig.freeOf(toilet, p, turns: 1, mirrored: mirrored))),
              reason: '$why: not the free placement');
          // Pressed away from the wall, released on it.
          expect(
              partsOf(await rig.ghostAt(away(run))),
              partsOf(
                  rig.freeOf(toilet, away(run), turns: 1, mirrored: mirrored)),
              reason: '$why: free');
          await rig.drag(away(run), p);
          expect(
              partsOf(rig.instances.single.transform), partsOf(want.transform),
              reason: '$why: the instance');
          expect(rig.document.commands.undoDepth, 1, reason: why);
        }
      }
    });

    testWidgets(
        'the capture is kWallAttachPixels (16 px), not the snap aperture: '
        '300 mm off the face attaches at 0.05 px/mm, 330 mm does not',
        (tester) async {
      // The support's copy of plan.symbol's constant (not exported).
      expect(kAttachPixels, 16.0);
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final toilet = armable(rig.c, 'bath.toilet');
      await rig.arm(toilet);
      final run = rig.runOn(FaceSide.left);
      final near = onRun(run, 1500, 300);
      final attached = rig.attachOf(toilet, near);
      expect(attached, isNotNull, reason: '300 < 320 mm');
      expect(partsOf(await rig.ghostAt(near)), partsOf(attached!.transform),
          reason: '300 < 320 mm');
      expect(300, greaterThan(edgeWorld), reason: 'premise: past 10 px');
      final far = onRun(run, 1500, 330);
      expect(partsOf(await rig.ghostAt(far)), partsOf(rig.freeOf(toilet, far)),
          reason: '330 > 320 mm');
    });

    testWidgets(
        'an untagged symbol (the island) does not attach: the ghost and the '
        'instance are free (M-09c-a)', (tester) async {
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final island = armable(rig.c, 'kitchen.island');
      await rig.arm(island);
      await rig.key(LogicalKeyboardKey.keyR);
      final p = nearFace(rig.runOn(FaceSide.left));
      expect(rig.attachOf(island, p, turns: 1), isNotNull,
          reason: 'premise: a face would take its box');
      final free = rig.freeOf(island, p, turns: 1);
      expect(partsOf(await rig.ghostAt(p)), partsOf(free));
      await rig.click(p);
      expect(partsOf(rig.instances.single.transform), partsOf(free));
    });

    testWidgets(
        'with object snap off (F3) nothing attaches; on, it does '
        '(M-09c-l)', (tester) async {
      for (final on in [false, true]) {
        final rig = await Rig.mount(tester,
            objectSnap: on, walls: [attachWall(30, Justification.left)]);
        final toilet = armable(rig.c, 'bath.toilet');
        await rig.arm(toilet);
        final p = nearFace(rig.runOn(FaceSide.left));
        final want = rig.attachOf(toilet, p)!;
        final ghost = await rig.ghostAt(p);
        await rig.click(p);
        final t = rig.instances.single.transform;
        if (on) {
          expect(partsOf(ghost), partsOf(want.transform));
          expect(partsOf(t), partsOf(want.transform));
        } else {
          expect(partsOf(ghost), partsOf(rig.freeOf(toilet, p)));
          expect(partsOf(t), partsOf(rig.freeOf(toilet, p)));
        }
      }
    });

    // Not ported (C7, premise impossible): 'a tool given no wall faces never
    // attaches (09b's behaviour)' (:1496-1506), its premise a tool built
    // without faces; plan.symbol always has the registry.
    // Not ported (ruling IA-R4): expect(rig.tool.faces, isNull) (:1499).

    testWidgets(
        'M while attached mirrors in place: the footprint stays, the '
        'transform is the mirrored attachment (M-09c-j)', (tester) async {
      for (final (deg, j, side) in attachCases) {
        final rig = await Rig.mount(tester, walls: [attachWall(deg, j)]);
        final toilet = armable(rig.c, 'bath.toilet');
        await rig.arm(toilet);
        final p = nearFace(rig.runOn(side));
        await rig.rest(p);
        final p0 = rig.resting();
        expect(partsOf(p0), partsOf(rig.attachOf(toilet, p)!.transform));
        // The ghost's commit at the pointer is the same (IA-R4).
        expect(partsOf(await rig.ghostAt(p)), partsOf(p0));
        await rig.key(LogicalKeyboardKey.keyM);
        // Not ported (ruling IA-R4): expect(rig.notifications, [false],
        // reason: '$deg°: one repaint').
        // Read with no pointer event: the key itself re-asked the faces.
        final p1 = rig.resting();
        final want = rig.attachOf(toilet, p, mirrored: true)!;
        expect(partsOf(p1), partsOf(want.transform), reason: '$deg°');
        expect(p0.a * p0.d - p0.b * p0.c, greaterThan(0));
        expect(p1.a * p1.d - p1.b * p1.c, lessThan(0),
            reason: '$deg°: mirrored');
        // The same four corners, the mirror swapping left and right.
        final box = boxOfEntry(toilet.entry)!;
        final f0 = footprint(box, p0), f1 = footprint(box, p1);
        for (final (i, k) in [(0, 1), (1, 0), (2, 3), (3, 2)]) {
          expect(f1[i].distanceTo(f0[k]), lessThan(1e-6),
              reason: '$deg°: corner $i in place');
        }
        await rig.click(p);
        expect(partsOf(rig.instances.single.transform), partsOf(want.transform),
            reason: '$deg°: placed mirrored');
        await rig.key(LogicalKeyboardKey.keyM);
        expect(partsOf(rig.resting()), partsOf(p0), reason: '$deg°: M again');
      }
    });

    testWidgets(
        'R and Shift+R while attached change the turn count only: the ghost '
        'does not turn; off the face the count applies (M-09c-k)',
        (tester) async {
      final rig = await Rig.mount(tester,
          walls: [attachWall(-112.5, Justification.right)]);
      final toilet = armable(rig.c, 'bath.toilet');
      await rig.arm(toilet);
      final run = rig.runOn(FaceSide.right);
      final p = nearFace(run);
      final pA = away(run);
      await rig.rest(p);
      final p0 = partsOf(rig.resting());
      await rig.key(LogicalKeyboardKey.keyR);
      // `rig.tool.quarterTurns` (1): read off the face, where the count
      // applies, as the commit there (IA-R4).
      expect(partsOf(rig.resting()), p0, reason: 'R');
      expect(partsOf(await rig.ghostAt(pA)),
          partsOf(rig.freeOf(toilet, pA, turns: 1)),
          reason: 'quarterTurns 1');
      await rig.rest(p);
      await rig.key(LogicalKeyboardKey.keyR);
      await rig.key(LogicalKeyboardKey.keyR);
      await rig.shiftR();
      expect(partsOf(rig.resting()), p0, reason: 'R, R, Shift+R');
      expect(partsOf(await rig.ghostAt(pA)),
          partsOf(rig.freeOf(toilet, pA, turns: 2)),
          reason: 'quarterTurns 2');
      await rig.click(p);
      expect(partsOf(rig.instances.single.transform), p0,
          reason: 'placed unturned');
      // Off the face: the two quarter turns apply.
      await rig.rest(pA);
      expect(rig.marker(), isNull);
      expect(partsOf(rig.resting()), partsOf(rig.freeOf(toilet, pA, turns: 2)));
      await rig.click(pA);
      expectAt(rig.placedAt(rig.instances.last), gridOf(rig.worldOf(pA)),
          'free at the grid');
    });

    testWidgets(
        'the marker is the nearest glyph at the face point q, not at the '
        'raw or the resolved point', (tester) async {
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final toilet = armable(rig.c, 'bath.toilet');
      await rig.arm(toilet);
      final p = nearFace(rig.runOn(FaceSide.left));
      await rig.rest(p);
      // `rig.tool.ghostAttachment!.q`: the provider's marker, the ghost the
      // resting pointer shows being that attachment.
      final want = rig.attachOf(toilet, p)!;
      expect(partsOf(rig.resting()), partsOf(want.transform),
          reason: 'premise: attached');
      final q = want.marker;
      // `rig.tool.paintOverlay(canvas, ...)`: the canvas's own call
      // (`Tool.paintOverlay`, through the plan's guard) on the drawing
      // area's size.
      final canvas = overlayOf(tester, rig.c);
      expect(canvas.named('drawRect'), isEmpty);
      final lines = canvas.named('drawLine').toList();
      expect(lines, hasLength(4), reason: 'the hourglass');
      final ends = [
        for (final l in lines) ...[
          l.positionalArguments[0] as Offset,
          l.positionalArguments[1] as Offset
        ]
      ];
      final cx = ends.map((o) => o.dx).reduce((a, b) => a + b) / 8;
      final cy = ends.map((o) => o.dy).reduce((a, b) => a + b) / 8;
      final sq = rig.c.camera.value.worldToScreen(q);
      expect(cx, closeTo(sq.x, 1e-9));
      expect(cy, closeTo(sq.y, 1e-9));
      // The glyph: top and bottom edges, then the two diagonals.
      const h = kSnapMarkerPixels / 2;
      for (final (o, dx, dy) in [
        (ends[0], -h, -h),
        (ends[1], h, -h),
        (ends[3], -h, h),
        (ends[4], -h, h),
        (ends[5], h, h),
        (ends[7], -h, -h),
      ]) {
        expect(o.dx, closeTo(sq.x + dx, 1e-9));
        expect(o.dy, closeTo(sq.y + dy, 1e-9));
      }
      for (final w in [rig.worldOf(p), gridOf(rig.worldOf(p))]) {
        final sw = rig.c.camera.value.worldToScreen(w);
        expect(sw.distanceTo(sq), greaterThan(5),
            reason: 'q is not the raw or the resolved point');
      }
    });

    testWidgets(
        'a camera zoom that brings the face within capture attaches the '
        'resting ghost (M-09c-ak)', (tester) async {
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final toilet = armable(rig.c, 'bath.toilet');
      await rig.arm(toilet);
      final run = rig.runOn(FaceSide.left);
      // 400 mm off the face: outside 320 mm, inside 640 mm.
      final p = onRun(run, run.length * 0.37, 400);
      final g = globalAt(tester, rig.c, p);
      await rig.restAt(g);
      expect(rig.marker(), isNull, reason: 'premise: too far');
      expect(partsOf(rig.resting()), partsOf(rig.freeOf(toilet, p)),
          reason: 'premise: too far');
      final s = g - tester.getTopLeft(find.byType(InteractionLayer));
      // Not ported (ruling IA-R4): rig.notifications.clear() and
      // expect(rig.notifications, [false]).
      rig.c.camera.zoomAt(s, 0.5);
      await tester.pump();
      final k = rig.c.camera.value.scale;
      expect(k, closeTo(scale / 2, 1e-15));
      final w = rig.c.camera.value.screenToWorld(Vector2(s.dx, s.dy));
      final want = rig.attachAt(toilet, w, k: k)!;
      // Read with no pointer event: the camera change alone re-resolved.
      final m = rig.marker();
      expect(m, isNotNull);
      expect((m! - rig.screen(want.marker)).distance, lessThan(1e-6));
      expect(partsOf(rig.resting()), partsOf(want.transform));
      // And back out: free again.
      rig.c.camera.zoomAt(s, 2);
      await tester.pump();
      expect(rig.marker(), isNull);
      final back = rig.c.camera.value.screenToWorld(Vector2(s.dx, s.dy));
      final free = placementTransform(
          at: gridOf(back), basePoint: toilet.entry.definition.basePoint);
      expect(partsOf(rig.resting()), partsOf(free));
      // The commit at the same pointer agrees (IA-R4).
      expect(partsOf(await rig.ghostAtGlobal(g)), partsOf(free));
    });

    testWidgets(
        'a re-arm between a tagged and an untagged entry while the ghost '
        'rests near a face switches the attachment on and off', (tester) async {
      final rig = await Rig.mount(tester,
          walls: [attachWall(-112.5, Justification.right)]);
      final toilet = armable(rig.c, 'bath.toilet');
      final island = armable(rig.c, 'kitchen.island');
      await rig.arm(island);
      final p = nearFace(rig.runOn(FaceSide.right));
      await rig.rest(p);
      expect(rig.marker(), isNull, reason: 'the island: free');
      final w = rig.worldOf(p);
      // Each re-arm read with no pointer event: the re-arm re-resolved.
      await rig.arm(toilet);
      final want = rig.attachAt(toilet, w)!;
      final m = rig.marker();
      expect(m, isNotNull, reason: 'the toilet');
      expect((m! - rig.screen(want.marker)).distance, lessThan(1e-6),
          reason: 'the toilet');
      expect(partsOf(rig.resting()), partsOf(want.transform));
      await rig.arm(island);
      expect(rig.marker(), isNull, reason: 'the island again');
      expect(partsOf(rig.resting()), partsOf(rig.freeOf(island, p)));
      // Hidden (no context to re-resolve with), a re-arm still drops the
      // tagged entry's attachment: the stored placement is the new entry's.
      await rig.arm(toilet);
      expect(rig.marker(), isNotNull);
      await rig.restAt(tester.getTopLeft(find.byType(InteractionLayer)) -
          const Offset(4, 4));
      expect(restingPlacement(tester, rig.c), isNull,
          reason: 'premise: the ghost hidden');
      await rig.arm(island);
      // Not ported (IA-R4: the read needs a pointer event, which
      // re-resolves): expect(rig.tool.ghostAttachment, isNull, reason:
      // 'hidden re-arm') and expect(partsOf(rig.tool.ghostPlacement!),
      // partsOf(rig.freeOf(island)), reason: 'hidden re-arm'). A hidden
      // ghost draws nothing, and bringing the pointer back re-resolves.
    });

    testWidgets(
        'W-5: a unit placed right after another along the face snaps to it '
        'before the change stream delivers; one undo step each (M-09c-ap)',
        (tester) async {
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final base600 = armable(rig.c, 'kitchen.base.600');
      await rig.arm(base600);
      final run = rig.runOn(FaceSide.left);
      final box = boxOfEntry(base600.entry)!;
      final p1 = onRun(run, 1000, 200);
      await rig.click(p1);
      final first = rig.instances.single.transform;
      expect((first.transformPoint(box.backCentre) - run.a).dot(run.t),
          closeTo(1000, 1e-6));
      // A second unit 120 mm (inside the 200 mm edge capture) to the right
      // of the first's right side, mirrored and turned.
      await rig.key(LogicalKeyboardKey.keyM);
      await rig.key(LogicalKeyboardKey.keyR);
      // Not ported (IA-R4: the kit's bands are the plan's services' own,
      // no public read): final gen = bands.generation. The kit pins the
      // before-delivery path (D-06's stateId) in wall_face_provider_test.dart.
      // 250 mm: outside the edge capture (10 px), inside the attach capture
      // (16 px): attached, not snapped.
      final beyond = await rig.ghostAt(onRun(run, 1000 + 600 + 250, 150));
      expect((beyond.transformPoint(box.backCentre) - run.a).dot(run.t),
          closeTo(1850, 1e-6),
          reason: 'beyond the edge capture: not snapped');
      final p2 = onRun(run, 1000 + 600 + 120, 150);
      final second = await rig.ghostAt(p2);
      // Not ported (as above): expect(bands.generation, gen, reason: 'no
      // change delivered meanwhile').
      expect((second.transformPoint(box.backCentre) - run.a).dot(run.t),
          closeTo(1600, 1e-6),
          reason: 'its left side on the first\'s right side');
      await rig.click(p2);
      expect(rig.instances, hasLength(2));
      expect(partsOf(rig.instances.last.transform), partsOf(second));
      expect(rig.document.commands.undoDepth, 2);
      rig.document.commands.undo();
      expect(partsOf(rig.instances.single.transform), partsOf(first),
          reason: 'one undo step took the second only');
      rig.document.commands.undo();
      expect(rig.instances, isEmpty);
    });

    testWidgets(
        'an attached placement refused by the permissions allocates nothing; '
        'lifted, it places the attached transform', (tester) async {
      final rig =
          await Rig.mount(tester, walls: [attachWall(30, Justification.left)]);
      final toilet = armable(rig.c, 'bath.toilet');
      await rig.arm(toilet);
      final p = nearFace(rig.runOn(FaceSide.left));
      rig.document.commands.permissions = const DraftPermissions(
          transform: true, components: true, geometry: true, structure: false);
      final seed = rig.document.handleSeed.current;
      // Not ported (IA-R4: no public read of the kit's bands): final gen =
      // rig.bands!.generation.
      await rig.click(p);
      // `rig.tool.ghostAttachment` isNotNull, read on the resting ghost.
      final want = rig.attachOf(toilet, p);
      expect(want, isNotNull, reason: 'premise');
      final m = rig.marker();
      expect(m, isNotNull, reason: 'premise');
      expect((m! - rig.screen(want!.marker)).distance, lessThan(1e-6),
          reason: 'premise');
      expect(rig.document.handleSeed.current, seed);
      expect(rig.instances, isEmpty);
      // Not ported (as above): expect(rig.bands!.generation, gen, reason:
      // 'nothing to see').
      rig.document.commands.permissions = DraftPermissions.all;
      await rig.click(p);
      expect(partsOf(rig.instances.single.transform),
          partsOf(rig.attachOf(toilet, p)!.transform));
    });
  });
}
