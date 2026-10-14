// Spec 2a E2: a frozen object is left out of every survey, view and
// regeneration and is a plain group to the system; no hook of its type is
// called for it. F and N overlap and each reads the other; P and Q are
// place contributors that S reads. Every object sits off the origin at a
// rotation, and each test first shows the relation the freeze then cuts.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/frozen_clients.dart';

void main() {
  setUp(resetHooks);

  test(
      'E2-1 an edit of a neighbour calls no hook of a frozen object, which '
      'keeps its geometry and is in no view', () {
    final s = frozenScene();
    // Fixture: F and N see each other, four edges and one tick each.
    expect(childrenOf(s.doc, hF), hasLength(5));
    expect(childrenOf(s.doc, hN), hasLength(5));
    s.frozen.add(hF);
    final kept = geometryOf(s.doc, hF);
    resetHooks();
    Tile.watch = hF;
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 450, 950)));
    // M-E2a, M-E2b, M-E2c: F's reach or generate is called.
    expect(callsOf('F'), isEmpty);
    expect(geometryOf(s.doc, hF), kept);
    final sight = tileSights['N']!;
    expect(sight.neighbours, isEmpty);
    expect(sight.tiles, [hN]);
    expect(sight.watched, isNull);
    expect(childrenOf(s.doc, hN), hasLength(4),
        reason: 'its tick to F is gone');

    // Positive control: unfrozen, F is N's neighbour again, regenerates,
    // and its tick follows N's new size.
    s.frozen.remove(hF);
    resetHooks();
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 500, 980)));
    expect(callsOf('F'), contains('generate F'));
    expect(geometryOf(s.doc, hF), isNot(kept));
  });

  test(
      'E2-2 a place reader does not read a frozen contributor, whose hooks '
      'are not called', () {
    final s = frozenScene(tiles: false, places: true);
    expect(childrenOf(s.doc, hS), hasLength(6),
        reason: 'fixture: S reads P, Q');
    s.frozen.add(hP);
    resetHooks();
    s.doc.commands
        .execute(SetComponentCommand<Plate>(hQ, const Plate('Q', 350, 320)));
    expect(hookCalls, contains('generate S'), reason: "Q's place changed");
    // M-E2a, M-E2b: S finds P placed. M-E2c: P's reach or place box is
    // asked in the before-view.
    expect(scopeSights['S'], [hQ]);
    expect(callsOf('P'), isEmpty);
    expect(childrenOf(s.doc, hS), hasLength(5));
  });

  test(
      'E2-3 a frozen object is a plain group: its children are edited '
      'directly, and it moves without regenerating', () {
    final s = frozenScene();
    final child = childrenOf(s.doc, hF).first;
    final moved = linePayload(Vector2(15, 25), Vector2(1985.5, 30.25));
    // Positive control: a live object's child is generated (spec 06 D6).
    expect(() => s.doc.commands.execute(SetEntityGeometryCommand(child, moved)),
        throwsA(isA<GeneratedGeometryError>()));
    s.frozen.add(hF);
    // M-E2d: refused as a generated child.
    s.doc.commands.execute(SetEntityGeometryCommand(child, moved));
    expect(
        s.doc.geometry
            .read(s.doc.entities.geomIndexAt(s.doc.entities.slotOf(child)!))
            .coords,
        moved.coords);
    resetHooks();
    s.doc.commands.execute(TransformNodeCommand(
        hF, atF.multiply(Transform2.translation(-300, 450))));
    expect(callsOf('F'), isEmpty);
  });

  test(
      'E2-4 a new value of its type written on a frozen object is refused, '
      'and nothing changes', () {
    final s = frozenScene();
    s.frozen.add(hF);
    final before = encoded(s.doc);
    final depth = s.doc.commands.undoDepth;
    // M-E2e: the write lands, and would never be regenerated.
    expect(
        () => s.doc.commands.execute(
            SetComponentCommand<Tile>(hF, const Tile('F', 2600, 1000))),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('would never be regenerated'))));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.undoDepth, depth);
  });

  test('E2-5 drift() neither lists a frozen object nor calls it', () {
    final s = frozenScene();
    s.frozen.add(hF);
    // F's tick still reads N's old size: F is stale.
    s.doc.commands
        .execute(SetComponentCommand<Tile>(hN, const Tile('N', 450, 950)));
    resetHooks();
    // M-E2f: drift's survey holds F, and lists it.
    expect(s.system.drift(), isEmpty);
    expect(callsOf('F'), isEmpty);
    // Positive control: unfrozen, F is stale and N would draw its tick to F
    // again.
    s.frozen.remove(hF);
    expect(s.system.drift(), [hF, hN]);
  });

  test(
      'E2-6 diagnostics() reports nothing of a frozen object and calls none '
      'of its hooks', () {
    final s = frozenScene();
    // Positive control: one entry per live tile.
    expect([
      for (final d in s.system.diagnostics()) d.handles
    ], [
      [hF],
      [hN],
    ]);
    s.frozen.add(hF);
    resetHooks();
    final report = s.system.diagnostics();
    // M-E2g: F's diagnose runs. M-E2h: F is reported misplaced.
    expect([for (final d in report) d.code], ['test.tile']);
    expect(report.single.handles, [hN]);
    expect(callsOf('F'), isEmpty);
  });

  test(
      'E2-7 a cascade referrer of a frozen object sees a dead handle: its '
      'edit is refused as dangling', () {
    final s = frozenScene();
    s.doc.commands
        .execute(place(s.doc, hR, atR, const Tile('R', 300, 250, ref: hF)));
    s.frozen.add(hF);
    final before = encoded(s.doc);
    final depth = s.doc.commands.undoDepth;
    // M-E2a: F is still a live referent, and the edit lands.
    expect(
        () => s.doc.commands.execute(
            SetComponentCommand<Tile>(hR, const Tile('R', 320, 250, ref: hF))),
        throwsA(isA<DanglingReferenceError>()
            .having((e) => e.object, 'object', hR)
            .having((e) => e.referent, 'referent', hF)));
    expect(encoded(s.doc), before);
    expect(s.doc.commands.undoDepth, depth);
    // Positive control: unfrozen, the same edit lands.
    s.frozen.remove(hF);
    s.doc.commands.execute(
        SetComponentCommand<Tile>(hR, const Tile('R', 320, 250, ref: hF)));
    expect(s.doc.components.get<Tile>(hR), const Tile('R', 320, 250, ref: hF));
  });
}
