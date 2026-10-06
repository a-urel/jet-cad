// Spec 14d S1, S2 (revision 2): the service layout's codec and its strict
// match. Tables are turned, mirrored and off the origin; moves are
// off-grid; the copy is a decoded copy of the design, as the controller
// makes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/service_layout.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// Tables 1 (turned, mirrored), 2, 3 (a stool, half-turned) and 4 (on
/// layer `L`), and a planter.
DraftDocument design() {
  final doc = plan();
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(-2600.25, 1400.5), quarterTurns: 1, mirrored: true));
  doc.commands.execute(
      placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(2300.75, 1400)));
  doc.commands.execute(placeSymbol(doc, entryOf(stoolSymbol),
      at: Vector2(300, -2100.125), quarterTurns: 2));
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
      at: Vector2(5100.5, -3300.25), quarterTurns: 3));
  doc.commands.execute(
      placeSymbol(doc, entryOf(planterSymbol), at: Vector2(4100, -900)));
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final layer = LayerRecord(
    handle: doc.handleSeed.next(),
    name: 'L',
    color: const IndexedColor(3),
    linetype: zero.linetype,
    lineweight: zero.lineweight,
    transparency: zero.transparency,
    visible: true,
    locked: false,
  );
  doc.commands.execute(AddLayerCommand(layer));
  doc.commands
      .execute(SetInstanceLayerCommand(table(doc, '4').handle, layer.handle));
  return doc;
}

DraftDocument copyOf(DraftDocument doc) =>
    DraftDocumentCodec.decodeString(DraftDocumentCodec.encodeToString(doc),
        permissions: DraftPermissions.runtime,
        registerComponents: registerAppComponents);

InstanceNode table(DraftDocument doc, String n) =>
    doc.tree[TableSurvey.of(doc).withNumber(n).single.instance]!
        as InstanceNode;

void move(DraftDocument doc, String n, double dx, double dy) {
  final node = table(doc, n);
  doc.commands.execute(TransformNodeCommand(
      node.handle, Transform2.translation(dx, dy).multiply(node.transform)));
}

