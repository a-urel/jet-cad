// Sub-project 4a Task 2 (spec R1, decision 10; U1-U3): the 25 seated symbols
// are numbered table units, no other symbol is, and the synchronous entries a
// sample build places are the ones the loader yields from the asset. The
// seated set is read from the old catalog's fixture, so it is the old one by
// construction, not a list written here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';

/// The 8 renamed keys, old to new (as test/catalog_geometry_test.dart).
const Map<String, String> _renamed = {
  'restaurant.cashier': 'restaurant.cashier.desk',
  'restaurant.buffet': 'restaurant.buffet.counter',
  'restaurant.highchair': 'restaurant.highchair.child',
  'restaurant.parasol': 'restaurant.parasol.round',
  'restaurant.heater': 'restaurant.heater.patio',
  'restaurant.partition': 'restaurant.partition.screen',
  'restaurant.stage': 'restaurant.stage.platform',
  'restaurant.piano': 'restaurant.piano.grand',
};

/// The fixture's new key to its old `seats` (null: not seated), all 69.
Map<String, int?> fixtureSeats() {
  final json = jsonDecode(
          File('test/fixtures/old_catalog_geometry.json').readAsStringSync())
      as Map<String, Object?>;
  return {
    for (final s
        in (json['symbols']! as List<Object?>).cast<Map<String, Object?>>())
      _renamed[s['key']] ?? s['key'] as String: s['seats'] as int?,
  };
}

SymbolLibrary assetLibrary() => SymbolLibrary.decode(
    File('assets/library/restaurant.jetlib').readAsBytesSync());

void main() {
  final seats = fixtureSeats();
  final entries = {for (final e in assetLibrary().entries) e.symbol.key: e};

  test('premise: the fixture has 69 symbols, 25 of them seated', () {
    expect(seats, hasLength(69));
    expect(seats.values.where((s) => s != null), hasLength(25));
    expect(entries.keys.toSet(), seats.keys.toSet());
  });

  test(
      'U1 exactly the fixture\'s seated keys are numbered table units whose '
      'capacity is the old seats', () {
    for (final MapEntry(key: key, value: n) in seats.entries) {
      if (n == null) continue;
      final unit = entries[key]!.unit;
      expect(unit, isNotNull, reason: key);
      expect(unit!.kind, UnitKinds.table, reason: key);
      expect(unit.capacity, n, reason: key);
      expect(unit.labelling, UnitLabelling.numbered, reason: key);
    }
  });

  test('U2 no other key is a unit', () {
    for (final MapEntry(key: key, value: n) in seats.entries) {
      if (n != null) continue;
      expect(entries[key]!.unit, isNull, reason: key);
    }
    expect(entries.values.where((e) => e.unit != null), hasLength(25));
  });

  test(
      'a unit draws a closed outline or a circle first, and has no size '
      'family (SC1)', () {
    for (final e in entries.values.where((e) => e.unit != null)) {
      expect(e.symbol.family, isNull, reason: e.symbol.key);
    }
  });

  test('U3 a sample build\'s entry is the loader\'s: key, capacity, outline',
      () {
    final sync = restaurantSymbolEntries();
    // Three seated keys of different shape and capacity: a rectangular
    // table, a round booth, the bar stool.
    for (final key in const [
      'restaurant.table.rect.eight',
      'restaurant.booth.round',
      'restaurant.bar.stool',
    ]) {
      final mine = sync['$key@1']!;
      final loaded = entries[key]!;
      expect(mine.symbol.key, loaded.symbol.key, reason: key);
      expect(mine.unit!.capacity, loaded.unit!.capacity, reason: key);
      expect(mine.unit!.kind, loaded.unit!.kind, reason: key);
      expect(mine.definition.name, loaded.definition.name, reason: key);
      expect(mine.definition.basePoint, loaded.definition.basePoint,
          reason: key);
      expect(restaurantSymbolDefinitions()['$key@1'], same(mine.definition),
          reason: key);
      expect(mine.leaves.first.record.kind, loaded.leaves.first.record.kind,
          reason: key);
      expect(mine.leaves.first.payload.pointCount,
          loaded.leaves.first.payload.pointCount,
          reason: key);
      expect(mine.leaves.first.payload.scalars,
          loaded.leaves.first.payload.scalars,
          reason: key);
    }
  });

  test('U3 every sync entry carries the unit the asset carries', () {
    final sync = restaurantSymbolEntries();
    expect(sync.keys.toSet(), {for (final k in entries.keys) '$k@1'});
    for (final e in entries.values) {
      expect(sync['${e.symbol.key}@1']!.unit?.capacity, e.unit?.capacity,
          reason: e.symbol.key);
    }
  });
}
