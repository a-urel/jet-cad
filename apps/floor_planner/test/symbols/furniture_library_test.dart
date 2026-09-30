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
import 'package:floor_planner/symbols/symbol_library.dart';
import 'package:floor_planner/symbols/symbol_placer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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

    test('ships at about two dozen symbols in six categories', () {
      final lib = assetLibrary();
      expect(lib.entries.length, inInclusiveRange(22, 26));
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
