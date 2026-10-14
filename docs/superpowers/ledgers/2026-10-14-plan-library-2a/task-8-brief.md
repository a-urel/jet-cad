### Task 8: `PlanController`, its core (spec P1 "PlanServices" and lifetimes, P2 "PlanController", "Events", "Documents and views")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`, `session.dart`, `plan_change.dart`, `services.dart`, `shared_cache.dart`, `grip_dispatch.dart`, `tool_settings_store.dart`, `diagnostics_log.dart`, `new_plan.dart`, `camera_bounds.dart` (all under `lib/src/controller/`); `packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart`; `packages/jet_cad_2d_plan/lib/src/export/registries.dart` (the exporter and importer interfaces only; **Task 19 extends this file**, it does not create it)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (exports), `packages/jet_cad_2d_plan/test/support/harness.dart` (adds `controllerFor`, `slabPlanText`, `slabsOf`, `setSlabWidth`)
- Test: `packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart`, `locale_separator_test.dart`, `camera_test.dart`, `lifetimes_test.dart`, `covariance_test.dart`, `plan_change_test.dart` (all under `test/controller/`)

**Interfaces:**
- Consumes: `KitSet`, `validateKitSet`, `KitSetError` (Task 6); `decodePlan`, `encodePlan`, `manifestOf`, `usedKits`, `checkManifest`, `PlanFormatException` (Task 7); the test kit API and `planText` (Tasks 6-7). Contract (Tasks 3-4): `PlanKit`, `PlanType<T>` (`id`, `registerInto(ParametricCatalog, {TypeGuard? guard})`, `gripsFor(PlanServices)`, `fieldsOf`, `commitField`, `colourOf`, `recolour`), `PlanTool` (`id`, `settings`, `create`), `PlanToolSettings` (`initial`, `fieldsOf(Object value, void Function(Object) store, {required String toolId})`), `PlanServices`, `KitWords`, `KitNamesWords(KitNames names, Locale Function() locale)`, `AttachmentRegistry`, `AttachmentQuery`, `Attachment`, `KitDiagnostic`, `KitDiagnosticCode`, `PropertyField`, `registerKitComponents`, `Disposable` (Task 4, `plan_services.dart`). Engine (Tasks 1-2): `ParametricCatalog.typeIdOf(CommandTarget, Handle)` (E1), `ParametricSystem(document, catalog, {isFrozen})` (E2). Flutter layer: `CameraController`, `SelectionController`, `SelectionKey`, `OutlineCache`, `GripCache` (`objects`), `ObjectGripProvider`, `ToolController`, `ToolContext`, `SelectTool`, `PageNotifier`, `SnapSettings`, `SymbolThumbnails`, `FlutterTextMeasurer`, `ViewportTransform`, `fitToPage`.
- Produces (exported from the barrel):
  - `class PlanController extends ChangeNotifier`:
    - `factory PlanController({required List<PlanKit> kits, String? json, SymbolThumbnails? thumbnails, List<PlanExporter> exporters = const [], List<PlanImporter> importers = const [], double minScale = kPlanMinScale, double maxScale = kPlanMaxScale})` — throws `KitSetError` (an `ArgumentError`), an `ArgumentError` for the zoom bounds, or a `PlanFormatException` for `json`, before it builds anything. `exporters` and `importers` are stored, in order (Task 19 implements the flows and the built-in `plan.pdf`, `plan.png`). **Later tasks add named parameters** as their types appear: `permissions` (Task 12), `symbols` (Task 13).
    - the plan: `KitSet get kits`, `DraftDocument get document`, `void newPlan({String? decimalSeparator})` (`'.'` or `','`, else `ArgumentError`), `void load(String text)`, `String save()`, `ValueListenable<bool> get dirty`, `void markSaved()`.
    - undo: `void undo()`, `void redo()`, `ValueListenable<bool> get canUndo`, `ValueListenable<bool> get canRedo`.
    - tools and selection: `bool selectTool(String id)`, `ValueListenable<String> get activeTool` (a tool id; `'plan.select'` after construction and after every swap), `bool deleteSelection()`.
    - objects: `PlanType<Component>? typeOf(Handle object)` (E1).
    - events: `Stream<PlanChange> get changes`.
    - camera: `CameraController get camera`, `void panBy(Offset)`, `bool zoomBy(double factor, {Offset? focus})`, `void centerOn(Offset world, {double? scale})`, `void fitToView()`, `ValueListenable<Rect?> get canvasRect`.
    - state: `ValueListenable<Locale> get locale`, `ValueListenable<List<KitDiagnostic>> get diagnostics`, `Set<String> get missingKits`, `ValueListenable<PlanSymbolsState> get symbolsState` (always `ready` until Task 13), `SymbolThumbnails get thumbnails`.
    - `@internal` seams for the widgets and later tasks: `ToolController get toolController`, `List<PlanExporter> get exporters`, `List<PlanImporter> get importers`, `ToolContext get toolContext`, `SelectionController get selection`, `SpatialIndex get index`, `PageNotifier get page`, `GripCache get grips`, `OutlineCache get outlines`, `SnapSettings get snap` (the user's F3 setting; the tools read the effective one), `bool snappingAllowed` (the canvas's `snapping` option, Task 15), `ToolSettingsStore get toolSettings`, `ParametricCatalog get catalog`, `ParametricSystem get parametric` (Task 11's probe), `Set<Handle> get frozen` (E2's set, empty until Task 11), `List<Diagnostic> get loadDiagnostics` (the engine's, kept, Task 11), `DiagnosticsLog get diagnosticsLog` (Task 11 reports into it), `PlanServices servicesOf(String kitId)`, `Tool? toolFor(String id)`, `VoidCallback registerSettle(VoidCallback settle)`, `void settlePendingInput()`, `void reportLocale(Locale locale)` (Task 9's `PlanLocaleScope`; Task 9 adds `{PlanStrings? strings}` and the last reported strings, controller ruling on NS7), `void canvasPlaced(Object view, Rect? global)`, `int get cameraEpoch`, `Listenable get fitRequests`, `bool takeFitOnStart()`, `bool get owesFirstFit`, `void fitted()`, `ViewportTransform? framingFor(Size viewport)` (Task 15's canvas); `@visibleForTesting int get debugChangeScans`.
  - `sealed class PlanChange` — `PlanObjectAdded(Handle object)`, `PlanObjectChanged(Handle object)`, `PlanObjectRemoved(Handle object)`, `PlanReplaced()`; value equality.
  - `enum PlanSymbolsState { loading, ready, failed }`.
  - `abstract interface class PlanExporter { String get id; String get extension; String get mimeType; Future<Uint8List> export(PlanExportRequest request); }`, `abstract interface class PlanImporter { String get id; List<String> get extensions; Future<String> import(Uint8List bytes); }` (the Shared interfaces' signatures), and `final class PlanExportRequest` with spec P5's `document`, `page`, `omitted` (Task 19 adds `choice` and `fonts`, whose types are its own).
  - `const double kPlanMinScale = 0.001`, `const double kPlanMaxScale = 100.0`, `const int kPlanThumbnailCapacity = 128`.
  - internal (not exported): `DocumentSession` (one document and its views), `KitServices` (`PlanServices`, one per kit per controller), `ServicesHost`, `NoAttachments` (the registry until Task 14), `EffectiveSnap`, `SharedCache`, `GripDispatch` (`ObjectGripProvider` by `typeIdOf`), `ToolSettingsStore`, `DiagnosticsLog` (append and `clearPlanScoped`; Task 11 adds the dedupe), `PlanChangeTracker`, `rootObjectOf`, `rootObjects`, `diffObjects`, `newPlanDocument`, `defaultPlanPage`, `decimalSeparatorFor(Locale)`, `clampCameraScale`, `planSelectToolId`.
  - harness: `PlanController controllerFor({required List<PlanKit> kits, String? json, double minScale = kPlanMinScale, double maxScale = kPlanMaxScale})` (disposed at tear-down), `String slabPlanText()` (two slabs off the origin, turned, and a line, over `[testKit()]`), `List<Handle> slabsOf(DraftDocument d)`, `void setSlabWidth(PlanController c, Handle slab, double width)`.

**Ports** (copied and adapted, never imported; the old files are untouched):
- `jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart`, design half only:
  - the factory and its checks `:275-310` → `PlanController` factory: `symbolSources`/`symbols` dropped (Task 13), `validateKitSet` and the catalog first, `_decode` → `decodePlan` (which throws `PlanFormatException` itself: no re-wrapping into `FormatException('Not a floor plan: ...')`), `newDocument` → `newPlanDocument`.
  - the private constructor `:312-334`, `_placeNominally` and `_pageFit` `:340-356`: as they are, over `document`.
  - the canvas rect and its reports `:419-489`: one canvas, so `_canvasIn` and the mode are dropped; `worldToGlobal`/`globalToWorld` are not ported here (Task 15, with the canvas).
  - the camera epoch and the fit flags `:491-526`, `:812-836`, `framingFor` and `_centred` `:838-893` (the `_Tables` target dropped: `fitToTables` is 2b), `fitToView`, `_request`, `centerOn`, `panBy`, `zoomBy`, `_command` `:1966-2060`: as they are, `cameraController` → `camera`.
  - the language `:998-1045` (`_unsettled`, `_untouched`, `reportLanguage`): `reportLanguage(FloorPlanStrings)` → `reportLocale(Locale)`, `documentSeparatorFor(strings)` → `decimalSeparatorFor(locale)` (Task 9 makes it read `PlanStrings`, which gives the same answers for `en`, `de`, `tr`).
  - the settle `:1058-1067`, `:1085-1088`: one registrar → a list of settles (the panels and the text tool each register one; spec P1 lifetimes).
  - `designJson`, `markSaved`, `load`, `newPlan`, `_replaceDesign` `:1172-1252`: `designJson` → `save` (through `encodePlan`); the service copy, the mode, `_revision` and the table baseline dropped (2b); `newPlan` takes `decimalSeparator`; `_replaceDesign` → `_replace`, which also cancels the tool, disposes the kit products and runs the factories (spec P1 lifetimes).
  - `undo` and `redo` `:1407-1423`: `_editorMidShape` → `_midShape` (the controller owns the tool controller); `_announceLayout` dropped (2b).
  - `selectTool`/`deleteSelection` `:690-714` with the shell's `_activate` (`planner_shell.dart:926-933`) and `_deleteByHost` (`:960`): by tool id; the capability check is `_allowsTool`, always true until Task 12.
  - `_attach`, `_refreshFlags`, `_drop`, `dispose` `:2098-2174`: per `DocumentSession`.
- `jet_cad_floor_plan/lib/src/planner_shell.dart`: the views' construction `:277-280` (document, page, index), `:428-437` (the select tool: no move resolver until Task 14, no gates until Task 12), `:625-671` (selection, outline cache, grip cache with one `GripDispatch` for `ObjectGrips`, tool context, tool controller), `:1050-1057` (the parametric system installed last; `DocumentSystems` and its two-shells trap are not ported, spec P2), `:859-865` (`_settlePendingInput`: the registered settles, then `applyFocusChangesIfNeeded`), `:1759-1776` (`_CapabilitySnap` → `EffectiveSnap`), and the disposal `:1114-1170` (`DocumentSession.dispose`).
- `jet_cad_floor_plan/lib/src/new_document.dart:18-56` → `new_plan.dart`: without `ensureDashedLinetype` (the separator's DASHED record is sub-project 3's) and with the registration passed in.
- `jet_cad_floor_plan/lib/src/camera_bounds.dart:1-36` → `controller/camera_bounds.dart`, whole; `startup_plan.dart:50-51` (`kMinScale`, `kMaxScale`) → `kPlanMinScale`, `kPlanMaxScale`. **Task 15 reuses this file and does not port `camera_bounds.dart` again.**

**Ported tests** (assertions unchanged where their semantics carry; each departure is listed):
- `jet_cad_floor_plan/test/host/controller_test.dart`: C8 → C3 (the service-mode lines `setMode`, `select`, `move`, `selectedTables` go to 2b; a table's transform → a slab's), C9 → C4 (`designJson` → `save`), C11 → C5 (`tables` → the plan's slabs: `isEmpty`, then `hasLength(2)` for the fixture's two), C12 → C6 and the second half of C2 (`FloorPlanController(json: '{"entities": 7}')` → `PlanController(kits: [testKit()], json: ...)`).
- `jet_cad_floor_plan/test/host/new_plan_separator_test.dart`: NS1, NS3, NS4, NS6, NS8, NS9, with the view replaced by `reportLocale` (what the view reports; Task 9's `PlanLocaleScope` reports it). Departures: the `panelShows` assertions (they need the Page panel in a view) go to Task 20's `editor_separator_test.dart`, and `serviceLayoutChanges` (2b) is left out; NS3's room-label assertion moves with the room type (sub-project 3); `designJson()` → `save()`. NS2 (a view handed another controller) is Task 20's (`PlanEditor`); NS5 is 2b's; NS7a and NS7 (a host's own language class settling the separator; kept by controller ruling) are Task 9's.
- `jet_cad_floor_plan/test/host/camera_test.dart`: CM4, CM5 (its first half; the second needs a mounted view, Task 15), CM6 and CM15, with the mount replaced by `canvasPlaced` (the report a mounted canvas makes) and `embeddingCamera()` inlined.
- `jet_cad_floor_plan/test/host/design_changes_test.dart` speaks of tables (`FloorPlanTableDetail`); `PlanChange` speaks of objects, so its cases are **re-expressed**, not ported: DC8 → C-ch2, DC9 → C-ch3, DC11 → C-ch4, DC12 and DC18 → C-ch5, DC17 → C-ch6, DC19 → C-ch7, DC13 → C-ch8. Their table-detail assertions belong to 2b.

Plan decision: an **object** is a root-level element: a group or an instance whose parent is the root, or an entity the root owns. `changes` reports, per synchronous step, the objects added, changed and removed, in ascending handle order (draw order), resolved when the step's report is delivered: a touched handle that is part of an object counts for that object. A page change (the root) is no object's. `load`, `newPlan` and `import` first report what the replaced plan still owes, then `PlanReplaced()` alone; a failed load reports nothing and drops nothing owed. Nothing is read while nothing listens (`debugChangeScans`).
Plan decision: the change tracker sees every mutation synchronously by stacking on the dispatcher's `onAfterMutate`, which the spatial index owns (`spatial_index.dart:162-174`), as `TableLabelSystem` stacks on the expander (`table_label_system.dart:27-48`): it keeps the index's callback, calls it first, and restores it before the index is disposed. That is what lets a swap report the old plan's owed changes synchronously, before `PlanReplaced`, as today's `_reportDesign` does (`floor_plan_controller.dart:1226`).
Plan decision: a swap disposes the old document's **kit products** (its kit tools, its grip and attachment providers, its `shared` cache) at once, in that order (spec P1 lifetimes, 2), and the factories then run over the new document (3). The engine and Flutter-layer objects of the old document (its views, index, system, the document itself) are disposed after the next frame, as today's `_drop` (`floor_plan_controller.dart:2127-2135`): a mounted canvas still holds them until it rebuilds. The old grip dispatch is closed at once, so no old view reaches a disposed provider.
Plan decision: the tool settings are the controller's (spec P3: "the controller holds one value of S per tool") and survive a swap; today's shell-owned settings were per document only because the shell was.
Plan decision: `PlanServices.settingsOf` answers only the asking kit's own tools (another kit's tool id is an `ArgumentError`): kits cooperate only through the contract (umbrella A1).
Plan decision: `PlanServices.shared` refuses a `create` that asks for the same `(kit, type)` while it is being made (`StateError`), instead of recursing.
Plan decision: diagnostics of the plan (`kitMissing`, `kitNewer`, `componentUnreadable`, `rollbackFailed`, `damagedUnsavable`) are cleared at each swap; the kit set's (`letterTaken`, the symbol library's, `attachmentKindUnoffered`, `hookFailed`) stay. `DiagnosticsLog` lives in `lib/src/controller/diagnostics_log.dart` (not in `kits/guard.dart` as the file structure sketches); Task 11 extends it there.
Plan decision: `missingKits` is a plain getter: it changes only at a swap, which notifies the controller's listeners.

