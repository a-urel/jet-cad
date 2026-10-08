# Plan — framing and focus by table number (zones)

**Spec:** [2026-10-08-zone-focus-design.md](../specs/2026-10-08-zone-focus-design.md),
revision 2 (`0b0d661`). Revision 1 was reviewed independently (*Approve
with fixes*, V-1 to V-19); every finding is folded in, with the
controller's rulings on Q-Z2, Q-Z6, V-2, V-3 and V-9.

**Started** on the human's ruling of 2026-10-08: a zone is the table's
attribute in the host's database; jet-cad frames tables by number and
optionally fades the others (spec header). The last jet-cad prerequisite
of Monépro's spec 103 §10.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `14616d9`,
plus the branch's docs commits `e0a728d` (STATUS: the tag), `0cfc87e`
and `0b0d661` (the spec) and this plan's.

**Ledger:** `.superpowers/sdd/2026-10-08-zone-focus/`.

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`) **and every golden
  stay untouched.** The engine and the renderer are not edited (I-1).
- **The standing sets stay exactly as they are:** engine 2, render 7
  plus 1 skip. Each package's run is compared with
  `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg>
  <run.json>` (the run from `test --file-reporter json:<run.json>`), as
  CI does.
- **Every task ends green** in every package it touches, and in every
  package whose tests read what it changed:
  - `packages/jet_cad_floor_plan`, `apps/restaurant_demo`,
    `apps/floor_planner`: `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_2d` and `packages/jet_cad_2d_flutter`: untouched,
    run once per task through the standing comparison;
  - `tool/ci`: `dart test`, analyze, format, and
    `dart run tool/ci/check_guide.dart`, whenever the guide or the probe
    moves.
- **Existing tests pass unedited** (I-6). A test that has to change is a
  finding: record it in the task's report.
- **Fixtures follow the spec's rule** (CLAUDE.md's testing bar; 14c R-2):
  a hand-made servable definition with an asymmetric top, turned 37°, one
  copy mirrored, 40 m off the origin; a non-identity camera (panned,
  0.37 px/mm) before every call; hidden and locked layers (`L`); a
  duplicated number, `B4`, an unnumbered table; a TEXT and a room named
  `7`, and a table numbered ` 7 `. Expectations are computed in the test
  by the forward transform; doubles use `closeTo`, relative 1e-12.
- **Each named mutant is applied, seen red and reverted**, and its result
  recorded (Ruling 49/50). Every mutant M-Z1 to M-Z43 belongs to exactly
  one task below.
- **Never `git checkout` a file to revert it.** Copy it aside, or use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.** Check `git status` before
  each commit.

## Tasks

### Task 1 — the candidate rule and the framing (Z0–Z9)

**Builds:**
- **Z0:** the static `TablePicker.candidatesOf(document, {boxes,
  leaves})`, extracted from `_build` (`table_picker.dart:165-194`), with
  the four-finite-corners rule added; the picker uses it. Its existing
  tests stay unedited.
- **Z3:** `lib/src/host/table_fit.dart`: `kTableFitMarginMm`,
  `kTableFitMinSpanMm`, the pure `frameTables(Aabb2, Size)` (margin,
  minimum span, `ViewportTransform.fit`, clamp about the centre).
- **Z1, Z2, Z4–Z6, Z8, Z9** in `FloorPlanController`:
  `bool fitToTables(Set<String>)`; the fit target beside `_fitPending`;
  `fitToView` sets it to null; `load`/`newPlan` reset it; the
  `@internal framingFor(Size)` (Z2's four-corner bound over Z0's
  candidates of the active plan, resolved at call time; a fresh box cache
  and one `leavesByOwner` scan per call). No settle, no notify.
- **Z7:** `PlannerView.framing` (optional), `_fit` reading `_size` when
  its post-frame callback runs; `PlannerShell` forwards `framing`;
  `FloorPlanView` passes `c.framingFor` to the shell; `ServiceView`
  passes it to its `PlannerView`.

**Tests** (`test/host/table_fit_test.dart`, `controller_test`,
`view_test`, `seams_test`, `test/service/table_picker_test.dart`):
**M-Z1, M-Z2, M-Z3, M-Z4, M-Z5, M-Z6, M-Z7, M-Z8, M-Z9, M-Z10, M-Z11
(framing half: I-2's counters after `fitToTables`), M-Z12, M-Z13, M-Z14,
M-Z15, M-Z30, M-Z31, M-Z32, M-Z33, M-Z40, M-Z41** — 21. The picker's
candidate list is also pinned plainly on the non-finite fixture; the
mutant that spans pick, framing and veil (M-Z43) is Task 2's.

**Gates:** planner, floor planner, demo; engine and render through the
standing comparison.

### Task 2 — the focus and the veil (Z10–Z13, Z15–Z17)

**Builds:**
- **Z10:** `setTableFocus(Set<String>?)` and `tableFocus` on the
  controller: trimmed, blanks dropped, copied unmodifiable; `{}` and
  `{''}` are a focus with no table; every call replaces and notifies;
  kept across `setMode`, `load`, `newPlan`, `resetLayout`,
  `restoreServiceLayout`; disposed with the controller.
- **Z12, Z13, Z16, Z17:** `lib/src/service/table_focus_painter.dart`:
  `kTableFocusVeilAlpha`; Z0's candidates' quads, counter-clockwise by
  the determinant's sign; the faded union minus the focused union by one
  `Path.combine(PathOperation.difference, …)` per rebuild; the rebuild
  key (state id, layer revision, focus identity); a paper change
  recolours the `Paint` only (RGB, alpha ignored); one reused
  `Float64List(16)`; `debugAllocations`; nothing drawn or built with a
  null focus.
- **Z11, Z13's wiring:** in `ServiceView` only, the overlay becomes a
  `Stack` (veil, then chips), keyed `table-focus-layer`; its repaint
  merges the camera, `tableFocus`, `_changed`, `_paper`.
- **Z15:** no change to the tool, the picker, `select` or Merge; the
  tests prove it.

**Tests** (`test/service/table_focus_painter_test.dart`, `view_test`,
`controller_test`): **M-Z16, M-Z17, M-Z18, M-Z19, M-Z20, M-Z21, M-Z22,
M-Z23, M-Z25, M-Z26, M-Z27, M-Z34, M-Z35, M-Z36, M-Z37, M-Z39, M-Z43** —
17. Pixel tests render through a `PictureRecorder` under `runAsync`
(14c R-10); M-Z21 uses 14c R-3's structural recording canvas
(`table_status_painter_test.dart:145`).

**Gates:** planner, demo; engine and render through the standing
comparison.

### Task 3 — groups, `FloorPlanTable.visible` and the demo (Z14, Z24, Z22)

**Builds:**
- **Z14:** `TableGroupPainter` takes `tableFocus`; its identity joins the
  rebuild key (`table_group_painter.dart:378-387`); `tableFocus` joins
  `_groupRepaint` (`service_view.dart:200-201`). A group with no focused
  visible member: one prebuilt faded frame `Paint` (alpha × (1 −
  `kTableFocusVeilAlpha`)); its chip as today, then its `RRect` again
  with the veil's paint. Straddling groups and the lead rule unchanged.
- **Z24:** `FloorPlanTable({…, bool visible = true})`, in `==`,
  `hashCode`, `toString`; the controller sets it from the table's layer.
  `tables` keeps hidden tables; `numberingWarnings` unchanged.
- **Z22:** `apps/restaurant_demo`: the Salon's zones A = 1–5, B = 6–7,
  C = 8–11 kept per `Area`; the zone `SegmentedButton` (*All*, A, B, C)
  and the "Fade the others" switch, shown only for an area with zones,
  calling the same code as the spec's `showZone`/`showAllZones`; the
  three demo strings in en, de and tr.

**Tests** (`test/service/table_group_painter_test.dart`, `controller_test`,
`barrel_test`, `apps/restaurant_demo/test/demo_test.dart`): **M-Z24,
M-Z38, M-Z42, M-Z29** — 4. M-Z42's recipe clause runs the spec's
`unplacedTables` body verbatim in a planner test; Task 4 puts the same
body in the probe.

**Gates:** planner, demo, floor planner; engine and render through the
standing comparison.

### Task 4 — docs and the exit (the controller's)

- **Host guide (Z20):** "### Zones: framing and focus" at the end of
  § 7: framing, none found, the last request, `load`, the focus, the
  inert recipe in prose, the number rules of 14a T4, the straddling
  group, `visible` and the unplaced recipe; marked *Unreleased*. § 4's
  fit sentence gains `fitToTables`.
- **Host probe (Z21):** `showZone`, `showAllZones`, `unplacedTables` in
  `tool/ci/host_probe/lib/main.dart`, called from app-bar actions; no
  other fenced block. `check_guide` green. **M-Z28** — 1: edit the
  probe's `showZone`, `check_guide.dart` exits 1; restore.
- **CHANGELOG (Z23):** Unreleased gains `fitToTables`,
  `setTableFocus`/`tableFocus`, `FloorPlanTable.visible`; no schema
  change; no planner string.
- **Results note** `docs/superpowers/notes/2026-10-08-zone-focus-results.md`:
  every mutant and its result, the gates, what was found, and what is
  owed.
- **STATUS** and **the roadmap's row 14** (`roadmap/00-README.md:267`):
  the zones entry with spec, plan and results.
- **Every gate**, `tool/ci` included, with the standing comparison.
- **Both web builds** (`apps/floor_planner`, `apps/restaurant_demo`).
- **The web smoke check (R-1)**, in Chromium. `apps/floor_planner` has
  no `FloorPlanController` and no selection mode, so the veil cannot be
  shown there. On the floor planner's web build: open the sample, draw
  and pan with no console error. On the demo's web build: the Salon in
  Service, zone B with "Fade the others", so the veil is drawn through
  CanvasKit's `Path.combine`; it is seen, with no console error.
- The host probe locally: `tool/ci/host_probe.sh "file://$PWD" <sha>`
  (clear `~/.pub-cache/git/cache/jet-cad-*` first).

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-Z1–M-Z15 (M-Z11 framing), M-Z30–M-Z33, M-Z40, M-Z41 | 21 |
| 2 | M-Z16–M-Z23, M-Z25–M-Z27, M-Z34–M-Z37, M-Z39, M-Z43 | 17 |
| 3 | M-Z24, M-Z29, M-Z38, M-Z42 | 4 |
| 4 | M-Z28 | 1 |

## Exit gate

- Task 4 green: every gate, the standing sets exact, both web builds, the
  smoke check, the probe locally and in CI.
- Every named mutant M-Z1 to M-Z43 seen red and recorded.
- The independent review applied.
- **Owed to the human:** Q-Z3, a look on a device (tablet and terminal,
  light and dark): the 500 mm margin, the 3 m minimum span, the 0.6
  veil, R-5's captions and the chip room at low zoom; the German and
  Turkish read of the three demo strings.
- **Owed to Monépro** (its phase-2 spec): Q-Z1, a public world-to-screen
  mapping or not; Q-Z4, D21's link is `pos_tables.code` under 14a T4.
- **The merge into `main` happens on the human's word.**
