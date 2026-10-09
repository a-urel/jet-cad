// Host embedding API spec, Slice 1, G-1 and G-4: a table's detail
// (`FloorPlanController.tableDetails`) and the table at a canvas point
// (`tableAt`), over the shared non-degenerate fixture (embedding_fixture):
// an off-base box, turned, mirrored, non-uniformly scaled tables 40 m off
// the origin, hidden and locked layers, a shared number, an unnumbered
// table, non-finite corners, and a panned camera at 0.37 px/mm.
// Expectations are the fixture's box through each table's own transform.
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' show Offset, PointerDeviceKind, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/table_detail.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';

import 'embedding_fixture.dart';

FloorPlanController embeddingController() {
  final c = FloorPlanController(json: embeddingPlanJson());
  addTearDown(c.dispose);
  c.cameraController.value = embeddingCamera();
  return c;
}

/// Within a relative 1e-12 of [want] (geometry), an absolute 1e-12 near 0.
Matcher near(double want) => closeTo(want, 1e-12 * math.max(want.abs(), 1.0));

/// World [x], [y] through [t].
Offset world(Transform2 t, double x, double y) =>
    Offset(t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f);

void expectOffset(Offset? got, Offset want, String reason) {
  expect(got, isNotNull, reason: reason);
  expect(got!.dx, near(want.dx), reason: '$reason: x');
  expect(got.dy, near(want.dy), reason: '$reason: y');
}

/// The fixture's tables that the planner shows: not hidden, finite.
Iterable<(EmbeddingTable, FloorPlanTableDetail)> shown(
    FloorPlanController c) sync* {
  final details = c.tableDetails;
  expect(details, hasLength(embeddingTables.length), reason: 'premise');
  for (var i = 0; i < details.length; i++) {
    final t = embeddingTables[i];
    if (t.layer == kEmbeddingHidden || !t.finite) continue;
    yield (t, details[i]);
  }
}

/// The canvas point of [t]'s local ([x], [y]) under [c]'s camera.
Offset canvasAt(FloorPlanController c, Transform2 t, double x, double y) {
  final w = world(t, x, y);
  final p = canvasOf(c.cameraController.value, w.dx, w.dy);
  return Offset(p.x, p.y);
}

EmbeddingTable fixtureTable(String? number) =>
    embeddingTables.firstWhere((t) => t.number == number);