- [ ] **Step 1: The harness.** In `packages/jet_cad_2d_plan/test/support/harness.dart` add the import `import 'test_kit.dart';` and, at the end:

```dart
/// A controller over [kits] (and [json]), disposed at tear-down.
PlanController controllerFor(
    {required List<PlanKit> kits,
    String? json,
    double minScale = kPlanMinScale,
    double maxScale = kPlanMaxScale}) {
  final c = PlanController(
      kits: kits, json: json, minScale: minScale, maxScale: maxScale);
  addTearDown(c.dispose);
  return c;
}

/// A saved plan over `[testKit()]`: a slab 1800 x 900 turned 0.4 rad at
/// (-2600, 1400), tiled; a slab 1200 x 700 turned -1.1 rad at (2300,
/// 1400); a line.
String slabPlanText() => planText([testKit()], (d) {
      addObject<SlabComponent>(
          d, SlabComponent(width: 1800, height: 900, angle: 0.4, finish: 'tiled'),
          at: Vector2(-2600, 1400));
      addObject<SlabComponent>(
          d, SlabComponent(width: 1200, height: 700, angle: -1.1),
          at: Vector2(2300, 1400));
      addLine(d, Vector2(-500, 700), Vector2(1800, 2400));
    });

/// [d]'s slabs, ascending.
List<Handle> slabsOf(DraftDocument d) =>
    d.components.withComponent<SlabComponent>().toList();

/// One edit: [slab]'s width set to [width].
void setSlabWidth(PlanController c, Handle slab, double width) {
  final s = c.document.components.get<SlabComponent>(slab)!;
  c.document.commands.execute(
      SetComponentCommand<SlabComponent>(slab, s.copyWith(width: width)));
}
```

- [ ] **Step 2: Write the failing tests.** Create `packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart`:

```dart
// Spec 2a P2 "PlanController": the plan (newPlan, load, save, dirty,
// markSaved), undo and redo, tools by id, deleteSelection, the settle, and
// the manifest's report. C3-C6 are jet_cad_floor_plan's controller_test.dart
// C8, C9, C11 and C12 (design half), assertions unchanged; a slab of the
// test kit stands in for a table.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

/// A design edit: a line (controller_test.dart's drawLine).
void drawLine(PlanController c) =>
    addLine(c.document, Vector2(-500, 700), Vector2(1800, 2400));

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Transform2 transformOf(DraftDocument d, Handle h) =>
    (d.tree[h]! as GroupNode).transform;

void main() {
  testWidgets(
      'C1 a new plan: the default page off the origin, millimetres, clean, '
      'no history, select armed, nothing missing', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final d = c.document;
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    expect(page.originX, -7425);
    expect(page.originY, -5250);
    expect(page.scaleDenominator, 50);
    // M-C1a: the units not set.
    expect(d.header.units, DrawingUnits.millimeters);
    // M-C1b: the history not cleared.
    expect(d.commands.canUndo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    expect(c.activeTool.value, 'plan.select');
    expect(c.missingKits, isEmpty);
    expect(c.symbolsState.value, PlanSymbolsState.ready);
    expect(c.diagnostics.value, isEmpty);
    expect(manifestOf(d), isNull, reason: 'a new plan has none until saved');
    await tester.pump();
  });

  testWidgets(
      'C2 a bad kit set or a bad plan throws before anything is built; a bad '
      'json at construction is a FormatException (C12, review F-5)',
      (tester) async {
    expect(() => PlanController(kits: [testKit(), testKit()]),
        throwsA(isA<KitSetError>()));
    // M-C2: the factory opens an empty plan when the json does not decode.
    expect(() => PlanController(kits: [testKit()], json: '{"entities": 7}'),
        throwsFormatException);
    expect(
        () => PlanController(kits: [testKit()], json: 'not json'),
        throwsA(isA<PlanFormatException>()
            .having((e) => e.code, 'code', PlanFormatCode.notJson)));
  });

  testWidgets(
      'C3 a bad plan changes nothing: broken structure, unknown schema, no '
      'manifest (C8, M-14b2-8)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final slab = slabsOf(c.document).first;
    final moved = parts(transformOf(c.document, slab));
    final document = c.document;
    final good = jsonDecode(slabPlanText()) as Map<String, Object?>;
    final broken = jsonEncode({...good, 'entities': 7});
    final future = jsonEncode({...good, 'schemaVersion': 9999});
    // M-C3: a load that does not decode opens an empty plan.
    for (final bad in [broken, future, '{}']) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.document, same(document));
    expect(parts(transformOf(c.document, slab)), moved);
    await tester.pump();
  });

  testWidgets('C4 markSaved marks the state the last save encoded (C9, '
      'M-14b2-14)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    c.save();
    drawLine(c); // lands while the host writes
    // M-C4: markSaved takes the current state.
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isTrue);
    c.save();
    c.markSaved();
    await tester.pump();
    expect(c.dirty.value, isFalse);
  });

  testWidgets('C5 newPlan is empty and clean; load of a plan is clean (C11)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    await tester.pump();
    expect(c.dirty.value, isTrue);
    // M-C5: the save point not moved by a swap.
    c.newPlan();
    await tester.pump();
    expect(slabsOf(c.document), isEmpty);
    expect(c.dirty.value, isFalse);
    c.load(slabPlanText());
    expect(slabsOf(c.document), hasLength(2));
    await tester.pump();
  });

  testWidgets("C6 a load forgets the last save's state (C12, review m31)",
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    drawLine(c);
    drawLine(c);
    drawLine(c);
    c.save(); // state 3 of the old plan
    c.load(slabPlanText());
    drawLine(c);
    // M-C6: the encoded state kept across a load.
    c.markSaved(); // the new plan's current state
    await tester.pump();
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'C7 a load reports the kits it names that are not loaded and a newer '
      'kit; a save keeps the missing entry; a new plan clears both',
      (tester) async {
    final json = jsonDecode(slabPlanText()) as Map<String, Object?>;
    final components = json['components']! as Map<String, Object?>;
    (components['jetcad.manifest']! as Map<String, Object?>)['${json['root']}'] = {
      'format': 1,
      'kits': {'gone': '3.1.0', 'test': '9.0.0'},
    };
    final c =
        controllerFor(kits: [testKit(version: '1.2.0')], json: jsonEncode(json));
    // M-C7a: the manifest not checked at a load.
    expect(c.missingKits, {'gone'});
    expect([for (final d in c.diagnostics.value) (d.kitId, d.code)], [
      ('gone', KitDiagnosticCode.kitMissing),
      ('test', KitDiagnosticCode.kitNewer),
    ]);
    final saved = jsonDecode(c.save()) as Map<String, Object?>;
    expect(
        ((saved['components']! as Map<String, Object?>)['jetcad.manifest']!
            as Map<String, Object?>)['${saved['root']}'],
        {
          'format': 1,
          'kits': {'gone': '3.1.0', 'test': '1.2.0'},
        });
    c.newPlan();
    expect(c.missingKits, isEmpty);
    // M-C7b: the plan's diagnostics kept across a swap.
    expect(c.diagnostics.value, isEmpty);
    await tester.pump();
  });

  testWidgets(
      'C8 undo and redo act on the plan, and do nothing while a tool is '
      'part-way through a shape', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    drawLine(c);
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')!;
    tool.onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    expect(tool.isMidShape, isTrue, reason: 'premise');
    final state = c.document.commands.stateId;
    // M-C8: the mid-shape check removed from undo (and redo).
    c.undo();
    expect(c.document.commands.stateId, state);
    c.redo();
    expect(c.document.commands.stateId, state);
    tool.cancel(c.toolContext);
    c.undo();
    expect(c.document.commands.canUndo, isFalse);
    c.redo();
    expect(c.document.commands.canUndo, isTrue);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
    expect(c.canRedo.value, isFalse);
  });

  testWidgets(
      'C9 selectTool by id: a kit tool clears the selection; select; an '
      'unknown id; a drawing tool refused while geometry is denied',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    c.selection.replace([SelectionKey.root(slabsOf(c.document).first)]);
    expect(c.selectTool('test.slab'), isTrue);
    expect(c.activeTool.value, 'test.slab');
    // M-C9a: a drawing tool keeps the selection.
    expect(c.selection.isEmpty, isTrue);
    expect(c.selectTool('nope.tool'), isFalse);
    expect(c.activeTool.value, 'test.slab');
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.activeTool.value, 'plan.select');
    c.document.commands.permissions = DraftPermissions.runtime;
    // M-C9b: the geometry check removed.
    expect(c.selectTool('test.slab'), isFalse);
    expect(c.activeTool.value, 'plan.select');
    await tester.pump();
  });

  testWidgets(
      'C10 deleteSelection: false with nothing selected and while a shape is '
      'part-way; otherwise one undo step', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    expect(c.deleteSelection(), isFalse);
    final slab = slabsOf(c.document).first;
    c.selection.replace([SelectionKey.root(slab)]);
    final depth = c.document.commands.undoDepth;
    expect(c.deleteSelection(), isTrue);
    expect(c.document.tree[slab], isNull);
    expect(leavesOf(c.document, slab), isEmpty);
    expect(c.document.commands.undoDepth, depth + 1);
    c.undo();
    expect(c.document.tree[slab], isNotNull);
    expect(c.selectTool('test.slab'), isTrue);
    c.toolFor('test.slab')!
        .onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    c.selection.replace([SelectionKey.root(slab)]);
    // M-C10: the mid-shape check removed from deleteSelection.
    expect(c.deleteSelection(), isFalse);
    expect(c.document.tree[slab], isNotNull);
    await tester.pump();
  });

  testWidgets(
      'C11 pending input is settled before save, markSaved, undo, redo, '
      'deleteSelection, newPlan and load; a withdrawn settle is not called',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final calls = <String>[];
    var phase = '';
    final withdraw = c.registerSettle(() => calls.add(phase));
    final runs = <(String, void Function())>[
      ('save', () => c.save()),
      ('markSaved', c.markSaved),
      ('undo', c.undo),
      ('redo', c.redo),
      ('delete', () => c.deleteSelection()),
      ('newPlan', () => c.newPlan()),
      ('load', () => c.load(slabPlanText())),
    ];
    for (final (name, run) in runs) {
      phase = name;
      run();
    }
    // M-C11: load does not settle.
    expect(calls,
        ['save', 'markSaved', 'undo', 'redo', 'delete', 'newPlan', 'load']);
    withdraw();
    c.save();
    expect(calls, hasLength(7));
    await tester.pump();
  });

  testWidgets('C13 the exporters and importers given are kept, in order',
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    expect(c.exporters, isEmpty);
    expect(c.importers, isEmpty);
    final exporters = [_Exporter('acme.dxf'), _Exporter('acme.svg')];
    final importers = [_Importer('acme.dxf')];
    final d = PlanController(
        kits: [testKit()], exporters: exporters, importers: importers);
    addTearDown(d.dispose);
    // M-C13: the lists not stored (`const []`).
    expect([for (final e in d.exporters) e.id], ['acme.dxf', 'acme.svg']);
    expect(d.importers.single, same(importers.single));
    exporters.clear();
    expect(d.exporters, hasLength(2), reason: 'copied');
  });
}

final class _Exporter implements PlanExporter {
  _Exporter(this.id);

  @override
  final String id;

  @override
  String get extension => 'dxf';

  @override
  String get mimeType => 'application/dxf';

  @override
  Future<Uint8List> export(PlanExportRequest request) async => Uint8List(0);
}

final class _Importer implements PlanImporter {
  _Importer(this.id);

  @override
  final String id;

  @override
  List<String> get extensions => const ['dxf'];

  @override
  Future<String> import(Uint8List bytes) async => '{}';
}
```

  Create `packages/jet_cad_2d_plan/test/controller/locale_separator_test.dart`:

