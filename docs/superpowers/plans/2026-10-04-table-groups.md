# Plan — table groups (merging and splitting tables)

**Spec:** [2026-10-04-table-groups-design.md](../specs/2026-10-04-table-groups-design.md),
revision 2. It covers G1–G7, F-1..F-11 and M-TG-1..22 with their b/c
variants, and the review findings R-1..R-18 are applied.
**Approved** by the human ("Onaylıyorum, planı yaz", 2026-10-04).
**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`4490cd9`. The spec is at `ccab8d1`.

## Global constraints

- **Repo rules.** The `CLAUDE.md` non-negotiables apply.
  - The engine (`jet_cad_2d`) and the render package
    (`jet_cad_2d_flutter`) are **not edited**.
  - There is no schema change. Groups never reach the document (spec
    invariant 3).
- **Allocation.** The frame path allocates nothing per entity in steady
  state. The status painter's and the new group painter's
  `debugAllocations` show it (spec invariant 1).
- **No group, no change** (spec invariant 2).
  - Existing suites pass unedited, except the mechanical changes the spec
    lists: `ServiceCallbacks`, `TableStatusPainter` and `TableSelectTool`
    constructions gain a parameter, and the barrel test gains
    `TableGroup`.
  - An existing expectation never changes.
- **Gates.** Every task ends green across the planner, restaurant
  symbols, `floor_planner`, `restaurant_demo` and `dev_harness_2d`
  packages, running `flutter test`, `flutter analyze` and `dart format`.
  - The render package is run once per task to show it unchanged (the 7
    standing text-ladder failures and 1 skip).
  - The engine is run at the exit.
- **Named mutants.** Each task kills its named mutants by a scratch edit,
  reverted, and records the red command in the ledger
  (`.superpowers/sdd/2026-10-04-table-groups/`). A surviving mutant
  blocks the task. M-TG-19 is an invariant check, not a counted kill.
- **Fixtures** (spec "Testing"):
  - an off-origin, non-unit camera;
  - turned and mirrored tables;
  - non-sorted ids and numbers (`G7 = {12, 3, 7}`);
  - a file duplicate number;
  - a locked member and a hidden member;
  - both themes through the dark theme palette fixture.

## Tasks

### Task 1 — the model and the controller (G1, G2, G4 selection, G5 rule)

- **`TableGroup`** goes in `host/floor_plan_types.dart`: trimmed members,
  a blank member dropped, the label trimmed and cut to 24 characters, a
  blank label meaning none, value equality. It is exported from the
  barrel.
- **New Flutter-free `service/table_groups.dart`:**
  - validation (spec G2, all checks before any assignment);
  - the number-to-group lookup;
  - visible and selectable members from given table facts;
  - the lead order (digits compared by (length after leading zeros,
    then string), else string, ties to the lowest handle);
  - the Merge-units rule and the Split rule.
- **`FloorPlanController`:**
  - `setTableGroups` throws before notifying anyone;
  - `tableGroups`, `setGroupStatus`, `groupStatuses`;
  - `selectedGroup` follows both the selection and the groups;
  - `_select` expands numbers to their groups, in the selection mode
    only, and filters through the visible / unlocked / live rule;
  - the new notifiers are disposed.
- **Tests** (unit and controller), killing:
  - M-TG-1 (overlap, including after trimming, and no notification);
  - M-TG-2;
  - G2's other throws and the orphan group status;
  - M-TG-9 and M-TG-9b;
  - the `selectedGroup` half of M-TG-17 and M-TG-17b;
  - M-TG-19 (invariant: `designJson` byte-identical);
  - M-TG-20 (survives `setMode`, `resetLayout`, `load`);
  - the barrel test gains `TableGroup` (mechanical).

### Task 2 — selecting, tapping and moving (G4)

- **`TableSelectTool`** takes `groups:
  ValueListenable<Map<String, TableGroup>>`. Its lookup is keyed on the
  picker's key plus the groups map's identity.
- **Tap:** replaces the selection with the whole group. A modifier tap
  or a long press adds or removes the whole group through one `replace`,
  never `toggle`.
- **Callbacks:** `onTableTap`, then `onGroupTap`, including for a locked
  member.
- **Drag:** `_moving` expands to every involved group's selectable
  members. The drag is spent, with the selection untouched, when any
  involved group has a locked visible member.
- **Plumbing:** `ServiceCallbacks` gains `onGroupTap`, `onMergeRequested`
  and `onSplitRequested`. `FloorPlanView` gains the three optional
  callbacks. `ServiceView` passes `tableGroups` to the tool.
- **Tests**, killing M-TG-4, -5, -5b, -6 (both halves), -7, -8, -8b, -8c
  and -17c.

### Task 3 — the look (G3)

- **`PlannerView`** gains an optional `overlay` slot, painted above
  `DraftCanvas` and below the selection overlay.
- **`TableStatusPainter`:**
  - it iterates the visible tables and resolves each one's effective
    status (group over table);
  - the group caption is drawn once, under the lead, where the lead is
    chosen among members that have a top;
  - `tableGroups` and `groupStatuses` join the rebuild key and
    `shouldRepaint`; their notifiers join `ServiceView`'s repaint merge.
- **New `service/table_group_painter.dart`:**
  - the frames: a hull of the `definitionBounds` corners, offset by
    150 mm with round joins, stroked 2 px in `paper.gripMove`, no fill,
    drawn in ascending lowest-member-handle order;
  - the chips, in the overlay, filled `paper.gripMove`, with the
    `foregroundFor` ink and a one-line intrinsic layout;
  - the per-frame recipe from spec G3: a reused `Paint`, its stroke
    width set in place, everything else built at rebuild time.
- **Layers:** the underlay `Stack` (`table-group-layer` under
  `table-status-layer`) and the overlay are mounted in `ServiceView`.
- **Tests**, killing M-TG-3, -10 (pixels after `setGroupStatus` with no
  camera or document change), -11, -11b, -12 (asymmetric mirrored
  definition, the non-member beside), -13, -14, -15, -21 and -22.

### Task 4 — the toolbar (G5)

- **Buttons:** Merge (`service-merge`) and Split (`service-split`) go
  after Redo.
- **Visibility:** each is shown only when its callback is set, and
  enabled by the Task 1 rules.
- **Payloads:** `selectedTables.value` and `selectedGroup.value`.
- **Freshness:** both buttons follow the selection and `tableGroups`.
- **Tests**, killing M-TG-16, the button half of M-TG-17, M-TG-17b
  through the widgets, and M-TG-18.

### Task 5 — the demo (G6)

- **`apps/restaurant_demo`:**
  - merge, using the grow rule or a new `G<n>` (max + 1);
  - split, which also removes the group's status;
  - status routing by `selectedGroup`;
  - the groups shown in the tables list, and `onGroupTap` logged.
- **Demo test:**
  - merge two tables, then grow the group with a third;
  - give the group a status;
  - drag the group;
  - split it;
  - run under the dark platform too.

### Task 6 — the exit

- **Gates:** every gate, the engine and render packages run once, and
  `flutter build web --release` for both apps.
- **Smoke:** a Chromium smoke of the demo (merge, group status, drag,
  split) under both colour schemes. Screenshots go to
  `docs/superpowers/notes/2026-10-04-table-groups/`.
- **Results note:** `docs/superpowers/notes/2026-10-04-table-groups-results.md`
  records the gates, the M-TG table, the rulings, the screenshots
  described honestly, and the debt.
- **Spec:** an "Amended at execution" section for any accepted ruling
  that changes the spec.
- **STATUS.md** is updated.
- **Owed:** the human's look on macOS, web and a tablet.
