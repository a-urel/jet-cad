import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

void expectWorld(
    DraftDocument doc, Handle g, Transform2 at, double w, double h) {
  final c = [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
      .map(at.transformPoint)
      .toList();
  final got = worldSegments(doc, g);
  expect(got, hasLength(4));
  for (var i = 0; i < 4; i++) {
    final want = [c[i].x, c[i].y, c[(i + 1) % 4].x, c[(i + 1) % 4].y];
    for (var k = 0; k < 4; k++) {
      expect(got[i][k], closeTo(want[k], 1e-9), reason: 'edge $i coord $k');
    }
  }
}

void main() {
  tearDown(() {
    Trip.mode = TripMode.off;
    Trip.document = null;
  });

  test('P1 the first object in an empty document generates (M-06q)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    expectWorld(doc, hA, parked, 2000, 1000);
    for (final k in kids(doc, hA)) {
      expect(doc.entities.kindAt(doc.entities.slotOf(k)!), EntityKind.line);
    }
  });

  test(
      'P2 a width edit regenerates in place, keeping every child handle '
      '(M-06p)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final before = kids(doc, hA);
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)));
    expect(kids(doc, hA), before);
    expectWorld(doc, hA, parked, 3100, 450);
  });

  test(
      'P3 edit plus regeneration is one undo step; undo and redo restore '
      'both, with the same handles (M-06c)', () {
    final doc = paramDoc();
    pair(doc);
    expect(kids(doc, hA), hasLength(5));
    expect(kids(doc, hB), hasLength(3));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    expect(doc.commands.undoDepth, depth + 1);
    final after = canon(doc);
    final handlesAfter = [...kids(doc, hA), ...kids(doc, hB)];
    expect(after, isNot(before));
    doc.commands.undo();
    expect(canon(doc), before);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    doc.commands.redo();
    expect(canon(doc), after);
    expect([...kids(doc, hA), ...kids(doc, hB)], handlesAfter);
  });

  test(
      'P4 the summary says geometry, so the index sees new children '
      '(M-06h)', () {
    final doc = paramDoc();
    final index = SpatialIndex(doc);
    // A at width 500 does not reach B; at 2000 it does, and both re-clip.
    doc.commands.execute(create(doc, hA, atA, const ClipRect(500, 1000)));
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    expect(kids(doc, hA), hasLength(4));
    doc.commands
        .execute(SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 1000)));
    expect(kids(doc, hA), hasLength(5));
    for (final g in [hA, hB]) {
      for (final s in worldSegments(doc, g)) {
        final mid = Vector2((s[0] + s[2]) / 2, (s[1] + s[3]) / 2);
        final found = <Handle>{};
        index.forEachInRect(
            Aabb2(mid - Vector2(0.5, 0.5), mid + Vector2(0.5, 0.5)),
            const QueryFilter.all(),
            (slot) => found.add(doc.entities.handleAt(slot)));
        expect(found.intersection(kids(doc, g).toSet()), isNotEmpty,
            reason: 'a child of ${g.toHex()} at $mid');
      }
    }
    index.dispose();
  });

  test('P5 children are matched by kind, then ordinal (M-06m)', () {
    final doc = paramDoc();
    const h = Handle(3000);
    doc.commands.execute(create(doc, h, parked, const Hinge(false)));
    final before = kids(doc, h);
    doc.commands.execute(SetComponentCommand<Hinge>(h, const Hinge(true)));
    expect(kids(doc, h), before);
    for (final k in kids(doc, h)) {
      final slot = doc.entities.slotOf(k)!;
      final p = doc.geometry.read(doc.entities.geomIndexAt(slot));
      switch (doc.entities.kindAt(slot)) {
        case EntityKind.line:
          expect((p.coords.length, p.scalars.length), (4, 0));
        case EntityKind.arc:
          expect(p.scalars.length, 3);
        default:
          fail('unexpected kind');
      }
    }
  });

  test(
      'P6 fast path: no parametric object, no parametric command, the '
      'command is returned as is', () {
    final doc = paramDoc();
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    expect(identical(doc.commands.expander!(add), add), isTrue);
    final box = create(doc, hA, parked, const ClipRect(10, 10));
    expect(doc.commands.expander!(box), isA<ParametricEdit>());
  });

  test('P7 a fill cannot be generated', () {
    expect(
        () => Generated(
            EntityKind.fill, linePayload(Vector2(1, 2), Vector2(3, 4))),
        throwsArgumentError);
  });

  test('P8 one system per document; dispose releases only its own slot', () {
    final doc = DraftDocument.empty();
    final s = ParametricSystem(doc, catalog)..install();
    expect(() => ParametricSystem(doc, catalog).install(), throwsStateError);
    s.dispose();
    expect(doc.commands.expander, isNull);
    final t = ParametricSystem(doc, catalog)..install();
    s.dispose();
    expect(doc.commands.expander, isNotNull, reason: 's no longer owns it');
    t.dispose();
  });

  test('P9 a ParametricEdit applies once (spec D9)', () {
    final doc = paramDoc();
    final edit =
        doc.commands.expander!(create(doc, hA, parked, const ClipRect(10, 10)));
    edit.apply(doc);
    expect(() => edit.apply(doc), throwsStateError);
  });

  test(
      'P10 a second system over a populated document keeps its '
      'components (Ruling 06-13, M-06v)', () {
    final doc = paramDoc();
    pair(doc);
    final before = enc(doc);
    final second = ParametricSystem(doc, catalog);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(second.drift(), isEmpty);
    expect(enc(doc), before);
  });

  test(
      'P11 a throwing reach on the after-survey rolls inner back and leaves '
      'nothing in history (M-06w: after-survey outside the try)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const Trip(10, 10)));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    Trip.mode = TripMode.throwingReach;
    expect(
        () => doc.commands
            .execute(SetComponentCommand<Trip>(hA, const Trip(-1, 10))),
        throwsStateError);
    expect(doc.commands.undoDepth, depth);
    expect(doc.components.get<Trip>(hA), const Trip(10, 10));
    expect(enc(doc), before);
  });

  test(
      'P12 a direct edit of a generated child is refused even when the same '
      'command first detaches its owner\'s parametric component (spec D6)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final child = kids(doc, hA).first;
    final childSlot = doc.entities.slotOf(child)!;
    final payload = doc.geometry.read(doc.entities.geomIndexAt(childSlot));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    expect(
        () => doc.commands.execute(CompoundCommand([
              SetComponentCommand<ClipRect>(hA, null),
              SetEntityGeometryCommand(child, payload),
            ], label: 'Detach then edit')),
        throwsA(isA<GeneratedGeometryError>()));
    expect(doc.commands.undoDepth, depth);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(enc(doc), before);
  });
}
