// Spec 09c D2, plan 09c-1 Task 2: the symbol's local box over the
// committed library's entries (jet_cad_floor_plan/test/symbols/
// symbol_box_test.dart:319-339, the group "library entries"'s first two
// cases, and :391-410, "reads the live leaves").
// Ported to jet_cad_2d_kit_architecture (3a Task 28, rulings R-P1, R-P3):
// placements through test/support/place_entry.dart; assertions unchanged.
// C7 class 1: every key gains `architecture.` (`armchair` is
// `architecture.armchair.single`, Task 23's keys) and an entry's key is its
// `SymbolComponent`'s (`e.symbol.key`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/place_entry.dart';

SymbolLibrary assetLibrary() => SymbolLibrary.decode(
    File('assets/library/furniture.jetlib').readAsBytesSync());

/// The entry of today's [key] (`bath.toilet`), under the kit.
SymbolEntry entryIn(SymbolLibrary lib, String key) =>
    lib.entries.firstWhere((e) => e.symbol.key == 'architecture.$key');

DraftDocument target() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOf(DraftDocument doc, String key) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    if (doc.components.get<SymbolComponent>(h)!.key == key &&
        doc.tree.definition(h) != null) {
      return h;
    }
  }
  throw StateError('no $key');
}

/// Every catalog symbol's box, derived by hand from `furniture_catalog.dart`
/// (left, right, front, back). The dining sets' boxes are set by their
/// chairs (350 mm beyond the table edge), the round table's too since 14s
/// (its Ø 1100 top centred at 900, 900: 900 − 550 − 350 = 0 and
/// 900 + 550 + 350 = 1800); the toilet's front only by its bowl's axis
/// extreme; the office chair's only by circles.
const Map<String, (double, double, double, double)> catalogBoxes = {
  'architecture.dining.table.square.two': (0, 800, 0, 1500),
  'architecture.dining.table.square.four': (0, 1600, 0, 1600),
  'architecture.dining.table.rect.four': (0, 1400, 0, 1500),
  'architecture.dining.table.rect.six': (0, 2500, 0, 1600),
  'architecture.dining.table.round': (0, 1800, 0, 1800),
  'architecture.dining.chair': (0, 450, 0, 450),
  'architecture.dining.bench': (0, 1200, 0, 350),
  'architecture.kitchen.base.300': (0, 300, 0, 600),
  'architecture.kitchen.base.400': (0, 400, 0, 600),
  'architecture.kitchen.base.600': (0, 600, 0, 600),
  'architecture.kitchen.base.800': (0, 800, 0, 600),
  'architecture.kitchen.sink': (0, 1200, 0, 600),
  'architecture.kitchen.hob': (0, 600, 0, 520),
  'architecture.kitchen.fridge': (0, 600, 0, 650),
  'architecture.kitchen.dishwasher': (0, 600, 0, 600),
  'architecture.kitchen.washer': (0, 600, 0, 600),
  'architecture.kitchen.island': (0, 1800, 0, 900),
  'architecture.bed.double.1400': (0, 1400, 0, 2000),
  'architecture.bed.double': (0, 1600, 0, 2000),
  'architecture.bed.double.1800': (0, 1800, 0, 2000),
  'architecture.bed.single.800': (0, 800, 0, 2000),
  'architecture.bed.single': (0, 900, 0, 2000),
  'architecture.bed.single.1000': (0, 1000, 0, 2000),
  'architecture.bed.nightstand': (0, 450, 0, 400),
  'architecture.bed.wardrobe.1200': (0, 1200, 0, 600),
  'architecture.bed.wardrobe': (0, 1800, 0, 600),
  'architecture.bed.wardrobe.2400': (0, 2400, 0, 600),
  'architecture.sofa.two': (0, 1500, 0, 900),
  'architecture.sofa.three': (0, 2000, 0, 900),
  'architecture.armchair.single': (0, 850, 0, 850),
  'architecture.table.coffee': (0, 1100, 0, 600),
  'architecture.tv.unit': (0, 1600, 0, 450),
  'architecture.bath.toilet': (0, 400, 0, 700),
  'architecture.bath.washbasin': (0, 600, 0, 450),
  'architecture.bath.tub': (0, 1700, 0, 750),
  'architecture.bath.shower': (0, 900, 0, 900),
  'architecture.office.desk.1200': (0, 1200, 0, 700),
  'architecture.office.desk': (0, 1400, 0, 700),
  'architecture.office.desk.1600': (0, 1600, 0, 700),
  'architecture.office.chair': (0, 600, 0, 600),
  'architecture.office.bookshelf': (0, 900, 0, 300),
};

SymbolBox boxOf((double, double, double, double) b) =>
    SymbolBox(left: b.$1, right: b.$2, front: b.$3, back: b.$4);

void main() {
  group('library entries', () {
    test('every catalog symbol\'s box equals its hand-derived literal', () {
      final lib = assetLibrary();
      expect({for (final e in lib.entries) e.symbol.key},
          catalogBoxes.keys.toSet(),
          reason: 'a new catalog symbol needs its literal here');
      for (final e in lib.entries) {
        expect(boxOfEntry(e), boxOf(catalogBoxes[e.symbol.key]!),
            reason: e.symbol.key);
      }
    });

    test(
        'the toilet\'s front is its bowl\'s axis extreme, its back the '
        'cistern', () {
      final toilet = entryIn(assetLibrary(), 'bath.toilet');
      final box = boxOfEntry(toilet)!;
      expect(box, const SymbolBox(left: 0, right: 400, front: 0, back: 700));
      expect(box.width, 400);
      expect(box.depth, 700);
      expect(box.backCentre, Vector2(200, 700));
    });
  });

  group('boxOfDefinition', () {
    test('reads the live leaves: a removed leaf no longer counts', () {
      final lib = assetLibrary();
      final doc = target();
      doc.commands.execute(placeEntry(doc, entryIn(lib, 'bath.toilet'),
          at: Vector2(1e5, -7e4), quarterTurns: 3, mirrored: true));
      final def = definitionOf(doc, 'architecture.bath.toilet');
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 700));
      // The cistern (the first leaf) goes; the lines reach y = 500.
      final cistern = [
        for (final slot in doc.entities.liveSlots)
          if (doc.entities.ownerAt(slot) == def) doc.entities.handleAt(slot)
      ].reduce((a, b) => a.value < b.value ? a : b);
      doc.commands.execute(RemoveEntityCommand(cistern));
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 500));
      doc.commands.undo();
      expect(boxOfDefinition(doc, def),
          const SymbolBox(left: 0, right: 400, front: 0, back: 700));
    });
  });
}
