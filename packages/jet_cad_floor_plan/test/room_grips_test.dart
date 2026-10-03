// Spec 10 D21: a room's label grip, a separator's end grips, and no
// select-tool move or rotate for a room (R-22). The label grip sits at the
// labels' anchor, `toWorld(q) − (0, 0.7 · h_name_w)` from the name TEXT's
// stored insertion point `q`; a drag stores `label = toLocal(p) − pole_l`,
// the pole `pole_l = toLocal(anchor_w) − label`; a drop within the snap
// aperture of the pole stores null (auto, R-26), whatever F3 says (Ruling
// 10-17). A separator's end grip moves one end through `trimSeparator`.
//
// The plan is the two-room rectangle (`twoRoomWalls`) with a separator
// face to face at x = 6,250.5, at the origin and at the corpus far origin
// with every wall and the separator in its own rotated, translated group.
// The Kitchen has a fractional, non-null label offset and a name that is
// not `Room N`; `GR6` puts it in a group turned 23°, at the far origin,
// scaled 1.5. Anchors come from the stored TEXTs by D21's formula
// (`anchorOf`), never from the grip code; expected areas are hand
// arithmetic, each label at least 0.0005 m² from a rounding tie.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/parametric/object_grips.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_inputs.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_trace.dart';
import 'package:jet_cad_floor_plan/src/parametric/separator.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

/// The Kitchen's stored label offset, local: fractional, non-null.
const (double, double) kitchenLabel = (-310.37, 145.61);

/// The plan's separator, face to face between the partition and the east
/// wall.
const S sep = (6250.5, 100, 6250.5, 3900);

/// The grips' plan.
typedef Fx = ({
  Plan plan,
  Handle kitchen,
  Handle b,
  Handle sep,
  Handle part,
});

/// [twoRoomWalls] and [sep] at [place], a 1:50 page in metres with no grid
/// snap (so a shell drop is the pointer's own point), and two rooms:
///
/// - the Kitchen, seeded at (1,500.25, 2,000.5) in the left face (x
///   100..2,950, y 100..3,900: 2,850 × 3,800 = 10,830,000 mm², "10.83 m²"),
///   its label offset [kitchenLabel], in its own group [kitchenAt] (the
///   identity by default);
/// - B, `Room 2`, auto, seeded at (4,700.75, 1,900.25) between the partition
///   and the separator (x 3,050..6,250.5: 3,200.5 × 3,800 = 12,161,900 mm²,
///   "12.16 m²").
///
/// With [shell], the plan's own system is disposed and the history
/// cleared: the shell installs one over the finished document.
Fx gripPlan(Placement place,
    {TextMeasurer measurer = const InsertionPointMeasurer(),
    Transform2? kitchenAt,
    bool shell = false}) {
  final plan = buildPlan(twoRoomWalls,
      seps: const [sep], place: place, measurer: measurer);
  attachPage(plan.doc, PageComponent(snapToGrid: false));
  final kitchen = addRoom(plan.doc, plan.at(1500.25, 2000.5), 'Kitchen',
      label: kitchenLabel, at: kitchenAt);
  final b = addRoom(plan.doc, plan.at(4700.75, 1900.25), 'Room 2');
  expect(labelStrings(plan.doc, kitchen), ['Kitchen', '10.83 m²'],
      reason: 'premise, $place');
  expect(labelStrings(plan.doc, b), ['Room 2', '12.16 m²'],
      reason: 'premise, $place');
  if (shell) plan.system.dispose();
  plan.doc.commands.clearHistory();
  return (
    plan: plan,
    kitchen: kitchen,
    b: b,
    sep: plan.seps.single,
    part: plan.walls[4],
  );
}

RoomParams roomOf(DraftDocument doc, Handle h) =>
    doc.components.get<RoomParams>(h)!;

SeparatorParams sepOf(DraftDocument doc, Handle h) =>
    doc.components.get<SeparatorParams>(h)!;

