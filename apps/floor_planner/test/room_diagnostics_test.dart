// Spec 10 D22: what rooms and separators report. `room.shared` once per
// pair by the lower handle; `room.broken` (an error) for a file's room whose
// seed is in a wall or in no bounded face, which `drift()` names too and
// which no unrelated edit trips over; `room.tint` for a fallback step;
// `room.degenerate` and `separator.degenerate` for a file's non-finite or
// too short values.
//
// A page is attached (1:50, metres). DG1 and DG2 run at the origin and at
// the corpus far origin in own groups. Expected areas are hand arithmetic,
// next to the assertion, at least 0.0005 m² from a rounding tie.
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_label.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The two-room fixture's right seed, plan mm (fractional).
const (double, double) rightSeed = (5487.75, 2012.5);

/// The two-room fixture's partition (wall 4) moved 250.5 mm east: x 3,250.5.
const W movedPartition = W(3250.5, 0, 3250.5, 4000, 100);

/// The room diagnostics of [doc].
List<Diagnostic> roomDiagnostics(DraftDocument doc) =>
    codedAs(diagnosticsOf(doc), 'room.');

/// `room.shared` for [a] (the lower handle) and [b], named [na] and [nb].
Diagnostic shared(Handle a, String na, Handle b, String nb) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'room.shared',
      message: '$na and $nb share a space',
      handles: [a, b],
    );

/// `room.degenerate` for [h], named [name].
Diagnostic degenerate(Handle h, String name) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'room.degenerate',
      message: 'room ${h.toHex()} ("$name") has a label offset that is not '
          'finite: its labels sit at the pole',
      handles: [h],
    );

/// `separator.degenerate` for [h].
Diagnostic shortSeparator(Handle h) => Diagnostic(
      severity: DiagnosticSeverity.error,
      code: 'separator.degenerate',
      message: 'separator ${h.toHex()} is no longer than the trace tolerance '
          'or has an end that is not finite: it splits no room and draws '
          'nothing',
      handles: [h],
    );

/// The pole of the face around world [seed], through the document adapter.
Vector2 poleIn(DraftDocument doc, Vector2 seed) {
  final t = faceAt(doc, seed) as Traced;
  return poleOfInaccessibility(t.ring, t.holes).point;
}

