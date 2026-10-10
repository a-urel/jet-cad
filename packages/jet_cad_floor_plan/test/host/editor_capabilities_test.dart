// Host embedding API spec C-5 (Slice 4 plan, Task 4; S-6, S-12, S-23):
// the capabilities type, the tools and the symbol a filter sees, read
// through the barrel alone. The profiles are read field by field against
// S-12's table, written out here, never from the code under test.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart' as host;
import 'package:jet_cad_floor_plan/src/host/editor_capabilities.dart'
    show validateEditorCapabilities;
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_loader.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart';

typedef Caps = host.FloorPlanEditorCapabilities;
typedef Tool = host.FloorPlanTool;

/// Every field but `tools` and `symbolFilter`, by name.
const List<String> kFlagNames = [
  'symbolPalette',
  'selectionPanel',
  'layerPanel',
  'pagePanel',
  'editLayers',
  'editPage',
  'selectTablesOnly',
  'move',
  'rotate',
  'mirror',
  'reshape',
  'delete',
  'renumber',
  'changeLayer',
  'undo',
  'export',
  'print',
  'rulers',
  'grid',
  'snapping',
];

/// [c]'s flags by name, read field by field.
Map<String, bool> flagsOf(Caps c) => {
      'symbolPalette': c.symbolPalette,
      'selectionPanel': c.selectionPanel,
      'layerPanel': c.layerPanel,
      'pagePanel': c.pagePanel,
      'editLayers': c.editLayers,
      'editPage': c.editPage,
      'selectTablesOnly': c.selectTablesOnly,
      'move': c.move,
      'rotate': c.rotate,
      'mirror': c.mirror,
      'reshape': c.reshape,
      'delete': c.delete,
      'renumber': c.renumber,
      'changeLayer': c.changeLayer,
      'undo': c.undo,
      'export': c.export,
      'print': c.print,
      'rulers': c.rulers,
      'grid': c.grid,
      'snapping': c.snapping,
    };

/// `c.copyWith(<name>: value)`.
Caps copyFlag(Caps c, String name, bool value) => switch (name) {
      'symbolPalette' => c.copyWith(symbolPalette: value),
      'selectionPanel' => c.copyWith(selectionPanel: value),
      'layerPanel' => c.copyWith(layerPanel: value),
      'pagePanel' => c.copyWith(pagePanel: value),
      'editLayers' => c.copyWith(editLayers: value),
      'editPage' => c.copyWith(editPage: value),
      'selectTablesOnly' => c.copyWith(selectTablesOnly: value),
      'move' => c.copyWith(move: value),
      'rotate' => c.copyWith(rotate: value),
      'mirror' => c.copyWith(mirror: value),
      'reshape' => c.copyWith(reshape: value),
      'delete' => c.copyWith(delete: value),
      'renumber' => c.copyWith(renumber: value),
      'changeLayer' => c.copyWith(changeLayer: value),
      'undo' => c.copyWith(undo: value),
      'export' => c.copyWith(export: value),
      'print' => c.copyWith(print: value),
      'rulers' => c.copyWith(rulers: value),
      'grid' => c.copyWith(grid: value),
      'snapping' => c.copyWith(snapping: value),
      _ => throw ArgumentError(name),
    };

/// A host's filter object, whose method a tear-off names.
final class Seats {
  const Seats(this.min);
  final int min;
  bool enough(host.FloorPlanSymbol s) => (s.seats ?? 0) >= min;
}

bool anyFour(host.FloorPlanSymbol s) => s.seats == 4;

host.FloorPlanSymbol symbol(String key, {int? seats}) => host.FloorPlanSymbol(
    key: key,
    name: 'Name of $key',
    category: 'Tests',
    tags: const ['a', 'b'],
    seats: seats);

