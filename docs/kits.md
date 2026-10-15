# Writing a kit

A **kit** brings a domain to jet_cad_2d plans: a restaurant's tables and
booths, a house's furniture, a cinema's seats. The plan library
(`jet_cad_2d_plan`) knows no domain; it loads the kits a host gives it.
Every kit and the plan library depend on one contract, `jet_cad_2d_kit`.

This document is the kit author's contract. Sections 1 to 9 cover the
**symbol side**: symbols, their library, their words and their tests.
Section 10 covers the **code side**: parametric types, tools, property
specs, colour targets and attachment providers, which the plan library
composes.

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

A kit's keys, types and tools all start with its own id. The conformance
test (§8) refuses a key that does not, and, given the kit's type, tool and
property ids, an id that does not. `PlanKit.validate` (§6) reports a type
or tool id that is not `<kit id>.<name>` or is given twice, and a word
under another kit's id, `tool:` and `type:` words included.

## 3. What a plan stores

| Component | On | Fields |
|---|---|---|
| `jetcad.symbol` (`SymbolComponent`) | a symbol's definition | `key`, `version`, `name` (English), `category` (English), `tags` (search words only, lower case, no duplicates), `attachTo` (target kinds, empty for none), `family` (a size family or null), `retired` (true: the gallery no longer offers it) |
| `jetcad.unit` (`UnitComponent`) | a service unit's definition | `kind` (`UnitKinds.table`, `UnitKinds.seat` or another kind), `capacity` (1 or more), `labelling` (`numbered`: the plan numbers it; `assigned`: a kit's type labels it) |
| `jetcad.library` (`LibraryComponent`) | a library's root | `kit`, `format` (1) |
| `jetcad.manifest` (`ManifestComponent`) | a plan's root | `format` (1), `kits` (kit id → the version that last saved the plan) |

Every component refuses a bad value in its constructor (an
`ArgumentError`) and writes its JSON keys in alphabetical order.
`registerKitComponents(registry)` registers the four and nothing else.

A field added after a component was first written is optional when read,
so what was saved before it still reads. `retired` is one: it is written
only when true and read as false when absent, so a library or a plan
without a retired symbol keeps its bytes.

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
    or is a closed polyline no wider than the engine's tolerance, its
    width being 2·area/perimeter (a 600 mm sliver 1e-9 mm wide is
    refused, a 600 mm by 1 mm bar is not): a unit's first leaf is its
    outline, which service mode fills;
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
| `type:<type id>` | a type's name: its panel section's title (§10.2) |
| `tool:<tool id>` | a tool's name in the palette (§10.5) |
| `property:<type or tool id>.<property id>` | a field of a type, or of a tool's settings (§10.3) |
| `property:<type or tool id>.<property id>.<value>` | a choice's value: an enum's name, else the value's text |
| `text:<kit id>.<id>` | a message or a template (a tool's notice, a numbered name, a label): `{name}` placeholders, filled by `KitWords.text`; a choice of words is two texts, one passed to the other |

Every word id carries its kit's id, so two kits never share one;
`PlanKit.validate` reports a word under another kit's id. Lookup
(`symbolName(locale, symbol)`, `categoryName(locale, kit, category)`)
falls back from the locale to English, then, for a symbol or a category,
to the library's stored English. English is required for every
word with no stored English. A kit's other locales are optional, and a kit
that declares one declares it complete. A text's every locale carries
English's placeholders (the conformance test's `placeholderMismatch`).
`KitWords.decimalSeparator` is the UI language's separator, for a number a
kit prints in the UI's words.

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

The code side (§10) adds `types`, `tools` and `attachments`. `validate()`
then also lists a type or tool id that is not `<kit id>.<name>`
(`typeOutsideKit`, `toolOutsideKit`), one given twice (`duplicateType`,
`duplicateTool`), and every word a type, tool or property needs that has
no English (`missingEnglish`). `propertyIds` lists the kit's property ids,
choice values included, for the conformance test.

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
  and never reused: a retired symbol stays in the library, marked
  `retired: true` in its catalog entry (`CatalogSymbol.retired`). The
  gallery stops offering it; a plan that holds it keeps drawing it. A plan
  never needs a library to draw: it copies every placed symbol's
  definition. Retiring changes no geometry, so the snapshot does not
  change; the library does, so run the generator.
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

