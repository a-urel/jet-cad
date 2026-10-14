// jet_cad_floor_plan's test/host/service_layout_test.dart (LC1-LC6),
// ported to the service record (spec 2b S3 "The service record"):
// assertions unchanged but where the format itself is the premise
// (ruling R13-a). Units are turned, mirrored and off the origin; moves are
// off-grid; the copy is a decoded copy of the design under runtime
// permissions, as the controller makes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/service/service_record.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placementTransform;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart'
    show catalogOf, planDocument, registerPlanComponents;
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit;

/// Units 1 (a quarter turn, mirrored), 2, 3 (a stool, half-turned) and 4
/// (on layer `L`), and a planter (today's `design()`,
/// service_layout_test.dart:16-45).
DraftDocument design() {
  final d = planDocument([testKit()]);
  final table = unitDefinition(d, key: 'test.table.square.four');
  final stool = unitDefinition(d,
      key: 'test.stool.round.one', name: 'Stool', capacity: 1, round: true);
  final planter = unitDefinition(d,
      key: 'test.planter.square.one', name: 'Planter', unit: false);
  placeDef(
      d,
      table,
      placementTransform(
          at: Vector2(-2600.25, 1400.5),
          basePoint: table.base,
          quarterTurns: 1,
          mirrored: true),
      label: '1');
  placeDef(d, table,
      placementTransform(at: Vector2(2300.75, 1400), basePoint: table.base),
      label: '2');
  placeDef(
      d,
      stool,
      placementTransform(
          at: Vector2(300, -2100.125), basePoint: stool.base, quarterTurns: 2),
      label: '3');
  final four = placeDef(
      d,
      table,
      placementTransform(
          at: Vector2(5100.5, -3300.25),
          basePoint: table.base,
          quarterTurns: 3),
      label: '4');
  placeDef(d, planter,
      placementTransform(at: Vector2(4100, -900), basePoint: planter.base));
  final layer = addLayer(d, 'L', visible: true, locked: false);
  d.commands.execute(SetInstanceLayerCommand(four, layer));
  return d;
}

DraftDocument copyOf(DraftDocument doc) =>
    DraftDocumentCodec.decodeString(DraftDocumentCodec.encodeToString(doc),
        permissions: DraftPermissions.runtime,
        registerComponents: (r) =>
            registerPlanComponents(r, catalogOf([testKit()])));

/// [d]'s units, every kit but the test kit missing.
UnitIndex unitsOf(DraftDocument d) => UnitIndex.of(d,
    catalog: catalogOf([testKit()]),
    locks: LockSet.scan(d, (kit) => kit == 'test'));

InstanceNode table(DraftDocument doc, String label) => unitNode(doc, label);

void moveIn(DraftDocument doc, String label, double dx, double dy) {
  final node = table(doc, label);
  doc.commands.execute(TransformNodeCommand(
      node.handle, Transform2.translation(dx, dy).multiply(node.transform)));
}

/// [d]'s copy with every unit moved, the highest handle first.
DraftDocument movedCopy(DraftDocument d) {
  final copy = copyOf(d);
  for (final (l, dx, dy) in const [
    ('4', 111.125, -37.5),
    ('3', -250.5, 75.25),
    ('2', 640.375, 12.5),
    ('1', -95.75, -410.625),
  ]) {
    moveIn(copy, l, dx, dy);
  }
  return copy;
}

List<ServiceMove> movesOf(DraftDocument d, DraftDocument copy) =>
    serviceMovesOf(d, copy, unitsOf(copy));

