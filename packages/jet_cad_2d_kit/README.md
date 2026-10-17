# jet_cad_2d_kit

The kit contract of jet_cad_2d plans. A kit — restaurant, architecture,
cinema — ships its symbols, its parametric types and its tools on this
contract, and the plan library loads any kit without knowing its domain.
No kit depends on the plan library, and no kit depends on another.

Two libraries:

- `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, the contract (Flutter): the
  components a plan stores (`jetcad.symbol`, `jetcad.unit`,
  `jetcad.manifest`, `jetcad.library`), the `.jetlib` library format and its
  validator, `KitNames`, `SymbolLibrarySource`, `bundledLibrary`, the code
  side (`PlanType`, `PlanTool`, the property specs, `ColourTarget`,
  attachment providers, `PlanServices`, `KitDiagnostic`) and the `PlanKit`
  descriptor.
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
versions, the new-kit checklist and the code side — is
[docs/kits.md](https://github.com/a-urel/jet-cad/blob/main/docs/kits.md).

## The jet-cad packages

| Package | What it is | Depends on |
|---|---|---|
| [`jet_cad_2d_plan`](https://pub.dev/packages/jet_cad_2d_plan) | The plan library: the editor, the widgets and the host API | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_architecture`](https://pub.dev/packages/jet_cad_2d_kit_architecture) | The architecture kit: walls, openings, rooms, dimensions and furniture | the kit contract, the renderer and the engine |
| [`jet_cad_2d_kit_restaurant`](https://pub.dev/packages/jet_cad_2d_kit_restaurant) | The restaurant kit: furniture and service units | the kit contract and the engine |
| [`jet_cad_2d_kit`](https://pub.dev/packages/jet_cad_2d_kit) | The kit contract: types, tools and the symbol library format | the renderer and the engine |
| [`jet_cad_2d_flutter`](https://pub.dev/packages/jet_cad_2d_flutter) | Flutter rendering and interaction | the engine |
| [`jet_cad_2d`](https://pub.dev/packages/jet_cad_2d) | The pure-Dart engine and document model | nothing of jet-cad |

A host that embeds the planner adds `jet_cad_2d_plan` and the kits it loads;
the kit contract, the renderer and the engine come with them, and a host
should not also depend on them directly unless it uses their API itself.

Embedding the floor planner in an app is walked through in the
[host guide](https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md).

## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).

## License

Apache License 2.0. See [LICENSE](LICENSE).
