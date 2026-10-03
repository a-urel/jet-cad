// Spec 14 V-6, V-6a, plan Tasks 6-7: the restaurant library. The committed
// asset equals what the catalog builds; every key, category, seat count and
// closed-polyline count below is written out by hand from the spec's list,
// not derived from the catalog; and every entry obeys the library's rules.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart'
    show placeSymbol, prepareDocument, registerAppComponents;
import 'package:jet_cad_floor_plan/symbols.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

Uint8List builtBytes() => Uint8List.fromList(utf8.encode(
    DraftDocumentCodec.encodeToString(buildSymbolLibrary(restaurantCatalog))));

Uint8List assetBytes() => File('assets/restaurant.jetlib').readAsBytesSync();

SymbolLibrary assetLibrary() => SymbolLibrary.decode(assetBytes());

SymbolEntry entryOf(String key) =>
    assetLibrary().entries.firstWhere((e) => e.key == key);

/// Every key, in palette order, with its category, its seats (null: not
/// servable) and its count of closed polylines. Written out by hand.
const List<(String, String, int?, int)> expected = [
  // Restaurant Tables: top, inset, one closed seat per chair.
  ('restaurant.table.square.two', 'Restaurant Tables', 2, 4),
  ('restaurant.table.square.four', 'Restaurant Tables', 4, 6),
  ('restaurant.table.rect.four', 'Restaurant Tables', 4, 6),
  ('restaurant.table.rect.six', 'Restaurant Tables', 6, 8),
  ('restaurant.table.rect.eight', 'Restaurant Tables', 8, 10),
  ('restaurant.table.rect.ten', 'Restaurant Tables', 10, 12),
  ('restaurant.table.rect.twelve', 'Restaurant Tables', 12, 14),
  ('restaurant.table.round.two', 'Restaurant Tables', 2, 2),
  ('restaurant.table.round.four', 'Restaurant Tables', 4, 4),
  ('restaurant.table.round.six', 'Restaurant Tables', 6, 6),
  ('restaurant.table.round.eight', 'Restaurant Tables', 8, 8),
  ('restaurant.table.round.ten', 'Restaurant Tables', 10, 10),
  // Booths and Lounge.
  ('restaurant.booth.two', 'Booths and Lounge', 2, 4),
  ('restaurant.booth.four', 'Booths and Lounge', 4, 4),
  ('restaurant.booth.six', 'Booths and Lounge', 6, 4),
  ('restaurant.booth.corner', 'Booths and Lounge', 5, 4),
  ('restaurant.booth.round', 'Booths and Lounge', 6, 0),
  ('restaurant.banquette.two', 'Booths and Lounge', 2, 4),
  ('restaurant.banquette.four', 'Booths and Lounge', 4, 5),
  ('restaurant.lounge.four', 'Booths and Lounge', 4, 4),
  ('restaurant.lounge.two', 'Booths and Lounge', 2, 2),
  // Bar.
  ('restaurant.bar.stool', 'Bar', 1, 0),
  ('restaurant.bar.table.high.two', 'Bar', 2, 0),
  ('restaurant.bar.table.high.four', 'Bar', 4, 0),
  ('restaurant.bar.table.ledge', 'Bar', 4, 1),
  ('restaurant.bar.counter', 'Bar', null, 1),
  ('restaurant.bar.counter.corner', 'Bar', null, 1),
  ('restaurant.bar.counter.u', 'Bar', null, 1),
  ('restaurant.bar.back', 'Bar', null, 1),
  ('restaurant.bar.taps', 'Bar', null, 1),
  // Service.
  ('restaurant.cashier', 'Service', null, 2),
  ('restaurant.host.stand', 'Service', null, 2),
  ('restaurant.pos.terminal', 'Service', null, 2),
  ('restaurant.service.station', 'Service', null, 1),
  ('restaurant.buffet', 'Service', null, 5),
  ('restaurant.salad.bar', 'Service', null, 7),
  ('restaurant.dessert.display', 'Service', null, 1),
  ('restaurant.drinks.fridge', 'Service', null, 1),
  ('restaurant.coffee.station', 'Service', null, 2),
  ('restaurant.service.cart', 'Service', null, 2),
  ('restaurant.tray.stand', 'Service', null, 1),
  ('restaurant.highchair', 'Service', null, 1),
  ('restaurant.waiting.bench', 'Service', null, 1),
  ('restaurant.coat.rack', 'Service', null, 0),
  // Commercial Kitchen.
  ('restaurant.kitchen.pass', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.prep.table', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.range.four', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.range.six', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.fryer', 'Commercial Kitchen', null, 3),
  ('restaurant.kitchen.griddle', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.oven.convection', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.oven.pizza', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.dishwasher', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.sink.three', 'Commercial Kitchen', null, 4),
  ('restaurant.kitchen.sink.hand', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.fridge.reachin', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.freezer', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.walkin', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.shelving', 'Commercial Kitchen', null, 1),
  ('restaurant.kitchen.ice.machine', 'Commercial Kitchen', null, 2),
  ('restaurant.kitchen.bin', 'Commercial Kitchen', null, 0),
  // Outdoor and Decor.
  ('restaurant.parasol', 'Outdoor and Decor', null, 0),
  ('restaurant.heater', 'Outdoor and Decor', null, 0),
  ('restaurant.planter.round', 'Outdoor and Decor', null, 0),
  ('restaurant.planter.long', 'Outdoor and Decor', null, 2),
  ('restaurant.partition', 'Outdoor and Decor', null, 1),
  ('restaurant.stage', 'Outdoor and Decor', null, 1),
  ('restaurant.dj.booth', 'Outdoor and Decor', null, 1),
  ('restaurant.piano', 'Outdoor and Decor', null, 2),
];

