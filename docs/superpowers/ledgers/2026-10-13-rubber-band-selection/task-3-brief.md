# Brief: Task 3 of docs/superpowers/plans/2026-10-13-rubber-band-selection.md

Spec: docs/superpowers/specs/2026-10-13-rubber-band-selection-design.md (revision 2, approved)

## Global Constraints

- `CLAUDE.md`'s non-negotiables. **The frame path allocates nothing per
  entity**: `query_allocation_test`, `paint_allocation_test` and
  `pick_allocation_test` stay untouched and green. A live band builds no
  `Paint` and no `Path` per frame (RB16).
- **`jet_cad_2d` is not edited.** `jet_cad_2d_flutter` is edited **only in
  Task 1**.
- **No existing public signature, `==`, `hashCode` or `toString`
  changes.** New public API, exactly: `bandModeFor`, `SelectionBandPainter`
  (Task 1, render barrel); `FloorPlanFloorDrag`,
  `FloorPlanView.floorDrag` (Tasks 2–3, host barrel). Every new parameter
  is named and optional with `pan` as its default. The internal
  `ServiceOptions` record gains `floorDrag` (Task 2).
- **Existing tests pass unedited**, with these named exceptions only: the
  `ServiceOptions` record literals in
  `test/service/service_options_test.dart`,
  `test/host/table_groups_context_test.dart` and
  `test/host/table_overlay_test.dart` gain `floorDrag:
  FloorPlanFloorDrag.pan` (Task 2). Any other test that has to change is a
  finding for the task's report.
- **The standing sets stay exactly as they are**
  (`tool/ci/standing_failures.txt`, `standing_skips.txt`), compared from
  the repo root with `dart run tool/ci/expect_failures.dart --package
  packages/<pkg> --root packages/<pkg> <run.json>` (runs made with
  `--file-reporter json:<run.json>`). On macOS the render package's
  `text_lod_ladder` rungs 1–2 pass: the recorded standing difference, not
  a finding. The engine's `dart test` exits 1 for its two fingerprints
  while `expect_failures` exits 0.
- **Every task ends green** in every package it touches and every package
  that reads what it changed. The planner runs with `flutter test
  --enable-vmservice`. `flutter analyze` / `dart analyze`, and `dart format
  --output=none --set-exit-if-changed .`, clean.
