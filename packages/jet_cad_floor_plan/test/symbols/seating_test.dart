// Spec 14 S1-S3, plan Task 4: the seating component, the library that
// carries it, and the placement that keeps it. Fixtures avoid the degenerate
// cases: base points and placements are off the origin, placements are
// quarter-turned and mirrored, and the target plan already holds an older,
// unservable copy of the same key.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/symbols.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 600 x 400 table with one 300 x 300 seat below it, its base point at the
/// top's centre (off the origin).
FurnitureSymbol table({int version = 1, int? seats = 3}) => FurnitureSymbol(
      key: 'test.table',
      name: 'Test table',
      category: 'Tests',
      tags: const ['table', 'test'],
      version: version,
      seats: seats,
      baseX: 300,
      baseY: 500,
      shapes: const [
        PolylineShape([(0, 300), (600, 300), (600, 700), (0, 700)],
            closed: true),
        PolylineShape([(150, 0), (450, 0), (450, 300), (150, 300)],
            closed: true),
      ],
    );

/// A symbol that is not servable.
const FurnitureSymbol planter = FurnitureSymbol(
  key: 'test.planter',
  name: 'Test planter',
  category: 'Tests',
  tags: ['planter', 'test'],
  baseX: 250,
  baseY: 250,
  shapes: [CircleShape(250, 250, 250)],
);

Uint8List bytesOf(DraftDocument doc) =>
    Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));

SymbolLibrary libraryOf(List<FurnitureSymbol> catalog) =>
    SymbolLibrary.decode(bytesOf(buildSymbolLibrary(catalog)));