void main() {
  testWidgets(
      'TD0 premise: the document\'s box of the symbol is the fixture\'s, off '
      'its base point', (tester) async {
    final c = embeddingController();
    final d = c.activeDocument;
    final t = TableSurvey.of(d).tables.first;
    final box = d.definitionBounds(t.definition, d.leavesByOwner());
    expect([
      box.minX,
      box.minY,
      box.maxX,
      box.maxY
    ], [
      embeddingBox.minX,
      embeddingBox.minY,
      embeddingBox.maxX,
      embeddingBox.maxY
    ]);
    expect(embeddingBox.center.x != 0 || embeddingBox.center.y != 0, isTrue);
  });

  testWidgets(
      'TD1 one detail per table, ascending by handle as `tables` lists them, '
      'its FloorPlanTable that one, its layer and lock its layer\'s, no data',
      (tester) async {
    final c = embeddingController();
    final details = c.tableDetails;
    expect([for (final d in details) d.table], c.tables);
    expect([for (final d in details) d.table.number],
        [for (final t in embeddingTables) t.number]);
    for (var i = 0; i < details.length; i++) {
      final t = embeddingTables[i], d = details[i];
      expect(d.table.seats, 4);
      expect(d.table.symbolKey, embeddingTable.key);
      expect(d.table.visible, t.layer != kEmbeddingHidden, reason: t.label);
      expect(d.layer, t.layer, reason: t.label);
      expect(d.locked, t.layer == kEmbeddingLocked, reason: t.label);
      expect(d.data, isEmpty);
    }
  });

  testWidgets(
      'TD2 M-H1, M-H13: center is the box\'s centre through the placement -- '
      'not a box corner, not the placement\'s translation (the box is off '
      'its base point)', (tester) async {
    final c = embeddingController();
    final cx = embeddingBox.center.x, cy = embeddingBox.center.y;
    var seen = 0;
    for (final (t, d) in shown(c)) {
      final want = world(t.transform, cx, cy);
      expectOffset(d.center, want, '${t.label}');
      // Premise: neither the corner nor the translation is the centre.
      final corner = world(t.transform, embeddingBox.minX, embeddingBox.minY);
      expect((corner - want).distance, greaterThan(100));
      expect((Offset(t.transform.e, t.transform.f) - want).distance,
          greaterThan(100));
      seen++;
    }
    expect(seen, 8, reason: 'premise: every table but 5 and 9');
  });

  testWidgets(
      'TD3 M-H2: rotation is the counter-clockwise turn, atan2(b, a): the 30 '
      'degree table reads +pi/6; every turn as built, mirrored or scaled',
      (tester) async {
    final c = embeddingController();
    final one = c.tableDetails.first;
    expect(one.table.number, '1');
    expect(one.rotation, near(math.pi / 6));
    for (final (t, d) in shown(c)) {
      expect(d.rotation, near(t.degrees * math.pi / 180), reason: t.label);
    }
  });

  testWidgets(
      'TD4 M-H3, O4: mirrored is det < 0 -- not a < 0, not a·d < 0: the 180 '
      'degree table is not mirrored, the exact 90 degree one is',
      (tester) async {
    final c = embeddingController();
    final four = c.tableDetails[3], two = c.tableDetails[1];
    expect(four.table.number, '4');
    expect(two.table.number, '2');
    // Premise: the first column's x is negative for 4 and not for 2.
    expect(fixtureTable('4').transform.a, lessThan(0));
    expect(fixtureTable('2').transform.a, greaterThanOrEqualTo(0));
    // Premise: 2's a·d is 0, not negative, while its det is -1.
    expect(fixtureTable('2').transform.a * fixtureTable('2').transform.d, 0);
    expect(fixtureTable('2').transform.determinant, -1);
    expect(four.mirrored, isFalse, reason: '180 degrees, unmirrored');
    expect(two.mirrored, isTrue, reason: 'mirrored at 90 degrees');
    for (final (t, d) in shown(c)) {
      expect(d.mirrored, t.sy < 0, reason: t.label);
    }
  });

  testWidgets(
      'TD5 M-H14: size is the box\'s width and height times the placement\'s '
      'column lengths: the (1.5, 0.8) table is 1200 x 480', (tester) async {
    final c = embeddingController();
    final three = c.tableDetails[2];
    expect(three.table.number, '3');
    expect(three.size!.width, near(800 * 1.5));
    expect(three.size!.height, near(600 * 0.8));
    for (final (t, d) in shown(c)) {
      expect(d.size!.width, near(embeddingBox.size.x * t.sx.abs()),
          reason: t.label);
      expect(d.size!.height, near(embeddingBox.size.y * t.sy.abs()),
          reason: t.label);
    }
  });

  testWidgets(
      'TD6 corners: the box\'s four corners in the world, counter-clockwise '
      'from its (min, min) corner whatever the mirror, unmodifiable',
      (tester) async {
    final c = embeddingController();
    final b = embeddingBox;
    for (final (t, d) in shown(c)) {
      final p00 = world(t.transform, b.minX, b.minY),
          p10 = world(t.transform, b.maxX, b.minY),
          p11 = world(t.transform, b.maxX, b.maxY),
          p01 = world(t.transform, b.minX, b.maxY);
      // The fixture knows which of its tables mirror.
      final want = t.sy < 0 ? [p00, p01, p11, p10] : [p00, p10, p11, p01];
      expect(d.corners, hasLength(4), reason: t.label);
      for (var i = 0; i < 4; i++) {
        expectOffset(d.corners[i], want[i], '${t.label} corner $i');
      }
      // Counter-clockwise: the shoelace area is positive, the box's own.
      var twice = 0.0;
      for (var i = 0; i < 4; i++) {
        final p = d.corners[i], q = d.corners[(i + 1) % 4];
        twice += p.dx * q.dy - q.dx * p.dy;
      }
      final area = d.size!.width * d.size!.height;
      expect(twice / 2, closeTo(area, 1e-9 * area), reason: t.label);
      expect(() => d.corners.add(Offset.zero), throwsUnsupportedError);
    }
  });

  testWidgets(
      'TD7 a table on a hidden layer and one with non-finite corners report '
      'no geometry; the locked table does, locked', (tester) async {
    final c = embeddingController();
    final details = c.tableDetails;
    for (final n in ['5', '9']) {
      final d = details.singleWhere((d) => d.table.number == n);
      expect(d.center, isNull, reason: n);
      expect(d.size, isNull, reason: n);
      expect(d.corners, isEmpty, reason: n);
      expect(d.rotation, 0, reason: n);
      expect(d.mirrored, isFalse, reason: n);
    }
    expect(details.singleWhere((d) => d.table.number == '5').layer,
        kEmbeddingHidden);
    final l = details.singleWhere((d) => d.table.number == 'L');
    expect(l.locked, isTrue);
    expect(l.layer, kEmbeddingLocked);
    expect(l.center, isNotNull);
    final sevens = [
      for (final d in details)
        if (d.table.number == '7') d
    ];
    expect(sevens, hasLength(2), reason: 'both tables numbered 7');
    expect(sevens[0].center, isNot(sevens[1].center));
    expect(details.where((d) => d.table.number == null), hasLength(1));
  });

  testWidgets(
      'TD8 cached: two reads at the same key are identical and unmodifiable; '
      'an edit or a mode switch makes a new list', (tester) async {
    final c = embeddingController();
    final first = c.tableDetails;
    expect(identical(c.tableDetails, first), isTrue);
    expect(() => first.removeLast(), throwsUnsupportedError);
    await tester.pump();
    expect(identical(c.tableDetails, first), isTrue, reason: 'nothing changed');

    final d = c.activeDocument;
    final one = TableSurvey.of(d).tables.first.instance;
    final node = d.tree[one]! as InstanceNode;
    d.commands.execute(TransformNodeCommand(
        one, Transform2.translation(500, 0).multiply(node.transform)));
    final moved = c.tableDetails;
    expect(identical(moved, first), isFalse);
    expect(moved.first.center!.dx, near(first.first.center!.dx + 500));
    expect(identical(c.tableDetails, moved), isTrue);

    c.setMode(FloorPlanMode.selection);
    expect(identical(c.tableDetails, moved), isFalse);
    expect(c.tableDetails, moved, reason: 'the copy is equal');
  });

  testWidgets(
      'TD9 M-H15: a layer hidden outside the history (a table edit, no '
      'command) reads at the next revision, though the state id is back '
      'where it was', (tester) async {
    final c = embeddingController();
    var revisions = 0;
    void count() => revisions++;
    c.revision.addListener(count);
    addTearDown(() => c.revision.removeListener(count));
    final d = c.activeDocument;
    final before = c.tableDetails;
    expect(before.singleWhere((t) => t.table.number == 'L').center, isNotNull);
    final state = d.commands.stateId;

    final locked = d.tables.layers.byName(kEmbeddingLocked)!;
    d.tables.layers
      ..remove(locked.handle)
      ..add(locked.copyWith(visible: false));
    // An edit and its undo: `revision` moves, the state id comes back.
    final one = TableSurvey.of(d).tables.first.instance;
    final node = d.tree[one]! as InstanceNode;
    d.commands.execute(TransformNodeCommand(
        one, Transform2.translation(500, 0).multiply(node.transform)));
    c.undo();
    await tester.pump();
    expect(revisions, greaterThan(0), reason: 'premise: revision moved');
    expect(d.commands.stateId, state, reason: 'premise: the same state');

    final l = c.tableDetails.singleWhere((t) => t.table.number == 'L');
    expect(l.center, isNull, reason: 'its layer is hidden now');
    expect(l.table.visible, isFalse);
  });

  testWidgets(
      'TD11 R-1, R-2 (O6, O10): a load of another plan at the same (state, '
      'revision) key reads the loaded plan: table 1\'s new centre in '
      'tableDetails, its new place in tableAt', (tester) async {
    final c = embeddingController();
    final one = fixtureTable('1');
    final oldTop = canvasAt(c, one.transform, 600, 0);
    final before = c.tableDetails;
    expect(before.first.table.number, '1');
    expectOffset(
        before.first.center,
        world(one.transform, embeddingBox.center.x, embeddingBox.center.y),
        'premise: 1 where the fixture puts it');
    expect(c.tableAt(oldTop), '1', reason: 'premise: the picker is built');

    // The fixture with table 1 moved 2 m along x, by a second controller.
    final other = FloorPlanController(json: embeddingPlanJson());
    addTearDown(other.dispose);
    final od = other.activeDocument;
    final h = TableSurvey.of(od).withNumber('1').single.instance;
    final node = od.tree[h]! as InstanceNode;
    od.commands.execute(TransformNodeCommand(
        h, Transform2.translation(2000, 0).multiply(node.transform)));
    final json = other.designJson();

    final oldDocument = c.activeDocument;
    final oldKey =
        (oldDocument.commands.stateId, oldDocument.tables.mutationRevision);
    c.load(json);
    // The load refits the camera: the fixture's again.
    c.cameraController.value = embeddingCamera();
    final d = c.activeDocument;
    expect(identical(d, oldDocument), isFalse, reason: 'premise: a new plan');
    expect((d.commands.stateId, d.tables.mutationRevision), oldKey,
        reason: 'premise: the key alone does not tell the plans apart');

    final moved = Transform2.translation(2000, 0).multiply(one.transform);
    final after = c.tableDetails;
    expect(after.first.table.number, '1');
    expectOffset(
        after.first.center,
        world(moved, embeddingBox.center.x, embeddingBox.center.y),
        'O6: 1 moved by the load');
    expect(c.tableAt(oldTop), isNull, reason: 'O10: 1 is gone from there');
    expect(c.tableAt(canvasAt(c, moved, 600, 0)), '1',
        reason: 'O10: 1 is at its loaded place');
  });

  test(
      'TD12 R-4 (O2, O3): rotation is in (-pi, pi]: a half turn written with '
      'b = -0.0 reads +pi, not -pi; no turn written with b = -0.0 reads '
      '+0.0', () {
    const table = FloorPlanTable(number: '1', seats: 4, symbolKey: 'k');
    FloorPlanTableDetail of(Transform2 t) {
      final b = embeddingBox;
      final corners = Float64List(8);
      for (final (i, (x, y)) in [
        (b.minX, b.minY),
        (b.maxX, b.minY),
        (b.maxX, b.maxY),
        (b.minX, b.maxY)
      ].indexed) {
        final p = world(t, x, y);
        corners[2 * i] = p.dx;
        corners[2 * i + 1] = p.dy;
      }
      return tableDetailOf(
          table: table,
          transform: t,
          box: b,
          corners: corners,
          layer: '0',
          locked: false);
    }

    // Premise: atan2 reads the sign of a zero b.
    expect(math.atan2(-0.0, -1), -math.pi);
    expect(math.atan2(-0.0, 1).isNegative, isTrue);

    final half = of(const Transform2(-1, -0.0, 0, -1, 45000, -33000));
    expect(half.rotation, math.pi);
    expect(half.mirrored, isFalse);

    final none = of(const Transform2(1, -0.0, 0, 1, 45000, -33000));
    expect(none.rotation, 0);
    expect(none.rotation.isNegative, isFalse);
    expect(none.toString(), contains('rotation: 0.0,'));
    expect(none, of(const Transform2(1, 0, 0, 1, 45000, -33000)));
  });

  testWidgets(
      'TD13 R-5 (O9): a layer missing from the plan\'s layers (a hand-edited '
      'file) reads shown and unlocked, named \'\', as the picker reads it',
      (tester) async {
    final c = embeddingController();
    final d = c.activeDocument;
    final locked = d.tables.layers.byName(kEmbeddingLocked)!;
    d.tables.layers.remove(locked.handle);
    final l = fixtureTable('L');
    final i = embeddingTables.indexOf(l);
    final detail = c.tableDetails[i];
    expect(detail.table.number, 'L');
    expect(detail.table.visible, isTrue);
    expect(detail.layer, '');
    expect(detail.locked, isFalse);
    expectOffset(detail.center,
        world(l.transform, embeddingBox.center.x, embeddingBox.center.y), 'L');
    expect(c.tables[i].visible, isTrue, reason: 'as `tables` reads it');
    expect(c.tableAt(canvasAt(c, l.transform, 600, 0)), 'L');
  });

  test('TD10 FloorPlanTableDetail: ==, hashCode and toString by every field',
      () {
    const table = FloorPlanTable(number: '7', seats: 4, symbolKey: 'k');
    FloorPlanTableDetail make(
            {FloorPlanTable t = table,
            Offset? center = const Offset(40700, -26900),
            Size? size = const Size(800, 600),
            double rotation = 0.5,
            bool mirrored = true,
            List<Offset> corners = const [Offset(1, 2), Offset(3, 4)],
            String layer = 'L',
            bool locked = true,
            Map<String, String> data = const {}}) =>
        FloorPlanTableDetail(
            table: t,
            center: center,
            size: size,
            rotation: rotation,
            mirrored: mirrored,
            corners: corners,
            layer: layer,
            locked: locked,
            data: data);
    final a = make();
    final same = make(corners: [const Offset(1, 2), const Offset(3, 4)]);
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    for (final other in [
      make(t: const FloorPlanTable(number: '8', seats: 4, symbolKey: 'k')),
      make(center: const Offset(40700, -26901)),
      make(center: null),
      make(size: const Size(800, 601)),
      make(rotation: 0.25),
      make(mirrored: false),
      make(corners: const [Offset(1, 2), Offset(3, 5)]),
      make(corners: const [Offset(3, 4), Offset(1, 2)]),
      make(layer: '0'),
      make(locked: false),
      make(data: const {'id': '42'}),
    ]) {
      expect(a == other, isFalse, reason: '$other');
    }
    expect(make(data: const {'a': '1', 'b': '2'}),
        make(data: const {'b': '2', 'a': '1'}));
    expect(make(data: const {'a': '1', 'b': '2'}).hashCode,
        make(data: const {'b': '2', 'a': '1'}).hashCode);
    expect(
        a.toString(),
        'FloorPlanTableDetail(FloorPlanTable(7, 4, k, visible: true), '
        'center: Offset(40700.0, -26900.0), size: Size(800.0, 600.0), '
        'rotation: 0.5, mirrored: true, corners: [Offset(1.0, 2.0), '
        'Offset(3.0, 4.0)], layer: L, locked: true, data: {})');
  });

  // G-4: `tableAt`.

  testWidgets(
      'TA1 tableAt: a point on a top, in a box off the top, nowhere; the '
      'unnumbered table and a hidden one answer null, the locked one and '
      'each 7 their number; the default kind is a mouse', (tester) async {
    final c = embeddingController();
    // On the top (the quadrilateral holds local (600, 0)).
    for (final t in embeddingTables) {
      if (!t.finite) continue;
      final want = t.layer == kEmbeddingHidden ? null : t.number;
      expect(c.tableAt(canvasAt(c, t.transform, 600, 0)), want,
          reason: '${t.label} on its top');
    }
    // In the box, outside the top: local (1050, 350).
    final one = fixtureTable('1');
    expect(c.tableAt(canvasAt(c, one.transform, 1050, 350)), '1');
    // Between the tables.
    expect(c.tableAt(canvasAt(c, one.transform, 2200, 100)), isNull);
    expect(
        c.tableAt(canvasAt(c, one.transform, 2200, 100),
            kind: PointerDeviceKind.touch),
        isNull,
        reason: 'far beyond a finger\'s reach');
  });

  testWidgets(
      'TA2 M-H19b(tableAt), O8: a finger 30 mm (11 px) off a table\'s box '
      'finds it, a mouse or a stylus does not; 80 mm (30 px) off, a finger '
      'does not', (tester) async {
    final c = embeddingController();
    final one = fixtureTable('1');
    final x = embeddingBox.maxX, y = embeddingBox.center.y;
    final near = canvasAt(c, one.transform, x + 30, y);
    final far = canvasAt(c, one.transform, x + 80, y);
    // Premise: 24 px is 64.9 mm at 0.37 px/mm.
    expect(30 * 0.37, lessThan(24));
    expect(80 * 0.37, greaterThan(24));
    expect(c.tableAt(near), isNull, reason: 'a mouse picks by containment');
    expect(c.tableAt(near, kind: PointerDeviceKind.mouse), isNull);
    expect(c.tableAt(near, kind: PointerDeviceKind.stylus), isNull,
        reason: 'O8: only a finger gets the reach');
    expect(c.tableAt(near, kind: PointerDeviceKind.touch), '1',
        reason: 'within a finger\'s reach');
    expect(c.tableAt(far, kind: PointerDeviceKind.touch), isNull,
        reason: 'beyond a finger\'s reach');
  });

  testWidgets(
      'TA3 tableAt follows the camera and the mode: a service move is found '
      'at the table\'s new place in the selection mode, at its old one '
      'after switching back', (tester) async {
    final c = embeddingController();
    final one = fixtureTable('1');
    final at = canvasAt(c, one.transform, 600, 0);
    expect(c.tableAt(at), '1');
    // A pan of 200 px moves what is under the point.
    c.cameraController.panBy(const Offset(200, 0));
    expect(c.tableAt(at), isNull);
    c.cameraController.value = embeddingCamera();

    c.setMode(FloorPlanMode.selection);
    // A mode switch reframes the camera (R-13): the fixture's again.
    c.cameraController.value = embeddingCamera();
    final d = c.activeDocument;
    final h = TableSurvey.of(d).withNumber('1').single.instance;
    final node = d.tree[h]! as InstanceNode;
    d.commands.execute(CompoundCommand([
      TransformNodeCommand(
          h, Transform2.translation(1500, 0).multiply(node.transform))
    ], label: 'Move'));
    final moved = Transform2.translation(1500, 0).multiply(one.transform);
    expect(c.tableAt(canvasAt(c, moved, 600, 0)), '1');
    expect(c.tableAt(at), isNull);

    c.setMode(FloorPlanMode.design);
    c.cameraController.value = embeddingCamera();
    expect(c.tableAt(at), '1');
    expect(c.tableAt(canvasAt(c, moved, 600, 0)), isNull);
  });
}