```dart
// Spec 2a P2 (newPlan: "default: the locale's, as today"), today's Q0 N1,
// N2: the constructor's empty plan is settled by the first locale reported
// -- as if made so: no undo step, clean -- unless something read or edited
// it first; newPlan() takes the locale last reported; a loaded plan is
// never settled. Ported from jet_cad_floor_plan's
// new_plan_separator_test.dart (NS1, NS3, NS4, NS6, NS8, NS9) with the view
// replaced by the report it makes (`reportLocale`); the Page panel's and
// the service layout's assertions are left out (Task 18; 2b).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/harness.dart';
import '../support/test_kit.dart';

DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

/// A design edit before any report: a layer added, one command.
void addLayer(PlanController c) {
  final doc = c.document;
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: doc.handleSeed.next(),
      name: 'Bar',
      color: const IndexedColor(5),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: true,
      locked: false)));
}

void main() {
  testWidgets(
      "NS1 the constructor's empty plan, reported Turkish, prints comma as if "
      'made so: no undo step, clean; English keeps it; newPlan() in English '
      'is point and stays point when Turkish comes; newPlan() in Turkish is '
      'comma', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final made = c.document;
    expect(separatorOf(made), DecimalSeparator.point,
        reason: "premise: unsettled, the engine's default");
    c.reportLocale(const Locale('tr'));
    expect(identical(c.document, made), isTrue,
        reason: 'the plan is settled in place, not replaced');
    expect(separatorOf(made), DecimalSeparator.comma);
    // M-NS1: the settle's step not cleared.
    expect(made.commands.undoDepth, 0);
    expect(made.commands.canRedo, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
    addLayer(c);
    await tester.pump();
    expect(c.dirty.value, isTrue, reason: 'premise: an edit');
    c.undo();
    await tester.pump();
    expect(c.dirty.value, isFalse, reason: 'the save point moved with it');

    c.reportLocale(const Locale('en'));
    expect(separatorOf(c.document), DecimalSeparator.comma);

    c.newPlan();
    await tester.pump();
    final english = c.document;
    expect(identical(english, made), isFalse, reason: 'premise: a new plan');
    expect(separatorOf(english), DecimalSeparator.point);
    c.reportLocale(const Locale('tr'));
    expect(identical(c.document, english), isTrue);
    expect(separatorOf(english), DecimalSeparator.point,
        reason: 'settled when made: a later language does not change it');

    c.newPlan();
    await tester.pump();
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.comma);
    expect(c.document.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS3 a loaded plan is never settled (N2): by the constructor or by '
      'load(), a point plan reported Turkish stays point', (tester) async {
    final json = slabPlanText();
    final byJson = controllerFor(kits: [testKit()], json: json);
    byJson.reportLocale(const Locale('tr'));
    // M-NS3: a loaded plan made unsettled.
    expect(separatorOf(byJson.document), DecimalSeparator.point);
    expect(byJson.save(), json, reason: "the bytes are the file's");

    final byLoad = controllerFor(kits: [testKit()]);
    byLoad.load(json);
    byLoad.reportLocale(const Locale('tr'));
    expect(separatorOf(byLoad.document), DecimalSeparator.point);
    expect(byLoad.dirty.value, isFalse);
    expect(byLoad.save(), json);
    await tester.pump();
  });

  testWidgets(
      'NS4 an empty plan touched before any report stays point in Turkish '
      '(N2): read by save(); edited; edited and undone', (tester) async {
    final read = controllerFor(kits: [testKit()]);
    final stored = read.save();
    read.markSaved();
    // M-NS4: save() leaves the plan unsettled.
    read.reportLocale(const Locale('tr'));
    expect(separatorOf(read.document), DecimalSeparator.point);
    expect(read.save(), stored, reason: 'the stored bytes still hold');
    expect(read.dirty.value, isFalse);

    final edited = controllerFor(kits: [testKit()]);
    addLayer(edited);
    edited.reportLocale(const Locale('tr'));
    expect(separatorOf(edited.document), DecimalSeparator.point);
    expect(edited.document.commands.undoDepth, 1,
        reason: "the edit's step only");

    final undone = controllerFor(kits: [testKit()]);
    addLayer(undone);
    undone.undo();
    expect(undone.document.commands.canRedo, isTrue,
        reason: 'premise: an undone edit');
    undone.reportLocale(const Locale('tr'));
    expect(separatorOf(undone.document), DecimalSeparator.point);
    expect(undone.document.commands.canRedo, isTrue,
        reason: 'its Redo is kept');
    await tester.pump();
  });

  testWidgets(
      "NS6 the constructor's empty plan reported first in English is settled "
      'at point: a later Turkish leaves it point, no undo step, clean',
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final made = c.document;
    c.reportLocale(const Locale('en'));
    expect(separatorOf(made), DecimalSeparator.point);
    // M-NS6: the first report does not settle the plan.
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(identical(c.document, made), isTrue);
    expect(separatorOf(made), DecimalSeparator.point,
        reason: 'settled by the first language, already point (N2)');
    expect(made.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      "NS8 newPlan() before any report is unsettled, as the constructor's "
      'plan is: reported Turkish it is comma, no step, clean', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final first = c.document;
    // M-NS8: newPlan always settled.
    c.newPlan();
    expect(identical(c.document, first), isFalse, reason: 'premise: a new plan');
    expect(separatorOf(c.document), DecimalSeparator.point);
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.comma);
    expect(c.document.commands.undoDepth, 0);
    expect(c.canUndo.value, isFalse);
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'NS9 a plan loaded over the unsettled one and edited once before any '
      "report keeps point and its step (F-4: state ids are per history)",
      (tester) async {
    final c = controllerFor(kits: [testKit()]);
    c.load(slabPlanText());
    addLayer(c);
    expect(c.document.commands.undoDepth, 1, reason: 'premise');
    // M-NS9: the unsettled plan kept across a load and the document check
    // dropped from _untouched.
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    expect(separatorOf(c.document), DecimalSeparator.point);
    expect(c.document.commands.undoDepth, 1, reason: "the edit's step is kept");
  });

  testWidgets(
      'NS10 newPlan(decimalSeparator:) prints it and is settled; another '
      'character is an ArgumentError and changes nothing', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    // M-NS10: the argument ignored.
    c.newPlan(decimalSeparator: ',');
    final comma = c.document;
    expect(separatorOf(comma), DecimalSeparator.comma);
    c.reportLocale(const Locale('en'));
    expect(separatorOf(comma), DecimalSeparator.comma, reason: 'settled');
    expect(() => c.newPlan(decimalSeparator: ';'), throwsArgumentError);
    expect(c.document, same(comma));
    c.newPlan(decimalSeparator: '.');
    expect(separatorOf(c.document), DecimalSeparator.point);
    await tester.pump();
  });
}
```

  Create `packages/jet_cad_2d_plan/test/controller/camera_test.dart`:

```dart
// Spec 2a P2 "Camera" (today's G-3): the zoom bounds, panBy, zoomBy,
// centerOn and fitToView on the controller. CM4, CM5 (first half), CM6 and
// CM15 are jet_cad_floor_plan's camera_test.dart, assertions unchanged; a
// mounted view is replaced by the report a canvas makes (canvasPlaced).
// Expectations are computed by the forward transform, never read back.
import 'package:flutter/widgets.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

List<double> parts(ViewportTransform t) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

List<double> panned(ViewportTransform t, Offset d) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e + d.dx, m.f + d.dy];
}

Offset canvasOfCamera(ViewportTransform t, Offset w) {
  final m = t.worldToScreenMatrix;
  return Offset(m.a * w.dx + m.c * w.dy + m.e, m.b * w.dx + m.d * w.dy + m.f);
}

Offset canvasToWorld(ViewportTransform t, Offset p) {
  final w = t.screenToWorld(Vector2(p.dx, p.dy));
  return Offset(w.x, w.y);
}

void expectPixel(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason: x');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason: y');
}

/// Where a mounted editor's canvas would report itself.
const Rect canvasRect = Rect.fromLTWH(264, 68, 1176, 832);

void main() {
  testWidgets(
      "CM4 the zoom bounds: today's by default, the constructor's when given, "
      'an ArgumentError unless finite and 0 < min < max', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    expect(c.camera.minScale, 0.001);
    expect(c.camera.maxScale, 100);
    final d = controllerFor(kits: [testKit()], minScale: 0.02, maxScale: 3.5);
    expect(d.camera.minScale, 0.02);
    expect(d.camera.maxScale, 3.5);
    // M-CM4: the `maxScale <= minScale` check removed.
    for (final (min, max) in [
      (0.0, 1.0),
      (-0.5, 1.0),
      (double.nan, 1.0),
      (double.infinity, 1.0),
      (1.0, 1.0),
      (2.0, 1.0),
      (0.1, double.infinity),
      (0.1, double.nan),
    ]) {
      expect(() => PlanController(kits: [testKit()], minScale: min, maxScale: max),
          throwsArgumentError,
          reason: '($min, $max)');
    }
  });

  testWidgets(
      'CM5 panBy acts at once and drops a request not yet performed with its '
      'target', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final before = c.camera.value;
    c.centerOn(const Offset(-2600, 1400), scale: 0.2);
    const d = Offset(37.25, -11.5);
    c.panBy(d);
    expect(parts(c.camera.value), panned(before, d));
    expect(() => c.panBy(const Offset(double.nan, 0)), throwsArgumentError);
    expect(parts(c.camera.value), panned(before, d));
    // M-CM5: the pending target kept by a camera command.
    expect(c.framingFor(canvasRect.size), isNull,
        reason: 'the centring was dropped with its target');
  });

  testWidgets(
      'CM6 zoomBy: false with no view or a bad factor, changing nothing; '
      'about the canvas centre or a focus; clamped to the bounds (M-H6)',
      (tester) async {
    final c = controllerFor(
        kits: [testKit()], json: slabPlanText(), minScale: 0.2, maxScale: 0.5);
    final idle = c.camera.value;
    // M-CM6a: zoomBy acts with no canvas reported.
    expect(c.zoomBy(1.5), isFalse, reason: 'no view');
    expect(c.camera.value, same(idle));

    c.canvasPlaced(Object(), canvasRect);
    final size = c.canvasRect.value!.size;
    final centre = size.center(Offset.zero);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix:
            const Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));
    final placed = c.camera.value;
    for (final f in [0.0, -2.0, double.nan, double.infinity]) {
      expect(c.zoomBy(f), isFalse, reason: 'factor $f');
    }
    expect(c.zoomBy(1.2, focus: const Offset(double.nan, 0)), isFalse);
    expect(c.camera.value, same(placed));

    // The world at the centre, by the inverse of the fixture's camera.
    final mid =
        Offset((centre.dx + 14612.25) / 0.37, (centre.dy + 9431.5) / -0.37);
    // M-CM6b: zoomBy about the canvas's top left.
    expect(c.zoomBy(1.25), isTrue);
    expect(c.camera.value.scale, closeTo(0.37 * 1.25, 1e-12));
    expectPixel(canvasOfCamera(c.camera.value, mid), centre, 'the centre stays');

    expect(c.zoomBy(10), isTrue);
    expect(c.camera.value.scale, closeTo(0.5, 1e-12), reason: 'max');
    expectPixel(canvasOfCamera(c.camera.value, mid), centre,
        'the centre stays at the bound');

    const focus = Offset(310.5, 190.25);
    final under = canvasToWorld(c.camera.value, focus);
    expect(c.zoomBy(1e-6, focus: focus), isTrue);
    expect(c.camera.value.scale, closeTo(0.2, 1e-12), reason: 'min');
    expectPixel(canvasOfCamera(c.camera.value, under), focus, 'the focus stays');
  });

  testWidgets(
      "CM15 minScale has a floor of 1e-6, the bound decisions' tolerance "
      'times a thousand; at the floor the bound holds', (tester) async {
    // M-CM15: no floor (`_minScaleFloor = 0`).
    for (final min in [1e-9, 1e-10, 9.99e-7]) {
      expect(() => PlanController(kits: [testKit()], minScale: min),
          throwsArgumentError,
          reason: '$min');
    }
    final c = controllerFor(kits: [testKit()], minScale: 1e-6);
    expect(c.camera.minScale, 1e-6);
    c.canvasPlaced(Object(), canvasRect);
    expect(c.zoomBy(1e-12), isTrue);
    expect(c.camera.value.scale, closeTo(1e-6, 1e-18), reason: 'min');
  });

  testWidgets(
      'C-cam1 centerOn queues a centring the canvas performs, at the scale '
      "asked or, before the plan's first fit, the page fit's; fitToView "
      'replaces it; each request moves the epoch', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final viewport = canvasRect.size;
    final e0 = c.cameraEpoch;
    c.centerOn(const Offset(-2600, 1400), scale: 0.25);
    expect(c.cameraEpoch, e0 + 1);
    final framing = c.framingFor(viewport)!;
    // M-C-cam1a: the scale asked ignored.
    expect(framing.scale, closeTo(0.25, 1e-12));
    final p = framing.worldToScreen(Vector2(-2600, 1400));
    expect(p.x, closeTo(viewport.width / 2, 1e-6));
    expect(p.y, closeTo(viewport.height / 2, 1e-6));
    // M-C-cam1b: fitToView keeps the centring.
    c.fitToView();
    expect(c.framingFor(viewport), isNull, reason: 'the page');
    expect(c.cameraEpoch, e0 + 2);
    expect(() => c.centerOn(const Offset(double.infinity, 0)),
        throwsArgumentError);
    expect(() => c.centerOn(Offset.zero, scale: 0), throwsArgumentError);
    c.centerOn(const Offset(-2600, 1400));
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    expect(c.framingFor(viewport)!.scale,
        closeTo(fitToPage(page, viewport).scale, 1e-12));
    expect(c.takeFitOnStart(), isTrue);
    expect(c.takeFitOnStart(), isTrue, reason: 'the centring is still owed');
    c.fitted();
    expect(c.takeFitOnStart(), isFalse);
  });
}
```

  Create `packages/jet_cad_2d_plan/test/controller/lifetimes_test.dart`:

