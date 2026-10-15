### Task 4: Plan library plumbing (spec S1 "The output" GuardedType line, S2 "The contract gains" symbolDefinition, S4 "Words" host words)

**Files:**
- Read only: `packages/jet_cad_2d_plan/lib/src/kits/guard.dart` (`GuardedType.instances` is Task 1's, controller ruling R-1; this task's PB-guard tests and mutations cover it).
- Modify (`packages/jet_cad_2d_plan/`):
  - `lib/src/controller/services.dart` (`ServicesHost` gains three members; `KitServices.symbolDefinition` and `symbolsState` replace Task 3's stubs);
  - `lib/src/controller/plan_controller.dart` (`words:`, `namesOf`, the pending refs, `SymbolsState`);
  - `lib/src/symbols/symbol_box.dart` (`servedTopOfEntry`);
  - `lib/src/symbols/plan_symbol_loader.dart`, `lib/src/panels/plan_symbol_gallery.dart` (`SymbolsState`);
  - `lib/src/panels/kit_lookup.dart`, `lib/src/panels/plan_property_panel.dart`, `lib/src/editor/plan_tool_palette.dart` (the host's words first);
  - `lib/jet_cad_2d_plan.dart` (`SymbolsState` re-exported in place of `PlanSymbolsState`).
- Delete: `packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart`.
- Test (`packages/jet_cad_2d_plan/test/`):
  - create `kits/guarded_instances_test.dart`, `controller/symbol_definition_test.dart`, `controller/host_words_test.dart`;
  - modify `support/box_kit.dart` (the square's `instances`, switchable);
  - rename `PlanSymbolsState` → `SymbolsState` in `controller/symbols_controller_test.dart`, `controller/plan_controller_test.dart`, `symbols/plan_symbol_loader_test.dart`, `panels/symbol_section_test.dart`, `panels/plan_symbol_gallery_test.dart`, `editor/plan_editor_test.dart`, `editor/editor_words_test.dart`, `barrel_test.dart` (the last three change an import or the export list too).

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Task 1: `ParametricType.instances(ParametricView view, Handle self)` (default `const []`), `GeneratedInstance`; the planner calls `instances` beside `generate` for each non-dissolving object of the closure, and `probe` and `drift` call it through `_plan` (spec S1).
  - Task 3: `SymbolsState`, `SymbolDefinitionRef`, `PlanServices.symbolDefinition`/`symbolsState`, `validateHostWords` (all from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`); Task 3's two `UnimplementedError` stubs in `controller/services.dart`.
  - 2a: `definitionForEntry(DraftDocument, SymbolEntry)` → `({Handle definition, List<DraftCommand> commands})` (`lib/src/symbols/symbol_placer.dart:84-134`: it reuses a leaf-equal definition, else takes one handle per definition and per leaf from `handleSeed`); `boxOfLeaves`, `boxOfEntry`, `footprintOf` (`lib/src/symbols/symbol_box.dart:68-152`); `PlanController.symbolById` (`plan_controller.dart:1044`, ids `key@version`); `KitNames.merge` (the receiver's word wins, `jet_cad_2d_kit/lib/src/model/kit_names.dart:46-51`); `isClosedPolyline` (`jet_cad_2d/lib/src/document/grips.dart:50`).
- Produces:
  - The PB-guard tests of Task 1's `GuardedType.instances` (a throw is `KitHookFailure(kitId, typeId, 'instances', error)`; controller ruling R-1).
  - `KitServices.symbolDefinition(String key)` / `symbolsState`, with pending refs by key kept per controller until the document holds the definition, the next `PlanController.execute`, or a document swap.
  - `PlanController({..., KitNames words = KitNames.empty})`: `ArgumentError` naming `validateHostWords`' first problem; each kit's `KitNamesWords` reads `words.merge(kit.names)`.
  - `PlanController.symbolsState`: `ValueListenable<SymbolsState>` (the kit's enum; `plan_symbols_state.dart` deleted).
  - `@internal KitNames? PlanController.namesOf(String kitId)`: a loaded kit's words with the host's first (null for a kit not loaded). Task 10's `unitKindWord` reads a kit's words through `servicesOf(kitId).words` or this.
  - Internal: `Aabb2 servedTopOfEntry(SymbolEntry entry)` (`symbol_box.dart`).

Plan decisions:
- **The pending refs are the controller's, not each kit's services'.** Spec S2: "the services keep pending refs by key until the document holds the definition or the next `execute`". Two kits asking for one key (a cinema kit placing the restaurant kit's seat) must not get two copies of one definition, so the map lives in the controller and every `KitServices` reads it through `ServicesHost`. A ref is dropped when its handle is a live definition of the document (the `add` was executed, through `PlanController.execute` or straight through `document.commands`, as a tool's commit does); every `PlanController.execute` clears the map; so does a document swap (`_open`: the handles were the old document's).
- **Only a ref with an `add` is pending.** A ref whose definition the document already holds has nothing to execute and takes no handle; it is made afresh on each call.
- **`top` is computed from the library entry**, not the document: the `add` may not have executed yet, and a reused definition is leaf-equal to the entry (`isLeafEqual`, `symbol_placer.dart:198-227`), so both give the same box. The first leaf is the entry's lowest-handle leaf (`SymbolEntry.leaves` is ascending, asserted at `symbol_placer.dart:86`), the rule of today's `tableTopOf` (`jet_cad_floor_plan/lib/src/service/table_picker.dart:92-110`). "The definition's box" is `boxOfEntry`, the symbol box 2a's attachment uses.
- **The host's words reach every reader of a kit's words.** The spec names `KitNamesWords`; 2a also reads `kit.names` directly in four places: the panel's word lookup (`panels/kit_lookup.dart:29-33`), the kit section's words (`panels/plan_property_panel.dart:766`), the Symbol section's name (`:789-792`) and the palette's tool label (`editor/plan_tool_palette.dart:38-41`), and the gallery's names come from the loaded `PlanSymbol.names` (`symbols/plan_symbol_loader.dart:108`). A host overriding `tool:` or `symbol:` would otherwise see its word in a kit's tool and not in the palette. All of them read `namesOf` (the section takes the services' own `KitWords`); the loaded symbols are wrapped again with the merged names when the host gave words (and kept as loaded otherwise, so 2a's behaviour is byte for byte unchanged without words; the loader stays shareable across controllers with different words).
- **`SymbolsState` is re-exported by the plan library's barrel**, in `PlanSymbolsState`'s place, so a host reading `controller.symbolsState.value` imports the plan library alone, as today.

- [ ] **Step 1: The switchable `instances` in the box kit.** In `test/support/box_kit.dart`:
  1. `Switches`' doc (lines 24-31) lists `instances` among the per-object hooks: `` `reach`, `references`, `generate`, `instances`, `diagnose`, ... ``.
  2. In `SquareType`, after `generate` (line 165), add:

```dart
  /// No instance (E5's default), but switchable: a poisoned square's
  /// `instances` throws when `instances` is failing (2b Task 4).
  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    sw.check('instances', view.paramsOf<SquareParams>(self)!.poisoned);
    return const [];
  }
```

  2a's tests never switch `instances`, so the box kit's behaviour is unchanged for them.

- [ ] **Step 2: The `instances` guard tests (PB-guard; they pass at once, R-1).** Create `test/kits/guarded_instances_test.dart`:

```dart
// Spec 2b S1 "The output": 2a's GuardedType wraps E5's `instances` as it
// wraps `generate` (guard.dart): a throw is a KitHookFailure naming the hook
// `instances`, the engine rolls the edit back and `probe` returns it; through
// the controller, the boundary probes the type, freezes and locks the
// failing object, and the other objects still regenerate (2a P4, E2). The
// square sits off the origin, turned (box_kit.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart' show GuardedType;

import '../support/box_kit.dart';

/// A document with a page and a system over the guarded square
/// (guarded_type_test.dart's harness, the disc left out).
({DraftDocument doc, ParametricSystem system}) harness(Switches sw) {
  final d = DraftDocument.empty();
  PageComponent.register(d.components);
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, PageComponent(scaleDenominator: 50)));
  final catalog = ParametricCatalog()
    ..register<SquareParams>(SquareParams.id, SquareParams.fromJson,
        GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw)));
  final system = ParametricSystem(d, catalog)..install();
  return (doc: d, system: system);
}