/// [room]'s area TEXT's world insertion point raised by `0.7 · h_area_w`:
/// the anchor again, from the other label (D10).
Vector2 anchorFromArea(DraftDocument doc, Handle room) {
  final c = payloadOf(doc, labelsOf(doc, room)[1]).coords;
  final q =
      doc.tree.accumulatedTransform(room).transformPoint(Vector2(c[0], c[1]));
  return q + Vector2(0, 0.7 * 2.0 * pageOf(doc).scaleDenominator);
}

/// D21's pole, local, from a grip at [anchorW] and the stored offset.
Vector2 poleLocal(DraftDocument doc, Handle room, Vector2 anchorW) {
  final toLocal = doc.tree.accumulatedTransform(room).invert();
  final l = roomOf(doc, room).label;
  return toLocal.transformPoint(anchorW) -
      (l == null ? Vector2.zero() : Vector2(l.$1, l.$2));
}

/// D21's stored offset for a drop at [p]: `toLocal(p) − pole_l`.
(double, double) labelFor(
    DraftDocument doc, Handle room, Vector2 anchorW, Vector2 p) {
  final toLocal = doc.tree.accumulatedTransform(room).invert();
  final l = toLocal.transformPoint(p) - poleLocal(doc, room, anchorW);
  return (l.x, l.y);
}

/// The line [preview] holds, as its two world points.
(Vector2, Vector2) lineOf(List<(EntityKind, GeometryPayload)> preview) {
  final (kind, payload) = preview.single;
  expect(kind, EntityKind.line);
  final c = payload.coords;
  return (Vector2(c[0], c[1]), Vector2(c[2], c[3]));
}

/// The distance from [p] to the line through [a] and [b], relative to [a].
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a, q = p - a;
  return (q.x * d.y - q.y * d.x).abs() / d.length;
}

// ---------------------------------------------------------------------------
// The shell, as `opening_grips_test.dart` drives it.

/// The camera's scale in pixels per mm: the snap aperture is ~67 mm.
const double _scale = 0.15;

