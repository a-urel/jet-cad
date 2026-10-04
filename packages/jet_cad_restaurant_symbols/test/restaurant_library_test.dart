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
  ('restaurant.kitchen.walkin', 'Commercial Kitchen', null, 1),
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

/// The served top of each servable symbol, written out by hand from spec 14
/// V-6 (review F-1, F-3): `(width, depth)` of a rectangle, or `(d, d)` with
/// [roundTops] for a circle of diameter d.
const Map<String, (double, double)> topSizes = {
  'restaurant.table.square.two': (700, 700),
  'restaurant.table.square.four': (800, 800),
  'restaurant.table.rect.four': (1200, 750),
  'restaurant.table.rect.six': (1800, 800),
  'restaurant.table.rect.eight': (2400, 900),
  'restaurant.table.rect.ten': (3000, 900),
  'restaurant.table.rect.twelve': (3600, 1000),
  'restaurant.table.round.two': (600, 600),
  'restaurant.table.round.four': (900, 900),
  'restaurant.table.round.six': (1200, 1200),
  'restaurant.table.round.eight': (1500, 1500),
  'restaurant.table.round.ten': (1800, 1800),
  'restaurant.booth.two': (700, 700),
  'restaurant.booth.four': (1200, 700),
  'restaurant.booth.six': (1800, 750),
  'restaurant.booth.corner': (1200, 800),
  'restaurant.booth.round': (1200, 1200),
  'restaurant.banquette.two': (700, 700),
  'restaurant.banquette.four': (1400, 700),
  'restaurant.lounge.four': (1000, 600),
  'restaurant.lounge.two': (600, 600),
  'restaurant.bar.stool': (380, 380),
  'restaurant.bar.table.high.two': (600, 600),
  'restaurant.bar.table.high.four': (700, 700),
  'restaurant.bar.table.ledge': (2000, 400),
};

/// The servable symbols whose top is a circle. Written out by hand.
const Set<String> roundTops = {
  'restaurant.table.round.two',
  'restaurant.table.round.four',
  'restaurant.table.round.six',
  'restaurant.table.round.eight',
  'restaurant.table.round.ten',
  'restaurant.booth.round',
  'restaurant.lounge.two',
  'restaurant.bar.stool',
  'restaurant.bar.table.high.two',
  'restaurant.bar.table.high.four',
};

/// The shoelace area of a closed ring.
double ringArea(List<Vector2> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a.abs() / 2;
}

/// [ring] clipped to the axis-aligned box (Sutherland-Hodgman).
List<Vector2> clipToBox(
    List<Vector2> ring, double minX, double minY, double maxX, double maxY) {
  var out = ring;
  for (final (inside, cut)
      in <(bool Function(Vector2), Vector2 Function(Vector2, Vector2))>[
    ((p) => p.x >= minX, (a, b) => a + (b - a) * ((minX - a.x) / (b.x - a.x))),
    ((p) => p.x <= maxX, (a, b) => a + (b - a) * ((maxX - a.x) / (b.x - a.x))),
    ((p) => p.y >= minY, (a, b) => a + (b - a) * ((minY - a.y) / (b.y - a.y))),
    ((p) => p.y <= maxY, (a, b) => a + (b - a) * ((maxY - a.y) / (b.y - a.y))),
  ]) {
    final input = out;
    out = [];
    for (var i = 0; i < input.length; i++) {
      final cur = input[i], prev = input[(i + input.length - 1) % input.length];
      if (inside(cur)) {
        if (!inside(prev)) out.add(cut(prev, cur));
        out.add(cur);
      } else if (inside(prev)) {
        out.add(cut(prev, cur));
      }
    }
    if (out.isEmpty) break;
  }
  return out;
}