Matcher failedInstances() => isA<KitHookFailure>()
    .having((f) => f.kitId, 'kitId', 'box')
    .having((f) => f.typeId, 'typeId', SquareParams.id)
    .having((f) => f.hook, 'hook', 'instances')
    .having((f) => f.error, 'error',
        isA<HookBoom>().having((b) => b.hook, 'hook', 'instances'));

List<KitDiagnostic> diagnosticsOf(PlanController c, KitDiagnosticCode code) => [
      for (final d in c.diagnostics.value)
        if (d.code == code) d
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const poisoned = SquareParams(side: 1200, poisoned: true);

  test(
      'PB-guard-1 a throwing instances is a KitHookFailure naming '
      '"instances": the edit rolled back, and probe returns it', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('instances');
    final before = canon(h.doc);
    final depth = h.doc.commands.undoDepth;
    // M-PB-guard-a: GuardedType.instances calling the delegate bare (the
    // raw HookBoom escapes). M-PB-guard-b: `_fail('generate', e, s)` in it.
    expect(
        () => h.doc.commands.execute(SetComponentCommand<SquareParams>(
            s, poisoned.copyWith(side: 900.5))),
        throwsA(failedInstances()));
    expect(canon(h.doc), before, reason: 'rolled back');
    expect(h.doc.commands.undoDepth, depth);
    expect(h.system.probe(s), failedInstances());
  });

  test(
      'PB-guard-2 through the controller: the object frozen and locked, one '
      'diagnostic naming the hook, its geometry kept, the other square '
      'still regenerated', () {
    final sw = Switches();
    final c = PlanController(kits: [boxKit(sw)]);
    addTearDown(c.dispose);
    final d = c.document;
    final broken = addObject(d, atSquare, poisoned);
    final other = addObject(
        d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final drawn = coordsOf(d, broken);
    sw.failing.add('instances');

    // The resize fails on the hook, the boundary probes the type, freezes
    // the broken square and retries: the retry touches a locked object.
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            broken, poisoned.copyWith(side: 900.5))),
        isFalse);
    expect(c.locked.value, {broken});
    expect(c.frozen, contains(broken));
    final failures = diagnosticsOf(c, KitDiagnosticCode.hookFailed);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject),
        ('box', SquareParams.id));
    expect(failures.single.message, startsWith('instances: '));
    expect(coordsOf(d, broken), drawn);

    final otherBefore = coordsOf(d, other);
    expect(
        c.execute(SetComponentCommand<SquareParams>(
            other, const SquareParams(side: 650.5))),
        isTrue);
    expect(coordsOf(d, other), isNot(otherBefore), reason: 'regenerated');
  });
}
```

- [ ] **Step 3: Run them (they pass: R-1).** `flutter test test/kits/guarded_instances_test.dart`. Expected: both tests pass. Task 1 added the forwarder (controller ruling R-1), so these tests pin existing code; the mutations M-PB-guard-a/b (Step 16) are what prove them.

- [ ] **Step 4: Check `GuardedType.instances` (no edit).** `lib/src/kits/guard.dart`, after `generate`, holds Task 1's forwarder (Task 1 Step 7), exactly:

```dart
  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    try {
      return inner.instances(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('instances', e, s);
    }
  }