A kit with a code side also passes its ids: `typeIds:` (`[for (final t in
kit.types) t.id]`), `toolIds:` (`[for (final t in kit.tools) t.id]`) and
`propertyIds:` (`kit.propertyIds`). Each id must be under the kit's id
(`typeOutsideKit`, `toolOutsideKit`, and `foreignWordId` for a property),
its word must have English (`missingEnglish`), and every declared locale
holds it like a symbol's word (`wordMissing`, `wordUntranslated`). Without
them, the code side is not checked. A kit's `text:` words are held the
same way, and a text whose placeholders are not English's is
`placeholderMismatch`.

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
7. Its code side, if it has one (§10): its types and tools under its id,
   their words in English and in every declared locale, its ids passed to
   the conformance test.
8. Its CI line, a demo and its README pictures (the plan library's
   sub-projects describe these).

## 10. The code side

A kit contributes the engine's own types and the Flutter layer's own tools,
each wrapped in a contract descriptor. The plan library composes them: it
registers the types, arms the tools, shows the fields, and calls every hook
through a guard. A kit never registers into the engine itself.

The snippets of this section are `example/cafe_code.dart`'s: a cafe's menu
board, `CafeSign`, a component with a width, a face and a colour, drawn by
`CafeSignType`, the engine's `ParametricType<CafeSign>`.

### 10.1 The descriptor

```dart
final PlanKit cafeCodeKit = PlanKit(
  id: 'cafe',
  version: '0.1.0',
  types: [
    PlanType<CafeSign>(
      id: CafeSign.id,
      fromJson: CafeSign.fromJson,
      parametric: const CafeSignType(),
      properties: signProperties,
      colour: signColour,
    ),
  ],
  names: cafeCodeNames,
);
```

