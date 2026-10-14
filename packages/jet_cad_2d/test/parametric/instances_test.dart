// Spec 2b S1 (E5): a parametric type generates symbol instances with their
// ATTRIBs beside its entities. The planner matches the i-th output to the
// i-th existing instance ascending by handle and ATTRIBs by tag, plans
// nothing for an unchanged output, and refuses an output naming no live
// definition before any command. Fixture: support/row_clients.dart.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart' show Caption;
import 'support/row_clients.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

void main() {
  setUp(resetRowCalls);

  test(
      'E5-args GeneratedAttrib refuses an empty tag, GeneratedInstance two '
      'attributes of one tag, and its list is its own (M-E5-args-tag, '
      'M-E5-args-dup, M-E5-args-copy)', () {
    final p = seatLabel(row1);
    expect(() => GeneratedAttrib('', 'A1', p), throwsArgumentError);
    final a = GeneratedAttrib(kSeatTag, 'A1', p, textAttrs: kSeatLabelAttrs);
    expect((a.tag, a.text, a.textAttrs), (kSeatTag, 'A1', kSeatLabelAttrs));
    final b = GeneratedAttrib(kSeatTag, 'A2', p);
    expect(() => GeneratedInstance(hSeat, seatAt(row1, 3), attributes: [a, b]),
        throwsArgumentError);
    final given = [a];
    final g = GeneratedInstance(hSeat, seatAt(row1, 3), attributes: given);
    given.add(GeneratedAttrib('ROW', 'A', p));
    expect(g.attributes, [a]);
    expect(() => g.attributes.add(b), throwsUnsupportedError);
    expect(GeneratedInstance(hStool, seatAt(row2, 2)).attributes, isEmpty);
  });

  test(
      'E5-shrink a row shrunk from 12 seats to 10 keeps seats 1-10 under '
      'their handles, untouched, with their components; seats 11-12 go with '
      'their labels; undo brings them back with theirs (M-E5-match, '
      'M-E5-surplus-leaves, M-E5-label-shape, M-E5-call)', () {
    final doc = hall();
    final before = seats(doc, hRow1);
    expect(before, hasLength(12));
    final labels = labelsOf(doc, hRow1);

    // Created: each seat a child of the row's group with InstanceNode's
    // default style, on the object's layer (layer 0: no ObjectLayer), and
    // one label of today's table label's shape.
    for (var i = 0; i < 12; i++) {
      final s = before[i];
      final why = 'seat ${i + 1}';
      expect(s.parent, hRow1, reason: why);
      expect(s.definition, hSeat, reason: why);
      expect(s.transform.equals(seatAt(row1, i), exact), isTrue, reason: why);
      expect(s.layer, ReservedHandles.layerZero, reason: why);
      expect(s.color, const ByBlockColor(), reason: why);
      expect(s.lineweight, kByBlock, reason: why);
      expect(s.transparency, kByBlock, reason: why);
      expect(s.linetype, ReservedHandles.byBlockLinetype, reason: why);
      expect(s.linetypeScale, 1.0, reason: why);
      expect(s.visible, isTrue, reason: why);
      final r = recordOf(doc, labels[i]);
      expect(r.owner, s.handle, reason: why);
      expect(r.kind, EntityKind.attrib, reason: why);
      expect(r.tag, kSeatTag, reason: why);
      expect(r.text, 'A${i + 1}', reason: why);
      expect(r.layer, ReservedHandles.layerZero, reason: why);
      expect(r.color, const ByBlockColor(), reason: why);
      expect(r.linetype, ReservedHandles.byBlockLinetype, reason: why);
      expect(r.lineweight, kByBlock, reason: why);
      expect(r.transparency, kByBlock, reason: why);
      expect(r.flags, 0, reason: why);
      expect(r.textStyle, ReservedHandles.standardTextStyle, reason: why);
      expect(r.textAttrs, kSeatLabelAttrs, reason: why);
      expect(payloadOf(doc, labels[i]).coords, seatLabel(row1).coords);
      expect(payloadOf(doc, labels[i]).scalars, seatLabel(row1).scalars);
    }
    // Premise: seat 12 sits off the origin in world, on row 1's turned
    // frame.
    final world = doc.tree
        .accumulatedTransform(before[11].handle)
        .transformPoint(Vector2(0, 0));
    final want =
        atRow1.multiply(seatAt(row1, 11)).transformPoint(Vector2(0, 0));
    expect(world.x, closeTo(want.x, 1e-9));
    expect(world.y, closeTo(want.y, 1e-9));
    expect(world.length, greaterThan(1000));
    expect(atRow1.transformDirection(Vector2(1, 0)).y, isNot(closeTo(0, 1e-3)));

    // Per-seat data: a component on each seat, which no hook reads.
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < 12; i++)
        SetComponentCommand<SeatNote>(before[i].handle, SeatNote('n${i + 1}')),
    ], label: 'Notes'));
    final noted = canon(doc);
    final depth = doc.commands.undoDepth;
    final row2Seats = [for (final s in seats(doc, hRow2)) s.handle];

    doc.commands
        .execute(SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final after = seats(doc, hRow1);
    expect([for (final s in after) s.handle],
        [for (final s in before.take(10)) s.handle]);
    for (var i = 0; i < 10; i++) {
      final why = 'seat ${i + 1}';
      expect(identical(doc.tree[before[i].handle], before[i]), isTrue,
          reason: '$why: no command planned on it');
      expect(
          doc.components.get<SeatNote>(before[i].handle), SeatNote('n${i + 1}'),
          reason: why);
      expect(leavesOf(doc, before[i].handle), [labels[i]], reason: why);
      expect(recordOf(doc, labels[i]).text, 'A${i + 1}', reason: why);
    }
    for (final i in [10, 11]) {
      expect(doc.tree[before[i].handle], isNull);
      expect(doc.entities.slotOf(labels[i]), isNull,
          reason: 'seat ${i + 1}\'s label goes with it');
      expect(doc.components.get<SeatNote>(before[i].handle), isNull);
    }
    expect(doc.commands.undoDepth, depth + 1);
    expect([for (final s in seats(doc, hRow2)) s.handle], row2Seats);
    expect(drift(doc), isEmpty);
    final shrunk = canon(doc);

    doc.commands.undo();
    expect(canon(doc), noted);
    expect([for (final s in seats(doc, hRow1)) s.handle],
        [for (final s in before) s.handle]);
    for (final i in [10, 11]) {
      expect(doc.components.get<SeatNote>(before[i].handle),
          SeatNote('n${i + 1}'));
      expect(leavesOf(doc, before[i].handle), [labels[i]]);
    }
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), shrunk);
  });

  test(
      'E5-noop an edit that leaves a curved row\'s output as it is plans '
      'nothing: no node touched, the summary components, the index not '
      'rebuilt (M-E5-eq-def, M-E5-eq-transform, M-E5-eq-layer, '
      'M-E5-eq-payload, M-E5-eq-text)', () async {
    final doc = hall();
    final index = SpatialIndex(doc);
    index.forEachInRect(Aabb2(Vector2(-20000, -20000), Vector2(30000, 30000)),
        const QueryFilter.all(), (_) {});
    final rebuilds = index.rebuildCount;
    final nodes = <Handle, Node?>{};
    for (final row in [hRow1, hRow2]) {
      nodes[row] = doc.tree[row];
      for (final s in seats(doc, row)) {
        nodes[s.handle] = s;
      }
    }
    resetRowCalls();
    final applied = await applying(
        doc,
        () => doc.commands.execute(
            SetComponentCommand<Row>(hRow2, row2.copyWith(note: 'aisle'))));
    expect(rowInstanceCalls, {hRow2: 1}, reason: 'the row regenerated');
    expect(rowGenerateCalls, {hRow2: 1});
    expect(applied.single.touched, {hRow2});
    expect(applied.single.capability, Capability.components);
    expect(index.rebuildCount, rebuilds);
    for (final MapEntry(key: h, value: n) in nodes.entries) {
      expect(identical(doc.tree[h], n), isTrue, reason: h.toHex());
    }
    expect(drift(doc), isEmpty);
    index.dispose();
  });

  test(
      'E5-tag labels are matched by tag: two regenerations rewrite each '
      'seat\'s one label in place and keep its tag; a new payload is '
      'rewritten in place; a new tag is added, a missing one removed; a '
      'caller\'s edit of a label is refused (M-E5-tag-own, M-E5-tag-missing, '
      'M-E5-tag-add, M-E5-owned)', () {
    final doc = hall();
    final labels = labelsOf(doc, hRow2);
    final ss = [for (final s in seats(doc, hRow2)) s.handle];
    expect(ss, hasLength(5));

    void expectLabels(String prefix, double height) {
      for (var k = 0; k < ss.length; k++) {
        final why = 'seat ${k + 1}';
        expect(leavesOf(doc, ss[k]).first, labels[k], reason: why);
        final r = recordOf(doc, labels[k]);
        expect(r.tag, kSeatTag, reason: why);
        expect(r.text, '$prefix${k + 1}', reason: why);
        expect(r.textAttrs, kSeatLabelAttrs, reason: why);
        expect(payloadOf(doc, labels[k]).scalars[0], height, reason: why);
      }
    }

    for (final prefix in ['C', 'D']) {
      doc.commands.execute(
          SetComponentCommand<Row>(hRow2, row2.copyWith(prefix: prefix)));
      for (var k = 0; k < ss.length; k++) {
        expect(leavesOf(doc, ss[k]), [labels[k]],
            reason: 'one label on seat ${k + 1}, the same one');
      }
      expectLabels(prefix, row2.labelHeight);
      expect(drift(doc), isEmpty);
    }

    doc.commands.execute(SetComponentCommand<Row>(
        hRow2, row2.copyWith(prefix: 'D', labelHeight: 175.5)));
    for (var k = 0; k < ss.length; k++) {
      expect(leavesOf(doc, ss[k]), [labels[k]]);
    }
    expectLabels('D', 175.5);

    const extra = Row(hSeat, 5,
        prefix: 'D',
        spacing: 700.25,
        bend: 0.125,
        labelHeight: 175.5,
        extraTag: 'ROW');
    doc.commands.execute(SetComponentCommand<Row>(hRow2, extra));
    final extras = <Handle>[];
    for (var k = 0; k < ss.length; k++) {
      final [label, added] = leavesOf(doc, ss[k]);
      expect(label, labels[k]);
      final r = recordOf(doc, added);
      expect(r.kind, EntityKind.attrib);
      expect(r.tag, 'ROW');
      expect(r.text, 'D');
      expect(r.layer, ReservedHandles.layerZero);
      expect(r.textAttrs, 0);
      extras.add(added);
    }
    expectLabels('D', 175.5);
    expect(drift(doc), isEmpty);

    doc.commands.execute(SetComponentCommand<Row>(
        hRow2, row2.copyWith(prefix: 'D', labelHeight: 175.5)));
    for (var k = 0; k < ss.length; k++) {
      expect(leavesOf(doc, ss[k]), [labels[k]]);
      expect(doc.entities.slotOf(extras[k]), isNull);
    }
    expect(drift(doc), isEmpty);

    // A caller's edit of a label: 06 D6's entity branch, which now covers
    // a generated instance's ATTRIBs (`owned`).
    final bytes = enc(doc);
    final depth = doc.commands.undoDepth;
    expect(
        () => doc.commands
            .execute(SetEntityTextCommand(labels[2], 'Z9', kSeatTag)),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', labels[2])));
    expect(enc(doc), bytes);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'E5-dup-tag a loaded seat carrying two labels of one tag: the lowest '
      'handle is matched, the other removed, in one undo step (M-E5-lowest)',
      () {
    final built = hall();
    final third = seats(built, hRow1)[2].handle;
    final original = leavesOf(built, third).single;
    late Handle extra;
    final doc = loadedWith(built, (raw) {
      extra = raw.handleSeed.next();
      raw.commands.execute(AddEntityCommand(
          record: recordOf(raw, original).copyWith(handle: extra, text: 'zz'),
          payload: payloadOf(raw, original)));
    });
    expect(leavesOf(doc, third), [original, extra]);
    expect(recordOf(doc, extra).tag, kSeatTag);
    expect(drift(doc), [hRow1], reason: 'its plan would remove the surplus');
    final loaded = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands
        .execute(SetComponentCommand<Row>(hRow1, row1.copyWith(prefix: 'E')));
    expect(leavesOf(doc, third), [original]);
    expect(recordOf(doc, original).text, 'E3');
    expect(doc.entities.slotOf(extra), isNull);
    expect(doc.commands.undoDepth, depth + 1);
    expect(drift(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc), loaded);
  });

  test(
      'E5-def an output naming no live definition: the edit is refused '
      'before any command; probe returns the error, drift throws it '
      '(M-E5-def)', () {
    final doc = hall();
    const ghost = Handle(4242);
    final bytes = enc(doc);
    final depth = doc.commands.undoDepth;
    final state = doc.commands.stateId;
    // A dead handle, and a live node that is not a definition.
    for (final bad in [ghost, hRow2]) {
      expect(
          () => doc.commands.execute(
              SetComponentCommand<Row>(hRow1, row1.copyWith(seat: bad))),
          throwsA(isA<GeneratedDefinitionError>()
              .having((e) => e.object, 'object', hRow1)
              .having((e) => e.definition, 'definition', bad)),
          reason: bad.toHex());
      expect(enc(doc), bytes);
      expect(doc.commands.undoDepth, depth);
      expect(doc.commands.stateId, state);
    }

    // A loaded file whose row names a dead definition.
    final loaded = loadedWith(
        doc,
        (raw) => raw.commands.execute(
            SetComponentCommand<Row>(hRow1, row1.copyWith(seat: ghost))));
    final saved = enc(loaded);
    final system = ParametricSystem(loaded, rowCatalog);
    expect(
        system.probe(hRow1),
        isA<GeneratedDefinitionError>()
            .having((e) => e.object, 'object', hRow1)
            .having((e) => e.definition, 'definition', ghost));
    expect(system.probe(hRow2), isNull);
    expect(() => system.drift(), throwsA(isA<GeneratedDefinitionError>()));
    expect(enc(loaded), saved);
  });

  test(
      'E5-default a type that keeps the default instances regenerates as '
      'before beside rows: its group gains no node, its TEXT is rewritten in '
      'place (M-E5-default)', () {
    final doc = hall();
    const hCaption = Handle(3000);
    place(
        doc,
        hCaption,
        atRow1.multiply(Transform2.translation(-900.5, 1200.25)),
        const Caption('Stage', 40.5, -12.25));
    expect((doc.tree[hCaption]! as GroupNode).children, isEmpty);
    final [text] = leavesOf(doc, hCaption);
    expect(recordOf(doc, text).text, 'Stage');
    doc.commands.execute(SetComponentCommand<Caption>(
        hCaption, const Caption('Screen', 40.5, -12.25)));
    expect((doc.tree[hCaption]! as GroupNode).children, isEmpty);
    expect(leavesOf(doc, hCaption), [text]);
    expect(recordOf(doc, text).text, 'Screen');
    expect(drift(doc), isEmpty);
  });

  test(
      'E5-order generated handles run in output order, each label just above '
      'its seat; a regrown seat takes handles above every other; existing '
      'seats are matched ascending by handle whatever order the group lists '
      'them in (M-E5-sort)', () {
    final doc = hall();
    final line = leavesOf(doc, hRow1).single;
    final ss = seats(doc, hRow1);
    expect((doc.tree[hRow1]! as GroupNode).children,
        [for (final s in ss) s.handle]);
    var last = line.value;
    for (final s in ss) {
      expect(s.handle.value, greaterThan(last));
      expect(leavesOf(doc, s.handle).single.value, s.handle.value + 1);
      last = s.handle.value + 1;
    }

    doc.commands
        .execute(SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final top = doc.handleSeed.current.value;
    doc.commands.execute(SetComponentCommand<Row>(hRow1, row1));
    final grown = seats(doc, hRow1);
    expect([for (final s in grown.take(10)) s.handle],
        [for (final s in ss.take(10)) s.handle]);
    expect(
        [for (final s in grown.skip(10)) s.handle.value], [top + 1, top + 3]);
    expect(leavesOf(doc, grown[10].handle).single.value, top + 2);
    expect(leavesOf(doc, grown[11].handle).single.value, top + 4);
    expect(recordOf(doc, leavesOf(doc, grown[11].handle).single).text, 'A12');

    // A loaded file whose group lists the seats in reverse.
    final loaded = loadedWith(doc, (raw) {
      final group = raw.tree[hRow1]! as GroupNode;
      raw.tree.replaceNode(
          group.copyWith(children: group.children.reversed.toList()));
    });
    final asc = seats(loaded, hRow1);
    expect((loaded.tree[hRow1]! as GroupNode).children,
        [for (final s in asc.reversed) s.handle]);
    loaded.commands
        .execute(SetComponentCommand<Row>(hRow1, row1.copyWith(prefix: 'F')));
    for (var k = 0; k < asc.length; k++) {
      expect(identical(loaded.tree[asc[k].handle], asc[k]), isTrue,
          reason: 'seat ${k + 1} not moved');
      expect(recordOf(loaded, leavesOf(loaded, asc[k].handle).single).text,
          'F${k + 1}');
    }
  });

  test(
      'E5-layer a generated seat is on its object\'s layer and follows it in '
      'one undo step; its label stays on layer 0, BYBLOCK (M-E5-layer-add, '
      'M-E5-layer-match, M-E5-label-layer)', () {
    final doc = rowDoc();
    final stalls = addLayer(doc, 'Stalls', 3);
    final balcony = addLayer(doc, 'Balcony', 5);
    place(doc, hRow2, atRow2, row2, layer: stalls);
    final ss = seats(doc, hRow2);
    final labels = labelsOf(doc, hRow2);
    final line = leavesOf(doc, hRow2).single;
    // Premise: row 2 is mirrored in world.
    final m = doc.tree.accumulatedTransform(hRow2);
    expect(m.a * m.d - m.b * m.c, lessThan(0));

    void expectOn(Handle layer) {
      expect(doc.entities.layerAt(doc.entities.slotOf(line)!), layer,
          reason: 'the LINE child (12b D2)');
      for (var k = 0; k < ss.length; k++) {
        final why = 'seat ${k + 1}';
        expect((doc.tree[ss[k].handle]! as InstanceNode).layer, layer,
            reason: why);
        final r = recordOf(doc, labels[k]);
        expect(r.layer, ReservedHandles.layerZero, reason: why);
        expect(r.color, const ByBlockColor(), reason: why);
        expect(r.transparency, kByBlock, reason: why);
      }
    }

    expectOn(stalls);
    final placed = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(hRow2, ObjectLayer(balcony)));
    expect([for (final s in seats(doc, hRow2)) s.handle],
        [for (final s in ss) s.handle]);
    expectOn(balcony);
    expect(doc.commands.undoDepth, depth + 1);
    final moved = canon(doc);
    doc.commands.undo();
    expect(canon(doc), placed);
    expectOn(stalls);
    doc.commands.redo();
    expect(canon(doc), moved);
    expect(drift(doc), isEmpty);
  });
}