```

  Run `flutter test test/kits/guarded_instances_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 5: The failing `symbolDefinition` tests (PB-def).** Create `test/controller/symbol_definition_test.dart`:

```dart
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

PlanKit pbKit() => symbolKit('pb', [
      SymbolLibrarySource(label: 'pb', read: () async => encodeLibrary(pbCatalog)),
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
    expect(identical(c.servicesOf('demo').symbolDefinition(table), one),
        isTrue);

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
```

- [ ] **Step 6: The failing host words tests (PB-words).** Create `test/controller/host_words_test.dart`:

```dart
// Spec 2b S4 "Words": PlanController(words:) checks a host's words
// (validateHostWords) and merges them before each kit's own, per locale: a
// host overrides a kit's word or adds a locale the kit lacks. Every reader
// of a kit's words reads them: the services, the panel's lookup, the
// gallery's names, the palette's labels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_tool_palette.dart'
    show planToolLabel;
import 'package:jet_cad_2d_plan/src/panels/kit_lookup.dart' show planWordOf;
import 'package:jet_cad_2d_plan/src/symbols/gallery_model.dart'
    show PlanSymbolWords;

import '../support/symbol_fixtures.dart';
import '../support/test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'PB-words-1 the host\'s word first, per locale: it overrides the '
      'kit\'s, the kit\'s own locale still beats the host\'s English, and a '
      'locale the kit lacks is the host\'s', () {
    final c = PlanController(kits: [
      testKit(),
      discKit()
    ], words: const KitNames({
      'en': {'type:test.slab': 'Floor slab'},
      'tr': {'tool:test.slab': 'Döşeme aracı'},
      'de': {'type:disc.round': 'Runde Scheibe'},
    }));
    addTearDown(c.dispose);
    final slab = c.servicesOf('test').words;
    final disc = c.servicesOf('disc').words;
    c.reportLocale(const Locale('tr'));
    // M-PB-W1: `kit.names.merge(words)` (the kit's word first).
    // M-PB-W2: the words ignored (KitNamesWords over kit.names).
    expect(slab.word('tool:test.slab'), 'Döşeme aracı');
    expect(slab.word('type:test.slab'), 'Döşeme',
        reason: "the kit's Turkish before the host's English");
    c.reportLocale(const Locale('en'));
    expect(slab.word('type:test.slab'), 'Floor slab');
    expect(slab.word('tool:test.slab'), 'Slab');
    c.reportLocale(const Locale('de'));
    expect(disc.word('type:disc.round'), 'Runde Scheibe');
    expect(disc.word('property:disc.round.radius'), 'Radius');
    expect(slab.word('type:test.slab'), 'Floor slab',
        reason: "no German: the host's English");
  });

  test(
      'PB-words-2 a host word in no known namespace, or naming no kit, is '
      'an ArgumentError naming the first problem; any kit is a kit', () {
    for (final (id, code) in [
      ('label:test.x', 'unknownWordId'),
      ('tool:slab', 'foreignWordId'),
    ]) {
      // M-PB-W3: the constructor not calling validateHostWords.
      expect(
          () => PlanController(kits: [
                testKit()
              ], words: KitNames({
                'en': {id: 'x', 'type:nokit': 'y'},
              })),
          throwsA(isA<ArgumentError>().having(
              (e) => '${e.message}',
              'message',
              allOf(contains('"$id"'), contains(code),
                  isNot(contains('type:nokit'))))),
          reason: id);
    }
    final c = PlanController(kits: [
      testKit()
    ], words: const KitNames({
      'en': {'tool:acme.wall': 'Wall'},
    }));
    addTearDown(c.dispose);
    expect(c.servicesOf('test').words.maybe('tool:acme.wall'), 'Wall',
        reason: "a word for a kit not loaded is sound, and merged");
  });

  test(
      'PB-words-3 the panel\'s word lookup and the gallery\'s symbol names '
      'read the host\'s words first', () async {
    final c = PlanController(kits: [
      testKit(),
      demoKit()
    ], words: const KitNames({
      'tr': {
        'property:test.slab.width': 'En',
        'symbol:demo.sofa.two': 'İkili koltuk',
      },
    }));
    addTearDown(c.dispose);
    c.reportLocale(const Locale('tr'));
    // M-PB-W4: planWordOf reading kit.names.
    expect(planWordOf(c, 'test', 'property:test.slab.width'), 'En');
    expect(planWordOf(c, 'test', 'property:test.slab.height'), 'Yükseklik');
    expect(c.namesOf('nokit'), isNull);
    await settle();
    // M-PB-W5: the loaded symbols kept with the kit's names only.
    expect(const PlanSymbolWords('tr').name(c.symbolById('demo.sofa.two@1')!),
        'İkili koltuk');
    expect(
        const PlanSymbolWords('tr').name(c.symbolById('demo.sofa.three@1')!),
        'Üçlü kanepe');
  });

  testWidgets('PB-words-4 the palette\'s label of a kit\'s tool',
      (tester) async {
    final c = PlanController(kits: [
      testKit()
    ], words: const KitNames({
      'en': {'tool:test.slab': 'Floor slab tool'},
    }));
    addTearDown(c.dispose);
    late String label;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      label = planToolLabel(context, c, 'test.slab');
      return const SizedBox();
    })));
    // M-PB-W6: planToolLabel reading kit.names.
    expect(label, 'Floor slab tool');
  });
}
```

  (`testKit`'s Turkish `property:test.slab.height` is `Yükseklik`, `test_kit.dart:522`; `demoNames`' Turkish `symbol:demo.sofa.three` is `Üçlü kanepe`, `symbol_fixtures.dart:191`.)

