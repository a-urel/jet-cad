# jet_cad_2d_kit

The kit contract of jet_cad_2d plans. A kit — restaurant, architecture,
cinema — ships its symbols (and, later, its parametric types and tools) on
this contract, and the plan library loads any kit without knowing its
domain. No kit depends on the plan library, and no kit depends on another.

Two libraries:

- `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, the contract (Flutter): the
  components a plan stores (`jetcad.symbol`, `jetcad.unit`,
  `jetcad.manifest`, `jetcad.library`), the `.jetlib` library format and its
  validator, `KitNames`, `SymbolLibrarySource`, `bundledLibrary` and the
  `PlanKit` descriptor.
- `package:jet_cad_2d_kit/authoring.dart`, the authoring toolkit (pure Dart,
  runs under `dart run`): the catalog language, the library builder, shape
  helpers, the geometry snapshot and the conformance test.

## A kit's catalog

```dart
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
```

`encodeLibrary(catalog)` gives the `.jetlib` bytes a kit commits as an
asset; `SymbolLibrary.decode(bytes)` validates and reads them. A kit's own
test runs `conformance(...)` and expects no problem: the committed library
is the built one, every published `key@N` keeps its geometry, and every
declared locale is complete.

The kit author's contract — naming, components, the format's rules, words,
versions and the new-kit checklist — is
[docs/kits.md](https://github.com/a-urel/jet-cad/blob/main/docs/kits.md).
