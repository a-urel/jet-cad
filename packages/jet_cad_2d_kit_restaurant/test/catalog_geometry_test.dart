// Sub-project 4a Task 1 (spec R1): the ported catalog draws what the old
// `jet_cad_restaurant_symbols` catalog drew. The old catalog is read from a
// committed fixture (test/fixtures/old_catalog_geometry.json), exported once
// by a one-off script from the old package; the kit may not name the old
// package. Every stored coordinate is compared with exact `==`.
//
// The fixture was written with (from the repository root, the old package
// being a workspace member):
//   dart --packages=.dart_tool/package_config.json export_old_catalog.dart \
//     packages/jet_cad_2d_kit_restaurant/test/fixtures/old_catalog_geometry.json
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';
import 'package:jet_cad_2d_kit_restaurant/src/catalog/restaurant_catalog.dart';

/// The 8 old keys with one segment after the kit id, which the contract
/// refuses (a symbol key is a kit id and two or more segments): old key to
/// the new one. Decided with the controller, spec R1.
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

/// The new catalog's key for the fixture's [oldKey].
String _newKey(String oldKey) => _renamed[oldKey] ?? oldKey;

double _d(Object? v) => (v! as num).toDouble();

CatalogPoint _pt(Object? v) {
  final l = v! as List<Object?>;
  return (_d(l[0]), _d(l[1]));
}

/// The fixture's shape as the catalog language's.
CatalogShape _shape(Map<String, Object?> j) => switch (j['kind']) {
      'line' => CatalogLine(_pt(j['from']), _pt(j['to'])),
      'polyline' => CatalogPolyline(
          [for (final p in j['points']! as List<Object?>) _pt(p)],
          closed: j['closed']! as bool),
      'circle' => CatalogCircle(_pt(j['center']), _d(j['radius'])),
      'arc' => CatalogArc(
          _pt(j['center']), _d(j['radius']), _d(j['start']), _d(j['sweep'])),
      final k => throw StateError('unknown shape kind $k'),
    };

/// The axis-aligned bounds [x0, y0, x1, y1] of [shapes]: vertices, circle
/// extents, and an arc's end points and the cardinal points its sweep passes.
List<double> _bounds(List<CatalogShape> shapes) {
  var x0 = double.infinity, y0 = double.infinity;
  var x1 = -double.infinity, y1 = -double.infinity;
  void add(double x, double y) {
    x0 = math.min(x0, x);
    y0 = math.min(y0, y);
    x1 = math.max(x1, x);
    y1 = math.max(y1, y);
  }

  for (final s in shapes) {
    switch (s) {
      case CatalogLine(:final from, :final to):
        add(from.$1, from.$2);
        add(to.$1, to.$2);
      case CatalogPolyline(:final points):
        for (final (x, y) in points) {
          add(x, y);
        }
      case CatalogCircle(:final center, :final radius):
        add(center.$1 - radius, center.$2 - radius);
        add(center.$1 + radius, center.$2 + radius);
      case CatalogArc(:final center, :final radius, :final start, :final sweep):
        void at(double a) => add(
            center.$1 + radius * math.cos(a), center.$2 + radius * math.sin(a));
        at(start);
        at(start + sweep);
        final lo = math.min(start, start + sweep);
        final hi = math.max(start, start + sweep);
        for (var k = (lo / (math.pi / 2)).ceil(); k * math.pi / 2 <= hi; k++) {
          at(k * math.pi / 2);
        }
    }
  }
  return [x0, y0, x1, y1];
}

/// A readable form of a shape, for failure messages.
String _show(CatalogShape s) => switch (s) {
      CatalogLine(:final from, :final to) => 'line $from -> $to',
      CatalogPolyline(:final points, :final closed) =>
        'polyline closed=$closed $points',
      CatalogCircle(:final center, :final radius) => 'circle $center r$radius',
      CatalogArc(:final center, :final radius, :final start, :final sweep) =>
        'arc $center r$radius $start +$sweep',
    };

/// Whether [a] and [b] are the same shape, every stored value exactly `==`.
bool _same(CatalogShape a, CatalogShape b) => switch ((a, b)) {
      (final CatalogLine a, final CatalogLine b) =>
        a.from == b.from && a.to == b.to,
      (final CatalogPolyline a, final CatalogPolyline b) => a.closed ==
              b.closed &&
          a.points.length == b.points.length &&
          [for (var i = 0; i < a.points.length; i++) a.points[i] == b.points[i]]
              .every((e) => e),
      (final CatalogCircle a, final CatalogCircle b) =>
        a.center == b.center && a.radius == b.radius,
      (final CatalogArc a, final CatalogArc b) => a.center == b.center &&
          a.radius == b.radius &&
          a.start == b.start &&
          a.sweep == b.sweep,
      _ => false,
    };

void main() {
  final fixture = (jsonDecode(
          File('test/fixtures/old_catalog_geometry.json').readAsStringSync())
      as Map<String, Object?>)['symbols']! as List<Object?>;
  final old = [for (final e in fixture) e! as Map<String, Object?>];
  final fresh = {for (final s in restaurantCatalog.symbols) s.key: s};
  final oldKeys = [for (final e in old) e['key']! as String];

  group('the fixture', () {
    test('holds the old catalog\'s 69 symbols, 25 of them seated', () {
      expect(old.length, 69);
      expect(old.where((e) => e['seats'] != null).length, 25);
    });
  });

  group('the ported catalog equals the old one', () {
    test('has the same 69 keys, renamed per the table, in the same order', () {
      expect(restaurantCatalog.symbols.map((s) => s.key).toList(),
          [for (final k in oldKeys) _newKey(k)]);
      expect(fresh.length, 69);
    });

    test('the rename table covers exactly the old keys the contract refuses',
        () {
      final refused = {
        for (final k in oldKeys)
          if (!isSymbolKey(k)) k,
      };
      expect(_renamed.keys.toSet(), refused);
      expect(refused.length, 8);
      for (final n in _renamed.values) {
        expect(isSymbolKey(n), isTrue, reason: n);
      }
    });

    test('is the restaurant kit\'s, all at version 1, none retired', () {
      expect(restaurantCatalog.kit, 'restaurant');
      for (final s in restaurantCatalog.symbols) {
        expect(s.version, 1, reason: s.key);
        expect(s.retired, isFalse, reason: s.key);
        expect(s.key, startsWith('restaurant.'));
      }
    });

    for (final e in old) {
      final key = e['key']! as String;
      test(key, () {
        final s = fresh[_newKey(key)];
        expect(s, isNotNull, reason: 'no symbol $key');
        s!;
        expect(s.name, e['name']);
        expect(s.category, e['category']);
        expect(s.tags, e['tags']);
        expect(s.base, _pt(e['base']));
        final shapes = [
          for (final j in e['shapes']! as List<Object?>)
            _shape(j! as Map<String, Object?>)
        ];
        expect(s.shapes.length, shapes.length);
        for (var i = 0; i < shapes.length; i++) {
          expect(_same(s.shapes[i], shapes[i]), isTrue,
              reason: 'shape $i: now ${_show(s.shapes[i])}, '
                  'was ${_show(shapes[i])}');
        }
        expect(_bounds(s.shapes),
            [for (final v in e['bounds']! as List<Object?>) _d(v)]);
      });
    }
  });
}
