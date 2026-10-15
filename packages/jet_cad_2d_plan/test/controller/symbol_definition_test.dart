// Spec 2b S2 "The contract gains": PlanServices.symbolDefinition answers a
// library symbol as a definition of the current document, with the command
// that adds it when the document lacks it; a second call before that add
// executes returns the same ref; symbolsState is the controller's own.
// Every value is off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        Catalog,
        CatalogCircle,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit,
        encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

/// A round table whose served top (its circle, the first leaf) is smaller
/// than its box (a line across it), and a shelf whose first leaf is a line.
final Catalog pbCatalog = Catalog(kit: 'pb', symbols: [
  const CatalogSymbol(
    key: 'pb.table.round',
    name: 'Round table',
    category: 'Tables',
    tags: ['table'],
    unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
    base: (2100.5, 1300.25),
    shapes: [
      CatalogCircle((2100.5, 1300.25), 450),
      CatalogLine((1400.5, 1300.25), (2800.5, 1300.25)),
    ],
  ),
  const CatalogSymbol(
    key: 'pb.shelf.plain',
    name: 'Plain shelf',
    category: 'Storage',
    tags: ['shelf'],
    base: (610.75, 205.5),
    shapes: [
      CatalogLine((110.75, 405.5), (1110.75, 405.5)),
      CatalogPolyline(
          [(160.75, 5.5), (1060.75, 5.5), (1060.75, 355.5), (160.75, 355.5)],
          closed: true),
    ],
  ),
]);

/// Symbols for `servedTopOfEntry`'s other arms: a turned closed outline
/// first with a larger line after it, an open polyline first with a larger
/// circle after it.
final Catalog polyCatalog = Catalog(kit: 'pp', symbols: [
  const CatalogSymbol(
    key: 'pp.closed.first',
    name: 'Closed first',
    category: 'Tables',
    tags: ['table'],
    base: (3000.5, 1300.25),
    shapes: [
      CatalogPolyline([
        (3000.5, 1000.25),
        (3400.5, 1300.25),
        (3000.5, 1600.25),
        (2600.5, 1300.25),
      ], closed: true),
      CatalogLine((2000.5, 800.25), (4000.5, 800.25)),
    ],
  ),
  const CatalogSymbol(
    key: 'pp.open.first',
    name: 'Open first',
    category: 'Tables',
    tags: ['table'],
    base: (1700.5, 900.25),
    shapes: [
      CatalogPolyline([(1500.5, 700.25), (1900.5, 900.25), (1500.5, 1100.25)]),
      CatalogCircle((1700.5, 900.25), 600),
    ],
  ),
]);

PlanKit pbKit() => symbolKit('pb', [
      SymbolLibrarySource(
          label: 'pb', read: () async => encodeLibrary(pbCatalog)),
    ]);

const String table = 'pb.table.round@1';

PlanController make(List<PlanKit> kits) {
  final c = PlanController(kits: kits);
  addTearDown(c.dispose);
  return c;
}

List<double> boxOf(Aabb2 b) => [b.minX, b.minY, b.maxX, b.maxY];

