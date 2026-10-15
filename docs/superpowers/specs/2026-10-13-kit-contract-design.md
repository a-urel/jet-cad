# Sub-project 1: `jet_cad_2d_kit`, the contract's symbol side — design

**Date:** 2026-10-13. **Status:** revision 1; awaiting the human's review of
this file.

**Umbrella:** [2026-10-13-kit-architecture-design.md](2026-10-13-kit-architecture-design.md)
(approved by the human, *"onaylıyorum"*). This spec is its sub-project 1
(A13). Where this file is silent, the umbrella binds; where they disagree,
the umbrella wins and this file is wrong.

**Branch:** `feat/kit-architecture` (the umbrella's), worktree
`.claude/worktrees/kit-architecture`. **Size:** L, one plan. **Release:**
none on its own; `jet_cad_2d_kit` 0.1.0 goes out in the wave (umbrella A10).

## Purpose

Create `packages/jet_cad_2d_kit` with everything a kit needs to ship symbols:
the components a plan stores, the library format with its validator, the
sources and the words, the `PlanKit` descriptor's symbol part, the authoring
toolkit and the conformance test. Sub-project 2 adds the code side
(`PlanType`, `PlanTool`, properties, attachment providers) to the same
package. Nothing here touches the old packages (umbrella A12).

## Facts this spec builds on (at `1b4670b`)

Read from `packages/jet_cad_floor_plan/lib/src/symbols/` and
`packages/jet_cad_restaurant_symbols/`:

- Today's catalog symbol is `FurnitureSymbol` (`furniture_catalog.dart:75`:
  key, name, category, tags, version, seats, base point, shapes); its shapes
  are `LineShape`, `PolylineShape`, `CircleShape` and `ArcShape` under the
  sealed `FurnitureShape` (:17-72).
- The builder (`build_library.dart:35-87`) makes one definition per symbol,
  named `key@version`, carrying `jetcad.symbol` and, when servable,
  `jetcad.seating`, every leaf on layer 0 with by-block attributes, in one
  compound command; the output is deterministic. The generators encode it
  with `DraftDocumentCodec.encodeToString` (schema 10).
- The validator (`symbol_library.dart:116-355`) refuses about 25 faults, each
  pinned by `test/symbols/symbol_library_test.dart` (L1-L6, R00-R27e). It
  decodes with `registerAppComponents`, which registers the whole parametric
  layer, though only the two symbol components are needed (`catalog.dart:55-62`).
- Behaviour tags: `against-wall` and `family:<id>` (`symbol_library.dart:18-22`).
  The served top is the first leaf by convention (spec 14 S4).
- `SymbolNames` (`symbol_names.dart:12-37`) holds per-language names by key
  and categories by their English name; English is the library's own text.
- `SymbolLibrarySource` (`symbol_library_loader.dart:30-42`) is plain data in
  a Flutter file.
- The restaurant package's `shapes.dart` (chair, chairs around, stool, stools
  around, rect, inset, poly) and the furniture catalog's private `_chair`,
  `_rect`, `_inset` are near copies.

## K1. The package

```
packages/jet_cad_2d_kit/
  pubspec.yaml            name: jet_cad_2d_kit, version: 0.1.0
  lib/jet_cad_2d_kit.dart    the contract (Flutter)
  lib/authoring.dart      the authoring toolkit (pure Dart)
  lib/src/model/          pure Dart, exported by both libraries
  lib/src/kit/            PlanKit, sources, the bundled reader (Flutter)
  lib/src/authoring/      catalog, builder, shapes, conformance (pure Dart)
  test/
  README.md, CHANGELOG.md, LICENSE, example/
```

- **Dependencies:** the Flutter SDK, `jet_cad_2d ^0.7.2`, `vector_math`,
  `meta`. Not `jet_cad_2d_flutter` yet: sub-project 2 adds it with
  `PlanTool`. Never `jet_cad_2d_plan` or a kit (umbrella A1).
- **Purity is tested.** A test walks the import graph of
  `lib/authoring.dart` and of every file under `lib/src/model/` and fails on
  any `package:flutter`, `dart:ui` or `dart:io` import (M: add
  `import 'package:flutter/foundation.dart';` to a model file; the test goes
  red).