```dart
// Spec 2a P1 "PlanServices" and its lifetimes, Review Focus 4: a kit's
// factories run once per document; a swap cancels the tool, settles the
// pending input into the old plan, disposes the old products and runs the
// factories again; `shared` is per document and per kit; the services read
// the current document, the settings, the words and the snap live; the
// grip cache asks each object's own type.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

final class _Probe {}

final class _Loop {}

void main() {
  testWidgets(
      'C-life1 the factories run once per document; after a swap every '
      'product of the previous document is disposed and new ones are made',
      (tester) async {
    final log = KitLog();
    final c = controllerFor(kits: [testKit(log: log)]);
    expect(log.events, ['cache+1', 'tool+1', 'grips+1']);
    final tool = c.toolFor('test.slab')! as SlabTool;
    expect(
        c.servicesOf('test').shared<SlabCache>(
            (_) => throw StateError('made twice')),
        same(tool.cache),
        reason: 'the tool and the grips share one cache per document');
    expect(c.selectTool('test.slab'), isTrue);
    expect(c.selectTool('plan.select'), isTrue);
    expect(c.selectTool('test.slab'), isTrue);
    expect(log.events, hasLength(3), reason: 'once per document, not per arming');
    // M-C-life1: the kit products not disposed at a swap.
    c.newPlan();
    expect(log.events.skip(3),
        ['tool-1', 'grips-1', 'cache-1', 'cache+2', 'tool+2', 'grips+2']);
    expect(tool.cache.disposed, isTrue);
    expect(c.toolFor('test.slab'), isNot(same(tool)));
    expect(c.activeTool.value, 'plan.select',
        reason: 'a tool armed before the swap is gone');
    await tester.pump();
  });

  testWidgets(
      "C-life2 shared is keyed by kit and type: two kits asking for one type "
      'get two values; a value that asks for itself is refused',
      (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final a = c.servicesOf('test').shared<_Probe>((_) => _Probe());
    // M-C-life2a: the cache keyed by type alone.
    expect(c.servicesOf('disc').shared<_Probe>((_) => _Probe()), isNot(same(a)));
    expect(c.servicesOf('test').shared<_Probe>((_) => _Probe()), same(a));
    // M-C-life2b: no guard against a create that asks for itself.
    expect(
        () => c
            .servicesOf('disc')
            .shared<_Loop>((s) => s.shared<_Loop>((_) => _Loop())),
        throwsStateError);
    c.newPlan();
    expect(c.servicesOf('test').shared<_Probe>((_) => _Probe()), isNot(same(a)),
        reason: 'per document');
    await tester.pump();
  });

  testWidgets(
      "C-svc the services: a kit's own tool settings, the controller's across "
      'plans; the words at the current locale with English the fallback; '
      'the effective snap; the current document, index and camera',
      (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final s = c.servicesOf('test');
    expect(s.settingsOf<SlabSettings>('test.slab'),
        const SlabSettings(width: 1200, height: 600));
    c.toolSettings.store('test.slab', const SlabSettings(width: 2400, height: 750));
    expect(s.settingsOf<SlabSettings>('test.slab').width, 2400);
    expect(() => s.settingsOf<DiscComponent>('test.slab'), throwsArgumentError);
    // M-C-svc-a: another kit's tool settings readable.
    expect(() => c.servicesOf('disc').settingsOf<SlabSettings>('test.slab'),
        throwsArgumentError);
    c.newPlan();
    expect(s.settingsOf<SlabSettings>('test.slab').width, 2400,
        reason: 'the controller holds one value per tool, across plans');
    expect(s.words.word('type:test.slab'), 'Slab');
    // M-C-svc-c: the words read a locale fixed at creation.
    c.reportLocale(const Locale('tr'));
    expect(s.words.word('type:test.slab'), 'Döşeme');
    c.reportLocale(const Locale('de'));
    expect(s.words.word('type:test.slab'), 'Slab', reason: 'no German: English');
    expect(s.objectSnap, isTrue);
    c.snap.toggleObjectSnap();
    expect(s.objectSnap, isFalse);
    c.snap.toggleObjectSnap();
    // M-C-svc-d: the canvas's snapping option ignored.
    c.snappingAllowed = false;
    expect(s.objectSnap, isFalse);
    expect(s.document, same(c.document));
    expect(s.index, same(c.index));
    expect(s.camera, same(c.camera));
    expect(s.attachments.kinds, isEmpty, reason: 'the registry is Task 14');
    await tester.pump();
  });

  testWidgets(
      "C-grips the grip cache asks each object's own type: a slab gives its "
      'grip and drags it, a disc and a plain group none; a swap lets the old '
      "plan's providers go", (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final d = c.document;
    final slab = addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    final disc = addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-3100, 2240));
    final plain = d.handleSeed.next();
    d.commands.execute(AddNodeCommand(GroupNode(
        handle: plain,
        parent: d.rootHandle,
        transform: Transform2.translation(-800, -2600),
        children: const [])));
    final objects = c.grips.objects!;
    // M-C-grips-a: the dispatch finds no provider.
    final grips = objects.gripsOf(d, slab);
    expect(grips.single.x, closeTo(2350 + 900 * math.cos(0.4), 1e-9));
    expect(grips.single.y, closeTo(-1180 + 900 * math.sin(0.4), 1e-9));
    expect(objects.gripsOf(d, disc), isEmpty);
    expect(objects.gripsOf(d, plain), isEmpty);
    expect(objects.movable(d, plain), isTrue);
    d.commands.execute(objects.drag(d, slab, grips.single,
        Vector2(2350 + 1300 * math.cos(0.4), -1180 + 1300 * math.sin(0.4)))!);
    expect(d.components.get<SlabComponent>(slab)!.width, closeTo(2600, 1e-9));
    // M-C-grips-b: the old dispatch not closed at a swap.
    c.newPlan();
    expect(objects.gripsOf(d, slab), isEmpty,
        reason: "the old plan's providers are let go");
    await tester.pump();
  });

  testWidgets(
      'C-swap-mid-shape (Review Focus 4) load while the slab tool is '
      'part-way through a shape and a field holds a value: no exception, '
      'the tool cancelled, the value settled into the old plan and not into '
      'the new one', (tester) async {
    final log = KitLog();
    final c = controllerFor(kits: [testKit(log: log)], json: slabPlanText());
    final old = c.document;
    final slab = slabsOf(old).first;
    var pending = true;
    // What a panel field holding 2750 for the slab's width does on settle:
    // it commits into the plan it was typed for.
    c.registerSettle(() {
      if (!pending) return;
      pending = false;
      setSlabWidth(c, slab, 2750);
    });
    expect(c.selectTool('test.slab'), isTrue);
    final tool = c.toolFor('test.slab')! as SlabTool;
    tool.onPointerDown(pointerAt(Vector2(1250, -730)), c.toolContext);
    expect(tool.isMidShape, isTrue, reason: 'premise');

    c.load(slabPlanText());

    // M-C-swap-a: load does not settle. M-C-swap-b: it settles after the
    // swap, into the new plan.
    expect(old.components.get<SlabComponent>(slab)!.width, 2750);
    expect(c.document.components.get<SlabComponent>(slab)!.width, 1800);
    // M-C-swap-c: the swap does not cancel the active tool.
    expect(tool.isMidShape, isFalse);
    expect(c.activeTool.value, 'plan.select');
    expect(log.events, contains('tool-1'));
    expect(c.toolFor('test.slab'), isNot(same(tool)));
    await tester.pump();
  });
}
```

  Create `packages/jet_cad_2d_plan/test/controller/covariance_test.dart`:

```dart
// Review Focus 3 (spec 2a P1 "Covariance"): two kits whose types carry
// different component types are held as PlanType<Component>; they register,
// regenerate, show their fields, edit and recolour through the erased
// operations under the VM's covariance checks.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

void main() {
  testWidgets(
      'C-covariance a slab and a disc register, regenerate, show their '
      'fields, edit and recolour through PlanType<Component>', (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final d = c.document;
    // M-C-cov-b: only the first kit's types registered.
    final slab = addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    final disc = addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-3100, 2240));
    for (final (object, typeId, length, value) in [
      (slab, 'test.slab', 'width', 1800.0),
      (disc, 'disc.round', 'radius', 650.0),
    ]) {
      final before = List.of(coordsOf(d, leavesOf(d, object).single));
      // M-C-cov-a: typeOf answers the set's first type.
      final PlanType<Component> type = c.typeOf(object)!;
      expect(type.id, typeId);
      final fields = type.fieldsOf(d, object);
      for (final f in fields) {
        expect(f.wordId, startsWith('property:$typeId.'));
        expect(() => (f.value, f.enabled), returnsNormally);
      }
      final field = fields.singleWhere((f) => f.spec.id == length);
      expect(field.value, value);
      d.commands.execute(type.commitField(d, object, field, 2345.5));
      expect(type.fieldsOf(d, object).singleWhere((f) => f.spec.id == length).value,
          2345.5);
      expect(coordsOf(d, leavesOf(d, object).single), isNot(before),
          reason: 'regenerated');
      d.commands.execute(type.recolour(d, object, 'red')!);
      expect(type.colourOf(d, object), 'red');
    }
    expect(c.typeOf(addLine(d, Vector2(-500, 700), Vector2(1800, 2400))),
        isNull);
    await tester.pump();
  });
}
```

  Create `packages/jet_cad_2d_plan/test/controller/plan_change_test.dart`:

```dart
// Spec 2a P2 "Events": the plan's changes, domain-neutral. Re-expressed
// from jet_cad_floor_plan's design_changes_test.dart (DC8, DC9, DC11, DC12,
// DC13, DC17, DC18, DC19) for objects instead of tables.
import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

List<PlanChange> listen(PlanController c) {
  final seen = <PlanChange>[];
  c.changes.listen(seen.add);
  return seen;
}

void main() {
  testWidgets(
      'C-ch1 an object added, changed, removed and undone, in ascending '
      'order, once per step; a line is an object; a page change and a layer '
      'are none', (tester) async {
    final c = controllerFor(kits: [testKit()]);
    final seen = listen(c);
    final slab = addObject<SlabComponent>(
        c.document, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    await tester.pump();
    // M-C-ch1a: a generated leaf reported as an object of its own.
    expect(seen, [PlanObjectAdded(slab)]);
    seen.clear();

    final line = addLine(c.document, Vector2(-500, 700), Vector2(1800, 2400));
    setSlabWidth(c, slab, 2400);
    final page =
        c.document.components.get<PageComponent>(c.document.rootHandle)!;
    c.document.commands.execute(SetComponentCommand<PageComponent>(
        c.document.rootHandle,
        page.copyWith(decimalSeparator: DecimalSeparator.comma)));
    c.reportLocale(const Locale('tr'));
    await tester.pump();
    // M-C-ch1b: reported in arrival order (the line first).
    expect(seen, [PlanObjectChanged(slab), PlanObjectAdded(line)]);
    seen.clear();

    c.selection.replace([SelectionKey.root(slab)]);
    expect(c.deleteSelection(), isTrue);
    await tester.pump();
    expect(seen, [PlanObjectRemoved(slab)]);
    c.undo();
    await tester.pump();
    expect(seen, [PlanObjectRemoved(slab), PlanObjectAdded(slab)]);
  });

  testWidgets('C-ch2 newPlan is exactly [PlanReplaced()], no Removed per '
      'object; a load the same (DC8)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    // M-C-ch2: no PlanReplaced at a swap.
    c.newPlan();
    await tester.pump();
    expect(seen, [const PlanReplaced()]);
    expect(slabsOf(c.document), isEmpty, reason: 'premise: an empty plan');
    c.load(slabPlanText());
    await tester.pump();
    expect(seen, [const PlanReplaced(), const PlanReplaced()]);
  });

  testWidgets(
      "C-ch3 an edit then a load in one synchronous step: the edit's change, "
      'then PlanReplaced, then an edit of the loaded plan (DC9)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    final first = slabsOf(c.document).first;
    setSlabWidth(c, first, 2100);
    // M-C-ch3: a swap drops the old plan's owed changes.
    c.load(slabPlanText());
    final again = slabsOf(c.document).last;
    setSlabWidth(c, again, 900);
    expect(seen, isEmpty, reason: 'delivered asynchronously');
    await tester.pump();
    expect(seen, [
      PlanObjectChanged(first),
      const PlanReplaced(),
      PlanObjectChanged(again),
    ]);
  });

  testWidgets(
      'C-ch4 nothing is read with no listener, nor after the last cancel; one '
      'read per listen and per moved plan; two edits of one synchronous step '
      'are one read and one report (DC11)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final slab = slabsOf(c.document).first;
    setSlabWidth(c, slab, 2100);
    c.undo();
    c.redo();
    await tester.pump();
    c.load(slabPlanText());
    c.newPlan();
    c.load(slabPlanText());
    await tester.pump();
    // M-C-ch4a: the baseline built whether or not anything listens.
    expect(c.debugChangeScans, 0, reason: 'no listener: nothing read');

    final first = <PlanChange>[];
    final a = c.changes.listen(first.add);
    expect(c.debugChangeScans, 1, reason: 'the baseline');
    final second = <PlanChange>[];
    final b = c.changes.listen(second.add);
    expect(c.debugChangeScans, 1, reason: 'one baseline for every listener');

    final s1 = slabsOf(c.document).first;
    // M-C-ch4b: each mutation reported at once, not per step.
    setSlabWidth(c, s1, 2200);
    setSlabWidth(c, s1, 2300);
    await tester.pump();
    expect(c.debugChangeScans, 2, reason: 'two edits of one step: one read');
    expect(first, [PlanObjectChanged(s1)]);
    expect(second, [PlanObjectChanged(s1)]);

    unawaited(a.cancel());
    setSlabWidth(c, s1, 2400);
    await tester.pump();
    expect(c.debugChangeScans, 3, reason: 'one listener left');
    expect(second, [PlanObjectChanged(s1), PlanObjectChanged(s1)]);
    expect(first, [PlanObjectChanged(s1)]);

    unawaited(b.cancel());
    final scans = c.debugChangeScans;
    setSlabWidth(c, s1, 2500);
    c.undo();
    await tester.pump();
    c.load(slabPlanText());
    c.newPlan();
    await tester.pump();
    expect(c.debugChangeScans, scans, reason: 'after the last cancel: nothing');
  });

  testWidgets(
      'C-ch5 dispose closes the stream: an edit made just before it is not '
      'reported; nor an edit and a load (DC12, DC18)', (tester) async {
    final c = PlanController(kits: [testKit()], json: slabPlanText());
    final seen = <PlanChange>[];
    var done = false;
    c.changes.listen(seen.add, onDone: () => done = true);
    setSlabWidth(c, slabsOf(c.document).first, 2100);
    c.dispose();
    await tester.pump();
    expect(seen, isEmpty);
    expect(done, isTrue);

    final d = PlanController(kits: [testKit()], json: slabPlanText());
    final seenD = <PlanChange>[];
    var doneD = false;
    d.changes.listen(seenD.add, onDone: () => doneD = true);
    setSlabWidth(d, slabsOf(d.document).first, 2100);
    d.load(slabPlanText());
    // M-C-ch5: the stream not filtered once disposed.
    d.dispose();
    await tester.pump();
    expect(seenD, isEmpty);
    expect(doneD, isTrue);
  });

  testWidgets(
      'C-ch6 a failed load reports nothing and drops nothing owed (DC17)',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final seen = listen(c);
    final slab = slabsOf(c.document).first;
    setSlabWidth(c, slab, 2100);
    // M-C-ch6: load lets the tracker go before it decodes.
    expect(() => c.load('not json'), throwsFormatException);
    expect(() => c.load('{"x": 1}'), throwsFormatException);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab)]);
    expect(() => c.load('not json'), throwsFormatException);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab)], reason: 'nothing owed');
    setSlabWidth(c, slab, 2200);
    await tester.pump();
    expect(seen, [PlanObjectChanged(slab), PlanObjectChanged(slab)],
        reason: 'the same plan, the same baseline');
  });

  testWidgets(
      'C-ch7 a listener that disposes the controller on the first change of '
      'a report hears no second one, and then done (DC19)', (tester) async {
    final c = PlanController(kits: [testKit()], json: slabPlanText());
    final seen = <PlanChange>[];
    var done = false;
    c.changes.listen((change) {
      seen.add(change);
      c.dispose();
    }, onDone: () => done = true);
    final [a, b] = slabsOf(c.document);
    setSlabWidth(c, a, 2100);
    setSlabWidth(c, b, 900);
    await tester.pump();
    expect(seen, hasLength(1), reason: 'the report had two changes');
    expect(seen.single, isA<PlanObjectChanged>());
    expect(done, isTrue);
  });

  test('C-ch8 the four changes: ==, hashCode and toString (DC13)', () {
    final h = Handle.checked(0x2A);
    // M-C-ch8: == by kind alone.
    expect(PlanObjectAdded(h), PlanObjectAdded(Handle.checked(0x2A)));
    expect(PlanObjectAdded(h), isNot(PlanObjectAdded(Handle.checked(0x2B))));
    expect(PlanObjectAdded(h), isNot(PlanObjectRemoved(h)));
    expect(PlanObjectChanged(h).hashCode,
        PlanObjectChanged(Handle.checked(0x2A)).hashCode);
    expect(const PlanReplaced(), const PlanReplaced());
    expect('${PlanObjectRemoved(h)}', 'PlanObjectRemoved(2A)');
  });
}
```

- [ ] **Step 3: Run them to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/controller`. Expected: compilation errors naming `PlanController`, `PlanChange`, `PlanSymbolsState`, `kPlanMinScale`.

- [ ] **Step 4: The small parts.** Create `packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart`:

```dart
// The symbol libraries' state (spec 2a P2 "Symbol libraries"): Task 13's
// loader drives it; until then a controller is `ready`.

