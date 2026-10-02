// Spec 09 D2, D7, plan 09a Task 5: the furniture library. The committed
// asset must equal what the catalog builds, every symbol must load, sit off
// the origin, place cleanly at an off-origin point and quarter turn, and be a
// plausible size in millimetres.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:floor_planner/new_document.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/symbols/build_library.dart';
import 'package:floor_planner/symbols/furniture_catalog.dart';
import 'package:floor_planner/symbols/symbol_box.dart';
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/pre_09c_library.dart';

Uint8List builtBytes() => Uint8List.fromList(
    utf8.encode(DraftDocumentCodec.encodeToString(buildFurnitureLibrary())));

Uint8List assetBytes() =>
    File('assets/library/furniture.jetlib').readAsBytesSync();

SymbolLibrary assetLibrary() => SymbolLibrary.decode(assetBytes());

void main() {
  group('the asset', () {
    test('the committed bytes equal the built library', () {
      expect(builtBytes(), orderedEquals(assetBytes()),
          reason: 'run `dart run tool/generate_furniture_library.dart`');
    });

    test('the built library decodes through the loader', () {
      expect(SymbolLibrary.decode(builtBytes()).entries.length,
          furnitureCatalog.length);
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
      final keys = assetLibrary().entries.map((e) => e.key).toList();
      expect(keys, [for (final s in furnitureCatalog) s.key]);
      expect(keys.toSet().length, keys.length);
    });

    test('every key is lower-case dotted', () {
      for (final e in assetLibrary().entries) {
        expect(RegExp(r'^[a-z]+(\.[a-z0-9]+)*$').hasMatch(e.key), isTrue,
            reason: e.key);
      }
    });

    test('every base point is off the origin', () {
      for (final e in assetLibrary().entries) {
        expect(e.definition.basePoint.x != 0 || e.definition.basePoint.y != 0,
            isTrue,
            reason: e.key);
        // The catalog says the same thing the file does.
        final s = furnitureCatalog.firstWhere((s) => s.key == e.key);
        expect(e.definition.basePoint, Vector2(s.baseX, s.baseY));
      }
    });

    test('every entry has a category, two tags, version 1 and leaves', () {
      for (final e in assetLibrary().entries) {
        expect(e.category, isNotEmpty, reason: e.key);
        expect(e.tags.length, greaterThanOrEqualTo(2), reason: e.key);
        for (final t in e.tags) {
          expect(t, t.toLowerCase(), reason: e.key);
        }
        expect(e.version, 1, reason: e.key);
        expect(e.leaves, isNotEmpty, reason: e.key);
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
      'dining.table.square.two': 4,
      'dining.table.square.four': 6,
      'dining.table.rect.four': 6,
      'dining.table.rect.six': 8,
      'dining.table.round': 0,
      'dining.chair': 2,
      'dining.bench': 2,
      'kitchen.base.300': 1,
      'kitchen.base.400': 1,
      'kitchen.base.600': 1,
      'kitchen.base.800': 1,
      'kitchen.sink': 2,
      'kitchen.hob': 1,
      'kitchen.fridge': 1,
      'kitchen.dishwasher': 1,
      'kitchen.washer': 1,
      'kitchen.island': 2,
      'bed.double.1400': 3,
      'bed.double': 3,
      'bed.double.1800': 3,
      'bed.single.800': 2,
      'bed.single': 2,
      'bed.single.1000': 2,
      'bed.nightstand': 2,
      'bed.wardrobe.1200': 1,
      'bed.wardrobe': 1,
      'bed.wardrobe.2400': 1,
      'sofa.two': 1,
      'sofa.three': 1,
      'armchair': 1,
      'table.coffee': 2,
      'tv.unit': 1,
      'bath.toilet': 1,
      'bath.washbasin': 1,
      'bath.tub': 2,
      'bath.shower': 2,
      'office.desk.1200': 1,
      'office.desk': 1,
      'office.desk.1600': 1,
      'office.chair': 0,
      'office.bookshelf': 1,
    };

    const categories = {
      'dining.table.square.two': 'Dining Room',
      'dining.table.square.four': 'Dining Room',
      'dining.table.rect.four': 'Dining Room',
      'dining.table.rect.six': 'Dining Room',
      'dining.table.round': 'Dining Room',
      'dining.chair': 'Dining Room',
      'dining.bench': 'Dining Room',
      'kitchen.base.300': 'Kitchen',
      'kitchen.base.400': 'Kitchen',
      'kitchen.base.600': 'Kitchen',
      'kitchen.base.800': 'Kitchen',
      'kitchen.sink': 'Kitchen',
      'kitchen.hob': 'Kitchen',
      'kitchen.fridge': 'Kitchen',
      'kitchen.dishwasher': 'Kitchen',
      'kitchen.washer': 'Kitchen',
      'kitchen.island': 'Kitchen',
      'bed.double.1400': 'Bed Room',
      'bed.double': 'Bed Room',
      'bed.double.1800': 'Bed Room',
      'bed.single.800': 'Bed Room',
      'bed.single': 'Bed Room',
      'bed.single.1000': 'Bed Room',
      'bed.nightstand': 'Bed Room',
      'bed.wardrobe.1200': 'Bed Room',
      'bed.wardrobe': 'Bed Room',
      'bed.wardrobe.2400': 'Bed Room',
      'sofa.two': 'Living Room',
      'sofa.three': 'Living Room',
      'armchair': 'Living Room',
      'table.coffee': 'Living Room',
      'tv.unit': 'Living Room',
      'bath.toilet': 'Bathroom',
      'bath.washbasin': 'Bathroom',
      'bath.tub': 'Bathroom',
      'bath.shower': 'Bathroom',
      'office.desk.1200': 'Office',
      'office.desk': 'Office',
      'office.desk.1600': 'Office',
      'office.chair': 'Office',
      'office.bookshelf': 'Office',
    };

    test('the tables cover exactly the 41 shipped keys', () {
      final keys = assetLibrary().entries.map((e) => e.key).toSet();
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
              reason: '${e.key}: an open polyline');
        }
        expect(polylines.length, closedPolylines[e.key], reason: e.key);
      }
    });

    test('the outline (first leaf) is a closed polyline or a circle', () {
      for (final e in assetLibrary().entries) {
        final first = e.leaves.first;
        if (first.record.kind == EntityKind.polyline) {
          expect(isClosedPolyline(first.payload), isTrue, reason: e.key);
        } else {
          expect(first.record.kind, EntityKind.circle, reason: e.key);
          expect(closedPolylines[e.key], 0, reason: e.key);
        }
      }
    });

    test('each key is in its own category', () {
      for (final e in assetLibrary().entries) {
        expect(e.category, categories[e.key], reason: e.key);
      }
    });
  });

  group('families and the wall tag (spec 09c D9)', () {
    // Written out by hand from D9, not derived from the catalog.
    const againstWall = {
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
      'kitchen.base.300',
      'kitchen.base.400',
      'kitchen.base.600',
      'kitchen.base.800',
      'kitchen.sink',
      'kitchen.hob',
      'kitchen.fridge',
      'kitchen.dishwasher',
      'kitchen.washer',
      'sofa.two',
      'sofa.three',
      'tv.unit',
      'bath.toilet',
      'bath.washbasin',
      'bath.tub',
      'bath.shower',
      'office.desk.1200',
      'office.desk',
      'office.desk.1600',
      'office.bookshelf',
    };

    // D9's table: each family's members (in library order) and each
    // member's W x D in mm, then the two appliances.
    const families = {
      'bed-double': ['bed.double.1400', 'bed.double', 'bed.double.1800'],
      'bed-single': ['bed.single.800', 'bed.single', 'bed.single.1000'],
      'wardrobe': ['bed.wardrobe.1200', 'bed.wardrobe', 'bed.wardrobe.2400'],
      'kitchen-base': [
        'kitchen.base.300',
        'kitchen.base.400',
        'kitchen.base.600',
        'kitchen.base.800',
      ],
      'desk': ['office.desk.1200', 'office.desk', 'office.desk.1600'],
      'sofa': ['sofa.two', 'sofa.three'],
    };
    const sizes = {
      'bed.double.1400': (1400.0, 2000.0),
      'bed.double': (1600.0, 2000.0),
      'bed.double.1800': (1800.0, 2000.0),
      'bed.single.800': (800.0, 2000.0),
      'bed.single': (900.0, 2000.0),
      'bed.single.1000': (1000.0, 2000.0),
      'bed.wardrobe.1200': (1200.0, 600.0),
      'bed.wardrobe': (1800.0, 600.0),
      'bed.wardrobe.2400': (2400.0, 600.0),
      'kitchen.base.300': (300.0, 600.0),
      'kitchen.base.400': (400.0, 600.0),
      'kitchen.base.600': (600.0, 600.0),
      'kitchen.base.800': (800.0, 600.0),
      'office.desk.1200': (1200.0, 700.0),
      'office.desk': (1400.0, 700.0),
      'office.desk.1600': (1600.0, 700.0),
      'sofa.two': (1500.0, 900.0),
      'sofa.three': (2000.0, 900.0),
      'kitchen.dishwasher': (600.0, 600.0),
      'kitchen.washer': (600.0, 600.0),
    };

    // The 14 new symbols' names (plan 09c-1 Task 3).
    const newNames = {
      'bed.double.1400': 'Double bed 1400',
      'bed.double.1800': 'Double bed 1800',
      'bed.single.800': 'Single bed 800',
      'bed.single.1000': 'Single bed 1000',
      'bed.wardrobe.1200': 'Wardrobe 1200',
      'bed.wardrobe.2400': 'Wardrobe 2400',
      'kitchen.base.300': 'Base unit 300',
      'kitchen.base.400': 'Base unit 400',
      'kitchen.base.800': 'Base unit 800',
      'office.desk.1200': 'Desk 1200',
      'office.desk.1600': 'Desk 1600',
      'sofa.two': 'Two-seat sofa',
      'kitchen.dishwasher': 'Dishwasher',
      'kitchen.washer': 'Washing machine',
    };

    SymbolEntry entry(String key) =>
        assetLibrary().entries.firstWhere((e) => e.key == key);

    test('the against-wall set is D9\'s list exactly', () {
      expect(againstWall, hasLength(30));
      expect({
        for (final e in assetLibrary().entries)
          if (e.tags.contains('against-wall')) e.key,
      }, againstWall);
    });

    test('the families are D9\'s table exactly, one family at most each', () {
      final found = <String, List<String>>{};
      for (final e in assetLibrary().entries) {
        final tags = e.tags.where((t) => t.startsWith('family:')).toList();
        expect(tags.length, lessThanOrEqualTo(1), reason: e.key);
        for (final t in tags) {
          (found[t.substring('family:'.length)] ??= []).add(e.key);
        }
      }
      expect(found, families);
    });

    test('the behaviour tags come last: against-wall, then family', () {
      for (final e in assetLibrary().entries) {
        final plain = e.tags
            .where((t) => t != 'against-wall' && !t.startsWith('family:'))
            .toList();
        expect(plain.length, greaterThanOrEqualTo(2), reason: e.key);
        expect(
            e.tags,
            [
              ...plain,
              if (againstWall.contains(e.key)) 'against-wall',
              for (final MapEntry(:key, :value) in families.entries)
                if (value.contains(e.key)) 'family:$key',
            ],
            reason: e.key);
      }
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
        expect(e.definition.basePoint.x, (b.left + b.right) / 2, reason: e.key);
      }
    });

    test('the 14 new symbols carry their names; the old keys stay', () {
      final lib = assetLibrary();
      for (final MapEntry(:key, :value) in newNames.entries) {
        expect(lib.entries.firstWhere((e) => e.key == key).name, value,
            reason: key);
      }
      expect(lib.entries.length - newNames.length, 27);
      expect(
          lib.entries.where((e) => newNames.containsKey(e.key)), hasLength(14));
    });
  });

  group('the 27 symbols shipped before 09c (spec 09c D2, D10)', () {
    // A definition is reused by key and version, so a version-1 symbol's
    // geometry may never change: a plan saved before 09c would otherwise get
    // a second copy on its next placement. 09c only appends tags.
    test('the fixture decodes to the 27 pre-09c symbols, none tagged by 09c',
        () {
      final old = pre09cLibrary().entries;
      expect(old, hasLength(27));
      for (final o in old) {
        expect(o.tags, isNot(contains('against-wall')), reason: o.key);
        expect(o.tags.where((t) => t.startsWith('family:')), isEmpty,
            reason: o.key);
      }
    });

    test('each keeps its name, category, version, base point and leaves', () {
      final now = {for (final e in assetLibrary().entries) e.key: e};
      for (final o in pre09cLibrary().entries) {
        final n = now[o.key];
        expect(n, isNotNull, reason: o.key);
        expect(n!.name, o.name, reason: o.key);
        expect(n.category, o.category, reason: o.key);
        expect(n.version, o.version, reason: o.key);
        expect(n.definition.basePoint.x, o.definition.basePoint.x,
            reason: o.key);
        expect(n.definition.basePoint.y, o.definition.basePoint.y,
            reason: o.key);
        expect(n.leaves.length, o.leaves.length, reason: o.key);
        for (var i = 0; i < o.leaves.length; i++) {
          final (record: or, payload: op) = o.leaves[i];
          final (record: nr, payload: np) = n.leaves[i];
          final at = '${o.key} leaf $i';
          expect(nr.kind, or.kind, reason: at);
          // Every record field but the three a library rebuild may renumber.
          final aligned = nr.copyWith(
              handle: or.handle, owner: or.owner, geomIndex: or.geomIndex);
          expect(aligned, or,
              reason: '$at: ${aligned.toJson()} != ${or.toJson()}');
          expect(np.coords, orderedEquals(op.coords), reason: at);
          expect(np.scalars, orderedEquals(op.scalars), reason: at);
        }
      }
    });

    test('its tags are the old tags with new ones appended only', () {
      final now = {for (final e in assetLibrary().entries) e.key: e};
      for (final o in pre09cLibrary().entries) {
        final tags = now[o.key]!.tags;
        expect(tags.length, greaterThanOrEqualTo(o.tags.length), reason: o.key);
        expect(tags.take(o.tags.length), orderedEquals(o.tags), reason: o.key);
      }
    });
  });

  group('the dining tables draw their chairs', () {
    // Written out by hand: the seats of each table. A table's leaves are its
    // outline and inset (two closed polylines), then one closed outline and
    // one back line per chair.
    const seats = {
      'dining.table.square.two': 2,
      'dining.table.square.four': 4,
      'dining.table.rect.four': 4,
      'dining.table.rect.six': 6,
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
      final e = assetLibrary().entries.firstWhere((e) => e.key == key);
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
        'dining.table.square.two': (400.0, 750.0),
        'dining.table.square.four': (800.0, 800.0),
        'dining.table.rect.four': (700.0, 750.0),
        'dining.table.rect.six': (1250.0, 800.0),
      };
      for (final MapEntry(:key, :value) in centres.entries) {
        final e = assetLibrary().entries.firstWhere((e) => e.key == key);
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
        final e = assetLibrary().entries.firstWhere((e) => e.key == key);
        final lines = e.leaves.where((l) => l.record.kind == EntityKind.line);
        expect(lines.length, value, reason: '$key: a back line per chair');
      }
    });

    test('every chair is 450 x 450 and tucked 100 mm under the table', () {
      for (final key in seats.keys) {
        final e = assetLibrary().entries.firstWhere((e) => e.key == key);
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
  });

  group('every symbol placed', () {
    final at = Vector2(12345, -6789);

    for (final s in furnitureCatalog) {
      for (final q in [1, 3]) {
        test('${s.key} at quarter turn $q lands its base point on at', () {
          final entry =
              assetLibrary().entries.firstWhere((e) => e.key == s.key);
          final doc = prepareDocument(const InsertionPointMeasurer());
          doc.commands.execute(placeSymbol(doc, entry,
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
    for (final s in furnitureCatalog) {
      test('${s.key} is between 100 and 4000 mm on each axis', () {
        final entry = assetLibrary().entries.firstWhere((e) => e.key == s.key);
        final doc = DraftDocument.empty();
        registerAppComponents(doc.components);
        doc.commands.execute(placeSymbol(doc, entry, at: Vector2(0, 0)));
        // Placed unrotated, at the origin, in a fresh document: the extents
        // are the symbol's own.
        final size = doc.extents.size;
        expect(size.x, inInclusiveRange(100, 4000), reason: s.key);
        expect(size.y, inInclusiveRange(100, 4000), reason: s.key);
      });
    }
  });
}