- `resolution: workspace`, a member of the root workspace.

## K2. The components a plan stores

All on the contract's registry function, `registerKitComponents(ComponentRegistry)`,
which registers these and nothing else. Each is immutable, value-equal,
with a fixed alphabetical JSON key order, and refuses bad values in its
constructor with `ArgumentError` (never an `assert`: a release build must
refuse too).

**`SymbolComponent`, `jetcad.symbol`**, on a definition's handle:

| Field | Type | Rule |
|---|---|---|
| `key` | String | the kit id, then two or more dot-separated segments; each segment lower-case letters and digits, joined by single hyphens: `^[a-z0-9]+(-[a-z0-9]+)*(\.[a-z0-9]+(-[a-z0-9]+)*){2,}$` |
| `version` | int | at least 1 |
| `name` | String | English, not empty |
| `category` | String | English, not empty |
| `tags` | List<String> | search words only: lower case, not empty, no duplicates; spaces allowed |
| `attachTo` | List<String> | attachment target kinds (umbrella A5): each `^[a-z0-9]+(-[a-z0-9]+)*$`, no duplicates; empty for none |
| `family` | String? | a size family, same pattern as a target kind |

**`UnitComponent`, `jetcad.unit`** (umbrella A6), on a definition's handle,
present when the symbol is a service unit:

| Field | Type | Rule |
|---|---|---|
| `kind` | String | a unit kind, same pattern as a target kind; the contract names `table` and `seat` as constants (`UnitKinds.table`, `UnitKinds.seat`), and others are allowed |
| `capacity` | int | at least 1 |
| `labelling` | enum `numbered` / `assigned` | `numbered`: the plan gives a placed unit the next free number (a table); `assigned`: a kit's type sets the label (a seat in a row) |

**`ManifestComponent`, `jetcad.manifest`** (umbrella A8), on a plan's root:
`format` (int, 1) and `kits` (kit id → the version string that last saved
the plan, each id a kit id). Defined and tested here; the plan library writes
and checks it in sub-project 2.

**`LibraryComponent`, `jetcad.library`**, on a library's root: `kit` (the
kit id whose symbols the library holds) and `format` (int, 1).

A **kit id** is `^[a-z][a-z0-9]*$` (no dots, no hyphens: it is the first
segment of every key and type id).

## K3. The library format

A `.jetlib` is the engine codec's JSON (`DraftDocumentCodec`, today schema
10) of a document that holds:

- a root group carrying `LibraryComponent`;
- one definition per `key@version`, named `key@version`, carrying
  `SymbolComponent` and, for a unit, `UnitComponent`;
- each definition's leaves: lines, polylines, circles and arcs only, on
  layer 0, linetype and colour by block, lineweight and transparency by
  block, flags 0;
- millimetre units; no instance, no group other than the root, no text, no
  fill.

**Encoding** is `encodeLibrary` in the authoring toolkit (K6), deterministic:
the same catalog gives the same bytes. **Decoding** is
`SymbolLibrary.decode(Uint8List)` in the model, which registers only
`registerKitComponents` and validates.