enum PlanSymbolsState { loading, ready, failed }
```

  Create `packages/jet_cad_2d_plan/lib/src/export/registries.dart` (the interfaces of the Shared interfaces; Task 19 extends this file with `PlanExportRequest.choice` and `.fonts`, the built-in exporters and the flows):

```dart
// Export and import registries (spec 2a P5, A17.4): a host's exporters
// render a copy of the plan into bytes; its importers turn bytes into a
// plan's text. The controller stores them (Task 8); Task 19 runs them.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart';

abstract interface class PlanExporter {
  /// `plan.pdf`, `plan.png`; a host's: `acme.dxf`.
  String get id;
  String get extension;

  /// What a host's save hands on with the bytes.
  String get mimeType;

  Future<Uint8List> export(PlanExportRequest request);
}

abstract interface class PlanImporter {
  String get id;
  List<String> get extensions;

  /// A plan's text (spec decision 4); one without a manifest gets an empty
  /// one before it is loaded.
  Future<String> import(Uint8List bytes);
}

/// What an exporter renders (spec P5). Task 19 adds the choice and the
/// fonts.
@immutable
final class PlanExportRequest {
  const PlanExportRequest(
      {required this.document, required this.page, required this.omitted});

  /// A copy decoded from the plan's text when the export starts.
  final DraftDocument document;

  /// Null for a "drawing" export.
  final PageComponent? page;

  /// Objects of types with `exported: false`.
  final Set<Handle> omitted;
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/camera_bounds.dart` (a port of `jet_cad_floor_plan/lib/src/camera_bounds.dart:1-36`, unchanged but for the constants of `startup_plan.dart:50-51`):

```dart
// The one clamp every fit passes through (today's host embedding API G-3):
// a camera a fit computes is brought inside the zoom bounds about the
// canvas's centre, as `CameraController.zoomAt` brings a zoom. Ported from
// jet_cad_floor_plan's camera_bounds.dart.
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

/// The default zoom bounds, logical pixels per millimetre (today's
/// `kMinScale`, `kMaxScale`).
const double kPlanMinScale = 0.001;
const double kPlanMaxScale = 100.0;

/// [camera] with its scale inside `[minScale, maxScale]`, scaled about the
/// centre of a canvas of [canvas]: the world point at the centre stays
/// there. [camera] itself when its scale is already inside.
///
/// Whether a scale is past a bound is a geometric decision on a derived
/// number, made with the tolerance `CameraController.zoomAt` uses.
ViewportTransform clampCameraScale(ViewportTransform camera, Size canvas,
    {required double minScale, required double maxScale}) {
  const tolerance = Tolerance.standard;
  final scale = camera.scale;
  final double bound;
  if (tolerance.compare(scale, maxScale) > 0) {
    bound = maxScale;
  } else if (tolerance.compare(scale, minScale) < 0) {
    bound = minScale;
  } else {
    return camera;
  }
  final k = bound / scale;
  final cx = canvas.width / 2, cy = canvas.height / 2;
  final about = Transform2.translation(cx, cy)
      .multiply(Transform2.scale(k, k))
      .multiply(Transform2.translation(-cx, -cy));
  return ViewportTransform(
      worldToScreenMatrix: about.multiply(camera.worldToScreenMatrix));
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart` (a port of `jet_cad_floor_plan/lib/src/new_document.dart:18-56`):

```dart
// The document a new plan opens with (today's spec 12a D4, Q0 N1): the
// plan's components registered, millimetres, the default page, no history.
// Ported from jet_cad_floor_plan's new_document.dart, without its DASHED
// linetype (the separator's, sub-project 3) and with the registration
// passed in (the kits').
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';

/// A4 landscape at 1:50 in metres, every field at its default, with a
/// fixed origin that centres the sheet on the world origin.
PageComponent defaultPlanPage(
        {DecimalSeparator decimalSeparator = DecimalSeparator.point}) =>
    PageComponent(
        originX: -7425, originY: -5250, decimalSeparator: decimalSeparator);

/// A new plan's document over [measurer]: [register] run once on its
/// registry, millimetres, [defaultPlanPage] attached through the log, then
/// the history cleared, so Undo is off and the save point finds it clean.
DraftDocument newPlanDocument(TextMeasurer measurer,
    {required void Function(ComponentRegistry registry) register,
    DecimalSeparator decimalSeparator = DecimalSeparator.point}) {
  final doc = DraftDocument.empty(measurer: measurer);
  register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, defaultPlanPage(decimalSeparator: decimalSeparator)));
  doc.commands.clearHistory();
  return doc;
}

/// The separator a new plan takes in [locale]'s language: comma for the
/// built-in German and Turkish, point otherwise (today's
/// `documentSeparatorFor` over `FloorPlanStrings.forLocale`). Task 9 reads
/// it from `PlanStrings`, which gives the same answers.
DecimalSeparator decimalSeparatorFor(Locale locale) =>
    switch (locale.languageCode) {
      'de' || 'tr' => DecimalSeparator.comma,
      _ => DecimalSeparator.point,
    };
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/diagnostics_log.dart`:

```dart
// The controller's diagnostics (spec 2a P4 "Diagnostics"): a listenable
// list of KitDiagnostic. The plan's own (a missing kit, a newer kit, a
// component that does not read, a failed rollback, an unsavable plan) are
// cleared when the plan is replaced; the kit set's stay. Task 11 adds the
// dedupe by (kit id, subject, code).
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class DiagnosticsLog extends ChangeNotifier
    implements ValueListenable<List<KitDiagnostic>> {
  /// The codes that belong to one plan.
  static const Set<KitDiagnosticCode> planScoped = {
    KitDiagnosticCode.kitMissing,
    KitDiagnosticCode.kitNewer,
    KitDiagnosticCode.componentUnreadable,
    KitDiagnosticCode.rollbackFailed,
    KitDiagnosticCode.damagedUnsavable,
  };

  List<KitDiagnostic> _value = const [];

  @override
  List<KitDiagnostic> get value => _value;

  void report(KitDiagnostic diagnostic) => reportAll([diagnostic]);

  void reportAll(Iterable<KitDiagnostic> diagnostics) {
    final added = diagnostics.toList();
    if (added.isEmpty) return;
    _value = List.unmodifiable([..._value, ...added]);
    notifyListeners();
  }

  /// Drops the [planScoped] diagnostics: the plan they spoke of is gone.
  void clearPlanScoped() {
    final kept = [
      for (final d in _value)
        if (!planScoped.contains(d.code)) d,
    ];
    if (kept.length == _value.length) return;
    _value = List.unmodifiable(kept);
    notifyListeners();
  }
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/shared_cache.dart`:

```dart
// PlanServices.shared (spec 2a P1): a per-document cache keyed by (kit id,
// type). The first call creates; later calls return the same value; a
// value that is Disposable is disposed with its document, last made first.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

final class SharedCache {
  final Map<(String, Type), Object> _values = {};
  final List<Object> _made = [];
  final Set<(String, Type)> _making = {};
  bool _disposed = false;

  T get<T extends Object>(
      String kitId, PlanServices services, T Function(PlanServices) create) {
    if (_disposed) {
      throw StateError('$kitId: shared<$T> of a plan that was replaced');
    }
    final key = (kitId, T);
    final found = _values[key];
    if (found != null) return found as T;
    if (!_making.add(key)) {
      throw StateError('$kitId: shared<$T> asked for itself while being made');
    }
    try {
      final made = create(services);
      _values[key] = made;
      _made.add(made);
      return made;
    } finally {
      _making.remove(key);
    }
  }

  void dispose() {
    _disposed = true;
    for (final value in _made.reversed) {
      if (value is Disposable) value.dispose();
    }
    _made.clear();
    _values.clear();
  }
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/grip_dispatch.dart`:

```dart
// The grip cache's one object provider (spec 2a P2: "grip cache (one
// provider, dispatching by typeIdOf, E1)"): each root-level group is asked
// of its own type's provider. Replaces the if-chain of today's ObjectGrips
// (jet_cad_floor_plan/lib/src/parametric/object_grips.dart). Task 10 adds
// the lock (no grips, not movable), Task 11 the guard.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class GripDispatch implements ObjectGripProvider {
  GripDispatch(this._catalog);

  final ParametricCatalog _catalog;
  final Map<String, ObjectGripProvider> _byType = {};

  void add(String typeId, ObjectGripProvider provider) =>
      _byType[typeId] = provider;

  /// Lets every provider go: a replaced plan's views reach none.
  void close() => _byType.clear();

  ObjectGripProvider? _of(DraftDocument d, Handle group) {
    if (_byType.isEmpty) return null;
    final typeId = _catalog.typeIdOf(d, group);
    return typeId == null ? null : _byType[typeId];
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) =>
      _of(d, group)?.gripsOf(d, group) ?? const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.drag(d, group, grip, world);

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(d, group)?.preview(d, group, grip, world) ?? const [];

  @override
  bool movable(DraftDocument d, Handle group) =>
      _of(d, group)?.movable(d, group) ?? true;
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/tool_settings_store.dart`:

```dart
// Tool settings (spec 2a P3 "Tool settings"): the controller holds one
// value of S per tool with settings, for its whole life; the panel edits it
// through the tool's specs, the tool reads it through
// PlanServices.settingsOf.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';

final class ToolSettingsStore extends ChangeNotifier {
  ToolSettingsStore(KitSet kits) {
    for (final tool in kits.tools) {
      final settings = tool.settings;
      if (settings == null) continue;
      _settings[tool.id] = settings;
      _values[tool.id] = settings.initial;
    }
  }

  final Map<String, PlanToolSettings<Object>> _settings = {};
  final Map<String, Object> _values = {};

  bool has(String toolId) => _values.containsKey(toolId);

  /// [toolId]'s settings now; an [ArgumentError] for a tool without any.
  Object valueOf(String toolId) =>
      _values[toolId] ??
      (throw ArgumentError.value(toolId, 'toolId', 'is no tool with settings'));

  void store(String toolId, Object value) {
    if (valueOf(toolId) == value) return;
    _values[toolId] = value;
    notifyListeners();
  }

  /// The panel's fields over [toolId]'s settings (Task 17); their words are
  /// `property:<tool id>.<id>`.
  List<PropertyField> fieldsOf(String toolId) {
    valueOf(toolId);
    return _settings[toolId]!.fieldsOf(
        _values[toolId]!, (value) => store(toolId, value),
        toolId: toolId);
  }
}
```

- [ ] **Step 5: The changes.** Create `packages/jet_cad_2d_plan/lib/src/controller/plan_change.dart`:

```dart
// The plan's changes as a host hears them (spec 2a P2 "Events"): an
// object added, changed or removed, and the plan replaced. An object is a
// root-level element: a group or an instance whose parent is the root, or
// an entity the root owns; a part of it (a generated leaf) counts for it.
// Modelled on today's design changes (floor_plan_controller.dart:
// 1690-1775), which speak of tables.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

@immutable
sealed class PlanChange {
  const PlanChange();
}

/// An object now in the plan that was not: placed, pasted, or a delete
/// undone.
final class PlanObjectAdded extends PlanChange {
  const PlanObjectAdded(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectAdded && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectAdded, object);

  @override
  String toString() => 'PlanObjectAdded(${object.toHex()})';
}

/// An object whose data, geometry, place or parts changed.
final class PlanObjectChanged extends PlanChange {
  const PlanObjectChanged(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectChanged && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectChanged, object);

  @override
  String toString() => 'PlanObjectChanged(${object.toHex()})';
}

/// An object no longer in the plan: deleted, or its placement undone.
final class PlanObjectRemoved extends PlanChange {
  const PlanObjectRemoved(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectRemoved && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectRemoved, object);

  @override
  String toString() => 'PlanObjectRemoved(${object.toHex()})';
}

/// The whole plan was replaced (`load`, `newPlan`, `import`), or reloaded
/// in place (a rollback that failed, Task 11): no change per object.
final class PlanReplaced extends PlanChange {
  const PlanReplaced();

  @override
  bool operator ==(Object other) => other is PlanReplaced;

  @override
  int get hashCode => (PlanReplaced).hashCode;

  @override
  String toString() => 'PlanReplaced()';
}

/// The root-level object [h] is part of in [d], or null: the root itself,
/// a handle no longer in [d], a definition's leaf, a table record.
Handle? rootObjectOf(DraftDocument d, Handle h) {
  final root = d.rootHandle;
  if (h == root) return null;
  var current = h;
  final slot = d.entities.slotOf(h);
  if (slot != null) {
    final owner = d.entities.ownerAt(slot);
    if (owner == root) return h;
    current = owner;
  }
  // The tree refuses a cycle; the bound only keeps a malformed load from
  // looping.
  for (var depth = 0; depth < 1 << 20; depth++) {
    final node = d.tree[current];
    if (node == null) return null;
    if (node.parent == root) return current;
    current = node.parent;
  }
  return null;
}

/// Every root-level object of [d].
Set<Handle> rootObjects(DraftDocument d) {
  final root = d.rootHandle;
  final node = d.tree[root];
  return {
    if (node is GroupNode) ...d.tree.childNodesOf(node.children),
    for (final slot in d.entities.liveSlots)
      if (d.entities.ownerAt(slot) == root) d.entities.handleAt(slot),
  };
}

/// What [touched] changed against [objects] (updated in place), in
/// ascending handle order.
List<PlanChange> diffObjects(
    DraftDocument d, Set<Handle> objects, Set<Handle> touched) {
  final sorted = touched.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final added = <Handle>{}, changed = <Handle>{}, removed = <Handle>{};
  for (final h in sorted) {
    if (h == d.rootHandle) continue;
    final object = rootObjectOf(d, h);
    if (object != h && objects.remove(h)) removed.add(h);
    if (object == null) continue;
    if (objects.add(object)) {
      added.add(object);
    } else if (!added.contains(object)) {
      changed.add(object);
    }
  }
  final all = {...removed, ...added, ...changed}.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return [
    for (final h in all)
      if (removed.contains(h) && !added.contains(h))
        PlanObjectRemoved(h)
      else if (added.contains(h))
        PlanObjectAdded(h)
      else
        PlanObjectChanged(h),
  ];
}

/// Collects one document's changes synchronously, stacked on the
/// dispatcher's `onAfterMutate` (the spatial index's, kept and called
/// first), and reports them once per synchronous step, while anything
/// listens. [detach] reports what is still owed, at once.
final class PlanChangeTracker {
  PlanChangeTracker(this._emit);

  final void Function(PlanChange change) _emit;

  DraftDocument? _document;
  void Function(DocChange change)? _previous;
  void Function(DocChange change)? _hook;
  Set<Handle>? _objects;
  final Set<Handle> _touched = {};
  bool _loaded = false;
  bool _scheduled = false;
  bool _listening = false;

  /// Baselines built and steps read: what a listener costs.
  int debugScans = 0;

  void attach(DraftDocument document) {
    _document = document;
    final previous = _previous = document.commands.onAfterMutate;
    void hook(DocChange change) {
      previous?.call(change);
      _note(document, change);
    }

    _hook = hook;
    document.commands.onAfterMutate = hook;
    if (_listening) _rebase();
  }

  /// Reports what [attach]'s document still owes, then lets it go: its
  /// `onAfterMutate` is the one found. Before the index is disposed.
  void detach() {
    final d = _document;
    if (d == null) return;
    flush();
    if (identical(d.commands.onAfterMutate, _hook)) {
      d.commands.onAfterMutate = _previous;
    }
    _document = null;
    _hook = null;
    _previous = null;
    _objects = null;
    _touched.clear();
    _loaded = false;
  }

  /// The plan was replaced: [PlanReplaced], while anything listens.
  void replaced() {
    if (_listening) _emit(const PlanReplaced());
  }

  void listen() {
    _listening = true;
    _rebase();
  }

  void cancel() {
    _listening = false;
    _objects = null;
    _touched.clear();
    _loaded = false;
  }

  void _rebase() {
    final d = _document;
    if (d == null) return;
    debugScans++;
    _objects = rootObjects(d);
  }

  void _note(DraftDocument from, DocChange change) {
    if (!_listening || !identical(from, _document)) return;
    if (change is DocumentLoaded) {
      _loaded = true;
    } else if (change is DocumentPurged) {
      return; // handles are stable: nothing to report
    } else {
      _touched.addAll(change.touched);
    }
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_deliver);
  }

  void _deliver() {
    _scheduled = false;
    flush();
  }

  /// Reports what is owed now.
  void flush() {
    final d = _document;
    final objects = _objects;
    if (d == null || objects == null) return;
    if (_loaded) {
      _loaded = false;
      _touched.clear();
      _rebase();
      _emit(const PlanReplaced());
      return;
    }
    if (_touched.isEmpty) return;
    debugScans++;
    final changes = diffObjects(d, objects, _touched);
    _touched.clear();
    changes.forEach(_emit);
  }
}
```

- [ ] **Step 6: The services and the session.** Create `packages/jet_cad_2d_plan/lib/src/controller/services.dart`:

```dart
// PlanServices (spec 2a P1): a live view, one per kit per controller, of
// the current document, its index, the camera, the effective object snap,
// the attachment registry, the kit's words at the controller's locale, the
// kit's own tools' settings and the per-document shared cache.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'session.dart';
import 'tool_settings_store.dart';

/// What the services read of their controller.
abstract interface class ServicesHost {
  DocumentSession get session;
  CameraController get camera;
  SnapSettings get snap;
  ToolSettingsStore get toolSettings;
}

final class KitServices implements PlanServices {
  KitServices(this.kit, this._host, this.words);

  final PlanKit kit;
  final ServicesHost _host;

  @override
  final KitWords words;

  @override
  DraftDocument get document => _host.session.document;

  @override
  SpatialIndex get index => _host.session.index;

  @override
  CameraController get camera => _host.camera;

  @override
  bool get objectSnap => _host.snap.objectSnap;

  @override
  AttachmentRegistry get attachments => _host.session.attachments;

  /// The kit's own tool [toolId]'s settings: another kit's tool, a tool
  /// without settings and settings that are not an [S] are each an
  /// [ArgumentError].
  @override
  S settingsOf<S extends Object>(String toolId) {
    if (kitOfKey(toolId) != kit.id) {
      throw ArgumentError.value(
          toolId, 'toolId', 'is not a tool of the kit "${kit.id}"');
    }
    final value = _host.toolSettings.valueOf(toolId);
    if (value is! S) {
      throw ArgumentError.value(
          toolId, 'toolId', 'has settings of ${value.runtimeType}, not $S');
    }
    return value;
  }

  @override
  T shared<T extends Object>(T Function(PlanServices) create) =>
      _host.session.shared.get<T>(kit.id, this, create);
}

/// The attachment registry until Task 14: no kind, no attachment.
final class NoAttachments implements AttachmentRegistry {
  const NoAttachments();

  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) => null;

  @override
  Set<String> get kinds => const {};
}