/// The seats drawn one by one (a 450 x 450 chair or a Ø 380 stool), where
/// a symbol draws them so; a bench or a sofa is not counted. Written out by
/// hand.
const Map<String, int> drawnSeats = {
  'restaurant.table.square.two': 2,
  'restaurant.table.square.four': 4,
  'restaurant.table.rect.four': 4,
  'restaurant.table.rect.six': 6,
  'restaurant.table.rect.eight': 8,
  'restaurant.table.rect.ten': 10,
  'restaurant.table.rect.twelve': 12,
  'restaurant.table.round.two': 2,
  'restaurant.table.round.four': 4,
  'restaurant.table.round.six': 6,
  'restaurant.table.round.eight': 8,
  'restaurant.table.round.ten': 10,
  'restaurant.booth.corner': 1,
  'restaurant.banquette.two': 1,
  'restaurant.banquette.four': 2,
  'restaurant.bar.stool': 1,
  'restaurant.bar.table.high.two': 2,
  'restaurant.bar.table.high.four': 4,
  'restaurant.bar.table.ledge': 4,
};

typedef Leaf = ({EntityRecord record, GeometryPayload payload});

List<Vector2> pointsOf(GeometryPayload p) =>
    [for (var i = 0; i < p.pointCount; i++) p.pointAt(i)];

/// A 4-point closed polyline whose sides are all 450: a chair's seat.
bool isChair(Leaf l) {
  if (l.record.kind != EntityKind.polyline) return false;
  if (!isClosedPolyline(l.payload)) return false;
  final pts = pointsOf(l.payload);
  // A closed polyline may or may not repeat its first point.
  final ring =
      pts.length == 5 && pts.first == pts.last ? pts.sublist(0, 4) : pts;
  if (ring.length != 4) return false;
  for (var i = 0; i < 4; i++) {
    if (((ring[(i + 1) % 4] - ring[i]).length - 450).abs() > 1e-6) {
      return false;
    }
  }
  return true;
}

/// A Ø 380 circle: a stool's seat.
bool isStool(Leaf l) =>
    l.record.kind == EntityKind.circle &&
    (l.payload.scalars[0] - 190).abs() < 1e-9;

/// The served top's centre: its circle's centre, or its polyline's box
/// centre.
Vector2 centreOf(Leaf top) {
  if (top.record.kind == EntityKind.circle) return top.payload.pointAt(0);
  final pts = pointsOf(top.payload);
  var minX = pts.first.x, maxX = minX, minY = pts.first.y, maxY = minY;
  for (final p in pts) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  return Vector2((minX + maxX) / 2, (minY + maxY) / 2);
}