/// A closed polyline's ring, without a repeated first point.
List<Vector2> ringOf(GeometryPayload p) {
  final pts = pointsOf(p);
  return pts.length > 1 && pts.first == pts.last
      ? pts.sublist(0, pts.length - 1)
      : pts;
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

  group('review fixes (F-1 to F-4, F-7)', () {
    test('RL17 each servable top has its V-6 size and shape (F-1, F-3)', () {
      final servable = assetLibrary().entries.where((e) => e.seats != null);
      expect(servable.map((e) => e.key).toSet(), topSizes.keys.toSet());
      for (final e in servable) {
        final top = e.leaves.first;
        final (w, d) = topSizes[e.key]!;
        if (roundTops.contains(e.key)) {
          expect(top.record.kind, EntityKind.circle, reason: e.key);
          expect(top.payload.scalars[0] * 2, w, reason: e.key);
        } else {
          expect(top.record.kind, EntityKind.polyline, reason: e.key);
          final ring = ringOf(top.payload);
          expect(ring, hasLength(4), reason: e.key);
          final xs = ring.map((p) => p.x), ys = ring.map((p) => p.y);
          expect(xs.reduce(math.max) - xs.reduce(math.min), w, reason: e.key);
          expect(ys.reduce(math.max) - ys.reduce(math.min), d, reason: e.key);
        }
      }
    });

    test('RL18 the first seat around a round top sits straight below it (F-4)',
        () {
      for (final key in const [
        'restaurant.table.round.two',
        'restaurant.table.round.four',
        'restaurant.table.round.six',
        'restaurant.table.round.eight',
        'restaurant.table.round.ten',
        'restaurant.bar.table.high.two',
        'restaurant.bar.table.high.four',
      ]) {
        final e = entryOf(key);
        final c = e.leaves.first.payload.pointAt(0);
        final seat =
            e.leaves.skip(1).firstWhere((l) => isChair(l) || isStool(l));
        final Vector2 sc;
        if (isStool(seat)) {
          sc = seat.payload.pointAt(0);
        } else {
          sc = ringOf(seat.payload).fold(Vector2.zero(), (a, p) => a + p) / 4.0;
        }
        expect(sc.x, closeTo(c.x, 1e-6), reason: key);
        expect(sc.y, lessThan(c.y), reason: key);
      }
    });

    test('RL19 the round booth\'s bench runs 100 under its top (F-2)', () {
      final e = entryOf('restaurant.booth.round');
      final top = e.leaves.first.payload;
      final r = top.scalars[0];
      final arcs = [
        for (final l in e.leaves)
          if (l.record.kind == EntityKind.arc) l.payload,
      ];
      // Written out by hand: the inner edge, the outer edge, the back.
      expect([for (final a in arcs) a.scalars[0]], [r - 100, r + 500, r + 350]);
      for (final a in arcs) {
        expect(a.pointAt(0), top.pointAt(0), reason: 'concentric with the top');
        expect(a.scalars[2], closeTo(math.pi, 1e-12), reason: 'a half ring');
      }
    });

    test(
        'RL20 the corner booth\'s L bench overlaps its top by 100 on each leg '
        '(F-2)', () {
      final e = entryOf('restaurant.booth.corner');
      final top = ringOf(e.leaves.first.payload);
      final xs = top.map((p) => p.x), ys = top.map((p) => p.y);
      final bench = ringOf(e.leaves[2].payload);
      expect(bench, hasLength(6), reason: 'premise: the L');
      final shared = ringArea(clipToBox(bench, xs.reduce(math.min),
          ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max)));
      // 100 deep along the 800 side, 100 deep along the 1200 side, their
      // 100 x 100 corner counted once.
      expect(shared, closeTo(100 * 800 + 100 * 1200 - 100 * 100, 1e-6));
    });

    test('RL21 a lounge set\'s seats stay clear of its low table (F-2)', () {
      for (final key in const [
        'restaurant.lounge.four',
        'restaurant.lounge.two'
      ]) {
        final e = entryOf(key);
        final top = e.leaves.first;
        final seats = e.leaves
            .skip(1)
            .where((l) => l.record.kind == EntityKind.polyline)
            .where((l) => ringArea(ringOf(l.payload)) > 400000)
            .toList();
        // Written out: lounge.four's sofa and armchair, lounge.two's two
        // armchairs (its table's inset is a circle).
        expect(seats, hasLength(key == 'restaurant.lounge.four' ? 3 : 2),
            reason: key);
        for (final s in seats) {
          if (e.key == 'restaurant.lounge.four' &&
              ringArea(ringOf(s.payload)) < 600000) {
            continue; // the table's inset
          }
          expect(penetration(top, s), 0, reason: key);
        }
      }
    });

    test('RL22 the walk-in\'s door opens out of a gap in its wall (F-7)', () {
      final e = entryOf('restaurant.kitchen.walkin');
      final wall = ringOf(e.leaves.first.payload);
      // The front wall (y = 0) is open from x 200 to 1000: no wall edge on
      // y = 0 crosses that span.
      for (var i = 0; i < wall.length; i++) {
        final a = wall[i], b = wall[(i + 1) % wall.length];
        if (a.y == 0 && b.y == 0) {
          final lo = math.min(a.x, b.x), hi = math.max(a.x, b.x);
          expect(hi <= 200 || lo >= 1000, isTrue, reason: 'edge $a-$b');
        }
      }
      // 100-thick walls: the wall's area is the outline less the room.
      expect(ringArea(wall), 2400 * 2000 - 2200 * 1800 - 800 * 100);
      final leaf = e.leaves[1].payload, swing = e.leaves[2].payload;
      expect((leaf.pointAt(0), leaf.pointAt(1)),
          (Vector2(200, 0), Vector2(200, -800)));
      // The swing: from the open leaf's end (200, -800) to the closed
      // door's end (1000, 0), outside the room.
      expect(swing.pointAt(0), Vector2(200, 0));
      expect(swing.scalars[0], 800);
      expect(swing.scalars[1], closeTo(-math.pi / 2, 1e-12));
      expect(swing.scalars[2], closeTo(math.pi / 2, 1e-12));
    });

    test('RL23 the dessert display\'s glass bulges 200 in front of it (F-7)',
        () {
      final e = entryOf('restaurant.dessert.display');
      final arc =
          e.leaves.firstWhere((l) => l.record.kind == EntityKind.arc).payload;
      final c = arc.pointAt(0);
      final r = arc.scalars[0];
      Vector2 at(double a) =>
          Vector2(c.x + r * math.cos(a), c.y + r * math.sin(a));
      final start = at(arc.scalars[1]),
          end = at(arc.scalars[1] + arc.scalars[2]);
      final mid = at(arc.scalars[1] + arc.scalars[2] / 2);
      expect(start.x, closeTo(0, 1e-9));
      expect(start.y, closeTo(0, 1e-9));
      expect(end.x, closeTo(1200, 1e-9));
      expect(end.y, closeTo(0, 1e-9));
      expect(mid.x, closeTo(600, 1e-9));
      expect(mid.y, closeTo(-200, 1e-9));
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