/// Object snap as the tools, the drags and the kits read it: the user's F3
/// while the canvas allows snapping. Ported from planner_shell.dart:
/// 1759-1776 (`_CapabilitySnap`).
final class EffectiveSnap extends SnapSettings {
  EffectiveSnap(this._user, this._allowed);

  final SnapSettings _user;
  final bool Function() _allowed;

  @override
  bool get objectSnap => _allowed() && _user.objectSnap;

  @override
  void toggleObjectSnap() => _user.toggleObjectSnap();

  @override
  void addListener(VoidCallback listener) => _user.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _user.removeListener(listener);
}
```

  Create `packages/jet_cad_2d_plan/lib/src/controller/session.dart`:

```dart
// One document and everything the plan library builds over it (spec 2a
// P1 lifetimes, P2 "Documents and views"): made when the controller opens
// a document, let go when it opens the next. Ported from PlannerShell's
// construction (planner_shell.dart:277-280, :428-437, :625-671, :1050-1057)
// and disposal (:1114-1170), and FloorPlanController's _Plan
// (floor_plan_controller.dart:67-99).
import 'dart:async';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
import 'grip_dispatch.dart';
import 'services.dart';
import 'shared_cache.dart';

/// The plan library's own select tool (spec P1 reserved ids).
const String planSelectToolId = 'plan.select';

final class DocumentSession {
  DocumentSession(
      {required this.document,
      required this.measurer,
      required ParametricCatalog catalog,
      required CameraController camera,
      required SnapSettings snap})
      : page = PageNotifier(document),
        index = SpatialIndex(document),
        dispatch = GripDispatch(catalog) {
    // planner_shell.dart:625-671, the order load-bearing: the selection
    // prunes a dead key before the outline cache walks it; the grip cache
    // rebuilds after the outlines.
    selection = SelectionController(document);
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines, objects: dispatch);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: select, context: toolContext);
    _entries.add((id: planSelectToolId, tool: select, kit: false));
    // :1050-1057: the document arrives built; the system installs last.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
  }

  final DraftDocument document;
  final FlutterTextMeasurer measurer;

  /// E2's frozen objects (Task 11 fills it).
  final Set<Handle> frozen = {};

  final PageNotifier page;
  final SpatialIndex index;
  final GripDispatch dispatch;
  late final SelectionController selection;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final ToolContext toolContext;
  final SelectTool select = SelectTool();
  late final ToolController tools;
  late final ParametricSystem parametric;
  final SharedCache shared = SharedCache();

  /// The registry until Task 14 runs the providers' factories.
  AttachmentRegistry attachments = const NoAttachments();

  /// The tools by id: select, then each kit's in load order (Task 12 adds
  /// the generic tools after select).
  final List<({String id, Tool tool, bool kit})> _entries = [];
  final List<Object> _providers = [];

  /// The document's change subscription, for the history flags.
  StreamSubscription<DocChange>? history;

  /// Registers a tool that is not a kit's (Task 12's generic tools).
  void addTool(String id, Tool tool) =>
      _entries.add((id: id, tool: tool, kit: false));

  /// Runs every kit's factories over this document, once (spec P1
  /// lifetimes): its tools, then its types' grip providers.
  void runKitFactories(KitSet kits, Map<String, PlanServices> services) {
    for (final kit in kits.kits) {
      final s = services[kit.id]!;
      for (final tool in kit.tools) {
        _entries.add((id: tool.id, tool: tool.create(s), kit: true));
      }
      for (final type in kit.types) {
        final provider = type.gripsFor(s);
        if (provider == null) continue;
        dispatch.add(type.id, provider);
        _providers.add(provider);
      }
    }
  }

  Tool? toolById(String id) {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id) return _entries[i].tool;
    }
    return null;
  }

  /// [tool]'s id; select's for a tool this session does not hold.
  String idOf(Tool tool) {
    for (var i = 0; i < _entries.length; i++) {
      if (identical(_entries[i].tool, tool)) return _entries[i].id;
    }
    return planSelectToolId;
  }

  /// Spec P1 lifetimes, 2: the kit tools, the grip (and, Task 14,
  /// attachment) providers and the shared cache disposed, in that order.
  /// The active tool must be select already.
  void disposeKitProducts() {
    for (final e in _entries) {
      if (e.kit) e.tool.dispose();
    }
    _entries.removeWhere((e) => e.kit);
    dispatch.close();
    for (final p in _providers) {
      if (p is Disposable) p.dispose();
    }
    _providers.clear();
    shared.dispose();
  }

  /// Stops listening to the document.
  void detach() {
    final h = history;
    history = null;
    if (h != null) unawaited(h.cancel());
  }

  /// Everything else, after the frame that unmounts its views
  /// (planner_shell.dart:1114-1170): the tool controller before the tools,
  /// the grip cache before the outlines and the selection, the system and
  /// the index before the document.
  void dispose() {
    tools.dispose();
    for (final e in _entries) {
      e.tool.dispose();
    }
    _entries.clear();
    grips.dispose();
    outlines.dispose();
    selection.dispose();
    page.dispose();
    parametric.dispose();
    index.dispose();
    unawaited(document.dispose());
    measurer.clear();
  }
}
```

- [ ] **Step 7: The controller.** Create `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`:

```dart
// The plan controller (spec 2a P1 services and lifetimes, P2 controller):
// the validated kit set, one design document and every system and view
// over it, the kit-facing services, the camera, the save point and the
// history flags, the changes. Ported from jet_cad_floor_plan's
// FloorPlanController, design half (see Task 8's Ports), and PlannerShell's
// construction of the views (planner_shell.dart:277-671).
import 'dart:async';
import 'dart:ui' show Locale, Offset, Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show FocusManager;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../file/manifest.dart';
import '../file/plan_file.dart';
import '../kits/kit_set.dart';
import '../export/registries.dart';
import '../symbols/plan_symbols_state.dart';
import 'camera_bounds.dart';
import 'diagnostics_log.dart';
import 'new_plan.dart';
import 'plan_change.dart';
import 'services.dart';
import 'session.dart';
import 'tool_settings_store.dart';

/// The thumbnail capacity of a controller's own cache (today's
/// `kFloorPlanThumbnailCapacity`).
const int kPlanThumbnailCapacity = 128;

/// A bump-only notifier: each [bump] is one request.
final class _Requests extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// A queued centring (today's `_Centre`): [world] at the canvas's centre.
final class _Centre {
  const _Centre(this.world, this.scale, {required this.pageScale});

  final Offset world;
  final double? scale;

  /// Asked with no [scale] before the plan's first fit: the page fit's
  /// scale at the canvas's size.
  final bool pageScale;
}

final class _Host implements ServicesHost {
  _Host(this._c);

  final PlanController _c;

  @override
  DocumentSession get session => _c._session;

  @override
  CameraController get camera => _c.camera;

  @override
  SnapSettings get snap => _c._snap;

  @override
  ToolSettingsStore get toolSettings => _c.toolSettings;
}

