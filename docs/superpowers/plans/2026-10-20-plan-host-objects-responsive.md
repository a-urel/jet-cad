# The plan library for a real POS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Any placed object takes host data and the host's inspector widget,
every table knows its section (the smallest room its centre stands in), and
`PlanEditor` lays itself out for phone, tablet and desktop in both modes.

**Architecture:** The kit contract gains an optional "area" capability on
`PlanType`; the architecture kit's room declares its traced outline. The plan
library reuses the unit-data component for any root object, names objects by
an opaque `PlanObjectRef`, computes sections at unit-index rebuild time, and
wraps its existing chrome in a width-driven layout (desktop = today's tree).

**Tech Stack:** Dart/Flutter pub workspace; `flutter_test`; the repo's
`tool/ci` checks and host probe.

**Spec:** `docs/superpowers/specs/2026-10-20-plan-host-objects-responsive-design.md`
(approved 2026-10-20). Read it before any task; decisions are cited as D1–D14.

## Global Constraints

- CLAUDE.md non-negotiables: no per-entity allocation on the frame path
  (`query_allocation_test.dart`, `paint_allocation_test.dart` stay green);
  draw order by handle; geometric decisions use `Tolerance`, stored values
  exact `==`; never commit `analysis_options.yaml`; never synthesize output;
  English code, comments and commits; commit trailer
  `Co-Authored-By: <model> <noreply@...>` as AGENTS.md says.
- Kit isolation: `dart run tool/ci/check_kit_deps.dart` green; the plan
  library names no kit type id.
- The host never receives a `Handle` (umbrella D18): every new public API
  names objects by `PlanObjectRef`.
- No host vocabulary in any API ("POS", "table id", "monepro").
- 0.8.x compatibility: `unitInspectorBuilder`, `setUnitData`,
  `setUnitsData`, `PlanUnitDetail.data`, `unitChanges` keep their behaviour;
  a plan saved by 0.8.1 opens with its unit data intact.
- Desktop unchanged: at ≥ 1000 logical px wide every existing test under
  `packages/jet_cad_2d_plan/test/editor/` passes **without edits**.
- Host data limits are today's: `unitDataProblem` (32 keys, key
  `^[a-z0-9_.-]{1,64}$`, value ≤ 1024, no control code units).
- Breakpoints (D4): phone `< 600`, tablet `600 ≤ w < 1000`, desktop `≥ 1000`
  logical px of the editor's own width.
- Versions are not bumped; each touched package's CHANGELOG gets its lines
  under `## Unreleased`. Publishing is the human's.

## Review Focus

1. A table centred on the shared boundary of two adjacent sections: a
   deterministic answer (the smaller area; equal areas → the lower handle),
   the same after save and load. → Task 4.
2. The window resized (or a phone rotated) across a breakpoint while a side
   panel is open: no exception, no panel left stranded, the selection kept.
   → Task 6.
3. The inspected object deleted, or its creation undone, while the host's
   widget shows: the widget goes, no stale reference reaches the builder.
   → Task 5.
4. Host data on a locked object or an object on a locked layer: the same
   answer as units today (locked object → false; locked layer → allowed).
   → Task 3.
5. A room whose bounding walls are removed (its trace becomes unbounded):
   its area is gone, its tables lose the section, and one section change
   is reported. → Task 4.

---

### Task 1: The kit contract's area capability

**Files:**
- Modify: `packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart`
- Modify: `packages/jet_cad_2d_kit/CHANGELOG.md`
- Test: `packages/jet_cad_2d_kit/test/kit/plan_type_area_test.dart`

**Interfaces:**
- Produces: `PlanType({..., List<Vector2>? Function(T value, PlanObject object)? area})`;
  `bool get hasArea`; `List<Vector2>? areaOf(CommandTarget target, Handle group, PlanWords words)`
  — the object's closed outline in **world** millimetres, anticlockwise, no
  closing duplicate, or null (no value, no capability, or no area now).
  Follows the file's erased-operation pattern (private `_area`).

