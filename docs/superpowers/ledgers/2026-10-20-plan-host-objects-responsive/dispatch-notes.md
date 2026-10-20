# Standing implementer notes (POS-host sub-project)

Read with your task brief. These hold for every task. The spec is
`docs/superpowers/specs/2026-10-20-plan-host-objects-responsive-design.md`
(decisions D1–D14); read the decisions your task cites. Do not read the whole
plan file.

## Binding rules
- Work only in `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/pos-host` (branch `feat/pos-host`). Never `cd` to the main checkout.
- Never push, merge, tag or `dart pub publish` (dry-run is fine). Never run `git stash` bare.
- Never commit any `analysis_options.yaml` (`flutter pub get` rewrites several). Stage files by name, never `git add -A`; check `git status --short` before each commit.
- Never synthesize test output: every count or line in your report is copied from a run you made.
- Code, comments and commit messages in English. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (or your own model's name).
- Do not dispatch subagents.
- Do not touch the engine packages (`jet_cad`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`) unless your brief says so; if you believe you must, stop and report NEEDS_CONTEXT.
- Never weaken, skip or delete an existing assertion. Existing tests under `packages/jet_cad_2d_plan/test/editor/` and `test/panels/` must pass unedited (desktop unchanged).
- The host never receives a `Handle`; no host vocabulary ("POS", "monepro", "table id") in any API name or doc comment of the packages.

## Testing bar
- Each new test and each behaviour change names a mutation that turns it red. Run it on committed code, revert with `git checkout -- <file>`, show `git diff --quiet` passing. List every mutation and the red test in the report.
- Beware degenerate fixtures: put objects off the origin, rotate (not 0/90 only where the brief allows) and mirror them.
- Widget tests at a size: `tester.binding.setSurfaceSize(Size(w, h))` with `addTearDown(() => tester.binding.setSurfaceSize(null))` (see `test/editor/editor_notice_test.dart:27`).

## Gates (every task ends green, in each package you touched)
- `jet_cad_2d_kit`, `jet_cad_2d_kit_architecture`, `jet_cad_2d_kit_restaurant`, apps: `flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
- `jet_cad_2d_plan`, `jet_cad_2d_integration`: the same with `flutter test --enable-vmservice`. A change to `jet_cad_2d_plan` (PlanStrings above all) also runs the `jet_cad_2d_integration` suite and analyze: it has its own copy of the recording strings.
- Any kit change: `dart run tool/ci/check_kit_deps.dart` from the worktree root.
- Known standing failures (not yours): `tool/ci/standing_failures.txt`.

## Report
Write the full report to the path your dispatch names: status, commits, the gates' real last lines, every mutation, decisions and concerns. Return only status, commits, one-line test summary, concerns.

## Facts learned (updated per task)
- (mapping) PlanEditor `_editor` = Column[`_topBar` (key chrome-top, 44 h), Expanded(Row[left 240 `chrome-left` (`_leftPanel`), canvas `chrome-canvas`, right 280 `chrome-right` (scroll `chrome-right-scroll`: PlanPropertyPanel, UnitInspector `unit-inspector`, PlanLayerPanel, PlanPagePanel, each `_kept` = Visibility maintainState)])]; service mode = cached `PlanServiceView` (`_serviceView`, plan_editor.dart:716), no side panels. PlanEditorBar(visible, actions, leading, trailing).
- Unit host data: component `UnitData` id `jetcad.unit_data`, JSON `{'data': {...}}`, on the unit INSTANCE node; limits `unitDataProblem` (unit_components.dart:18-36); writes via `_setUnitComponents` → `_runHostEdit` (one CompoundCommand, one undo step). `unitDetails` cached per unit index; `unitChanges` broadcast async, design only.
- Property panel targets (plan_property_panel.dart:64-123): `_ObjectTarget(handle, typeId)` via `catalog.typeIdOf`, `_SymbolTarget` (`isSymbolInstance`), `_UnitTarget` (`placedUnitOf`), `_ToolTarget`; only root-level single selection.
- PlanType capabilities are private nullable fields with erased public operations (plan_type.dart header, `colourOf`/`titleWordOf`). Room: `roomPlanType` (room_plan.dart:29); trace `_traceOf(view, self)` needs a ParametricView; `traceRoomAmong(seedWorld, PlaceSource)` (room_trace.dart:578) with `RoomInputs(document, live)` (room_inputs.dart:230) works from a document; `Traced.ring` world, anticlockwise.
- Handles persist across save/load (json_codec); never expose them.
- (T1-T2) `PlanType.areaOf(DraftDocument document, Handle group, PlanWords words)` → world ring (anticlockwise, no closing duplicate) or null; `hasArea`. `roomPlanType` has an area (traced ring); memo per document + `commands.stateId` (not moved by notifyLoaded — see ledger R4). Frozen walls still bound an area (R3).
- (T3) `PlanObjectRef` (opaque, `@internal PlanObjectRef.of(handle)`, `==` by handle; valid for its plan only), `PlanObjectKind {unit, symbol, type}`, `PlanObjectDetail {ref, kind, typeId, symbolKey, label, data}` in lib/src/objects/; controller `objectDetailOf(ref)`, `objectDetails` (data-carrying only), `setObjectData`, `setObjectsData` (plan_controller.dart ~1590-1640). Objects = root unit instances, root kit-type groups, root symbol instances. Data stored in `UnitData` on the root node.
- (T4) `PlanUnitDetail.section` (`PlanObjectDetail?`), `Stream<PlanSectionChange> sectionChanges` (`byLabel: Map<String, PlanObjectDetail?>`), lib/src/objects/sections.dart (`SectionFinder`, areas from every PlanType with hasArea; equal areas within linear × perimeters → lower handle). Test zone kit: packages/jet_cad_2d_plan/test/support/zone_kit.dart; real-room tests in packages/jet_cad_2d_integration/test/sections/.
- (T5) `PlanEditor.objectInspectorBuilder` → `ObjectInspector` (lib/src/editor/object_inspector.dart), Key('object-inspector'), mounted in chrome-right-scroll under PlanPropertyPanel (plan_editor.dart ~1000-1012), after UnitInspector.
- (T6) lib/src/editor/editor_layout.dart: `PlanEditorLayout {phone, tablet, desktop}`, `PlanLayoutBreakpoints(tablet: 600, desktop: 1000).layoutFor(w)`, the drawer host (Stack fit expand, fixed barrier slot, left 280 / right 300 capped 85%, maintainState), Escape via a HardwareKeyboard handler while a drawer is open (ignored when focus is in an EditableText). PlanEditor(breakpoints, layout). Keys chrome-left-button / chrome-right-button / chrome-left-drawer / chrome-right-drawer / chrome-tool-strip / chrome-symbols-button. Tests that need the desktop chrome below 1000 px pass `layout: PlanEditorLayout.desktop` (ruling R6).
- (T7) `PlanEditor`/`PlanServiceView` `serviceSidePanel` (+ breakpoints/layout on PlanServiceView): desktop docked 320 `Key('service-side-panel')`; phone/tablet behind `Key('service-right-button')` in the service bar, a 300 right drawer; none → no button/column.
- (T8) A pick (activeTool or armedSymbol change) closes the phone/tablet left drawer. PH1 (packages/jet_cad_2d_integration/test/phone/phone_design_test.dart) designs on a 375x812 phone by touch; integration depends on jet_cad_2d_kit_restaurant. A wall chain ends by picking another tool (open question for the human).
- (T10/T10c) Demo: Salon has Salon/VIP/Garden rooms; objectInspectorBuilder combo over fake_records.dart; PlanType `name` capability (room → name); PlanObjectDetail.label = name ?? title word; controller `sectionDetails`.