/// One plan and everything over it (spec P2). A controller is shown in one
/// `PlanCanvas` at a time (Task 15).
class PlanController extends ChangeNotifier {
  /// A controller over [kits] and [json], or an empty plan. Throws, before
  /// it builds anything it would have to dispose: a [KitSetError] for the
  /// kits (spec P4), an [ArgumentError] unless `1e-6 <= minScale <
  /// maxScale`, both finite (today's G-3), and a [PlanFormatException]
  /// when [json] is not a plan.
  ///
  /// The empty plan prints the decimal separator of the first locale a
  /// widget reports ([reportLocale]): until then the engine's point, and
  /// then as if made so -- no undo step, not [dirty] -- unless [save] read
  /// it or an edit touched it first (today's Q0 N1, N2).
  factory PlanController({
    required List<PlanKit> kits,
    String? json,
    SymbolThumbnails? thumbnails,
    List<PlanExporter> exporters = const [],
    List<PlanImporter> importers = const [],
    double minScale = kPlanMinScale,
    double maxScale = kPlanMaxScale,
  }) {
    final set = validateKitSet(kits);
    if (!minScale.isFinite || minScale < _minScaleFloor) {
      throw ArgumentError.value(
          minScale, 'minScale', 'must be finite and at least 1e-6');
    }
    if (!maxScale.isFinite || maxScale <= minScale) {
      throw ArgumentError.value(
          maxScale, 'maxScale', 'must be finite and above minScale');
    }
    final catalog = ParametricCatalog();
    for (final type in set.types) {
      type.registerInto(catalog);
    }
    final measurer = FlutterTextMeasurer();
    final diagnostics = <Diagnostic>[];
    final DraftDocument document;
    try {
      document = json == null
          ? newPlanDocument(measurer, register: (r) => _register(r, catalog))
          : decodePlan(json,
              register: (r) => _register(r, catalog),
              diagnostics: diagnostics,
              measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    return PlanController._(set, catalog, document, measurer,
        unsettled: json == null,
        loadDiagnostics: diagnostics,
        thumbnails: thumbnails,
        exporters: exporters,
        importers: importers,
        minScale: minScale,
        maxScale: maxScale);
  }

  PlanController._(this.kits, this.catalog, DraftDocument document,
      FlutterTextMeasurer measurer,
      {required bool unsettled,
      required List<Diagnostic> loadDiagnostics,
      required SymbolThumbnails? thumbnails,
      required List<PlanExporter> exporters,
      required List<PlanImporter> importers,
      required double minScale,
      required double maxScale})
      : exporters = List.unmodifiable(exporters),
        importers = List.unmodifiable(importers),
        _minScale = minScale,
        _maxScale = maxScale,
        _ownsThumbnails = thumbnails == null,
        thumbnails =
            thumbnails ?? SymbolThumbnails(maxEntries: kPlanThumbnailCapacity),
        camera = CameraController(
            ViewportTransform(
                worldToScreenMatrix: const Transform2(1, 0, 0, -1, 0, 0)),
            minScale: minScale,
            maxScale: maxScale),
        toolSettings = ToolSettingsStore(kits) {
    _services = {
      for (final kit in kits.kits)
        kit.id: KitServices(
            kit, _host, KitNamesWords(kit.names, () => _locale.value)),
    };
    _open(document, measurer, loadDiagnostics);
    _savedState = document.commands.stateId;
    if (unsettled) _unsettled = (document: document, at: _savedState);
    _placeNominally();
    _refreshFlags();
  }

  /// The page, the contract's four components and the kits' types: what a
  /// plan's registry holds. Once per registry.
  static void _register(ComponentRegistry r, ParametricCatalog catalog) {
    PageComponent.register(r);
    registerKitComponents(r);
    catalog.registerComponents(r);
  }

  void _registerComponents(ComponentRegistry r) => _register(r, catalog);

  /// The least `minScale`: a thousand times the bound decisions' tolerance.
  static const double _minScaleFloor = 1e-6;

  /// The validated kits, in load order (spec P4).
  final KitSet kits;

  /// Every kit's types, registered once for the controller's life.
  @internal
  final ParametricCatalog catalog;

  /// The one camera of the controller's views, bounded by the zoom bounds.
  final CameraController camera;

  @internal
  final ToolSettingsStore toolSettings;

  /// The symbol thumbnails: the given one, never disposed here, or the
  /// controller's own.
  final SymbolThumbnails thumbnails;
  final bool _ownsThumbnails;

  /// The host's exporters and importers, in order (spec P5); Task 19 adds
  /// the built-in ones and the flows.
  @internal
  final List<PlanExporter> exporters;
  @internal
  final List<PlanImporter> importers;

  final double _minScale, _maxScale;

  late final Map<String, KitServices> _services;
  late final _Host _host = _Host(this);
  late DocumentSession _session;
  List<Diagnostic> _loadDiagnostics = const [];

  final List<DocumentSession> _dropped = [];
  bool _disposed = false;

  final SnapSettings _userSnap = SnapSettings();
  late final EffectiveSnap _snap =
      EffectiveSnap(_userSnap, () => snappingAllowed);

  /// The canvas's `snapping` option (Task 15): object snap only while true.
  @internal
  bool snappingAllowed = true;

  final ValueNotifier<Locale> _locale = ValueNotifier(const Locale('en'));
  final DiagnosticsLog _diagnostics = DiagnosticsLog();
  final ValueNotifier<PlanSymbolsState> _symbolsState =
      ValueNotifier(PlanSymbolsState.ready);
  final ValueNotifier<bool> _dirty = ValueNotifier(false);
  final ValueNotifier<bool> _canUndo = ValueNotifier(false);
  final ValueNotifier<bool> _canRedo = ValueNotifier(false);
  final ValueNotifier<String> _activeTool = ValueNotifier(planSelectToolId);
  Set<String> _missingKits = const {};

  late final PlanChangeTracker _tracker = PlanChangeTracker(_emit);
  late final StreamController<PlanChange> _out =
      StreamController<PlanChange>.broadcast(
          onListen: _tracker.listen, onCancel: _tracker.cancel);
  late final Stream<PlanChange> _changeStream =
      _out.stream.where((_) => !_disposed);

  final List<VoidCallback> _settles = [];

  // ---------------------------------------------------------------------
  // The plan.

  /// The plan's document. Replaced by [load] and [newPlan].
  DraftDocument get document => _session.document;

  /// Whether the plan differs from its save point.
  ValueListenable<bool> get dirty => _dirty;

  int _savedState = 0;

  /// The state the last [save] encoded.
  int? _encodedState;

  /// The plan made with no locale known and its state then, while it is
  /// unsettled; null for a settled or a loaded plan.
  ({DraftDocument document, int at})? _unsettled;

  /// The last locale a widget reported, for [newPlan].
  Locale? _reported;

  /// The plan's text: the engine's JSON with the manifest of the kits it
  /// uses (Task 7). [markSaved] marks the state encoded here. An empty plan
  /// read here is settled as it is.
  String save() {
    settlePendingInput();
    _unsettled = null;
    _encodedState = document.commands.stateId;
    return encodePlan(document, kits);
  }

  /// The host stored the last [save]: that state is the save point; an
  /// edit made since stays dirty. With no [save] yet, the current state.
  void markSaved() {
    settlePendingInput();
    _savedState = _encodedState ?? document.commands.stateId;
    _refreshFlags();
  }

  /// Replaces the plan with [text] (spec P2). Pending input is settled into
  /// the old plan first. Throws a [PlanFormatException] (a
  /// [FormatException]) and changes nothing when [text] is not a plan.
  void load(String text) {
    settlePendingInput();
    final measurer = FlutterTextMeasurer();
    final diagnostics = <Diagnostic>[];
    final DraftDocument next;
    try {
      next = decodePlan(text,
          register: _registerComponents,
          diagnostics: diagnostics,
          measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    _replace(next, measurer, unsettled: false, loadDiagnostics: diagnostics);
  }

  /// Replaces the plan with an empty one printing [decimalSeparator] (`.`
  /// or `,`; any other is an [ArgumentError], and nothing changes); without
  /// one, the separator of the locale last reported, or, with none
  /// reported yet, point and unsettled, as the constructor's plan.
  void newPlan({String? decimalSeparator}) {
    final DecimalSeparator? given = switch (decimalSeparator) {
      null => null,
      '.' => DecimalSeparator.point,
      ',' => DecimalSeparator.comma,
      _ => throw ArgumentError.value(
          decimalSeparator, 'decimalSeparator', 'must be "." or ","'),
    };
    settlePendingInput();
    final reported = _reported;
    final separator = given ??
        (reported == null
            ? DecimalSeparator.point
            : decimalSeparatorFor(reported));
    final measurer = FlutterTextMeasurer();
    _replace(
        newPlanDocument(measurer,
            register: _registerComponents, decimalSeparator: separator),
        measurer,
        unsettled: given == null && reported == null);
  }

  /// The kits the plan names or uses that are not loaded (spec P4).
  Set<String> get missingKits => _missingKits;

  /// The engine's diagnostics of the last load, kept (spec P4; Task 11).
  @internal
  List<Diagnostic> get loadDiagnostics => _loadDiagnostics;

  /// The type of [object] (E1), or null for anything that is not a live
  /// object of a loaded kit's type.
  PlanType<Component>? typeOf(Handle object) {
    final typeId = catalog.typeIdOf(document, object);
    return typeId == null ? null : kits.typeOf(typeId);
  }

  // ---------------------------------------------------------------------
  // Opening and replacing documents.

  void _open(DraftDocument document, FlutterTextMeasurer measurer,
      List<Diagnostic> loadDiagnostics) {
    final session = DocumentSession(
        document: document,
        measurer: measurer,
        catalog: catalog,
        camera: camera,
        snap: _snap);
    _session = session;
    session.runKitFactories(kits, _services);
    session.tools.addListener(_onTools);
    session.history = document.commands.changes.listen((_) {
      if (!_disposed) _refreshFlags();
    });
    _loadDiagnostics = List.unmodifiable(loadDiagnostics);
    _readManifest();
    _tracker.attach(document);
  }

  /// What the plan's manifest says against the loaded kits (Task 7).
  void _readManifest() {
    _diagnostics.clearPlanScoped();
    final d = _session.document;
    final manifest = manifestOf(d);
    if (manifest == null) {
      _missingKits = const {};
      return;
    }
    final check = checkManifest(manifest, usedKits(d), kits);
    _missingKits = check.missing;
    _diagnostics.reportAll(check.diagnostics);
  }

  /// [document] becomes the plan (spec P1 lifetimes): 1. the active tool
  /// cancelled and select armed; the old plan's owed changes reported;
  /// 2. the old document's kit products disposed; 3. the factories run
  /// over the new document. The old views go after the next frame.
  void _replace(DraftDocument document, FlutterTextMeasurer measurer,
      {required bool unsettled,
      List<Diagnostic> loadDiagnostics = const []}) {
    final old = _session;
    old.tools.activate(old.select);
    old.tools.removeListener(_onTools);
    _tracker.detach();
    old.disposeKitProducts();
    old.detach();
    _open(document, measurer, loadDiagnostics);
    _tracker.replaced();
    _activeTool.value = planSelectToolId;
    _savedState = document.commands.stateId;
    _unsettled =
        unsettled ? (document: document, at: document.commands.stateId) : null;
    _encodedState = null;
    _fitOnStart = true;
    _fitTarget = null;
    _placeNominally();
    _refreshFlags();
    _drop(old);
    notifyListeners();
  }

  /// Lets [session] go after the frame that unmounts its views (today's
  /// R-2).
  void _drop(DocumentSession session) {
    _dropped.add(session);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_dropped.remove(session)) session.dispose();
      })
      ..ensureVisualUpdate();
  }

  void _refreshFlags() {
    final commands = document.commands;
    _dirty.value = commands.stateId != _savedState;
    _canUndo.value = commands.canUndo;
    _canRedo.value = commands.canRedo;
  }

  // ---------------------------------------------------------------------
  // Undo and redo.

  ValueListenable<bool> get canUndo => _canUndo;
  ValueListenable<bool> get canRedo => _canRedo;

  bool get _midShape => _session.tools.active.isMidShape;

  /// Undoes the last step, after settling pending input; nothing while the
  /// active tool is part-way through a shape (today's S-4).
  void undo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (commands.canUndo) commands.undo();
  }

  /// Redoes the next step, as [undo].
  void redo() {
    if (_midShape) return;
    settlePendingInput();
    final commands = document.commands;
    if (commands.canRedo) commands.redo();
  }

  // ---------------------------------------------------------------------
  // Tools and the selection.

  /// The active tool's id (`plan.select`, a kit's `<kit>.<tool>`).
  ValueListenable<String> get activeTool => _activeTool;

  void _onTools() {
    _activeTool.value = _session.idOf(_session.tools.active);
  }

  /// Arms the tool [id] (spec P2), as a palette tap would, and answers
  /// whether it is now active: false for an unknown id, a tool the
  /// permissions refuse (Task 12), and a drawing tool while the plan's
  /// permissions deny geometry. A drawing tool clears the selection
  /// (planner_shell.dart:926-933).
  bool selectTool(String id) {
    final session = _session;
    final tool = session.toolById(id);
    if (tool == null || !_allowsTool(id)) return false;
    final drawing = !identical(tool, session.select);
    if (drawing &&
        !document.commands.permissions.allows(Capability.geometry)) {
      return false;
    }
    if (drawing) session.selection.clear();
    session.tools.activate(tool);
    return true;
  }

  /// The permissions' say on a tool; Task 12 fills it.
  bool _allowsTool(String id) => true;

  /// Deletes the selection as the select tool's Delete does, one undo step
  /// (spec P2), after settling pending input. False with nothing selected,
  /// while a shape is part-way, and when every selected object is refused.
  /// Tasks 10 and 12 add the lock and `delete: false`.
  bool deleteSelection() {
    if (_midShape) return false;
    settlePendingInput();
    final session = _session;
    return session.select.deleteSelection(session.toolContext);
  }

  @internal
  ToolController get toolController => _session.tools;
  @internal
  ToolContext get toolContext => _session.toolContext;
  @internal
  SelectionController get selection => _session.selection;
  @internal
  SpatialIndex get index => _session.index;
  @internal
  PageNotifier get page => _session.page;
  @internal
  GripCache get grips => _session.grips;
  @internal
  OutlineCache get outlines => _session.outlines;
  /// The user's F3 setting (Tasks 15, 16, 20 read and toggle it). The
  /// tools and the kits read the effective flag: this while
  /// [snappingAllowed] ([EffectiveSnap]).
  @internal
  SnapSettings get snap => _userSnap;
  @internal
  ParametricSystem get parametric => _session.parametric;
  @internal
  Set<Handle> get frozen => _session.frozen;
  @internal
  DiagnosticsLog get diagnosticsLog => _diagnostics;

  /// The tool [id] of the current document, or null.
  @internal
  Tool? toolFor(String id) => _session.toolById(id);

  /// The kit [kitId]'s services.
  @internal
  PlanServices servicesOf(String kitId) =>
      _services[kitId] ??
      (throw ArgumentError.value(kitId, 'kitId', 'is no loaded kit'));

  // ---------------------------------------------------------------------
  // Pending input.

  /// Registers a settle (a panel field's, the text entry's): called, in
  /// order, before the controller reads or replaces the plan. Returns its
  /// withdrawal, which withdraws only [settle].
  @internal
  VoidCallback registerSettle(VoidCallback settle) {
    _settles.add(settle);
    return () => _settles.remove(settle);
  }

  /// Settles input typed and not committed (planner_shell.dart:859-865):
  /// each registered settle, then the pending focus changes now, so a
  /// field's focus-loss commit lands before the caller reads the plan.
  /// Synchronous, and never called in a build.
  @internal
  void settlePendingInput() {
    for (final settle in List.of(_settles)) {
      settle();
    }
    FocusManager.instance.applyFocusChangesIfNeeded();
  }

  // ---------------------------------------------------------------------
  // The locale.

  /// The app's locale, as the widgets report it (spec P5). Kits' words
  /// read it live.
  ValueListenable<Locale> get locale => _locale;

  bool get _untouched {
    final u = _unsettled;
    if (u == null || !identical(u.document, document)) return false;
    final commands = u.document.commands;
    return commands.stateId == u.at && !commands.canRedo;
  }

  /// A widget's locale (floor_plan_controller.dart:1028-1045): kept for
  /// [newPlan] and the kits' words. An unsettled, untouched plan takes its
  /// separator now, as if made so: the page's command, then the history
  /// cleared and the save point moved, so it stays clean with no step.
  @internal
  void reportLocale(Locale locale) {
    _locale.value = locale;
    _reported = locale;
    final untouched = _untouched;
    _unsettled = null;
    if (!untouched) return;
    final d = document;
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    final separator = decimalSeparatorFor(locale);
    if (page.decimalSeparator == separator) return;
    d.commands.execute(SetComponentCommand<PageComponent>(
        d.rootHandle, page.copyWith(decimalSeparator: separator)));
    d.commands.clearHistory();
    _savedState = d.commands.stateId;
  }

  // ---------------------------------------------------------------------
  // State.

  ValueListenable<List<KitDiagnostic>> get diagnostics => _diagnostics;

  /// Task 13 drives it; `ready` until then.
  ValueListenable<PlanSymbolsState> get symbolsState => _symbolsState;

  /// The plan's changes (spec P2 "Events"), a broadcast stream delivered
  /// asynchronously, one report per synchronous step. Closed by [dispose]:
  /// nothing reaches a listener after it.
  Stream<PlanChange> get changes => _changeStream;

  void _emit(PlanChange change) {
    if (!_disposed) _out.add(change);
  }

  @visibleForTesting
  int get debugChangeScans => _tracker.debugScans;

  // ---------------------------------------------------------------------
  // The camera (floor_plan_controller.dart:340-356, :419-526, :812-893,
  // :1966-2060).

  void _placeNominally() {
    const size = Size(1440, 900);
    camera.value = clampCameraScale(_pageFit(document, size), size,
        minScale: _minScale, maxScale: _maxScale);
  }

  static ViewportTransform _pageFit(DraftDocument d, Size size) {
    final page = d.components.isRegistered<PageComponent>()
        ? d.components.get<PageComponent>(d.rootHandle)
        : null;
    return page != null
        ? fitToPage(page, size)
        : ViewportTransform.fit(d.extents, size);
  }

  final ValueNotifier<Rect?> _canvasRect = ValueNotifier(null);
  final Map<Object, Rect> _canvases = {};

  /// The canvas's place in global logical pixels, or null while none is
  /// mounted.
  ValueListenable<Rect?> get canvasRect => _canvasRect;