- [ ] **Step 7: Run them, expecting failure.** `flutter test test/controller/symbol_definition_test.dart test/controller/host_words_test.dart`. Expected: compile errors (`No named parameter with the name 'words'`, `The method 'namesOf' isn't defined`); with those two lines removed by hand, the symbol definition tests fail on Task 3's `UnimplementedError('KitServices.symbolDefinition (2b Task 4)')`. Put the lines back.

- [ ] **Step 8: `SymbolsState` replaces `PlanSymbolsState`.**
  1. `git rm packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart`.
  2. `lib/src/symbols/plan_symbol_loader.dart`: delete `import 'plan_symbols_state.dart';` (the file imports `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` whole); `PlanSymbolsState` → `SymbolsState` (lines 23, 112, 113).
  3. `lib/src/panels/plan_symbol_gallery.dart`: `import '../symbols/plan_symbols_state.dart';` → delete it, and add `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolsState;` after the `jet_cad_2d_flutter` import; `PlanSymbolsState` → `SymbolsState` (lines 173-176).
  4. `lib/src/controller/plan_controller.dart`: delete `import '../symbols/plan_symbols_state.dart';` (line 31; the file imports the kit's barrel whole); every `PlanSymbolsState` → `SymbolsState` (lines 349-350, 1038, 1059, 1075, 1078, 1088).
  5. `lib/jet_cad_2d_plan.dart`: delete line 69 (`export 'src/symbols/plan_symbols_state.dart' show PlanSymbolsState;`) and, after the `jet_cad_2d_flutter` export (lines 5-6), add:

```dart
export 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolsState;
```

  6. The tests: in `test/controller/symbols_controller_test.dart`, `test/controller/plan_controller_test.dart`, `test/symbols/plan_symbol_loader_test.dart`, `test/panels/symbol_section_test.dart`, `test/panels/plan_symbol_gallery_test.dart`, run `sed -i '' 's/PlanSymbolsState/SymbolsState/g' <file>` one file at a time (each imports the kit's or the plan library's barrel, which now carries `SymbolsState`). In `test/editor/plan_editor_test.dart` (line 22) and `test/editor/editor_words_test.dart` (line 25), delete `import 'package:jet_cad_2d_plan/src/symbols/plan_symbols_state.dart';`, add `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show SymbolsState;` after the `jet_cad_2d_flutter` import, and run the same `sed`. In `test/barrel_test.dart`, the Task 8 line's `'PlanSymbolsState'` → `'SymbolsState'`. No assertion changes beyond the enum's name.
  7. `grep -rn "PlanSymbolsState\|plan_symbols_state" packages/jet_cad_2d_plan` (from the root): no output.

- [ ] **Step 9: The served top.** In `lib/src/symbols/symbol_box.dart`, after `boxOfEntry` (line 128), add:

```dart
/// The served top of [entry] in its definition's coordinates (spec 2b S2,
/// `SymbolDefinitionRef.top`): its first leaf's box when that leaf is a
/// circle or a closed polyline (today's `tableTopOf`,
/// jet_cad_floor_plan/lib/src/service/table_picker.dart:92-110), else the
/// symbol's box ([boxOfEntry]); empty when no leaf draws. The entry's
/// leaves are ascending by handle, so the first is the lowest.
Aabb2 servedTopOfEntry(SymbolEntry entry) {
  final all = boxOfEntry(entry);
  final whole = all == null ? Aabb2.empty() : footprintOf(all);
  if (entry.leaves.isEmpty) return whole;
  final first = entry.leaves.first;
  final kind = first.record.kind;
  final served = kind == EntityKind.circle ||
      (kind == EntityKind.polyline && isClosedPolyline(first.payload));
  if (!served) return whole;
  final top = boxOfLeaves([(kind, first.payload)]);
  return top == null ? whole : footprintOf(top);
}
```

- [ ] **Step 10: The services.** In `lib/src/controller/services.dart`:
  1. Imports gain `import '../symbols/plan_symbol.dart';`, `import '../symbols/symbol_box.dart' show servedTopOfEntry;` and `import '../symbols/symbol_placer.dart' show definitionForEntry;`.
  2. `ServicesHost` gains:

```dart
  /// The loaded symbol `key@version`, or null.
  PlanSymbol? symbolById(String id);

  /// The controller's symbol libraries' state.
  ValueListenable<SymbolsState> get symbolsState;

  /// The refs whose `add` has not executed yet, by key: one map per
  /// controller, shared by every kit's services (spec 2b S2).
  Map<String, SymbolDefinitionRef> get pendingDefinitions;
```

  3. Task 3's two stubs in `KitServices` are replaced by:

```dart
  /// Spec 2b S2. A pending ref is handed out again until the document holds
  /// its definition (its `add` executed, by whatever path), the controller
  /// executes a command, or the document is replaced; a ref whose
  /// definition the document holds is made afresh, with no `add`.
  @override
  SymbolDefinitionRef? symbolDefinition(String key) {
    final pending = _host.pendingDefinitions;
    final document = this.document;
    final kept = pending[key];
    if (kept != null) {
      if (document.tree.definition(kept.handle) == null) return kept;
      pending.remove(key);
    }
    final entry = _host.symbolById(key)?.entry;
    if (entry == null) return null;
    final made = definitionForEntry(document, entry);
    final ref = SymbolDefinitionRef(
      handle: made.definition,
      add: made.commands.isEmpty
          ? null
          : CompoundCommand(made.commands, label: 'Add ${entry.symbol.name}'),
      basePoint: entry.definition.basePoint.clone(),
      top: servedTopOfEntry(entry),
    );
    if (ref.add != null) pending[key] = ref;
    return ref;
  }

  @override
  ValueListenable<SymbolsState> get symbolsState => _host.symbolsState;
```

- [ ] **Step 11: The controller.** In `lib/src/controller/plan_controller.dart`:
  1. `_Host` gains:

```dart
  @override
  PlanSymbol? symbolById(String id) => _c.symbolById(id);

  @override
  ValueListenable<SymbolsState> get symbolsState => _c._symbolsState;

  @override
  Map<String, SymbolDefinitionRef> get pendingDefinitions =>
      _c._pendingDefinitions;
```

  2. The factory gains the parameter `KitNames words = KitNames.empty,` (after `permissions`), its doc gains `/// [words] are the host's words (spec 2b S4): each kit reads them before its own, per locale; an id in no known namespace or naming no kit is an [ArgumentError] naming the first problem (`validateHostWords`).`, and right after `final set = validateKitSet(kits);`:

```dart
    final wordProblems = validateHostWords(words);
    if (wordProblems.isNotEmpty) {
      throw ArgumentError.value(words, 'words', '${wordProblems.first}');
    }
```

     The `return PlanController._(...)` call passes `words: words`; `PlanController._` gains `required KitNames words` and the initializer `_hostWords = words`.
  3. The members, beside `_services`:

```dart
  /// The host's words (spec 2b S4).
  final KitNames _hostWords;

  /// Each loaded kit's words with the host's first, per locale.
  late final Map<String, KitNames> _names = {
    for (final kit in kits.kits) kit.id: _hostWords.merge(kit.names),
  };

  /// The words of the loaded kit [kitId], the host's first (spec 2b S4);
  /// null for a kit that is not loaded. Every reader of a kit's words reads
  /// them here or through its services.
  @internal
  KitNames? namesOf(String kitId) => _names[kitId];

  /// The refs `symbolDefinition` handed out whose `add` has not executed
  /// (spec 2b S2): cleared by [execute] and by a document swap.
  final Map<String, SymbolDefinitionRef> _pendingDefinitions = {};
```

  4. The services (line 192-196) read the merged words:

```dart
    _services = {
      for (final kit in kits.kits)
        kit.id: KitServices(
            kit, _host, KitNamesWords(_names[kit.id]!, () => _locale.value)),
    };
```

  5. `execute`'s body starts with `_pendingDefinitions.clear();` (before its `try`), and its doc gains `/// Drops the pending symbol definitions (spec 2b S2).`.
  6. `_open`'s body starts with `_pendingDefinitions.clear();`.
  7. In `_loadSymbols`, lines 1092-1093 become:

```dart
    _symbols = _named(load.symbols);
    _symbolsById = {for (final s in _symbols) s.id: s};
```

     and after `_loadSymbols` add:

```dart
  /// [symbols] named with the host's words first (spec 2b S4): each wrapped
  /// again with its kit's merged words; as loaded when the host gave none
  /// (a loader may serve several controllers).
  List<PlanSymbol> _named(List<PlanSymbol> symbols) => _hostWords.words.isEmpty
      ? symbols
      : List.unmodifiable([
          for (final s in symbols)
            PlanSymbol(
                kitId: s.kitId,
                names: _names[s.kitId] ?? s.names,
                entry: s.entry),
        ]);
```

- [ ] **Step 12: The other readers of a kit's words.**
  1. `lib/src/panels/kit_lookup.dart`, `planWordOf` (lines 27-33):

```dart
/// [wordId] of kit [kitId] in the controller's locale, else English, else
/// null (`KitNames.word`), the host's words first (spec 2b S4).
String? planWordOf(PlanController controller, String kitId, String wordId) =>
    controller
        .namesOf(kitId)
        ?.word(controller.locale.value.languageCode, wordId);
```

  2. `lib/src/panels/plan_property_panel.dart`: line 766's `KitNamesWords(c.kits.kitOf(kit)!.names, () => c.locale.value)` → `c.servicesOf(kit).words` (the kit's one `KitNamesWords`, over the merged words); lines 789-792's `c.kits.kitOf(kitOfKey(component.key))?.names.symbolName(...)` → `c.namesOf(kitOfKey(component.key))?.symbolName(_strings.languageCode, component)`. If `KitNamesWords` is then no longer used in the file, delete what the analyzer reports as unused, nothing else.
  3. `lib/src/editor/plan_tool_palette.dart`, `planToolLabel`'s last arm (lines 38-41):

