# Task 8 report: PlanController core

Status: DONE. Commit `551985c8` (on top of `6df8967a`).

## Implemented

All files the brief names, under `packages/jet_cad_2d_plan`:

- `lib/src/controller/plan_controller.dart`, `session.dart`, `plan_change.dart`, `services.dart`, `shared_cache.dart`, `grip_dispatch.dart`, `tool_settings_store.dart`, `diagnostics_log.dart`, `new_plan.dart`, `camera_bounds.dart`
- `lib/src/symbols/plan_symbols_state.dart`, `lib/src/export/registries.dart` (exporter and importer interfaces and `PlanExportRequest` only; Task 19 extends it)
- `lib/jet_cad_2d_plan.dart`: the barrel exports, sorted
- `test/support/harness.dart`: `import 'test_kit.dart';`, `controllerFor`, `slabPlanText`, `slabsOf`, `setSlabWidth`
- Tests in `test/controller/`: `plan_controller_test.dart`, `locale_separator_test.dart`, `camera_test.dart`, `lifetimes_test.dart`, `covariance_test.dart`, `plan_change_test.dart`

Carried rulings:
- **Task 7 review carry.** `_open` calls `_readManifest`, which runs `checkManifest(manifestOf(d), usedKits(d), kits)` and reports its `kitMissing`/`kitNewer` diagnostics into the `DiagnosticsLog`. It does this for the constructor's json and for every `load` (C7, and the new C14). Each `decodePlan` call (in the factory and in `load`) gets its own fresh `<Diagnostic>[]`. A refused load throws before `_replace`, so `diagnostics`, `loadDiagnostics`, `missingKits` and the document are left as they were. C14 pins this with two mutations.
- **Tool settings belong to the controller.** `ToolSettingsStore` is a controller field and survives a swap. C-svc pins it ("the controller holds one value per tool, across plans"). Today's shell kept tool settings per document; the plan library deliberately does not.
- `toolController` is the accessor name; `registerSettle`/`settlePendingInput` exist; `lib/src/export/registries.dart` and `lib/src/controller/camera_bounds.dart` were created here.

Kit products are now really exercised, as the dispatch asked:
- `SlabTool`:
  - Built by the factory: C-life1 (the `tool+1`/`tool-1` events, and the same `SlabCache` through `shared`).
  - Mid-shape: C8, C10 and C-swap-mid-shape.
  - Committing: an addition to C-svc arms the new plan's slab tool and clicks twice. The tool commits a slab whose size comes from `PlanServices.settingsOf`, after the settings were stored as 2400 x 750. The test asserts `(placed.width, placed.height) == (2400.0, 750.0)`.