- [ ] **Step 1: Write the failing tests** — `AR1 a type without area: hasArea false, areaOf null`;
  `AR2 areaOf returns the capability's outline for the group's value, read through a DocumentPlanObject whose world is the group's accumulated transform`
  (fixture: a group translated by (5000, -3000) and rotated 30°; the
  capability returns `object.world` applied to a unit square; expect the
  four transformed corners within `Tolerance`);
  `AR3 areaOf on a group without the type's component: null`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_kit && flutter test test/kit/plan_type_area_test.dart` — FAIL (no `area`).
- [ ] **Step 3: Implement** the parameter, `hasArea`, `areaOf`; a CHANGELOG line under `## Unreleased`.
- [ ] **Step 4: Run** the package's gates (`flutter test`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`) — green. Mutation: `areaOf` ignoring `object.world` → AR2 red.
- [ ] **Step 5: Commit** `feat(kit): PlanType's area capability`.

### Task 2: The room declares its area

**Files:**
- Modify: `packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart` (and a helper in `room.dart` or `room_trace.dart` if needed)
- Modify: `packages/jet_cad_2d_kit_architecture/CHANGELOG.md`
- Test: `packages/jet_cad_2d_kit_architecture/test/room/room_area_test.dart`

**Interfaces:**
- Consumes: Task 1's `area` capability.
- Produces: `roomPlanType.hasArea == true`; `roomPlanType.areaOf(doc, room, words)`
  = the room's traced outer ring in world mm (`Traced.ring`), null for
  `SeedInWall` / `Unbounded`. Computed from the document (e.g.
  `traceRoomAmong(seedWorld, RoomInputs(document, live))` with the plan's
  live rule, or the room's generated outline child mapped by `object.world`
  — the implementer picks; memoise per `commands.stateId` like
  `roomAreaText`). Not on the frame path.

- [ ] **Step 1: Write the failing tests** — `RA1 four walls 6000 x 4000 placed at (12000, 7000): the area is the inner ring, anticlockwise, equal within Tolerance to the traced ring`;
  `RA2 a room bounded by two walls and two separators (an open garden): the area exists`;
  `RA3 the room group rotated 90° and mirrored: the area follows the world placement`;
  `RA4 a seed in a wall, and a room after one wall is deleted (unbounded): null`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_kit_architecture && flutter test test/room/room_area_test.dart` — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates** for the package plus `dart run tool/ci/check_kit_deps.dart`. Mutation: return the ring in local space → RA1/RA3 red.
- [ ] **Step 5: Commit** `feat(architecture): the room declares its area`.

### Task 3: Host data on any object

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/objects/object_ref.dart` (`PlanObjectRef`)
- Create: `packages/jet_cad_2d_plan/lib/src/objects/object_detail.dart` (`PlanObjectDetail`, `PlanObjectKind`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export)
- Test: `packages/jet_cad_2d_plan/test/objects/object_data_test.dart`

