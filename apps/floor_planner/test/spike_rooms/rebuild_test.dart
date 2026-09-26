// SPIKE 10 -- throwaway. Q3 (which walls a rebuild needs, and when a ring
// breaks) and Q5 (the room on the real ParametricSystem: tint, label text
// rewritten, page reads, dissolve, per-reference policy).
import 'dart:convert';

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'support.dart';

/// [room]'s verdict over a full survey (`diagnostics()` asks every room).
RoomVerdict verdictOf(Plan plan, Handle room) {
  debugVerdicts.clear();
  plan.system.diagnostics();
  return debugVerdicts[room]!;
}

bool alive(DraftDocument doc, Handle room) =>
    doc.tree[room] != null && doc.components.get<RoomParams>(room) != null;

void setWall(Plan plan, Handle h, WallParams Function(WallParams) f) =>
    plan.doc.commands.execute(SetComponentCommand<WallParams>(
        h, f(plan.doc.components.get<WallParams>(h)!)));

/// World point [x], [y] of [plan] taken into wall [h]'s group.
WallParams movedWall(Plan plan, Handle h,
    {(double, double)? s, (double, double)? e}) {
  final p = plan.doc.components.get<WallParams>(h)!;
  final inv = plan.doc.tree.accumulatedTransform(h).invert();
  final ls = s == null ? p.start : inv.transformPoint(plan.at(s.$1, s.$2));
  final le = e == null ? p.end : inv.transformPoint(plan.at(e.$1, e.$2));
  return p.copyWith(start: ls, end: le);
}

String save(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

/// [save] with the root's child order normalised (06's convention: undoing
/// a node removal re-adds the node last).
String canonical(DraftDocument doc) {
  final j = DraftDocumentCodec.encode(doc);
  for (final n in j['nodes']! as List) {
    final m = n as Map<String, Object?>;
    if (m['handle'] == j['root']) {
      m['children'] = [...(m['children']! as List).cast<int>()]..sort();
    }
  }
  return jsonEncode(j);
}

DraftDocument load(String s) =>
    DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
        registerComponents: (r) {
      PageComponent.register(r);
      parametricCatalog.registerComponents(r);
    });

