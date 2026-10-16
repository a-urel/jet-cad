// Spec 09c D6 (plan 09c-1 Task 7): the shell's wall faces. The walls are
// added straight through the document's commands (no Wall or Opening tool
// ever runs, W-5), each in its own rotated group near (1e5, −7e4) at 30°
// (`wall_attach_fixture.dart`, plan P-2); the expected placements are
// `attachToWall` over the wall's own runs from the raw pointer the layer
// computes.
//
// Ported to jet_cad_2d_integration (3a Task 28, D-04; rulings IA-R1,
// IA-R4, IA-R5) from apps/floor_planner/test/symbols/symbol_shell_test.dart,
// SS16 and SS17 (:620-730): the app is `PlanEditor` over
// `architectureController` whose plan file holds today's `addAttachWall`
// wall (`attachPlan` of one 30° wall, its group the handle's, as today's
// handle 7's), the camera today's `aimCamera` on `c.camera`; the symbols
// are the kit's (`architecture.*`, C7 class 1), armed through the gallery.
// The oracle is the kit's provider through the contract (IA-R1); the run
// is written here (`faceLineOf`). A ghost read (`tool.ghostAttachment`) is
// the placement a click at that pointer commits (IA-R4), read and undone:
// attached is the back-centre on the face line, turned to it.
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_plans.dart';
import '../support/canvas_rig.dart' show globalAt, pumpPlanEditor, symbolsReady;
import '../support/plans.dart' show polar, walls;
import '../support/room_plans.dart' show undoKey;

/// Today's `addAttachWall`: a wall at 30°, 3600 long and 150 thick,
/// justified left, in its own rotated group near (1e5, −7e4) (no tool
/// runs), as the plan file [c] opens, the editor pumped, the furniture
/// loaded and the camera aimed at it. Returns the wall and its left face.
Future<(PlanController, Handle, FaceLine)> addAttachWall(
    WidgetTester tester) async {
  final s = farAt(1234.5, 678.25);
  final plan = attachPlan([(s, polar(s, 30, 3600), 150, Justification.left)]);
  final c = architectureController(json: plan.json);
  addTearDown(c.dispose);
  await pumpPlanEditor(tester, c);
  expect(await symbolsReady(tester, c), isTrue,
      reason: 'premise: the furniture library loaded');
  await aimCamera(tester, c, polar(s, 30, 1800));
  final h = plan.walls.single;
  return (c, h, faceLineOf(c.document, h, left: true));
}

void main() {
  group('the wall attachment (spec 09c D6)', () {
    testWidgets(
        'SS16 a fresh shell where no Wall or Opening tool ran: a base unit '
        'attaches to a 30° face, a second placed after it snaps to its '
        'side; one undo step each (W-5)', (tester) async {
      final (c, wall, run) = await addAttachWall(tester);
      final doc = c.document;
      final unit = armable(c, 'kitchen.base.600');
      await armBySymbolsTab(tester, c, unit);
      final box = boxOfEntry(unit.entry)!;
      final scale = c.camera.value.scale;
      expect(scale, closeTo(0.1, 1e-12), reason: 'capture 160 mm, edge 100');
      final depth = doc.commands.undoDepth;

      Future<void> click(Vector2 p) async {
        final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
        await mouse.down(globalAt(tester, c, p));
        await tester.pump();
        await mouse.up();
        await mouse.removePointer();
        await tester.pump();
      }

      final p1 = onRun(run, 1000, 120);
      final want1 = answerAt(c, unit, rawWorldAt(tester, c, p1))!;
      await click(p1);
      final first = instancesOf(doc).single;
      expect(partsOf(first.transform), partsOf(want1.transform));
      expect(doc.commands.undoDepth, depth + 1);

      // 60 mm (inside the 100 mm edge capture) right of the first's side.
      final p2 = onRun(run, 1000 + 600 + 60, 90);
      // The answer the release finds: the first unit its neighbour.
      final want2 = answerAt(c, unit, rawWorldAt(tester, c, p2));
      await click(p2);
      final second = instancesOf(doc).last;
      expect(instancesOf(doc), hasLength(2));
      final q2 = second.transform.transformPoint(box.backCentre);
      expect((q2 - run.a).dot(run.t), closeTo(1600, 1e-6),
          reason: 'its left side on the first\'s right side');
      expect((q2 - run.a).dot(run.m), closeTo(0, 1e-6), reason: 'on the face');
      // `tool.ghostAttachment` (IA-R4): the answer the release used.
      expect(want2, isNotNull);
      expect(partsOf(second.transform), partsOf(want2!.transform));
      expect(doc.commands.undoDepth, depth + 2);

      await undoKey(tester);
      expect(instancesOf(doc).single.handle, first.handle,
          reason: 'one undo step took the second only');
      await undoKey(tester);
      expect(instancesOf(doc), isEmpty);
      expect(walls(doc), [wall]);
    });

    testWidgets(
        'SS17 a wall on a hidden or a locked layer hosts nothing: the shell '
        'hands its faces the openings\' host rule (M-09c-e)', (tester) async {
      final (c, wall, run) = await addAttachWall(tester);
      final doc = c.document;
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      Handle layer(String name, {bool visible = true, bool locked = false}) {
        final h = doc.handleSeed.next();
        doc.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(3),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: visible,
          locked: locked,
        )));
        return h;
      }

      final hidden = layer('Hidden', visible: false);
      final locked = layer('Locked', locked: true);
      final open = layer('Open');
      final toilet = armable(c, 'bath.toilet');
      await armBySymbolsTab(tester, c, toilet);
      final box = boxOfEntry(toilet.entry)!;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
          location: globalAt(tester, c, onRun(run, 900, 80)));
      addTearDown(mouse.removePointer);
      for (final (i, (on, hosts)) in [
        (hidden, false),
        (locked, false),
        (open, true),
      ].indexed) {
        doc.commands
            .execute(SetComponentCommand<ObjectLayer>(wall, ObjectLayer(on)));
        await tester.pump();
        final why = doc.tables.layers[on]!.name;
        // `isUsableHost(doc, wall)` is the kit's (not exported): the
        // wall's layer is visible and unlocked.
        final l = doc.tables.layers[on]!;
        expect(l.visible && !l.locked, hosts, reason: 'premise: $why');
        final p = onRun(run, 1100 + 250.0 * i, 80);
        await mouse.moveTo(globalAt(tester, c, p));
        await tester.pump();
        // `tool.ghostVisible` and `tool.ghostAttachment != null` (IA-R4):
        // the placement a click at the resting pointer commits, undone.
        final depth = doc.commands.undoDepth;
        final want = answerAt(c, toilet, rawWorldAt(tester, c, p));
        await mouse.down(globalAt(tester, c, p));
        await tester.pump();
        await mouse.up();
        await tester.pump();
        expect(doc.commands.undoDepth, depth + 1, reason: '$why: placed');
        final placed = instancesOf(doc).last.transform;
        final back = placed.transformPoint(box.backCentre);
        final attached = (back - run.a).dot(run.m).abs() < 1e-6 &&
            (placed.c + run.m.x).abs() < 1e-12 &&
            (placed.d + run.m.y).abs() < 1e-12;
        expect(attached, hosts, reason: why);
        if (hosts) expect(partsOf(placed), partsOf(want!.transform));
        c.undo();
        await tester.pump();
      }
    });
  });
}