**Interfaces:**
- Produces:
  - `final class PlanObjectRef` — opaque; `==`/`hashCode` by the wrapped
    handle; no public constructor and no public handle; `@internal` access
    for the library.
  - `enum PlanObjectKind { unit, symbol, type }`.
  - `final class PlanObjectDetail { PlanObjectRef ref; PlanObjectKind kind; String? typeId; String? symbolKey; String? label; Map<String, String> data; }`
    — `typeId` for `type` objects, `symbolKey` for symbols and units,
    `label` the unit's label or the type's title word (a room's name).
  - `PlanObjectDetail? objectDetailOf(PlanObjectRef ref)`;
    `List<PlanObjectDetail> get objectDetails` (every root object that
    carries data, in draw order);
    `bool setObjectData(PlanObjectRef ref, Map<String, String> data)`;
    `bool setObjectsData(Map<PlanObjectRef, Map<String, String>> byRef)` —
    same rules as `setUnitsData`: `_requireDesign`, `unitDataProblem`
    (ArgumentError), empty map removes, one undo step labelled "Object data",
    false for an unknown ref or a locked object, a locked layer allowed.
  - Storage *(spec "left to the builder", decided here)*: the existing
    `UnitData` component (`jetcad.unit_data`) on the object's root node, so a
    unit's data written either way is the same data and 0.8.1 plans open.

- [ ] **Step 1: Write the failing tests** — `OD1 a bar counter symbol takes data: set, read back, undo removes, redo restores`;
  `OD2 a room takes data; it survives save and load (bytes round trip) with the same PlanObjectDetail`;
  `OD3 a unit's data written by setObjectData reads back as PlanUnitDetail.data, and setUnitData's as PlanObjectDetail.data`;
  `OD4 a plan saved by 0.8.1 (fixture bytes produced on main at 179b9fdc, committed under test/fixtures/) opens with its unit data`;
  `OD5 limits: 33 keys → ArgumentError; a locked object → false and no undo step; an object on a locked layer → true`;
  `OD6 in service mode setObjectData throws StateError`;
  `OD7 a ref from before newPlan() → objectDetailOf null, setObjectData false`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_plan && flutter test test/objects/object_data_test.dart` — FAIL.
- [ ] **Step 3: Implement**; export the three types; CHANGELOG line.
- [ ] **Step 4: Gates** (`flutter test --enable-vmservice`, analyze, format). Mutation: `setObjectsData` skipping the locked check → OD5 red.
- [ ] **Step 5: Commit** `feat(plan): host data on any object`.

### Task 4: Sections

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/objects/sections.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/units/unit_detail.dart`, `plan_controller.dart`, the barrel
- Test: `packages/jet_cad_2d_plan/test/objects/sections_test.dart`

**Interfaces:**
- Consumes: Task 1 `areaOf`, Task 3 `PlanObjectRef`/`PlanObjectDetail`.
- Produces:
  - `PlanUnitDetail.section` — `PlanObjectDetail?`, the section of D10.
  - `Stream<PlanSectionChange> get sectionChanges` — broadcast, async like
    `unitChanges`; `final class PlanSectionChange { Map<String, PlanObjectDetail?> byLabel; }`
    with the units (by label) whose section changed and the new section.
    Reported for design edits and service-mode layout moves; nothing on
    listen; nothing when no section changed; `newPlan`/`load` report nothing
    (as `PlanUnitsReplaced` covers them).
  - Rule (D10): the area whose outline contains the unit's centre
    (boundary counts as inside, by `Tolerance`); several → the smallest by
    area; equal → the lower handle; none → null. Computed when the unit
    index rebuilds, never per frame.

- [ ] **Step 1: Write the failing tests** — `SC1 two rooms, tables in each: each table's section is its room`;
  `SC2 a table outside every room: null`;
  `SC3 a VIP room inside the Salon: tables in the VIP corner get VIP, the rest Salon`;
  `SC4 a table centred on the shared wall-less boundary (a separator) of two rooms: the smaller room; equal rooms → the lower handle; the same after save and load` (Review Focus 1);
  `SC5 rotated (37°) and mirrored tables, a room group not at the origin: the centre decides`;
  `SC6 moving a table across rooms in design reports one PlanSectionChange with that label only; moving it within its room reports nothing`;
  `SC7 a service-mode layout move across rooms reports the change`;
  `SC8 deleting one wall of a room (unbounded): its tables lose the section, one change reported` (Review Focus 5);
  `SC9 the paint-allocation invariant with sections present` (extend the existing invariant fixture with two rooms; it stays green).
- [ ] **Step 2: Run** `flutter test --enable-vmservice test/objects/sections_test.dart` — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates.** Mutations: largest instead of smallest area → SC3 red; centre replaced by the box's min corner → SC5 red.
- [ ] **Step 5: Commit** `feat(plan): a unit's section, and its change events`.

### Task 5: The inspector for any object

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/editor/object_inspector.dart` (generalises `unit_inspector.dart`'s relay logic; keep `UnitInspector` working)
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`
- Test: `packages/jet_cad_2d_plan/test/editor/object_inspector_test.dart`

**Interfaces:**
- Consumes: Task 3 `PlanObjectDetail`, Task 4 `section`.
- Produces: `PlanEditor({..., Widget? Function(BuildContext, PlanObjectDetail)? objectInspectorBuilder})`.
  Mounted in the right column directly under `PlanPropertyPanel`, keyed
  `Key('object-inspector')`, only in design mode, only while
  `propertyPanel` is true, for exactly one selected root object. Routing
  (D9): units go to `unitInspectorBuilder` when given, else to
  `objectInspectorBuilder`; every other object to `objectInspectorBuilder`.
  Rebuilt on selection change and on each plan revision while shown
  (frame-safe, as `UnitInspector`).

- [ ] **Step 1: Write the failing tests** — `OI1 a selected bar counter shows the host widget with kind symbol and its key`;
  `OI2 a selected room shows it with kind type, the room type id and its name`;
  `OI3 with both builders a table goes to unitInspectorBuilder and a room to objectInspectorBuilder; with only the new one, the table goes to it`;
  `OI4 two objects selected, or none: no host widget`;
  `OI5 the inspected object deleted, then the deletion undone and redone: the widget goes, comes back, goes; the builder never sees a ref objectDetailOf answers null for` (Review Focus 3);
  `OI6 setObjectData from inside the host widget's callback updates the detail the next build sees`.
- [ ] **Step 2: Run** the test — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**, including `test/editor/unit_inspector_test.dart` unchanged and green. Mutation: route units to the new builder even when the old one is given → OI3 red.
- [ ] **Step 5: Commit** `feat(plan): the object inspector`.

### Task 6: The responsive design-mode layout

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/editor/editor_layout.dart` (`PlanEditorLayout`, `PlanLayoutBreakpoints`, the drawer host)
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (`_editor`, `_topBar`, `_leftPanel`)
- Test: `packages/jet_cad_2d_plan/test/editor/editor_layout_test.dart`

**Interfaces:**
- Produces:
  - `enum PlanEditorLayout { phone, tablet, desktop }`.
  - `final class PlanLayoutBreakpoints { const PlanLayoutBreakpoints({this.tablet = 600, this.desktop = 1000}); PlanEditorLayout layoutFor(double width); }`.
  - `PlanEditor({..., PlanLayoutBreakpoints breakpoints = const PlanLayoutBreakpoints(), PlanEditorLayout? layout})` — `layout` forces one.
  - Keys for tests and hosts: `Key('chrome-left-button')`, `Key('chrome-right-button')`,
    `Key('chrome-left-drawer')`, `Key('chrome-right-drawer')`, `Key('chrome-tool-strip')`.
  - Desktop: today's tree, byte-for-byte the same widgets and keys.
  - Phone (D1): no docked columns; the bar's first item the left button, its
    last the right button; the left drawer holds `_leftPanel`, the right
    drawer the right column's content (property panel, inspectors, layers,
    page). Tablet (D2): `chrome-tool-strip` docked left, icons only, a
    symbols icon at its foot opening the gallery as the left drawer; the
    right button as on the phone.
  - D5: one drawer at a time; a tap on the canvas, the same button again,
    or Escape closes it; opening never moves the camera. Drawers keep their
    panels' state (`maintainState`).

- [ ] **Step 1: Write the failing tests** (sizes via `tester.binding.setSurfaceSize`, reset in tearDown) —
  `EL1 1440 x 900: chrome-left/right present, no buttons, no drawers` (desktop as today);
  `EL2 375 x 812: no docked columns; both buttons in chrome-top; left button opens the tools drawer, right button the properties drawer`;
  `EL3 800 x 1280: chrome-tool-strip present, the symbols icon opens the gallery drawer, the right button opens properties`;
  `EL4 one drawer at a time; canvas tap, the button again, Escape each close it; the camera transform unchanged by opening`;
  `EL5 breakpoints (tablet: 700) and layout: PlanEditorLayout.phone both obeyed`;
  `EL6 a drawer open on the phone, the surface resized to 1440 x 900 and back: no exception, no drawer left open, the selection kept` (Review Focus 2);
  `EL7 the phone bar at 320 px wide does not overflow` (no RenderFlex overflow error).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**; every existing `test/editor/*` and `test/panels/*` test passes unedited. Mutation: swap the breakpoint comparison (`<` → `<=` at 1000 with a 1000-wide surface test in EL5) → red.
- [ ] **Step 5: Commit** `feat(plan): PlanEditor on phones and tablets`.

### Task 7: The service mode on every device

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (`_serviceView`), `lib/src/service/view/plan_service_view.dart`
- Test: `packages/jet_cad_2d_plan/test/service/view/service_layout_test.dart`

**Interfaces:**
- Consumes: Task 6's layout, breakpoints and drawer host.
- Produces: `PlanEditor({..., Widget? serviceSidePanel})` and the same
  parameter on `PlanServiceView`. Desktop: docked on the right, 320 wide,
  `Key('service-side-panel')`. Phone and tablet: behind a right button in
  the service bar (`Key('service-right-button')`), as a right drawer under
  D5's rules. None given: no button, no column. The plan otherwise fills
  the screen.

- [ ] **Step 1: Write the failing tests** — `SL1 desktop: the side panel docked, the plan beside it`;
  `SL2 phone: the button opens and closes the panel; a unit tap still reaches onUnitTap while it is closed`;
  `SL3 no serviceSidePanel: no button, no column, at all three widths`;
  `SL4 switching design → service with a design drawer open closes it`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**; existing `test/service/**` unedited and green. Mutation: dock on the phone too → SL2 red.
- [ ] **Step 5: Commit** `feat(plan): the service mode on phones and tablets`.

### Task 8: Designing on a phone (D7)

**Files:**
- Test: `packages/jet_cad_2d_integration/test/phone/phone_design_test.dart`
- Modify: whatever the scenario shows blocking (plan library or architecture kit), each fix with its own test.

**Interfaces:**
- Consumes: Tasks 3, 5, 6.

- [ ] **Step 1: Write the scenario test** at 375 x 812 with touch gestures (`tester.startGesture` / `kind: PointerDeviceKind.touch`):
  open the left drawer, pick Wall, draw a 4 m wall; open Symbols, place
  `restaurant.table.rect.four`; select it; open the right drawer, change its
  rotation; the object inspector's host widget (a test `DropdownButton`)
  sets `{'id': 't1'}`; assert the unit's data, its rotation, the wall's
  length within `Tolerance`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/phone/phone_design_test.dart`; for each failure, write the narrow failing test in the owning package, fix, re-run.
- [ ] **Step 3: Gates** for every touched package.
- [ ] **Step 4: Commit** `test(integration): designing on a phone` (fixes in their own commits).

### Task 9: The host guide and its probe

**Files:**
- Modify: `docs/host-guide.md` (new §6.10 "Linking any object", §6.11 "Sections", §6.12 "The inspector" (both builders), §14 "Phones and tablets" (layouts, breakpoints, the service side panel))
- Modify: `tool/ci/host_probe/lib/main.dart` (every new dart block)
- Modify: CHANGELOGs touched above if a line is missing

- [ ] **Step 1:** Write the sections; each code block also in the probe.
- [ ] **Step 2: Run** `dart run tool/ci/check_guide.dart` and `bash tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"` — green. Mutation: edit one new guide block without the probe → `check_guide` exit 1.
- [ ] **Step 3: Commit** `docs: the host guide — any object, sections, inspectors, phones and tablets`.

### Task 10: The restaurant demo

**Files:**
- Modify: `apps/restaurant_demo/lib/samples/salon.dart` (two rooms: VIP — walls of the Salon plus two separators in the north-east corner; Garden — outside the south wall, bounded by separators; each `RoomParams` + `ObjectLayer`, as `room_tool.dart:280-287`)
- Modify: `apps/restaurant_demo/lib/main.dart`, `side_panel.dart`; create `apps/restaurant_demo/lib/fake_records.dart` (the demo's own records: tables, bars, sections)
- Test: `apps/restaurant_demo/test/linking_test.dart`, `apps/restaurant_demo/test/layouts_test.dart`

- [ ] **Step 1: Write the failing tests** — `DL1 the Salon has three sections and every sample table's section is the expected one (by label)`;
  `DL2 the inspector's combo links a table, a bar counter and the VIP room to fake records; the data round-trips through Save/Restore`;
  `DL3 the side panel shows each table's section and updates when a table is moved into the Garden`;
  `DL4 the demo builds without exception at 375 x 812, 800 x 1280 and 1440 x 900 in both modes`.
- [ ] **Step 2: Run** `cd apps/restaurant_demo && flutter test` — the new tests FAIL.
- [ ] **Step 3: Implement**; keep every existing demo test green (update only those whose premise the new rooms change, each with a `// Decided:` line).
- [ ] **Step 4: Gates**; `apps/architecture_demo` tests green; `cd apps/restaurant_demo && flutter build web` OK.
- [ ] **Step 5: Commit** `feat(restaurant_demo): sections, linking any object, phones and tablets`.

### Task 11: Close

- [ ] **Step 1:** The full gates: every package and app (`flutter test`, `--enable-vmservice` where CI uses it), analyze, format; `cd tool/ci && dart test`; `check_guide`, `check_readmes`, `check_screenshots`, `check_kit_deps`; `flutter pub publish --dry-run` for `jet_cad_2d_kit`, `jet_cad_2d_kit_architecture`, `jet_cad_2d_plan` — 0 warnings.
- [ ] **Step 2:** Results note `docs/superpowers/notes/2026-10-20-plan-host-objects-results.md` with "For the human" (proposed versions under the 0.x rule, open questions) and a screenshot of the restaurant demo at phone width.
- [ ] **Step 3:** STATUS: the sub-project's state and resume point.
- [ ] **Step 4: Commit** `docs: the POS-host sub-project's results and STATUS`.