/// Pumps the shell over [f], then sets a rotated, non-reflecting camera
/// centred on [centre].
Future<PlannerView> pumpShell(WidgetTester tester, Fx f, Vector2 centre) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: PlannerShell(document: f.plan.doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, Vector2 p) {
  final s = view.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> tapWorld(WidgetTester tester, PlannerView view, Vector2 p) async {
  await tester.tapAt(globalOf(tester, view, p));
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(
    WidgetTester tester, PlannerView view, Vector2 from, Vector2 to) async {
  final a = globalOf(tester, view, from), b = globalOf(tester, view, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
  await tester.pump();
}

Future<void> toggleF3(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.f3);
  await tester.pump();
}

String osnap(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;

/// The shown object grips of [h].
List<Grip> objectGripsOf(PlannerView view, Handle h) => [
      for (final r in view.grips.grips)
        if (r.object && r.key == k(h)) r.grip,
    ];

Vector2 at(Grip g) => Vector2(g.x, g.y);

void main() {
  test(
      'GR1 the label grip sits at the anchor, and a drag stores the offset in '
      'one undo step', () {
    for (final place in [origin, corpusGroups]) {
      final f = gripPlan(place);
      final doc = f.plan.doc;
      const ap = 40.0;
      final objects =
          ObjectGrips(edgeAperture: () => null, labelAperture: () => ap);

      // The grip, at the anchor by D21's formula, which the area label
      // agrees with; B's, auto, at its pole: the rectangle's centre line,
      // x (3,050 + 6,250.5) / 2 = 4,650.25, y within 1,700.25..2,299.75
      // (the inscribed circle, radius 1,600.25, is free to slide), to the
      // pole's 10 mm precision.
      final g = objects.gripsOf(doc, f.kitchen).single;
      expect(g.role, GripRole.stretch, reason: '$place');
      final anchor = anchorOf(doc, f.kitchen);
      expect((at(g) - anchor).length, lessThan(1e-6),
          reason: '$place: at the anchor');
      expect((anchorFromArea(doc, f.kitchen) - anchor).length, lessThan(1e-6),
          reason: '$place: the area label agrees');
      final gb = objects.gripsOf(doc, f.b).single;
      final bPlan = place.m.invert().transformPoint(at(gb));
      expect(bPlan.x, closeTo(4650.25, 10), reason: '$place: B at its pole');
      expect(bPlan.y, inInclusiveRange(1700.25 - 10, 2299.75 + 10),
          reason: '$place: B at its pole');

      // A drag to a fractional point stores `toLocal(p) − pole_l` exactly,
      // the pole the anchor less the stored offset; the preview runs from
      // the pole to the would-be anchor.
      final p = f.plan.at(1900.37, 2600.81);
      final pole = doc.tree
          .accumulatedTransform(f.kitchen)
          .transformPoint(poleLocal(doc, f.kitchen, at(g)));
      expect((pole - p).length, greaterThan(ap), reason: 'premise');
      final (from, to) = lineOf(objects.preview(doc, f.kitchen, g, p));
      expect((from - pole).length, lessThan(1e-6), reason: '$place: the pole');
      expect((to - p).length, lessThan(1e-6), reason: '$place: to the drop');
      final before = roomOf(doc, f.kitchen);
      final beforeAnchor = anchorOf(doc, f.kitchen);
      final want = labelFor(doc, f.kitchen, at(g), p);
      final depth = doc.commands.undoDepth;
      doc.commands.execute(objects.drag(doc, f.kitchen, g, p)!);
      expect(doc.commands.undoDepth, depth + 1, reason: '$place: one step');
      expect(roomOf(doc, f.kitchen),
          RoomParams(before.seedX, before.seedY, 'Kitchen', label: want),
          reason: '$place: the offset, exactly');
      expect(want, isNot(before.label));
      expect((anchorOf(doc, f.kitchen) - p).length, lessThan(1e-6),
          reason: '$place: the labels moved there');
      expect(labelStrings(doc, f.kitchen), ['Kitchen', '10.83 m²']);
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(roomOf(doc, f.kitchen), before, reason: '$place: undone');
      final back = anchorOf(doc, f.kitchen);
      expect((back.x, back.y), (beforeAnchor.x, beforeAnchor.y),
          reason: '$place: the labels back, exactly');

      // A drop on the grip, and B's auto label dropped near its pole,
      // store what is stored: nothing.
      expect(objects.drag(doc, f.kitchen, g, at(g)), isNull,
          reason: '$place: on the grip');
      final near = at(gb) + Vector2(0.6 * ap, -0.5 * ap);
      expect(objects.drag(doc, f.b, gb, near), isNull,
          reason: '$place: auto stays auto');
      expect(objects.preview(doc, f.b, gb, near), isEmpty,
          reason: '$place: no line back to the pole');
      expect(doc.commands.undoDepth, depth);

      // A room whose area TEXT sits in a lower slot than its name: four
      // lines deleted in one step leave four free slots, reused last in,
      // first out. The grip reads the name, the first TEXT in handle order.
      final lines = <Handle>[];
      for (var i = 0; i < 4; i++) {
        final h = doc.handleSeed.next();
        doc.commands.execute(AddEntityCommand(
            record: draftRecord(h, doc.rootHandle, EntityKind.line,
                layer: ReservedHandles.layerZero),
            payload: linePayload(f.plan.at(-2000.25 + 300 * i, -3000.5),
                f.plan.at(-1500.75, -2700.25))));
        lines.add(h);
      }
      doc.commands.execute(CompoundCommand(
          [for (final h in lines) RemoveEntityCommand(h)],
          label: 'Delete'));
      final store = addRoom(doc, f.plan.at(7000.25, 2000.5), 'Store');
      final [sName, sArea] = labelsOf(doc, store);
      expect(doc.entities.slotOf(sArea)!, lessThan(doc.entities.slotOf(sName)!),
          reason: 'premise: the area TEXT sits in the lower slot, $place');
      final gs = objects.gripsOf(doc, store).single;
      expect((at(gs) - anchorOf(doc, store)).length, lessThan(1e-6),
          reason: '$place: the anchor read from the name');

      // A non-default page, ft-in at 1:100 (Task 17's review): the name's
      // world height is 2.5 mm × 100 = 250, so the grip, which takes
      // 0.7 · h_name_w off in world, reads the root's page, not the app's
      // opening page. 10,830,000 / 92,903.04 = 116.5737… ("116.57 ft²",
      // 0.0013 from a tie).
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle,
          pageOf(doc).copyWith(
              displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
      expect(labelStrings(doc, f.kitchen), ['Kitchen', '116.57 ft²'],
          reason: '$place: premise, the page');
      final g100 = objects.gripsOf(doc, f.kitchen).single;
      expect((at(g100) - anchorOf(doc, f.kitchen)).length, lessThan(1e-6),
          reason: '$place: at the anchor at 1:100');
      final p100 = f.plan.at(1100.29, 1400.67);
      expect((p100 - at(g100)).length, greaterThan(3 * ap), reason: 'premise');
      doc.commands.execute(objects.drag(doc, f.kitchen, g100, p100)!);
      expect((anchorOf(doc, f.kitchen) - p100).length, lessThan(1e-6),
          reason: '$place: the labels moved there at 1:100');
      expect(driftOf(doc), isEmpty);
    }
  });

  for (final place in [origin, corpusGroups]) {
    testWidgets(
        'GR1 (shell) the label grip is shown at the anchor and a drag stores '
        'the offset in one undo step, $place', (tester) async {
      final f = gripPlan(place, measurer: FlutterTextMeasurer(), shell: true);
      final doc = f.plan.doc;
      final view = await pumpShell(tester, f, f.plan.at(1500, 2000));
      view.selection.replace([k(f.kitchen)]);
      await tester.pump();
      final g = objectGripsOf(view, f.kitchen).single;
      expect((at(g) - anchorOf(doc, f.kitchen)).length, lessThan(1e-6));
      final before = roomOf(doc, f.kitchen);
      final p = f.plan.at(1900.37, 2600.81);
      final want = labelFor(doc, f.kitchen, at(g), p);
      await dragWorld(tester, view, at(g), p);
      expect(doc.commands.undoDepth, 1, reason: 'one undo step');
      final got = roomOf(doc, f.kitchen).label!;
      expect(got.$1, closeTo(want.$1, 1e-6));
      expect(got.$2, closeTo(want.$2, 1e-6));
      expect((anchorOf(doc, f.kitchen) - p).length, lessThan(1e-6));
      await undoKey(tester);
      expect(roomOf(doc, f.kitchen), before, reason: 'undone, exactly');
    });

    testWidgets(
        'GR2 a drop within the aperture of the pole returns the label to '
        'auto, with object snap on and off, $place', (tester) async {
      final f = gripPlan(place, measurer: FlutterTextMeasurer(), shell: true);
      final doc = f.plan.doc;
      final view = await pumpShell(tester, f, f.plan.at(1500, 2000));
      view.selection.replace([k(f.kitchen)]);
      await tester.pump();
      final before = roomOf(doc, f.kitchen);
      final ap = kSnapAperturePixels / view.camera.value.scale;
      expect(ap, closeTo(66.67, 0.01), reason: 'premise');
      final g0 = objectGripsOf(view, f.kitchen).single;
      final pole = doc.tree
          .accumulatedTransform(f.kitchen)
          .transformPoint(poleLocal(doc, f.kitchen, at(g0)));
      expect((pole - at(g0)).length, greaterThan(3 * ap),
          reason: 'premise: the stored offset is well outside the aperture');

      for (final snap in [true, false]) {
        expect(osnap(tester), snap ? 'OSNAP' : 'osnap off');
        final g = objectGripsOf(view, f.kitchen).single;
        await dragWorld(
            tester, view, at(g), pole + Vector2(0.4 * ap, -0.3 * ap));
        expect(doc.commands.undoDepth, 1, reason: 'F3 $snap: one step');
        expect(roomOf(doc, f.kitchen).label, isNull,
            reason: 'F3 $snap: auto (Ruling 10-17)');
        expect(roomOf(doc, f.kitchen).name, 'Kitchen');
        expect((anchorOf(doc, f.kitchen) - pole).length, lessThan(1e-6),
            reason: 'F3 $snap: the labels at the pole');
        expect(driftOf(doc), isEmpty);
        await undoKey(tester);
        expect(roomOf(doc, f.kitchen), before, reason: 'F3 $snap: undone');
        if (snap) await toggleF3(tester);
      }

      // The control: 1.5 apertures from the pole stores an offset.
      final g = objectGripsOf(view, f.kitchen).single;
      final out = pole + Vector2(1.5 * ap, 0);
      final want = labelFor(doc, f.kitchen, at(g), out);
      await dragWorld(tester, view, at(g), out);
      expect(doc.commands.undoDepth, 1);
      final got = roomOf(doc, f.kitchen).label!;
      expect(got.$1, closeTo(want.$1, 1e-6));
      expect(got.$2, closeTo(want.$2, 1e-6));
    });
  }

  testWidgets('GR3 the label grip is not hit under runtime permissions',
      (tester) async {
    final f =
        gripPlan(corpusGroups, measurer: FlutterTextMeasurer(), shell: true);
    final doc = f.plan.doc;
    final view = await pumpShell(tester, f, f.plan.at(1500, 2000));
    view.selection.replace([k(f.kitchen)]);
    await tester.pump();
    final g = objectGripsOf(view, f.kitchen).single;
    final m = view.camera.value.worldToScreenMatrix;
    final s = view.camera.value.worldToScreen(at(g));
    expect(view.grips.hitTest(Offset(s.x, s.y), m), isNot(-1),
        reason: 'the control: hit under full permissions');
    doc.commands.permissions = DraftPermissions.runtime;
    expect(view.grips.hitTest(Offset(s.x, s.y), m), -1);
    final before = enc(doc);
    await dragWorld(tester, view, at(g), f.plan.at(1900.37, 2600.81));
    expect(enc(doc), before, reason: 'nothing moved');
  });

  for (final place in [origin, corpusGroups]) {
    testWidgets(
        'GR4 a body drag on a selected room moves nothing; rooms alone have '
        'no rotation grip; a wall selected with a room moves and the room '
        're-traces, $place', (tester) async {
      final f = gripPlan(place, measurer: FlutterTextMeasurer(), shell: true);
      final doc = f.plan.doc;
      final view = await pumpShell(tester, f, f.plan.at(3000, 2000));

      // The Kitchen alone, selected by a click on its name label.
      final name = anchorOf(doc, f.kitchen) + Vector2(0, 0.7 * 125);
      await tapWorld(tester, view, name);
      expect(view.selection.keys, [k(f.kitchen)]);
      expect(view.grips.box, isNotNull);
      expect(view.grips.rotatable, isFalse, reason: 'no rotation grip');
      final before = enc(doc);
      await dragWorld(
          tester, view, name, name + (f.plan.at(700, 300) - f.plan.at(0, 0)));
      expect(doc.commands.undoDepth, 0, reason: 'nothing in the history');
      expect(enc(doc), before, reason: 'nothing moved');
      expect(view.selection.keys, [k(f.kitchen)], reason: 'still a click');

      // The Kitchen, B and the partition: a drag on the partition's west
      // face, x 2,950, 250 mm along the plan's x axis, with object snap
      // off, moves the partition alone.
      await toggleF3(tester);
      view.selection.replace([k(f.kitchen), k(f.b), k(f.part)]);
      await tester.pump();
      expect(view.grips.rotatable, isTrue, reason: 'the partition');
      final t0 = doc.tree.accumulatedTransform(f.part);
      final rooms = {
        f.kitchen: (roomOf(doc, f.kitchen), doc.tree[f.kitchen]),
        f.b: (roomOf(doc, f.b), doc.tree[f.b]),
      };
      await dragWorld(
          tester, view, f.plan.at(2950, 1200.5), f.plan.at(3200, 1200.5));
      expect(doc.commands.undoDepth, 1, reason: 'one step');
      final t1 = doc.tree.accumulatedTransform(f.part);
      final v = Vector2(t1.e - t0.e, t1.f - t0.f);
      final x = Vector2(math.cos(place.deg * math.pi / 180),
          math.sin(place.deg * math.pi / 180));
      final delta = v.dot(x);
      expect(delta, closeTo(250, 1), reason: 'premise: the partition moved');
      expect((v - x * delta).length, lessThan(1e-6), reason: 'along x only');
      for (final MapEntry(key: h, value: (p, node)) in rooms.entries) {
        expect(roomOf(doc, h), p, reason: 'the room stays: $h');
        expect(doc.tree[h], node, reason: 'its group untouched: $h');
      }
      // Re-traced: the Kitchen x 100..2,950 + Δ, (2,850 + Δ) × 3,800 with
      // Δ = 250 ± 1: 11.776..11.784 m², "11.78 m²"; B x 3,050 + Δ..6,250.5,
      // (3,200.5 − Δ) × 3,800: 11.2081..11.2157 m², "11.21 m²".
      expect(labelStrings(doc, f.kitchen), ['Kitchen', '11.78 m²']);
      expect(labelStrings(doc, f.b), ['Room 2', '11.21 m²']);
      final kitchen = faceAt(doc, f.plan.at(1500.25, 2000.5)) as Traced;
      expect(kitchen.area, closeTo((2850 + delta) * 3800, 1e-2));
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusGroups]) {
    test(
        'GR5 a separator\'s end grips move one end, trimmed to a face with '
        'object snap on, $place', () {
      final f = gripPlan(place);
      final doc = f.plan.doc;
      final inputs = RoomInputs(doc);
      addTearDown(inputs.dispose);
      var snap = true;
      final objects = ObjectGrips(
          edgeAperture: () => null, roomInputs: inputs, objectSnap: () => snap);
      expect(objects.movable(doc, f.sep), isTrue);
      final [g0, g1] = objects.gripsOf(doc, f.sep);
      expect([g0.role, g1.role], [GripRole.stretch, GripRole.stretch]);
      expect((at(g0) - f.plan.at(6250.5, 100)).length, lessThan(1e-6));
      expect((at(g1) - f.plan.at(6250.5, 3900)).length, lessThan(1e-6));
      final stored = sepOf(doc, f.sep);
      final toWorld = doc.tree.accumulatedTransform(f.sep);
      final toLocal = toWorld.invert();

      // Walls 0-3: south, east, north, west; inner faces 100 in.
      for (final (what, grip, (x, y), wall) in [
        ('the end into the north wall', g1, (5800.37, 3960.21), 2),
        ('the start into the south wall', g0, (6700.13, 40.29), 0),
      ]) {
        final p = f.plan.at(x, y);
        final kept = grip.index == 0 ? at(g1) : at(g0);
        for (final on in [true, false]) {
          snap = on;
          final why = '$what, F3 $on';
          final depth = doc.commands.undoDepth;
          final (a, b) = lineOf(objects.preview(doc, f.sep, grip, p));
          doc.commands.execute(objects.drag(doc, f.sep, grip, p)!);
          expect(doc.commands.undoDepth, depth + 1, reason: '$why: one step');
          final now = sepOf(doc, f.sep);
          final (moved, same, movedStored, sameStored) = grip.index == 0
              ? (now.start, now.end, stored.start, stored.end)
              : (now.end, now.start, stored.end, stored.start);
          expect((same.x, same.y), (sameStored.x, sameStored.y),
              reason: '$why: the other end stays, exactly');
          expect(moved, isNot(movedStored));
          final w = toWorld.transformPoint(moved);
          expect(((grip.index == 0 ? a : b) - w).length, lessThan(1e-6),
              reason: '$why: the preview is the stored segment');
          expect(((grip.index == 0 ? b : a) - kept).length, lessThan(1e-6),
              reason: '$why: the preview keeps the other end');
          if (on) {
            // The face by hand: 100 in from the wall's centreline.
            final (h1, h2) = wall == 0
                ? (f.plan.at(0, 100), f.plan.at(8000, 100))
                : (f.plan.at(0, 3900), f.plan.at(8000, 3900));
            expect(distToLine(w, h1, h2), lessThan(1e-6),
                reason: '$why: on the inner face');
            expect(distToLine(w, kept, p), lessThan(1e-6),
                reason: '$why: on the drawn segment');
            expect((w - p).length, greaterThan(20),
                reason: '$why: out of the band');
          } else {
            final q = toLocal.transformPoint(p);
            expect((moved.x, moved.y), (q.x, q.y), reason: '$why: as placed');
          }
          expect(driftOf(doc), isEmpty);
          doc.commands.undo();
          expect(sepOf(doc, f.sep), stored, reason: '$why: undone');
          inputs.invalidate();
        }
      }

      // Both ends in one band, and a drop on the grip: nothing.
      snap = true;
      expect(objects.drag(doc, f.sep, g0, f.plan.at(6600.5, 3950.25)), isNull,
          reason: 'the start dragged into the band the end is trimmed to');
      expect(
          objects.preview(doc, f.sep, g0, f.plan.at(6600.5, 3950.25)), isEmpty);
      expect(objects.drag(doc, f.sep, g1, at(g1)), isNull,
          reason: 'on the grip');

      // A wall added in the same task as the drag, its change not yet
      // delivered: the drag still trims to its face, y 1,900.
      final mid = doc.handleSeed.next();
      final ms = f.plan.at(0, 2000), me = f.plan.at(8000, 2000);
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: mid,
            parent: doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(
            mid, WallParams(ms.x, ms.y, me.x, me.y, 200, Justification.centre)),
      ], label: 'Add wall'));
      doc.commands
          .execute(objects.drag(doc, f.sep, g1, f.plan.at(5800.37, 2030.21))!);
      final w = toWorld.transformPoint(sepOf(doc, f.sep).end);
      expect(distToLine(w, f.plan.at(0, 1900), f.plan.at(8000, 1900)),
          lessThan(1e-6),
          reason: 'trimmed to the new wall\'s face');
      expect(driftOf(doc), isEmpty);
    });

    testWidgets(
        'GR5 (shell) a separator end dragged into a band is trimmed with F3 '
        'on and kept as placed with it off; a separator alone gets a '
        'rotation grip, $place', (tester) async {
      final f = gripPlan(place, measurer: FlutterTextMeasurer(), shell: true);
      final doc = f.plan.doc;
      final view = await pumpShell(tester, f, f.plan.at(6000, 3000));
      view.selection.replace([k(f.sep)]);
      await tester.pump();
      expect(view.grips.rotatable, isTrue, reason: 'a separator is movable');
      final stored = sepOf(doc, f.sep);
      final toWorld = doc.tree.accumulatedTransform(f.sep);
      final p = f.plan.at(5800.37, 3960.21);
      for (final on in [true, false]) {
        expect(osnap(tester), on ? 'OSNAP' : 'osnap off');
        final g = objectGripsOf(view, f.sep)[1];
        await dragWorld(tester, view, at(g), p);
        expect(doc.commands.undoDepth, 1, reason: 'F3 $on: one step');
        final now = sepOf(doc, f.sep);
        expect((now.sx, now.sy), (stored.sx, stored.sy),
            reason: 'F3 $on: the start stays');
        final w = toWorld.transformPoint(now.end);
        if (on) {
          expect(distToLine(w, f.plan.at(0, 3900), f.plan.at(8000, 3900)),
              lessThan(1e-6),
              reason: 'trimmed to the north wall\'s inner face');
        } else {
          expect((w - p).length, lessThan(1e-6), reason: 'as placed');
        }
        await undoKey(tester);
        expect(sepOf(doc, f.sep), stored);
        if (on) await toggleF3(tester);
      }
    });
  }

  test(
      'GR6 the label grip under a rotated, translated, scaled room group: '
      'GR1 and GR2 again', () {
    final c = corpus.at(1400, 1900);
    final g = Transform2.translation(c.x, c.y)
        .multiply(Transform2.rotation(23 * math.pi / 180))
        .multiply(Transform2.scale(1.5, 1.5));
    final f = gripPlan(corpus, kitchenAt: g);
    final doc = f.plan.doc;
    expect(doc.tree.accumulatedTransform(f.kitchen).scaleMagnitude,
        closeTo(1.5, 1e-12),
        reason: 'premise');
    const ap = 40.0;
    final objects =
        ObjectGrips(edgeAperture: () => null, labelAperture: () => ap);

    // The grip at the anchor; the premise that the frames differ: the name
    // TEXT's point less the line offset in local space lands elsewhere.
    final grip = objects.gripsOf(doc, f.kitchen).single;
    final anchor = anchorOf(doc, f.kitchen);
    expect((at(grip) - anchor).length, lessThan(1e-6), reason: 'the anchor');
    expect((anchorFromArea(doc, f.kitchen) - anchor).length, lessThan(1e-6));
    final q = payloadOf(doc, labelsOf(doc, f.kitchen).first).coords;
    final localFrame = g.transformPoint(Vector2(q[0], q[1] - 0.7 * 125));
    expect((localFrame - anchor).length, greaterThan(20),
        reason: 'premise: the local frame is not the world frame');

    // GR1: a drag stores `toLocal(p) − pole_l`, exactly; the labels move
    // there; undo is exact.
    final before = roomOf(doc, f.kitchen);
    final p = f.plan.at(1900.37, 2600.81);
    final want = labelFor(doc, f.kitchen, at(grip), p);
    doc.commands.execute(objects.drag(doc, f.kitchen, grip, p)!);
    expect(doc.commands.undoDepth, 1);
    expect(roomOf(doc, f.kitchen).label, want);
    expect((anchorOf(doc, f.kitchen) - p).length, lessThan(1e-6),
        reason: 'the labels moved there');
    expect(driftOf(doc), isEmpty);
    doc.commands.undo();
    expect(roomOf(doc, f.kitchen), before);

    // GR2: a drop within the aperture of the pole, in world, stores null.
    final pole = g.transformPoint(poleLocal(doc, f.kitchen, at(grip)));
    expect((pole - at(grip)).length, greaterThan(3 * ap), reason: 'premise');
    final near = pole + Vector2(-0.5 * ap, 0.6 * ap);
    expect(objects.preview(doc, f.kitchen, grip, near), isEmpty);
    doc.commands.execute(objects.drag(doc, f.kitchen, grip, near)!);
    expect(roomOf(doc, f.kitchen).label, isNull);
    expect((anchorOf(doc, f.kitchen) - pole).length, lessThan(1e-6),
        reason: 'the labels at the pole');
    expect(driftOf(doc), isEmpty);
    doc.commands.undo();
    expect(roomOf(doc, f.kitchen), before);

    // The aperture is measured in world (Task 17's review): a drop 1.2
    // apertures from the pole in world is 0.8 of one in the group's local
    // space (scale 1.5), and stores an offset.
    final beyond = pole + Vector2(0.72 * ap, -0.96 * ap); // |·| = 1.2 ap
    expect((beyond - pole).length, closeTo(1.2 * ap, 1e-9), reason: 'premise');
    final toLocal = g.invert();
    expect(
        (toLocal.transformPoint(beyond) - toLocal.transformPoint(pole)).length,
        lessThan(ap),
        reason: 'premise: inside the aperture in local space');
    final wantBeyond = labelFor(doc, f.kitchen, at(grip), beyond);
    expect(objects.preview(doc, f.kitchen, grip, beyond), isNotEmpty);
    doc.commands.execute(objects.drag(doc, f.kitchen, grip, beyond)!);
    expect(roomOf(doc, f.kitchen).label, wantBeyond);
    expect((anchorOf(doc, f.kitchen) - beyond).length, lessThan(1e-6),
        reason: 'the labels moved there');
    expect(driftOf(doc), isEmpty);
  });
}
