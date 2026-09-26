// Generated TEXT (spec 10 D12): a TEXT child whose string the planner owns,
// written with its textAttrs on add and rewritten in place on a match.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

EntityRecord recordOf(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

List<String> drift(DraftDocument doc) => [
      for (final d in ParametricSystem(doc, catalog).drift()) d.toString(),
    ];

void main() {
  setUp(generateCalls.clear);

  test(
      'TX1 a generated TEXT is added with its string and textAttrs; a '
      'string change rewrites it in place, one undo step; a caller\'s text '
      'edit is refused; the plain form refuses TEXT and ATTRIB', () async {
    final doc = paramDoc();
    // Off the origin, turned, on A's rotated frame; fractional stored
    // values, so a rounding mutant cannot survive the round trip.
    final at = onA(1234.5, -310.25, 0.4);
    const kueche = Caption('Küche 2', 125.5, -40.25);
    doc.commands.execute(create(doc, hA, at, kueche));

    // Created: one TEXT child with the string, centre-middle, ByLayer,
    // flags 0, tag ''.
    final [child] = kids(doc, hA);
    final r0 = recordOf(doc, child);
    expect(r0.kind, EntityKind.text);
    expect(r0.text, 'Küche 2');
    expect(r0.textAttrs, 0x21, reason: 'centre (1) | middle (2) << 4');
    expect(r0.color, const ByLayerColor());
    expect(r0.flags, 0);
    expect(r0.tag, '');
    final bytes = payloadOf(doc, child);
    expect(bytes.coords, [125.5, -40.25]);
    expect(bytes.scalars, [Caption.height, 0, 1, 0]);
    // Premise: the TEXT sits off the origin in world, on A's turned frame.
    final world = doc.tree
        .accumulatedTransform(hA)
        .transformPoint(Vector2(bytes.coords[0], bytes.coords[1]));
    final want = at.transformPoint(Vector2(125.5, -40.25));
    expect(world.x, closeTo(want.x, 1e-9));
    expect(world.y, closeTo(want.y, 1e-9));
    expect(world.length, greaterThan(1000));
    expect(drift(doc), isEmpty);

    // The rename: same handle, new string, the payload's bytes unchanged,
    // one undo step whose summary is `geometry` (06 D9: a string changes a
    // TEXT's bounds, and the index must hear it).
    final created = canon(doc);
    final depth = doc.commands.undoDepth;
    await pumpEventQueue();
    final applied = <CommandApplied>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) applied.add(c);
    });
    doc.commands.execute(
        SetComponentCommand<Caption>(hA, const Caption('Bath', 125.5, -40.25)));
    await pumpEventQueue();
    await sub.cancel();
    expect(kids(doc, hA), [child], reason: 'rewritten in place');
    final r1 = recordOf(doc, child);
    expect(r1.text, 'Bath');
    expect(r1.tag, '', reason: 'the rewrite writes no tag');
    expect(r1.textAttrs, 0x21);
    expect(r1.color, const ByLayerColor());
    expect(r1.flags, 0);
    expect(payloadOf(doc, child).coords, bytes.coords);
    expect(payloadOf(doc, child).scalars, bytes.scalars);
    expect(doc.commands.undoDepth, depth + 1);
    expect(applied.single.capability, Capability.geometry);
    expect(drift(doc), isEmpty);
    final renamed = canon(doc);

    doc.commands.undo();
    expect(canon(doc), created);
    expect(recordOf(doc, child).text, 'Küche 2');
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), renamed);
    expect(recordOf(doc, child).text, 'Bath');
    expect(drift(doc), isEmpty);

    // A move of the insertion point only: the payload is rewritten, the
    // string is not.
    doc.commands.execute(
        SetComponentCommand<Caption>(hA, const Caption('Bath', -75.75, 60.5)));
    expect(kids(doc, hA), [child]);
    expect(recordOf(doc, child).text, 'Bath');
    expect(payloadOf(doc, child).coords, [-75.75, 60.5]);
    expect(payloadOf(doc, child).scalars, bytes.scalars);
    expect(drift(doc), isEmpty);

    // A caller's text edit of the generated child is refused (06 D6): the
    // bytes, the history and doc.changes are unchanged.
    final before = enc(doc);
    final depth2 = doc.commands.undoDepth;
    await pumpEventQueue();
    var changes = 0;
    final sub2 = doc.changes.listen((_) => changes++);
    expect(
        () => doc.commands.execute(SetEntityTextCommand(child, 'x', '')),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', child)));
    await pumpEventQueue();
    await sub2.cancel();
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth2);
    expect(changes, 0);

    // The plain form refuses TEXT and ATTRIB (R-15).
    final p = textPayload(Vector2(1.5, 2.5), 250);
    expect(() => Generated(EntityKind.text, p), throwsArgumentError);
    expect(() => Generated(EntityKind.attrib, p), throwsArgumentError);

    // Save, load, save: byte-identical, the string kept, no drift.
    final saved = enc(doc);
    final loaded = reload(saved);
    expect(enc(loaded), saved);
    expect(recordOf(loaded, child).text, 'Bath');
    expect(recordOf(loaded, child).textAttrs, 0x21);
    expect(drift(loaded), isEmpty);
  });
}