**The validator refuses** (each rule with its test, ported from
`symbol_library_test.dart`'s L and R rules where one exists):

1. bytes that are not a readable document of the codec (any codec error,
   any codec diagnostic: a repaired cycle is a refusal);
2. a root without `LibraryComponent`, a `format` other than 1, a
   `LibraryComponent` anywhere but the root, or units other than millimetres;
3. any node other than the root (an instance, a group);
4. a definition without `SymbolComponent`; a definition with children;
5. a key that breaks K2's pattern, or whose first segment is not the
   library's `kit`;
6. a repeated `key@version` (the same key at two versions is allowed);
7. a `Definition.name` other than `key@version`;
8. a tag, target kind or family that breaks K2;
9. a unit definition (one carrying `UnitComponent`) whose `SymbolComponent`
   has a `family`;
10. a `UnitComponent` on a handle that is not a symbol definition;
11. a unit whose first leaf is not closed (a closed polyline or a circle),
    or is a closed polyline enclosing an area at or under
    `Tolerance.linear`² (amended by the final review): the first leaf of a
    unit is its outline, which service mode fills (today's S4, now a rule
    instead of a convention);
12. a non-finite base point;
13. a leaf owned by anything but a definition; a leaf of kind text, fill,
    attribute or point;
14. a leaf's style other than exactly what the builder writes: layer 0,
    linetype, colour, lineweight and transparency by block, linetype scale 1,
    flags 0 (by layer and CONTINUOUS, which today's validator accepts, are
    refused: a library leaf takes its look from the instance, as an AutoCAD
    block's does);
15. bad geometry: wrong coordinate or scalar counts for the kind, a
    non-finite value, a coordinate beyond `1e6`, a zero-length line, a
    polyline under 2 points or whose points' bounding box has width and
    height both at or under `Tolerance.linear` (amended by the final review
    and the PR review), a radius or sweep at or under `Tolerance`.

What the validator does not check: names, categories and tags beyond K2's
patterns (the conformance test checks completeness, K7), and anything under
another component type (preserved and ignored, as the engine does).

**`SymbolLibrary`** (model) holds the kit id and its entries in definition
order; an entry carries its `SymbolComponent`, its `UnitComponent` or null,
its definition and its leaves. `SymbolLibrary.merge(List<SymbolLibrary>)`
concatenates in order and refuses a `key@version` in two libraries, naming
each library by its position and its kit.

## K4. Words

**`KitNames`** (model) replaces `SymbolNames`: one flat map per locale, from
a namespaced word id to the word.

| Word id | For |
|---|---|
| `symbol:<key>` | a symbol's name |
| `category:<kit id>/<English category>` | a category; under the kit's id, since two kits may both have a `Bar` |
| `tool:<tool id>`, `type:<type id>`, `property:<type id>.<property>` | sub-project 2's words |

- **Lookup** falls back from the locale to English, then, for a symbol or a
  category, to the library's stored English text.
- English (`en`) is required for every word that has no stored English
  (tools, types, properties); a kit's other locales are optional, and a kit
  that declares one declares it complete (K7).
- `KitNames.merge` joins kits' words; two kits never share a word id, since
  every id carries a key or id under its kit (umbrella A7).

## K5. Kits and sources

**`SymbolLibrarySource`** (Flutter library, plain data): a `label` for
messages and `Future<Uint8List> Function() read`. A kit's symbols are its
sources' libraries; every library a kit's sources read must carry that
kit's id (a refusal otherwise, when the plan library loads it).

**`bundledLibrary(String assetKey, {AssetBundle? bundle})`** returns a
reader of an asset bundle (`rootBundle` when null). A kit's source is one
line: `SymbolLibrarySource(label: 'restaurant', read:
bundledLibrary('packages/jet_cad_2d_kit_restaurant/assets/restaurant.jetlib'))`.

**`PlanKit`**, the descriptor's symbol part:

```dart
final class PlanKit {
  const PlanKit({
    required this.id,
    required this.version,
    this.symbols = const [],
    this.names = KitNames.empty,
  });
  final String id;          // a kit id (K2)
  final String version;     // the kit package's version, for the manifest
  final List<SymbolLibrarySource> symbols;
  final KitNames names;
}
```

`PlanKit.validate()` returns the descriptor's problems: a bad id, an empty
version, a word id under another kit's id. Sub-project 2 adds `types`,
`tools` and `attachments` and extends `validate`.

## K6. The authoring toolkit

`package:jet_cad_2d_kit/authoring.dart`, pure Dart.

**The catalog language:**

```dart
const CatalogSymbol(
  key: 'restaurant.table.rect.four',
  name: 'Rectangular table, 4 seats',
  category: 'Restaurant Tables',
  tags: ['table', 'rectangular', 'four'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
  base: (0, 0),
  shapes: [CatalogPolyline([...], closed: true), ...],
);
```

- `CatalogSymbol`: `key`, `version` (default 1), `name`, `category`,
  `tags`, `attachTo` (default empty), `family`, `unit` (a `CatalogUnit`,
  `labelling` defaulting to `numbered`), `base`, `shapes`.
- `CatalogShape`, sealed: `CatalogLine`, `CatalogPolyline`, `CatalogCircle`,
  `CatalogArc` (from `start` through a signed `sweep`, both in radians: a
  positive sweep turns counter-clockwise, a negative one clockwise).
- `Catalog(kit: 'restaurant', symbols: [...])`.

**The builder:** `Uint8List encodeLibrary(Catalog)` and, for tests,
`DraftDocument buildLibraryDocument(Catalog)`. Deterministic; handles
ascend in catalog order (definition, its leaves, the next definition), as
today's builder does.

**Shape helpers**, the shared ones the two catalogs copy today, pure
functions returning shapes: `rect`, `inset`, `poly`, `chairAt`,
`chairsAround`, `stoolAt`, `stoolsAround`, with today's constants
(`chairSize` 450, `chairTuck` 100, `stoolRadius` 190, `stoolTuck` 40), and
the cleaning of every coordinate to 1e-6 with `-0` made `0`. A helper is a
convenience for kit authors, not part of the runtime contract: a change to
one never changes a published `key@N` (K7 holds every kit to its committed
geometry).

## K7. The conformance test

`List<KitProblem> conformance(...)` in the authoring toolkit, pure Dart. A
kit's own test calls it and expects an empty list. Inputs: the kit's
`Catalog`, its committed library bytes, its committed geometry snapshot,
its `KitNames`, the locales it declares.

It reports:

1. **Built equals committed:** `encodeLibrary(catalog)` equals the
   committed bytes.
2. **The library validates** (K3) and its `kit` is the catalog's.
3. **Every key is under the kit's id** (K2's pattern, first segment).
4. **The geometry snapshot holds.** `geometrySnapshot(catalog)` gives, per
   `key@version`, a canonical JSON text of its base point, shapes and unit
   (kind, capacity, labelling). Every entry of the committed snapshot must
   be in the current one and equal to it: a published `key@N` never changes
   its geometry or its unit (umbrella A16). A new `key@N` may be added. A
   removed `key@N` is a problem: a key is never removed.
5. **Words are complete:** every declared locale has a word for every
   symbol and category, not equal to the English unless the English is the
   right word for that locale (an explicit allow-list per kit); no word for a
   key or category the catalog lacks. A key's word is compared with the English name of
   the key's newest version.
6. **Lower case** for keys, tags, target kinds, families and kinds.

The snapshot is a committed JSON file in the kit's `test/`. The kit's
generator writes the library and **adds** the snapshot entries of new
`key@N`s; it never rewrites an existing entry, so a changed geometry shows as
a failing test, never as a quietly regenerated file. `updateSnapshot` in the
authoring toolkit is that merge, tested (M: let it overwrite an existing
entry; the test goes red).

## K8. `docs/kits.md`, begun

The kit author's contract, written as far as sub-project 1 reaches: the
naming (umbrella A7), the components (K2), the library format (K3), the
words (K4), the descriptor (K5), the authoring toolkit (K6), the key and
version rules and the semver steps (umbrella A16), the conformance test
(K7), and the new-kit checklist's symbol part. Sub-project 2 adds the code
side.

## K9. CI

- A job for `packages/jet_cad_2d_kit`: `flutter test`, `flutter analyze`,
  `dart format --output=none --set-exit-if-changed .`.
- **The dependency rule** (umbrella A1) as `tool/ci/check_kit_deps.dart`
  with tests: `jet_cad_2d_kit` depends on neither `jet_cad_2d_plan` nor any
  `jet_cad_2d_kit_*`; a `jet_cad_2d_kit_*` depends on no `jet_cad_2d_plan` and no other
  `jet_cad_2d_kit_*`, in its pubspec or in an import of any of its Dart files
  (every directory but `build/` and `.dart_tool/`; amended by the final
  review, umbrella A1). It passes vacuously for packages that do not exist
  yet and runs in the CI tools job.

## Tests

Every test is worth landing only if a named mutation makes it go red
(CLAUDE.md). The plan names one per test. In outline:

- **Components:** constructor refusals per field and pattern; JSON key
  order; `fromJson` refusals; a byte-identical round trip; equality over
  every field (M: drop `attachTo` from `==`).
- **The validator:** one fault per rule of K3, each made by a one-edit change
  to a valid library's JSON (today's `symbol_fixtures.dart` breaker
  pattern), ported where a rule exists and new for 2, 5, 7, 8, 9, 11.
  Fixtures are off the origin and rotated where geometry matters (the
  degenerate-fixture lesson).
