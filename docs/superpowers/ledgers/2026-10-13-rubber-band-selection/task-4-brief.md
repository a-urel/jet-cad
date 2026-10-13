# Brief: Task 4 of docs/superpowers/plans/2026-10-13-rubber-band-selection.md

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


### Task 4: The demo, the guide, the CHANGELOG, the specs, STATUS and the exit (RB-7)

**Files:**
- Modify: `apps/restaurant_demo/lib/main.dart` (a `floorBand` bool beside `longPressMenu`, `:403`; `floorDrag:` at `:1210`'s view; a `SwitchListTile` keyed `'floor-band'` after `'long-press-menu'`, `:1461-1466`)
- Modify: `apps/restaurant_demo/lib/demo_strings.dart` (`floorBand` in the base, English, German, Turkish: "Floor drag: select" / "Ziehen auf dem Boden: Auswählen" / "Zeminde sürükle: Seç")
- Modify: `apps/restaurant_demo/test/demo_test.dart` (the switch flips the view's `floorDrag`)
- Modify: `docs/host-guide.md` (§8's option list; a "Selecting with a band" subsection in §7 before "### Table groups"; §10 Touch)
- Modify: `tool/ci/host_probe/lib/main.dart` (every new code block)
- Modify: `CHANGELOG.md` (`## Unreleased`), `STATUS.md`
- Modify: `docs/superpowers/specs/2026-10-09-host-embedding-api-design.md` (O-4), `2026-10-03-selection-mode-design.md` (S3), `2026-10-03-restaurant-embedding-design.md` (D11, D17), `2026-10-03-touch-design.md` (T6)

- [ ] **Step 1: The demo** — the switch, its strings in three languages,
  its test (the `FloorPlanView` found by type has `floorDrag ==
  FloorPlanFloorDrag.band` after the tap, `pan` before). Run the demo's
  `flutter test`, analyze, format.

- [ ] **Step 2: The guide** — the subsection, in the guide's voice:
  `floorDrag: FloorPlanFloorDrag.band` in a `FloorPlanView(...)` block;
  the two triggers; the direction rule; groups whole, locked never,
  unnumbered selected but absent from `selectedTables`; the camera under
  `band` (two fingers, wheel, middle button); a finger near a table:
  tap selects it, drag bands; the modifier read at the press (the
  editor's band reads Shift at the release); **the change under the
  default** (a modifier mouse drag on the floor now bands, it panned
  before 0.7.0). §8 gains a `floorDrag` bullet; §10 Touch gains one
  sentence for `band`. Every block in the host probe; from the repo root
  `dart run tool/ci/check_guide.dart` passes.

- [ ] **Step 3: The CHANGELOG** — `## Unreleased` ("Nothing yet."
  replaced): "**A band selects tables in the selection mode.**
  `FloorPlanView(floorDrag: FloorPlanFloorDrag.band)` makes a one-finger
  or mouse drag on the floor draw a band — left to right the tables
  wholly inside, right to left every table touched; a group whole; a
  locked table never; a plain band replaces the selection, one with
  Shift, Ctrl or Cmd adds — and the camera then pans with two fingers,
  the wheel or trackpad and the middle button. **Changed under the
  default `pan`:** a mouse or stylus drag on the floor with Shift, Ctrl
  or Cmd held now draws a band that adds to the selection; it panned
  before." and, for `jet_cad_2d_flutter`: "`bandModeFor` and
  `SelectionBandPainter`: the selection band's direction rule and look,
  shared by the editor and the selection mode."

- [ ] **Step 4: The specs' notes** — host embedding O-4: "**Taken up**
  (2026-10-13) by the rubber-band spec
  [2026-10-13-rubber-band-selection-design.md](2026-10-13-rubber-band-selection-design.md)."
  Selection-mode S3, restaurant-embedding D11 and D17, touch T6: a dated
  line each, "(2026-10-13) Except under `floorDrag: band` (rubber-band
  spec RB-2)."

- [ ] **Step 5: STATUS** — "In flight": the rubber-band slice implemented
  on `feat/rubber-band`, reviewed, awaiting the human's merge word, then
  release 0.7.0. "Resume here" likewise. "Owed to the human": a look at
  the band (mouse and tablet, light and dark, `pan` with Shift and
  `band`); a native German and Turkish read of the demo's new switch.

- [ ] **Step 6: The exit gate, whole.** Every package and app through its
  gate (the comparison for the engine, render and GPU; `flutter test`,
  analyze and format for the rest, the planner with `--enable-vmservice`),
  `tool/ci` (`dart test`, analyze, format, `check_guide`), the host probe
  (`tool/ci/host_probe.sh file:///<absolute worktree path> <full HEAD
  sha>`) and the four old-host probes (`tool/ci/old_host_probe.sh
  v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0`). Paste each command's last lines
  into the report.

- [ ] **Step 7: Commit** — `docs: rubber-band selection in the guide, the
  CHANGELOG, the specs and STATUS; the demo's switch`.

---