- `SlabGrips`, reached through the controller's `GripDispatch`:
  - `gripsOf` and `drag` (the brief's C-grips).
  - `preview`, added to C-grips: the previewed polyline's corners are those of a 2600 x 900 slab turned 0.4 rad at (2350, -1180).
  - `dispose`, through the `grips-1` event (C-life1).
- `PlanServices`:
  - `settingsOf`, `words`, `objectSnap`, `document`, `index`, `camera` and `attachments` (C-svc).
  - `shared`: per kit, refusing a create that asks for itself, and per document (C-life2).

## TDD evidence

RED (Step 3), with the tests and the harness written and no implementation (`flutter test test/controller`, exit 1). Six suites failed to compile, for example:
```
test/support/harness.dart:125:1: Error: Type 'PlanController' not found.
test/support/harness.dart:154:19: Error: Type 'PlanController' not found.
test/support/harness.dart:128:23: Error: Undefined name 'kPlanMinScale'.
```
GREEN (Step 8), after the implementation: `flutter test test/controller` ended `00:00 +38: All tests passed!` (the brief's 38 tests). After the three additions below: 39 controller tests. The whole package now ends `00:01 +64: All tests passed!`.

The added C14 first failed on a matcher issue in the test itself. A record holding a `List` does not compare deeply: `Expected: [(String, List<int>):(component.unreadable, [18])]`, `Actual:` the same text. I split the comparison into `code` and `handles`, and it passed. The controller code did not change.

## Mutations

All of them were run after the commit, on committed files. Each was applied, its named test run, then reverted with `git checkout -- <file>`. `git diff --quiet -- <file>` returned 0 (`revert=0`) after every one. A Python driver did the apply, run, revert and check; its log is in the session scratchpad. Every mutation turned its test red. The red lines:

| id | file | test | red line |
|---|---|---|---|
| M-C1a | new_plan.dart | C1 | `Expected: DrawingUnits.millimeters` / `Actual: DrawingUnits.unitless` (line 39) |
| M-C1b | new_plan.dart | C1 | `Expected: false` / `Actual: <true>` (line 41, canUndo) |
| M-C2 | plan_controller.dart | C2 | `Expected: throws FormatException` / `Which: returned <Instance of 'PlanController'>` |
| M-C3 | plan_controller.dart | C3 | `Expected: throws FormatException` / `Which: returned <null>` |
| M-C4 | plan_controller.dart | C4 | `Expected: true` / `Actual: <false>` (line 96) |
| M-C5 | plan_controller.dart | C5 | `Expected: false` / `Actual: <true>` (line 113) |
| M-C6 | plan_controller.dart | C6 | `Expected: false` / `Actual: <true>` (line 131) |
| M-C7a | plan_controller.dart | C7 | `Expected: Set:['gone']` / `Actual: Set:[]` |
| M-C7b | plan_controller.dart | C7 | `Expected: empty` / `Actual: [` (line 166) |
| M-C8 | plan_controller.dart | C8 | `Expected: <2>` / `Actual: <1>` (line 182, stateId) |
| M-C9a | plan_controller.dart | C9 | `Expected: true` / `Actual: <false>` (line 204, selection.isEmpty) |
| M-C9b | plan_controller.dart | C9 | `Expected: false` / `Actual: <true>` (line 211) |
| M-C10 | plan_controller.dart | C10 | `Expected: false` / `Actual: <true>` (line 236) |
| M-C11 | plan_controller.dart | C11 | `Expected: [... 'newPlan', 'load']` / `Actual: [... 'newPlan']` |
| M-C13 | plan_controller.dart | C13 | `Expected: ['acme.dxf', 'acme.svg']` / `Actual: []` |
| M-C14a (added) | plan_controller.dart: `_diagnostics.clearPlanScoped();` before load decodes | C14 | `Expected: same instance as [` / `Actual: []` (line 307) |
| M-C14b (added) | plan_controller.dart: `_loadDiagnostics = const [];` before load decodes | C14 | `Expected: same instance as [` / `Actual: []` (line 308) |
| M-C-swap-a | plan_controller.dart | C-swap-mid-shape | `Expected: <2750>` / `Actual: <1800.0>` (line 195) |
| M-C-swap-b | plan_controller.dart | C-swap-mid-shape | `Expected: <2750>` / `Actual: <1800.0>` (line 195) |
| M-C-swap-c | plan_controller.dart | C-swap-mid-shape | `Expected: false` / `Actual: <true>` (line 198, isMidShape) |
| M-C-life1 | plan_controller.dart | C-life1 | `Expected: ['tool-1', 'grips-1', 'cache-1', 'cache+2', ...]` / `Actual: ['cache+2', 'tool+2', 'grips+2']` |
| M-C-life2a | shared_cache.dart | C-life2 | `Expected: not same instance as <_Probe>` (line 59) |
| M-C-life2b | shared_cache.dart | C-life2 | `Expected: throws StateError` / `Which: returned <Instance of '_Loop'>` (see Deviations) |
| M-C-svc-a | services.dart | C-svc | `Expected: throws ArgumentError` / `Which: returned <Instance of 'SlabSettings'>` |
| M-C-svc-c | plan_controller.dart | C-svc | `Expected: 'Döşeme'` / `Actual: 'Slab'` |
| M-C-svc-d | services.dart | C-svc | `Expected: false` / `Actual: <true>` (line 115) |
| M-C-svc-e (added) | tool_settings_store.dart: `store` drops `_values[toolId] = value;` | C-svc | `Expected: <2400>` / `Actual: <1200.0>` (line 85) |
| M-C-grips-a | grip_dispatch.dart | C-grips | `StateError: Bad state: No element` at `grips.single` (line 143) |
| M-C-grips-b | session.dart | C-grips | `Expected: empty` / `Actual: [Grip(stretch 0 @ 3547.37..., -673.75...)]` (line 164) |
| M-C-grips-c (added) | grip_dispatch.dart: `preview` returns `const []` | C-grips | `StateError: Bad state: Pattern matching error` at the `final [(kind, payload)]` destructure (line 151) |
| M-C-cov-a | plan_controller.dart | C-covariance | `Expected: 'disc.round'` / `Actual: 'test.slab'` |
| M-C-cov-b | plan_controller.dart | C-covariance | `UnregisteredComponentError(DiscComponent): call registry.register first` |
| M-CM4 | plan_controller.dart | CM4 | `Expected: throws ArgumentError` / `Which: threw _AssertionError: 'package:jet_cad_2d_flutter/src/camera_controller.dart': Failed` |
| M-CM5 | plan_controller.dart | CM5 | `Expected: null` / `Actual: <Instance of 'ViewportTransform'>` (line 84) |
| M-CM6a | plan_controller.dart | CM6 | `Expected: false` / `Actual: <true>` (line 96) |
| M-CM6b | plan_controller.dart | CM6 | `Expected: within 1e-6 of <588.0>` / `Actual: <735.0000000000036>` |
| M-CM15 | plan_controller.dart | CM15 | `Expected: throws ArgumentError` / `Which: returned <Instance of 'PlanController'>` |
| M-C-cam1a | plan_controller.dart | C-cam1 | `Expected: within 1e-12 of <0.25>` / `Actual: <0.08142857142857142>` |
| M-C-cam1b | plan_controller.dart | C-cam1 | `Expected: null` / `Actual: <Instance of 'ViewportTransform'>` (line 167) |
| M-NS1 | plan_controller.dart | NS1 | `Expected: <0>` / `Actual: <1>` (line 50, undoDepth) |
| M-NS3 | plan_controller.dart | NS3 | `Expected: point` / `Actual: comma` (line 99) |
| M-NS4 | plan_controller.dart | NS4 | `Expected: point` / `Actual: comma` (line 113) |
| M-NS6 | plan_controller.dart | NS6 | `Expected: point` / `Actual: comma` (line 148) |
| M-NS8 | plan_controller.dart | NS8 | `Expected: comma` / `Actual: point` (line 167) |
| M-NS9 | plan_controller.dart (both edits) | NS9 | `Expected: point` / `Actual: comma` (line 185) |
| M-NS10 | plan_controller.dart | NS10 | `Expected: comma` / `Actual: point` (line 196) |
| M-C-ch1a | plan_change.dart | C-ch1 | `Expected: [PlanObjectAdded(12)]` / `Actual: [PlanObjectAdded(12), PlanObjectAdded(13)]` |
| M-C-ch1b | plan_change.dart (both sorts) | C-ch1 | `Expected: [Changed(12), Added(14)]` / `Actual: [Added(14), Changed(12)]` |
| M-C-ch2 | plan_controller.dart | C-ch2 | `Expected: [PlanReplaced()]` / `Actual: []` |
| M-C-ch3 | plan_change.dart | C-ch3 | `Actual: [PlanReplaced(), PlanObjectChanged(14)]` (Changed(12) dropped) |
| M-C-ch4a | plan_change.dart | C-ch4 | `Expected: <0>` / `Actual: <4>` (line 110) |
| M-C-ch4b | plan_change.dart | C-ch4 | `Expected: <2>` / `Actual: <3>` (line 124) |
| M-C-ch5 | plan_controller.dart | C-ch5 | `Expected: empty` / `Actual: [PlanObjectChanged(12), PlanReplaced()]` (line 168) |
| M-C-ch5 | plan_controller.dart | C-ch7 | `Expected: an object with length of <1>` / `Which: has length of <2>` |
| M-C-ch6 | plan_controller.dart | C-ch6 | `Actual: [PlanObjectChanged(12)]` / `Which: at location [1] ... shorter than expected` |
| M-C-ch8 | plan_change.dart | C-ch8 | `Expected: not PlanObjectAdded(2B)` / `Actual: PlanObjectAdded(2A)` |

## Gates (packages/jet_cad_2d_plan, after the mutations, tree clean)

```
flutter test                                   -> 00:01 +64: All tests passed!
flutter analyze                                -> No issues found! (ran in 2.7s)
dart format --output=none --set-exit-if-changed . -> Formatted 32 files (0 changed); exit 0
```
`git status --short` is empty: no `analysis_options.yaml` was touched.
`git diff --stat main -- packages/jet_cad_2d_flutter packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu apps` is empty.
`git diff --stat 6df8967a HEAD -- packages/jet_cad_2d packages/jet_cad_2d_kit` is empty: the engine diff against main is Tasks 1-2's only.

## Files (commit 551985c8)

```
M packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart
A packages/jet_cad_2d_plan/lib/src/controller/{camera_bounds,diagnostics_log,grip_dispatch,new_plan,plan_change,plan_controller,services,session,shared_cache,tool_settings_store}.dart
A packages/jet_cad_2d_plan/lib/src/export/registries.dart
A packages/jet_cad_2d_plan/lib/src/symbols/plan_symbols_state.dart
A packages/jet_cad_2d_plan/test/controller/{camera,covariance,lifetimes,locale_separator,plan_change,plan_controller}_test.dart
M packages/jet_cad_2d_plan/test/support/harness.dart
```

## Deviations from the brief

1. **None in the library code.** The brief's code compiled and passed against the real code unchanged, apart from `dart format` (it rewrapped 9 of the new files).
2. **Test additions.** Ported assertions are unchanged; these are new assertions, not changes:
   - **C14**, a new test in `plan_controller_test.dart`, for the binding Task 7 carry. A `load` of a plan whose manifest names the missing kit `gone` and whose first slab's width is -1:
     - reports `missingKits == {'gone'}` and one `kitMissing`;
     - keeps one engine `component.unreadable` in `loadDiagnostics`, on that slab's handle.
     Three refused loads follow (`not json`, `{}`, a broken structure). After them, the document, `diagnostics.value`, `loadDiagnostics` (by identity) and `missingKits` are unchanged. Mutations M-C14a and M-C14b pin it. The brief's numbering skips C12, so the new test is C14 and C12 stays free.
   - **C-svc**: after the swap, the new plan's slab tool commits a slab whose size comes from the stored settings. This exercises `SlabTool.accept` and `settingsOf` end to end. Added mutation: M-C-svc-e.
   - **C-grips**: the dispatch's `preview` is checked against the expected corners before the drag, and the drag reuses the same `drop` vector. Added mutation: M-C-grips-c.
3. **The M-C3 mutation needed a change to compile.** Besides the brief's catch-branch edit, it also changes `final DraftDocument next;` to `DraftDocument next;`. Otherwise Dart refuses a `final` assigned in both the `try` and the `catch`, and the "red" would be a compile error, not the behaviour.
4. **M-C-life2b goes red by a different route.** The brief predicts a stack overflow. The real result is that the inner `create` succeeds and returns `_Loop`, and the test fails with `Which: returned <Instance of '_Loop'>`. It is still red, on the same line.
5. **M-C-ch5 reddens only C-ch5's second half** (line 168: edit, then load, then dispose). The first half stays green under this mutation, because `_emit` already drops changes once `_disposed` is set and `detach` runs after it. The brief's claim, "C-ch5 and C-ch7 red", holds.

## Final controller members

Public:
- Construction: `factory PlanController({required List<PlanKit> kits, String? json, SymbolThumbnails? thumbnails, List<PlanExporter> exporters, List<PlanImporter> importers, double minScale, double maxScale})`
- The plan: `KitSet kits`, `DraftDocument get document`, `String save()`, `void markSaved()`, `void load(String)`, `void newPlan({String? decimalSeparator})`, `ValueListenable<bool> get dirty`
- Undo: `ValueListenable<bool> get canUndo`, `get canRedo`, `void undo()`, `void redo()`
- Tools and objects: `ValueListenable<String> get activeTool`, `bool selectTool(String)`, `bool deleteSelection()`, `PlanType<Component>? typeOf(Handle)`
- Events: `Stream<PlanChange> get changes`
- Camera: `CameraController camera`, `void panBy(Offset)`, `bool zoomBy(double, {Offset? focus})`, `void centerOn(Offset, {double? scale})`, `void fitToView()`, `ValueListenable<Rect?> get canvasRect`
- State: `ValueListenable<Locale> get locale`, `ValueListenable<List<KitDiagnostic>> get diagnostics`, `Set<String> get missingKits`, `ValueListenable<PlanSymbolsState> get symbolsState`, `SymbolThumbnails thumbnails`
- `dispose()`

`@internal`:
- Data: `catalog`, `toolSettings`, `exporters`, `importers`, `snappingAllowed` (a field), `loadDiagnostics`, `diagnosticsLog`
- Document views: `toolController`, `toolContext`, `selection`, `index`, `page`, `grips`, `outlines`, `snap` (the user's F3 setting), `parametric`, `frozen`
- Lookups: `toolFor(String)`, `servicesOf(String)`
- Settle and locale: `registerSettle(VoidCallback)` (returns the withdrawal), `settlePendingInput()`, `reportLocale(Locale)`
- Canvas: `canvasPlaced(Object, Rect?)`, `cameraEpoch`, `fitRequests`, `takeFitOnStart()`, `owesFirstFit`, `fitted()`, `framingFor(Size)`

`@visibleForTesting`: `debugChangeScans`.

Exported from the barrel:
- From `camera_bounds.dart`: `kPlanMinScale`, `kPlanMaxScale`.
- From `plan_change.dart`: `PlanChange`, `PlanObjectAdded`, `PlanObjectChanged`, `PlanObjectRemoved`, `PlanReplaced`.
- From `plan_controller.dart`: everything public in the file, that is `PlanController` and `kPlanThumbnailCapacity`.
- From `registries.dart`: `PlanExporter`, `PlanImporter`, `PlanExportRequest`.
- `PlanSymbolsState`.

The session, services, cache, dispatch, store, log, tracker and helpers are not exported.

## Self-review

- **Swap order** (`_replace`), as spec P1 lifetimes and the brief require:
  1. arm select (this cancels the active tool), unhook `_onTools`;
  2. detach the tracker (flushes what the old plan owes);
  3. dispose the kit products: tools, then the dispatch closed, then the providers, then the shared cache;
  4. stop the history listener, then `_open` the new document (factories run, manifest checked, tracker attached);
  5. `PlanReplaced`, flags and camera reset; the old session is dropped after the next frame.

  `load` settles pending input before it decodes, so a refused load still settles; C11 expects exactly that.
- **No double dispose.** `disposeKitProducts` removes the kit tools from `_entries` before `DocumentSession.dispose` disposes what is left (select), which matches pre-flight ruling F2.
- **`PlanServices` reads everything live** through `ServicesHost`: the session, the camera, the effective snap and the store. `words` reads `_locale.value` on every call.

## Concerns

1. **`PlanController.dispose` does not arm select first.** When a kit tool is active (C10 ends mid-shape), `disposeKitProducts` disposes that tool while the `ToolController` still holds it. `ToolController.dispose` then calls `removeListener` on a disposed notifier. Flutter allows that, and the C10 tear-down runs clean. Later tasks that hook tool disposal may want `activate(select)` at the head of `dispose`.
2. **A kit factory that throws inside `_open` during a swap** leaves the controller half-swapped: the old kit products are already disposed. This is Task 11's guard territory, not handled here.
3. **The brief's code needed no fixes to compile.** This contradicts the planner note that it was never compiled. Nothing was redesigned.
