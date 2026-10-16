// 3a Task 23 (spec C4, C7), ported from jet_cad_floor_plan/test/symbols/
// furniture_library_test.dart (spec 09 D2, D7, plan 09a Task 5): the
// committed asset must equal what the catalog builds, every symbol must
// load, sit off the origin, place cleanly at an off-origin point and quarter
// turn, and be a plausible size in millimetres. C7's rulings: keys and
// versions are C4's (class 1); the against-wall and family tags are the
// `attachTo` and `family` fields (class 2); "the behaviour tags come last"
// is retired (class 2); the pre-09c group and "the 14 new symbols … == 27"
// are not ported (umbrella decision 9); the seating group's two seat-count
// tests are dropped (decision 7). Placement goes through the test support's
// `placeEntry` (the plan's placer is not exported).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/furniture/furniture_catalog.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/place_entry.dart';

Uint8List builtBytes() => encodeLibrary(furnitureCatalog);

Uint8List assetBytes() =>
    File('assets/library/furniture.jetlib').readAsBytesSync();

SymbolLibrary assetLibrary() => SymbolLibrary.decode(assetBytes());

/// A document a symbol is placed in: the contract's components and
/// millimetres (today's `prepareDocument` less the planner's own types and
/// its DASHED record, which no furniture leaf uses).
DraftDocument placementDocument() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

