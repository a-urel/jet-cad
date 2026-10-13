# Writing a kit

A **kit** brings a domain to jet_cad_2d plans: a restaurant's tables and
booths, a house's furniture, a cinema's seats. The plan library
(`jet_cad_2d_plan`) knows no domain; it loads the kits a host gives it.
Every kit and the plan library depend on one contract, `jet_cad_2d_kit`.

This document is the kit author's contract. It covers the **symbol side**:
symbols, their library, their words and their tests. Parametric types,
tools, properties and attachment providers (the code side) are added by
the plan library's sub-project and documented here then.

## 1. Packages and dependencies

```
jet_cad_2d               the engine
└─ jet_cad_2d_flutter    the Flutter layer
   └─ jet_cad_2d_kit     the contract
      ├─ jet_cad_2d_plan          the plan library
      ├─ jet_cad_2d_kit_<domain>  a kit
      └─ ...
```

- A kit depends on `jet_cad_2d_kit`. **A kit never depends on
  `jet_cad_2d_plan` and never on another kit**, in its pubspec or in an
  import of any of its Dart files (`lib/`, `test/`, `tool/`, `example/` and
  every other directory but `build/` and `.dart_tool/`).
  `tool/ci/check_kit_deps.dart` fails CI when one does. Kits cooperate only
  through the contract.
- `jet_cad_2d_kit/authoring.dart` is pure Dart: a kit's generator runs
  under `dart run`.

## 2. Names

| What | Rule | Example |
|---|---|---|
| Kit id | a lower-case letter, then lower-case letters and digits | `restaurant` |
| Kit package | `jet_cad_2d_kit_<kit id>` | `jet_cad_2d_kit_restaurant` |
| Symbol key | the kit id, then two or more segments of lower-case letters and digits joined by single hyphens | `restaurant.table.rect.four` |
| Symbol version | an integer from 1; `key@version` names one geometry | `restaurant.table.rect.four@1` |
| Type id, tool id | `<kit id>.<name>` | `architecture.wall` |
| Target kind, size family, unit kind | lower-case letters and digits joined by single hyphens | `wall-face`, `bed-double`, `table` |
| Contract component | `jetcad.<name>` | `jetcad.symbol` |

A kit's keys, types and tools all start with its own id. Today the
conformance test (§8) refuses a key that does not; it checks type and tool
ids when the code side arrives (the plan library's sub-project).
`PlanKit.validate` (§6) already reports a word under another kit's id,
`tool:` and `type:` words included.

## 3. What a plan stores

| Component | On | Fields |
|---|---|---|
| `jetcad.symbol` (`SymbolComponent`) | a symbol's definition | `key`, `version`, `name` (English), `category` (English), `tags` (search words only, lower case, no duplicates), `attachTo` (target kinds, empty for none), `family` (a size family or null) |
| `jetcad.unit` (`UnitComponent`) | a service unit's definition | `kind` (`UnitKinds.table`, `UnitKinds.seat` or another kind), `capacity` (1 or more), `labelling` (`numbered`: the plan numbers it; `assigned`: a kit's type labels it) |
| `jetcad.library` (`LibraryComponent`) | a library's root | `kit`, `format` (1) |
| `jetcad.manifest` (`ManifestComponent`) | a plan's root | `format` (1), `kits` (kit id → the version that last saved the plan) |

Every component refuses a bad value in its constructor (an
`ArgumentError`) and writes its JSON keys in alphabetical order.
`registerKitComponents(registry)` registers the four and nothing else.

Behaviour is in fields, never in tags: a symbol that stands against a wall
says `attachTo: ['wall-face']`; a symbol in a size family says
`family: 'bed-double'`.

## 4. The library format, `.jetlib`

A `.jetlib` is the engine codec's JSON of a document holding a root group
with `jetcad.library`, one definition per `key@version` named
`key@version` carrying `jetcad.symbol` (and `jetcad.unit` for a unit), and
each definition's leaves. `SymbolLibrary.decode(bytes)` refuses, with a
`SymbolLibraryError` naming the rule:

1. bytes that are not a readable document, or that the codec repaired;
2. a root without `jetcad.library`, a format other than 1, a library
   component elsewhere, units other than millimetres;
3. any node but the root (an instance, a group);
4. a definition without `jetcad.symbol`, with children, external, or with
   no leaf; a symbol component off a definition;
5. a key that breaks §2, or that is not under the library's kit;
6. a repeated `key@version` (the same key at two versions is fine);
7. a definition not named `key@version`;
8. a tag, target kind, family or unit kind that breaks §2 or §3;
9. a unit in a size family;
10. a unit component off a symbol's definition;
11. a unit whose first leaf is not closed (a closed polyline or a circle),
    or is a closed polyline enclosing no more area than the engine's
    tolerance squared: a unit's first leaf is its outline, which service
    mode fills;
12. a non-finite base point;
13. a leaf owned by anything but a definition; a text, fill, attribute or
    point leaf;
14. a leaf style other than layer 0, BYBLOCK linetype at scale 1, BYBLOCK
    colour, lineweight and transparency, no flag, text style STANDARD;
15. bad geometry: wrong counts, a non-finite value, a coordinate beyond
    1e6 mm, a zero-length line, a polyline under 2 points or whose points
    all lie in a box the engine's tolerance wide and high, a radius or a
    sweep within the engine's tolerance of zero.

`SymbolLibrary.merge` joins libraries in order and refuses a `key@version`
in two of them.

## 5. Words

`KitNames` holds a kit's words: one map per locale (a language code), from
a word id to the word.