void main() {
  tearDown(() => debugTintFailedSteps = null);

  test(
      'DG1 room.shared is reported once per pair, by the lower handle; three '
      'rooms in one face give three entries', () {
    for (final place in [origin, corpusGroups]) {
      // One face, the box's 7,800 × 3,800 = 29,640,000 (29.64, 0.005 from
      // the ties), three rooms in it.
      const seeds = {
        'Den': (1000.25, 1000.5),
        'Study': (4000.75, 2000.25),
        'Nook': (7000.5, 3000.25),
      };
      for (final order in [
        ['Den', 'Study', 'Nook'],
        ['Nook', 'Study', 'Den'],
      ]) {
        final plan = buildPlan(boxWalls, place: place);
        final doc = plan.doc;
        attachPage(doc, PageComponent());
        final h = {
          for (final n in order)
            n: addRoom(doc, plan.at(seeds[n]!.$1, seeds[n]!.$2), n),
        };
        for (final n in order) {
          expect(labelStrings(doc, h[n]!), [n, '29.64 m²'],
              reason: '$n at $place');
        }
        // The lower handle reports each higher room, handles [lower,
        // higher], the lower's name first: built in the other order, the
        // reporter and the names swap.
        final [a, b, c] = order;
        expect(
            roomDiagnostics(doc),
            [
              shared(h[a]!, a, h[b]!, b),
              shared(h[a]!, a, h[c]!, c),
              shared(h[b]!, b, h[c]!, c),
            ],
            reason: '$order at $place');
        expect(driftOf(doc), isEmpty, reason: '$order at $place');

        // Who reports: the middle room's own room.degenerate comes after
        // its room.shared entries and before the highest room's, in
        // diagnostics()' ascending handle order. Were the higher room the
        // reporter, the middle room's pair with the lowest would come first
        // and its room.degenerate second.
        doc.commands.execute(SetComponentCommand<RoomParams>(
            h[b]!,
            doc.components
                .get<RoomParams>(h[b]!)!
                .copyWith(label: (double.nan, 1.5))));
        expect(
            roomDiagnostics(doc),
            [
              shared(h[a]!, a, h[b]!, b),
              shared(h[a]!, a, h[c]!, c),
              shared(h[b]!, b, h[c]!, c),
              degenerate(h[b]!, b),
            ],
            reason: 'the reporter, $order at $place');
        expect(driftOf(doc), isEmpty, reason: '$order at $place');
      }

      // Another room's seed is read through its own group: a room in a
      // turned, translated group (a file's), its world seed at plan
      // (4,000.75, 2,000.25), shares the box with Den.
      {
        final plan = buildPlan(boxWalls, place: place);
        final doc = plan.doc;
        attachPage(doc, PageComponent());
        final den = addRoom(doc, plan.at(1000.25, 1000.5), 'Den');
        final g = place.m
            .multiply(Transform2.translation(9000.5, -1200.25))
            .multiply(Transform2.rotation(0.61));
        final bay = addRoom(doc, plan.at(4000.75, 2000.25), 'Bay', at: g);
        // Premise: the stored (local) seed, read as a world point, lies
        // outside the face, so only the group's map puts it inside.
        final local = doc.components.get<RoomParams>(bay)!.seed;
        final face = faceAt(doc, plan.at(1000.25, 1000.5)) as Traced;
        expect(pointInRing(local, face.ring), isFalse,
            reason: 'the premise: local seed $local at $place');
        expect(pointInRing(plan.at(4000.75, 2000.25), face.ring), isTrue);
        expect(labelStrings(doc, bay), ['Bay', '29.64 m²'], reason: '$place');
        expect(roomDiagnostics(doc), [shared(den, 'Den', bay, 'Bay')],
            reason: 'a turned group at $place');
        expect(driftOf(doc), isEmpty, reason: '$place');
      }

      // A seed in a hole is not in the face: a room in the hollow column's
      // courtyard (x 5,050..5,550, y 1,550..2,050) and the room around the
      // column, the lower handle, share nothing.
      final plan = boxAndSeparatorPlan(place);
      final doc = plan.doc;
      attachPage(doc, PageComponent());
      final outer = addRoom(doc, plan.at(6512.25, 3012.75), 'Hall');
      final court = addRoom(doc, plan.at(5300.25, 1800.5), 'Courtyard');
      // 4,900 × 3,800 − 700 × 700 = 18,130,000 (18.13); the courtyard 500 ×
      // 500 = 250,000 (0.25, 0.005 from the ties).
      expect(labelStrings(doc, outer), ['Hall', '18.13 m²']);
      expect(labelStrings(doc, court), ['Courtyard', '0.25 m²']);
      // Premise: the courtyard seed lies inside the Hall's outer ring, in
      // its hole.
      final face = faceAt(doc, plan.at(6512.25, 3012.75)) as Traced;
      final courtSeed = plan.at(5300.25, 1800.5);
      expect(pointInRing(courtSeed, face.ring), isTrue);
      expect(face.holes.where((r) => pointInRing(courtSeed, r)), hasLength(1));
      expect(roomDiagnostics(doc), isEmpty, reason: 'the courtyard at $place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });

  test(
      'DG2 a loaded room whose seed is in a wall is room.broken, and drift() '
      'names it; an unrelated edit is not refused', () {
    for (final place in [origin, corpusGroups]) {
      final plan = buildPlan(twoRoomWalls, place: place);
      attachPage(plan.doc, PageComponent());
      final right =
          addRoom(plan.doc, plan.at(rightSeed.$1, rightSeed.$2), 'Room 2');
      // A file with two rooms no program regenerated: one seeded in the
      // partition's band (x 2,950..3,050), one outside the box.
      late final Handle inWall, outside;
      final file = staleFile(plan.doc, (bare) {
        inWall = addRoom(bare, plan.at(3000.25, 2000.5), 'Wall room');
        outside = addRoom(bare, plan.at(-2000.5, 1000.25), 'Outside');
      });
      final doc = reloadWithPage(file);
      final partition = plan.walls[4];
      // Premises: neither has a child; the first seed is in the partition.
      expect(kids(doc, inWall), isEmpty);
      expect(kids(doc, outside), isEmpty);
      expect(faceAt(doc, plan.at(3000.25, 2000.5)), isA<SeedInWall>());
      expect(
          roomDiagnostics(doc),
          [
            Diagnostic(
              severity: DiagnosticSeverity.error,
              code: 'room.broken',
              message: 'room ${inWall.toHex()} ("Wall room") has its seed in '
                  '${partition.toHex()}, a wall or a separator: it has no face',
              handles: [inWall, partition],
            ),
            Diagnostic(
              severity: DiagnosticSeverity.error,
              code: 'room.broken',
              message:
                  'room ${outside.toHex()} ("Outside") has no bounded face '
                  'around its seed',
              handles: [outside],
            ),
          ],
          reason: '$place');
      expect(driftOf(doc), [inWall, outside], reason: '$place');

      // An unrelated edit lands: the right room renamed.
      final depth = doc.commands.undoDepth;
      doc.commands.execute(renameRoom(doc, right, 'Store'));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      // x 3,050..7,900: 4,850 × 3,800 = 18,430,000 (18.43).
      expect(labelStrings(doc, right), ['Store', '18.43 m²'], reason: '$place');
      expect(doc.components.get<RoomParams>(inWall), isNotNull);
      expect(driftOf(doc), [inWall, outside], reason: '$place');

      // A wall edit at its seed regenerates it (its read box holds its seed
      // even with no stored child): the partition moved east, off the seed,
      // which now lies in the left face, x 100..3,200.5: 3,100.5 × 3,800 =
      // 11,781,900 (11.78, 0.0031 from 11.785).
      doc.commands.execute(moveWall(plan, 4, movedPartition, doc: doc));
      expect(labelStrings(doc, inWall), ['Wall room', '11.78 m²'],
          reason: '$place');
      // x 3,300.5..7,900: 4,599.5 × 3,800 = 17,478,100 (17.48).
      expect(labelStrings(doc, right), ['Store', '17.48 m²'], reason: '$place');
      expect(driftOf(doc), [outside], reason: '$place');
      expect(
          roomDiagnostics(doc),
          [
            Diagnostic(
              severity: DiagnosticSeverity.error,
              code: 'room.broken',
              message:
                  'room ${outside.toHex()} ("Outside") has no bounded face '
                  'around its seed',
              handles: [outside],
            ),
          ],
          reason: '$place');

      // A broken room shares no face: a file's room seeded within
      // roomTrace.linear inside the partition's west face (x 2,950), so
      // inside the left room's ring yet SeedInWall (the review's P5).
      final plan2 = buildPlan(twoRoomWalls, place: place);
      attachPage(plan2.doc, PageComponent());
      final left = addRoom(plan2.doc, plan2.at(1512.5, 1987.25), 'Room 1');
      for (final off in [2e-7, 5e-7, 9e-7]) {
        final seed = plan2.at(2950 - off, 2000.5);
        late final Handle edge;
        final doc2 = reloadWithPage(staleFile(plan2.doc, (bare) {
          edge = addRoom(bare, seed, 'Edge');
        }));
        // Premises: the seed is inside the left face's ring, and in a wall.
        final face = faceAt(doc2, plan2.at(1512.5, 1987.25)) as Traced;
        expect(pointInRing(seed, face.ring), isTrue,
            reason: 'the premise: in the ring, $off at $place');
        final inWall = faceAt(doc2, seed);
        expect(inWall, isA<SeedInWall>(), reason: '$off at $place');
        final source = (inWall as SeedInWall).source;
        expect(
            roomDiagnostics(doc2),
            [
              Diagnostic(
                severity: DiagnosticSeverity.error,
                code: 'room.broken',
                message: 'room ${edge.toHex()} ("Edge") has its seed in '
                    '${source.toHex()}, a wall or a separator: it has no face',
                handles: [edge, source],
              ),
            ],
            reason: 'no room.shared with a broken room, $off at $place');
        expect(driftOf(doc2), [edge], reason: '$off at $place');
        expect(labelStrings(doc2, left), ['Room 1', '10.83 m²']);
      }
    }
  });

  test('DG3 room.tint reports a fallback step and a hole left out', () {
    for (final place in [origin, corpusGroups]) {
      // The box with a 400 × 400 column: 29,640,000 − 160,000 = 29,480,000
      // (29.48, 0.005 from the ties).
      final plan = buildPlan(
          [...boxWalls, const W(4000.5, 2000.25, 4400.5, 2000.25, 400)],
          place: place);
      final doc = plan.doc;
      attachPage(doc, PageComponent());
      final room = addRoom(doc, plan.at(1000.25, 3000.5), 'Room 1');
      expect(labelStrings(doc, room), ['Room 1', '29.48 m²']);
      expect(roomDiagnostics(doc), isEmpty, reason: 'step 1 at $place');

      // diagnose reads the very decision generate takes: with a step failed
      // (Ruling 10-16) it reports it, and the stored step-1 tint drifts.
      Diagnostic tint(String why) => Diagnostic(
            severity: DiagnosticSeverity.warning,
            code: 'room.tint',
            message: 'room ${room.toHex()} ("Room 1"): $why',
            handles: [room],
          );
      debugTintFailedSteps = {1};
      expect(
          roomDiagnostics(doc),
          [
            tint('its tint covers its holes: the keyholed ring does not '
                'triangulate'),
          ],
          reason: 'step 2 at $place');
      expect(driftOf(doc), [room], reason: 'step 2 at $place');
      debugTintFailedSteps = {1, 2};
      expect(
          roomDiagnostics(doc),
          [
            tint('its tint is an unfilled outline: its face does not '
                'triangulate'),
          ],
          reason: 'step 3 at $place');
      doc.commands.execute(renameRoom(doc, room, 'Room 1'));
      expect(kindsOf(doc, room),
          [EntityKind.text, EntityKind.text, EntityKind.polyline],
          reason: 'step 3 stored at $place');
      expect(driftOf(doc), isEmpty, reason: 'step 3 at $place');
      debugTintFailedSteps = null;
      expect(roomDiagnostics(doc), isEmpty, reason: 'no seam at $place');
      expect(driftOf(doc), [room], reason: 'no seam at $place');
      // A hole left out of the keyhole (`Tint.holesLeftOut`) is also
      // `room.tint` (`Tint.isExact`, pinned by TN1), but no real trace
      // leaves one out (Tint's doc, Eberly's argument): diagnose reports
      // `!isExact`, the same test.
    }
  });

  test(
      'DG4 separator.degenerate for a short or non-finite separator, '
      'room.degenerate for a non-finite label', () {
    final plan = buildPlan(twoRoomWalls);
    final doc = plan.doc;
    attachPage(doc, PageComponent());
    final room = addRoom(doc, plan.at(rightSeed.$1, rightSeed.$2), 'Room 2');
    // Separators above the box (y > 4,100), at the identity: one of length
    // zero, one exactly roomTrace.linear long (degenerate: not more than
    // it), one twice that (not degenerate).
    final zero =
        addSeparator(doc, Vector2(1000.5, 5000.25), Vector2(1000.5, 5000.25));
    final s = Vector2(0, 6000.25), e = Vector2(roomTrace.linear, 6000.25);
    expect((e - s).length, roomTrace.linear, reason: 'the premise: exact');
    final exact = addSeparator(doc, s, e);
    final twice = addSeparator(
        doc, Vector2(0, 7000.25), Vector2(2 * roomTrace.linear, 7000.25));
    expect(kids(doc, zero), isEmpty);
    expect(kids(doc, exact), isEmpty, reason: 'no input, nothing drawn');
    expect(kindsOf(doc, twice), [EntityKind.polyline]);

    // A file whose separator's end and a room's label read 1e999: JSON's
    // way to write a non-finite number, which decodes to infinity.
    late final Handle farEnd, store;
    final file = staleFile(doc, (bare) {
      farEnd = addSeparator(
          bare, Vector2(9000.5, 6000.25), Vector2(7777.125, 6000.25));
      store = addRoom(bare, plan.at(6800.25, 1000.5), 'Store',
          label: (4321.375, 5.5));
    });
    for (final v in ['7777.125', '4321.375']) {
      expect(v.allMatches(file), hasLength(1), reason: 'the premise: $v');
    }
    final loaded = reloadWithPage(file
        .replaceFirst('7777.125', '1e999')
        .replaceFirst('4321.375', '1e999'));
    expect(loaded.components.get<SeparatorParams>(farEnd)!.ex, double.infinity);
    expect(
        loaded.components.get<RoomParams>(store)!.label!.$1, double.infinity);
    expect(codedAs(diagnosticsOf(loaded), 'separator.'), [
      shortSeparator(zero),
      shortSeparator(exact),
      shortSeparator(farEnd),
    ]);
    expect(roomDiagnostics(loaded), [
      shared(room, 'Room 2', store, 'Store'),
      degenerate(store, 'Store'),
    ]);
    // The file's room has no child yet; a rename regenerates it, its labels
    // at the pole of its face (x 3,050..7,900, y 100..3,900: 18.43 m²).
    expect(driftOf(loaded), [store]);
    loaded.commands.execute(renameRoom(loaded, store, 'Pantry'));
    expect(labelStrings(loaded, store), ['Pantry', '18.43 m²']);
    expect(
        (anchorOf(loaded, store) - poleIn(loaded, plan.at(6800.25, 1000.5)))
            .length,
        lessThan(1e-6),
        reason: 'the labels at the pole');
    expect(roomDiagnostics(loaded), [
      shared(room, 'Room 2', store, 'Pantry'),
      degenerate(store, 'Pantry'),
    ]);
    expect(driftOf(loaded), isEmpty);

    // A wall whose ring is not finite (a finite, enormous thickness 1.7e308
    // at y 1e308 overflows its band): no input to rooms, through either
    // adapter, and U stays the finite box's.
    final wall = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: wall,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      SetComponentCommand<WallParams>(
          wall,
          const WallParams(
              0, 1e308, 1000, 1e308, 1.7e308, Justification.centre)),
    ], label: 'Add wall'));
    final inputs = RoomInputs(doc);
    expect(inputs.inputOf(wall), isNull, reason: 'the document adapter');
    final u = inputs.bounds!;
    expect([u.minX, u.minY, u.maxX, u.maxY].every((v) => v.isFinite), isTrue,
        reason: 'U: $u');
    inputs.dispose();
    final seen = probeView(doc);
    expect(seen.contributors, contains(wall));
    expect(seen.inputs[wall], isNull, reason: 'the view adapter');
    expect(seen.bounds!.maxY.isFinite, isTrue, reason: 'U in the view');
    expect(labelStrings(doc, room), ['Room 2', '18.43 m²']);
    expect(driftOf(doc), isEmpty);
  });
}
