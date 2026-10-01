// Spec 10 D16.6 at the app level: what an edit costs among rooms. A plain
// entity drawn among them asks no type for a place box or a read box
// (RK1); a wall move among many walls and rooms is timed and its rebuilt
// rooms counted (RK2, 06's NC4 method, printed, not asserted: the results
// note records it); a room's rebuild on the sample plan traces no more
// segments than the bound its own run set (LZ3, spec 10 D7).
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/room_fixture.dart';

double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

/// The side of a cell of RK2's layouts, mm.
const double cell = 3000;

/// A grid of [rows] × [cols] cells of [cell], 200 mm centred walls, one wall
/// per cell edge, so four walls meet at every inner node.
List<W> gridWalls(int rows, int cols) => [
      for (var r = 0; r <= rows; r++)
        for (var c = 0; c < cols; c++)
          W(c * cell, r * cell, (c + 1) * cell, r * cell, 200),
      for (var c = 0; c <= cols; c++)
        for (var r = 0; r < rows; r++)
          W(c * cell, r * cell, c * cell, (r + 1) * cell, 200),
    ];

/// [rows] strips, each [cols] cells long: `rows + 1` long exterior walls,
/// 250 mm, the whole length, and in each strip `cols + 1` partitions,
/// 120 mm, teed into the long walls at both ends (07's T).
List<W> stripWalls(int rows, int cols) => [
      for (var r = 0; r <= rows; r++)
        W(0, r * cell, cols * cell, r * cell, 250),
      for (var r = 0; r < rows; r++)
        for (var c = 0; c <= cols; c++)
          W(c * cell, r * cell, c * cell, (r + 1) * cell, 120),
    ];

/// The cells of a [rows] × [cols] layout that hold a room: every
/// [every]-th, counted row by row, and always the two either side of the
/// moved wall ([movedRow], between columns [movedCol] − 1 and [movedCol]).
List<(int, int)> roomCells(
        int rows, int cols, int every, int movedRow, int movedCol) =>
    [
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          if ((r * cols + c) % every == 0 ||
              (r == movedRow && (c == movedCol - 1 || c == movedCol)))
            (r, c),
    ];

