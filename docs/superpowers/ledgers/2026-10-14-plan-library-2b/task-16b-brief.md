### Task 16: `PlanServiceView`, the service bar, unit overlays, the events and `PlanEditor`'s mode switch; README and CHANGELOG (spec S4 "Widgets", "Events", "Painting"; S5 "The view" rows and the controller rows `mode`, `camera`, `export`/`print`, `selectTool`)

This task is in two parts, each ending green with its own commit and its own Mutation step. **Part A** (Steps A1-A13) builds the service view a host may mount alone: the bar, the overlays, the per-copy canvas, the events and the flows. **Part B** (Steps B1-B12) puts it into `PlanEditor`: the mode switch, the plan kept in place across a switch (today's R-13), the design-mode overlays, the barrel, the example, the README and the CHANGELOG. The controller may dispatch them as two tasks (16a, 16b); Part B consumes everything Part A produces.

Plan decision: **`PlanServiceView` follows the mode.** It shows nothing while `controller.mode` is `design` (no copy exists) and builds its canvas over `controller.serviceSession` once the mode is `service`, rebuilt for each new copy (`resetService`, `restoreService`, `load`, `newPlan`) by keying it on the copy's document, as today's `ServiceView` was keyed (`host/service_view.dart:35-37`, `host/floor_plan_view.dart:696-697`). A host that mounts it alone switches modes with `setMode`; a host with one widget mounts `PlanEditor`, which shows it in service (spec S4).

Plan decision: **the per-copy canvas is today's `ServiceView`, ported.** `PlanServiceView` plays `FloorPlanView`'s service role (the flows, the theme scope, the text keys, the events record, the overlay layer); a private `_ServiceCanvas`, keyed by the copy, is today's `ServiceView` (`host/service_view.dart:38-717`) over the session's document, index, page, selection, outlines and tool controller (Task 11), with the session's systems (Task 11 owns them; nothing here acquires a system).

Plan decision: **the service tool hears the view through the session.** The tool lives in the session (Task 11, wired by Task 14), so the view cannot hand it closures at construction as today's view did (`service_view.dart:134-142`). The view sets `session.host`, a `ServiceHost` of read-at-each-call functions (today's `callbacks`, `options`, `userCamera`, `toGlobal`, `events`, `idleKeys`, `table_select_tool.dart:101-142`), when its canvas mounts, and puts `ServiceHost.none` back when it goes. See "Interface problem" 1.

Plan decision: **overlays rebuild only at a host's rebuild** (today's G-5, `table_overlay.dart:79-90`). The overlay layer widget is made once per widget instance the host hands in (`PlanServiceView`'s, `PlanEditor`'s), memoized by `identical(widget, …)`; `PlanEditor` also memoizes its `PlanServiceView` child per `PlanEditor` widget, so the editor's own `setState`s (permissions, locale, mode) hand the same instances down and build no overlay, as today's `ListenableBuilder` handed the same `serviceOverlays` (`floor_plan_view.dart:663-669`).