`PlanKit` carries `types` (`PlanType`), `tools` (`PlanTool`) and
`attachments` (factories of `AttachmentProvider`) beside its symbols and
words. Its factories (a tool's `create`, a type's `grips`, the
`attachments`) run **once per document**: when the plan is replaced
(`load`, `newPlan`, an import), the plan library disposes what they made
and runs them again, so nothing a kit holds outlives its document. A
kit's prepare (a void Function(DraftDocument)) sets up each plan the plan
library makes, the empty plan of a new controller and every newPlan,
before any edit and outside history: the records its types draw with (the
separator's DASHED linetype). A loaded or imported plan is never prepared,
so a file is saved back as it was read. A host may fill a new plan in code
with a PlanBuild (PlanController(build:), newPlan(build:)).

### 10.2 A parametric type

| `PlanType` field | What it is |
|---|---|
| `id` | `<kit id>.<name>`, equal to the component's `typeId`: a plan's manifest finds its kits by it |
| `fromJson` | the component's factory |
| `parametric` | the engine's `ParametricType<T>`: `reach`, `generate`, `references`, the place hooks |
| `grips` | `ObjectGripProvider Function(PlanServices)?`: the Flutter layer's grips for its objects |
| `properties` | the panel's fields (§10.3) |
| `section` | the escape hatch: `(context, section) => Widget`, for what specs cannot say; `section` (a `PlanSection`) holds the `value`, `commit` (one undo step), the kit's `words`, the `object` (document, handle, world) and the kit's `services` |
| `title` | a word id for the section's title, from the value; default `type:<id>` |
| `colour` | a `ColourTarget` (§10.4) |
| `exported` | false leaves the type's objects out of every export |

**Covariance.** The plan library holds every type as `PlanType<Component>`.
A member whose type takes a `T` (a section builder, a spec's `read`) fails
Dart's runtime type check when read through that supertype, and
`register` would infer `T = Component`. So `PlanType` keeps those members
private and offers erased operations that run over its own `T`:
`registerInto`, `fieldsOf`, `commitField`, `titleWordOf`, `colourOf`,
`recolour`, `sectionFor`, `gripsFor`. The plan library calls only these. A
kit calls none of them, and never reads a spec's `read`, `write` or
`enabled` through a supertype either.

### 10.3 Property specs

```dart
final List<PropertySpec<CafeSign>> signProperties = [
  LengthProperty<CafeSign>(
    id: 'width',
    read: (s) => s.width,
    write: (s, v) => s.copyWith(width: v),
    min: 300,
    max: 2400,
  ),
  ChoiceProperty<CafeSign, SignFace>(
    id: 'face',
    values: SignFace.values,
    read: (s) => s.face,
    write: (s, v) => s.copyWith(face: v),
  ),
  ValueDisplay<CafeSign>(
    id: 'area',
    read: (s) => s.width * 80,
    unit: ValueUnit.area,
  ),
];

final ColourTarget<CafeSign> signColour = ColourTarget<CafeSign>(
  read: (s) => s.swatch,
  write: (s, swatch) => s.withSwatch(swatch),
);
```

| Kind | Holds | The panel |
|---|---|---|
| `LengthProperty` | `read`, `write`, `min`, `max`, `range(value, object)` (inclusive; null refuses every value) | millimetres, with the plan's decimal separator |
| `AngleProperty` | `read`, `write` | radians stored, degrees shown |
| `NumberProperty` | `read`, `write`, `min`, `max`, `decimals` (0 to 10) | rounded to `decimals` on commit |
| `ChoiceProperty<T, V>` | `values`, `read`, `write` | one of `values`, compared with `==` |
| `ToggleProperty` | `read`, `write` | a switch |
| `TextProperty` | `read`, `write`, `maxLength` (code points) | a text field |
| `ValueDisplay` | `read`, `unit` (`length`, `area`, `angle`, `none`) | read-only: a room's area |
| `TextDisplay` | `read(value, object)` → a `String`, or null to omit the line | read-only: a room's area as drawn |
| `ActionProperty` | `apply` | a button: a door's Flip hinge |

- Every spec has an `id` (a lower-case letter, then lower-case letters,
  digits and hyphens), an optional `enabled(T)` that greys the field out,
  an optional visible(T) that hides the field (a hidden field takes no
  room; an action whose gate is refused is hidden too), and an optional
  `gate`, the `PlanGate` permission it needs.
- A TextDisplay and a range read the object a field is shown for
  (PlanObject: document, handle, world, the kit's words); a tool's
  settings have none, so PlanKit.validate refuses them there
  (settingsNeedObject).
- `write` and `apply` return a changed copy; the plan library commits it
  as one `SetComponentCommand<T>`, the parametric system regenerates, and
  the edit is one undo step.
- Out of range, not finite, not one of the values, too long: the input is
  refused and the field shows its stored value again. A bad `min`, `max`,
  `decimals`, `maxLength`, `values` or `id` is an `ArgumentError` when the
  spec is made.
- Words: `property:<type id>.<id>`, a choice's values
  `property:<type id>.<id>.<value>`.

### 10.4 Colour

A `ColourTarget` reads a component's swatch, a name from the plan's palette,
and writes a copy with another (null clears it). The panel's colour row
recolours every selected object whose type has one, of any kit, in one
command; the `recolor` permission gates it.

### 10.5 Tools

| `PlanTool` field | What it is |
|---|---|
| `id` | `<kit id>.<name>`; its word is `tool:<id>` |
| `icon` | the palette's icon |
| `letter` | a suggested shortcut. The plan library's tools keep V, L, P, R, C, A and T; F is reserved; kits' letters follow in load order, and a letter already taken goes to no later tool (a `letterTaken` diagnostic) |
| `needs` | the `Capability`s its commits need; the palette disables it where the document's permissions deny one |
| `settings` | `PlanToolSettings<S>(initial: ..., specs: [...])`: one `S` per tool, edited in the panel with the same specs while the tool is active (words `property:<tool id>.<id>`), read by the tool through `PlanServices.settingsOf` |
| `create` | `Tool Function(PlanServices)`: the Flutter layer's `Tool` |

### 10.6 The services

`PlanServices` is a live view of one plan, one per kit:

| Member | |
|---|---|
| `document`, `index`, `camera` | the current document, its spatial index, the camera (apertures in world units) |
| `objectSnap` | the effective object-snap flag: F3 and the editor's snapping |
| `attachments` | every loaded kit's attachment providers (§10.7) |
| `words` | `KitWords`: this kit's words at the plan's locale, falling back to English, read live |
| `settingsOf<S>(toolId)` | a tool's current settings |
| `shared<T>(create)` | one `T` per kit and document, made on first use: what a kit's tools, grips and providers share (a wall's bands). A `T` that implements `Disposable` is disposed with its document |
| `liveTypeIdOf(handle)` | the type id of a live object; null for a frozen one (its code failed), a missing kit's, or anything else: what a kit's caches ask before they read an object as theirs |

A kit's own tests need no plan library: `package:jet_cad_2d_kit/testing.dart`'s `FakePlanServices` is a `PlanServices` over a document, with a real spatial index, a camera at a given scale, words from `KitNames` and settings from a map. It moves with the contract, so a kit's tests compile when the contract adds a member.

### 10.7 Attachment

An `AttachmentProvider` offers one target kind (`wall-face`). Asked with an
`AttachmentQuery` (the symbol's footprint and transform, the pointer, the
capture distances, whether it is mirrored, whether it may rotate, what to
exclude, the previous answer), it answers an `Attachment` (where the symbol
goes, where the plan library draws its marker, a token of its own) or null.
The plan library asks the providers of every kind in a symbol's `attachTo`
and keeps the answer whose marker is nearest the pointer. Under
`rotate: false`, a provider offers only targets the symbol's current turn
already fits.

### 10.8 When a kit's code fails

Every hook is called through a guard. A failure never stops the plan; it
becomes a `KitDiagnostic` (kit, subject, `KitDiagnosticCode`, message),
once per subject and code:

| What throws | What happens |
|---|---|
| a `ParametricType` hook | the edit is rolled back; the type's objects are probed, and each one whose hooks throw is frozen (treated as a plain group) and locked; the edit is tried once more. One broken object blocks one edit, once |
| a component's `fromJson`, on load | the component is kept as stored, and its object is locked |
| grips, an attachment provider | an `ArgumentError` from a grip's `drag` or `preview` refuses that point (no move, nothing reported); anything else: no grips for that object; no attachment |
| a tool's `create` | the tool is disabled |
| a tool's event or painting | the tool is cancelled and selection is armed |
| a spec's `write` or `apply` | the field shows its stored value |
| a section | a small "section failed" box in its place |
| a kit's `prepare` | the plan opens without what it would have added |

A plan that names a kit the host did not load opens: that kit's objects
draw, are locked, and are saved back unchanged (`kitMissing`). A plan saved
by a newer version of a loaded kit opens with a warning (`kitNewer`).

A frozen object's live referents (an opening's host wall) are locked with
it: they cannot be edited or deleted while it is frozen.

### 10.9 The engine's types, and byte equality

**The engine's types bind the contract.** A `PlanType` takes the engine's
`ParametricType<T>` and `Component`; a tool commits the engine's
`DraftCommand`s to its `DraftDocument`; a library's `SymbolLeaf` exposes
`EntityRecord` and `GeometryPayload`, a `SymbolEntry` its `Definition`.
Wrapping them in contract types would rewrite the parametric and grip
layers, so the contract uses them as they are. A breaking change of one of
them in `jet_cad_2d` 0.x is a breaking change of the contract and of every
kit that uses it.

**Byte equality ties a kit's CI to the codec.** The conformance test
compares the committed `.jetlib` with `encodeLibrary(catalog)` byte for
byte, and those bytes are the engine codec's `encodeToString`. An engine
release that changes that output (a key order, a number's spelling, a new
field) turns every kit's conformance test red with `builtDiffers` until the
kit runs its generator again. That is a regeneration, not a change of
geometry: the snapshot is unaffected and every published `key@N` keeps its
shapes. A kit that raises its `jet_cad_2d` constraint runs its generator
and commits the new library in the same change.