/// How deep [seat] (its corner points, or its circle) reaches into [top]
/// (a circle or an axis-aligned rectangle): 0 when it stays outside.
double penetration(Leaf top, Leaf seat) {
  if (top.record.kind == EntityKind.circle) {
    final c = top.payload.pointAt(0);
    final r = top.payload.scalars[0];
    if (seat.record.kind == EntityKind.circle) {
      final d = (seat.payload.pointAt(0) - c).length;
      return math.max(0, r - (d - seat.payload.scalars[0]));
    }
    // The nearest point of a convex polygon to the centre: on an edge.
    var best = double.infinity;
    final pts = pointsOf(seat.payload);
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      final ab = b - a;
      final t = ((c - a).dot(ab) / ab.length2).clamp(0.0, 1.0);
      best = math.min(best, (a + ab * t - c).length);
    }
    return math.max(0, r - best);
  }
  final tp = pointsOf(top.payload);
  final tminX = tp.map((p) => p.x).reduce(math.min);
  final tmaxX = tp.map((p) => p.x).reduce(math.max);
  final tminY = tp.map((p) => p.y).reduce(math.min);
  final tmaxY = tp.map((p) => p.y).reduce(math.max);
  final double sminX, smaxX, sminY, smaxY;
  if (seat.record.kind == EntityKind.circle) {
    final c = seat.payload.pointAt(0);
    final r = seat.payload.scalars[0];
    (sminX, smaxX, sminY, smaxY) = (c.x - r, c.x + r, c.y - r, c.y + r);
  } else {
    final sp = pointsOf(seat.payload);
    sminX = sp.map((p) => p.x).reduce(math.min);
    smaxX = sp.map((p) => p.x).reduce(math.max);
    sminY = sp.map((p) => p.y).reduce(math.min);
    smaxY = sp.map((p) => p.y).reduce(math.max);
  }
  final ox = math.min(tmaxX, smaxX) - math.max(tminX, sminX);
  final oy = math.min(tmaxY, smaxY) - math.max(tminY, sminY);
  if (ox <= 0 || oy <= 0) return 0;
  return math.min(ox, oy);
}

/// Whether two convex seats overlap (separating axis test; circles by
/// their centres' distance, a circle against a polygon by its box).
bool overlap(Leaf a, Leaf b) {
  if (a.record.kind == EntityKind.circle &&
      b.record.kind == EntityKind.circle) {
    return (a.payload.pointAt(0) - b.payload.pointAt(0)).length <
        a.payload.scalars[0] + b.payload.scalars[0] - 1e-9;
  }
  List<Vector2> poly(Leaf l) {
    if (l.record.kind == EntityKind.polyline) return pointsOf(l.payload);
    final c = l.payload.pointAt(0);
    final r = l.payload.scalars[0];
    return [
      Vector2(c.x - r, c.y - r),
      Vector2(c.x + r, c.y - r),
      Vector2(c.x + r, c.y + r),
      Vector2(c.x - r, c.y + r),
    ];
  }

  final pa = poly(a), pb = poly(b);
  for (final pts in [pa, pb]) {
    for (var i = 0; i < pts.length; i++) {
      final e = pts[(i + 1) % pts.length] - pts[i];
      final axis = Vector2(-e.y, e.x);
      double lo(List<Vector2> q) => q.map((p) => p.dot(axis)).reduce(math.min);
      double hi(List<Vector2> q) => q.map((p) => p.dot(axis)).reduce(math.max);
      if (hi(pa) <= lo(pb) + 1e-6 || hi(pb) <= lo(pa) + 1e-6) return false;
    }
  }
  return true;
}

