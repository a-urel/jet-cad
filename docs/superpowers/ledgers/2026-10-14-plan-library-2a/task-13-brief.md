### Task 13: Symbols: `PlanSymbolLoader`, the gallery model and `PlanSymbolGallery` (spec P2 "Symbol libraries", "The widgets")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/plan_symbol.dart` (`PlanSymbol`)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/plan_symbol_loader.dart` (`PlanSymbolLoader`, `PlanSymbolLoad`)
- Reuse (no change): `packages/jet_cad_2d_plan/lib/src/l10n/search_fold.dart` (Task 9 ports it and its SF test; this task imports it)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/gallery_model.dart` (`PlanSymbolWords`, `PlanSymbolGroup`, `searchPlanSymbols`)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart` (port; Task 14's `plan.symbol` consumes it, and the thumbnails need it here)
- Create: `packages/jet_cad_2d_plan/lib/src/symbols/thumbnail_document.dart` (`symbolThumbnailDocument`)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/panel_focus.dart` (port; Tasks 17 and 18 import this file and do not create another)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/plan_symbol_gallery.dart` (`PlanSymbolGallery`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the loader, the thumbnails, `symbolsState`, `symbols`, `symbolById`, `retrySymbols`, `armedSymbol`, `armSymbol`; the `symbols` constructor parameter)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (exports)
- Test support: `packages/jet_cad_2d_plan/test/support/symbol_fixtures.dart` (new)
- Test: `test/symbols/plan_symbol_loader_test.dart`, `test/symbols/gallery_model_test.dart`, `test/symbols/symbol_placer_test.dart` (port), `test/controller/symbols_controller_test.dart`, `test/panels/plan_symbol_gallery_test.dart` (port + new)

(Paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root.)

**Interfaces:**
- Consumes:
  - From `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`: `PlanKit` (`id`, `symbols`, `names`), `SymbolLibrarySource` (`label`, `read`), `SymbolLibrary.decode` / `.kits` / `.entries`, `SymbolEntry` (`symbol`, `unit`, `definition`, `leaves`, `id`), `SymbolComponent` (with Task 5's `retired`), `UnitComponent`, `KitNames` (`symbolName`, `categoryName`), `registerKitComponents`, `KitDiagnostic`, `KitDiagnosticCode` (Task 4).
  - From `package:jet_cad_2d_kit/authoring.dart` (tests only): `Catalog`, `CatalogSymbol` (with Task 5's `retired`), `CatalogPolyline`, `CatalogLine`, `encodeLibrary`.
  - From `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`: `SymbolGallery`, `GalleryCategory`, `GallerySymbol`, `SymbolThumbnails`, `foregroundFor`.
  - Task 6: `KitSet` (`kits`, load order). Task 8: `PlanController` (see "Assumed"). Task 9: `PlanStrings`. Task 12: `PlanToolIds`, `PlanController.permissions`, `selectTool`.
- Produces:
  - Exported: `final class PlanSymbol` — `const PlanSymbol({required String kitId, required KitNames names, required SymbolEntry entry})`; `String get id` (`key@version`); `SymbolComponent get component`.
  - Exported: `class PlanSymbolLoader` — `PlanSymbolLoader()`; `Future<SymbolLibrary> library(SymbolLibrarySource source)`; `Future<PlanSymbolLoad> load(KitSet kits)`; `bool get isDisposed`; `void dispose()`.
  - Exported: `final class PlanSymbolLoad` — `List<PlanSymbol> symbols`, `List<KitDiagnostic> diagnostics`, `PlanSymbolsState state`.
  - Exported: `class PlanSymbolGallery extends StatefulWidget` — `const PlanSymbolGallery({Key? key, required PlanController controller, bool Function(PlanSymbol symbol)? filter, TextEditingController? query})`.
  - On `PlanController` (public): `ValueListenable<PlanSymbolsState> get symbolsState`, `List<PlanSymbol> get symbols`, `PlanSymbol? symbolById(String id)`, `Future<void> retrySymbols()`, `ValueListenable<PlanSymbol?> get armedSymbol`, `bool armSymbol(PlanSymbol symbol)`; `thumbnails` stays Task 8's.
  - Internal: `final class PlanSymbolWords`; `typedef PlanSymbolGroup = ({String kitId, String category, List<PlanSymbol> symbols})`; `String groupIdOf(PlanSymbolGroup g)`; `List<PlanSymbolGroup> searchPlanSymbols(List<PlanSymbol> symbols, String query, PlanSymbolWords words, {bool Function(PlanSymbol)? filter})`; `InstanceStyle`, `placementTransform`, `definitionForEntry`, `placeSymbol`, `isLeafEqual` (ported); `DraftDocument symbolThumbnailDocument(PlanSymbol symbol)`; `PanelFieldFocusNode`.

Plan decision (`symbolsState`): `loading` until every source has settled; then `failed` only when the kits name at least one source and **every** source failed (unreadable or refused); otherwise `ready`, with whatever loaded. Spec P2: problems are diagnostics and "the load goes on with the rest", so a partly failed set is usable and `ready`; `failed` exists for the gallery's failure state and its Retry, as today's (`symbol_panel.dart:219-224`). Kits with no source are `ready` with no symbols.

Plan decision (Retry): `retrySymbols()` acts only from `failed` (today's `retry`, `symbol_library_loader.dart:108-112`). The loader keeps a successful read and drops a failed one, so a retry reads only what failed.

Plan decision (duplicates): the first `key@N` in load order (kit order, then each kit's source order, then library order) wins; a later one is dropped with `symbolDuplicate` naming it. Across two kits the case cannot arise: decode refuses a key outside the library's kit (`jet_cad_2d_kit/lib/src/model/symbol_library.dart:229-232`, rule 5) and this loader refuses a library whose kit is not its kit, so the reachable duplicate is two sources of one kit, which today's merge refused whole (`SymbolLibrary.merge`, `symbol_library.dart:90-111`). The rule is written over all sources so the spec's cross-kit wording holds too.

Plan decision (`placeSymbol` moves here from Task 14): the gallery's thumbnails are the placer's identity output (today's `symbolThumbnailDocument`, `symbol_panel.dart:43-50`), so the port lands with the gallery. Adaptations: the copy carries the entry's whole `SymbolComponent` (its `attachTo`, `family` and `retired` too: the move resolver of Task 14 reads `attachTo` from the plan's copy), and a `UnitComponent` when the entry has one; a reused definition must carry an equal `UnitComponent` (today's `SeatingComponent` check, `symbol_placer.dart:106`); the table number (`numbered`, `:218-234`) goes to 2b with the units.

Plan decision (the search field's keys): the gallery's field stops every typed character, Undo/Redo and Escape near itself (today's `ShellShortcutGuard` over the shell's 16 letters, `shortcut_guard.dart:42-73`, and `PlannerTextKeys`' typing activator, `:118-138`), so it needs no list of the letters in use; Task 16's guard covers the other fields.

Ported (assertions unchanged; fixtures, names and imports adapted):

| Source | Tests | Destination |
|---|---|---|
| `jet_cad_floor_plan/test/l10n/l10n_test.dart:171-183` | SF | not here: Task 9 ports it in `test/l10n/l10n_test.dart` |
| `test/symbols/symbol_search_test.dart:166-189` | "a term in the key alone finds nothing", "a mixed-case tag is found in any case" | `test/symbols/gallery_model_test.dart` |
| `test/symbols/symbol_search_test.dart:269-295` | "a category that is not contiguous in the library is one group", "a category keeps its library place when its first symbol fails" | same |
| `test/l10n/symbol_words_test.dart:66-97` | SN1; SN2's `name` and `category` lines (its `nameOfKey`/`merge` lines are `KitNames`' own, tested in `jet_cad_2d_kit/test/model/kit_names_test.dart`) | same |
| `test/symbols/symbol_placer_test.dart` (whole file) | every test | `test/symbols/symbol_placer_test.dart` |
| `test/symbols/symbol_section_test.dart:284-300` | SS9 (Task 17 sent it here: it asserts `definitionForEntry`, this task's port); the shuffled entry is the kit's `SymbolEntry` built from a fixture entry with its `leaves` reversed (the kit's `SymbolEntry` fields in place of `seats`) | `test/symbols/symbol_placer_test.dart` |
| `test/symbols/symbol_panel_test.dart:230-502, 534-637` | the fixture test; states (2); search (2); the search controller (4); the field and the keys (5); the gallery: "a tap reports the entry…", "the cells are the entries…", "the thumbnail document…" | `test/panels/plan_symbol_gallery_test.dart` |

Departure (fixture keys, A12-allowed): in the ported `symbol_search_test.dart` cases the fixture keys gain the kit prefix the kit format requires (`chair.wingback` → `fixture.chair.wingback`), so the expected ids and the one key query follow (`'chair.wingback@1'` → `'fixture.chair.wingback@1'`, `searchSymbols(entries, 'chair.wingback')` → `searchPlanSymbols(entries, 'fixture.chair.wingback', en)`); no other literal changes, and every matcher is the source's.

Not ported here: `symbol_search_test.dart:82-164, 191-267` (they pin the furniture asset's 41 symbols; the asset moves with the furniture kit, sub-project 3) — new GM tests cover each field and rule on the fixture; `symbol_panel_test.dart:505-532` (the highlight needs `plan.symbol`: Task 14 ports it); `symbol_sources_test.dart` LS2 and LS3 (their rule changed: one failing source no longer fails the load, a duplicate is dropped, spec P2) — replaced by S-4 and S-2; LS5 (the furniture default) — gone; `symbol_words_test.dart` SN3 (the Symbol section, Task 17), SN4 (the collapsed category across languages: GM-9 pins the language-independent group id, and `SymbolGallery` keys its collapsed set by that id, `symbol_gallery.dart:32-41, 134-141`).

- [ ] **Step 1: The fixtures.** Create `test/support/symbol_fixtures.dart`. Part one ports `jet_cad_floor_plan/test/support/symbol_fixtures.dart:1-133` to the kit's format (a `LibraryComponent` on the root, every key under the kit `fixture`, `registerKitComponents`); part two builds the gallery's and the loader's libraries through the authoring toolkit.

```dart
// Symbol fixtures for the plan library (Task 13).
//
// Part one: the 09a fixture library of jet_cad_floor_plan's
// test/support/symbol_fixtures.dart (lines 1-133), in the kit format: a
// LibraryComponent on the root and every key under the kit "fixture".
// Non-degenerate as before: every base point and leaf off the origin,
// versions 3, 2 and 1, three tags each, definition handles far apart, the
// leaves inserted out of handle order.
//
// Part two: the gallery's library (kit "demo", one retired symbol, words in
// Turkish) and small per-kit libraries for the loader, built with the
// authoring toolkit's encodeLibrary.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogLine, CatalogPolyline, CatalogSymbol, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// ---- part one ----

const Handle sofaDef = Handle(4200);
const Handle nightstandDef = Handle(4300);
const Handle armchairDef = Handle(4400);

const int sofaLine = 4210,
    sofaPolyline = 4211,
    sofaArc = 4212,
    sofaCircle = 4213;
const int nightstandRect = 4310, nightstandLine = 4311;
const int armchairCircle = 4410, armchairArc = 4411;

SymbolComponent sofaSymbol() => SymbolComponent(
    key: 'fixture.sofa.three',
    name: 'Three-seat sofa',
    category: 'Living Room',
    tags: const ['sofa', 'seating', 'couch'],
    version: 3);

SymbolComponent nightstandSymbol() => SymbolComponent(
    key: 'fixture.nightstand.single',
    name: 'Nightstand',
    category: 'Bed Room',
    tags: const ['nightstand', 'bedside', 'table'],
    version: 2);

SymbolComponent armchairSymbol() => SymbolComponent(
    key: 'fixture.armchair.single',
    name: 'Armchair',
    category: 'Living Room',
    tags: const ['armchair', 'seating', 'chair'],
    version: 1);

EntityRecord leafRecord(int handle, Handle owner, EntityKind kind) =>
    EntityRecord(
      handle: Handle(handle),
      owner: owner,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    );

/// The leaves in their insertion (file) order: not ascending by handle,
/// the symbols interleaved.
List<SymbolLeaf> fixtureLeaves() => [
      (
        record: leafRecord(sofaCircle, sofaDef, EntityKind.circle),
        payload: circlePayload(Vector2(1500, 620), 45),
      ),
      (
        record: leafRecord(nightstandRect, nightstandDef, EntityKind.polyline),
        payload: polylinePayload([
          Vector2(50, 60),
          Vector2(450, 60),
          Vector2(450, 410),
          Vector2(50, 410),
        ], closed: true),
      ),
      (
        record: leafRecord(sofaLine, sofaDef, EntityKind.line),
        payload: linePayload(Vector2(120, 340), Vector2(1680, 340)),
      ),
      (
        record: leafRecord(armchairArc, armchairDef, EntityKind.arc),
        payload: arcPayload(Vector2(500, 500), 300, 0.25, 2.5),
      ),
      (
        record: leafRecord(sofaArc, sofaDef, EntityKind.arc),
        payload: arcPayload(Vector2(900, 900), 250, 0.5, 1.75),
      ),
      (
        record: leafRecord(nightstandLine, nightstandDef, EntityKind.line),
        payload: linePayload(Vector2(70, 230), Vector2(430, 230)),
      ),
      (
        record: leafRecord(sofaPolyline, sofaDef, EntityKind.polyline),
        payload: polylinePayload(
            [Vector2(120, 340), Vector2(120, 900), Vector2(400, 950)]),
      ),
      (
        record: leafRecord(armchairCircle, armchairDef, EntityKind.circle),
        payload: circlePayload(Vector2(510, 480), 120),
      ),
    ];

/// The valid library: kit "fixture", three symbols, two categories.
DraftDocument buildValidLibrary() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  Definition def(Handle h, String name, double x, double y) =>
      Definition(handle: h, name: name, basePoint: Vector2(x, y), children: []);
  doc.commands.execute(CompoundCommand([
    SetComponentCommand<LibraryComponent>(
        doc.rootHandle, LibraryComponent(kit: 'fixture')),
    AddDefinitionCommand(
        def(armchairDef, 'fixture.armchair.single@1', 510, 0)),
    AddDefinitionCommand(def(sofaDef, 'fixture.sofa.three@3', 900, 400)),
    AddDefinitionCommand(
        def(nightstandDef, 'fixture.nightstand.single@2', 250, 60)),
    SetComponentCommand<SymbolComponent>(sofaDef, sofaSymbol()),
    SetComponentCommand<SymbolComponent>(nightstandDef, nightstandSymbol()),
    SetComponentCommand<SymbolComponent>(armchairDef, armchairSymbol()),
    for (final l in fixtureLeaves())
      AddEntityCommand(record: l.record, payload: l.payload),
  ], label: 'Fixture library'));
  doc.commands.clearHistory();
  return doc;
}

Uint8List bytesOf(DraftDocument doc) =>
    Uint8List.fromList(utf8.encode(DraftDocumentCodec.encodeToString(doc)));

// ---- part two ----

/// A symbol drawn as a closed outline and a middle line, its base point
/// off the origin.
CatalogSymbol box(String key, String name, String category, List<String> tags,
        {int version = 1,
        bool retired = false,
        List<String> attachTo = const [],
        (double, double) base = (950, 410)}) =>
    CatalogSymbol(
      key: key,
      version: version,
      name: name,
      category: category,
      tags: tags,
      attachTo: attachTo,
      retired: retired,
      base: base,
      shapes: const [
        CatalogPolyline([(150, 210), (1750, 210), (1750, 960), (150, 960)],
            closed: true),
        CatalogLine((150, 585), (1750, 585)),
      ],
    );

/// The gallery's library, in library order. `bed` matches the Bed Room
/// symbols only (a name, a tag or the category); `demo.chair.old` is
/// retired.
final Catalog demoCatalog = Catalog(kit: 'demo', symbols: [
  box('demo.bed.double', 'Double bed', 'Bed Room', ['bed', 'sleep'],
      base: (980.5, 640.25)),
  box('demo.bed.single', 'Single bed', 'Bed Room', ['bed'],
      base: (720.25, 515.5)),
  box('demo.bed.night', 'Nightstand', 'Bed Room', ['bedside'],
      base: (402.75, 233.5)),
  box('demo.sofa.three', 'Three-seat sofa', 'Living Room', ['sofa', 'couch'],
      base: (1100.5, 480.75)),
  box('demo.sofa.two', 'Two-seat sofa', 'Living Room', ['sofa', 'couch'],
      base: (860.25, 470.5)),
  box('demo.chair.old', 'Old chair', 'Living Room', ['chair'],
      retired: true, base: (512.5, 301.25)),
  box('demo.desk.office', 'Office desk', 'Office', ['desk', 'work'],
      base: (1203.75, 655.5)),
]);

/// The demo kit's Turkish words; no German (the English fallback).
const KitNames demoNames = KitNames({
  'tr': {
    'symbol:demo.bed.double': 'Çift kişilik yatak',
    'symbol:demo.sofa.three': 'Üçlü kanepe',
    'category:demo/Bed Room': 'Yatak odası',
    'category:demo/Living Room': 'Oturma odası',
  },
});

Uint8List demoBytes() => encodeLibrary(demoCatalog);

/// The visible (not retired) demo symbols' ids, in library order.
List<String> demoVisibleIds() => [
      for (final s in demoCatalog.symbols)
        if (!s.retired) s.id,
    ];

/// A library of kit [kit] holding `<kit>.item.<name>` for each of [names]
/// at [version].
Uint8List itemsBytes(String kit, List<String> names, {int version = 1}) =>
    encodeLibrary(Catalog(kit: kit, symbols: [
      for (final (i, n) in names.indexed)
        box('$kit.item.$n', 'Item $n', 'Things', [n],
            version: version, base: (300.5 + 100 * i, 220.25 + 50 * i)),
    ]));

/// A source whose reads are counted and whose bytes come from [read].
final class CountingSource {
  CountingSource(String label, Future<Uint8List> Function() read) {
    source = SymbolLibrarySource(
        label: label,
        read: () {
          reads++;
          return read();
        });
  }

  late final SymbolLibrarySource source;
  int reads = 0;
}

/// A kit of symbols only.
PlanKit symbolKit(String id, List<SymbolLibrarySource> sources,
        {KitNames names = KitNames.empty}) =>
    PlanKit(id: id, version: '1.0.0', symbols: sources, names: names);

/// The demo kit, read through [source] (a counting one by default).
PlanKit demoKit({SymbolLibrarySource? source}) => symbolKit(
    'demo', [source ?? SymbolLibrarySource(label: 'demo', read: () async => demoBytes())],
    names: demoNames);

/// The ids of [symbols].
List<String> idsOf(Iterable<PlanSymbol> symbols) =>
    [for (final s in symbols) s.id];

/// Lets every pending read and decode of a loader finish (plain tests).
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
```

- [ ] **Step 2: Write the failing loader tests.** Create `test/symbols/plan_symbol_loader_test.dart`:

```dart
// Spec P2 "Symbol libraries" (Task 13): the loader reads every kit's
// sources, decodes, refuses a library under another kit, drops a repeated
// key@N, skips an unreadable library, and caches each source's read. Every
// problem is a KitDiagnostic, and the load goes on with the rest.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/symbol_fixtures.dart';

PlanSymbolLoader loader() {
  final l = PlanSymbolLoader();
  addTearDown(l.dispose);
  return l;
}

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanSymbolLoad load) => [
      for (final d in load.diagnostics) (d.kitId, d.subject, d.code),
    ];

void main() {
  test(
      'S-1 every kit\'s libraries in kit order, then source order, then '
      'library order; each symbol knows its kit and words', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one', 'two'])),
      SymbolLibrarySource(
          label: 'a2', read: () async => itemsBytes('alpha', ['three'])),
    ]);
    final beta = symbolKit('beta', [
      SymbolLibrarySource(
          label: 'b1', read: () async => itemsBytes('beta', ['four'])),
    ], names: const KitNames({
      'tr': {'symbol:beta.item.four': 'Dört'},
    }));
    final load = await loader().load(validateKitSet([beta, alpha]));
    expect(idsOf(load.symbols), [
      'beta.item.four@1',
      'alpha.item.one@1',
      'alpha.item.two@1',
      'alpha.item.three@1',
    ]);
    expect([for (final s in load.symbols) s.kitId],
        ['beta', 'alpha', 'alpha', 'alpha']);
    expect(load.symbols.first.names, same(beta.names));
    expect(load.symbols.first.component.key, 'beta.item.four');
    expect(load.diagnostics, isEmpty);
    expect(load.state, PlanSymbolsState.ready);
    expect(() => load.symbols.add(load.symbols.first), throwsUnsupportedError);
  });

  test(
      'S-2 a key@N given again by a later source is dropped from it, one '
      'symbolDuplicate naming it; the rest of that library stays', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one', 'two'])),
      SymbolLibrarySource(
          label: 'a2',
          read: () async => itemsBytes('alpha', ['two', 'three'])),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    // M-S2: the `given` check dropped.
    expect(idsOf(load.symbols),
        ['alpha.item.one@1', 'alpha.item.two@1', 'alpha.item.three@1']);
    expect(problemsOf(load),
        [('alpha', 'alpha.item.two@1', KitDiagnosticCode.symbolDuplicate)]);
    expect(load.symbols[1].entry.definition.basePoint.x, 400.5,
        reason: 'the first source\'s two, not the second\'s (at 300.5)');
    expect(load.state, PlanSymbolsState.ready);
  });

  test('S-3 the same key at another version is a different symbol (LS4)',
      () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'a1', read: () async => itemsBytes('alpha', ['one'])),
      SymbolLibrarySource(
          label: 'a2',
          read: () async => itemsBytes('alpha', ['one'], version: 2)),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    expect(idsOf(load.symbols), ['alpha.item.one@1', 'alpha.item.one@2']);
    expect(load.diagnostics, isEmpty);
  });

  test(
      'S-4 a library under another kit is refused whole, one '
      'libraryKitMismatch; the kit\'s other library loads', () async {
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(
          label: 'wrong', read: () async => itemsBytes('beta', ['four'])),
      SymbolLibrarySource(
          label: 'right', read: () async => itemsBytes('alpha', ['one'])),
    ]);
    final load = await loader().load(validateKitSet([alpha]));
    // M-S4: the kit check dropped.
    expect(idsOf(load.symbols), ['alpha.item.one@1']);
    expect(problemsOf(load),
        [('alpha', 'wrong', KitDiagnosticCode.libraryKitMismatch)]);
    expect(load.state, PlanSymbolsState.ready);
  });

  test(
      'S-5 an unreadable library (a throwing read, bytes that do not '
      'decode) is skipped, one libraryUnreadable each, its error kept',
      () async {
    final boom = StateError('no asset here');
    final alpha = symbolKit('alpha', [
      SymbolLibrarySource(label: 'throws', read: () async => throw boom),
      SymbolLibrarySource(
          label: 'garbage',
          read: () async => Uint8List.fromList([0x7b, 0x7b, 0x7b])),
      SymbolLibrarySource(
          label: 'good', read: () async => itemsBytes('alpha', ['one'])),
    ]);
    // M-S5: the read's catch rethrows (the load throws).
    final load = await loader().load(validateKitSet([alpha]));
    expect(idsOf(load.symbols), ['alpha.item.one@1']);
    expect(problemsOf(load), [
      ('alpha', 'throws', KitDiagnosticCode.libraryUnreadable),
      ('alpha', 'garbage', KitDiagnosticCode.libraryUnreadable),
    ]);
    expect(load.diagnostics.first.error, same(boom));
    expect(load.diagnostics.last.error, isA<SymbolLibraryError>());
  });

  test(
      'S-6 the state: no source is ready and empty; every source failed is '
      'failed; one loaded is ready', () async {
    final none = await loader().load(validateKitSet([symbolKit('alpha', [])]));
    expect(none.state, PlanSymbolsState.ready);
    expect(none.symbols, isEmpty);
    final bad = SymbolLibrarySource(
        label: 'bad', read: () async => throw StateError('gone'));
    final all = await loader().load(validateKitSet([
      symbolKit('alpha', [bad]),
      symbolKit('beta', [
        SymbolLibrarySource(
            label: 'mismatch', read: () async => itemsBytes('alpha', ['x'])),
      ]),
    ]));
    expect(all.state, PlanSymbolsState.failed);
    // M-S6: `failed == total` written `failed > 0`.
    final one = await loader().load(validateKitSet([
      symbolKit('alpha', [
        bad,
        SymbolLibrarySource(
            label: 'ok', read: () async => itemsBytes('alpha', ['one'])),
      ]),
    ]));
    expect(one.state, PlanSymbolsState.ready);
  });

  test(
      'S-7 a source is read once across loads and kit sets; a failed read '
      'is not kept, so the next load reads it again', () async {
    final good = CountingSource('good', () async => itemsBytes('alpha', ['a']));
    var fail = true;
    final flaky = CountingSource('flaky', () async {
      if (fail) throw StateError('not yet');
      return itemsBytes('beta', ['b']);
    });
    final l = loader();
    final kits = validateKitSet([
      symbolKit('alpha', [good.source]),
      symbolKit('beta', [flaky.source]),
    ]);
    final first = await l.load(kits);
    expect(idsOf(first.symbols), ['alpha.item.a@1']);
    // Another kit set over the same sources.
    final again = await l.load(validateKitSet([
      symbolKit('beta', [flaky.source]),
      symbolKit('alpha', [good.source]),
    ]));
    await settle();
    // M-S7a: the cache dropped (good is read again).
    expect(good.reads, 1);
    expect(idsOf(again.symbols), ['alpha.item.a@1']);
    fail = false;
    final third = await l.load(kits);
    // M-S7b: the eviction of a failed read dropped (flaky stays failed).
    expect(idsOf(third.symbols), ['alpha.item.a@1', 'beta.item.b@1']);
    expect(flaky.reads, 3);
  });

  test('S-8 a disposed loader refuses to load', () async {
    final l = PlanSymbolLoader();
    expect(l.isDisposed, isFalse);
    l.dispose();
    expect(l.isDisposed, isTrue);
    expect(() => l.load(validateKitSet([symbolKit('alpha', [])])),
        throwsStateError);
  });
}
```

(`validateKitSet` is Task 6's; it accepts kits of symbols only.)

- [ ] **Step 3: Write the failing gallery-model tests.** (The search fold and its SF test are Task 9's, `lib/src/l10n/search_fold.dart` and `test/l10n/l10n_test.dart`.) Create `test/symbols/gallery_model_test.dart`:

```dart
// Spec P2 "PlanSymbolGallery" (Task 13): the gallery's model. Search over
// the shown names, the shown categories, the stored English and the tags,
// folded; groups by kit and category in first-appearance order; retired
// symbols hidden (R2); an optional filter. Ported tests keep their
// assertions (only the fixture keys gained a kit id); GM tests are new.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show Catalog, CatalogPolyline, CatalogSymbol, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/gallery_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

String idOf(PlanSymbol s) => s.id;

List<String> ids(List<PlanSymbolGroup> groups) =>
    [for (final g in groups) ...g.symbols.map(idOf)];

List<String> categoriesOf(List<PlanSymbolGroup> groups) =>
    [for (final g in groups) g.category];

/// The fields of [s] that contain the lower-case [term], computed here
/// independently of the code under test (symbol_search_test.dart:39-44);
/// the key is listed although the search ignores it.
Set<String> fieldsHit(PlanSymbol s, String term) {
  final c = s.component;
  return {
    if (c.key.toLowerCase().contains(term)) 'key',
    if (c.name.toLowerCase().contains(term)) 'name',
    if (c.tags.any((t) => t.toLowerCase().contains(term))) 'tag',
    if (c.category.toLowerCase().contains(term)) 'category',
  };
}

/// Proves that [term] hits [field] alone over all of [symbols], and returns
/// the ids of the symbols it hits (symbol_search_test.dart:48-59).
List<String> hitsOnly(List<PlanSymbol> symbols, String term, String field) {
  final hit = <String>[];
  for (final s in symbols) {
    final fields = fieldsHit(s, term);
    expect(fields.difference({field}), isEmpty,
        reason: '"$term" must hit only the $field of ${idOf(s)}, '
            'it hits $fields');
    if (fields.isNotEmpty) hit.add(idOf(s));
  }
  expect(hit, isNotEmpty, reason: '"$term" must hit some $field');
  return hit;
}

/// A symbol with no leaves: the search reads its identity only.
PlanSymbol entry(int handle, String key, String name, String category,
        List<String> tags,
        {String kit = 'fixture', KitNames names = KitNames.empty}) =>
    PlanSymbol(
      kitId: kit,
      names: names,
      entry: SymbolEntry(
        symbol: SymbolComponent(
            key: key, version: 1, name: name, category: category, tags: tags),
        unit: null,
        definition: Definition(
            handle: Handle(handle),
            name: '$key@1',
            basePoint: Vector2(130.0 + handle, 70.0 - handle),
            children: const []),
        leaves: const [],
      ),
    );

/// [bytes]' library as plan symbols of [kit].
List<PlanSymbol> symbolsOf(String kit, Uint8List bytes,
        {KitNames names = KitNames.empty}) =>
    [
      for (final e in SymbolLibrary.decode(bytes).entries)
        PlanSymbol(kitId: kit, names: names, entry: e),
    ];

/// symbol_words_test.dart's catalog: keys gained a second segment where
/// they had one (`t.heater` → `t.heater.patio`, `t.unnamed` →
/// `t.unnamed.crate`), as K2 requires.
CatalogSymbol rect(String key, String name, String category,
        {List<String> tags = const []}) =>
    CatalogSymbol(
      key: key,
      name: name,
      category: category,
      tags: tags,
      base: (450, 300),
      shapes: const [
        CatalogPolyline([(0, 0), (900, 0), (900, 600), (0, 600)],
            closed: true),
      ],
    );

const KitNames tNames = KitNames({
  'tr': {
    'symbol:t.booth.corner': 'Köşe loca',
    'symbol:t.heater.patio': 'Dış mekân ısıtıcısı',
    'category:t/Booths': 'Localar',
    'category:t/Outdoor': 'Dış mekân',
  },
  'de': {
    'symbol:t.booth.corner': 'Ecksitznische',
    'symbol:t.heater.patio': 'Heizstrahler',
  },
});

final List<PlanSymbol> tSymbols = symbolsOf(
    't',
    encodeLibrary(Catalog(kit: 't', symbols: [
      rect('t.booth.corner', 'Corner booth', 'Booths', tags: ['booth']),
      rect('t.heater.patio', 'Patio heater', 'Outdoor'),
      rect('t.unnamed.crate', 'Plain crate', 'Outdoor'),
    ])),
    names: tNames);

List<String> keysFound(String query, PlanSymbolWords words) => [
      for (final g in searchPlanSymbols(tSymbols, query, words))
        for (final s in g.symbols) s.component.key
    ];

final List<PlanSymbol> demo =
    symbolsOf('demo', demoBytes(), names: demoNames);

void main() {
  group('ported from symbol_search_test.dart', () {
    // "wing" is in the key only; "Reading" is a mixed-case tag.
    final entries = [
      entry(9500, 'fixture.lamp.arc', 'Arc lamp', 'Den', ['lamp', 'light']),
      entry(9600, 'fixture.chair.wingback', 'Armchair', 'Den',
          ['Reading', 'seat']),
    ];
    const en = PlanSymbolWords.english;

    test('a term in the key alone finds nothing', () {
      expect(hitsOnly(entries, 'wing', 'key'), ['fixture.chair.wingback@1']);
      expect(searchPlanSymbols(entries, 'wing', en), isEmpty);
      expect(searchPlanSymbols(entries, 'fixture.chair.wingback', en),
          isEmpty);
      // The symbol itself is searchable: its name finds it.
      expect(ids(searchPlanSymbols(entries, 'armchair', en)),
          ['fixture.chair.wingback@1']);
    });

    test('a mixed-case tag is found in any case', () {
      expect(hitsOnly(entries, 'reading', 'tag'), ['fixture.chair.wingback@1']);
      expect(entries[1].component.tags.first, 'Reading');
      for (final query in ['reading', 'READING', 'rEaDiNg']) {
        expect(ids(searchPlanSymbols(entries, query, en)),
            ['fixture.chair.wingback@1'],
            reason: query);
      }
    });

    test('a category that is not contiguous in the library is one group', () {
      // The 09a fixture: sofa (Living Room), nightstand (Bed Room),
      // armchair (Living Room), in definition-handle order.
      final fixture = symbolsOf('fixture', bytesOf(buildValidLibrary()));
      expect(fixture.map(idOf).toList(), [
        'fixture.sofa.three@3',
        'fixture.nightstand.single@2',
        'fixture.armchair.single@1'
      ]);
      final all = searchPlanSymbols(fixture, '', en);
      expect(categoriesOf(all), ['Living Room', 'Bed Room']);
      expect(all.map((g) => g.symbols.map(idOf).toList()).toList(), [
        ['fixture.sofa.three@3', 'fixture.armchair.single@1'],
        ['fixture.nightstand.single@2'],
      ]);
      expect(ids(searchPlanSymbols(fixture, 'seating', en)),
          ['fixture.sofa.three@3', 'fixture.armchair.single@1']);
    });

    test('a category keeps its library place when its first symbol fails',
        () {
      final entries = [
        entry(9100, 'fixture.desk.corner', 'Corner desk', 'Study',
            ['desk', 'work']),
        entry(9200, 'fixture.lamp.floor', 'Floor lamp', 'Lounge',
            ['lamp', 'light']),
        entry(9300, 'fixture.lamp.desk', 'Desk lamp', 'Study',
            ['lamp', 'work']),
      ];
      final found = searchPlanSymbols(entries, 'lamp', en);
      expect(categoriesOf(found), ['Study', 'Lounge']);
      expect(ids(found), ['fixture.lamp.desk@1', 'fixture.lamp.floor@1']);
    });
  });

  group('ported from symbol_words_test.dart', () {
    test('SN1 search meets either language through the fold (L11, M-14d-j)',
        () {
      const tr = PlanSymbolWords('tr');
      expect(keysFound('kose', tr), ['t.booth.corner']);
      expect(keysFound('KÖŞE LOCA', tr), ['t.booth.corner']);
      expect(keysFound('booth', tr), ['t.booth.corner'], reason: 'a tag');
      expect(keysFound('corner', tr), ['t.booth.corner'],
          reason: 'the English name, in no tag');
      expect(keysFound('ISITICI', tr), ['t.heater.patio']);
      expect(keysFound('dis mekan', tr), ['t.heater.patio', 't.unnamed.crate'],
          reason: 'the category in Turkish');
      expect(keysFound('heizstrahler', tr), isEmpty,
          reason: 'German is not the shown language');
      const de = PlanSymbolWords('de');
      expect(keysFound('heizstrahler', de), ['t.heater.patio']);
      final groups = searchPlanSymbols(tSymbols, '', tr);
      expect([for (final g in groups) g.category], ['Booths', 'Outdoor'],
          reason: 'groups keep the English category as their key');
    });

    test('SN2 the words fall back to the library\'s English (L9)', () {
      const tr = PlanSymbolWords('tr');
      final crate =
          tSymbols.singleWhere((s) => s.component.key == 't.unnamed.crate');
      expect(tr.name(crate), 'Plain crate');
      final unknown = entry(9700, 't.x.y', 'X', 'Unknown', const [],
          kit: 't', names: tNames);
      expect(tr.category(unknown), 'Unknown');
    });
  });

  group('the gallery model (new)', () {
    const en = PlanSymbolWords.english;

    test('GM-1 an empty or blank query: every visible symbol, in order', () {
      for (final q in ['', ' ', ' \t\n  ']) {
        expect(ids(searchPlanSymbols(demo, q, en)), demoVisibleIds(),
            reason: '"$q"');
      }
    });

    test('GM-2 a retired symbol is hidden, whatever the query (R2)', () {
      expect(demo.map(idOf), contains('demo.chair.old@1'),
          reason: 'premise: loaded');
      // M-GM2: the retired filter dropped.
      expect(ids(searchPlanSymbols(demo, '', en)),
          isNot(contains('demo.chair.old@1')));
      expect(ids(searchPlanSymbols(demo, 'old chair', en)), isEmpty);
    });

    test(
        'GM-3 each stored field finds alone, shown in another language: the '
        'English name, a tag, the English category', () {
      // In Turkish the sofas show "Üçlü kanepe" and "Oturma odası", so only
      // the stored English can match these terms.
      const tr = PlanSymbolWords('tr');
      // M-GM3a: the stored name dropped from the texts.
      expect(ids(searchPlanSymbols(demo, 'three-seat', tr)),
          ['demo.sofa.three@1']);
      // M-GM3b: the tags dropped.
      expect(ids(searchPlanSymbols(demo, 'couch', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
      // M-GM3c: the stored category dropped.
      expect(ids(searchPlanSymbols(demo, 'living', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
    });

    test('GM-4 the shown words: the locale\'s name and category find it', () {
      const tr = PlanSymbolWords('tr');
      // M-GM4a: the shown name dropped from the texts.
      expect(ids(searchPlanSymbols(demo, 'kanepe', tr)),
          ['demo.sofa.three@1']);
      // M-GM4b: the shown category dropped.
      expect(ids(searchPlanSymbols(demo, 'oturma', tr)),
          ['demo.sofa.three@1', 'demo.sofa.two@1']);
      expect(ids(searchPlanSymbols(demo, 'kanepe', en)), isEmpty);
    });

    test('GM-5 every term is required, across fields; white space splits', () {
      expect(ids(searchPlanSymbols(demo, 'sofa three', en)),
          ['demo.sofa.three@1']);
      expect(ids(searchPlanSymbols(demo, '\tsofa \n  three\t', en)),
          ['demo.sofa.three@1']);
      // M-GM5: `every` written `any`.
      expect(ids(searchPlanSymbols(demo, 'couch office', en)), isEmpty);
      expect(ids(searchPlanSymbols(demo, 'BED', en)),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
    });

    test('GM-6 the filter runs before the search', () {
      bool beds(PlanSymbol s) => s.component.key.startsWith('demo.bed.');
      expect(ids(searchPlanSymbols(demo, '', en, filter: beds)),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
      // M-GM6: the filter ignored.
      expect(searchPlanSymbols(demo, 'sofa', en, filter: beds), isEmpty);
    });

    test('GM-7 two kits with one category name are two groups', () {
      final mixed = [
        entry(9100, 'alpha.bar.stool', 'Stool', 'Bar', ['stool'],
            kit: 'alpha'),
        entry(9200, 'beta.bar.stool', 'Stool', 'Bar', ['stool'], kit: 'beta'),
        entry(9300, 'alpha.bar.tap', 'Tap', 'Bar', ['tap'], kit: 'alpha'),
      ];
      final groups = searchPlanSymbols(mixed, '', en);
      // M-GM7: groups keyed by the category alone.
      expect([for (final g in groups) (g.kitId, g.category)],
          [('alpha', 'Bar'), ('beta', 'Bar')]);
      expect(groups.map((g) => g.symbols.map(idOf).toList()).toList(), [
        ['alpha.bar.stool@1', 'alpha.bar.tap@1'],
        ['beta.bar.stool@1'],
      ]);
      expect([for (final g in groups) groupIdOf(g)], ['alpha/Bar', 'beta/Bar']);
    });

    test(
        'GM-8 the words: the locale\'s, else English\'s, else the stored '
        'text', () {
      const tr = PlanSymbolWords('tr');
      final bed = demo.singleWhere((s) => s.id == 'demo.bed.double@1');
      final desk = demo.singleWhere((s) => s.id == 'demo.desk.office@1');
      expect(tr.name(bed), 'Çift kişilik yatak');
      expect(tr.category(bed), 'Yatak odası');
      expect(tr.name(desk), 'Office desk');
      expect(tr.category(desk), 'Office');
      const de = PlanSymbolWords('de');
      expect(de.name(bed), 'Double bed', reason: 'no German: the fallback');
    });

    test('GM-9 a group\'s id is the same in every language', () {
      final en = searchPlanSymbols(demo, '', PlanSymbolWords.english);
      final tr = searchPlanSymbols(demo, '', const PlanSymbolWords('tr'));
      expect([for (final g in tr) groupIdOf(g)],
          [for (final g in en) groupIdOf(g)]);
      expect([for (final g in en) groupIdOf(g)],
          ['demo/Bed Room', 'demo/Living Room', 'demo/Office']);
    });
  });
}
```

(SN2's `tr.category('Unknown')` asked by category name; the model asks by symbol, so the unknown category is a symbol's, `unknown` above.)

- [ ] **Step 4: Port the placer tests.** Copy `jet_cad_floor_plan/test/symbols/symbol_placer_test.dart` (all of it, lines 1-1388) to `test/symbols/symbol_placer_test.dart`. Assertions unchanged. Adaptations, each applied everywhere it occurs:
  1. Imports: replace the four `package:jet_cad_floor_plan/...` imports with `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (for `SymbolComponent`, `SymbolEntry`, `SymbolLibrary`, `registerKitComponents`) and `package:jet_cad_2d_plan/src/symbols/symbol_placer.dart`; `../support/symbol_fixtures.dart` stays (Step 1's port).
  2. `registerAppComponents` → `registerKitComponents` (`target()`, line 43; `reload`, line 91).
  3. A `SymbolEntry`'s fields: `e.key` → `e.symbol.key`, `e.name` → `e.symbol.name`, `e.category` → `e.symbol.category`, `e.tags` → `e.symbol.tags`, `e.version` → `e.symbol.version` (only where `e` is a `SymbolEntry`; a `SymbolComponent`'s own fields keep their names).
  4. Every `SymbolEntry(key: …, name: …, category: …, tags: …, version: …, definition: …, leaves: …)` construction (`withVersion` at 29-38, `styledSofa` at 113-160, and any in the leaf-equal group from 962) becomes `SymbolEntry(symbol: SymbolComponent(key: …, version: …, name: …, category: …, tags: …), unit: e.unit, definition: …, leaves: …)` with the same values.
  5. Key literals: every symbol key `'X'` of the fixture becomes `'fixture.X'` (and a definition name `'X@n'` or `'X@n#k'` becomes `'fixture.X@n'` / `'fixture.X@n#k'`); `entryOf('sofa.three')` → `entryOf('fixture.sofa.three')`.
  6. The table number is gone from `placeSymbol` (2b): if a test passes `numbered:`, drop the argument (the fixture's symbols are no units, so no test of this file depends on it).
  A test whose assertion fails after these adaptations is a finding: stop and report it (Global Constraints).

- [ ] **Step 5: Write the failing controller tests.** Create `test/controller/symbols_controller_test.dart`:

```dart
// Spec P2 "Symbol libraries" at the controller (Task 13): the load starts
// with the controller and never blocks editing; its problems reach the
// diagnostics; a shared loader and thumbnail cache are never disposed by a
// controller, its own are; retry; arming. Review Focus 5: S-late-fail.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';
import '../support/tool_events.dart';

final class SpyThumbnails extends SymbolThumbnails {
  int disposals = 0;

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

PlanController make(List<PlanKit> kits,
    {PlanSymbolLoader? symbols, SymbolThumbnails? thumbnails}) {
  final c = PlanController(
      kits: kits, symbols: symbols, thumbnails: thumbnails);
  addTearDown(c.dispose);
  return c;
}

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanController c) => [
      for (final d in c.diagnostics.value) (d.kitId, d.subject, d.code),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'S-9 the load starts with the controller: loading, then ready with the '
      'symbols; its diagnostics reach the controller', () async {
    final c = make([
      demoKit(),
      symbolKit('beta', [
        SymbolLibrarySource(
            label: 'broken', read: () async => throw StateError('no file')),
      ]),
    ]);
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    expect(c.symbols, isEmpty);
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(idsOf(c.symbols), [for (final s in demoCatalog.symbols) s.id],
        reason: 'retired symbols load; the gallery hides them');
    // M-S9: the load's diagnostics not added to the controller's log.
    expect(problemsOf(c),
        [('beta', 'broken', KitDiagnosticCode.libraryUnreadable)]);
    expect(c.symbolById('demo.sofa.two@1')!.component.name, 'Two-seat sofa');
    expect(c.symbolById('demo.sofa.two@9'), isNull);
  });

  test(
      'S-10 S-late-fail: libraries that finish after drawing began, one '
      'failing: the drawing goes on, the rest fills in, one diagnostic, no '
      'symbol of the failed library (Review Focus 5)', () async {
    final alphaRead = Completer<Uint8List>();
    final betaRead = Completer<Uint8List>();
    final c = make([
      symbolKit('alpha',
          [SymbolLibrarySource(label: 'alpha', read: () => alphaRead.future)]),
      symbolKit('beta',
          [SymbolLibrarySource(label: 'beta', read: () => betaRead.future)]),
    ]);
    useTestCamera(c);
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    final line =
        drawLine(c, Vector2(4120.5, -1415.25), Vector2(4730.75, -1102.5));
    final state = c.document.commands.stateId;
    final depth = c.document.commands.undoDepth;
    expect(depth, greaterThan(0), reason: 'premise: drawn while loading');

    alphaRead.complete(itemsBytes('alpha', ['one', 'two']));
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.loading,
        reason: 'beta has not settled');
    betaRead.completeError(StateError('beta asset missing'));
    await settle();

    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(idsOf(c.symbols), ['alpha.item.one@1', 'alpha.item.two@1']);
    expect(c.symbols.where((s) => s.kitId == 'beta'), isEmpty);
    expect(problemsOf(c),
        [('beta', 'beta', KitDiagnosticCode.libraryUnreadable)]);
    expect(linesOf(c.document), contains(line));
    expect(c.document.commands.stateId, state);
    expect(c.document.commands.undoDepth, depth);
    expect(c.activeTool.value, 'plan.select');
    // The drawing goes on.
    final next =
        drawLine(c, Vector2(5010.25, -990.5), Vector2(5600.75, -1250.25));
    expect(linesOf(c.document), containsAll([line, next]));
  });

  test(
      'S-11 a shared loader and cache are not disposed by the controller; '
      'its own are', () async {
    final shared = PlanSymbolLoader();
    addTearDown(shared.dispose);
    final thumbs = SpyThumbnails();
    addTearDown(thumbs.dispose);
    final read = CountingSource('demo', () async => demoBytes());
    final one = PlanController(
        kits: [demoKit(source: read.source)],
        symbols: shared,
        thumbnails: thumbs);
    await settle();
    one.dispose();
    // M-S11: the controller disposes the loader it was given.
    expect(shared.isDisposed, isFalse);
    expect(thumbs.disposals, 0);
    // A second controller over the same loader reads nothing again.
    final two = make([demoKit(source: read.source)],
        symbols: shared, thumbnails: thumbs);
    await settle();
    expect(two.symbolsState.value, PlanSymbolsState.ready);
    expect(read.reads, 1);

    final own = PlanController(kits: [demoKit()]);
    final ownThumbs = own.thumbnails;
    await settle();
    own.dispose();
    expect(
        () => ownThumbs.imageFor(
            key: 'k',
            document: DraftDocument.empty,
            logicalSize: const Size(8, 6),
            devicePixelRatio: 1,
            foreground: 0),
        throwsStateError,
        reason: 'its own cache is disposed');
  });

  test(
      'S-12 every library failed is failed; retrySymbols reads again and '
      'reaches ready; from ready it does nothing', () async {
    var fail = true;
    final read = CountingSource('demo', () async {
      if (fail) throw StateError('offline');
      return demoBytes();
    });
    final c = make([demoKit(source: read.source)]);
    await settle();
    expect(c.symbolsState.value, PlanSymbolsState.failed);
    fail = false;
    final retry = c.retrySymbols();
    expect(c.symbolsState.value, PlanSymbolsState.loading);
    await retry;
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(read.reads, 2);
    await c.retrySymbols();
    // M-S12: retrySymbols acts in every state.
    expect(read.reads, 2);
  });

  test('S-13 a controller disposed mid-load ignores the late result',
      () async {
    // The controller is made inside the zone, so the load's continuation
    // runs there too and any error it throws lands in [errors].
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final pending = Completer<Uint8List>();
      final c = PlanController(kits: [
        demoKit(
            source: SymbolLibrarySource(
                label: 'demo', read: () => pending.future)),
      ]);
      c.dispose();
      pending.complete(demoBytes());
      await settle();
    }, (error, _) => errors.add(error));
    // M-S13: the `_disposed` check dropped: a disposed notifier is used
    // (a debug assertion, caught here).
    expect(errors, isEmpty, reason: 'the late result touches nothing');
  });

  test('S-14 armSymbol arms the symbol, whatever plan.symbol answers', () async {
    final c = make([demoKit()]);
    await settle();
    final sofa = c.symbolById('demo.sofa.three@1')!;
    expect(c.armedSymbol.value, isNull);
    c.armSymbol(sofa);
    // M-S14: armSymbol drops the `_armed.value = symbol`.
    expect(c.armedSymbol.value, same(sofa));
  });
}
```

- [ ] **Step 6: Write the failing gallery tests.** Create `test/panels/plan_symbol_gallery_test.dart`. Port `jet_cad_floor_plan/test/symbols/symbol_panel_test.dart:1-502` and `:534-637` with these adaptations (assertions unchanged unless named):
  - **The host.** `Host` becomes the controller plus the canvas stand-in and the shell's counted keys: the loader, the thumbnail cache, the tool controller, `IdleTool`, the placement tool and the `armed` notifier are the controller's own. The document is the controller's.

```dart
final class Host {
  Host(this.tester, {Future<Uint8List> Function()? read}) {
    controller = PlanController(kits: [
      demoKit(
          source: SymbolLibrarySource(
              label: 'demo', read: read ?? () async => demoBytes())),
    ]);
    addTearDown(dispose);
  }

  final WidgetTester tester;
  late final PlanController controller;
  final FocusNode canvas = FocusNode(debugLabel: 'canvas');

  /// The search field's controller (spec 09c D13): the host's, as the
  /// editor's is; the gallery neither makes nor disposes a given one.
  final TextEditingController query = TextEditingController();

  /// The shell's keys that reached the ancestor `CallbackShortcuts`.
  final Map<String, int> shortcuts = {'R': 0, 'W': 0, 'M': 0, 'Esc': 0};

  PlanSymbol loaded(String key) =>
      controller.symbols.singleWhere((s) => s.component.key == key);

  Widget build({TextEditingController? query}) => MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyR): () =>
                  shortcuts['R'] = shortcuts['R']! + 1,
              const SingleActivator(LogicalKeyboardKey.keyW): () =>
                  shortcuts['W'] = shortcuts['W']! + 1,
              const SingleActivator(LogicalKeyboardKey.keyM): () =>
                  shortcuts['M'] = shortcuts['M']! + 1,
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  shortcuts['Esc'] = shortcuts['Esc']! + 1,
            },
            child: Row(children: [
              SizedBox(
                width: 240,
                child: PlanSymbolGallery(
                    controller: controller, query: query ?? this.query),
              ),
              Expanded(
                child: Focus(
                  key: const Key('canvas'),
                  focusNode: canvas,
                  autofocus: true,
                  child: const SizedBox.expand(),
                ),
              ),
            ]),
          ),
        ),
      );

  /// Lets the load settle (when [load]), pumps the gallery and lets the
  /// canvas take focus.
  Future<void> pump({bool load = true, TextEditingController? query}) async {
    await tester.pumpWidget(build(query: query));
    if (load) {
      for (var i = 0;
          i < 10 &&
              controller.symbolsState.value == PlanSymbolsState.loading;
          i++) {
        await tester.pump();
      }
    }
    await tester.pump();
  }

  void dispose() {
    query.dispose();
    canvas.dispose();
    controller.dispose();
  }
}
```

  - **The fixture.** `library`, `assetBytes`, `entryOf` and `allIds` read the demo library: `allIds` is `demoVisibleIds()`, `bedIds` is `['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']`, and `entryOf(key)` is `h.loaded(key)`. Key literals: `'bed.double'` → `'demo.bed.double'`, `'bed.single'` → `'demo.bed.single'`, `'sofa.three@1'` → `'demo.sofa.three@1'`, `startsWith('sofa.')` → `startsWith('demo.sofa.')`. "The fixture is not degenerate" (`:230-235`) reads `SymbolLibrary.decode(demoBytes()).entries` and asserts `length > 5` (the demo library's size in place of the asset's `> 20`; a fixture-size premise, not a behaviour assertion) and each base point `length > 100`.
  - **Loading** (`:238-256`): `Host(tester, read: () => read.future)`; drop `unawaited(h.loader.load())` (the controller starts its load); `await h.pump(load: false)`.
  - **Failed and Retry** (`:258-284`): unchanged but for the host; Retry calls `controller.retrySymbols()` through the gallery's button.
  - **Permissions** (`:534-590`): `h.pump(permissions: p)` becomes `h.controller.document.commands.permissions = p; await h.pump();`. `h.selected` (the panel's `onSelect` record) becomes the controller's armed symbol: `expect(h.selected, isEmpty)` → `expect(h.controller.armedSymbol.value, isNull)` and `expect(h.selected.single, same(h.loaded('bed.single')))` → `expect(h.controller.armedSymbol.value, same(h.loaded('demo.bed.single')))` (the observation point moved from a callback to the controller; the fact asserted is the same).
  - **The cells** (`:592-608`): `library.entries` → the demo library's visible entries in order; `symbols[i].label` against `e.symbol.name`.
  - **The thumbnail document** (`:610-637`): `component.key` against `'demo.bed.double'`; the last line reads `doc.components.withComponent<PageComponent>()` as before.
  - Imports: `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `../support/symbol_fixtures.dart`; drop the planner's.

  Then add, in the same file:

```dart
  group('the plan library\'s gallery (new)', () {
    testWidgets(
        'S-15 retired symbols are not shown; the filter narrows the cells '
        'and a tap outside it arms nothing', (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(galleryIds(tester), isNot(contains('demo.chair.old@1')));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  child: PlanSymbolGallery(
                      controller: h.controller,
                      filter: (s) => s.component.key.startsWith('demo.sofa.'))))));
      await tester.pump();
      // M-S15: the gallery ignores its filter.
      expect(galleryIds(tester), ['demo.sofa.three@1', 'demo.sofa.two@1']);
    });

    testWidgets(
        'S-16 the gallery is disabled while plan.symbol is not among the '
        'permitted tools', (tester) async {
      final h = Host(tester);
      await h.pump();
      expect(gallery(tester).enabled, isTrue);
      h.controller.permissions =
          PlanPermissions.full.copyWith(tools: {'plan.select', 'plan.line'});
      await tester.pump();
      // M-S16: `_enabled` drops the allowsTool test.
      expect(gallery(tester).enabled, isFalse);
      await tester.tap(find.byKey(const Key('symbol-cell-demo.sofa.two@1')));
      await tester.pump();
      expect(h.controller.armedSymbol.value, isNull);
    });

    // A positive control (exempt from a mutant): the gallery's own query.
    testWidgets('S-17 a gallery given no query searches with its own',
        (tester) async {
      final h = Host(tester);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
                  width: 240,
                  child: PlanSymbolGallery(controller: h.controller)))));
      await tester.pump();
      await tester.pump();
      await tester.enterText(field, 'bed');
      await tester.pump();
      expect(galleryIds(tester),
          ['demo.bed.double@1', 'demo.bed.single@1', 'demo.bed.night@1']);
      await tester.pumpWidget(const SizedBox());
    });
  });
```

- [ ] **Step 7: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/symbols test/controller/symbols_controller_test.dart test/panels/plan_symbol_gallery_test.dart`. Expected: compilation errors naming `PlanSymbolLoader`, `PlanSymbol`, `searchPlanSymbols`, `PlanSymbolGallery`, `symbolById` (no test runs). Quote the first.

- [ ] **Step 8: `PlanSymbol` and the loader.** Create `lib/src/symbols/plan_symbol.dart`:

```dart
// Spec P2 "Symbol libraries" (Task 13): one symbol the plan offers, with
// the kit that gave it and that kit's words.
import 'package:meta/meta.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitNames, SymbolComponent, SymbolEntry;

@immutable
final class PlanSymbol {
  const PlanSymbol(
      {required this.kitId, required this.names, required this.entry});

  /// The kit whose library gave it.
  final String kitId;

  /// That kit's words (its `symbol:` and `category:` words).
  final KitNames names;

  /// The library's entry: identity, unit, definition, leaves.
  final SymbolEntry entry;

  /// `key@version`, the gallery's and the loader's identity.
  String get id => entry.id;

  SymbolComponent get component => entry.symbol;

  @override
  String toString() => 'PlanSymbol($kitId: $id)';
}
```

Create `lib/src/symbols/plan_symbol_loader.dart`:

```dart
// Spec P2 "Symbol libraries" (Task 13): reads, decodes and caches the
// kits' symbol libraries. One loader may serve several controllers (today's
// §4: the app's loader, never disposed by a view); a controller never
// disposes a loader it was given.
import 'dart:async';

import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
import 'plan_symbol.dart';

/// One assembly of a kit set's libraries: the symbols in load order, the
/// problems met, and the state they leave.
final class PlanSymbolLoad {
  PlanSymbolLoad._(List<PlanSymbol> symbols, List<KitDiagnostic> diagnostics,
      this.state)
      : symbols = List.unmodifiable(symbols),
        diagnostics = List.unmodifiable(diagnostics);

  final List<PlanSymbol> symbols;
  final List<KitDiagnostic> diagnostics;
  final PlanSymbolsState state;
}

/// The kits' symbol libraries, read once per source.
///
/// [library] reads and decodes one source and keeps the result; a failed
/// read or decode is not kept, so a later call reads again. [load] asks
/// for every source of a kit set at once and assembles them in kit order,
/// then each kit's source order, then library order:
/// - a library that cannot be read or decoded is skipped
///   (`libraryUnreadable`);
/// - a library whose kit is not its kit's is refused
///   (`libraryKitMismatch`);
/// - a `key@N` already given earlier in that order is dropped
///   (`symbolDuplicate`).
/// The state is `failed` only when there was a source and every one
/// failed; else `ready`.
class PlanSymbolLoader {
  PlanSymbolLoader();

  final Map<SymbolLibrarySource, Future<SymbolLibrary>> _reads =
      Map<SymbolLibrarySource, Future<SymbolLibrary>>.identity();
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// [source]'s decoded library, read on the first call.
  Future<SymbolLibrary> library(SymbolLibrarySource source) {
    if (_disposed) throw StateError('PlanSymbolLoader used after dispose');
    final kept = _reads[source];
    if (kept != null) return kept;
    final read = Future.sync(source.read).then(SymbolLibrary.decode);
    _reads[source] = read;
    read.then<void>((_) {}, onError: (Object _) {
      if (identical(_reads[source], read)) _reads.remove(source);
    });
    return read;
  }

  Future<PlanSymbolLoad> load(KitSet kits) async {
    if (_disposed) throw StateError('PlanSymbolLoader used after dispose');
    final reads = [
      for (final kit in kits.kits)
        for (final source in kit.symbols) (kit, source, library(source)),
    ];
    final symbols = <PlanSymbol>[];
    final diagnostics = <KitDiagnostic>[];
    final given = <String, String>{};
    var failed = 0;
    for (final (kit, source, read) in reads) {
      final SymbolLibrary lib;
      try {
        lib = await read;
      } catch (e) {
        failed++;
        diagnostics.add(KitDiagnostic(
            kitId: kit.id,
            subject: source.label,
            code: KitDiagnosticCode.libraryUnreadable,
            message: 'the library "${source.label}" could not be read: $e',
            error: e));
        continue;
      }
      if (lib.kits.length != 1 || lib.kits.single != kit.id) {
        failed++;
        diagnostics.add(KitDiagnostic(
            kitId: kit.id,
            subject: source.label,
            code: KitDiagnosticCode.libraryKitMismatch,
            message: 'the library "${source.label}" holds the kit '
                '${lib.kits.join('+')}, not "${kit.id}"'));
        continue;
      }
      for (final entry in lib.entries) {
        final earlier = given[entry.id];
        if (earlier != null) {
          diagnostics.add(KitDiagnostic(
              kitId: kit.id,
              subject: entry.id,
              code: KitDiagnosticCode.symbolDuplicate,
              message: '${entry.id} of "${source.label}" is already given '
                  'by the kit "$earlier"; dropped'));
          continue;
        }
        given[entry.id] = kit.id;
        symbols.add(PlanSymbol(kitId: kit.id, names: kit.names, entry: entry));
      }
    }
    final state = reads.isNotEmpty && failed == reads.length
        ? PlanSymbolsState.failed
        : PlanSymbolsState.ready;
    return PlanSymbolLoad._(symbols, diagnostics, state);
  }

  /// Drops every kept read. A load still running completes; the loader
  /// cannot be used afterwards.
  void dispose() {
    _disposed = true;
    _reads.clear();
  }
}
```

(`PlanSymbolsState` is the shared enum Task 8 declared; import it from its file. `KitSet` path per Task 6: `lib/src/kits/kit_set.dart`.)

- [ ] **Step 9: The fold, the model, the placer and the thumbnail document.**

The fold is Task 9's `lib/src/l10n/search_fold.dart`; nothing is created for it here.

Create `lib/src/symbols/gallery_model.dart` (the algorithm of `symbol_search.dart:27-61`, generalised to kits, words and retired symbols):

```dart
// Spec P2 "PlanSymbolGallery" (Task 13): the gallery's model. Ported from
// jet_cad_floor_plan's symbol_search.dart (spec 09b D3, 14d L11) and
// symbol_names.dart's SymbolWords (L9): the words are now each kit's
// KitNames, a group is a kit's category, and retired symbols are hidden
// (R2).
import 'package:meta/meta.dart';

import '../l10n/search_fold.dart';
import 'plan_symbol.dart';

/// The names a gallery shows in one language: the language's word, else
/// English's, else the library's stored text (KitNames' fallbacks).
@immutable
final class PlanSymbolWords {
  const PlanSymbolWords(this.language);

  static const PlanSymbolWords english = PlanSymbolWords('en');

  /// A language code.
  final String language;

  String name(PlanSymbol s) => s.names.symbolName(language, s.component);

  String category(PlanSymbol s) =>
      s.names.categoryName(language, s.kitId, s.component.category);
}

/// One kit's category of symbols that survive a search, in load order.
typedef PlanSymbolGroup = ({
  String kitId,
  String category,
  List<PlanSymbol> symbols
});

/// The group's id, the same in every language: `<kit>/<English category>`
/// (the `category:` word id's tail).
String groupIdOf(PlanSymbolGroup g) => '${g.kitId}/${g.category}';

final RegExp _whiteSpace = RegExp(r'\s+');

/// The groups the gallery shows for [query] over [symbols].
///
/// Retired symbols and those [filter] refuses are left out first. The
/// query is folded and split on white space; a symbol matches when every
/// term is a substring of its shown name or category ([words]), its stored
/// English name or category, or one of its tags, all folded; a blank query
/// matches every symbol. Groups are keyed by kit and English category, in
/// first-appearance order over the symbols left (not over the matches);
/// symbols keep [symbols]' order; an empty group is omitted.
List<PlanSymbolGroup> searchPlanSymbols(
    List<PlanSymbol> symbols, String query, PlanSymbolWords words,
    {bool Function(PlanSymbol symbol)? filter}) {
  final terms = [
    for (final t in searchFold(query).split(_whiteSpace))
      if (t.isNotEmpty) t,
  ];
  final offered = [
    for (final s in symbols)
      if (!s.component.retired && (filter == null || filter(s))) s,
  ];
  final byGroup = <(String, String), List<PlanSymbol>>{};
  for (final s in offered) {
    byGroup.putIfAbsent((s.kitId, s.component.category), () => []);
  }
  for (final s in offered) {
    final group = byGroup[(s.kitId, s.component.category)]!;
    if (terms.isEmpty) {
      group.add(s);
      continue;
    }
    final c = s.component;
    final texts = [
      searchFold(words.name(s)),
      searchFold(words.category(s)),
      searchFold(c.name),
      searchFold(c.category),
      for (final tag in c.tags) searchFold(tag),
    ];
    if (terms.every((t) => texts.any((x) => x.contains(t)))) group.add(s);
  }
  return [
    for (final MapEntry(key: (kit, category), value: list) in byGroup.entries)
      if (list.isNotEmpty)
        (kitId: kit, category: category, symbols: List.unmodifiable(list)),
  ];
}
```

Create `lib/src/symbols/symbol_placer.dart` by porting `jet_cad_floor_plan/lib/src/symbols/symbol_placer.dart:1-283`:
  - lines 18-78 (`InstanceStyle`, `placementTransform`, `_quarterTurn`), 156-163 (`_ascending`) and 239-283 (`isLeafEqual`) unchanged;
  - imports: `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolComponent, SymbolEntry, SymbolLeaf, UnitComponent`, `package:vector_math/vector_math_64.dart' show Vector2`; drop the table and seating imports (`:11-15`);
  - `definitionForEntry` (`:87-154`) and `placeSymbol` (`:181-237`) become:

```dart
/// The definition a placement of [entry] in [doc] uses, and the commands
/// that make it when it is a copy (none when one is reused). A definition
/// is reused when it carries the entry's key and version, still exists,
/// carries an equal unit (or none, as the entry) and is leaf-equal to the
/// entry; otherwise it is copied with fresh handles, its `jetcad.symbol`
/// the entry's whole component (attachment kinds, family and retired
/// included) and its `jetcad.unit` the entry's when it has one.
({Handle definition, List<DraftCommand> commands}) definitionForEntry(
    DraftDocument doc, SymbolEntry entry) {
  assert(_ascending(entry.leaves),
      'the entry\'s leaves must be ascending by handle (spec 09c R5-7)');
  final symbol = entry.symbol;
  final commands = <DraftCommand>[];
  Handle? definition;
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h);
    if (c != null &&
        c.key == symbol.key &&
        c.version == symbol.version &&
        doc.tree.definition(h) != null &&
        doc.components.get<UnitComponent>(h) == entry.unit &&
        isLeafEqual(doc, h, entry)) {
      definition = h;
      break;
    }
  }

  if (definition == null) {
    final copy = doc.handleSeed.next();
    final taken = {for (final d in doc.tree.definitions) d.name};
    final base = symbol.id;
    var name = base;
    for (var n = 2; taken.contains(name); n++) {
      name = '$base#$n';
    }
    commands
      ..add(AddDefinitionCommand(Definition(
        handle: copy,
        name: name,
        basePoint: entry.definition.basePoint,
        children: const [],
      )))
      ..add(SetComponentCommand<SymbolComponent>(copy, symbol));
    final unit = entry.unit;
    if (unit != null) {
      commands.add(SetComponentCommand<UnitComponent>(copy, unit));
    }
    for (final leaf in entry.leaves) {
      commands.add(AddEntityCommand(
        record:
            leaf.record.copyWith(handle: doc.handleSeed.next(), owner: copy),
        payload: leaf.payload,
      ));
    }
    definition = copy;
  }
  return (definition: definition, commands: commands);
}

/// The command that places [entry] in [doc] at [at], labelled
/// `Place <name>`; it does not execute. Every handle is allocated here,
/// once, so a redo reuses them. The instance takes the current layer
/// (`drawingLayer`) and [style]; [transform], when given, is used as is
/// (an attachment's), else [placementTransform] of [at], [quarterTurns]
/// and [mirrored].
CompoundCommand placeSymbol(
  DraftDocument doc,
  SymbolEntry entry, {
  required Vector2 at,
  int quarterTurns = 0,
  bool mirrored = false,
  Transform2? transform,
  InstanceStyle style = const InstanceStyle(),
}) {
  final made = definitionForEntry(doc, entry);
  final commands = <DraftCommand>[...made.commands];
  commands.add(AddNodeCommand(InstanceNode(
    handle: doc.handleSeed.next(),
    parent: doc.rootHandle,
    definition: made.definition,
    layer: drawingLayer(doc),
    transform: transform ??
        placementTransform(
          at: at,
          basePoint: entry.definition.basePoint,
          quarterTurns: quarterTurns,
          mirrored: mirrored,
        ),
    color: style.color,
    lineweight: style.lineweight,
    transparency: style.transparency,
    linetype: style.linetype,
    linetypeScale: style.linetypeScale,
  )));
  return CompoundCommand(commands, label: 'Place ${entry.symbol.name}');
}
```

  The handle order is today's: the copy's definition and leaves first, then the instance (`:191-195`).

Create `lib/src/symbols/thumbnail_document.dart`:

```dart
// Spec P2 "PlanSymbolGallery" (Task 13): a gallery cell's thumbnail is what
// a placement makes (today's symbolThumbnailDocument, symbol_panel.dart:
// 43-50): the kit components registered, millimetres, the symbol placed at
// its own base point with no turn and no mirror, an identity transform.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show registerKitComponents;

import 'plan_symbol.dart';
import 'symbol_placer.dart';

DraftDocument symbolThumbnailDocument(PlanSymbol symbol) {
  final doc = DraftDocument.empty(measurer: const InsertionPointMeasurer());
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(placeSymbol(doc, symbol.entry,
      at: symbol.entry.definition.basePoint));
  return doc;
}
```

Create `lib/src/panels/panel_focus.dart`: a copy of `jet_cad_floor_plan/lib/src/panel_focus.dart:1-50`, unchanged (one leading comment line naming the source added).

- [ ] **Step 10: The gallery.** Create `lib/src/panels/plan_symbol_gallery.dart` (ported from `symbol_panel.dart:52-408`; the loader, the tool controller, the placement tool and the armed notifier are the controller's):

```dart
// Spec P2 "PlanSymbolGallery" (Task 13): the loaded kits' symbols with a
// search over names and tags, categories, retired symbols hidden (R2), an
// optional filter (today's symbolFilter); choosing a symbol arms
// plan.symbol. Ported from jet_cad_floor_plan's symbol_panel.dart (spec
// 09b D7, F-4, F-13; 09c D13).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/plan_controller.dart';
import '../l10n/strings.dart';
import '../symbols/gallery_model.dart';
import '../symbols/plan_symbol.dart';
import '../symbols/thumbnail_document.dart';
import '../tools/generic_tools.dart' show PlanToolIds;
import 'panel_focus.dart';

/// The gallery of [controller]'s symbols.
///
/// - **Loading:** a progress indicator and the "loading" words (key
///   `symbol-loading`).
/// - **Failed:** the words and a Retry button (key `symbol-retry`) calling
///   `PlanController.retrySymbols`.
/// - **Ready:** the search field (key `symbol-search`; a clear button
///   keyed `symbol-search-clear` while it is not empty), then the
///   [SymbolGallery] over [searchPlanSymbols]. An empty result shows the
///   no-match words (key `symbol-search-empty`) and a Clear button (key
///   `symbol-search-clear-empty`); with no query (a [filter] offering
///   nothing), an empty area.
///
/// **The highlight** is the armed symbol's id while plan.symbol is the
/// active tool. **Enabled** while the permissions offer plan.symbol and
/// the document's engine permissions allow a placement's needs. A tap arms
/// the symbol through `PlanController.armSymbol`.
///
/// **The search text** is [query]'s when given (the caller's, which may
/// outlive this widget, so the text survives a tab switch; never disposed
/// here); else the gallery's own.
class PlanSymbolGallery extends StatefulWidget {
  const PlanSymbolGallery({
    super.key,
    required this.controller,
    this.filter,
    this.query,
  });

  final PlanController controller;

  /// The symbols offered: applied before the search and to a tapped cell;
  /// null offers every (not retired) symbol. Read at each build.
  final bool Function(PlanSymbol symbol)? filter;

  final TextEditingController? query;

  @override
  State<PlanSymbolGallery> createState() => _PlanSymbolGalleryState();
}

class _PlanSymbolGalleryState extends State<PlanSymbolGallery> {
  TextEditingController? _ownQuery;
  TextEditingController? _listening;
  final PanelFieldFocusNode _searchFocus =
      PanelFieldFocusNode(debugLabel: 'symbol-search');

  /// One cell per symbol, by identity, so a rebuild hands the gallery the
  /// same values; cleared when the symbols or the language change.
  final Map<PlanSymbol, GallerySymbol> _cells =
      Map<PlanSymbol, GallerySymbol>.identity();
  final Map<String, PlanSymbol> _byId = <String, PlanSymbol>{};
  List<PlanSymbol>? _indexed;
  PlanSymbolWords _words = PlanSymbolWords.english;

  TextEditingController get _query =>
      widget.query ?? (_ownQuery ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(PlanSymbolGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
  }

  void _listen() {
    final q = _query;
    if (identical(q, _listening)) return;
    _listening?.removeListener(_onQuery);
    _listening = q;
    q.addListener(_onQuery);
  }

  void _onQuery() => setState(() {});

  @override
  void dispose() {
    _listening?.removeListener(_onQuery);
    _ownQuery?.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handBack() => _searchFocus.handBack();

  void _clear() => _query.clear();

  void _index(List<PlanSymbol> symbols) {
    if (identical(symbols, _indexed)) return;
    _indexed = symbols;
    _cells.clear();
    _byId
      ..clear()
      ..addAll({for (final s in symbols) s.id: s});
  }

  GallerySymbol _cell(PlanSymbol s) => _cells.putIfAbsent(
      s,
      () => GallerySymbol(
            id: s.id,
            label: _words.name(s),
            thumbnailKey: s.id,
            thumbnailDocument: () => symbolThumbnailDocument(s),
          ));

  String? get _selectedId {
    final c = widget.controller;
    final armed = c.armedSymbol.value;
    if (armed == null || c.activeTool.value != PlanToolIds.symbol) {
      return null;
    }
    return armed.id;
  }

  bool get _enabled {
    final c = widget.controller;
    if (!c.permissions.allowsTool(PlanToolIds.symbol)) return false;
    final engine = c.document.commands.permissions;
    return PlanToolIds.symbolNeeds.every(engine.allows);
  }

  void _onSelect(String id) {
    final s = _byId[id];
    if (s == null) return;
    if (widget.filter case final f? when !f(s)) return;
    widget.controller.armSymbol(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable:
          Listenable.merge([c, c.symbolsState, c.activeTool, c.armedSymbol]),
      builder: (context, _) => switch (c.symbolsState.value) {
        PlanSymbolsState.loading => const _Loading(),
        PlanSymbolsState.failed =>
          _Failed(onRetry: () => unawaited(c.retrySymbols())),
        PlanSymbolsState.ready => _ready(context),
      },
    );
  }

  Widget _ready(BuildContext context) {
    final c = widget.controller;
    _index(c.symbols);
    final words = PlanSymbolWords(PlanStrings.of(context).languageCode);
    if (words.language != _words.language) {
      _words = words;
      _cells.clear();
    }
    final scheme = Theme.of(context).colorScheme;
    final cellColor = scheme.surfaceContainerLowest;
    final groups =
        searchPlanSymbols(c.symbols, _query.text, words, filter: widget.filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: _searchField(context),
        ),
        Expanded(
          child: groups.isEmpty
              ? (_query.text.trim().isEmpty
                  ? const SizedBox.shrink()
                  : _NoMatch(query: _query.text, onClear: _clear))
              : SymbolGallery(
                  categories: [
                    for (final g in groups)
                      GalleryCategory(
                        id: groupIdOf(g),
                        name: words.category(g.symbols.first),
                        symbols: [for (final s in g.symbols) _cell(s)],
                      ),
                  ],
                  selectedId: _selectedId,
                  enabled: _enabled,
                  onSelect: _onSelect,
                  thumbnails: c.thumbnails,
                  foreground: foregroundFor(cellColor.toARGB32() & 0xFFFFFF),
                  selectedForeground: foregroundFor(
                      scheme.primaryContainer.toARGB32() & 0xFFFFFF),
                  cellColor: cellColor,
                ),
        ),
      ],
    );
  }

  /// The field keeps every typed character, Undo, Redo and Escape from
  /// the bindings above it (`_FieldKeys`); its own nearer Escape hands the
  /// focus back to the canvas, as Enter and a tap outside do (F-4, F-13).
  Widget _searchField(BuildContext context) {
    final strings = PlanStrings.of(context);
    return _FieldKeys(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _handBack,
        },
        child: TextField(
          key: const Key('symbol-search'),
          controller: _query,
          focusNode: _searchFocus,
          maxLines: 1,
          textInputAction: TextInputAction.search,
          onEditingComplete: _handBack,
          onTapOutside: (_) => _handBack(),
          decoration: InputDecoration(
            isDense: true,
            hintText: strings.searchSymbols,
            prefixIcon: const Icon(Icons.search, size: 18),
            border: const OutlineInputBorder(),
            suffixIcon: _query.text.isEmpty
                ? null
                : ExcludeFocus(
                    child: IconButton(
                      key: const Key('symbol-search-clear'),
                      tooltip: strings.clear,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clear,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Spec 05 D9's guard for this one field: a typed character, Undo
/// (Ctrl/Meta+Z), Redo (Ctrl/Meta+Shift+Z, Ctrl+Y) and Escape stop here as
/// `DoNothingAndStopPropagationTextIntent`, which a focused field answers
/// by taking the key as text; elsewhere no action is found and the key
/// bubbles on.
class _FieldKeys extends StatelessWidget {
  const _FieldKeys({required this.child});

  final Widget child;

  static final Map<ShortcutActivator, Intent> _stop = {
    const _TypingActivator(): const DoNothingAndStopPropagationTextIntent(),
    for (final activator in const [
      SingleActivator(LogicalKeyboardKey.keyZ, control: true),
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
      SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
      SingleActivator(LogicalKeyboardKey.keyY, control: true),
      SingleActivator(LogicalKeyboardKey.escape),
    ])
      activator: const DoNothingAndStopPropagationTextIntent(),
  };

  @override
  Widget build(BuildContext context) =>
      Shortcuts(shortcuts: _stop, child: child);
}

/// A key-down or repeat that types a printable character with neither
/// Control nor Meta held (ported from shortcut_guard.dart:118-138).
class _TypingActivator extends ShortcutActivator {
  const _TypingActivator();

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is KeyUpEvent) return false;
    final character = event.character;
    if (character == null || character.isEmpty) return false;
    final unit = character.codeUnitAt(0);
    if (unit < 0x20 || unit == 0x7f) return false;
    return !state.isControlPressed && !state.isMetaPressed;
  }

  @override
  String debugDescribeKeys() => 'a key that types a character';
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('symbol-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 8),
            Text(PlanStrings.of(context).loadingSymbols),
          ],
        ),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        key: const Key('symbol-failed'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The words only: the errors are the controller's diagnostics.
              Text(PlanStrings.of(context).symbolsFailed,
                  key: const Key('symbol-failed-text'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ExcludeFocus(
                child: FilledButton.tonal(
                  key: const Key('symbol-retry'),
                  onPressed: onRetry,
                  child: Text(PlanStrings.of(context).retry),
                ),
              ),
            ],
          ),
        ),
      );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              PlanStrings.of(context).noSymbolsMatch(query),
              key: const Key('symbol-search-empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ExcludeFocus(
              child: TextButton(
                key: const Key('symbol-search-clear-empty'),
                onPressed: onClear,
                child: Text(PlanStrings.of(context).clear),
              ),
            ),
          ],
        ),
      );
}
```

(`Listenable.merge` over the controller covers a runtime permissions change, which notifies the controller, Task 12. The `strings.dart` import path is Task 9's.)

- [ ] **Step 11: The controller.** In `lib/src/controller/plan_controller.dart`:
  1. Constructor: Task 8's factory and private constructor gain the named parameter `PlanSymbolLoader? symbols` (spec P2; Task 8 leaves it to this task) and pass it through; `thumbnails` is Task 8's already (the field `thumbnails`, `_ownsThumbnails` and its disposal) and stays as it is, and so does Task 8's `_symbolsState` notifier (this task drives it). Add the fields and start the load last in the constructor body (after the first document's systems exist, so a failure to construct leaves no load running):

```dart
  final PlanSymbolLoader _symbolLoader;
  final bool _ownsSymbolLoader;
  final ValueNotifier<PlanSymbol?> _armed = ValueNotifier<PlanSymbol?>(null);
  List<PlanSymbol> _symbols = const [];
  Map<String, PlanSymbol> _symbolsById = const {};
  int _symbolRun = 0;
```

     initialised in the initialiser list as `_symbolLoader = symbols ?? PlanSymbolLoader(), _ownsSymbolLoader = symbols == null`; the constructor body ends with `unawaited(_loadSymbols());`. Task 8's `symbolsState` getter stays; its doc comment becomes the one below.
  2. Members:

```dart
  /// The symbol libraries' state (spec P2): loading until every source has
  /// settled; failed when every source failed; else ready.
  ValueListenable<PlanSymbolsState> get symbolsState => _symbolsState;

  /// The loaded symbols in load order, retired ones included (a placed
  /// retired symbol still resolves; the gallery hides them).
  List<PlanSymbol> get symbols => _symbols;

  PlanSymbol? symbolById(String id) => _symbolsById[id];

  /// The symbol plan.symbol places.
  ValueListenable<PlanSymbol?> get armedSymbol => _armed;

  /// Arms [symbol] and activates plan.symbol (a gallery cell, or the
  /// host). Answers whether plan.symbol is now active; the symbol stays
  /// armed either way (today's _armSymbol, planner_shell.dart:940-943).
  bool armSymbol(PlanSymbol symbol) {
    _armed.value = symbol;
    return selectTool(PlanToolIds.symbol);
  }

  /// Loads the libraries again after a failure; nothing in another state.
  Future<void> retrySymbols() async {
    if (_symbolsState.value != PlanSymbolsState.failed) return;
    await _loadSymbols();
  }

  Future<void> _loadSymbols() async {
    final run = ++_symbolRun;
    // A kit set without a symbol library is ready at once, empty (Task
    // 8's C1 reads `ready` right after construction).
    if (kits.kits.every((kit) => kit.symbols.isEmpty)) {
      _symbolsState.value = PlanSymbolsState.ready;
      return;
    }
    _symbolsState.value = PlanSymbolsState.loading;
    PlanSymbolLoad? load;
    Object? error;
    try {
      load = await _symbolLoader.load(kits);
    } catch (e) {
      error = e; // a loader the host disposed
    }
    if (_disposed || run != _symbolRun) return;
    if (load == null) {
      _symbolsState.value = PlanSymbolsState.failed;
      debugPrint('The symbol libraries could not be loaded: $error');
      return;
    }
    _symbols = load.symbols;
    _symbolsById = {for (final s in load.symbols) s.id: s};
    for (final d in load.diagnostics) {
      _diagnostics.add(d);
    }
    _symbolsState.value = load.state;
  }
```

     (`kits` is Task 8's validated `KitSet`, `_diagnostics` its diagnostics log, `_disposed` the flag its `dispose` sets first. Task 14 adds one call after the diagnostics loop.)
  3. `dispose()` (Task 8's sets `_disposed = true` first and already disposes `thumbnails` when owned and `_symbolsState`): add `if (_ownsSymbolLoader) _symbolLoader.dispose(); _armed.dispose();`.

- [ ] **Step 12: The barrel.** Export `src/symbols/plan_symbol.dart`, `src/symbols/plan_symbol_loader.dart` and `src/panels/plan_symbol_gallery.dart` from `lib/jet_cad_2d_plan.dart`.

- [ ] **Step 13: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/symbols test/controller/symbols_controller_test.dart test/panels/plan_symbol_gallery_test.dart`. Expected: `All tests passed!`. Then `flutter test`. Expected: `All tests passed!`.

- [ ] **Step 14: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 15: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/symbols/plan_symbol.dart packages/jet_cad_2d_plan/lib/src/symbols/plan_symbol_loader.dart packages/jet_cad_2d_plan/lib/src/symbols/gallery_model.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart packages/jet_cad_2d_plan/lib/src/symbols/thumbnail_document.dart packages/jet_cad_2d_plan/lib/src/panels/panel_focus.dart packages/jet_cad_2d_plan/lib/src/panels/plan_symbol_gallery.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/symbol_fixtures.dart packages/jet_cad_2d_plan/test/symbols/plan_symbol_loader_test.dart packages/jet_cad_2d_plan/test/symbols/gallery_model_test.dart packages/jet_cad_2d_plan/test/symbols/symbol_placer_test.dart packages/jet_cad_2d_plan/test/controller/symbols_controller_test.dart packages/jet_cad_2d_plan/test/panels/plan_symbol_gallery_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the symbol loader and the gallery (P2)

PlanSymbolLoader reads every kit's libraries at once, caches each
source's read and assembles them in kit order: an unreadable library is
skipped, one under another kit refused, a repeated key@N dropped, each a
diagnostic, and the load goes on. The controller loads at construction
without blocking edits and never disposes a loader or thumbnail cache it
was given. PlanSymbolGallery searches names, categories and tags in
either language, hides retired symbols and arms plan.symbol. The placer
is ported for the thumbnails.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 16: Mutation check** (committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-S-none `plan_controller.dart`: delete `_loadSymbols`' early return for a kit set without a library → Task 8's C1 red (`loading`, not `ready`).
  - M-S2 `plan_symbol_loader.dart`: delete the `if (earlier != null) { … continue; }` block → S-2 red.
  - M-S4 `plan_symbol_loader.dart`: delete the `if (lib.kits.length != 1 …) { … continue; }` block → S-4 red.
  - M-S5 `plan_symbol_loader.dart`: replace the read's `catch (e) { … }` body with `rethrow;` → S-5 red.
  - M-S6 `plan_symbol_loader.dart`: `failed == reads.length` → `failed > 0` → S-6 red.
  - M-S7a `plan_symbol_loader.dart`: delete `if (kept != null) return kept;` → S-7 red; M-S7b: delete the `read.then<void>(…)` eviction → S-7 red.
  - M-S9 `plan_controller.dart`: delete the `for (final d in load.diagnostics)` loop → S-9 red.
  - M-S11 `plan_controller.dart`: `if (_ownsSymbolLoader) _symbolLoader.dispose();` → `_symbolLoader.dispose();` → S-11 red.
  - M-S12 `plan_controller.dart`: delete `if (_symbolsState.value != PlanSymbolsState.failed) return;` → S-12 red.
  - M-S13 `plan_controller.dart`: delete `_disposed ||` from `_loadSymbols` → S-13 red (`errors` holds the disposed `ValueNotifier`'s assertion).
  - M-S14 `plan_controller.dart`: delete `_armed.value = symbol;` → S-14 red.
  - M-GM2 `gallery_model.dart`: delete `!s.component.retired && ` → GM-2 red.
  - M-GM3a/b/c `gallery_model.dart`: delete `searchFold(c.name),` / the tags line / `searchFold(c.category),` → GM-3 red (each).
  - M-GM4a/b `gallery_model.dart`: delete `searchFold(words.name(s)),` / `searchFold(words.category(s)),` → GM-4 red.
  - M-GM5 `gallery_model.dart`: `terms.every(` → `terms.any(` → GM-5 red.
  - M-GM6 `gallery_model.dart`: delete `&& (filter == null || filter(s))` → GM-6 red.
  - M-GM7 `gallery_model.dart`: key the map by `('', s.component.category)` in both places → GM-7 red.
  - M-S15 `plan_symbol_gallery.dart`: `filter: widget.filter` → `filter: null` in `_ready` → S-15 red.
  - M-S16 `plan_symbol_gallery.dart`: delete the `allowsTool` line of `_enabled` → S-16 red.
  - The ported tests carry their own named mutants (`symbol_panel_test.dart`'s M-09b7, M-09b8, M-09b10, M-09b22, M-09c-t…; the placer's P- and L- tests); run M-09b7 (`_FieldKeys` returns `child` without the `Shortcuts`) → "typing r, w and m in the field fires no shortcut" red, and M-09b22 (`_enabled` returns `true`) → "a tap reports the entry…" red.

#### Assumed from earlier tasks

- Task 4: `KitDiagnostic({required String kitId, String? subject, required KitDiagnosticCode code, required String message, Object? error})` with getters `kitId`, `subject`, `code`, `message`, `error`; `KitDiagnosticCode.libraryUnreadable`, `.libraryKitMismatch`, `.symbolDuplicate`.
- Task 5: `SymbolComponent.retired` and `CatalogSymbol({..., bool retired = false})`, `CatalogSymbol.retired`.
- Task 6: `KitSet` at `lib/src/kits/kit_set.dart` with `List<PlanKit> get kits` in load order; `KitSet validateKitSet(List<PlanKit> kits)` exported from the barrel and accepting kits of symbols only.
- Task 8: `enum PlanSymbolsState { loading, ready, failed }` (shared interfaces) exported; `PlanController({required List<PlanKit> kits, SymbolThumbnails? thumbnails, ...})` (this task adds `PlanSymbolLoader? symbols`), with Task 8's `thumbnails` field and `_symbolsState` notifier; `ValueListenable<List<KitDiagnostic>> get diagnostics`; the private log `_diagnostics` with `add(KitDiagnostic)` (Task 11's `DiagnosticsLog`); the validated kit set `KitSet get kits`; the `_disposed` flag set at the start of `dispose`; the `symbolsState` placeholder this task replaces.
- Task 9: `PlanStrings.of(BuildContext)` (English without a delegate, as `FloorPlanStrings.of`) with `languageCode`, `searchSymbols`, `clear`, `loadingSymbols`, `symbolsFailed`, `retry`, `noSymbolsMatch(String query)` (the ported `FloorPlanStrings` members, `strings.dart:39, 161-182`), at `lib/src/l10n/strings.dart`; `String searchFold(String)` at `lib/src/l10n/search_fold.dart` (Task 9 ports it and its SF test; this task imports it).
- Task 12: `PlanToolIds`, `PlanPermissions.allowsTool`, `PlanController.permissions` (a change notifies the controller), `selectTool`, `test/support/tool_events.dart` (`useTestCamera`, `drawLine`, `linesOf`).

---