/// Adds a room at the centre of each of [cells] of [plan] (a little off
/// it, fractional), one compound.
List<Handle> addRooms(Plan plan, List<(int, int)> cells) {
  final doc = plan.doc;
  final handles = [for (final _ in cells) doc.handleSeed.next()];
  doc.commands.execute(CompoundCommand([
    for (final (i, (r, c)) in cells.indexed) ...[
      AddNodeCommand(GroupNode(
          handle: handles[i],
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      () {
        final s = plan.at((c + 0.5) * cell + 12.25, (r + 0.5) * cell - 7.5);
        return SetComponentCommand<RoomParams>(
            handles[i], RoomParams(s.x, s.y, 'Room ${i + 1}'));
      }(),
    ],
  ], label: 'Add rooms'));
  return handles;
}

/// `LZ3`'s bound: the segments one room's rebuild may trace on the sample
/// plan (spec 10 D7). Set from the plan's own run (Task 18's probe, Ruling
/// 10-20): P5 moved 10 mm east rebuilds the Kitchen and the Bath, 99
/// segments in all; through the document adapter the Kitchen's localised
/// trace takes in 49 and the Bath's 50 (growth to r = 4,000 mm, the
/// certificate, the canonical trace among its four walls). One trace among
/// every contributor takes in 41 (ten bands of 4 segments and the
/// separator's 1), so the growth costs more than tracing everything on a
/// plan of 11 contributors; what it buys is a cost that does not grow with
/// the plan, which `LZ3`'s clutter case pins.
const int kSampleRebuildSegments = 50;

void main() {
  test(
      'LZ3 a room\'s rebuild on the sample plan traces no more segments '
      'than the bound set from the plan\'s run', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);

    /// The sample plan's P5 moved 10 mm east, with [clutter] walls placed
    /// far east of the plan first: the rooms rebuilt, and the segments
    /// their rebuild traced.
    (int, int) moveP5({required int clutter}) {
      final doc = startupPlan(m);
      final system = installParametric(doc);
      addTearDown(system.dispose);
      for (var i = 0; i < clutter; i++) {
        // 3 m walls in a row 40 m east of the plan, 1 m apart, 200 thick:
        // contributors that touch nothing near any room.
        final h = doc.handleSeed.next();
        doc.commands.execute(CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: Transform2.identity(),
              children: const [])),
          SetComponentCommand<WallParams>(
              h,
              WallParams(66000.5 + 4000 * i, 12000.25, 69000.5 + 4000 * i,
                  12000.25, 200, Justification.centre)),
        ], label: 'Add wall'));
      }
      final walls = doc.components.withComponent<WallParams>().toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      final p5 = walls[8];
      final w = doc.components.get<WallParams>(p5)!;
      expect(
          w,
          const WallParams(
              21500, 8125, 21500, 11500, 120, Justification.centre),
          reason: 'premise: P5');
      final rooms = {
        for (final r in doc.components.withComponent<RoomParams>())
          doc.components.get<RoomParams>(r)!.name: r,
      };
      final generates = debugRoomGenerates, segments = debugTracedSegments;
      doc.commands.execute(SetComponentCommand<WallParams>(
          p5,
          WallParams(
              w.sx + 10, w.sy, w.ex + 10, w.ey, w.thickness, w.justification)));
      final rebuilt = debugRoomGenerates - generates;
      final traced = debugTracedSegments - segments;
      expect(rebuilt, 2, reason: 'premise: the Kitchen and the Bath');
      expect(traced, lessThanOrEqualTo(kSampleRebuildSegments * rebuilt),
          reason: 'the rebuild, clutter $clutter');
      // The premise, by hand: the Kitchen grows by 10 mm and the Bath
      // shrinks by 10 mm, (4,380 ± 10) × 3,190 = 14,004,100 ("14.00 m²")
      // and 13,334,200 ("13.33 m²"), each at least 0.0005 m² from a tie.
      expect(labelStrings(doc, rooms['Kitchen']!), ['Kitchen', '14.00 m²']);
      expect(labelStrings(doc, rooms['Bath']!), ['Bath', '13.33 m²']);
      expect(driftOf(doc), isEmpty);

      // Each rebuilt room's own trace, through the document adapter: the
      // same growth, certificate and canonical trace as its view's.
      final inputs = RoomInputs(doc);
      addTearDown(inputs.dispose);
      for (final name in ['Kitchen', 'Bath']) {
        final before = debugTracedSegments;
        final face = traceRoomAmong(
            doc.components.get<RoomParams>(rooms[name]!)!.seed, inputs);
        expect(face, isA<Traced>(), reason: name);
        expect(debugTracedSegments - before,
            lessThanOrEqualTo(kSampleRebuildSegments),
            reason: '$name, clutter $clutter');
      }
      return (rebuilt, traced);
    }

    final (rebuilt, traced) = moveP5(clutter: 0);
    // Forty walls far away change nothing a rebuild traces: the growth
    // never reaches them. Traced among every contributor, each room would
    // take in 160 segments more.
    expect(moveP5(clutter: 40), (rebuilt, traced));
  });

  test(
      'RK1 a line drawn among the sample plan\'s rooms makes no place-box or '
      'read-box call', () {
    final plan = samplePlan(origin);
    final doc = plan.doc;
    final rooms = addSampleRooms(plan);
    // The control: a wall move among the same rooms asks for both (P5, 10
    // mm east: the counters are live).
    var place = debugPlaceBoxCalls, read = debugReadBoxCalls;
    doc.commands
        .execute(moveWall(plan, 8, const W(21510, 8125, 21510, 11500, 120)));
    expect(debugPlaceBoxCalls - place, greaterThan(0), reason: 'the control');
    expect(debugReadBoxCalls - read, greaterThan(0), reason: 'the control');

    // A LINE on the root, across Living and its column, and one across
    // every room's labels, each one command.
    final strings = {
      for (final h in rooms.values) h: labelStrings(doc, h),
    };
    place = debugPlaceBoxCalls;
    read = debugReadBoxCalls;
    final generates = debugRoomGenerates;
    final depth = doc.commands.undoDepth;
    for (final (s, e) in [
      (plan.at(21700.5, 12000.25), plan.at(25600.75, 16500.5)),
      (plan.at(12400.5, 8400.25), plan.at(25600.75, 16500.5)),
    ]) {
      doc.commands.execute(AddEntityCommand(
          record: draftRecord(
              doc.handleSeed.next(), doc.rootHandle, EntityKind.line,
              layer: ReservedHandles.layerZero),
          payload: linePayload(s, e)));
    }
    expect(doc.commands.undoDepth, depth + 2);
    expect(debugPlaceBoxCalls - place, 0, reason: 'place-box calls');
    expect(debugReadBoxCalls - read, 0, reason: 'read-box calls');
    expect(debugRoomGenerates - generates, 0, reason: 'rooms rebuilt');
    expect({
      for (final h in rooms.values) h: labelStrings(doc, h),
    }, strings);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'RK2 a wall move among 100, 300 and 600 walls with a room per four '
      'walls, printed, not asserted', () {
    /// One configuration: the layout [walls] with about [n] walls at
    /// [place], its rooms, the wall move timed; the line RK2 prints.
    String measure(String layout, List<W> Function(int, int) walls,
        Placement place, int n) {
      // The layout's size whose wall count is nearest n: a grid has
      // 2rc + r + c walls, strips r + 1 + r(c + 1); rows ≈ columns for
      // the grid, strips of 10 cells.
      var best = (0, 0, 1 << 30);
      for (var r = 1; r < 80; r++) {
        for (var c = 1; c < 30; c++) {
          if (layout == 'grid' && c != r && c != r + 1) continue;
          if (layout != 'grid' && c != 10) continue;
          final count = walls(r, c).length;
          if ((count - n).abs() < (best.$3 - n).abs()) {
            best = (r, c, count);
          }
        }
      }
      final (rows, cols, count) = best;
      final plan = buildPlan(walls(rows, cols), place: place);
      attachPage(plan.doc, PageComponent());
      final doc = plan.doc;
      // The moved wall: the vertical wall nearest the middle, between
      // two rooms; 20 mm east and back, perpendicular to itself.
      final movedRow = rows ~/ 2, movedCol = cols ~/ 2;
      // A room in every `every`-th cell: one room per four walls.
      final every = (rows * cols * 4 / count).round().clamp(1, 1 << 20);
      final rooms =
          addRooms(plan, roomCells(rows, cols, every, movedRow, movedCol));
      final index = [
        for (var i = 0; i < plan.walls.length; i++)
          if (walls(rows, cols)[i] case W(:final sx, :final sy, :final ex)
              when sx == movedCol * cell &&
                  ex == movedCol * cell &&
                  sy == movedRow * cell)
            i,
      ].single;
      final moved = plan.walls[index];
      final home = (doc.tree[moved]! as GroupNode).transform;
      final d = plan.at(20, 0) - plan.at(0, 0);
      final away = Transform2.translation(d.x, d.y).multiply(home);
      final rebuilt = <int>[];
      double time(int k) {
        final before = debugRoomGenerates;
        final sw = Stopwatch()..start();
        doc.commands
            .execute(TransformNodeCommand(moved, k.isEven ? away : home));
        sw.stop();
        rebuilt.add(debugRoomGenerates - before);
        return sw.elapsedMicroseconds / 1000;
      }

      // Four untimed warm-ups for the JIT: an even number, so the wall
      // ends back home and every timed move is real.
      for (final k in [-4, -3, -2, -1]) {
        time(k);
      }
      rebuilt.clear();
      final moves = [for (var k = 0; k < 5; k++) time(k)];
      expect(driftOf(doc), isEmpty, reason: '$layout $place n=$n');
      expect([
        for (final h in rooms)
          if (doc.components.get<RoomParams>(h) == null) h,
      ], isEmpty, reason: 'every room lives');
      return 'RK2 $layout at $place: $count walls ($rows × $cols), '
          '${rooms.length} rooms; move median '
          '${median(moves).toStringAsFixed(2)} ms '
          '${moves.map((x) => x.toStringAsFixed(2)).toList()}; rooms '
          'rebuilt per move $rebuilt';
    }

    final sweep = [
      for (final (layout, walls) in [
        ('grid', gridWalls),
        ('strips of long exterior walls', stripWalls),
      ])
        for (final place in [origin, corpus])
          for (final n in [100, 300, 600]) (layout, walls, place, n),
    ];
    // A throwaway pass over every configuration first, untimed and
    // unprinted: otherwise the first configurations run cold (the JIT is
    // still compiling the trace, the planner and the regeneration: the
    // 97-wall grid at the origin measured 12-25 ms cold, 5-9 ms after one
    // throwaway configuration, and about 2.5 ms after this pass).
    for (final (layout, walls, place, n) in sweep) {
      measure(layout, walls, place, n);
    }
    for (final (layout, walls, place, n) in sweep) {
      // ignore: avoid_print
      print(measure(layout, walls, place, n));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