Plan decision: **R-13 is ported into the controller and `PlanEditor`** (2a deferred it: 2a Task 20, "what is not ported", `floor_plan_view.dart`'s `_measureAfterFrame`, `_keepPlanInPlace`, `_chromeOrigin`). `PlanEditor` plays `FloorPlanView`'s part (it measures both modes' canvases in itself); the controller holds today's `_canvasAt`, `_assumed`, `_chromeAt`, `_canvasIn`, `canvasAssumed`, `canvasMeasured`, `chromeMoved` and the reframing in `setMode` (`floor_plan_controller.dart:48-63`, `:150-200`, `:427`, `:478`, `:900-988`, `:1268-1277`). A `PlanServiceView` mounted alone reports `canvasPlaced` only: a host that shows its own widgets in each mode keeps the camera's numbers across a switch, not the plan's place on the screen.

Plan decision: **the design permissions never gate service** (spec S4 "Permissions"). The service bar shows Undo, Redo, Export and Print whatever `undo`, `export` and `print` say; `EditorPageFlows` reads `permissions.export`/`print` only in design. Merge and Split are gated by `serviceMerge` (and their callbacks); drags by `serviceMove` (Task 14's tool reads it).

Plan decision: **`userCamera` is a service option only** (spec S4 "Options", S5 view rows). `PlanEditor(userCamera:)` passes it to its `PlanServiceView`; the design canvas keeps 2a's behaviour (2a mapped no `userCamera`). Recorded for sub-project 4's parity table as a design-side gap.

Plan decision: **not ported here.** `view_test.dart` V14 (a shared loader loaded by the view: design, 2a's `S-11`); the design halves of V1 and V2 (2a's `editor_view_test.dart`); `bars_test.dart` BC2, BC3, M-H40's editor case, "a bare shell's other file commands" and the editor halves 2a ported (2a Task 20 report, item 13); `host_text_keys_test.dart`'s design cases ("in the table number, …", "readOnly: in the table number …": the unit section's, Task 10) and its design canvas case (2a's `KB-3`); `keyboard_focus_test.dart`'s design groups (2a's Tasks 16 and 20); `host/barrel_test.dart` B1 and B2 (ED-9 and ED-9b are this package's), B4 (2a's camera rows). The service tool's own tests (`table_select_tool_test`, `table_band_test`, `service_events_test`, the two allocation tests) are Task 14's; the painters', the fills' and the theme's fields are Task 15's; `fitToUnits`' unit tests are Task 9's. The view-level tests Tasks 14 and 15 leave here (they pump today's view in the selection mode) are ported in Step B2b (controller ruling R-15).

**Files:**
- Part A
  - Create: `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_bar.dart`
  - Create: `packages/jet_cad_2d_plan/lib/src/service/view/unit_overlays.dart` (port of `jet_cad_floor_plan/lib/src/host/table_overlay.dart:1-845`)
  - Create: `packages/jet_cad_2d_plan/lib/src/service/view/plan_service_view.dart` (port of `host/service_view.dart:1-717` and the service parts of `host/floor_plan_view.dart:509-653`)
  - Modify: `packages/jet_cad_2d_plan/lib/src/export/editor_page_flows.dart` (the active document, the mode-aware gates, the colour opacity)
  - Modify: `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart` (`unitOverlays`)
  - Create (test support): `packages/jet_cad_2d_plan/test/support/service_fixtures.dart` (`pagePlan`, `kToolbarNumbers`, `toolbarPlanJson`; the embedding fixture and the units' fixture re-exported; controller ruling R-19)
  - Create (test support): `packages/jet_cad_2d_plan/test/support/service_host.dart`
  - Test (new): `packages/jet_cad_2d_plan/test/service/view/plan_service_view_test.dart` (SV-1 … SV-7)
  - Test (ported): `test/service/view/service_bar_test.dart`, `test/service/view/unit_overlay_test.dart`, `test/service/view/view_events_test.dart`, `test/service/view/unit_groups_toolbar_test.dart`
- Part B
  - Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (R-13: the camera, the canvas origins, the reframing in `setMode`)
  - Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (the mode switch, the service options, the overlays, the chrome origins)
  - Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (the 2b names)
  - Modify: `packages/jet_cad_2d_plan/example/main.dart`, `README.md`, `CHANGELOG.md`
  - Test (new): `packages/jet_cad_2d_plan/test/editor/editor_service_mode_test.dart` (SV-8 … SV-10); `test/example_test.dart` (ED-8b); `test/barrel_test.dart` (ED-9's set grown)
  - Test (ported): `test/editor/editor_service_view_test.dart`, `test/editor/editor_modes_test.dart`, `test/service/view/service_keys_test.dart`, the B3, B5, B6 and B-R10 halves into `test/barrel_test.dart`
  - Test (ported, moved here from Tasks 14 and 15 by controller ruling R-15; Step B2b): `test/service/view/service_options_test.dart`, `test/service/view/band_view_test.dart`, `test/service/view/unit_groups_gesture_test.dart`, `test/service/view/unit_groups_context_test.dart`, `test/service/view/theme_service_test.dart`, `test/service/view/status_caption_test.dart`, `test/service/view/unit_groups_look_test.dart`, `test/service/view/unit_fill_view_test.dart`, `test/theme/theme_service_mode_test.dart`; `test/editor/unit_inspector_test.dart` (Task 10's) gains two inspector tests Task 10 sends here

**Interfaces:**
- Consumes (Shared interfaces):
  - Task 8: `PlanPermissions.serviceMove`, `.serviceMerge`, `copyWith`.
  - Task 9: `PlanController.units`, `unitDetails`, `unitIndex` (`@internal`), `revision`, `cameraValue`, `fitToUnits`, `select`; Task 11: `selectedUnits`; `PlanUnitDetail` (`unit.label`, `unit.generatedBy`, `center`, `corners`); `PlanCamera`. Task 15: `kUnitColourOpacity` (`lib/src/theme/plan_theme.dart`, controller ruling R-22).
  - Task 10: `PlanStrings.merge`, `.split`; `PlanEditor(unitInspectorBuilder:)` (kept as Task 10 left it).
  - Task 11: `enum PlanMode { design, service }`; `PlanController.mode`, `setMode`, `activeDocument`, `activeSelection`, `serviceSession` (`@internal`), `undo`, `redo`, `canUndo`, `canRedo` on the active document; `ServiceSession`'s `document`, `index`, `page`, `selection`, `outlines`, `tools`, `units`.
  - Task 12: `unitStatuses`, `unitGroups`, `groupStatuses`, `unitFocus`, `selectedUnits`, `selectedGroup`, `mergeCandidate`; `UnitStatus`, `UnitGroup`.
  - Task 13: `resetService`, `restoreService`, `serviceJson`, `serviceChanges`.
  - Task 14: `PlanLongPress`, `PlanFloorDrag`, `ServiceTool`; and the names in "Assumed from earlier tasks".
  - Task 15: `PlanTheme.serviceBarHeight`, `.unitColourOpacity`; `UnitStatusPainter`, `UnitGroupPainter`, `UnitFocusPainter`; `PlanCanvasView.unitOverlays` (the slot renamed); `PlanController.export`/`print({double? unitColourOpacity})`.
- Produces (Shared interfaces, Task 16):
  ```dart
  enum PlanServiceAction { undo, redo, merge, split, export, print }
  final class PlanServiceBar { const PlanServiceBar({this.visible = true,
    this.actions = PlanServiceAction.values, this.leading = const [], this.trailing = const []}); }
  final class PlanUnitOverlay { final PlanUnitDetail detail; final bool selected; final bool focused;
    final UnitStatus? status; final int detailLevel; }
  typedef PlanUnitOverlayBuilder = Widget? Function(BuildContext, PlanUnitOverlay);
  enum PlanOverlaySize { natural, box }
  final class PlanOverlayLayout { /* anchor, size, maxNaturalSize, hideBelowScale, detailBreakpoints, interactive */ }
  final class PlanServiceView extends StatefulWidget { /* below */ }
  ```
  - `PlanServiceView({Key? key, required PlanController controller, PlanServiceBar bar = const PlanServiceBar(), void Function(String label)? onUnitTap, void Function(String label)? onUnitDoubleTap, void Function(String label, Offset globalPosition)? onUnitContextMenu, void Function(String groupId, String label)? onGroupTap, void Function(String? label)? onUnitHover, void Function(Set<String> labels)? onMergeRequested, void Function(String groupId)? onSplitRequested, VoidCallback? onLayoutChanged, void Function(List<PlanUnitDetail> moved)? onUnitsMoved, void Function(Offset world)? onFloorTap, PlanLongPress longPress = PlanLongPress.toggleSelection, PlanFloorDrag floorDrag = PlanFloorDrag.pan, bool userCamera = true, bool shortcuts = true, bool autofocus = true, PlanUnitOverlayBuilder? unitOverlayBuilder, PlanOverlayLayout unitOverlayLayout = const PlanOverlayLayout(), Set<PlanMode> unitOverlayModes = const {PlanMode.service}, void Function(PlanExport export)? onExport, PlanExportDialog? onExportDialog, void Function(Object error)? onPageFlowError, PagePrinter? printer, String exportName = 'plan', PlanTheme? theme})`.
  - `PlanEditor` gains the same service options, under the same names, and `PlanServiceBar serviceBar = const PlanServiceBar()`; they reach its `PlanServiceView` unchanged.
  - `PlanCanvas` gains `Widget? unitOverlays` (the layer `PlanEditor` builds for `PlanMode.design`).
  - Package-internal: `const double kServiceBarHeight = 44`; `void validatePlanServiceBar(PlanServiceBar)`; `void validatePlanOverlayLayout(PlanOverlayLayout)`; `int overlayDetailLevel(List<double>, double)`; `UnitOverlayLayer({required PlanController controller, required PlanUnitOverlayBuilder builder, required PlanOverlayLayout layout})`; `RenderPlanUnitOverlays`, `PlanUnitOverlayParentData` (their `debug*` counters `@visibleForTesting`); on `PlanController`: `@internal void canvasAssumed(PlanMode, Offset)`, `@internal void canvasMeasured(PlanMode, Offset, {Offset? chrome})`, `@internal void chromeMoved(Offset from, Offset to)`, `@visibleForTesting Map<PlanMode, Offset> planCanvasSeeds`.

---


> Part A (Steps A1-A13, the service view) is committed before you start; this brief is Part B only.

#### Part B: the mode switch in `PlanEditor`, the plan kept in place, and the package's face

- [ ] **Step B1: The new tests (they fail first).** Create `packages/jet_cad_2d_plan/test/editor/editor_service_mode_test.dart`:

```dart
// 2b spec S4 ("PlanEditor shows it when the mode is service, so a host
// with one widget keeps today's single view"; the events and options
// passed through PlanEditor) and today's G-5 (overlays rebuild at the
// host's rebuild only). Over the embedding plan and Task 5's rows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_bar.dart';
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:jet_cad_2d_plan/src/service/view/unit_overlays.dart';
import 'package:jet_cad_2d_plan/src/units/unit_detail.dart';

import '../support/service_fixtures.dart';
import '../support/service_host.dart';

Future<void> pumpEditor(WidgetTester tester, PlanEditor editor) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: editor)));
  await tester.pump();
  await tester.pump();
  editor.controller.camera.value = embeddingCamera();
  await tester.pump();
}

void main() {
  testWidgets(
      'SV-8 PlanEditor shows PlanServiceView in service and its editor in '
      'design: no canvas of the other mode, one canvas in each', (tester) async {
    final c = serviceController();
    await pumpEditor(tester, PlanEditor(controller: c));
    expect(find.byType(PlanCanvas), findsOneWidget);
    expect(find.byType(PlanServiceView), findsNothing);
    c.setMode(PlanMode.service);
    await tester.pump();
    await tester.pump();
    // M-SV-8: PlanEditor builds its editor whatever the mode.
    expect(find.byType(PlanServiceView), findsOneWidget);
    expect(find.byType(PlanCanvas), findsNothing);
    expect(byKey('chrome-left'), findsNothing);
    expect(find.byType(InteractionLayer), findsOneWidget);
    c.setMode(PlanMode.design);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanCanvas), findsOneWidget);
    expect(find.byType(PlanServiceView), findsNothing);
  });

  testWidgets(
      'SV-9 every service option of PlanEditor reaches its PlanServiceView '
      'unchanged', (tester) async {
    final c = serviceController();
    void tap(String _) {}
    void doubleTap(String _) {}
    void menu(String _, Offset __) {}
    void group(String _, String __) {}
    void hover(String? _) {}
    void merge(Set<String> _) {}
    void split(String _) {}
    void layout() {}
    void moved(List<PlanUnitDetail> _) {}
    void floor(Offset _) {}
    Widget? badge(BuildContext _, PlanUnitOverlay __) => null;
    const bar = PlanServiceBar(actions: [PlanServiceAction.print]);
    const layout2 = PlanOverlayLayout(hideBelowScale: 0.1);
    c.setMode(PlanMode.service);
    await pumpEditor(
        tester,
        PlanEditor(
          controller: c,
          serviceBar: bar,
          onUnitTap: tap,
          onUnitDoubleTap: doubleTap,
          onUnitContextMenu: menu,
          onGroupTap: group,
          onUnitHover: hover,
          onMergeRequested: merge,
          onSplitRequested: split,
          onLayoutChanged: layout,
          onUnitsMoved: moved,
          onFloorTap: floor,
          longPress: PlanLongPress.contextMenu,
          floorDrag: PlanFloorDrag.band,
          userCamera: false,
          shortcuts: false,
          autofocus: false,
          unitOverlayBuilder: badge,
          unitOverlayLayout: layout2,
          unitOverlayModes: const {PlanMode.design, PlanMode.service},
          exportName: 'hall',
        ));
    final v = tester.widget<PlanServiceView>(find.byType(PlanServiceView));
    // M-SV-9: PlanEditor does not hand onUnitHover down.
    expect(v.bar, same(bar));
    expect(v.onUnitTap, same(tap));
    expect(v.onUnitDoubleTap, same(doubleTap));
    expect(v.onUnitContextMenu, same(menu));
    expect(v.onGroupTap, same(group));
    expect(v.onUnitHover, same(hover));
    expect(v.onMergeRequested, same(merge));
    expect(v.onSplitRequested, same(split));
    expect(v.onLayoutChanged, same(layout));
    expect(v.onUnitsMoved, same(moved));
    expect(v.onFloorTap, same(floor));
    expect(v.longPress, PlanLongPress.contextMenu);
    expect(v.floorDrag, PlanFloorDrag.band);
    expect(v.userCamera, isFalse);
    expect(v.shortcuts, isFalse);
    expect(v.autofocus, isFalse);
    expect(v.unitOverlayBuilder, same(badge));
    expect(v.unitOverlayLayout, same(layout2));
    expect(v.unitOverlayModes, {PlanMode.design, PlanMode.service});
    expect(v.exportName, 'hall');
  });

  testWidgets(
      'SV-10 in service, PlanEditor\'s own rebuild (new permissions) builds '
      'no overlay; the host\'s rebuild builds every one again (G-5)',
      (tester) async {
    final c = rowsController();
    var builds = 0;
    final host = ValueNotifier(0);
    addTearDown(host.dispose);
    c.setMode(PlanMode.service);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ValueListenableBuilder<int>(
                valueListenable: host,
                builder: (_, __, ___) => PlanEditor(
                    controller: c,
                    unitOverlayBuilder: (_, __) {
                      builds++;
                      return const SizedBox(width: 6, height: 6);
                    }))))));
    await tester.pump();
    await tester.pump();
    final overlaid = [
      for (final d in c.unitDetails)
        if (d.unit.label != null && d.center != null) d
    ].length;
    expect(builds, overlaid, reason: 'premise: one build each');
    builds = 0;
    c.permissions = c.permissions.copyWith(rotate: false);
    await tester.pump();
    await tester.pump();
    // M-SV-10: PlanEditor makes its PlanServiceView afresh at each build.
    expect(builds, 0);
    host.value++;
    await tester.pump();
    expect(builds, overlaid);
  });
}
```

Add to `packages/jet_cad_2d_plan/test/example_test.dart`:

```dart
  testWidgets(
      'ED-8b the example switches modes: the editor bar\'s button shows the '
      'service view, the service bar\'s brings the editor back',
      (tester) async {
    await tester.pumpWidget(const PlanExampleApp());
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('example-service')));
    await tester.pump();
    await tester.pump();
    // M-ED-8b: both buttons switch to design.
    expect(find.byType(PlanServiceView), findsOneWidget);
    expect(find.byType(PlanCanvas), findsNothing);
    await tester.tap(find.byKey(const Key('example-design')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlanCanvas), findsOneWidget);
  });
```

Grow `test/barrel_test.dart`'s ED-9 set by a `// 2b Task 16` block holding only the names this task exports (Step B7):

```dart
      // 2b Task 16
      'kUnitColourOpacity', 'UnitProblem',
      'PlanLongPress', 'PlanFloorDrag', 'PlanServiceAction', 'PlanServiceBar',
      'PlanServiceView', 'PlanUnitOverlay', 'PlanUnitOverlayBuilder',
      'PlanOverlaySize', 'PlanOverlayLayout',
```

The 2b names the earlier tasks exported are in the set already, each under its task's comment, and stay there: Task 4's `SymbolsState` (in place of `PlanSymbolsState`), Task 8's `isUnitSymbol`, Task 9's `BadLabel`, `DuplicateLabel`, `PlanCamera`, `PlanUnit`, `PlanUnitAdded`, `PlanUnitChange`, `PlanUnitChanged`, `PlanUnitDetail`, `PlanUnitRemoved`, `PlanUnitsReplaced`, `Unlabelled`, `UnitLabelProblem`, `UnitLabelWarning`, Task 11's `PlanMode`, Task 12's `UnitGroup`, `UnitStatus`, Task 13's `ServiceRestore`. ED-9's expected value is a set literal: naming one of them again is the analyzer's `equal_elements_in_set` warning.

Run: `cd packages/jet_cad_2d_plan && flutter test test/editor/editor_service_mode_test.dart test/example_test.dart test/barrel_test.dart`. Expected: compilation errors (`PlanEditor` has no `serviceBar`, `onUnitTap`, …).

- [ ] **Step B2: The ported tests.** Part A's common adaptations hold, with `FloorPlanView` → `PlanEditor` (the one widget whose mode switch these tests exercise) and `editorBar:` → `bar:`, `editorCapabilities:` → `c.permissions` or the editor's option (2a's mapping, 2a Task 20 Step 3), `tableInspectorBuilder:` → `unitInspectorBuilder:`. Each file's header lists what it ports.

**`test/editor/editor_service_view_test.dart`** ← `view_test.dart` (48 tests): V1's service half (`:144-157`: `service-bar`, `service-export`, no `tool-plan.select`, no `PlanPropertyPanel`; back in design the editor), V2's service half (`:164-166`), V3, V4 (the unit section's keys as Task 10 named them for `table-section` and `table-number`; `designJson()` → `save()`), V5, V6, V7a-V7h (`:284-492`; the seeds `floorPlanCanvasSeeds` → `planCanvasSeeds`), V8-V13, V15, V18 (touch, `:728-781`), V19, V16, V17, V18 (rulers, `:848-933`), VZ1-VZ12, VF1-VF7, RV1-RV3. `pumpView` (`:68-89`) → `PlanEditor` over `serviceController(json: json ?? pagePlan())`; `FakePrinter` (`:59-66`) → 2a's `FakePagePrinter`; `exportPng` (`:92-117`) → through 2a's dialog keys; `move` (`:119-128`) → Part A's `move`; `paged()` and the zone helpers (`:1200-1287`) → `serviceController()` over the page plan or the embedding plan as each source helper chose; the palette fixture's `shoot`/`pumpThemed` → 2a's `test/support/canvas_fixture.dart` equivalents (find them by name there; a helper 2a did not port is copied into this file from `jet_cad_floor_plan/test/support/palette_fixture.dart`, with its line range in a comment). V7a's numbers (`-310.5 + 240 + 24`, `2400.25 + 24`) are today's chrome, which 2a's `PlanEditor` keeps (the left column 240, the top bar 44, `kRulerThickness` 24, the service bar 44).

**`test/editor/editor_modes_test.dart`** ← `bars_test.dart`'s group "the canvas re-measured" (`:998-1090`: M-H47(serviceBar), T2-f, "a bar of the mode not shown changed"), the R-3 tests (`:1179-1423`, eight), K1 (`:1424-…`); and `table_overlay_test.dart`'s TO13, TO14, TO23. `mountHost` (`:244-269`) → `PlanEditor(controller: c, onExport: …, onMergeRequested: …, onSplitRequested: …, serviceBar: bars.$1, bar: bars.$2, theme: theme)`; `canvasIn` (`:272-274`) measured from `find.byType(PlanEditor)`; `globalOf`, `centreOf`, `expectAt` (`:276-294`) copied with `c.camera`, `c.unitIndex.withLabel(n)` and `embeddingBox`'s centre `(700, 100)`.

**`test/service/view/service_keys_test.dart`** ← `keyboard_focus_test.dart`: M-H41b (`:301-340`), T6-g (`:341-363`), the service half of "shortcuts: false: undo() and exportPlan act in each mode" (`:494-517`, `exportPlan` → `c.export('plan.pdf', PlanExportChoice.initial)`), DS4 (`:629-658`, `deleteSelection()` false in service, before the frame and with no view), T6-a's service case (`:768-786`, the mode loop's `service` value) and "T6-a the host field focused, the view in a focus scope of its own: after each setMode, resetLayout and load the field keeps the focus" (`:787-851`, `resetLayout` → `resetService`); `kServiceChords` (`:38-…`) and `mountKeys` (its service form) copied, over `PlanEditor`. And `host_text_keys_test.dart`: "selection, shortcuts: false/true: a host field in the service bar keeps its keys …" (`:244-254`, both values), the `selection` case of "…, shortcuts: false, the canvas focused: …" (`:255-275`, `c.selectedTables.value` → `c.selectedUnits.value`), and the `selection` case of "(final review F-6, mutant S25) …" (`:276-301`); `PosHost`, `mountPos` (`:64-122`, its `serviceBar:` → `serviceBar: const PlanServiceBar(leading: […])`), `focusedText`, `inField`, `fill`, `typeInto` copied, with 2a's `test/shortcuts/host_text_keys_test.dart` as the model for the imports and `k`/`t` helpers.

**`test/barrel_test.dart`** gains, ported from `jet_cad_floor_plan/test/host/barrel_test.dart` and using the barrel alone: B3 (`:135-153`, `PlanUnit.visible`: named, true by default, in `==`, `hashCode`, `toString`), B5 (`:183-215`, the unit overlays: `PlanUnitOverlay`, `PlanUnitOverlayBuilder`, `PlanOverlayLayout`, `PlanOverlaySize` through `PlanServiceView`), B6's unit half (`:216-…`, `unitChanges` and an exhaustive switch over `PlanUnitChange`'s four types) and B-R10's label half (`:91-103`, an exhaustive switch over `UnitLabelProblem`; the library-state half is 2a's and Task 4's).

Run: `cd packages/jet_cad_2d_plan && flutter test test/editor test/service/view test/barrel_test.dart`. Expected: failures (the editor shows no service view; the controller keeps no canvas origins).

- [ ] **Step B2b: The view-level ports from Tasks 14 and 15 (controller ruling R-15).** Each pumps today's view in the selection mode and drives `ServiceView`'s listeners or reads the service painters through the mounted view (`service_options_test.dart:96`, `band_view_test.dart:152`, `table_groups_gesture_test.dart:118-120`, `table_groups_context_test.dart:27-29`, `theme_service_test.dart:147-154`, `status_caption_test.dart:68-81`, `table_groups_look_test.dart:141-142`), so it needs `PlanServiceView` and, where it switches modes inside one widget, `PlanEditor`. Assertions unchanged; each file starts with `// Ported from jet_cad_floor_plan/test/<path>; assertions unchanged.` and lists what it ports. Part A's common adaptations (Step A4) hold: a view mounted in the selection mode alone → `PlanServiceView` through `pumpService`; one that switches modes → `PlanEditor` (Step B2's adaptations). The fixtures are Step A1's (`service_fixtures.dart`), Task 15's `unit_zone_fixture.dart` for the zone plan, and Task 15's names for the theme (`FloorPlanTheme` → `PlanTheme`, `tableColorOpacity` → `unitColourOpacity`, the painters as Task 15's Step 10 renames them).
  1. **`test/service/view/service_options_test.dart`** ← `service/service_options_test.dart`: SO1-SO6. The view option `serviceMoves: false` → `c.permissions = c.permissions.copyWith(serviceMove: false)` (Task 14's plan decision: a permission read at each press); `longPress:`, `floorDrag:` and `onTableContextMenu:` → `PlanServiceView`'s `longPress:`, `floorDrag:`, `onUnitContextMenu:`.
  2. **`test/service/view/band_view_test.dart`** ← `host/band_view_test.dart`: RBV1-RBV8.
  3. **`test/service/view/unit_groups_gesture_test.dart`** ← `host/table_groups_gesture_test.dart`: TG-G1-TG-G14.
  4. **`test/service/view/unit_groups_context_test.dart`** ← `host/table_groups_context_test.dart`: its two tests, renamed **TG-CX1** and **TG-CX2** (Task 12 ports `table_groups_controller_test.dart`'s TG-C1 … under their source ids; the names would repeat).
  5. **`test/service/view/theme_service_test.dart`** ← `host/theme_service_test.dart`: its 13 tests (M-H33(repaint), M-H31 through the view, the animated switch, the full theme removed at runtime, the group "the veil with no colour is the paper's (M-H32)", the group "the bar (T-1, S-10)" with T3-d and RV5 over `PlanEditor`, invariant 4, the group "invariant 7 with a theme" with TO10 and TO21 themed). Invariant 4's `designJson` → `c.save()`, the service layout → `c.serviceJson()`, the PNG export → `c.export('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96))`; `RenderFloorPlanOverlays` → `RenderPlanUnitOverlays`; the zone fixture → `unit_zone_fixture.dart`'s `zonePlanJson` loaded with `serviceController(json: zonePlanJson())`.
  6. **`test/service/view/status_caption_test.dart`** ← `host/status_caption_test.dart`: its four tests (the premise on Bill's caption, M-DT-13/F-16, the two D6c).
  7. **`test/service/view/unit_groups_look_test.dart`** ← `host/table_groups_look_test.dart`: TG-V1-TG-V6, TG-Z3, TG-Z4.
  8. **`test/service/view/unit_fill_view_test.dart`** ← `service/table_fill_test.dart`: TF6 (`:650-673`) and TF7's selection-mode tail (`:735-755`) as **TF7b** ("may move, never weaken", 2a's ruling). The fixture is Task 15's: `import '../paint/unit_fill_test.dart' show controllerOver, fillJson, pumpPlan;` (Task 15's export test reads the same file the same way); `c.setMode(FloorPlanMode.selection)` → `c.setMode(PlanMode.service)` under `PlanEditor`.
  9. **`test/theme/theme_service_mode_test.dart`** ← `host/floor_plan_theme_test.dart`: the `selection` runs of the group "resolution (T-2, S-11), in both modes" (`:673-737`: P-6, M-H30 and the ambient switch, each run for `PlanMode.service` through `PlanEditor`) and the tests at `:832-1020` that read `ServiceView` or the service layout (Task 15's plan decision "what moves to Task 16"). Before porting one, check 2a's `test/theme/` and `test/editor/editor_theme_test.dart` and Task 15's `test/theme/plan_theme_test.dart`: a test already ported there is not ported again (report which).

  10. **`test/editor/unit_inspector_test.dart`** (Task 10's file) gains, from `host/inspector_test.dart`, "none without a builder (no slot); none in the selection mode, the builder given" (`:271-290`) and T6-e (`:293-…`, through the barrel), which Task 10 sends here (they switch modes inside `PlanEditor`): over Task 10's `mountInspector` (`PlanEditor` with `unitInspectorBuilder`), its `mode:` argument → `c.setMode(PlanMode.service)` before the mount; `FloorPlanMode` → `PlanMode` (`selection` → `service`); `selectedTables` → `selectedUnits`, `editorSelectedTables` → `editorSelectedUnits`; the keys `table-inspector` → `unit-inspector` (Task 10's); the wall key → the editor fixture's north wall line (as Task 10 maps it).

  Run: `cd packages/jet_cad_2d_plan && flutter test test/service/view test/theme`. Expected after Step B4: `All tests passed!`; a ported test that fails on an assertion is a finding: stop and report it.

- [ ] **Step B3: The plan kept in place (R-13), in the controller.** In `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`:

The camera becomes today's view camera (`floor_plan_controller.dart:150-200`), its type unchanged for hosts:

```dart
/// The controller's camera (today's `_ViewCamera`): a pan made while a
/// view builds ([panUnheard]) is applied at once and heard after that
/// frame.
final class _PlanCamera extends CameraController {
  _PlanCamera(super.initial, {super.minScale, super.maxScale});

  bool _quiet = false;
  bool _owed = false;
  bool _gone = false;

  /// Pans by [canvasDelta] now, while a view builds: the frame being built
  /// lays out and paints at the new value; the listeners hear it once,
  /// after the frame.
  void panUnheard(Offset canvasDelta) {
    _quiet = true;
    try {
      panBy(canvasDelta);
    } finally {
      _quiet = false;
    }
    if (_owed) return;
    _owed = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _owed = false;
        if (!_gone) notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void notifyListeners() {
    if (_quiet) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }
}
```

In the constructor's initializer list, `camera = CameraController(` → `camera = _PlanCamera(` (the arguments unchanged).

Top level (`floor_plan_controller.dart:44-63`):

```dart
/// Where each mode's canvas starts in a `PlanEditor`, by its chrome alone:
/// the top bar (44), the left column (240) and the rulers in design; the
/// service bar in service.
const Map<PlanMode, Offset> _defaultChromeOrigins = {
  PlanMode.design: Offset(240 + kRulerThickness, 44 + kRulerThickness),
  PlanMode.service: Offset(0, kServiceBarHeight),
};

/// Where each mode's canvas starts until an editor has measured it (R-13
/// as amended). Read when a controller is made; a test seam.
@visibleForTesting
final Map<PlanMode, Offset> planCanvasSeeds = Map.of(_defaultChromeOrigins);
```

Members (`floor_plan_controller.dart:427`, `:900-988`, `:1268-1277`), beside `canvasPlaced`:

```dart
  /// The last rect a canvas reported in each mode, for [setMode].
  final Map<PlanMode, Rect> _canvasIn = {};

  // R-13 as amended (the human, 2026-10-07): a mode switch keeps the plan
  // where it is on the screen. The camera's numbers are in the shown
  // canvas's coordinates and the two modes' canvases start at different
  // places in the editor, so [setMode] reframes the camera by the
  // difference of their origins -- here, not in a widget, so a switch made
  // while no editor is shown keeps the place too.
  final Map<PlanMode, Offset> _canvasAt = Map.of(planCanvasSeeds);

  /// The origins a reframing used and no measurement has confirmed yet.
  final Map<PlanMode, Offset> _assumed = {};

  /// Where each mode's chrome alone put its canvas when its origin was
  /// seeded or measured: the basis [canvasAssumed] moves it from.
  final Map<PlanMode, Offset> _chromeAt = Map.of(_defaultChromeOrigins);

  /// An editor lays out [mode]'s chrome so that its canvas starts at
  /// [chrome]. For a mode not shown, the origin a switch into it reframes
  /// by moves by what the chrome moved, and so do a reframing's assumption
  /// and the rect [canvasRect] takes at the switch: the first frame after
  /// the switch is exact. The shown mode waits for its measurement.
  @internal
  void canvasAssumed(PlanMode mode, Offset chrome) {
    if (mode == this.mode.value) return;
    final delta = chrome - _chromeAt[mode]!;
    _chromeAt[mode] = chrome;
    if (delta == Offset.zero) return;
    _canvasAt[mode] = _canvasAt[mode]! + delta;
    final assumed = _assumed[mode];
    if (assumed != null) _assumed[mode] = assumed + delta;
    final rect = _canvasIn[mode];
    if (rect != null) {
      _canvasIn[mode] = Rect.fromLTRB(
          rect.left + delta.dx, rect.top + delta.dy, rect.right, rect.bottom);
    }
  }

  void _reframe(PlanMode from, PlanMode to) {
    final a = _canvasAt[from]!, b = _canvasAt[to]!;
    _assumed.putIfAbsent(from, () => a);
    _assumed.putIfAbsent(to, () => b);
    if (a != b) camera.panBy(a - b);
  }

  /// An editor measured where [shown]'s canvas starts in it, after the
  /// frame that first showed a plan in that mode; a reframing that assumed
  /// another origin is corrected. [chrome] is the basis a later
  /// [canvasAssumed] moves the origin from.
  @internal
  void canvasMeasured(PlanMode shown, Offset origin, {Offset? chrome}) {
    _canvasAt[shown] = origin;
    if (chrome != null) _chromeAt[shown] = chrome;
    final assumed = _assumed.remove(shown);
    if (assumed == null || assumed == origin) return;
    camera.panBy(shown == mode.value ? assumed - origin : origin - assumed);
  }

  /// An editor's chrome in the shown mode moved its canvas from [from] to
  /// [to]: the camera pans by the difference, applied at once and heard
  /// after the frame. No camera command: a pending fit still runs.
  @internal
  void chromeMoved(Offset from, Offset to) {
    if (_disposed || from == to) return;
    (camera as _PlanCamera).panUnheard(from - to);
  }
```

In `canvasPlaced`, in the `global != null` branch, before `_canvasRect.value = global;`: `_canvasIn[mode.value] = global;`.

In Task 11's `setMode`, after the copy is built or dropped and before the mode's value changes (`floor_plan_controller.dart:1268-1277`):

```dart
    _reframe(mode.value, next);
    // The new mode's canvas, where an editor last showed it.
    final shownIn = _canvasIn[next];
    if (_canvasRect.value != null && shownIn != null) {
      _canvasRect.value = shownIn;
    }
```

(`mode.value` is read before Task 11's assignment of `next`; use Task 11's private notifier if its getter is a `ValueListenable` view of it.) Imports: `kRulerThickness` from `jet_cad_2d_flutter`, `kServiceBarHeight` from `../service/view/plan_service_bar.dart`, `SchedulerBinding` from `package:flutter/scheduler.dart` if not imported yet, `visibleForTesting` from `package:meta/meta.dart` beside `internal`.

- [ ] **Step B4: The editor.** In `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`:

The constructor and fields gain the service options (doc comments as `PlanServiceView`'s, one line each, ending "passed to the service view"):

```dart
    this.serviceBar = const PlanServiceBar(),
    this.onUnitTap,
    this.onUnitDoubleTap,
    this.onUnitContextMenu,
    this.onGroupTap,
    this.onUnitHover,
    this.onMergeRequested,
    this.onSplitRequested,
    this.onLayoutChanged,
    this.onUnitsMoved,
    this.onFloorTap,
    this.longPress = PlanLongPress.toggleSelection,
    this.floorDrag = PlanFloorDrag.pan,
    this.userCamera = true,
    this.unitOverlayBuilder,
    this.unitOverlayLayout = const PlanOverlayLayout(),
    this.unitOverlayModes = const {PlanMode.service},
// fields:
  final PlanServiceBar serviceBar;
  final void Function(String label)? onUnitTap;
  final void Function(String label)? onUnitDoubleTap;
  final void Function(String label, Offset globalPosition)? onUnitContextMenu;
  final void Function(String groupId, String label)? onGroupTap;
  final void Function(String? label)? onUnitHover;
  final void Function(Set<String> labels)? onMergeRequested;
  final void Function(String groupId)? onSplitRequested;
  final VoidCallback? onLayoutChanged;
  final void Function(List<PlanUnitDetail> moved)? onUnitsMoved;
  final void Function(Offset world)? onFloorTap;
  final PlanLongPress longPress;
  final PlanFloorDrag floorDrag;
  final bool userCamera;
  final PlanUnitOverlayBuilder? unitOverlayBuilder;
  final PlanOverlayLayout unitOverlayLayout;
  final Set<PlanMode> unitOverlayModes;
```

The class's doc comment gains a paragraph: "In `PlanMode.service` the editor shows a `PlanServiceView` over the service copy with the options above, and the plan keeps its place on the screen across a switch (today's R-13)."

`_flowsFor` passes `unitColourOpacity: _unitColourOpacity` (the same method as `PlanServiceView`'s, reading `widget.theme`).

The state gains, ported from `floor_plan_view.dart:327-500` (the chrome) and this task's memoization:

```dart
  /// The PlanServiceView handed down, made once per widget the host hands
  /// in: the editor's own rebuilds hand the same one, so they build no
  /// overlay (G-5).
  PlanServiceView? _service;

  /// The design canvas's overlay layer, likewise.
  PlanEditor? _overlaysOf;
  Widget? _designLayer;

  PlanServiceView _serviceView() => _service ??= PlanServiceView(
        controller: widget.controller,
        bar: widget.serviceBar,
        onUnitTap: widget.onUnitTap,
        onUnitDoubleTap: widget.onUnitDoubleTap,
        onUnitContextMenu: widget.onUnitContextMenu,
        onGroupTap: widget.onGroupTap,
        onUnitHover: widget.onUnitHover,
        onMergeRequested: widget.onMergeRequested,
        onSplitRequested: widget.onSplitRequested,
        onLayoutChanged: widget.onLayoutChanged,
        onUnitsMoved: widget.onUnitsMoved,
        onFloorTap: widget.onFloorTap,
        longPress: widget.longPress,
        floorDrag: widget.floorDrag,
        userCamera: widget.userCamera,
        shortcuts: widget.shortcuts,
        autofocus: widget.autofocus,
        unitOverlayBuilder: widget.unitOverlayBuilder,
        unitOverlayLayout: widget.unitOverlayLayout,
        unitOverlayModes: widget.unitOverlayModes,
        onExport: widget.onExport,
        onExportDialog: widget.onExportDialog,
        onPageFlowError: widget.onPageFlowError,
        printer: widget.printer,
        exportName: widget.exportName,
        theme: widget.theme,
      );

  Widget? _designOverlays() {
    final w = widget;
    if (!identical(w, _overlaysOf)) {
      _overlaysOf = w;
      final builder = w.unitOverlayBuilder;
      _designLayer =
          builder == null || !w.unitOverlayModes.contains(PlanMode.design)
              ? null
              : UnitOverlayLayer(
                  controller: w.controller,
                  builder: builder,
                  layout: w.unitOverlayLayout);
    }
    return _designLayer;
  }

  // ---- R-13 (floor_plan_view.dart:327-500) ----

  /// The plan last measured: each plan shown, a mode's or a new copy's,
  /// is measured once, after its first frame.
  DraftDocument? _measuredFor;

  void _measureAfterFrame(PlanMode shown, DraftDocument document) {
    if (identical(_measuredFor, document)) return;
    _measuredFor = document;
    final c = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(c, widget.controller)) return;
      final origin = _canvasOrigin();
      if (origin != null) {
        c.canvasMeasured(shown, origin, chrome: _chromeOrigin(shown));
      }
    });
  }

  /// The service bar's height under this editor's resolved theme.
  double _serviceBarHeight = kServiceBarHeight;

  /// Where [mode]'s canvas starts in this editor by its chrome alone.
  Offset _chromeOrigin(PlanMode mode) {
    switch (mode) {
      case PlanMode.service:
        return Offset(0, widget.serviceBar.visible ? _serviceBarHeight : 0);
      case PlanMode.design:
        final ruler = widget.rulers ? kRulerThickness : 0.0;
        final left = _leftShown ? 240.0 : 0.0;
        final top = widget.bar.visible ? 44.0 : 0.0;
        return Offset(left + ruler, top + ruler);
    }
  }

  /// At each build and each change of the theme: the mode not shown is
  /// assumed from its chrome; the shown one is kept in place. A changed
  /// service bar height while service shows moves the canvas with the plan
  /// (today's S-10); the canvas is measured again after the frame.
  void _assumeCanvases(PlanTheme? theme) {
    final height = theme?.serviceBarHeight ?? kServiceBarHeight;
    final moved = height != _serviceBarHeight;
    _serviceBarHeight = height;
    final c = widget.controller;
    for (final mode in PlanMode.values) {
      if (mode != c.mode.value) c.canvasAssumed(mode, _chromeOrigin(mode));
    }
    _keepPlanInPlace();
    if (moved && c.mode.value == PlanMode.service) _scheduleCanvasMoved();
  }

  PlanMode? _laidOutMode;
  Offset _laidOutChrome = Offset.zero;

  /// When the shown mode's chrome changes (a bar, the left column or the
  /// rulers shown or hidden), the camera pans by the canvas origin's move,
  /// so the plan keeps its place from the frame that lays the new chrome
  /// out. The theme's bar height is not compensated.
  void _keepPlanInPlace() {
    final c = widget.controller;
    final mode = c.mode.value;
    final chrome = _chromeOrigin(mode);
    final lastMode = _laidOutMode;
    var last = _laidOutChrome;
    if (mode == PlanMode.service && last.dy != 0) {
      last = Offset(0, _serviceBarHeight);
    }
    _laidOutMode = mode;
    _laidOutChrome = chrome;
    if (lastMode != mode || last == chrome) return;
    c.chromeMoved(last, chrome);
  }

  PlanMode? _shown;
  (bool, bool, bool, bool)? _chrome;
  bool _canvasMoveDue = false;

  /// After the frame that lays out other chrome than the last, the shown
  /// canvas is measured again.
  void _measureChrome() {
    final chrome =
        (widget.serviceBar.visible, widget.bar.visible, widget.rulers, _leftShown);
    final last = _chrome;
    _chrome = chrome;
    if (last == null || last == chrome) return;
    _scheduleCanvasMoved();
  }

  void _scheduleCanvasMoved() {
    if (_canvasMoveDue) return;
    _canvasMoveDue = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canvasMoveDue = false;
      _canvasMoved();
    });
  }

  void _canvasMoved() {
    final c = widget.controller;
    final shown = _shown;
    if (!mounted || shown == null || c.mode.value != shown) return;
    final origin = _canvasOrigin();
    if (origin != null) {
      c.canvasMeasured(shown, origin, chrome: _chromeOrigin(shown));
    }
  }

  /// The shown canvas's top left (its interaction layer's) in this editor.
  Offset? _canvasOrigin() {
    final view = context.findRenderObject();
    if (view is! RenderBox || !view.attached) return null;
    RenderBox? canvas;
    void visit(Element e) {
      if (canvas != null) return;
      if (e.widget is InteractionLayer) {
        final r = e.findRenderObject();
        if (r is RenderBox && r.attached && r.hasSize) canvas = r;
        return;
      }
      e.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return canvas?.localToGlobal(Offset.zero, ancestor: view);
  }
```

`initState` adds `widget.controller.mode.addListener(_onController);` (and `dispose` and the controller swap in `didUpdateWidget` remove and move it). `didUpdateWidget` also clears `_service = null;` at its top (every new widget is the host's rebuild), and on a controller swap sets `_laidOutMode = null;`.

`build` becomes (the 2a body between `PlanShortcuts(` and its closing parenthesis moves unchanged into `_editor`, with `PlanCanvas(…, unitOverlays: _designOverlays())`):

```dart
  @override
  Widget build(BuildContext context) {
    validatePlanEditorBar(widget.bar);
    validatePlanServiceBar(widget.serviceBar);
    if (widget.unitOverlayBuilder != null) {
      validatePlanOverlayLayout(widget.unitOverlayLayout);
    }
    _measureChrome();
    // The theme reader rebuilds alone on a theme change, handing back the
    // same child, so no overlay is built again (G-5); the modes are built
    // below it, after it assumed the canvases (floor_plan_view.dart:675-684).
    return PlanThemeScope(
      view: widget.theme,
      child: _ChromeOrigins(
        onTheme: _assumeCanvases,
        child: Builder(builder: _modes),
      ),
    );
  }

  Widget _modes(BuildContext context) {
    final c = widget.controller;
    final mode = c.mode.value;
    _shown = mode;
    _measureAfterFrame(mode, c.activeDocument);
    _keepPlanInPlace();
    return mode == PlanMode.service ? _serviceView() : _editor(context);
  }

  /// 2a's editor: the shortcuts, the bar, the columns and the canvas.
  Widget _editor(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final strings = PlanStrings.of(context);
    final file = _fileCommands(strings);
    final edit = _editCommands(strings);
    return PlanShortcuts(
      // … 2a's PlanShortcuts(…) subtree, unchanged but for the canvas:
      // PlanCanvas(controller: c, rulers: widget.rulers, grid: widget.grid,
      //   snapping: widget.snapping, autofocus: widget.autofocus,
      //   unitOverlays: _designOverlays()),
    );
  }
```

and, at the end of the file:

```dart
/// Reads the resolved theme for [onTheme] at each build of the editor and
/// each change of the theme, and builds [child] as given
/// (floor_plan_view.dart:758-773).
class _ChromeOrigins extends StatelessWidget {
  const _ChromeOrigins({required this.onTheme, required this.child});

  final void Function(PlanTheme? theme) onTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onTheme(PlanThemeScope.of(context));
    return child;
  }
}
```

The `_editor` comment lines stand for 2a's code, which the implementer moves, not rewrites: everything `build` returned inside `PlanThemeScope(child: …)` in 2a (`plan_editor.dart:596-662`). Imports gained: `package:jet_cad_2d/jet_cad_2d.dart` (`DraftDocument`), `InteractionLayer` and `kRulerThickness` from `jet_cad_2d_flutter`, `../service/service_tool.dart`, `../service/view/plan_service_bar.dart`, `../service/view/plan_service_view.dart`, `../service/view/unit_overlays.dart`, `../units/unit_detail.dart`, and Task 11's `PlanMode` file.

Task 10's `unitInspectorBuilder` stays as Task 10 wired it (the property panel, design only; in service there is no panel).

- [ ] **Step B5: Run the tests.** `cd packages/jet_cad_2d_plan && flutter test test/editor test/service test/canvas test/controller`. Expected: all pass.

- [ ] **Step B6: Remove Part A's skip.** In `test/service/view/service_bar_test.dart`, BT1 imports `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` for its names (today's BT1 used the barrel alone) and loses its `skip:` argument. It goes green after Step B7.

- [ ] **Step B7: The barrel.** In `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, every export keeps its `show` list; add (sorted among the exports):

```dart
export 'src/service/service_tool.dart' show PlanFloorDrag, PlanLongPress;
export 'src/service/view/plan_service_bar.dart'
    show PlanServiceAction, PlanServiceBar;
export 'src/service/view/plan_service_view.dart' show PlanServiceView;
export 'src/service/view/unit_overlays.dart'
    show
        PlanOverlayLayout,
        PlanOverlaySize,
        PlanUnitOverlay,
        PlanUnitOverlayBuilder;
```

and grow two existing `show` lists: Task 9's `export 'src/units/unit_problems.dart' show …` gains `UnitProblem`, and the `theme/plan_theme.dart` export gains `kUnitColourOpacity` (Task 15's, controller ruling R-22). The 2b names Tasks 4, 8, 9, 11, 12 and 13 exported stay where those tasks put them (`PlanCamera` from `controller/plan_camera.dart`, the unit types from `units/unit_detail.dart`, `PlanMode` from `service/service_session.dart`, `UnitGroup`/`UnitStatus` from `service/service_state.dart`, `ServiceRestore` from `service/service_record.dart`); none is exported twice. A public name an earlier 2b task declared that is in neither ED-9's set nor this list is reported, not dropped or added silently: the coordinator rules.

- [ ] **Step B8: The example, the README and the CHANGELOG.** Replace `packages/jet_cad_2d_plan/example/main.dart`'s `build` and add the button, so the file reads:

```dart
// PlanEditor over an empty plan with no kit: the plan library's own tools,
// the layers and the page; a button in each bar switches to the service
// mode and back. Run from the package directory with
// `flutter run -t example/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePlanFonts();
  registerFontLicences();
  runApp(const PlanExampleApp());
}

class PlanExampleApp extends StatefulWidget {
  const PlanExampleApp({super.key});

  @override
  State<PlanExampleApp> createState() => PlanExampleAppState();
}

class PlanExampleAppState extends State<PlanExampleApp> {
  /// One plan and no kit: a kit package adds its types, tools and symbols
  /// through `PlanController(kits: [...])`.
  final PlanController controller = PlanController(kits: const []);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Switches the plan to [next]: the service mode works on a copy, so
  /// nothing done there reaches the saved plan.
  Widget modeButton(PlanMode next) => IconButton(
        key: Key('example-${next.name}'),
        tooltip: next.name,
        icon: Icon(next == PlanMode.service
            ? Icons.room_service_outlined
            : Icons.edit_outlined),
        onPressed: () => controller.setMode(next),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        home: Scaffold(
          body: PlanEditor(
            controller: controller,
            bar: PlanEditorBar(trailing: [modeButton(PlanMode.service)]),
            serviceBar: PlanServiceBar(trailing: [modeButton(PlanMode.design)]),
          ),
        ),
      );
}
```

In `packages/jet_cad_2d_plan/README.md`, replace the Dart block with the new `example/main.dart`, whole, byte for byte (ED-README); replace the first paragraph's last sentence and add a paragraph after it:

```markdown
…or `PlanEditor`, which lays them out as one editor.

In **service mode** (`controller.setMode(PlanMode.service)`) staff work on
a copy of the plan: `PlanServiceView` (which `PlanEditor` shows in that
mode) taps, selects, groups and moves its **units** -- the tables placed by
hand and the seats a kit's rows generate -- by their labels, with statuses,
groups, focus and the host's own widgets on them. Nothing done there
reaches the saved plan; `serviceJson()` and `restoreService` keep the
moves and groups apart from it.
```

In `packages/jet_cad_2d_plan/CHANGELOG.md`, under `## 0.8.0 (unreleased)`, after the 2a paragraph's list, add:

```markdown
The service mode (sub-project 2b).

- Units: a placed symbol instance whose definition carries `jetcad.unit`,
  or one a kit's parametric type generates (a seat in a row); identified
  by its label (the `UNIT` attribute), numbered on placement when the
  unit is `numbered`; `units`, `unitDetails`, `unitAt`, `select`,
  `fitToUnits`, `labelWarnings`, `unitChanges`; host data and colour
  (`setUnitData`, `setUnitColour`, `setUnitLabel` and their plural forms).
- `PlanMode` and `setMode`: the service mode works on a copy of the design
  with its own systems, lock and failure boundary; `undo`, `redo`,
  `export`, `print` act on the active document.
- Service state by label: `unitStatuses`, `unitGroups`, `groupStatuses`,
  `unitFocus`, `selectedUnits`, `selectedGroup`, `mergeCandidate`; the
  service record `jet_cad.service` (`serviceJson`, `restoreService`,
  `resetService`, `serviceEdited`, `serviceChanges`).
- `PlanServiceView` with `PlanServiceBar`, the events (`onUnitTap`,
  `onUnitDoubleTap`, `onUnitContextMenu`, `onGroupTap`, `onUnitHover`,
  `onUnitsMoved`, `onFloorTap`, `onMergeRequested`, `onSplitRequested`,
  `onLayoutChanged`), unit overlays (`PlanUnitOverlay`,
  `PlanOverlayLayout`); `PlanEditor` shows it in service and keeps the
  plan in place across a switch.
- `PlanPermissions`: `relabel`, `selectUnitsOnly`, `serviceMove`,
  `serviceMerge`, the `unitsOnly` profile. `PlanTheme`: the service and
  colour fields. Words for units and the service mode in English, German
  and Turkish; a host's own words (`PlanController(words:)`).
- In design, a generated unit stands for its object: a click on a seat
  selects its row. A window band over a row of seats alone selects
  nothing (a known limit).
```

- [ ] **Step B9: Run the tests.** `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice` (CI's form since Task 14). Expected: `All tests passed!`, no skip (BT1's is gone, Step B6; plain `flutter test` skips only Task 14's two allocation files).

- [ ] **Step B10: The gates.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, format exit 0. `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants` passes, nothing skipped (the paint invariant with Task 15's service scene; the canvas's `unitOverlays` slot adds nothing per entity). After the commit: `cd packages/jet_cad_2d_plan && dart pub publish --dry-run` exits 0 with `Package has 0 warnings.` (**never** without `--dry-run`). `git status --short` shows only Part B's files before the commit.

- [ ] **Step B11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/example/main.dart packages/jet_cad_2d_plan/README.md packages/jet_cad_2d_plan/CHANGELOG.md packages/jet_cad_2d_plan/test/editor/editor_service_mode_test.dart packages/jet_cad_2d_plan/test/editor/editor_service_view_test.dart packages/jet_cad_2d_plan/test/editor/editor_modes_test.dart packages/jet_cad_2d_plan/test/service/view/service_keys_test.dart packages/jet_cad_2d_plan/test/service/view/service_bar_test.dart packages/jet_cad_2d_plan/test/service/view/service_options_test.dart packages/jet_cad_2d_plan/test/service/view/band_view_test.dart packages/jet_cad_2d_plan/test/service/view/unit_groups_gesture_test.dart packages/jet_cad_2d_plan/test/service/view/unit_groups_context_test.dart packages/jet_cad_2d_plan/test/service/view/theme_service_test.dart packages/jet_cad_2d_plan/test/service/view/status_caption_test.dart packages/jet_cad_2d_plan/test/service/view/unit_groups_look_test.dart packages/jet_cad_2d_plan/test/service/view/unit_fill_view_test.dart packages/jet_cad_2d_plan/test/theme/theme_service_mode_test.dart packages/jet_cad_2d_plan/test/editor/unit_inspector_test.dart packages/jet_cad_2d_plan/test/example_test.dart packages/jet_cad_2d_plan/test/barrel_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): PlanEditor's service mode, the plan kept in place

PlanEditor shows PlanServiceView in service with every service option
passed through, and keeps the plan where it is on the screen across a
mode switch (today's R-13: the controller reframes the camera by the
two canvases' origins, assumed from the chrome and measured after the
frame). Overlays rebuild at the host's rebuild only. The barrel exports
the service mode's names; the example switches modes; the README and
the CHANGELOG describe the service mode.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step B12: Mutation check** (on the committed files; after each, `git checkout -- <file>` and `git diff --quiet -- <file>` exits 0):
  - M-SV-8: in `_modes`, `return mode == PlanMode.service ? _serviceView() : _editor(context);` → `return _editor(context);` → SV-8 red.
  - M-SV-9: in `_serviceView`, delete `onUnitHover: widget.onUnitHover,` → SV-9 red.
  - M-SV-10: in `_serviceView`, `_service ??= PlanServiceView(` → `_service = PlanServiceView(` (a new view at each build) → SV-10 red.
  - M-SV-R1: in `plan_controller.dart`'s `_reframe`, delete `if (a != b) camera.panBy(a - b);` → the ported V7a red.
  - M-SV-R2: `chromeMoved` returns at once → the ported T2-f red.
  - M-SV-R3: `canvasAssumed` returns at once → the ported R-3 "the service bar hidden from the start: the first switch …" red.
  - M-SV-R4: in `canvasMeasured`, delete the `camera.panBy(…)` line → the ported V7b red.
  - M-SV-R5: in `plan_editor.dart`'s `_chromeOrigin`, `final left = _leftShown ? 240.0 : 0.0;` → `final left = 240.0;` → the ported R-3 "the editor's rulers and left column gone and back …" red.
  - M-ED-8b: in `example/main.dart`, `onPressed: () => controller.setMode(next),` → `onPressed: () => controller.setMode(PlanMode.design),` (and the README block with it, so ED-README stays green) → ED-8b red.
  - M-ED-9: drop `PlanServiceView` from the barrel's `show` list → ED-9 red.

#### Assumed from earlier tasks

Used as written; where an earlier task named it otherwise, use that task's name and report the difference.
- Task 5: `unitKit()` in `test/support/test_kit.dart` carries the `test.row` type (id `test.row`; `testKit()` alone does not) and labels its seats `A1`…, `B1`…; `serviceFixture().json` (`test/support/service_fixture.dart`) holds the plan's text; `service_host.dart`'s `rowsController` reads it.
- Task 9: `@internal List<Handle> get unitDetailInstances` on `PlanController`, one instance per `unitDetails` entry, index for index (today's `tableDetailInstances`, `floor_plan_controller.dart:1518`); `UnitIndex.withLabel` and `units` reached through `PlanController.unitIndex` (the active document's).
- Task 11: `PlanController.mode` is a `ValueListenable<PlanMode>` that notifies on `setMode`; `setMode` is where Step B3 inserts the reframing; `ServiceSession.document`, `index`, `page` (a `PageNotifier`), `selection`, `outlines`, `tools` (a `ToolController`), `units` (a `UnitIndexCache`); the session's systems are its own (nothing here acquires them); `resetService`/`restoreService`/`load`/`newPlan` give the session a new document (the canvas is keyed by it).
- Task 12: `groupIdsByLabel(Map<String, UnitGroup>) → Map<String, String>` in `service/service_state.dart` (today's `groupIdsByNumber`, `table_groups.dart:50`).
- Task 14, in `service/service_tool.dart`: today's records renamed for units, read at each call —
  ```dart
  typedef ServiceCallbacks = ({void Function(String label)? onUnitTap, void Function()? onLayoutChanged,
      void Function(String groupId, String label)? onGroupTap,
      void Function(Set<String> labels)? onMergeRequested, void Function(String groupId)? onSplitRequested});
  typedef ServiceOptions = ({PlanLongPress longPress,
      void Function(String label, Offset globalPosition)? onUnitContextMenu, PlanFloorDrag floorDrag});
  typedef ServiceEvents<M> = ({void Function(List<M> moved)? onUnitsMoved,
      void Function(String label)? onUnitDoubleTap, void Function(Offset world)? onFloorTap,
      void Function(String? label)? onUnitHover});
  const kNoServiceEvents = (onUnitsMoved: null, onUnitDoubleTap: null, onFloorTap: null, onUnitHover: null);
  final class ServiceHost {
    const ServiceHost({this.callbacks, this.options, this.userCamera,
        this.toGlobal, this.events, this.idleKeys});   // each defaults to today's (Task 14); Step A9 passes all six
    static const ServiceHost none;     // today's defaults: no callback, kDefaultServiceOptions, …
    final ServiceCallbacks Function() callbacks; final ServiceOptions Function() options;
    final bool Function() userCamera; final Offset Function(Offset local) toGlobal;
    final ServiceEvents<Handle> Function() events; final bool Function() idleKeys;
  }
  String? contextSelect(UnitInfo hit, SelectionController selection, {Set<SelectionKey>? group});
  // ServiceTool: UnitPicker get picker; Set<SelectionKey>? groupKeysOf(UnitInfo hit); ToolPhase get phase.
  // ServiceSession (Task 11, wired by Task 14): ServiceTool get tool; ServiceHost host (read by the tool at each call).
  ```
  `serviceMove` is read by the tool from the controller's permissions, so `ServiceOptions` has no `serviceMoves`.
- Task 15: the painters' constructors as the code of Step A9 calls them (today's `service_view.dart:290-351`, renamed: `document`, `units`, `camera`, `statuses`/`unitGroups`/`groupStatuses`, `groups`/`unitFocus`, `focus`, `paper` a `ValueListenable<int>`, `theme` a `ValueListenable<PlanTheme?>`, `darkCanvas`, `repaint`; `UnitGroupLayer.frames`/`.chips`). They are Task 15's Produces exactly (checked by the reconcile: every named argument of Step A9's three calls is a parameter there). `PlanPageFlows.exportOnce(…, {double unitColourOpacity})` and `printOnce(…, {double unitColourOpacity})` carry the opacity to `PlanExportRequest.unitColourOpacity`. `PlanCanvasView.unitOverlays` is the renamed slot.
- 2a: `PlanCanvasView`, `PlanTextKeys`, `PlanShortcutGuard`, the chords, `PlanThemeScope`, `planPaperPaletteFor`, `PlanLocaleScope.push`, `EditorPageFlows`, `FakePagePrinter`, `RecordingPageExporter`, `placeSymbol`, `testKit()`.

#### Interface problem

1. Resolved by R-17 (`ServiceHost` and the settable `ServiceSession.host` are Task 14's, its parameters optional with today's defaults; `ServiceSession.tool` is a `ServiceTool`; `ServiceOptions` has no `serviceMove`).
2. Resolved: `@internal List<Handle> get unitDetailInstances` is Task 9's Produces (the Shared interfaces list it).
3. Resolved: `groupIdsByLabel` is Task 12's Produces (the Shared interfaces list it).
4. Resolved: the painters' constructors and `PlanPageFlows.exportOnce`/`printOnce({double unitColourOpacity})` are Task 15's Produces (the Shared interfaces list them).
5. Resolved by R-19 (one owner per support helper: the table fixture is Task 6's and Task 8's `unit_fixtures.dart`, the embedding fixture Task 9's `unit_embedding_fixture.dart`; Step A1 creates only `pagePlan`, `kToolbarNumbers` and `toolbarPlanJson`).

---