void main() {
  test(
      'EC1 FloorPlanTool: the palette\'s sixteen tools in its order, then '
      'symbol (S-6)', () {
    expect(Tool.values.map((t) => t.name), [
      'select',
      'line',
      'polyline',
      'rectangle',
      'box',
      'wall',
      'door',
      'window',
      'gap',
      'room',
      'separator',
      'dimension',
      'circle',
      'arc',
      'text',
      'symbol',
    ]);
  });

  test('EC2 the three profiles, field by field, as S-12 lists them', () {
    // full: every tool, every flag true, no filter; and it is the default.
    expect(Caps.full.tools, Tool.values.toSet());
    expect(Caps.full.symbolFilter, isNull);
    // Every flag allows: selectTablesOnly, a restriction, is false.
    expect(flagsOf(Caps.full),
        {for (final n in kFlagNames) n: n != 'selectTablesOnly'});
    expect(const Caps(), Caps.full);

    final tables = Caps.tablesOnly;
    expect(tables.tools, {Tool.select, Tool.symbol});
    expect(flagsOf(tables), {
      'symbolPalette': true,
      'selectionPanel': true,
      'layerPanel': false,
      'pagePanel': false,
      'editLayers': false,
      'editPage': false,
      'selectTablesOnly': true,
      'move': true,
      'rotate': true,
      'mirror': false,
      'reshape': false,
      'delete': true,
      'renumber': true,
      'changeLayer': false,
      'undo': true,
      'export': true,
      'print': true,
      'rulers': true,
      'grid': true,
      'snapping': true,
    });
    // The tables: a symbol that seats.
    final filter = tables.symbolFilter!;
    expect(filter(symbol('t', seats: 2)), isTrue);
    expect(filter(symbol('t', seats: 0)), isTrue);
    expect(filter(symbol('c')), isFalse);

    final read = Caps.readOnly;
    expect(read.tools, {Tool.select});
    expect(read.symbolFilter, isNull);
    expect(flagsOf(read), {
      'symbolPalette': false,
      'selectionPanel': true,
      'layerPanel': true,
      'pagePanel': true,
      'editLayers': false,
      'editPage': false,
      'selectTablesOnly': false,
      'move': false,
      'rotate': false,
      'mirror': false,
      'reshape': false,
      'delete': false,
      'renumber': false,
      'changeLayer': false,
      'undo': false,
      'export': true,
      'print': true,
      'rulers': true,
      'grid': true,
      'snapping': true,
    });
  });

  test(
      'EC3 copyWith replaces exactly the field it names; a null argument '
      'keeps the field, the filter included', () {
    for (final name in kFlagNames) {
      for (final base in [Caps.full, Caps.tablesOnly, Caps.readOnly]) {
        final before = flagsOf(base);
        final after = flagsOf(copyFlag(base, name, !before[name]!));
        expect(after, {...before, name: !before[name]!},
            reason: '$name on $base');
        expect(copyFlag(base, name, before[name]!), base, reason: name);
      }
    }
    final tools = Caps.full.copyWith(tools: {Tool.select, Tool.wall});
    expect(tools.tools, {Tool.select, Tool.wall});
    expect(flagsOf(tools), flagsOf(Caps.full));
    final filtered = Caps.full.copyWith(symbolFilter: anyFour);
    expect(filtered.symbolFilter, same(anyFour));
    expect(flagsOf(filtered), flagsOf(Caps.full));
    expect(filtered.tools, Caps.full.tools);
    // Flutter's convention: null keeps (S-12).
    expect(Caps.tablesOnly.copyWith().symbolFilter,
        same(Caps.tablesOnly.symbolFilter));
    expect(Caps.tablesOnly.copyWith(symbolFilter: null).symbolFilter,
        same(Caps.tablesOnly.symbolFilter));
    expect(Caps.tablesOnly.copyWith(), Caps.tablesOnly);
    expect(filtered.copyWith(reshape: false).symbolFilter, same(anyFour));
  });

  test(
      'EC4 == and hashCode over every field: the tools as a set, the '
      'filter by ==', () {
    final a = Caps(tools: {Tool.wall, Tool.select, Tool.door});
    final b = Caps(tools: {Tool.door, Tool.wall, Tool.select});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == Caps(tools: {Tool.select, Tool.wall}), isFalse);
    for (final name in kFlagNames) {
      final changed = copyFlag(Caps.full, name, !flagsOf(Caps.full)[name]!);
      expect(changed == Caps.full, isFalse, reason: name);
      expect(Caps.full == changed, isFalse, reason: name);
    }
    expect(Caps.full == Caps.readOnly, isFalse);
    expect(Caps.tablesOnly == Caps.readOnly, isFalse);
    // A static function is equal to itself; two closures are not; two
    // tear-offs of one method on one receiver are equal.
    expect(Caps.full.copyWith(symbolFilter: anyFour),
        Caps.full.copyWith(symbolFilter: anyFour));
    expect(Caps.full.copyWith(symbolFilter: anyFour).hashCode,
        Caps.full.copyWith(symbolFilter: anyFour).hashCode);
    expect(
        Caps.full.copyWith(symbolFilter: (s) => s.seats == 4) ==
            Caps.full.copyWith(symbolFilter: (s) => s.seats == 4),
        isFalse);
    const seats = Seats(2);
    expect(Caps.full.copyWith(symbolFilter: seats.enough),
        Caps.full.copyWith(symbolFilter: seats.enough));
    expect(
        Caps.full.copyWith(symbolFilter: seats.enough) ==
            Caps.full.copyWith(symbolFilter: anyFour),
        isFalse);
    expect(Caps.full.copyWith(symbolFilter: anyFour) == Caps.full, isFalse);
    // The profiles are const: the same object wherever named.
    expect(identical(Caps.tablesOnly, Caps.tablesOnly), isTrue);
    expect(Caps.tablesOnly, Caps.tablesOnly.copyWith());
  });

  test('EC5 toString names the fields that differ from full', () {
    expect(Caps.full.toString(), 'FloorPlanEditorCapabilities()');
    expect(Caps.full.copyWith(reshape: false).toString(),
        'FloorPlanEditorCapabilities(reshape: false)');
    expect(Caps.full.copyWith(export: false, undo: false).toString(),
        'FloorPlanEditorCapabilities(undo: false, export: false)');
    expect(
        Caps.tablesOnly.toString(),
        'FloorPlanEditorCapabilities(tools: {select, symbol}, '
        'symbolFilter: given, layerPanel: false, pagePanel: false, '
        'editLayers: false, editPage: false, selectTablesOnly: true, '
        'mirror: false, reshape: false, changeLayer: false)');
    expect(
        Caps.readOnly.toString(),
        'FloorPlanEditorCapabilities(tools: {select}, symbolPalette: false, '
        'editLayers: false, editPage: false, move: false, rotate: false, '
        'mirror: false, reshape: false, delete: false, renumber: false, '
        'changeLayer: false, undo: false)');
  });

  test(
      'T4-i tools without select: an ArgumentError naming tools; with '
      'select, none', () {
    expect(
        () => validateEditorCapabilities(const Caps(tools: {Tool.wall})),
        throwsA(isA<ArgumentError>()
            .having((e) => e.name, 'name', 'tools')
            .having((e) => e.invalidValue, 'value', {Tool.wall})));
    expect(() => validateEditorCapabilities(const Caps(tools: {})),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'tools')));
    for (final c in [
      Caps.full,
      Caps.tablesOnly,
      Caps.readOnly,
      const Caps(tools: {Tool.select}),
    ]) {
      validateEditorCapabilities(c);
    }
  });

  test('EC6 FloorPlanSymbol: ==, hashCode and toString over every field', () {
    final a = symbol('k', seats: 4);
    expect(a, symbol('k', seats: 4));
    expect(a.hashCode, symbol('k', seats: 4).hashCode);
    expect(
        a ==
            const host.FloorPlanSymbol(
                key: 'k',
                name: 'Name of k',
                category: 'Tests',
                tags: ['a', 'b'],
                seats: 4),
        isTrue);
    for (final other in [
      symbol('j', seats: 4),
      symbol('k', seats: 2),
      symbol('k'),
      host.FloorPlanSymbol(
          key: 'k',
          name: 'Other',
          category: 'Tests',
          tags: const ['a', 'b'],
          seats: 4),
      host.FloorPlanSymbol(
          key: 'k',
          name: 'Name of k',
          category: 'X',
          tags: const ['a', 'b'],
          seats: 4),
      host.FloorPlanSymbol(
          key: 'k',
          name: 'Name of k',
          category: 'Tests',
          tags: const ['b', 'a'],
          seats: 4),
    ]) {
      expect(a == other, isFalse, reason: '$other');
    }
    expect(
        a.toString(),
        'FloorPlanSymbol(k, name: Name of k, category: Tests, tags: [a, b], '
        'seats: 4)');
    expect(symbol('c').toString(),
        'FloorPlanSymbol(c, name: Name of c, category: Tests, tags: [a, b])');
  });

  testWidgets(
      'EC7 FloorPlanSymbol.of a bundled table and of a chair: the library\'s '
      'key, stored name, category and tags; seats, null for the chair; the '
      'tags unmodifiable (S-23)', (tester) async {
    final loader = SymbolLibraryLoader();
    addTearDown(loader.dispose);
    await tester.runAsync(loader.load);
    final library = (loader.state as SymbolLibraryReady).library;
    final round =
        library.entries.singleWhere((e) => e.key == 'dining.table.round');
    final chair = library.entries.singleWhere((e) => e.key == 'dining.chair');

    final t = host.FloorPlanSymbol.of(round);
    expect(
        t,
        const host.FloorPlanSymbol(
            key: 'dining.table.round',
            name: 'Round dining table, 4 seats',
            category: 'Dining Room',
            tags: ['table', 'dining', 'round', 'four'],
            seats: 4));
    expect(() => t.tags.add('x'), throwsUnsupportedError);
    final c = host.FloorPlanSymbol.of(chair);
    expect(
        c,
        const host.FloorPlanSymbol(
            key: 'dining.chair',
            name: 'Dining chair',
            category: 'Dining Room',
            tags: ['chair', 'seating', 'dining'],
            seats: null));
    expect(c.seats, isNull);
    expect(Caps.tablesOnly.symbolFilter!(t), isTrue);
    expect(Caps.tablesOnly.symbolFilter!(c), isFalse);
  });

  // Task 4 review R-3 (O3): EC3's three profiles share `rulers == grid`
  // (and other neighbours), so a field copied from its neighbour went
  // unseen. Two bases alternate every flag, built by the constructor, so
  // each flag differs from both of its neighbours in each.
  test(
      'EC3b copyWith on two bases whose flags alternate: no argument keeps '
      'every field, each flag replaces that field alone', () {
    Caps alternating(bool first) {
      final v = [for (var i = 0; i < kFlagNames.length; i++) i.isEven == first];
      return Caps(
        tools: const {Tool.select, Tool.door, Tool.symbol},
        symbolFilter: anyFour,
        symbolPalette: v[0],
        selectionPanel: v[1],
        layerPanel: v[2],
        pagePanel: v[3],
        editLayers: v[4],
        editPage: v[5],
        selectTablesOnly: v[6],
        move: v[7],
        rotate: v[8],
        mirror: v[9],
        reshape: v[10],
        delete: v[11],
        renumber: v[12],
        changeLayer: v[13],
        undo: v[14],
        export: v[15],
        print: v[16],
        rulers: v[17],
        grid: v[18],
        snapping: v[19],
      );
    }

    for (final first in [true, false]) {
      final base = alternating(first);
      final flags = flagsOf(base);
      // The premise: the constructor took each value, and they alternate.
      for (final (i, name) in kFlagNames.indexed) {
        expect(flags[name], i.isEven == first, reason: name);
      }
      expect(base.rulers, isNot(base.grid));
      final kept = base.copyWith();
      expect(flagsOf(kept), flags, reason: 'copyWith() on $base');
      expect(kept.tools, {Tool.select, Tool.door, Tool.symbol});
      expect(kept.symbolFilter, same(anyFour));
      for (final name in kFlagNames) {
        expect(flagsOf(copyFlag(base, name, !flags[name]!)),
            {...flags, name: !flags[name]!},
            reason: '$name on $base');
      }
    }
  });

  // Task 4 review R-4: a host's set is copied, so changing it afterwards
  // changes nothing.
  test('copyWith copies the tools it is given, unmodifiable', () {
    final mine = {Tool.select, Tool.wall};
    final caps = Caps.full.copyWith(tools: mine);
    mine
      ..remove(Tool.wall)
      ..add(Tool.line);
    expect(caps.tools, {Tool.select, Tool.wall});
    expect(() => caps.tools.add(Tool.door), throwsUnsupportedError);
    expect(caps, Caps.full.copyWith(tools: {Tool.wall, Tool.select}));
  });
}
