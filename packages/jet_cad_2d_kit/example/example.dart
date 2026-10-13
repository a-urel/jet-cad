// A one-symbol kit: its catalog, its words, its library, decoded.
//
//   cd packages/jet_cad_2d_kit && dart run example/example.dart
import 'package:jet_cad_2d_kit/authoring.dart';

/// The catalog of a kit "cafe": one round table for two, a service unit.
Catalog buildCafeCatalog() => Catalog(kit: 'cafe', symbols: [
      CatalogSymbol(
        key: 'cafe.table.round-two',
        name: 'Round table, 2 seats',
        category: 'Tables',
        tags: const ['table', 'round', 'two'],
        unit: const CatalogUnit(kind: UnitKinds.table, capacity: 2),
        base: (600, 600),
        shapes: [
          const CatalogCircle((600, 600), 350),
          ...chairsAround(600, 600, 350, 2),
        ],
      ),
    ]);

/// The kit's words: Turkish, declared complete.
const KitNames cafeNames = KitNames({
  'tr': {
    'symbol:cafe.table.round-two': 'Yuvarlak masa, 2 kişilik',
    'category:cafe/Tables': 'Masalar',
  },
});

void main() {
  final library = SymbolLibrary.decode(encodeLibrary(buildCafeCatalog()));
  for (final entry in library.entries) {
    print('${entry.id}: ${entry.leaves.length} leaves, '
        '${cafeNames.symbolName('tr', entry.symbol)}, '
        'capacity ${entry.unit?.capacity}');
  }
}