void main() {
  test(
      'LC1 the record lists the moved units, ascending by handle although '
      'moved highest first; a unit moved back exactly is not listed (S1, '
      'M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    moveIn(copy, '2', -640.375, -12.5);
    final entries = movesOf(d, copy);
    expect([for (final e in entries) e.label], ['1', '3', '4']);
    final handles = [for (final e in entries) e.handle.value];
    expect(handles, [...handles]..sort());
    expect(handles.first < handles.last, isTrue, reason: 'premise');
    for (final e in entries) {
      expect(parts(e.from), parts(table(d, e.label!).transform));
      expect(parts(e.to), parts(table(copy, e.label!).transform));
    }
    expect(parts(entries.first.to)[4],
        closeTo(parts(entries.first.from)[4] - 95.75, 1e-9));
  });

  test(
      'LC2 the encoding round-trips, and is byte-equal twice and after the '
      'design is encoded and decoded (S1, M-14d-n)', () {
    final d = design();
    final copy = movedCopy(d);
    final text = encodeServiceRecord(movesOf(d, copy), const {});
    expect(encodeServiceRecord(movesOf(d, copy), const {}), text);
    expect(encodeServiceRecord(movesOf(copyOf(d), copy), const {}), text);
    final back = decodeServiceRecord(text);
    expect(encodeServiceRecord(back.moves, const {}), text);
    // Ruling R13-a: today's 'jet_cad.service_layout'.
    expect(text, contains('"format":"jet_cad.service"'));
    expect(text, contains('"version":1'));
  });

  test('LC3 a text that is not a version-1 record is refused (S2, R13-a)', () {
    String record(String moves, {String format = 'jet_cad.service'}) =>
        '{"format":"$format","version":1,"moves":$moves,"groups":[]}';
    const ok = '[1,0,0,1,10.5,-3]';
    String entry(
            {String handle = '"2F"',
            String label = '"1"',
            String from = ok,
            String to = ok}) =>
        '{"handle":$handle,"label":$label,"from":$from,"to":$to}';
    expect(decodeServiceRecord(record('[${entry()}]')).moves, hasLength(1));
    expect(
        decodeServiceRecord(record('[${entry(label: 'null')}]'))
            .moves
            .single
            .label,
        isNull);
    for (final bad in [
      'not json',
      '[]',
      record('[]', format: 'other'),
      '{"format":"jet_cad.service","version":2,"moves":[],"groups":[]}',
      record('{}'),
      record('[3]'),
      record('[${entry(handle: '"XYZ"')}]'),
      record('[${entry(handle: '47')}]'),
      record('[${entry(label: '5')}]'),
      record('[${entry(from: '[1,0,0,1,10]')}]'),
      record('[${entry(to: '[1,0,0,1,10,"x"]')}]'),
      record('[${entry()},${entry(label: '"2"')}]'),
    ]) {
      expect(() => decodeServiceRecord(bad), throwsFormatException,
          reason: bad);
    }
  });

  test('LC4 `1` and `1.0` read alike (V-21, R13-a)', () {
    final a = decodeServiceRecord('{"format":"jet_cad.service",'
        '"version":1,"moves":[{"handle":"A","label":null,'
        '"from":[1,0,0,1,2,3],"to":[1,0,0,1,4,5]}],"groups":[]}');
    final b = decodeServiceRecord('{"format":"jet_cad.service",'
        '"version":1,"moves":[{"handle":"A","label":null,'
        '"from":[1.0,0.0,0.0,1.0,2.0,3.0],"to":[1.0,0.0,0.0,1.0,4.0,5.0]}],'
        '"groups":[]}');
    expect(parts(a.moves.single.to), parts(b.moves.single.to));
    expect(sameTransform(a.moves.single.from, b.moves.single.from), isTrue);
  });

  test(
      'LC6 an unlabelled unit moved is listed with a null label and '
      'applied by the match (S1, S2, review F-3)', () {
    final d = design();
    final spare = table(d, '2');
    d.commands.execute(SetEntityTextCommand(
        labelEntityOf(d, spare.handle)!, '', kUnitLabelTag));
    expect(unitsOf(d).units.where((u) => u.text == null), hasLength(1),
        reason: 'premise: one unlabelled unit');
    final copy = copyOf(d);
    final node = copy.tree[spare.handle]! as InstanceNode;
    copy.commands.execute(TransformNodeCommand(node.handle,
        Transform2.translation(-310.375, 58.25).multiply(node.transform)));
    final entries =
        decodeServiceRecord(encodeServiceRecord(movesOf(d, copy), const {}))
            .moves;
    expect([for (final e in entries) e.label], [null]);
    expect(entries.single.handle, spare.handle);
    final m = matchServiceMoves(d, unitsOf(d), entries);
    expect([for (final e in m.applied) e.label], [null]);
    expect(m.dropped, isEmpty);
  });

  group('LC5 the strict match (S2, M-14d-l)', () {
    late DraftDocument d;
    late List<ServiceMove> entries;
    setUp(() {
      d = design();
      entries = decodeServiceRecord(
          encodeServiceRecord(movesOf(d, movedCopy(d)), const {})).moves;
    });
    List<String?> dropped() => [
          for (final e in matchServiceMoves(d, unitsOf(d), entries).dropped)
            e.label
        ];

    test('an unchanged design applies every entry', () {
      final m = matchServiceMoves(d, unitsOf(d), entries);
      expect([for (final e in m.applied) e.label], ['1', '2', '3', '4']);
      expect(m.dropped, isEmpty);
    });

    test('a unit moved in the design since is dropped', () {
      moveIn(d, '2', 0.5, 0);
      expect(dropped(), ['2']);
    });

    test('a unit relabelled in the design since is dropped', () {
      d.commands.execute(SetEntityTextCommand(
          labelEntityOf(d, table(d, '3').handle)!, '9', kUnitLabelTag));
      expect(dropped(), ['3']);
    });

    test('a unit locked or hidden in the design since is dropped', () {
      final layer = d.tables.layers[table(d, '4').layer]!;
      d.commands.execute(SetLayerCommand(layer.copyWith(locked: true)));
      expect(dropped(), ['4']);
      d.commands.execute(
          SetLayerCommand(layer.copyWith(locked: false, visible: false)));
      expect(dropped(), ['4']);
    });

    test(
        'an entry for a missing node, a non-unit, or another unit with the '
        'label of the first is dropped', () {
      final first = entries.first;
      final units = unitsOf(d);
      final planter = d.tree.nodes
          .whereType<InstanceNode>()
          .where((n) => units[n.handle] == null)
          .single
          .handle;
      entries = [
        for (final h in [
          Handle(d.handleSeed.current.value + 50),
          planter,
          table(d, '2').handle,
        ])
          ServiceMove(
              handle: h, label: first.label, from: first.from, to: first.to),
      ];
      expect(matchServiceMoves(d, unitsOf(d), entries).applied, isEmpty);
    });

    test(
        'an entry that turns the unit, shears it in one term, or holds a '
        'NaN or an infinity, is dropped (review F-5)', () {
      final e = entries.first;
      final t = e.to;
      for (final to in [
        Transform2.rotation(0.25).multiply(t),
        Transform2(t.a, t.b + 0.25, t.c, t.d, t.e, t.f),
        Transform2(t.a, t.b, t.c, t.d, double.nan, t.f),
        Transform2(t.a, t.b, t.c, t.d, t.e, double.infinity),
      ]) {
        final one = [
          ServiceMove(handle: e.handle, label: e.label, from: e.from, to: to)
        ];
        expect(matchServiceMoves(d, unitsOf(d), one).applied, isEmpty,
            reason: '$to');
      }
      expect(matchServiceMoves(d, unitsOf(d), [e]).applied, hasLength(1),
          reason: 'premise: the entry itself applies');
    });
  });

  test(
      'SR-codec-shapes the groups: a list of objects with a string id, a list '
      'of string members and a string or null label; anything else is a '
      'FormatException; a group the validation would refuse decodes as '
      'written', () {
    String record(String groups) =>
        '{"format":"jet_cad.service","version":1,"moves":[],"groups":$groups}';
    final ok = decodeServiceRecord(record(
        '[{"id":" ","members":[],"label":null},{"id":"g1","members":["1"," 1 "]}]'));
    expect([for (final g in ok.groups) g.id], [' ', 'g1']);
    expect(ok.groups.last.members, ['1', ' 1 ']);
    expect(ok.groups.last.label, isNull);
    for (final bad in [
      // M-SR19: `groups` missing read as none.
      '{"format":"jet_cad.service","version":1,"moves":[]}',
      record('{}'),
      record('[3]'),
      record('[{"members":["1"]}]'),
      record('[{"id":3,"members":["1"]}]'),
      record('[{"id":"g","members":"1"}]'),
      record('[{"id":"g","members":[1]}]'),
      record('[{"id":"g","members":["1"],"label":5}]'),
    ]) {
      expect(() => decodeServiceRecord(bad), throwsFormatException,
          reason: bad);
    }
  });
}