void main() {
  setUp(() => roomTraceSet = RoomTraceSet.refs);
  tearDown(() => roomTraceSet = RoomTraceSet.refs);

  // -----------------------------------------------------------------------
  // Q3a: the restricted trace against the all-walls trace, every fixture,
  // every placement, both candidate sets.
  for (final place in placements) {
    test('Q3a restricted == all walls on every clicked room at $place', () {
      final fixtures = <(List<W>, List<S>, List<(double, double)>)>[
        (
          [...sampleWalls(), sampleColumn],
          [sampleSeparator],
          [...sampleSeeds.values, (19000, 14000), (22500, 14000)]
        ),
        (lWalls, const [], const [(1000, 1000)]),
        (mixedWalls, const [], const [(2500, 2000)]),
        (twoRoomWalls, const [], const [(1500, 2000), (5500, 2000)]),
        (
          [
            ...boxWalls,
            (5000, 1500, 5600, 1500, 100),
            (5600, 1500, 5600, 2100, 100),
            (5600, 2100, 5000, 2100, 100),
            (5000, 2100, 5000, 1500, 100),
          ],
          const [(3000, 100, 3000, 3900)],
          const [(1500, 2000), (7000, 2000), (5300, 1800)]
        ),
      ];
      var rooms = 0;
      for (final (walls, seps, seeds) in fixtures) {
        final plan = buildPlan(walls, seps: seps, place: place);
        final handles = [
          for (final (x, y) in seeds) clickRoom(plan.doc, plan.at(x, y), 'R')!
        ];
        expect(plan.system.drift(), isEmpty);
        for (final mode in RoomTraceSet.values) {
          roomTraceSet = mode;
          for (var i = 0; i < seeds.length; i++) {
            final (x, y) = seeds[i];
            final all = traceAll(plan.doc, plan.at(x, y)) as Traced;
            final v = verdictOf(plan, handles[i]);
            expect(v, isA<RoomOk>(), reason: '$mode $x,$y: $v');
            final t = (v as RoomOk).trace;
            expect(t.area, closeTo(all.area, 1e-6), reason: '$mode $x,$y');
            expect(t.ring.length, all.ring.length);
            for (var k = 0; k < t.ring.length; k++) {
              expect((t.ring[k] - all.ring[k]).length, lessThan(1e-6));
            }
            expect(t.holes.length, all.holes.length);
          }
        }
        roomTraceSet = RoomTraceSet.refs;
        rooms += seeds.length;
      }
      // ignore: avoid_print
      print(
          'Q3a $place: $rooms rooms, restricted == all walls, all three sets');
    });
  }

  // -----------------------------------------------------------------------
  // Q3b: counter-examples. A wall added after the click that touches the
  // ring without joining a bounding wall.
  for (final place in [origin, corpus]) {
    test('Q3b counter-examples at $place', () {
      String run(List<W> extra, String what) {
        final plan = buildPlan(twoRoomWalls, place: place);
        final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
        final before = labelsOf(plan.doc, right);
        final x = [
          for (final (sx, sy, ex, ey, t) in extra)
            () {
              final h = plan.doc.handleSeed.next();
              plan.doc.commands.execute(CompoundCommand([
                AddNodeCommand(GroupNode(
                    handle: h,
                    parent: plan.doc.rootHandle,
                    transform: Transform2.identity(),
                    children: const [])),
                SetComponentCommand<WallParams>(
                    h,
                    WallParams(
                        plan.at(sx, sy).x,
                        plan.at(sx, sy).y,
                        plan.at(ex, ey).x,
                        plan.at(ex, ey).y,
                        t,
                        Justification.centre)),
              ], label: 'Add wall'));
              return h;
            }(),
        ];
        final all = areaOf(traceAll(plan.doc, plan.at(5500, 2000)));
        final refs = verdictOf(plan, right);
        roomTraceSet = RoomTraceSet.refsAndNeighbours;
        final withNb = verdictOf(plan, right);
        roomTraceSet = RoomTraceSet.neighboursShape;
        final shape = verdictOf(plan, right);
        roomTraceSet = RoomTraceSet.refs;
        final line = '$what: all walls ${all.toStringAsFixed(1)}; '
            'refs ${refs is RoomOk ? refs.trace.area.toStringAsFixed(1) : refs}; '
            'refs+neighbours ${withNb is RoomOk ? withNb.trace.area.toStringAsFixed(1) : withNb}; '
            'neighbours shape ${shape is RoomOk ? shape.trace.area.toStringAsFixed(1) : shape}; '
            'label after the add ${labelsOf(plan.doc, right)} (was $before); '
            'room alive ${alive(plan.doc, right)}; drift ${plan.system.drift()}; '
            'added ${x.map((h) => h.value)}';
        // ignore: avoid_print
        print('Q3b $place $line');
        return line;
      }

      // c1: a partition drawn face to face (its ends on the exterior's
      // inner faces, not its centrelines): 07 does not join it.
      // All walls: (6450 - 3050) x 3800 = 3400 x 3800 = 12,920,000.
      run([(6500, 100, 6500, 3900, 100)], 'c1 face-to-face partition');
      // c2: a freestanding wall inside the room: a hole 1000 x 100.
      // All walls: 18,430,000 - 100,000 = 18,330,000.
      run([(6000, 3000, 7000, 3000, 100)], 'c2 freestanding wall');
      // c3: a partition drawn centreline to centreline (T at both ends):
      // a neighbour of the bounding walls at every placement.
      // All walls: 12,920,000.
      run([(6500, 0, 6500, 4000, 100)], 'c3 T-joined partition');
    });
  }

  test('Q3b c4 a bound moved into an unreferenced wall\'s band', () {
    for (final place in [origin, corpus]) {
      final plan = buildPlan(twoRoomWalls, place: place);
      final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
      // The partition onto the west wall's centreline: its band (-50..50)
      // lies inside the west wall's (-100..100), which the right room
      // does not reference.
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (0, 0), e: (0, 4000)));
      final all = areaOf(traceAll(plan.doc, plan.at(5500, 2000)));
      final refs = verdictOf(plan, right);
      roomTraceSet = RoomTraceSet.refsAndNeighbours;
      final nb = verdictOf(plan, right);
      roomTraceSet = RoomTraceSet.neighboursShape;
      final shape = verdictOf(plan, right);
      roomTraceSet = RoomTraceSet.refs;
      // ignore: avoid_print
      print('Q3b $place c4: all walls $all (by hand (7900 - 100) x 3800 = '
          '29,640,000); refs '
          '${refs is RoomOk ? refs.trace.area : refs} (by hand (7900 - 50) '
          'x 3800 = 29,830,000); refs+neighbours '
          '${nb is RoomOk ? nb.trace.area : nb}; neighbours shape '
          '${shape is RoomOk ? shape.trace.area : shape}; label '
          '${labelsOf(plan.doc, right)}');
      expect(all, closeTo(29640000, 1e-2));
      expect((refs as RoomOk).trace.area, closeTo(29830000, 1e-2));
    }
  });

  test('Q3e the closure: refs+neighbours reads two hops, refs only one', () {
    Handle addW(Plan plan, W w) {
      final (sx, sy, ex, ey, t) = w;
      final h = plan.doc.handleSeed.next();
      plan.doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: plan.doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(
            h,
            WallParams(plan.at(sx, sy).x, plan.at(sx, sy).y, plan.at(ex, ey).x,
                plan.at(ex, ey).y, t, Justification.centre)),
      ], label: 'Add wall'));
      return h;
    }

    for (final mode in RoomTraceSet.values) {
      roomTraceSet = mode;
      final plan = buildPlan(boxWalls);
      final room = clickRoom(plan.doc, plan.at(6000, 3000), 'Box')!;
      // Q: a stub T-joined into the south wall, free end in the room.
      addW(plan, (4000, 0, 4000, 1500, 100));
      final afterQ = labelsOf(plan.doc, room);
      final driftQ = plan.system.drift();
      // X: joins Q's free end at a node (an L), away from every bound.
      addW(plan, (4000, 1500, 5000, 1500, 100));
      final driftX = plan.system.drift();
      // ignore: avoid_print
      print('Q3e $mode: after Q $afterQ, drift $driftQ; after X, label '
          '${labelsOf(plan.doc, room)}, drift $driftX (room ${room.value})');
      switch (mode) {
        case RoomTraceSet.refs:
          expect(driftX, isEmpty);
          expect(labelsOf(plan.doc, room), ['Box', '29.64 m²']);
        case RoomTraceSet.refsAndNeighbours:
          // Q is a neighbour of the south wall and now bounds the room.
          expect(alive(plan.doc, room), isFalse);
        case RoomTraceSet.neighboursShape:
          // Q shapes the ring; X, two hops away, changes Q's outline, and
          // the room is not in X's closure.
          expect(driftX, [room]);
      }
    }
    roomTraceSet = RoomTraceSet.refs;
  });

  test(
      'Q3d rule 4 (every bound carries an edge) dissolves a valid room: a '
      'stub wall pushed into the wall it stood against', () {
    final plan =
        buildPlan([...boxWalls, (2000, 250, 3000, 250, 300)], place: corpus);
    final room = clickRoom(plan.doc, plan.at(5500, 2000), 'Box')!;
    // 7800 x 3800 - 1000 x 300 = 29,640,000 - 300,000 = 29,340,000.
    expect(labelsOf(plan.doc, room), ['Box', '29.34 m²']);
    expect(plan.doc.components.get<RoomParams>(room)!.bounds,
        contains(plan.walls[4]));
    setWall(
        plan,
        plan.walls[4],
        (p) => movedWall(plan, plan.walls[4], s: (2000, 0), e: (3000, 0))
            .copyWith(thickness: 150));
    final all = areaOf(traceAll(plan.doc, plan.at(5500, 2000)));
    // ignore: avoid_print
    print('Q3d the stub inside the south wall\'s band: all walls $all '
        '(7800 x 3800 = 29,640,000); room alive ${alive(plan.doc, room)}');
    expect(all, closeTo(29640000, 1e-2));
    expect(alive(plan.doc, room), isFalse);
  });

  test('Q5 a direct edit of a generated label is refused (06 D6)', () {
    final plan = buildPlan(twoRoomWalls);
    final room = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
    final label = kids(plan.doc, room)
        .firstWhere((k) => kindOf(plan.doc, k) == EntityKind.text);
    expect(
        () => plan.doc.commands
            .execute(SetEntityTextCommand(label, 'Renamed', '')),
        throwsA(isA<GeneratedGeometryError>()));
    expect(labelsOf(plan.doc, room), ['Left', '10.83 m²']);
  });

  // -----------------------------------------------------------------------
  // Q3c: the ring-breaks rule, e2e, with dissolve.
  group('Q3c the ring breaks', () {
    test('the seed ends outside: the partition moved past the left seed', () {
      final plan = buildPlan(twoRoomWalls, place: corpus);
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
      final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
      final depth = plan.doc.commands.undoDepth;
      final saved = save(plan.doc);
      expect(canonical(plan.doc), saved);
      // Into the seed: x = 1500 puts the seed inside the partition's band.
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (1500, 0), e: (1500, 4000)));
      // ignore: avoid_print
      print('Q3c seed in the band: left alive ${alive(plan.doc, left)}, '
          'right ${labelsOf(plan.doc, right)}');
      expect(alive(plan.doc, left), isFalse);
      expect(kids(plan.doc, left), isEmpty);
      expect(plan.doc.components.get<RoomParams>(left), isNull);
      // Right: (7900 - 1550) x 3800 = 6350 x 3800 = 24,130,000.
      expect(labelsOf(plan.doc, right), ['Right', '24.13 m²']);
      expect(plan.doc.commands.undoDepth, depth + 1);
      expect(plan.system.drift(), isEmpty);
      plan.doc.commands.undo();
      // ignore: avoid_print
      print('Q3c undo of a dissolve: save equal ${save(plan.doc) == saved}, '
          'canonical equal ${canonical(plan.doc) == saved}');
      expect(canonical(plan.doc), saved);
      plan.doc.commands.redo();
      expect(alive(plan.doc, left), isFalse);
      plan.doc.commands.undo();
      // Past it: x = 1000; the seed's face among the left room's
      // references is open to the east.
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (1000, 0), e: (1000, 4000)));
      expect(alive(plan.doc, left), isFalse);
      // Right: (7900 - 1050) x 3800 = 26,030,000.
      expect(labelsOf(plan.doc, right), ['Right', '26.03 m²']);
      expect(plan.system.drift(), isEmpty);
    });

    test('the face becomes unbounded: the west wall shortened by 1000', () {
      final plan = buildPlan(twoRoomWalls, place: corpus);
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
      final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
      setWall(plan, plan.walls[3],
          (_) => movedWall(plan, plan.walls[3], e: (0, 1000)));
      expect(alive(plan.doc, left), isFalse);
      expect(labelsOf(plan.doc, right), ['Right', '18.43 m²']);
      expect(plan.system.drift(), isEmpty);
    });

    test(
        'a bounding wall shortened: 60 mm (inside the band) keeps both, '
        '150 mm (a 50 mm gap) breaks both', () {
      final plan = buildPlan(twoRoomWalls, place: corpus);
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
      final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (3000, 60)));
      // ignore: avoid_print
      print('Q3c shortened 60: ${labelsOf(plan.doc, left)} '
          '${labelsOf(plan.doc, right)}');
      expect(labelsOf(plan.doc, left), ['Left', '10.83 m²']);
      expect(labelsOf(plan.doc, right), ['Right', '18.43 m²']);
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (3000, 150)));
      expect(alive(plan.doc, left), isFalse);
      expect(alive(plan.doc, right), isFalse);
      expect(plan.system.drift(), isEmpty);
    });

    test('the separator pulled 50 mm short of a face: both halves dissolve',
        () {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: [sampleSeparator], place: corpusGroups);
      final dining = clickRoom(plan.doc, plan.at(19000, 14000), 'Dining')!;
      final living = clickRoom(plan.doc, plan.at(22500, 14000), 'Living')!;
      expect(labelsOf(plan.doc, dining), ['Dining', '23.04 m²']);
      expect(labelsOf(plan.doc, living), ['Living', '21.90 m²']);
      final sep = plan.seps.single;
      final p = plan.doc.components.get<SeparatorParams>(sep)!;
      final inv = plan.doc.tree.accumulatedTransform(sep).invert();
      final e = inv.transformPoint(plan.at(21500, 16700));
      plan.doc.commands.execute(SetComponentCommand<SeparatorParams>(
          sep, SeparatorParams(p.sx, p.sy, e.x, e.y)));
      expect(alive(plan.doc, dining), isFalse);
      expect(alive(plan.doc, living), isFalse);
      expect(plan.system.drift(), isEmpty);
    });

    test(
        'decision 9: deleting a bounding wall cascades; decision 13: '
        'deleting the island orphans (the room stays, the hole goes)', () {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: [sampleSeparator], place: corpus);
      final living = clickRoom(plan.doc, plan.at(22500, 14000), 'Living')!;
      final hall = clickRoom(plan.doc, plan.at(14500, 10500), 'Hall')!;
      expect(plan.doc.components.get<RoomParams>(living)!.islands,
          [plan.walls[9]]);
      final column = plan.walls[9];
      final depth = plan.doc.commands.undoDepth;
      plan.doc.commands.execute(CompoundCommand([
        for (final k in kids(plan.doc, column))
          if (kindOf(plan.doc, k) != EntityKind.fill) RemoveEntityCommand(k),
        RemoveNodeCommand(column),
      ], label: 'Delete'));
      expect(alive(plan.doc, living), isTrue);
      expect(labelsOf(plan.doc, living), ['Living', '22.06 m²']);
      expect(plan.doc.commands.undoDepth, depth + 1);
      final diags = plan.system.diagnostics();
      expect(diags.where((d) => d.code == 'parametric.orphan'), hasLength(1));
      // The hall's west wall E4.
      final e4 = plan.walls[3];
      plan.doc.commands.execute(CompoundCommand([
        for (final k in kids(plan.doc, e4))
          if (kindOf(plan.doc, k) != EntityKind.fill) RemoveEntityCommand(k),
        RemoveNodeCommand(e4),
      ], label: 'Delete'));
      expect(alive(plan.doc, hall), isFalse);
      expect(alive(plan.doc, living), isTrue);
      expect(plan.system.drift(), isEmpty);
    });
  });

  // -----------------------------------------------------------------------
  // Q5: the room object end to end.
  group('Q5 the room on the ParametricSystem', () {
    test('children: tint (translucent, unpickable), name, area', () {
      final plan = buildPlan(twoRoomWalls, place: corpusGroups);
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Room 1')!;
      final ks = kids(plan.doc, left);
      // ignore: avoid_print
      print(
          'Q5 children ${ks.map((k) => '${k.value}:${kindOf(plan.doc, k).name}')}');
      expect([
        for (final k in ks) kindOf(plan.doc, k)
      ], [
        EntityKind.fill,
        EntityKind.polyline,
        EntityKind.text,
        EntityKind.text
      ]);
      final fill = recordOf(plan.doc, ks[0]);
      expect(fill.transparency, kRoomTintTransparency);
      expect(fill.flags & EntityFlags.unpickable, isNonZero);
      expect(recordOf(plan.doc, ks[2]).text, 'Room 1');
      expect(recordOf(plan.doc, ks[3]).text, '10.83 m²');
      expect(recordOf(plan.doc, ks[2]).textAttrs,
          packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle));
    });

    test(
        'a wall moved: shape, area and label follow, one undo step, same '
        'child handles; undo, redo; save -> load -> save', () {
      final plan = buildPlan(twoRoomWalls, place: corpusGroups);
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
      final right = clickRoom(plan.doc, plan.at(5500, 2000), 'Right')!;
      final kl = kids(plan.doc, left), kr = kids(plan.doc, right);
      final depth = plan.doc.commands.undoDepth;
      final saved = save(plan.doc);
      setWall(plan, plan.walls[4],
          (_) => movedWall(plan, plan.walls[4], s: (3500, 0), e: (3500, 4000)));
      // Left (3450 - 100) x 3800 = 12,730,000; right (7900 - 3550) x 3800 =
      // 16,530,000.
      expect(labelsOf(plan.doc, left), ['Left', '12.73 m²']);
      expect(labelsOf(plan.doc, right), ['Right', '16.53 m²']);
      expect(kids(plan.doc, left), kl);
      expect(kids(plan.doc, right), kr);
      expect(plan.doc.commands.undoDepth, depth + 1);
      expect(plan.system.drift(), isEmpty);
      final moved = save(plan.doc);
      plan.doc.commands.undo();
      expect(save(plan.doc), saved);
      expect(labelsOf(plan.doc, left), ['Left', '10.83 m²']);
      plan.doc.commands.redo();
      expect(save(plan.doc), moved);
      final re = load(moved);
      expect(save(re), moved);
      final sys = ParametricSystem(re, parametricCatalog);
      expect(sys.drift(), isEmpty);
    });

    test('the sample plan\'s east wall dragged out by 500 at its nodes', () {
      final plan = buildPlan(sampleWalls(), place: corpus);
      final bath = clickRoom(plan.doc, plan.at(23500, 10000), 'Bath')!;
      final living = clickRoom(plan.doc, plan.at(21000, 14000), 'Living')!;
      final hall = clickRoom(plan.doc, plan.at(14500, 10500), 'Hall')!;
      final w = plan.walls;
      plan.doc.commands.execute(CompoundCommand([
        SetComponentCommand<WallParams>(
            w[0], movedWall(plan, w[0], e: (26375, 8125))),
        SetComponentCommand<WallParams>(
            w[1], movedWall(plan, w[1], s: (26375, 8125), e: (26375, 16875))),
        SetComponentCommand<WallParams>(
            w[2], movedWall(plan, w[2], s: (26375, 16875))),
        SetComponentCommand<WallParams>(
            w[6], movedWall(plan, w[6], e: (26375, 11500))),
      ], label: 'Drag'));
      // Bath (26250 - 21560) x 3190 = 4690 x 3190 = 14,961,100;
      // Living (26250 - 17060) x 5190 = 9190 x 5190 = 47,696,100.
      expect(labelsOf(plan.doc, bath), ['Bath', '14.96 m²']);
      expect(labelsOf(plan.doc, living), ['Living', '47.70 m²']);
      expect(labelsOf(plan.doc, hall), ['Hall', '22.00 m²']);
      expect(plan.system.drift(), isEmpty);
    });

    test('a page change (unit, scale) regenerates every room, one step', () {
      final plan = buildPlan(twoRoomWalls, place: corpus);
      PageComponent.register(plan.doc.components);
      plan.doc.commands.execute(SetComponentCommand<PageComponent>(
          plan.doc.rootHandle, PageComponent(scaleDenominator: 50)));
      final left = clickRoom(plan.doc, plan.at(1500, 2000), 'Left')!;
      final texts = [
        for (final k in kids(plan.doc, left))
          if (kindOf(plan.doc, k) == EntityKind.text) k
      ];
      expect(payloadOf(plan.doc, texts[0]).scalars[0], 125);
      final depth = plan.doc.commands.undoDepth;
      final page = plan.doc.components.get<PageComponent>(plan.doc.rootHandle)!;
      plan.doc.commands.execute(SetComponentCommand<PageComponent>(
          plan.doc.rootHandle,
          page.copyWith(
              displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
      // 10,830,000 mm2 / 304.8^2 = 10,830,000 / 92,903.04 = 116.57 ft2.
      expect(labelsOf(plan.doc, left), ['Left', '116.57 ft²']);
      expect(payloadOf(plan.doc, texts[0]).scalars[0], 250);
      expect(payloadOf(plan.doc, texts[1]).scalars[0], 200);
      expect(plan.doc.commands.undoDepth, depth + 1);
      expect(plan.system.drift(), isEmpty);
      plan.doc.commands.undo();
      expect(labelsOf(plan.doc, left), ['Left', '10.83 m²']);
    });

    test('the tint\'s holes: a keyholed ring the triangulator accepts', () {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: [sampleSeparator], place: corpusGroups);
      final living = clickRoom(plan.doc, plan.at(22500, 14000), 'Living')!;
      final ks = kids(plan.doc, living);
      final boundary = ks[1];
      final pts = payloadOf(plan.doc, boundary).coords.length ~/ 2;
      final tri =
          triangulationFor(EntityKind.polyline, payloadOf(plan.doc, boundary))!;
      // ignore: avoid_print
      print('Q5 Living tint: $pts stored points, ${tri.length ~/ 3} '
          'triangles');
      expect(tri, isNotEmpty);
      // The same keyhole without the slit (the bridge two coincident
      // edges) is refused by the engine's triangulator.
      final t = (verdictOf(plan, living) as RoomOk).trace;
      final exact = triangulationFor(EntityKind.polyline,
          polylinePayload(keyhole(t.ring, t.holes, slit: 0), closed: true))!;
      // ignore: avoid_print
      print('Q5 exact keyhole: ${exact.length ~/ 3} triangles');
      expect(exact, isEmpty);
    });
  });
}
