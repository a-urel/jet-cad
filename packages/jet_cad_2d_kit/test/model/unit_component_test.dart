// Spec K2 and umbrella A6: the service unit (ported from
// jet_cad_floor_plan's seating_test SE1-SE3, `seats` now `capacity`).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

UnitComponent table({
  String kind = UnitKinds.table,
  int capacity = 6,
  UnitLabelling labelling = UnitLabelling.numbered,
}) =>
    UnitComponent(kind: kind, capacity: capacity, labelling: labelling);

void main() {
  test('U1 refusals: a kind off the pattern, a capacity below one', () {
    // M-U1: drop either check; its line goes red.
    expect(() => table(kind: 'Table'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kind')));
    expect(() => table(kind: 'bar table'), throwsArgumentError);
    expect(
        () => table(capacity: 0),
        throwsA(
            isA<ArgumentError>().having((e) => e.name, 'name', 'capacity')));
    expect(() => table(capacity: -4), throwsArgumentError);
    expect(table(capacity: 1).capacity, 1);
    expect(table(kind: 'bed-space').kind, 'bed-space');
  });

  test('U2 the named kinds and the default labelling', () {
    expect(UnitKinds.table, 'table');
    expect(UnitKinds.seat, 'seat');
    expect(UnitComponent(kind: UnitKinds.seat, capacity: 1).labelling,
        UnitLabelling.numbered);
  });

  test('U3 equality sees every field', () {
    expect(table(), table());
    expect(table().hashCode, table().hashCode);
    expect(table(), isNot(table(kind: UnitKinds.seat)));
    expect(table(), isNot(table(capacity: 5)));
    // M-U3: drop labelling from ==.
    expect(table(), isNot(table(labelling: UnitLabelling.assigned)));
  });

  test('U4 the JSON text is pinned and reads back', () {
    expect(table().typeId, 'jetcad.unit');
    expect(jsonEncode(table().toJson()),
        '{"capacity":6,"kind":"table","labelling":"numbered"}');
    final seat = table(
        kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned);
    expect(jsonEncode(seat.toJson()),
        '{"capacity":1,"kind":"seat","labelling":"assigned"}');
    expect(UnitComponent.fromJson(seat.toJson()), seat);
  });

  test('U5 fromJson refusals', () {
    const full = <String, Object?>{
      'capacity': 6,
      'kind': 'table',
      'labelling': 'numbered',
    };
    expect(UnitComponent.fromJson(full), table());
    for (final field in full.keys) {
      expect(() => UnitComponent.fromJson({...full}..remove(field)),
          throwsFormatException,
          reason: field);
    }
    // M-U5: `UnitLabelling.values.byName` throws an ArgumentError instead.
    expect(() => UnitComponent.fromJson({...full, 'labelling': 'random'}),
        throwsFormatException);
    expect(() => UnitComponent.fromJson({...full, 'capacity': '6'}),
        throwsFormatException);
    expect(() => UnitComponent.fromJson({...full, 'capacity': 0}),
        throwsArgumentError);
  });
}