void main() {
  group('the asset', () {
    test('the committed bytes equal the built library', () {
      expect(builtBytes(), orderedEquals(assetBytes()),
          reason: 'run `dart run tool/generate_furniture_library.dart`');
    });

    test('the built library decodes through the loader', () {
      expect(SymbolLibrary.decode(builtBytes()).entries.length,
          furnitureCatalog.symbols.length);
    });

    test('building twice gives identical bytes', () {
      expect(builtBytes(), orderedEquals(builtBytes()));
    });

    test('is declared in the pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
          RegExp(
                  r'^\s*assets:\s*\n(\s*-\s+.*\n)*?\s*-\s+assets/library/'
                  r'furniture\.jetlib\s*$',
                  multiLine: true)
              .hasMatch(pubspec),
          isTrue);
    });

    test('ships 41 symbols in six categories', () {
      final lib = assetLibrary();
      expect(lib.entries.length, 41);
      expect(lib.categories, [
        'Dining Room',
        'Kitchen',
        'Bed Room',
        'Living Room',
        'Bathroom',
        'Office',
      ]);
    });
  });

  group('the decoded library', () {
    test('lists every catalog key once, in catalog order', () {
      final keys = assetLibrary().entries.map((e) => e.symbol.key).toList();
      expect(keys, [for (final s in furnitureCatalog.symbols) s.key]);
      expect(keys.toSet().length, keys.length);
    });

    test('every key is lower-case dotted', () {
      for (final e in assetLibrary().entries) {
        expect(RegExp(r'^[a-z]+(\.[a-z0-9]+)*$').hasMatch(e.symbol.key), isTrue,
            reason: e.symbol.key);
      }
    });

    test('every base point is off the origin', () {
      for (final e in assetLibrary().entries) {
        expect(e.definition.basePoint.x != 0 || e.definition.basePoint.y != 0,
            isTrue,
            reason: e.symbol.key);
        // The catalog says the same thing the file does.
        final s =
            furnitureCatalog.symbols.firstWhere((s) => s.key == e.symbol.key);
        expect(e.definition.basePoint, Vector2(s.base.$1, s.base.$2));
      }
    });

    test('every entry has a category, two tags, its version and leaves', () {
      for (final e in assetLibrary().entries) {
        expect(e.symbol.category, isNotEmpty, reason: e.symbol.key);
        expect(e.symbol.tags.length, greaterThanOrEqualTo(2),
            reason: e.symbol.key);
        for (final t in e.symbol.tags) {
          expect(t, t.toLowerCase(), reason: e.symbol.key);
        }
        // C4: versions restart at 1 (umbrella decision 9), the dining tables' 2 included.
        expect(e.symbol.version, 1, reason: e.symbol.key);
        expect(e.leaves, isNotEmpty, reason: e.symbol.key);
      }
    });

    test('leaf handles ascend across the whole library', () {
      final handles = [
        for (final e in assetLibrary().entries)
          for (final l in e.leaves) l.record.handle.value,
      ];
      expect([...handles]..sort(), handles);
    });
  });

  group('the outline and the category of each symbol', () {
    // Written out by hand from the drawn catalog, not derived from it: the
    // number of closed polylines each symbol draws. Every polyline in the
    // library is closed, so an open one is a defect.
    const closedPolylines = {
      'architecture.dining.table.square.two': 4,
      'architecture.dining.table.square.four': 6,
      'architecture.dining.table.rect.four': 6,
      'architecture.dining.table.rect.six': 8,
      'architecture.dining.table.round': 4,
      'architecture.dining.chair': 2,
      'architecture.dining.bench': 2,
      'architecture.kitchen.base.300': 1,
      'architecture.kitchen.base.400': 1,
      'architecture.kitchen.base.600': 1,
      'architecture.kitchen.base.800': 1,
      'architecture.kitchen.sink': 2,
      'architecture.kitchen.hob': 1,
      'architecture.kitchen.fridge': 1,
      'architecture.kitchen.dishwasher': 1,
      'architecture.kitchen.washer': 1,
      'architecture.kitchen.island': 2,
      'architecture.bed.double.1400': 3,
      'architecture.bed.double': 3,
      'architecture.bed.double.1800': 3,
      'architecture.bed.single.800': 2,
      'architecture.bed.single': 2,
      'architecture.bed.single.1000': 2,
      'architecture.bed.nightstand': 2,
      'architecture.bed.wardrobe.1200': 1,
      'architecture.bed.wardrobe': 1,
      'architecture.bed.wardrobe.2400': 1,
      'architecture.sofa.two': 1,
      'architecture.sofa.three': 1,
      'architecture.armchair.single': 1,
      'architecture.table.coffee': 2,
      'architecture.tv.unit': 1,
      'architecture.bath.toilet': 1,
      'architecture.bath.washbasin': 1,
      'architecture.bath.tub': 2,
      'architecture.bath.shower': 2,
      'architecture.office.desk.1200': 1,
      'architecture.office.desk': 1,
      'architecture.office.desk.1600': 1,
      'architecture.office.chair': 0,
      'architecture.office.bookshelf': 1,
    };

    const categories = {
      'architecture.dining.table.square.two': 'Dining Room',
      'architecture.dining.table.square.four': 'Dining Room',
      'architecture.dining.table.rect.four': 'Dining Room',
      'architecture.dining.table.rect.six': 'Dining Room',
      'architecture.dining.table.round': 'Dining Room',
      'architecture.dining.chair': 'Dining Room',
      'architecture.dining.bench': 'Dining Room',
      'architecture.kitchen.base.300': 'Kitchen',
      'architecture.kitchen.base.400': 'Kitchen',
      'architecture.kitchen.base.600': 'Kitchen',
      'architecture.kitchen.base.800': 'Kitchen',
      'architecture.kitchen.sink': 'Kitchen',
      'architecture.kitchen.hob': 'Kitchen',
      'architecture.kitchen.fridge': 'Kitchen',
      'architecture.kitchen.dishwasher': 'Kitchen',
      'architecture.kitchen.washer': 'Kitchen',
      'architecture.kitchen.island': 'Kitchen',
      'architecture.bed.double.1400': 'Bed Room',
      'architecture.bed.double': 'Bed Room',
      'architecture.bed.double.1800': 'Bed Room',
      'architecture.bed.single.800': 'Bed Room',
      'architecture.bed.single': 'Bed Room',
      'architecture.bed.single.1000': 'Bed Room',
      'architecture.bed.nightstand': 'Bed Room',
      'architecture.bed.wardrobe.1200': 'Bed Room',
      'architecture.bed.wardrobe': 'Bed Room',
      'architecture.bed.wardrobe.2400': 'Bed Room',
      'architecture.sofa.two': 'Living Room',
      'architecture.sofa.three': 'Living Room',
      'architecture.armchair.single': 'Living Room',
      'architecture.table.coffee': 'Living Room',
      'architecture.tv.unit': 'Living Room',
      'architecture.bath.toilet': 'Bathroom',
      'architecture.bath.washbasin': 'Bathroom',
      'architecture.bath.tub': 'Bathroom',
      'architecture.bath.shower': 'Bathroom',
      'architecture.office.desk.1200': 'Office',
      'architecture.office.desk': 'Office',
      'architecture.office.desk.1600': 'Office',
      'architecture.office.chair': 'Office',
      'architecture.office.bookshelf': 'Office',
    };

    test('the tables cover exactly the 41 shipped keys', () {
      final keys = assetLibrary().entries.map((e) => e.symbol.key).toSet();
      expect(keys.length, 41);
      expect(closedPolylines.keys.toSet(), keys);
      expect(categories.keys.toSet(), keys);
    });

    test('every polyline is closed and each symbol has its closed count', () {
      for (final e in assetLibrary().entries) {
        final polylines =
            e.leaves.where((l) => l.record.kind == EntityKind.polyline);
        for (final l in polylines) {
          expect(isClosedPolyline(l.payload), isTrue,
              reason: '${e.symbol.key}: an open polyline');
        }
        expect(polylines.length, closedPolylines[e.symbol.key],
            reason: e.symbol.key);
      }
    });

    test('the outline (first leaf) is a closed polyline or a circle', () {
      for (final e in assetLibrary().entries) {
        final first = e.leaves.first;
        if (first.record.kind == EntityKind.polyline) {
          expect(isClosedPolyline(first.payload), isTrue, reason: e.symbol.key);
        } else {
          expect(first.record.kind, EntityKind.circle, reason: e.symbol.key);
          // Written out by hand: the two symbols whose outline is a circle.
          expect(
              e.symbol.key,
              isIn(const [
                'architecture.dining.table.round',
                'architecture.office.chair'
              ]));
        }
      }
    });

    test('each key is in its own category', () {
      for (final e in assetLibrary().entries) {
        expect(e.symbol.category, categories[e.symbol.key],
            reason: e.symbol.key);
      }
    });
  });

  group('families and the wall tag (spec 09c D9)', () {
    // Written out by hand from D9, not derived from the catalog.
    const againstWall = {
      'architecture.bed.double.1400',
      'architecture.bed.double',
      'architecture.bed.double.1800',
      'architecture.bed.single.800',
      'architecture.bed.single',
      'architecture.bed.single.1000',
      'architecture.bed.nightstand',
      'architecture.bed.wardrobe.1200',
      'architecture.bed.wardrobe',
      'architecture.bed.wardrobe.2400',
      'architecture.kitchen.base.300',
      'architecture.kitchen.base.400',
      'architecture.kitchen.base.600',
      'architecture.kitchen.base.800',
      'architecture.kitchen.sink',
      'architecture.kitchen.hob',
      'architecture.kitchen.fridge',
      'architecture.kitchen.dishwasher',
      'architecture.kitchen.washer',
      'architecture.sofa.two',
      'architecture.sofa.three',
      'architecture.tv.unit',
      'architecture.bath.toilet',
      'architecture.bath.washbasin',
      'architecture.bath.tub',
      'architecture.bath.shower',
      'architecture.office.desk.1200',
      'architecture.office.desk',
      'architecture.office.desk.1600',
      'architecture.office.bookshelf',
    };

    // D9's table: each family's members (in library order) and each
    // member's W x D in mm, then the two appliances.
    const families = {
      'bed-double': [
        'architecture.bed.double.1400',
        'architecture.bed.double',
        'architecture.bed.double.1800'
      ],
      'bed-single': [
        'architecture.bed.single.800',
        'architecture.bed.single',
        'architecture.bed.single.1000'
      ],
      'wardrobe': [
        'architecture.bed.wardrobe.1200',
        'architecture.bed.wardrobe',
        'architecture.bed.wardrobe.2400'
      ],
      'kitchen-base': [
        'architecture.kitchen.base.300',
        'architecture.kitchen.base.400',
        'architecture.kitchen.base.600',
        'architecture.kitchen.base.800',
      ],
      'desk': [
        'architecture.office.desk.1200',
        'architecture.office.desk',
        'architecture.office.desk.1600'
      ],
      'sofa': ['architecture.sofa.two', 'architecture.sofa.three'],
    };
    const sizes = {
      'architecture.bed.double.1400': (1400.0, 2000.0),
      'architecture.bed.double': (1600.0, 2000.0),
      'architecture.bed.double.1800': (1800.0, 2000.0),
      'architecture.bed.single.800': (800.0, 2000.0),
      'architecture.bed.single': (900.0, 2000.0),
      'architecture.bed.single.1000': (1000.0, 2000.0),
      'architecture.bed.wardrobe.1200': (1200.0, 600.0),
      'architecture.bed.wardrobe': (1800.0, 600.0),
      'architecture.bed.wardrobe.2400': (2400.0, 600.0),
      'architecture.kitchen.base.300': (300.0, 600.0),
      'architecture.kitchen.base.400': (400.0, 600.0),
      'architecture.kitchen.base.600': (600.0, 600.0),
      'architecture.kitchen.base.800': (800.0, 600.0),
      'architecture.office.desk.1200': (1200.0, 700.0),
      'architecture.office.desk': (1400.0, 700.0),
      'architecture.office.desk.1600': (1600.0, 700.0),
      'architecture.sofa.two': (1500.0, 900.0),
      'architecture.sofa.three': (2000.0, 900.0),
      'architecture.kitchen.dishwasher': (600.0, 600.0),
      'architecture.kitchen.washer': (600.0, 600.0),
    };

    SymbolEntry entry(String key) =>
        assetLibrary().entries.firstWhere((e) => e.symbol.key == key);

    test('the against-wall set is D9\'s list exactly', () {
      expect(againstWall, hasLength(30));
      expect({
        for (final e in assetLibrary().entries)
          if (e.symbol.attachTo.contains('wall-face')) e.symbol.key,
      }, againstWall);
    });

    test('the families are D9\'s table exactly, one family at most each', () {
      final found = <String, List<String>>{};
      for (final e in assetLibrary().entries) {
        final family = e.symbol.family;
        if (family != null) (found[family] ??= []).add(e.symbol.key);
      }
      expect(found, families);
    });

    test('every family\'s members share depth, front and back (W-16)', () {
      for (final MapEntry(:key, :value) in families.entries) {
        final first = boxOfEntry(entry(value.first))!;
        for (final k in value.skip(1)) {
          final b = boxOfEntry(entry(k))!;
          expect(b.depth, first.depth, reason: '$key: $k');
          expect(b.front, first.front, reason: '$key: $k');
          expect(b.back, first.back, reason: '$key: $k');
        }
      }
    });

    test('each family member\'s and appliance\'s box is its D9 W x D', () {
      for (final MapEntry(:key, :value) in sizes.entries) {
        final b = boxOfEntry(entry(key))!;
        expect((b.width, b.depth), value, reason: key);
      }
      expect(
          {for (final v in families.values) ...v}
              .difference(sizes.keys.toSet()),
          isEmpty);
    });

    test('every base point lies on its box\'s centre x, exactly (D4 step 5)',
        () {
      for (final e in assetLibrary().entries) {
        final b = boxOfEntry(e)!;
        expect(e.definition.basePoint.x, (b.left + b.right) / 2,
            reason: e.symbol.key);
      }
    });
  });

  group('the dining tables draw their chairs', () {
    // Written out by hand: the seats of each table. A table's leaves are its
    // outline and inset (two closed polylines), then one closed outline and
    // one back line per chair.
    const seats = {
      'architecture.dining.table.square.two': 2,
      'architecture.dining.table.square.four': 4,
      'architecture.dining.table.rect.four': 4,
      'architecture.dining.table.rect.six': 6,
    };

    // Axis-aligned box (minX, minY, maxX, maxY) of a closed polyline leaf.
    (double, double, double, double) box(GeometryPayload p) {
      final c = p.coords;
      var minX = c[0], minY = c[1], maxX = c[0], maxY = c[1];
      for (var i = 0; i < p.pointCount; i++) {
        minX = c[2 * i] < minX ? c[2 * i] : minX;
        maxX = c[2 * i] > maxX ? c[2 * i] : maxX;
        minY = c[2 * i + 1] < minY ? c[2 * i + 1] : minY;
        maxY = c[2 * i + 1] > maxY ? c[2 * i + 1] : maxY;
      }
      return (minX, minY, maxX, maxY);
    }

    List<(double, double, double, double)> chairBoxes(String key) {
      final e = assetLibrary().entries.firstWhere((e) => e.symbol.key == key);
      final polylines = [
        for (final l in e.leaves)
          if (l.record.kind == EntityKind.polyline) l,
      ];
      return [for (final l in polylines.skip(2)) box(l.payload)];
    }

    test('each table\'s base point is its table centre', () {
      // Written out by hand, in the symbol's own frame (the chairs shift the
      // table off the corner on the sides that carry them).
      const centres = {
        'architecture.dining.table.square.two': (400.0, 750.0),
        'architecture.dining.table.square.four': (800.0, 800.0),
        'architecture.dining.table.rect.four': (700.0, 750.0),
        'architecture.dining.table.rect.six': (1250.0, 800.0),
      };
      for (final MapEntry(:key, :value) in centres.entries) {
        final e = assetLibrary().entries.firstWhere((e) => e.symbol.key == key);
        expect(e.definition.basePoint, Vector2(value.$1, value.$2),
            reason: key);
        final t = box(e.leaves.first.payload);
        expect(e.definition.basePoint,
            Vector2((t.$1 + t.$3) / 2, (t.$2 + t.$4) / 2),
            reason: '$key: the table outline\'s centre');
      }
    });

    test('each table draws one chair outline and back line per seat', () {
      for (final MapEntry(:key, :value) in seats.entries) {
        expect(chairBoxes(key).length, value, reason: key);
        final e = assetLibrary().entries.firstWhere((e) => e.symbol.key == key);
        final lines = e.leaves.where((l) => l.record.kind == EntityKind.line);
        expect(lines.length, value, reason: '$key: a back line per chair');
      }
    });

    test('every chair is 450 x 450 and tucked 100 mm under the table', () {
      for (final key in seats.keys) {
        final e = assetLibrary().entries.firstWhere((e) => e.symbol.key == key);
        final table = box(e.leaves.first.payload);
        for (final (x0, y0, x1, y1) in chairBoxes(key)) {
          expect(x1 - x0, 450, reason: key);
          expect(y1 - y0, 450, reason: key);
          final ox =
              (x1 < table.$3 ? x1 : table.$3) - (x0 > table.$1 ? x0 : table.$1);
          final oy =
              (y1 < table.$4 ? y1 : table.$4) - (y0 > table.$2 ? y0 : table.$2);
          // The chair overlaps the table by 100 mm in depth and by its full
          // 450 mm along the side.
          expect([ox, oy]..sort(), [100, 450], reason: key);
        }
      }
    });

    test('the chairs of one table do not overlap each other', () {
      for (final key in seats.keys) {
        final boxes = chairBoxes(key);
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            final a = boxes[i], b = boxes[j];
            final overlap =
                a.$3 > b.$1 && b.$3 > a.$1 && a.$4 > b.$2 && b.$4 > a.$2;
            expect(overlap, isFalse, reason: '$key: chairs $i and $j');
          }
        }
      }
    });

    test('the round table draws its four chairs around its top', () {
      final e = assetLibrary()
          .entries
          .firstWhere((e) => e.symbol.key == 'architecture.dining.table.round');
      final top = e.leaves.first;
      expect(top.record.kind, EntityKind.circle);
      final c = top.payload.pointAt(0);
      final r = top.payload.scalars[0];
      expect(e.definition.basePoint, c, reason: 'the base point is the top');
      expect((c.x, c.y, r), (900.0, 900.0, 550.0));
      final chairs = [
        for (final l in e.leaves)
          if (l.record.kind == EntityKind.polyline) l.payload,
      ];
      expect(chairs, hasLength(4));
      for (final p in chairs) {
        // A 450 x 450 seat whose nearest edge is 100 under the top's edge:
        // its nearest point to the centre is at r - 100.
        var minD = double.infinity;
        var minX = double.infinity, maxX = -double.infinity;
        var minY = double.infinity, maxY = -double.infinity;
        for (var i = 0; i < p.pointCount; i++) {
          final q = p.pointAt(i);
          minX = q.x < minX ? q.x : minX;
          maxX = q.x > maxX ? q.x : maxX;
          minY = q.y < minY ? q.y : minY;
          maxY = q.y > maxY ? q.y : maxY;
        }
        expect((maxX - minX, maxY - minY), (450.0, 450.0));
        // The nearest point of an axis-aligned box to the centre.
        final nx = c.x.clamp(minX, maxX), ny = c.y.clamp(minY, maxY);
        minD = (Vector2(nx, ny) - c).length;
        expect(minD, closeTo(r - 100, 1e-9));
        expect(minX, greaterThanOrEqualTo(0));
        expect(minY, greaterThanOrEqualTo(0));
      }
    });
  });

  group('every symbol placed', () {
    final at = Vector2(12345, -6789);

    for (final s in furnitureCatalog.symbols) {
      for (final q in [1, 3]) {
        test('${s.key} at quarter turn $q lands its base point on at', () {
          final entry =
              assetLibrary().entries.firstWhere((e) => e.symbol.key == s.key);
          final doc = placementDocument();
          doc.commands.execute(placeEntry(doc, entry,
              at: at, quarterTurns: q, mirrored: q == 3));
          expect(doc.validate(), isEmpty, reason: s.key);
          final box = doc.extents;
          expect(box.isEmpty, isFalse);
          expect(at.x, inInclusiveRange(box.minX, box.maxX), reason: s.key);
          expect(at.y, inInclusiveRange(box.minY, box.maxY), reason: s.key);
        });
      }
    }
  });

  group('plausible size (a unit slip guard)', () {
    for (final s in furnitureCatalog.symbols) {
      test('${s.key} is between 100 and 4000 mm on each axis', () {
        final entry =
            assetLibrary().entries.firstWhere((e) => e.symbol.key == s.key);
        final doc = DraftDocument.empty();
        registerKitComponents(doc.components);
        doc.commands.execute(placeEntry(doc, entry, at: Vector2(0, 0)));
        // Placed unrotated, at the origin, in a fresh document: the extents
        // are the symbol's own.
        final size = doc.extents.size;
        expect(size.x, inInclusiveRange(100, 4000), reason: s.key);
        expect(size.y, inInclusiveRange(100, 4000), reason: s.key);
      });
    }
  });

  group('C4: keys, fields and plain tables (3a Task 23)', () {
    // Written out by hand: today's 41 keys in today's catalog order
    // (jet_cad_floor_plan/lib/src/symbols/furniture_catalog.dart:300-675).
    const today = [
      'dining.table.square.two',
      'dining.table.square.four',
      'dining.table.rect.four',
      'dining.table.rect.six',
      'dining.table.round',
      'dining.chair',
      'dining.bench',
      'kitchen.base.300',
      'kitchen.base.400',
      'kitchen.base.600',
      'kitchen.base.800',
      'kitchen.sink',
      'kitchen.hob',
      'kitchen.fridge',
      'kitchen.dishwasher',
      'kitchen.washer',
      'kitchen.island',
      'bed.double.1400',
      'bed.double',
      'bed.double.1800',
      'bed.single.800',
      'bed.single',
      'bed.single.1000',
      'bed.nightstand',
      'bed.wardrobe.1200',
      'bed.wardrobe',
      'bed.wardrobe.2400',
      'sofa.two',
      'sofa.three',
      'armchair',
      'table.coffee',
      'tv.unit',
      'bath.toilet',
      'bath.washbasin',
      'bath.tub',
      'bath.shower',
      'office.desk.1200',
      'office.desk',
      'office.desk.1600',
      'office.chair',
      'office.bookshelf',
    ];

    test(
        'FU-keys every id is `architecture.` and today\'s key at version 1, '
        'in today\'s order; armchair, one segment today, is '
        'architecture.armchair.single', () {
      expect(today, hasLength(41));
      expect([
        for (final e in assetLibrary().entries) e.symbol.id
      ], [
        for (final k in today)
          k == 'armchair'
              ? 'architecture.armchair.single@1'
              : 'architecture.$k@1',
      ]);
    });

    test(
        'FU-tags tags are search words only: no against-wall tag, no family: '
        'tag; every attachTo is empty or exactly [wall-face]', () {
      for (final e in assetLibrary().entries) {
        final why = e.symbol.key;
        expect(e.symbol.tags, isNot(contains('against-wall')), reason: why);
        expect(e.symbol.tags.where((t) => t.startsWith('family:')), isEmpty,
            reason: why);
        expect(e.symbol.attachTo, anyOf(isEmpty, equals(const ['wall-face'])),
            reason: why);
      }
    });

    test(
        'FU-plain-tables no symbol carries a unit, in the catalog or the '
        'file; the five dining tables are plain symbols at version 1 '
        '(decision 3)', () {
      final lib = assetLibrary();
      expect([
        for (final e in lib.entries)
          if (e.unit != null) e.symbol.key,
      ], isEmpty);
      expect([
        for (final s in furnitureCatalog.symbols)
          if (s.unit != null) s.key,
      ], isEmpty);
      for (final key in const [
        'architecture.dining.table.square.two',
        'architecture.dining.table.square.four',
        'architecture.dining.table.rect.four',
        'architecture.dining.table.rect.six',
        'architecture.dining.table.round',
      ]) {
        final e = lib.entries.firstWhere((e) => e.symbol.key == key);
        expect((e.symbol.version, e.unit), (1, null), reason: key);
      }
    });
  });
}