/// The definitions of [d] carrying [key]'s jetcad.symbol.
List<Handle> definitionsOf(DraftDocument d, String key) => [
      for (final h in d.components.withComponent<SymbolComponent>())
        if (d.components.get<SymbolComponent>(h)!.key == key &&
            d.tree.definition(h) != null)
          h,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'PB-def-twice two calls for one key before its add executes: one ref, '
      'from any kit\'s services; executed once, through the document, the '
      'next call adds nothing', () async {
    final c = make([pbKit(), demoKit()]);
    await settle();
    final s = c.servicesOf('pb');
    final d = c.document;
    final one = s.symbolDefinition(table)!;
    expect(one.add, isA<CompoundCommand>());
    expect(d.tree.definition(one.handle), isNull, reason: 'not added yet');
    // M-PB1: no ref kept pending (each call copies anew).
    expect(identical(s.symbolDefinition(table), one), isTrue);
    // M-PB2: the pending refs kept per kit's services.
    expect(
        identical(c.servicesOf('demo').symbolDefinition(table), one), isTrue);

    // A tool's commit executes straight through the document.
    d.commands.execute(one.add!);
    expect(d.tree.definition(one.handle), isNotNull);
    expect(d.components.get<UnitComponent>(one.handle),
        UnitComponent(kind: UnitKinds.table, capacity: 4));
    final again = s.symbolDefinition(table)!;
    // M-PB3: a pending ref kept after the document holds its definition
    // (its add handed out again).
    expect(again.add, isNull);
    expect(again.handle, one.handle);
    expect(definitionsOf(d, 'pb.table.round'), [one.handle]);
  });

  test(
      'PB-def-execute a controller execute, and a new plan, drop the '
      'pending refs: the next call is a new copy', () async {
    final c = make([pbKit()]);
    await settle();
    final s = c.servicesOf('pb');
    final d = c.document;
    final one = s.symbolDefinition(table)!;
    expect(
        c.execute(addDrafted(d, EntityKind.line,
            linePayload(Vector2(-3100.5, 4200.25), Vector2(-1700.75, 5100.5)),
            layer: ReservedHandles.layerZero)),
        isTrue);
    final next = s.symbolDefinition(table)!;
    // M-PB4: `execute` not clearing the pending refs.
    expect(identical(next, one), isFalse);
    expect(next.add, isNotNull);
    expect(next.handle, isNot(one.handle), reason: 'new handles from the seed');

    c.newPlan();
    final fresh = s.symbolDefinition(table)!;
    // M-PB5: `_open` not clearing them (the old document's handles).
    expect(identical(fresh, next), isFalse);
    expect(fresh.add, isNotNull);
    expect(c.document.tree.definition(fresh.handle), isNull);
  });

  test(
      'PB-def-top the base point, and the top: the first leaf\'s box for a '
      'circle or a closed outline, else the definition\'s box', () async {
    final c = make([pbKit()]);
    await settle();
    final s = c.servicesOf('pb');
    final round = s.symbolDefinition(table)!;
    expect(round.basePoint, Vector2(2100.5, 1300.25));
    // M-PB6: the top always the definition's box.
    expect(boxOf(round.top), [1650.5, 850.25, 2550.5, 1750.25]);
    final shelf = s.symbolDefinition('pb.shelf.plain@1')!;
    expect(shelf.basePoint, Vector2(610.75, 205.5));
    // M-PB7: any first leaf taken as the top (the shelf's line).
    expect(boxOf(shelf.top), [110.75, 5.5, 1110.75, 405.5]);
    // The base point is the ref's own: writing it leaves the library as is.
    shelf.basePoint.x = 0;
    expect(c.symbolById('pb.shelf.plain@1')!.entry.definition.basePoint,
        Vector2(610.75, 205.5));
  });

  test(
      'PB-def-top-poly a closed outline first is the top, an open polyline '
      'first is not (the leafless symbol is a library error, rule 4: the '
      'empty-leaves guard is unreachable here)', () async {
    final c = make([
      symbolKit('pp', [
        SymbolLibrarySource(
            label: 'pp', read: () async => encodeLibrary(polyCatalog)),
      ]),
    ]);
    await settle();
    final s = c.servicesOf('pp');
    final closed = s.symbolDefinition('pp.closed.first@1')!;
    // M-PB9a: the polyline arm of `served` made false. M-PB9b:
    // `isClosedPolyline` made true (the open case then reads the outline).
    expect(boxOf(closed.top), [2600.5, 1000.25, 3400.5, 1600.25]);
    final open = s.symbolDefinition('pp.open.first@1')!;
    expect(boxOf(open.top), [1100.5, 300.25, 2300.5, 1500.25]);
  });

  test(
      'PB-def-null null for a key no loaded library has, and while loading; '
      'symbolsState is the controller\'s, failed included', () async {
    final c = make([pbKit()]);
    final s = c.servicesOf('pb');
    // M-PB8: the services' own listenable (a ValueNotifier(ready)).
    expect(identical(s.symbolsState, c.symbolsState), isTrue);
    expect(s.symbolsState.value, SymbolsState.loading);
    expect(s.symbolDefinition(table), isNull, reason: 'still loading');
    await settle();
    expect(s.symbolsState.value, SymbolsState.ready);
    expect(s.symbolDefinition('pb.table.round@9'), isNull);
    expect(s.symbolDefinition('pb.table.round'), isNull,
        reason: 'a full versioned key only');
    expect(s.symbolDefinition('pb.chair.none@1'), isNull);
    expect(s.symbolDefinition(table), isNotNull);

    final f = make([
      symbolKit('pb', [
        SymbolLibrarySource(
            label: 'pb', read: () async => throw StateError('offline')),
      ]),
    ]);
    await settle();
    expect(f.servicesOf('pb').symbolsState.value, SymbolsState.failed);
    expect(f.servicesOf('pb').symbolDefinition(table), isNull);
  });
}