```dart
    _ => controller
            .namesOf(kitOfKey(toolId))
            ?.word(controller.locale.value.languageCode, 'tool:$toolId') ??
        toolId,
```

- [ ] **Step 13: Run the tests.** `cd packages/jet_cad_2d_plan && dart format . && flutter test test/kits/guarded_instances_test.dart test/controller/symbol_definition_test.dart test/controller/host_words_test.dart`. Expected: `All tests passed!`. Then `flutter test`. Expected: `All tests passed!` (2a's tests unchanged but for the enum's name and the barrel's list).

- [ ] **Step 14: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_plan && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. If `flutter analyze` reports an import of this task as unnecessary or unused, delete that import line; change nothing else to quiet it.
  - `git status --short`: only this task's files, `plan_symbols_state.dart` as `D` (no `analysis_options.yaml`).

- [ ] **Step 15: Commit.** (`plan_symbols_state.dart`'s deletion is already staged by Step 8's `git rm`; naming it in `git add` would fail with `pathspec … did not match any files`.)

```bash
git add packages/jet_cad_2d_plan/lib/src/controller/services.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart packages/jet_cad_2d_plan/lib/src/symbols/plan_symbol_loader.dart packages/jet_cad_2d_plan/lib/src/panels/plan_symbol_gallery.dart packages/jet_cad_2d_plan/lib/src/panels/kit_lookup.dart packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/lib/src/editor/plan_tool_palette.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/box_kit.dart packages/jet_cad_2d_plan/test/kits/guarded_instances_test.dart packages/jet_cad_2d_plan/test/controller/symbol_definition_test.dart packages/jet_cad_2d_plan/test/controller/host_words_test.dart packages/jet_cad_2d_plan/test/controller/symbols_controller_test.dart packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart packages/jet_cad_2d_plan/test/symbols/plan_symbol_loader_test.dart packages/jet_cad_2d_plan/test/panels/symbol_section_test.dart packages/jet_cad_2d_plan/test/panels/plan_symbol_gallery_test.dart packages/jet_cad_2d_plan/test/editor/plan_editor_test.dart packages/jet_cad_2d_plan/test/editor/editor_words_test.dart packages/jet_cad_2d_plan/test/barrel_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the 2b plumbing: instances guarded, symbol definitions, host words

GuardedType wraps E5's instances hook like generate, so a throwing
instances freezes and locks its object. The kits' services answer
symbolDefinition through the symbol placer, keeping one pending ref per
key until its add executes, and expose the controller's symbolsState,
now the contract's SymbolsState. PlanController takes a host's words,
checks them, and every reader of a kit's words reads the host's first.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 16: Mutation check** (committed files only; after each: run `cd packages/jet_cad_2d_plan && flutter test <the named test's file>`, see the named test red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-PB-guard-a `lib/src/kits/guard.dart`: `instances`' body → `return inner.instances(view, self);` (no `try`) → PB-guard-1 and PB-guard-2 red.
  - M-PB-guard-b `guard.dart`: `_fail('instances', e, s)` → `_fail('generate', e, s)` → PB-guard-1 red (and PB-guard-2's `startsWith('instances: ')`).
  - M-PB1 `lib/src/controller/services.dart`: delete `if (ref.add != null) pending[key] = ref;` → PB-def-twice red.
  - M-PB2 `services.dart`: add a field `final Map<String, SymbolDefinitionRef> _pending = {};` to `KitServices` and read `final pending = _pending;` instead of `_host.pendingDefinitions` → PB-def-twice red (the demo services' call).
  - M-PB3 `services.dart`: `if (document.tree.definition(kept.handle) == null) return kept;` → `return kept;` (the `remove` then unreachable; delete it) → PB-def-twice red.
  - M-PB4 `lib/src/controller/plan_controller.dart`: delete `_pendingDefinitions.clear();` at the start of `execute` → PB-def-execute red.
  - M-PB5 `plan_controller.dart`: delete `_pendingDefinitions.clear();` at the start of `_open` → PB-def-execute red (after `newPlan`).
  - M-PB6 `lib/src/symbols/symbol_box.dart`: `servedTopOfEntry`'s `if (!served) return whole;` → `return whole;` (the rest unreachable; delete it) → PB-def-top red.
  - M-PB7 `symbol_box.dart`: `final served = kind == EntityKind.circle || (...);` → `const served = true;` → PB-def-top red (the shelf).
  - M-PB8 `services.dart`: `symbolsState => _host.symbolsState` → `symbolsState => ValueNotifier(SymbolsState.ready)` → PB-def-null red.
  - M-PB-W1 `plan_controller.dart`: `_hostWords.merge(kit.names)` → `kit.names.merge(_hostWords)` → PB-words-1 red.
  - M-PB-W2 `plan_controller.dart`: `KitNamesWords(_names[kit.id]!, ...)` → `KitNamesWords(kit.names, ...)` → PB-words-1 red.
  - M-PB-W3 `plan_controller.dart`: delete the `wordProblems` check (three lines) → PB-words-2 red.
  - M-PB-W4 `lib/src/panels/kit_lookup.dart`: `controller.namesOf(kitId)?.word(...)` → `controller.kits.kitOf(kitId)?.names.word(...)` → PB-words-3 red.
  - M-PB-W5 `plan_controller.dart`: `_symbols = _named(load.symbols);` → `_symbols = load.symbols;` → PB-words-3 red.
  - M-PB-W6 `lib/src/editor/plan_tool_palette.dart`: `controller.namesOf(kitOfKey(toolId))?.word(...)` → `controller.kits.kitOf(kitOfKey(toolId))?.names.word(...)` → PB-words-4 red.

  Not mutation-tested, by reading: the property panel's two re-pointed reads (Step 12.2), which only route through `servicesOf(kit).words` and `namesOf`, both pinned above. Quote each red line.

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 1: `ParametricType.instances` and `GeneratedInstance` exported from `package:jet_cad_2d/jet_cad_2d.dart`; `ParametricSystem.probe` and an edit's regeneration call `instances` for every non-dissolving object of the closure, so a throwing `instances` fails the edit and the probe (spec S1).
- Task 3: `SymbolsState`, `SymbolDefinitionRef` (const constructor with `handle`, `add`, `basePoint`, `top`), `PlanServices.symbolDefinition`/`symbolsState`, `validateHostWords` (its problems' `toString` is `'<code>: <message>'`, the message naming the word id in quotes), and the two `UnimplementedError` stubs in `controller/services.dart` that Step 10 replaces.
- Task 1 (controller ruling R-1): `GuardedType.instances` is already in `guard.dart`, exactly as Step 4 quotes it.

---

