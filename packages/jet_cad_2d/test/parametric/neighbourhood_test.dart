import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// drift() on a document that already has a system installed: build a
/// second, uninstalled system over it, which only reads.
List<Handle> driftOf(DraftDocument doc) =>
    ParametricSystem(doc, catalog).drift();

void main() {
  test('N1 the pair clips each other: A 5, B 3, and no drift', () {
    final doc = paramDoc();
    pair(doc);
    expect(kids(doc, hA), hasLength(5));
    expect(kids(doc, hB), hasLength(3));
    expect(driftOf(doc), isEmpty);
  });

  test('N2 an edit of A changes B too (M-06d)', () {
    final doc = paramDoc();
    pair(doc);
    final b = worldSegments(doc, hB);
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    expect(worldSegments(doc, hB), isNot(b));
    expect(driftOf(doc), isEmpty);
  });

  test('N3 moving A away restores B: old neighbours are dirty (M-06l)', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.execute(TransformNodeCommand(hA, parked));
    expect(kids(doc, hB), hasLength(4));
    expect(kids(doc, hA), hasLength(4));
    expect(driftOf(doc), isEmpty);
  });

  test(
      'N4 both transforms matter: B clipped in world by A, both rotated '
      '(M-06g engine)', () {
    final doc = paramDoc();
    pair(doc);
    // Every B child lies outside A's open interior, in world.
    final toA = atA.invert();
    for (final s in worldSegments(doc, hB)) {
      final mid =
          toA.transformPoint(Vector2((s[0] + s[2]) / 2, (s[1] + s[3]) / 2));
      final inside = mid.x > 1e-6 &&
          mid.x < 2000 - 1e-6 &&
          mid.y > 1e-6 &&
          mid.y < 1000 - 1e-6;
      expect(inside, isFalse, reason: 'B piece midpoint in A-local: $mid');
    }
  });

  test(
      'N5 the same edit on a document and its reload gives the same bytes '
      '(M-06b)', () {
    const n1 = Handle(1000), n2 = Handle(2000), s = Handle(3000);
    final x = paramDoc();
    x.commands
        .execute(create(x, n2, onA(0, 1500, 0), const ClipRect(2000, 1000)));
    x.commands.execute(create(x, n1, atA, const ClipRect(2000, 1000)));
    x.commands.execute(create(x, s, parked, const ClipRect(200, 900)));
    final y = reload(enc(x)); // store order [n1, n2, s]; x holds [n2, n1, s]
    for (final d in [x, y]) {
      d.commands.execute(TransformNodeCommand(s, onA(900, 800, 0)));
    }
    expect(kids(x, n1), hasLength(5));
    expect(kids(x, n2), hasLength(5));
    expect(enc(y), enc(x));
  });

  test(
      'N6 two seeds in one command: either child order, same bytes '
      '(M-06b\')', () {
    String run(bool bFirst) {
      final d = paramDoc();
      d.commands.execute(create(d, hA, parked, const ClipRect(2000, 1000)));
      d.commands.execute(create(
          d,
          hB,
          Transform2.translation(-9000, -4000)
              .multiply(Transform2.rotation(0.9)),
          const ClipRect(400, 900)));
      final moves = [
        TransformNodeCommand(hA, atA),
        TransformNodeCommand(hB, atB),
      ];
      d.commands.execute(CompoundCommand(
          bFirst ? moves.reversed.toList() : moves,
          label: 'Move'));
      expect(kids(d, hA), hasLength(5));
      return enc(d);
    }

    expect(run(true), run(false));
  });

  test('N7 per-object world geometry does not depend on creation order', () {
    final x = paramDoc();
    pair(x);
    final y = paramDoc();
    pair(y, bFirst: true);
    expect(worldSegments(y, hA), worldSegments(x, hA));
    expect(worldSegments(y, hB), worldSegments(x, hB));
  });

  test('N8 load then save is byte-identical, typed', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    final s = enc(doc);
    final back = reload(s);
    expect(back.components.get<ClipRect>(hA), const ClipRect(2600, 1400));
    expect(enc(back), s);
  });

  test(
      'N9 stale geometry on file is trusted on load and reported by drift '
      '(M-06f, Ruling 06-7)', () {
    final doc = paramDoc();
    pair(doc);
    final json = jsonDecode(enc(doc)) as Map<String, Object?>;
    final victim = kids(doc, hB).first.value;
    for (final e in json['entities']! as List) {
      final m = e as Map<String, Object?>;
      if ((m['record']! as Map)['handle'] == victim) {
        ((m['geometry']! as Map)['coords']! as List)[0] = 12.5;
      }
    }
    final stale = jsonEncode(json);
    final back = reload(stale);
    expect(enc(back), stale);
    expect(back.commands.undoDepth, 0);
    expect(driftOf(back), [hB]);
  });

  test(
      'N10 undo restores stale geometry exactly: undo never regenerates '
      '(M-06n)', () {
    final doc = paramDoc();
    pair(doc);
    final json = jsonDecode(enc(doc)) as Map<String, Object?>;
    final victim = kids(doc, hB).first.value;
    for (final e in json['entities']! as List) {
      final m = e as Map<String, Object?>;
      if ((m['record']! as Map)['handle'] == victim) {
        ((m['geometry']! as Map)['coords']! as List)[0] = 12.5;
      }
    }
    final back = reload(jsonEncode(json));
    final stale = canon(back);
    back.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 1001)));
    expect(driftOf(back), isEmpty, reason: 'the edit re-generated B');
    back.commands.undo();
    expect(canon(back), stale);
  });

  test('N11 a misplaced component is reported and never regenerated', () {
    final doc = paramDoc();
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    doc.commands.execute(line);
    final h = line.record.handle;
    doc.commands
        .execute(SetComponentCommand<ClipRect>(h, const ClipRect(5, 5)));
    final d = ParametricSystem(doc, catalog).diagnostics();
    expect(d.single.code, 'parametric.misplaced');
    expect(d.single.handles, [h]);
    expect(kids(doc, h), isEmpty);
  });

  test('N12 an edit inside a query walk fails before anything mutates', () {
    final doc = paramDoc();
    final index = SpatialIndex(doc);
    pair(doc);
    final before = enc(doc);
    Object? error;
    index.forEachInRect(
        Aabb2(Vector2(-1e6, -1e6), Vector2(1e6, 1e6)), const QueryFilter.all(),
        (slot) {
      try {
        doc.commands.execute(
            SetComponentCommand<ClipRect>(hA, const ClipRect(100, 100)));
      } catch (e) {
        error ??= e;
      }
    });
    expect(error, isA<QueryReentrancyError>());
    expect(enc(doc), before);
    index.dispose();
  });

  test(
      'N13 rotating A while it overlaps B is one step and re-clips B '
      '(Review Focus 1)', () {
    final doc = paramDoc();
    pair(doc);
    final depth = doc.commands.undoDepth;
    final b = worldSegments(doc, hB);
    final pivot = atA.transformPoint(Vector2(1000, 500));
    final turn = Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(0.25))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));
    doc.commands.execute(CompoundCommand(
        [TransformNodeCommand(hA, turn.multiply(atA))],
        label: 'Rotate'));
    expect(doc.commands.undoDepth, depth + 1);
    expect(worldSegments(doc, hB), isNot(b));
    expect(driftOf(doc), isEmpty);
  });

  test(
      'N14 swallowed whole, then back, with new handles '
      '(Review Focus 3)', () {
    final doc = paramDoc();
    pair(doc);
    final old = kids(doc, hB);
    // B shrinks to 50 x 50 at (800,700) in A-local: wholly inside A.
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hB, const ClipRect(50, 50)));
    expect(kids(doc, hB), isEmpty);
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hB, const ClipRect(400, 900)));
    expect(kids(doc, hB), hasLength(3));
    expect(kids(doc, hB).toSet().intersection(old.toSet()), isEmpty);
    expect(driftOf(doc), isEmpty);
  });
}
