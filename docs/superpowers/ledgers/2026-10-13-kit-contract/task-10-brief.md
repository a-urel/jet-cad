### Task 10: `docs/kits.md`, the package README and its example (K8)

**Files:**
- Create: `docs/kits.md`
- Create: `packages/jet_cad_2d_kit/example/example.dart`
- Modify: `packages/jet_cad_2d_kit/README.md`, `packages/jet_cad_2d_kit/CHANGELOG.md`
- Test: `test/authoring/example_test.dart`

**Interfaces:**
- Consumes: the whole public API of Tasks 2-9.
- Produces: the kit author's contract as far as sub-project 1 reaches (K8); the package's README and example for the dry run (Task 12) and pub.dev.

Plan decision: the authoring code shown in `docs/kits.md` and in the README is `example/example.dart`'s, and a test runs the example's `buildCafeCatalog()` through `encodeLibrary`, `SymbolLibrary.decode` and `conformance`, so the documented code cannot rot without a red test.

- [ ] **Step 1: The example and its failing test.** Create `test/authoring/example_test.dart`:

```dart
// Spec K8: the code docs/kits.md and the README show is the example's, and
// it builds, decodes and conforms.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import '../../example/example.dart';

void main() {
  test('E1 the documented catalog builds, decodes and conforms', () {
    final catalog = buildCafeCatalog();
    final bytes = encodeLibrary(catalog);
    final library = SymbolLibrary.decode(bytes);
    expect(library.kits, ['cafe']);
    expect([for (final e in library.entries) e.id], ['cafe.table.round-two@1']);
    expect(library.entries.single.unit,
        UnitComponent(kind: UnitKinds.table, capacity: 2));
    // M-E1: give the example's table three chairs; the leaf count changes.
    expect(library.entries.single.leaves, hasLength(1 + 2 * 2));
    expect(
        conformance(
          catalog: catalog,
          committedLibrary: bytes,
          committedSnapshot: encodeSnapshot(geometrySnapshot(catalog)),
          names: cafeNames,
          locales: const ['tr'],
        ),
        isEmpty);
  });
}
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/example_test.dart`. Expected: compilation error (`Error when reading 'example/example.dart'`).

Create `packages/jet_cad_2d_kit/example/example.dart`:

```dart
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
```

Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/example_test.dart && dart run example/example.dart`. Expected: `All tests passed!`, then `cafe.table.round-two@1: 5 leaves, Yuvarlak masa, 2 kişilik, capacity 2`.

- [ ] **Step 2: The README.** Replace `packages/jet_cad_2d_kit/README.md` with:

````markdown
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
````

- [ ] **Step 3: The CHANGELOG.** Replace `packages/jet_cad_2d_kit/CHANGELOG.md` with:

```markdown
## 0.1.0

- The kit contract's symbol side: the plan components (`jetcad.symbol`
  with attachment kinds and a size family, `jetcad.unit`, `jetcad.manifest`,
  `jetcad.library`) and `registerKitComponents`.
- The `.jetlib` library format: `SymbolLibrary.decode` and its fifteen
  rules, `SymbolLibrary.merge`.
- `KitNames`, `SymbolLibrarySource`, `bundledLibrary`, `PlanKit`.
- The authoring toolkit (pure Dart): the catalog language,
  `encodeLibrary`, the shared shape helpers, the geometry snapshot and the
  conformance test.
```

- [ ] **Step 4: `docs/kits.md`.** Create `docs/kits.md`:

````markdown
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
  `jet_cad_2d_plan` and never on another kit**, in its pubspec or in any
  import under `lib/`, `test/` or `tool/`. `tool/ci/check_kit_deps.dart`
  fails CI when one does. Kits cooperate only through the contract.
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

A kit's keys, types and tools all start with its own id; the conformance
test (§8) refuses one that does not.

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
11. a unit whose first leaf is not closed (a closed polyline or a circle):
    a unit's first leaf is its outline, which service mode fills;
12. a non-finite base point;
13. a leaf owned by anything but a definition; a text, fill, attribute or
    point leaf;
14. a leaf style other than layer 0, BYBLOCK linetype at scale 1, BYBLOCK
    colour, lineweight and transparency, no flag, text style STANDARD;
15. bad geometry: wrong counts, a non-finite value, a coordinate beyond
    1e6 mm, a zero-length line, a polyline under 2 points, a radius or a
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

```dart
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
  `CatalogArc` (counter-clockwise from `start`, `sweep` in radians), in
  millimetres in the symbol's frame. A unit draws its outline first.
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
void main() {
  File('assets/cafe.jetlib').writeAsBytesSync(encodeLibrary(buildCafeCatalog()));
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
  and never reused: a retired symbol leaves the gallery but stays in the
  library. A plan never needs a library to draw: it copies every placed
  symbol's definition.
- **Names, categories, words and tags may change at any version**; they are
  not geometry.
- **Semver at 0.x:** a new symbol, a new `@N`, words or tags is a patch; a
  removed or renamed Dart name, a type's parameters changed or the kit id
  changed is a minor (0.x+1.0).

A kit's test:

```dart
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
6. Its conformance test, expecting no problem.
7. Its CI line, a demo and its README pictures (the plan library's
   sub-projects describe these).
````

- [ ] **Step 5: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0. Then check by eye that every Dart name in `docs/kits.md` exists in the package (`grep -n` each of `buildCafeCatalog`, `cafeNames`, `bundledLibrary`, `parseSnapshot`, `encodeSnapshot`, `updateSnapshot`, `geometrySnapshot`, `conformance`, `sameAsEnglish`, `cleanCoordinate` under `packages/jet_cad_2d_kit/lib` or `example/`) and that the two catalog blocks are character-for-character the example's `buildCafeCatalog`. Also `grep -n "cafeCatalog" docs/kits.md packages/jet_cad_2d_kit/README.md` finds only `buildCafeCatalog` (no bare `cafeCatalog`), and every word id and category in a `docs/kits.md` or README snippet (`symbol:cafe.table.round-two`, `category:cafe/Tables`) is one the example's catalog or `cafeNames` has: no `Bar`. `grep -n "Bar" docs/kits.md` shows only the §4 prose about two kits both having a `Bar`.

- [ ] **Step 6: Mutation check.** M-E1: in `example/example.dart`, `chairsAround(600, 600, 350, 3)` → E1 red. Revert with `git checkout -- example/example.dart`; `git diff --quiet` exits 0.

- [ ] **Step 7: Commit.**

```bash
git add docs/kits.md packages/jet_cad_2d_kit/README.md packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/example/example.dart packages/jet_cad_2d_kit/test/authoring/example_test.dart
git commit -m "$(cat <<'EOF'
docs(kit): docs/kits.md, the package README and its example (K8)

The kit author's contract as far as the symbol side reaches: names, the
plan components, the library format's fifteen rules, words, the
descriptor, the authoring toolkit, key and version rules with the semver
steps, the conformance test and the new-kit checklist. The documented
catalog is the example's, and a test builds, decodes and conforms it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