/// A bundle that serves fixed bytes under the keys it holds, and nothing
/// else.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  group('the asset', () {
    test('RL1 the committed bytes equal the built library', () {
      expect(builtBytes(), orderedEquals(assetBytes()),
          reason: 'run `dart run tool/generate_restaurant_library.dart`');
    });

    test('RL2 building twice gives identical bytes', () {
      expect(builtBytes(), orderedEquals(builtBytes()));
    });

    test('RL3 is declared in the pubspec and read under the package key',
        () async {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
          RegExp(r'^\s*-\s+assets/restaurant\.jetlib\s*$', multiLine: true)
              .hasMatch(pubspec),
          isTrue);
      // Written out, not read from the constant.
      const key =
          'packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib';
      expect(kRestaurantLibraryAsset, key);
      final bytes = assetBytes();
      expect(await readRestaurantLibrary(_MapBundle({key: bytes})),
          orderedEquals(bytes));
      expect(restaurantSymbolSource.name, 'restaurant');
    });
  });

  group('the list (written out by hand)', () {
    test('RL4 69 symbols: every key once, in order, with its category', () {
      final lib = assetLibrary();
      expect(expected, hasLength(69), reason: 'premise: the spec\'s count');
      expect([for (final e in lib.entries) e.key],
          [for (final x in expected) x.$1]);
      for (final (key, category, _, _) in expected) {
        expect(entryOf(key).category, category, reason: key);
      }
      expect(lib.categories, restaurantCategories);
      expect(restaurantCategories, [
        'Restaurant Tables',
        'Booths and Lounge',
        'Bar',
        'Service',
        'Commercial Kitchen',
        'Outdoor and Decor',
      ]);
    });

    test('RL5 the servable symbols and their seats (M-14s-1)', () {
      for (final (key, _, seats, _) in expected) {
        expect(entryOf(key).seats, seats, reason: key);
      }
      expect(expected.where((x) => x.$3 != null), hasLength(25));
    });

    test('RL6 every polyline is closed, and each symbol has its count', () {
      for (final (key, _, _, closed) in expected) {
        final polylines = entryOf(key)
            .leaves
            .where((l) => l.record.kind == EntityKind.polyline)
            .toList();
        for (final l in polylines) {
          expect(isClosedPolyline(l.payload), isTrue, reason: key);
        }
        expect(polylines, hasLength(closed), reason: key);
      }
    });

    test('RL7 every key is lower-case dotted, two tags or more, version 1', () {
      for (final e in assetLibrary().entries) {
        expect(RegExp(r'^restaurant(\.[a-z0-9]+)+$').hasMatch(e.key), isTrue,
            reason: e.key);
        expect(e.tags.length, greaterThanOrEqualTo(2), reason: e.key);
        expect(e.version, 1, reason: e.key);
      }
    });
  });

  group('the rules over every entry', () {
    test('RL8 every base point is off the origin', () {
      for (final e in assetLibrary().entries) {
        expect(e.definition.basePoint.x != 0 || e.definition.basePoint.y != 0,
            isTrue,
            reason: e.key);
      }
    });

    test(
        'RL9 a servable symbol draws its served top first, and its base point '
        'is the top\'s centre (S4, M-14s-4)', () {
      for (final e in assetLibrary().entries.where((e) => e.seats != null)) {
        final top = e.leaves.first;
        expect(
            top.record.kind == EntityKind.circle ||
                (top.record.kind == EntityKind.polyline &&
                    isClosedPolyline(top.payload)),
            isTrue,
            reason: e.key);
        if (e.key != 'restaurant.bar.stool') {
          expect(isChair(top) || isStool(top), isFalse,
              reason: '${e.key}: a seat is not the top');
        }
        expect(e.definition.basePoint, centreOf(top), reason: e.key);
      }
    });

    test('RL10 each symbol draws its seats one by one where it says so', () {
      for (final e in assetLibrary().entries) {
        // Over every leaf: no top is a chair or a Ø 380 circle, and a bar
        // stool's own seat is its first leaf.
        final seats = e.leaves.where((l) => isChair(l) || isStool(l));
        expect(seats.length, drawnSeats[e.key] ?? 0, reason: e.key);
      }
    });

    test(
        'RL11 no chair reaches more than 100 and no stool more than 40 under '
        'its top, and no two seats overlap (M-14s-6)', () {
      for (final e in assetLibrary().entries) {
        if (!drawnSeats.containsKey(e.key)) continue;
        final top = e.leaves.first;
        final seats =
            e.leaves.skip(1).where((l) => isChair(l) || isStool(l)).toList();
        for (final s in seats) {
          final limit = isChair(s) ? 100.0 : 40.0;
          if (e.key == 'restaurant.bar.stool') continue; // its own top
          expect(penetration(top, s), lessThanOrEqualTo(limit + 1e-6),
              reason: e.key);
          expect(penetration(top, s), greaterThan(0),
              reason: '${e.key}: a seat sits at its top');
        }
        for (var i = 0; i < seats.length; i++) {
          for (var j = i + 1; j < seats.length; j++) {
            expect(overlap(seats[i], seats[j]), isFalse,
                reason: '${e.key}: seats $i and $j');
          }
        }
      }
    });

    test(
        'RL16 every chair faces its top: its back line, the leaf after its '
        'seat, is 165 from the seat\'s centre, straight away from the top', () {
      var checked = 0;
      for (final e in assetLibrary().entries) {
        final top = e.leaves.first;
        for (var i = 1; i < e.leaves.length; i++) {
          if (!isChair(e.leaves[i])) continue;
          final back = e.leaves[i + 1];
          expect(back.record.kind, EntityKind.line, reason: e.key);
          final seat = pointsOf(e.leaves[i].payload);
          final centre =
              seat.take(4).fold(Vector2.zero(), (a, p) => a + p) / 4.0;
          final mid = (back.payload.pointAt(0) + back.payload.pointAt(1)) / 2.0;
          // The top's nearest point to the seat's centre.
          final Vector2 near;
          if (top.record.kind == EntityKind.circle) {
            final c = top.payload.pointAt(0);
            near = c + (centre - c).normalized() * top.payload.scalars[0];
          } else {
            final tp = pointsOf(top.payload);
            near = Vector2(
                centre.x.clamp(tp.map((p) => p.x).reduce(math.min),
                    tp.map((p) => p.x).reduce(math.max)),
                centre.y.clamp(tp.map((p) => p.y).reduce(math.min),
                    tp.map((p) => p.y).reduce(math.max)));
          }
          final out = mid - centre;
          expect(out.length, closeTo(165, 1e-6), reason: e.key);
          expect(out.normalized().dot((centre - near).normalized()),
              closeTo(1, 1e-9),
              reason: '${e.key}: chair at leaf $i');
          checked++;
        }
      }
      // Written out: 46 around the rectangular tables, 30 around the round
      // ones, one at the corner booth, three at the banquettes.
      expect(checked, 80, reason: 'premise: every drawn chair was seen');
    });

    test('RL12 a booth\'s benches stay outside its top beyond the tuck', () {
      for (final key in const [
        'restaurant.booth.two',
        'restaurant.booth.four',
        'restaurant.booth.six',
        'restaurant.banquette.two',
        'restaurant.banquette.four',
      ]) {
        final e = entryOf(key);
        final top = e.leaves.first;
        // The benches: the closed polylines after the inset that are not
        // chairs.
        final benches = e.leaves
            .skip(2)
            .where((l) => l.record.kind == EntityKind.polyline && !isChair(l))
            .toList();
        expect(benches, isNotEmpty, reason: key);
        for (final b in benches) {
          expect(penetration(top, b), closeTo(100, 1e-6), reason: key);
        }
      }
    });
  });

  group('every symbol placed', () {
    final at = Vector2(-23456, 7890);
    for (final (key, _, _, _) in expected) {
      test('RL13 $key, quarter-turned and mirrored, validates and covers at',
          () {
        final entry = entryOf(key);
        for (final q in const [1, 3]) {
          final doc = prepareDocument(const InsertionPointMeasurer());
          doc.commands.execute(placeSymbol(doc, entry,
              at: at, quarterTurns: q, mirrored: q == 3));
          expect(doc.validate(), isEmpty, reason: key);
          final box = doc.extents;
          expect(at.x, inInclusiveRange(box.minX, box.maxX), reason: key);
          expect(at.y, inInclusiveRange(box.minY, box.maxY), reason: key);
        }
      });
    }

    test('RL14 each is between 100 and 5000 mm on each axis', () {
      for (final (key, _, _, _) in expected) {
        final doc = DraftDocument.empty();
        registerAppComponents(doc.components);
        doc.commands.execute(placeSymbol(doc, entryOf(key), at: Vector2(0, 0)));
        final size = doc.extents.size;
        expect(size.x, inInclusiveRange(100, 5000), reason: key);
        expect(size.y, inInclusiveRange(100, 5000), reason: key);
      }
    });
  });

  test('RL15 the furniture and restaurant libraries merge without a clash', () {
    final furniture = SymbolLibrary.decode(Uint8List.fromList(utf8
        .encode(DraftDocumentCodec.encodeToString(buildFurnitureLibrary()))));
    final merged = SymbolLibrary.merge(
        [('furniture', furniture), ('restaurant', assetLibrary())]);
    expect(merged.entries, hasLength(furniture.entries.length + 69));
    expect(merged.categories.take(6).toList(), furniture.categories);
    expect(merged.categories.skip(6).toList(), restaurantCategories);
  });
}
