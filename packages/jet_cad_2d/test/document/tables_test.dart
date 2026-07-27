import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('TableSection', () {
    test('adds, looks up by handle and by name', () {
      final layers = TableSection<LayerRecord>();
      const record = LayerRecord(
        handle: Handle(20),
        name: 'A-WALL',
        color: IndexedColor(7),
        linetype: ReservedHandles.continuousLinetype,
        lineweight: kLineweightDefault,
        transparency: 0,
      );
      layers.add(record);
      expect(layers[const Handle(20)], record);
      expect(layers.byName('A-WALL'), record);
      expect(layers.byName('missing'), isNull);
      expect(layers.length, 1);
    });

    test('name lookup is case-insensitive, as DXF table names are', () {
      final layers = TableSection<LayerRecord>()
        ..add(const LayerRecord(
          handle: Handle(20),
          name: 'A-Wall',
          color: ByLayerColor(),
          linetype: ReservedHandles.continuousLinetype,
          lineweight: kLineweightDefault,
          transparency: 0,
        ));
      expect(layers.byName('a-wall'), isNotNull);
      expect(layers.byName('A-WALL'), isNotNull);
    });

    test('records iterate in ascending handle order, never insertion order',
        () {
      // Determinism: serialization walks this iterator, and byte-identical
      // output cannot depend on insertion or hash order.
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(30), name: 'C'))
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'))
        ..add(const AppIdRecord(handle: Handle(20), name: 'B'));
      expect([for (final r in ids.records) r.name], ['A', 'B', 'C']);
    });

    test('rejects a duplicate handle and a duplicate name', () {
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'));
      expect(() => ids.add(const AppIdRecord(handle: Handle(10), name: 'B')),
          throwsA(isA<DuplicateHandleError>()));
      expect(() => ids.add(const AppIdRecord(handle: Handle(11), name: 'a')),
          throwsA(isA<DuplicateTableNameError>()));
    });

    test('remove clears both indices', () {
      final ids = TableSection<AppIdRecord>()
        ..add(const AppIdRecord(handle: Handle(10), name: 'A'))
        ..remove(const Handle(10));
      expect(ids[const Handle(10)], isNull);
      expect(ids.byName('A'), isNull);
    });
  });

  group('DocumentTables.standard', () {
    final tables = DocumentTables.standard();

    test('seeds layer 0 at its reserved handle', () {
      final zero = tables.layers[ReservedHandles.layerZero];
      expect(zero, isNotNull);
      expect(zero!.name, '0');
      // Layer 0 carries the block-inheritance rule, so it must always exist.
      expect(tables.layers.byName('0'), same(zero));
    });

    test('seeds BYLAYER, BYBLOCK and CONTINUOUS linetypes as real records', () {
      expect(
          tables.linetypes[ReservedHandles.byLayerLinetype]?.name, 'ByLayer');
      expect(
          tables.linetypes[ReservedHandles.byBlockLinetype]?.name, 'ByBlock');
      final continuous = tables.linetypes[ReservedHandles.continuousLinetype];
      expect(continuous?.name, 'Continuous');
      expect(continuous?.pattern.dashes, isEmpty);
    });

    test('seeds the Standard text style', () {
      final std = tables.textStyles[ReservedHandles.standardTextStyle];
      expect(std, isNotNull);
      expect(std!.name, 'Standard');
      expect(std.widthFactor, 1.0);
      expect(std.isShx, isFalse);
    });

    test('pattern and dimstyle tables start empty', () {
      expect(tables.patterns.length, 0);
      expect(tables.dimStyles.length, 0);
    });
  });

  group('records', () {
    test('LayerRecord json round-trips with stable key order', () {
      const record = LayerRecord(
        handle: Handle(20),
        name: 'A-WALL',
        color: TrueColor(0x00FF00),
        linetype: ReservedHandles.continuousLinetype,
        lineweight: 25,
        transparency: 0,
        visible: false,
        locked: true,
      );
      expect(record.toJson().keys.toList(), [
        'handle',
        'name',
        'color',
        'linetype',
        'lineweight',
        'transparency',
        'visible',
        'locked',
      ]);
      expect(LayerRecord.fromJson(record.toJson()), record);
    });

    test('LinetypeRecord carries a dash pattern in paper units', () {
      const record = LinetypeRecord(
        handle: Handle(21),
        name: 'Dashed',
        description: '__ __ __',
        pattern: DashPattern(dashes: [0.5, -0.25], totalLength: 0.75),
      );
      expect(LinetypeRecord.fromJson(record.toJson()), record);
    });

    test('PatternRecord carries hatch pattern lines', () {
      const record = PatternRecord(
        handle: Handle(22),
        name: 'ANSI31',
        lines: [
          PatternLine(
            angle: 0.785398,
            baseX: 0,
            baseY: 0,
            deltaX: 0,
            deltaY: 0.125,
            dashes: [],
          ),
        ],
      );
      expect(PatternRecord.fromJson(record.toJson()), record);
    });

    test('DimStyleRecord preserves opaque data it never interprets', () {
      // Dimension editing is a non-goal; the record exists so an imported
      // DIMSTYLE survives a round-trip untouched.
      const record = DimStyleRecord(
        handle: Handle(23),
        name: 'ISO-25',
        opaque: {'dimtxt': 2.5, 'dimclrd': 256},
      );
      expect(DimStyleRecord.fromJson(record.toJson()), record);
      expect(record.opaque['dimtxt'], 2.5);
    });
  });
}