- **Fixtures** (the spec's testing section): the camera is y-flipped,
  scaled ≠ 1 and off the origin (it never rotates); tables are rotated
  and one is mirrored; one L-shaped table is rotated 37°; the plans hold
  a group of three, a table on a locked layer, a group with a locked
  member, an unnumbered table, a table on a hidden layer and a non-table
  symbol (the planter).
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report.
- **Never `git checkout` a file to revert it**; copy it aside or `git show
  HEAD:path > path`. **Never commit an `analysis_options.yaml`.** **Never
  synthesize test output.** Code, comments and commits in English; commit
  trailers name the model that wrote the commit.
- **No handle and no component type crosses the host barrel.**
- **The worktree guard:** this session's shell refuses `$VAR` in argument
  position, `bash <script>` and git-mixing pipelines inside the worktree;
  use plain commands and literal paths and SHAs.

## Review Focus

The situations a person meets that the spec's table does not name, each
pinned by a test in the task named:

1. **A tablet under `band` on a crowded floor**: a finger in the aisle
   10 px off a table's box draws a band, a tap there still selects that
   table, and a finger on the table itself still moves it. Task 2, RB5b;
   Task 3, RBV7.
2. **A band, then at once a tap on a table**: the tap acts normally (no
   stuck state, no double tap made from the band's press). Task 2, RB13b.
3. **A band while a host status, group colour and zone veil are drawn**:
   the band takes veiled tables and paints over the fills (it is an
   overlay). Task 3, RBV6.
4. **The design mode, after the refactor**: its band still selects, still
   toggles with Shift at the up, and still paints the same colours. Task
   1, BP3 and the existing `tool_palette_test` / `select_tool` tests.
5. **A host flipping `floorDrag` while the view is shown**: the next press
   reads the new value; a band in progress finishes as it started. Task 3,
   RBV5.

---


### Task 3: The view's option, through real pointers (RB-1)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart` (`:41-47` the constructor, the field beside `longPress` `:95`, `:698-702` the options record)
- Modify: `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart:30-40` (`FloorPlanFloorDrag` in the `show` list of `floor_plan_types.dart`)
- Test: `packages/jet_cad_floor_plan/test/host/band_view_test.dart`
- Test: `packages/jet_cad_floor_plan/test/host/barrel_test.dart` only if it enumerates the barrel's names (then a named exception: add `FloorPlanFloorDrag`; say so in the report)

**Interfaces:**
- Consumes: Task 2's `FloorPlanFloorDrag`, `ServiceOptions.floorDrag`.
- Produces: `FloorPlanView({…, FloorPlanFloorDrag floorDrag =
  FloorPlanFloorDrag.pan, …})`, `final FloorPlanFloorDrag floorDrag;`
  read at each press.

- [ ] **Step 1: Write the failing tests** — `test/host/band_view_test.dart`,
  on `service_options_test.dart`'s harness pattern (read it; build the
  plan the same way with a group `{'5', '6'}` via
  `controller.setTableGroups`, table 3 locked, table 4 unnumbered), a
  `FloorPlanView` with `floorDrag`, `userCamera`, `shortcuts`,
  `longPress`, `onTableTap`, `onFloorTap`, `onTableContextMenu`
  parameters; `selectedTables` listened to with a counter:
  - **RBV1** (RB3) `band`: a one-finger drag (`TestGesture`, kind touch)
    from the floor over tables 1 and 2 selects `{'1', '2'}`, the camera
    unmoved; a mouse drag does the same; two fingers down on the floor
    and moved together pan (the camera moved) and select nothing; a
    second finger landing mid-band cancels it (selection unchanged), and
    after both lift a tap on table 1 selects it. M-RB3, M-RB3b.
  - **RBV2** (RB4) `band` with `userCamera: false`: the band selects.
    M-RB4.
  - **RBV3** (RB13) `selectedTables` notifies exactly once for a band
    that selects `{'1', '2'}`; no `onTableTap`, no `onFloorTap`.
  - **RBV4** (RB14) under `shortcuts: false`, Escape mid-band (a mouse
    drag held, `sendKeyEvent(LogicalKeyboardKey.escape)`) ends it: the
    up then changes nothing; a secondary click mid-band opens no menu;
    `controller.setMode(FloorPlanMode.design)` mid-band, then back:
    nothing selected. M-RB17 at the view.
  - **RBV5** `floorDrag` flipped from `pan` to `band` by rebuilding the
    view: the next plain drag bands; flipped back mid-band: that band
    finishes as a band. (Review Focus 5.)
  - **RBV6** (RB18) with `controller.setTableFocus({'2'})` (table 1
    veiled) and a status on table 2, a band over 1 and 2 selects both. A
    pin, not a mutant's killer: the tool never sees the focus, so M-RB20
    has no place to be applied; the report says so.
  - **RBV7** (RB19) `longPress: FloorPlanLongPress.contextMenu`, touch,
    `band`: a 600 ms press on table 1 opens the menu for `'1'`; a floor
    drag bands. M-RB21. Also Review Focus 1: a finger 10 px outside
    table 2's box dragged bands; on table 2's top dragged moves it.
  - **RBV8** `pan` (the default): a Shift mouse drag over 1 and 2 adds
    them to a selected 4 (unnumbered: `selectedTables` is `{'1', '2'}`);
    a plain mouse drag pans.
  Run: fails (`floorDrag` is not a parameter).

- [ ] **Step 2: Implement** — the constructor parameter `this.floorDrag
  = FloorPlanFloorDrag.pan` after `longPress`; the field, documented:

```dart
  /// What a one-pointer drag on the empty floor does in the selection
  /// mode (rubber-band spec RB-1): `pan` (the default) pans, and a Shift,
  /// Ctrl or Cmd mouse or stylus drag draws a band that adds to the
  /// selection; `band` draws a band that selects — left to right the
  /// tables wholly inside, right to left every table touched, a group
  /// whole, a locked table never — and the camera pans with two fingers,
  /// the wheel or trackpad, and the middle button. Read at each press.
  final FloorPlanFloorDrag floorDrag;
```

  and `floorDrag: widget.floorDrag` in the options record (replacing
  Task 2's `FloorPlanFloorDrag.pan`). Barrel: add `FloorPlanFloorDrag` to
  the `show` list.

- [ ] **Step 3: Run** — the file passes; the planner's suite green.

- [ ] **Step 4: Mutants** — M-RB3 (the view passes `pan` always), M-RB3b
  (`banding` mapped to `ToolPhase.idle` in Task 2's `phase`), M-RB4,
  M-RB21 (`_startsBand` returns false when
  `_options.longPress == contextMenu`): each red, reverted.

- [ ] **Step 5: Commit** — `feat(floor-plan): FloorPlanView.floorDrag`.

---