/// [d]'s copy with every table moved, the highest handle first.
DraftDocument movedCopy(DraftDocument d) {
  final copy = copyOf(d);
  for (final (n, dx, dy) in const [
    ('4', 111.125, -37.5),
    ('3', -250.5, 75.25),
    ('2', 640.375, 12.5),
    ('1', -95.75, -410.625),
  ]) {
    move(copy, n, dx, dy);
  }
  return copy;
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

void main() {
  test(
      'LC1 the layout lists the moved tables, ascending by handle although '
      'moved highest first; a table moved back exactly is not listed '
      '(S1, M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    move(copy, '2', -640.375, -12.5);
    final entries = serviceLayoutOf(d, copy);
    expect([for (final e in entries) e.number], ['1', '3', '4']);
    final handles = [for (final e in entries) e.handle.value];
    expect(handles, [...handles]..sort());
    expect(handles.first < handles.last, isTrue, reason: 'premise');
    for (final e in entries) {
      expect(parts(e.from), parts(table(d, e.number!).transform));
      expect(parts(e.to), parts(table(copy, e.number!).transform));
    }
    expect(parts(entries.first.to)[4],
        closeTo(parts(entries.first.from)[4] - 95.75, 1e-9));
  });

  test(
      'LC2 the encoding round-trips, and is byte-equal twice and after the '
      'design is encoded and decoded (S1, M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    final text = encodeServiceLayout(serviceLayoutOf(d, copy));
    expect(encodeServiceLayout(serviceLayoutOf(d, copy)), text);
    expect(encodeServiceLayout(serviceLayoutOf(copyOf(d), copy)), text);
    final back = decodeServiceLayout(text);
    expect(encodeServiceLayout(back), text);
    expect(text, contains('"format":"jet_cad.service_layout"'));
    expect(text, contains('"version":1'));
  });

  test('LC3 a text that is not a version-1 layout is refused (S2)', () {
    String layout(String tables, {String format = 'jet_cad.service_layout'}) =>
        '{"format":"$format","version":1,"tables":$tables}';
    const ok = '[1,0,0,1,10.5,-3]';
    String entry(
            {String handle = '"2F"',
            String number = '"1"',
            String from = ok,
            String to = ok}) =>
        '{"handle":$handle,"number":$number,"from":$from,"to":$to}';
    expect(decodeServiceLayout(layout('[${entry()}]')), hasLength(1));
    expect(
        decodeServiceLayout(layout('[${entry(number: 'null')}]')).single.number,
        isNull);
    for (final bad in [
      'not json',
      '[]',
      layout('[]', format: 'other'),
      '{"format":"jet_cad.service_layout","version":2,"tables":[]}',
      layout('{}'),
      layout('[3]'),
      layout('[${entry(handle: '"XYZ"')}]'),
      layout('[${entry(handle: '47')}]'),
      layout('[${entry(number: '5')}]'),
      layout('[${entry(from: '[1,0,0,1,10]')}]'),
      layout('[${entry(to: '[1,0,0,1,10,"x"]')}]'),
      layout('[${entry()},${entry(number: '"2"')}]'),
    ]) {
      expect(() => decodeServiceLayout(bad), throwsFormatException,
          reason: bad);
    }
  });

  test('LC4 `1` and `1.0` read alike (V-21)', () {
    final a = decodeServiceLayout('{"format":"jet_cad.service_layout",'
        '"version":1,"tables":[{"handle":"A","number":null,'
        '"from":[1,0,0,1,2,3],"to":[1,0,0,1,4,5]}]}');
    final b = decodeServiceLayout('{"format":"jet_cad.service_layout",'
        '"version":1,"tables":[{"handle":"A","number":null,'
        '"from":[1.0,0.0,0.0,1.0,2.0,3.0],"to":[1.0,0.0,0.0,1.0,4.0,5.0]}]}');
    expect(parts(a.single.to), parts(b.single.to));
    expect(sameTransform(a.single.from, b.single.from), isTrue);
  });

  group('LC5 the strict match (S2, M-14d-l)', () {
    late DraftDocument d;
    late List<ServiceLayoutEntry> entries;
    setUp(() {
      d = design();
      entries = decodeServiceLayout(
          encodeServiceLayout(serviceLayoutOf(d, movedCopy(d))));
    });
    List<String?> dropped() =>
        [for (final e in matchServiceLayout(d, entries).dropped) e.number];

    test('an unchanged design applies every entry', () {
      final m = matchServiceLayout(d, entries);
      expect([for (final e in m.applied) e.number], ['1', '2', '3', '4']);
      expect(m.dropped, isEmpty);
    });

    test('a table moved in the design since is dropped', () {
      move(d, '2', 0.5, 0);
      expect(dropped(), ['2']);
    });

    test('a table renumbered in the design since is dropped', () {
      d.commands.execute(SetEntityTextCommand(
          TableSurvey.of(d).withNumber('3').single.label!,
          '9',
          kTableLabelTag));
      expect(dropped(), ['3']);
    });

    test('a table locked or hidden in the design since is dropped', () {
      final layer = d.tables.layers[table(d, '4').layer]!;
      d.commands.execute(SetLayerCommand(layer.copyWith(locked: true)));
      expect(dropped(), ['4']);
      d.commands.execute(
          SetLayerCommand(layer.copyWith(locked: false, visible: false)));
      expect(dropped(), ['4']);
    });

    test(
        'an entry for a missing node, a non-table, or another table with '
        'the number of the first is dropped', () {
      final first = entries.first;
      final planter = d.tree.nodes
          .whereType<InstanceNode>()
          .where((n) =>
              TableSurvey.of(d).tables.every((t) => t.instance != n.handle))
          .single
          .handle;
      entries = [
        for (final h in [
          Handle(d.handleSeed.current.value + 50),
          planter,
          table(d, '2').handle,
        ])
          ServiceLayoutEntry(
              handle: h, number: first.number, from: first.from, to: first.to),
      ];
      expect(matchServiceLayout(d, entries).applied, isEmpty);
    });

    test('an entry that turns the table, or holds a NaN, is dropped', () {
      final e = entries.first;
      final turned = Transform2.rotation(0.25).multiply(e.to);
      final nan =
          Transform2(e.to.a, e.to.b, e.to.c, e.to.d, double.nan, e.to.f);
      entries = [
        ServiceLayoutEntry(
            handle: e.handle, number: e.number, from: e.from, to: turned),
        ServiceLayoutEntry(
            handle: e.handle, number: e.number, from: e.from, to: nan),
      ];
      expect(matchServiceLayout(d, entries).applied, isEmpty);
    });
  });
}