- **The builder:** deterministic; handle order; a catalog of every shape
  kind round-trips through `decode` to equal entries; a unit's components.
- **Merge:** order; the cross-library duplicate names each library by position and kit.
- **Words:** fallback chain locale → English → stored English; merge.
- **Conformance:** one failing kit per problem of K7, including a moved
  vertex of a committed `key@1`, a changed capacity, a removed key, a missing
  Turkish word, a key under another kit's id.
- **Purity** (K1) and **the dependency rule** (K9).
- **A sample kit** in `test/fixtures/` exercises the whole path: a catalog,
  its generated library and snapshot, its names, conformance empty.

## Exit gate

- `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
- `cd tool/ci && dart test`, and `dart run tool/ci/check_kit_deps.dart`
- The three CLAUDE.md gates still green (no old package changes, but run).
- `cd packages/jet_cad_2d_kit && dart pub publish --dry-run` with 0 warnings
  (not published: the wave publishes).
- An independent review of the whole branch.

## Out of scope

- The code side of the contract (`PlanType`, `PlanTool`, properties,
  attachment providers): sub-project 2.
- Loading, placing and the service behaviour: sub-project 2.
- The architecture and restaurant catalogs: sub-projects 3 and 4 (the sample
  kit in K7's tests stands in).
- Any change to `jet_cad_floor_plan` or `jet_cad_restaurant_symbols`.

## Amendments while planning (2026-10-13)

From the plan's spec gaps 1-8: decode reads components through guarded
factories so a bad pattern reaches rule 5 or 8 rather than a codec error;
rule 2 covers units and a misplaced `LibraryComponent`; rule 9 and rule 14
are worded exactly; the merge error names libraries by position and kit; a
category's word id carries its kit id; K7.5 compares with the newest
version's English. The umbrella's A2 now matches K5 (words on the kit, a
`final` sketch).

`SymbolLibrary` holds `kits` (a list), since a merged library spans kits.

## Amendments from the final review (2026-10-13)

- **K3 rule 15** also refuses a zero-length polyline (a closed polyline of
  one point among them): one whose points' bounding box has width and height
  both at or under `Tolerance.linear` (the PR review's wording; this
  amendment first said "within `Tolerance.linear` of each other").
- **K3 rule 11** also refuses a unit whose outline is a closed polyline
  enclosing an area at or under `Tolerance.linear`², in either winding:
  service mode would fill nothing.
- **K9** reads every Dart file of the contract and of a kit (every
  directory but `build/` and `.dart_tool/`), picking packages by their
  pubspec's name: umbrella A1 says "any of its Dart files", and the umbrella
  wins.
- `docs/kits.md` no longer says a retired symbol leaves the gallery: the
  contract has no retired mark (R2 below).

## Amendments from the PR review (2026-10-13)

- PR #11: PR1 rule 15's zero-length polyline test is the points' bounding
  box (width and height both at or under `Tolerance.linear`), one
  allocation-free pass on untrusted bytes, not a pairwise comparison (it
  differs only up to the box's diagonal); PR2 K9's check reports an
  unreadable pubspec as a problem instead of throwing; PR3 `CatalogArc`'s
  sweep is signed (positive counter-clockwise, negative clockwise); PR4 the
  purity test and K9 read directives with `package:analyzer`, a
  dev_dependency of the contract and a dependency of `tool/ci`.
- PR #12: PR5 `analyzer` ^13.3.0 needs Dart 3.11, so `tool/ci`'s SDK floor
  is `^3.11.0`; the contract keeps `^3.6.0`, since a dev_dependency binds
  only whoever runs its tests, never a host; PR6 K6's `CatalogArc` bullet
  states the signed sweep that PR3 introduced.

## Amendments from sub-project 3a (2026-10-15)

Each line is written by the 3a task that lands it (the 3a spec,
[2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md),
"Amendments to other specs").

- **The symbol box family** (3a C1.4): `SymbolBox`, `isOrthonormal`,
  `boxOfLeaves`, `boxOfEntry`, `servedTopOfEntry`, `boxOfDefinition`,
  `footprintOf` and `placementTransform` are the contract's, pure Dart in
  the model (`lib/src/model/symbol_box.dart`), exported by both libraries;
  moved unchanged from the plan library, which imports them from here and
  keeps no copy.
- **Object views and hidden fields** (3a C1.1, C1.7): the surface gains
  `PlanObject`, `DocumentPlanObject`, `TextDisplay`,
  `LengthProperty.range`, `PropertySpec.visible`,
  `PropertyField.visible`, `PlanSection` (the escape hatch's one context)
  and `KitProblemCode.settingsNeedObject`; `PlanType.fieldsOf`,
  `commitField` and `sectionFor` take a `DraftDocument`, and `fieldsOf`
  and `commitField` the kit's words, which the object carries
  (`PlanObject.words`, a `PlanWords`: the pure interface `KitWords` now
  implements, exported by both libraries).
- **K4, texts** (3a C1.6): a fourth kind of word id, `text:<kit id>.<id>`,
  for a kit's messages and templates, with `{name}` placeholders filled
  when read (`KitWords.text`; a missing argument is left as written; a
  choice of words is two texts). English is required, `validateHostWords`
  accepts them, and the conformance test holds them to the declared
  locales and asks every locale's text for English's placeholders
  (`placeholderMismatch`).
- **Words with parameters** (3a C1.6, C1.2): the surface gains `KitText`,
  `fillText`, `placeholdersOf`, `numberedNameIndex` (moved from the plan
  library, over patterns that name no plan type), `PlanWords.text` and
  `PlanWords.decimalSeparator`, inherited by `KitWords` (the UI
  language's separator, which the plan fills from its `PlanStrings`).

## Inputs for sub-project 2

The final review's API risks, none needing a breaking change if settled in
sub-project 2's spec before the wave publishes 0.1.0:

- **R1 Per-unit data has no home.** `UnitComponent` sits on a definition;
  umbrella A6's per-unit label (`assigned`, set by a kit's type) and number
  (`numbered`) need an instance-level contract component, so
  `registerKitComponents`' "the four and nothing else" changes. A parametric
  unit (a booth with N seats) cannot carry a capacity on a definition's
  handle.
- **R2 Retirement.** A retired symbol leaving the gallery (umbrella A16)
  needs a mark, likely an optional `retired` field in `jetcad.symbol` and
  the catalog. Every `fromJson` requires every field today: a field added
  later must be optional when read (absent reads as its default, here
  `false`), or plans saved before it stop opening.
- **R3 Conformance sees no types, tools or properties.** `conformance()` is
  pure Dart and they live on the Flutter `PlanKit`; A16 requires their ids
  and their English to be checked. Grow additive named parameters (ids and
  words as strings) rather than moving the check into `PlanKit.validate`
  alone.
- **R4 `KitProblemCode` will grow** (types, tools, attachments). Each new
  value after 0.1.0 breaks exhaustive switches: land sub-project 2's codes
  before publishing.
- **R5 Engine types in the public API.** `SymbolLeaf` exposes
  `EntityRecord` and `GeometryPayload`, `SymbolEntry.definition` a
  `Definition`: a breaking change of those in `jet_cad_2d` 0.x is one of the
  contract and of every kit. K7.1's byte equality ties every kit's CI to the
  codec's exact output: an engine release that changes `encodeToString`
  turns every kit red until it regenerates. Document both in `docs/kits.md`.
- **R6 Manifest versions are free strings** (`ManifestComponent`,
  `PlanKit.version`). If sub-project 2 compares versions, it parses semver;
  tightening the format later must not refuse manifests already stored.
- **R7 Rule 11's threshold does not scale.** The area test
  (`area <= Tolerance.linear²`) is absolute, so only a zero-area outline is
  refused: a 600 mm × 1e-9 mm sliver loads. Sub-project 2 replaces it with
  a width test (`2·area/perimeter <= Tolerance.linear`).

## Risks

- **The model fixed before its first real user.** Sub-project 2 may need a
  field K2 lacks. Nothing is published until the wave, so K2 may still
  change then; the change goes into this spec as an amendment.
- **The snapshot's canonical form** must not drift with formatting: it is
  built from the catalog's numbers after the helpers' 1e-6 cleaning,
  printed with Dart's shortest round-trip representation, keys sorted.