DraftDocument plan() {
  final doc = DraftDocument.empty();
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOfOnlyInstance(DraftDocument doc) =>
    doc.tree.nodes.whereType<InstanceNode>().single.definition;

void main() {
  group('SeatingComponent', () {
    test('SE1 one seat or more; below one is an ArgumentError (M-14s-5)', () {
      expect(SeatingComponent(seats: 1).seats, 1);
      expect(SeatingComponent(seats: 12).seats, 12);
      expect(() => SeatingComponent(seats: 0), throwsArgumentError);
      expect(() => SeatingComponent(seats: -4), throwsArgumentError);
    });

    test('SE2 JSON: one key, round trip, refusals', () {
      final c = SeatingComponent(seats: 6);
      expect(c.typeId, 'jetcad.seating');
      expect(c.toJson(), {'seats': 6});
      expect(SeatingComponent.fromJson(c.toJson()), c);
      expect(() => SeatingComponent.fromJson(const {}), throwsFormatException);
      expect(() => SeatingComponent.fromJson(const {'seats': '6'}),
          throwsFormatException);
      expect(() => SeatingComponent.fromJson(const {'seats': 0}),
          throwsArgumentError);
    });

    test('SE3 value equality', () {
      expect(SeatingComponent(seats: 4), SeatingComponent(seats: 4));
      expect(SeatingComponent(seats: 4).hashCode,
          SeatingComponent(seats: 4).hashCode);
      expect(SeatingComponent(seats: 4), isNot(SeatingComponent(seats: 5)));
    });
  });

  group('the library', () {
    test('SE4 a servable symbol carries its seats; another carries none', () {
      final lib = libraryOf([planter, table()]);
      expect({for (final e in lib.entries) e.key: e.seats},
          {'test.planter': null, 'test.table': 3});
    });

    test('SE5 the definition holds the component (M-14s-1)', () {
      final doc = buildSymbolLibrary([planter, table(seats: 5)]);
      final byKey = {
        for (final d in doc.tree.definitions)
          doc.components.get<SymbolComponent>(d.handle)!.key:
              doc.components.get<SeatingComponent>(d.handle),
      };
      expect(byKey,
          {'test.planter': null, 'test.table': SeatingComponent(seats: 5)});
    });

    test('SE6 a file whose seats are below one is refused', () {
      final json = jsonDecode(DraftDocumentCodec.encodeToString(
          buildSymbolLibrary([table(seats: 2)]))) as Map<String, Object?>;
      final text = jsonEncode(json).replaceAll('{"seats":2}', '{"seats":0}');
      expect(text, contains('{"seats":0}'), reason: 'premise: edited');
      expect(() => SymbolLibrary.decode(Uint8List.fromList(utf8.encode(text))),
          throwsA(isA<SymbolLibraryError>()));
    });

    test(
        'SE7 a seating component on a handle that is not a definition is '
        'refused', () {
      final doc = buildSymbolLibrary([table()]);
      doc.commands.execute(SetComponentCommand<SeatingComponent>(
          doc.rootHandle, SeatingComponent(seats: 2)));
      expect(
          () => SymbolLibrary.decode(bytesOf(doc)),
          throwsA(isA<SymbolLibraryError>()
              .having((e) => e.message, 'message', contains('not a symbol'))));
    });
  });

  group('the placement', () {
    test(
        'SE8 a quarter-turned, mirrored, off-origin placement copies the '
        'seats with the definition, and they survive a save (M-14s-3)', () {
      final entry = libraryOf([table(seats: 3)]).entries.single;
      final doc = plan();
      doc.commands.execute(placeSymbol(doc, entry,
          at: Vector2(12345, -6789), quarterTurns: 3, mirrored: true));
      final def = definitionOfOnlyInstance(doc);
      expect(doc.components.get<SeatingComponent>(def),
          SeatingComponent(seats: 3));
      final reloaded = DraftDocumentCodec.decodeString(
          DraftDocumentCodec.encodeToString(doc),
          registerComponents: registerAppComponents);
      expect(reloaded.components.get<SeatingComponent>(def),
          SeatingComponent(seats: 3));
      // One undo step takes it away with the definition.
      doc.commands.undo();
      expect(doc.components.get<SeatingComponent>(def), isNull);
    });

    test('SE9 a symbol that is not servable places without seats', () {
      final entry = libraryOf([planter]).entries.single;
      final doc = plan();
      doc.commands.execute(placeSymbol(doc, entry, at: Vector2(-300, 4000)));
      expect(
          doc.components.get<SeatingComponent>(definitionOfOnlyInstance(doc)),
          isNull);
      expect(doc.components.withComponent<SeatingComponent>(), isEmpty);
    });

    test(
        'SE10 a plan holding an unservable version-1 dining table gets a '
        'servable version-2 copy beside it (M-14s-2)', () {
      // The real square table, re-issued at version 1 without seats: what a
      // plan saved before spec 14 holds.
      final square = SymbolLibrary.decode(bytesOf(buildFurnitureLibrary()))
          .entries
          .firstWhere((e) => e.key == 'dining.table.square.four');
      final v1 = SymbolEntry(
        key: square.key,
        name: square.name,
        category: square.category,
        tags: square.tags,
        version: 1,
        definition: square.definition,
        leaves: square.leaves,
      );
      final doc = plan();
      doc.commands.execute(placeSymbol(doc, v1, at: Vector2(900, 900)));
      final oldDef = definitionOfOnlyInstance(doc);
      expect(doc.components.get<SeatingComponent>(oldDef), isNull,
          reason: 'premise: the old copy is not servable');

      doc.commands.execute(placeSymbol(doc, square,
          at: Vector2(3000, -900), quarterTurns: 1, mirrored: true));
      final defs = {
        for (final i in doc.tree.nodes.whereType<InstanceNode>()) i.definition
      };
      expect(defs, hasLength(2));
      final newDef = defs.firstWhere((d) => d != oldDef);
      expect(doc.components.get<SymbolComponent>(newDef)!.version, 2);
      expect(doc.components.get<SeatingComponent>(newDef),
          SeatingComponent(seats: 4));
      expect(doc.components.get<SeatingComponent>(oldDef), isNull);
    });

    test(
        'SE10b a copy of the same key and version without seats (a '
        'hand-edited plan) is not reused: a servable one is made beside it '
        '(review F-5)', () {
      final entry = libraryOf([table(seats: 3)]).entries.single;
      final doc = plan();
      doc.commands.execute(placeSymbol(doc, entry, at: Vector2(-700, 450)));
      final first = definitionOfOnlyInstance(doc);
      // The hand edit: the plan's copy loses its seats.
      doc.commands.execute(SetComponentCommand<SeatingComponent>(first, null));
      expect(doc.components.get<SeatingComponent>(first), isNull);

      doc.commands.execute(placeSymbol(doc, entry, at: Vector2(2100, 450)));
      final defs = {
        for (final i in doc.tree.nodes.whereType<InstanceNode>()) i.definition
      };
      expect(defs, hasLength(2));
      final second = defs.firstWhere((d) => d != first);
      expect(doc.components.get<SeatingComponent>(second),
          SeatingComponent(seats: 3));

      // A copy that agrees is reused, as before.
      doc.commands.execute(placeSymbol(doc, entry, at: Vector2(4100, 450)));
      expect({
        for (final i in doc.tree.nodes.whereType<InstanceNode>()) i.definition
      }, defs);
    });

    test(
        'SE11 the furniture library\'s dining tables are version 2 and '
        'servable', () {
      final lib = SymbolLibrary.decode(bytesOf(buildFurnitureLibrary()));
      final square =
          lib.entries.firstWhere((e) => e.key == 'dining.table.square.four');
      expect((square.version, square.seats), (2, 4));
      final doc = plan();
      doc.commands.execute(
          placeSymbol(doc, square, at: Vector2(-2500, 1700), quarterTurns: 1));
      expect(
          doc.components.get<SeatingComponent>(definitionOfOnlyInstance(doc)),
          SeatingComponent(seats: 4));
    });
  });
}