  /// A canvas is at [global], or, null, [view] is going.
  @internal
  void canvasPlaced(Object view, Rect? global) {
    if (_disposed) return;
    if (global != null) {
      _canvases
        ..remove(view)
        ..[view] = global;
      _canvasRect.value = global;
      return;
    }
    if (_canvases.remove(view) == null) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_disposed) return;
        _canvasRect.value = _canvases.isEmpty ? null : _canvases.values.last;
      })
      ..ensureVisualUpdate();
  }

  int _cameraEpoch = 0;

  @internal
  int get cameraEpoch => _cameraEpoch;

  final _Requests _fits = _Requests();

  @internal
  Listenable get fitRequests => _fits;

  bool _fitOnStart = true;
  bool _fitPending = false;
  _Centre? _fitTarget;

  @internal
  bool takeFitOnStart() {
    final fit = _fitOnStart || _fitPending;
    _fitOnStart = false;
    return fit;
  }

  @internal
  bool get owesFirstFit => _fitOnStart;

  @internal
  void fitted() => _fitPending = false;

  /// The camera a fit sets in a canvas of [viewport]: null for the page,
  /// else the queued centring. Not finite: none.
  @internal
  ViewportTransform? framingFor(Size viewport) {
    final target = _fitTarget;
    if (target == null) return null;
    final framing = _centred(
        target.world,
        target.pageScale
            ? _pageFit(document, viewport).worldToScreenMatrix.scaleMagnitude
            : target.scale,
        viewport);
    final m = framing.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f].every((v) => v.isFinite)
        ? framing
        : null;
  }

  ViewportTransform _centred(Offset world, double? scale, Size viewport) {
    final m = camera.value.worldToScreenMatrix;
    final k = scale == null ? 1.0 : scale / m.scaleMagnitude;
    final a = m.a * k, b = m.b * k, c = m.c * k, d = m.d * k;
    return ViewportTransform(
        worldToScreenMatrix: Transform2(
            a,
            b,
            c,
            d,
            viewport.width / 2 - (a * world.dx + c * world.dy),
            viewport.height / 2 - (b * world.dx + d * world.dy)));
  }

  /// The canvas frames the plan as on its first frame; it replaces a
  /// [centerOn] not yet performed.
  void fitToView() {
    _fitTarget = null;
    _request();
  }

  void _request() {
    _fitPending = true;
    _cameraEpoch++;
    _fits.bump();
  }

  /// Puts [world] at the canvas's centre, at [scale] or the camera's, the
  /// next time the canvas fits. An [ArgumentError] for a [world] that is
  /// not finite or a [scale] that is not finite and above 0.
  void centerOn(Offset world, {double? scale}) {
    if (!world.isFinite) {
      throw ArgumentError.value(world, 'world', 'must be finite');
    }
    if (scale != null && (!scale.isFinite || scale <= 0)) {
      throw ArgumentError.value(scale, 'scale', 'must be finite and above 0');
    }
    _fitTarget =
        _Centre(world, scale, pageScale: scale == null && _fitOnStart);
    _request();
  }

  /// Pans by [canvasDelta] at once; a fit requested and not performed is
  /// dropped. An [ArgumentError] for a delta that is not finite.
  void panBy(Offset canvasDelta) {
    if (!canvasDelta.isFinite) {
      throw ArgumentError.value(canvasDelta, 'canvasDelta', 'must be finite');
    }
    _command();
    camera.panBy(canvasDelta);
  }

  /// Zooms by [factor] about [focus] (the canvas's centre by default),
  /// clamped to the bounds; false, changing nothing, with no canvas, a
  /// [factor] that is not finite and above 0, or a [focus] not finite.
  bool zoomBy(double factor, {Offset? focus}) {
    final rect = _canvasRect.value;
    if (rect == null || !factor.isFinite || factor <= 0) return false;
    if (focus != null && !focus.isFinite) return false;
    _command();
    camera.zoomAt(focus ?? rect.size.center(Offset.zero), factor);
    return true;
  }

  void _command() {
    _cameraEpoch++;
    if (_fitPending) {
      _fitPending = false;
      _fitTarget = null;
    }
  }

  // ---------------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;
    _tracker.detach();
    for (final s in _dropped) {
      s.dispose();
    }
    _dropped.clear();
    final session = _session;
    session.tools.removeListener(_onTools);
    session
      ..disposeKitProducts()
      ..detach()
      ..dispose();
    if (_ownsThumbnails) thumbnails.dispose();
    toolSettings.dispose();
    _diagnostics.dispose();
    _locale.dispose();
    _symbolsState.dispose();
    _dirty.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
    _activeTool.dispose();
    _canvasRect.dispose();
    _fits.dispose();
    _snap.dispose();
    _userSnap.dispose();
    camera.dispose();
    _settles.clear();
    unawaited(_out.close());
    super.dispose();
  }
}
```

  In `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` add (keeping the exports sorted):

```dart
export 'src/controller/camera_bounds.dart' show kPlanMaxScale, kPlanMinScale;
export 'src/controller/plan_change.dart'
    show
        PlanChange,
        PlanObjectAdded,
        PlanObjectChanged,
        PlanObjectRemoved,
        PlanReplaced;
export 'src/controller/plan_controller.dart';
export 'src/export/registries.dart';
export 'src/symbols/plan_symbols_state.dart';
```

- [ ] **Step 8: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/controller`. Expected: `All tests passed!`. Then the whole package: `flutter test`; expected: `All tests passed!`.

- [ ] **Step 9: Format and the gates.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`, all exit 0 (`No issues found!`). The engine and the Flutter layer are not changed here: `git diff --stat main -- packages/jet_cad_2d packages/jet_cad_2d_flutter` shows only Tasks 1-2's engine files.

- [ ] **Step 10: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/src/controller/plan_change.dart packages/jet_cad_2d_plan/lib/src/controller/services.dart packages/jet_cad_2d_plan/lib/src/controller/shared_cache.dart packages/jet_cad_2d_plan/lib/src/controller/grip_dispatch.dart packages/jet_cad_2d_plan/lib/src/controller/tool_settings_store.dart packages/jet_cad_2d_plan/lib/src/controller/diagnostics_log.dart packages/jet_cad_2d_plan/lib/src/controller/new_plan.dart packages/jet_cad_2d_plan/lib/src/controller/camera_bounds.dart packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart packages/jet_cad_2d_plan/lib/src/export/registries.dart packages/jet_cad_2d_plan/test/support/harness.dart packages/jet_cad_2d_plan/test/controller/plan_controller_test.dart packages/jet_cad_2d_plan/test/controller/locale_separator_test.dart packages/jet_cad_2d_plan/test/controller/camera_test.dart packages/jet_cad_2d_plan/test/controller/lifetimes_test.dart packages/jet_cad_2d_plan/test/controller/covariance_test.dart packages/jet_cad_2d_plan/test/controller/plan_change_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanController, its documents, services and changes

One controller owns the validated kits, one plan and every view over it:
the parametric system over a catalog of every kit's types, the index,
page, selection, outline and grip caches (one grip provider dispatching
by typeIdOf), the tool controller with select and the kits' tools, and a
PlanServices per kit. Load and newPlan settle pending input into the old
plan, cancel the tool, dispose the kit products and run the factories
again. The save point, undo and redo, the camera commands and the
locale-settled empty plan are ported from FloorPlanController's design
half; changes report objects added, changed and removed per step.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Mutation step** (committed files only; after each: run the named test with `cd packages/jet_cad_2d_plan && flutter test test/controller/<file> --plain-name '<id> '`, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0). Files are under `lib/src/controller/` unless named.
  - M-C1a (`new_plan.dart`): delete `doc.header.units = DrawingUnits.millimeters;` → C1 red.
  - M-C1b (`new_plan.dart`): delete `doc.commands.clearHistory();` → C1 red.
  - M-C2 (`plan_controller.dart`): in the factory, replace `: decodePlan(json, ...)` with `: (() { try { return decodePlan(json, register: (r) => _register(r, catalog), diagnostics: diagnostics, measurer: measurer); } catch (_) { return newPlanDocument(measurer, register: (r) => _register(r, catalog)); } })()` → C2 red.
  - M-C3 (`plan_controller.dart`): in `load`, replace `} catch (_) { measurer.clear(); rethrow; }` with `} catch (_) { next = newPlanDocument(measurer, register: _registerComponents); }` → C3 red.
  - M-C4 (`plan_controller.dart`): in `markSaved`, `_savedState = document.commands.stateId;` → C4 red.
  - M-C5 (`plan_controller.dart`): in `_replace`, delete `_savedState = document.commands.stateId;` → C5 red.
  - M-C6 (`plan_controller.dart`): in `_replace`, delete `_encodedState = null;` → C6 red.
  - M-C7a (`plan_controller.dart`): in `_readManifest`, replace everything after `_diagnostics.clearPlanScoped();` with `_missingKits = const {};` → C7 red.
  - M-C7b (`plan_controller.dart`): delete `_diagnostics.clearPlanScoped();` → C7 red.
  - M-C8 (`plan_controller.dart`): in `undo` and `redo`, delete `if (_midShape) return;` → C8 red.
  - M-C9a (`plan_controller.dart`): delete `if (drawing) session.selection.clear();` → C9 red.
  - M-C9b (`plan_controller.dart`): delete the `if (drawing && !document.commands.permissions.allows(Capability.geometry)) { return false; }` block → C9 red.
  - M-C10 (`plan_controller.dart`): in `deleteSelection`, delete `if (_midShape) return false;` → C10 red.
  - M-C11 / M-C-swap-a (`plan_controller.dart`): in `load`, delete `settlePendingInput();` → C11 red and C-swap-mid-shape red.
  - M-C-swap-b (`plan_controller.dart`): in `load`, move `settlePendingInput();` after the `_replace(...)` call → C-swap-mid-shape red (the value lands in the new plan).
  - M-C-swap-c (`plan_controller.dart`): in `_replace`, delete `old.tools.activate(old.select);` → C-swap-mid-shape red.
  - M-C-life1 (`plan_controller.dart`): in `_replace`, delete `old.disposeKitProducts();` → C-life1 red.
  - M-C-life2a (`shared_cache.dart`): `final key = ('', T);` → C-life2 red.
  - M-C-life2b (`shared_cache.dart`): replace `if (!_making.add(key)) { throw ... }` with `_making.add(key);` → C-life2 red (a stack overflow, not a `StateError`).
  - M-C-svc-a (`services.dart`): delete the `if (kitOfKey(toolId) != kit.id) { ... }` block → C-svc red.
  - M-C-svc-c (`plan_controller.dart`): `KitNamesWords(kit.names, () => const Locale('en'))` → C-svc red.
  - M-C-svc-d (`services.dart`): `bool get objectSnap => _user.objectSnap;` in `EffectiveSnap` → C-svc red.
  - M-C-grips-a (`grip_dispatch.dart`): `ObjectGripProvider? _of(DraftDocument d, Handle group) => null;` → C-grips red.
  - M-C-grips-b (`session.dart`): in `disposeKitProducts`, delete `dispatch.close();` → C-grips red.
  - M-C-cov-a (`plan_controller.dart`): `PlanType<Component>? typeOf(Handle object) => kits.types.first;` → C-covariance red.
  - M-C-cov-b (`plan_controller.dart`): in the factory, `for (final type in set.kits.first.types)` → C-covariance red (the disc's component type is not registered).
  - M-CM4 (`plan_controller.dart`): `if (!maxScale.isFinite)` (the `maxScale <= minScale` check dropped) → CM4 red (an `AssertionError` from `CameraController`, not an `ArgumentError`).
  - M-CM5 (`plan_controller.dart`): in `_command`, delete `_fitTarget = null;` → CM5 red.
  - M-CM6a (`plan_controller.dart`): in `zoomBy`, `final rect = _canvasRect.value ?? Offset.zero & const Size(1440, 900); if (!factor.isFinite || factor <= 0) return false;` → CM6 red.
  - M-CM6b (`plan_controller.dart`): `camera.zoomAt(focus ?? Offset.zero, factor);` → CM6 red.
  - M-CM15 (`plan_controller.dart`): `static const double _minScaleFloor = 0;` → CM15 red.
  - M-C-cam1a (`plan_controller.dart`): in `_centred`, `final k = 1.0;` → C-cam1 red.
  - M-C-cam1b (`plan_controller.dart`): in `fitToView`, delete `_fitTarget = null;` → C-cam1 red.
  - M-NS1 (`plan_controller.dart`): in `reportLocale`, delete `d.commands.clearHistory();` → NS1 red.
  - M-NS3 (`plan_controller.dart`): in `load`, `unsettled: true` → NS3 red.
  - M-NS4 (`plan_controller.dart`): in `save`, delete `_unsettled = null;` → NS4 red.
  - M-NS6 (`plan_controller.dart`): in `reportLocale`, replace `final untouched = _untouched; _unsettled = null; if (!untouched) return;` with `if (!_untouched) return;` → NS6 red.
  - M-NS8 (`plan_controller.dart`): in `newPlan`, `unsettled: false` → NS8 red.
  - M-NS9 (`plan_controller.dart`): in `_replace`, `_unsettled = unsettled ? (document: document, at: document.commands.stateId) : _unsettled;` **and** in `_untouched`, `if (u == null) return false;` → NS9 red.
  - M-NS10 (`plan_controller.dart`): in `newPlan`, `final separator = reported == null ? DecimalSeparator.point : decimalSeparatorFor(reported);` (the argument checked, then ignored) → NS10 red.
  - M-C-ch1a (`plan_change.dart`): in `rootObjectOf`, `if (slot != null) return h;` in place of the owner check → C-ch1 red.
  - M-C-ch1b (`plan_change.dart`): in `diffObjects`, `final sorted = touched.toList();` and `final all = {...removed, ...added, ...changed}.toList();` (no sorts) → C-ch1 red.
  - M-C-ch2 (`plan_controller.dart`): in `_replace`, delete `_tracker.replaced();` → C-ch2 red.
  - M-C-ch3 (`plan_change.dart`): in `detach`, delete `flush();` → C-ch3 red.
  - M-C-ch4a (`plan_change.dart`): in `attach`, `_rebase();` in place of `if (_listening) _rebase();` → C-ch4 red.
  - M-C-ch4b (`plan_change.dart`): in `_note`, replace the three scheduling lines with `flush();` → C-ch4 red.
  - M-C-ch5 (`plan_controller.dart`): `late final Stream<PlanChange> _changeStream = _out.stream;` → C-ch5 and C-ch7 red.
  - M-C-ch6 (`plan_controller.dart`): in `load`, add `_tracker.detach();` before `final measurer = FlutterTextMeasurer();` → C-ch6 red.
  - M-C13 (`plan_controller.dart`): `: exporters = const [], importers = const [],` in the private constructor's initializer list → C13 red.
  - M-C-ch8 (`plan_change.dart`): `bool operator ==(Object other) => other is PlanObjectAdded;` → C-ch8 red.

#### Interface problem

Resolved by controller ruling R-d (`Disposable` is Task 4's, `jet_cad_2d_kit` `plan_services.dart`); the sequencing of `permissions` (Task 12) and `symbols` (Task 13) is stated in those tasks.

---