| Word id | For |
|---|---|
| `symbol:<key>` | a symbol's name (all versions of the key) |
| `category:<kit id>/<English category>` | a category, under the kit's id: two kits may both have a `Bar` |
| `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>` | the code side's words |

Every word id carries its kit's id, so two kits never share one;
`PlanKit.validate` reports a word under another kit's id. Lookup
(`symbolName(locale, symbol)`, `categoryName(locale, kit, category)`)
falls back from the locale to English, then, for a symbol or a category,
to the library's stored English. English is required for every
word with no stored English. A kit's other locales are optional, and a kit
that declares one declares it complete.

## 6. The descriptor

The snippets in sections 6 to 8 are files under the package's `example/`
(`cafe_kit.dart`, `generate_cafe.dart`, `cafe_conformance_test.dart`),
analysed with the package; `example.dart` is the file with
`buildCafeCatalog` and `cafeNames`.

```dart
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'example.dart';

final PlanKit cafeKit = PlanKit(
  id: 'cafe',
  version: '0.1.0',
  symbols: [
    SymbolLibrarySource(
      label: 'cafe',
      read: bundledLibrary('packages/jet_cad_2d_kit_cafe/assets/cafe.jetlib'),
    ),
  ],
  names: cafeNames,
);
```

`bundledLibrary` reads the asset (from `rootBundle` unless a bundle is
given) when the plan library loads the kit. Every library a kit's sources
read carries that kit's id. `cafeKit.validate()` lists a bad id, an empty
version, a word under another kit's id, a word in no known namespace, a
code-side word without English. A source's `read` is a call, so a kit's
descriptor is `final`, not `const`.

## 7. The authoring toolkit

`package:jet_cad_2d_kit/authoring.dart`:

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

- Shapes: `CatalogLine`, `CatalogPolyline` (`closed:`), `CatalogCircle`,
  `CatalogArc` (from `start` through a signed `sweep`, in radians: positive
  counter-clockwise, negative clockwise), in millimetres in the symbol's
  frame. A unit draws its outline first.
- Helpers: `rect`, `inset`, `poly`, `chairAt`, `chairsAround`, `stoolAt`,
  `stoolsAround`, with `chairSize` 450, `chairTuck` 100, `stoolRadius` 190,
  `stoolTuck` 40; every coordinate cleaned to 1e-6 (`cleanCoordinate`). A
  helper is a convenience: changing one never changes a published `key@N`,
  because the conformance test holds every kit to its committed geometry.
- `encodeLibrary(catalog)` gives the bytes, deterministically, and refuses
  a catalog the format refuses.

A kit's generator (`tool/generate.dart`) writes the library and **adds** the
snapshot entries of new `key@N`s; it never rewrites an existing entry:

```dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';

import 'example.dart';

void main() {
  Directory('assets').createSync(recursive: true);
  Directory('test').createSync(recursive: true);
  File('assets/cafe.jetlib')
      .writeAsBytesSync(encodeLibrary(buildCafeCatalog()));
  final file = File('test/cafe_snapshot.json');
  final committed = file.existsSync()
      ? parseSnapshot(file.readAsStringSync())
      : <String, String>{};
  file.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(buildCafeCatalog()))));
}
```

## 8. Keys, versions and the conformance test

- **A published `key@N` never changes its geometry or its unit.** A change
  of either is a new `key@N+1`, beside the old one. A key is never removed
  and never reused: a retired symbol stays in the library. Taking a retired
  symbol out of the gallery is the plan library's sub-project: the contract
  has no retired mark yet. A plan never needs a library to draw: it copies
  every placed symbol's definition.
- **Names, categories, words and tags may change at any version**; they are
  not geometry.
- **Semver at 0.x:** a new symbol, a new `@N`, words or tags is a patch; a
  removed or renamed Dart name, a type's parameters changed or the kit id
  changed is a minor (0.x+1.0).

A kit's test:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import 'example.dart';

void main() {
  test('the kit conforms', () {
    expect(
      conformance(
        catalog: buildCafeCatalog(),
        committedLibrary: File('assets/cafe.jetlib').readAsBytesSync(),
        committedSnapshot: File('test/cafe_snapshot.json').readAsStringSync(),
        names: cafeNames,
        locales: const ['tr'],
      ),
      isEmpty,
    );
  });
}
```

It reports: a catalog that does not build; keys, tags, kinds and families
not in lower case; a key under another kit's id; a committed library that
is not the built one, that the format refuses, or that is another kit's; a
committed `key@N` whose geometry or unit changed, that was removed, or a
new one the snapshot lacks; a declared locale missing a word, or giving the
English word unless `sameAsEnglish` allows it; a word for a key or category
the catalog lacks; a locale with words that is not declared.

## 9. A new kit, the symbol part

1. A package `packages/jet_cad_2d_kit_<id>` depending on `jet_cad_2d_kit`
   (and nothing of the plan library or another kit).
2. Its catalog (`lib/src/catalog.dart`), keys under its id.
3. Its words (`KitNames`), English for everything without stored English,
   each declared locale complete.
4. Its generator (`tool/generate.dart`), run once: the `.jetlib` asset,
   declared in its pubspec, and the snapshot under `test/`.
5. Its source and descriptor (`PlanKit`), reading the asset with
   `bundledLibrary`.
6. Its conformance test, expecting no problem, and a test that
   `kit.validate()` is empty: a word under another kit's id or in no known
   namespace, and a `tool:`, `type:` or `property:` word without English,
   are caught only there.
7. Its CI line, a demo and its README pictures (the plan library's
   sub-projects describe these).
