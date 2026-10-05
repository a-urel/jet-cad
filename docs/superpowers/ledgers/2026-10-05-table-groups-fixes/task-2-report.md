# Task 2 report — the chip outside the frame (X3)

Status: done. Commit `7a96dc5`, "fix(table-groups): Task 2 — the chip sits on the frame, outside it" (on `d8d06ed`; not pushed).

## Files changed

- packages/jet_cad_floor_plan/lib/src/service/table_group_painter.dart
- packages/jet_cad_floor_plan/test/service/table_group_painter_test.dart
- packages/jet_cad_floor_plan/test/host/table_groups_look_test.dart
- docs/superpowers/specs/2026-10-04-table-groups-design.md

The engine and the render package are untouched:
`git diff d8d06ed -- packages/jet_cad_2d packages/jet_cad_2d_flutter`
has 0 lines.

## What was built

- **Painter** (`table_group_painter.dart:425`): the chip's per-frame
  translate is now `translate(sx - p.width / 2, sy - (p.height +
  kGroupChipPaddingY))`. The rebuild-time `RRect`
  `[-padX, -padY, w + padX, h + padY]` then spans `[sy - h - 2·padY, sy]`
  on screen: its bottom edge is on the anchor (the frame bounds' top line
  at their centre x). Only the constant changed. There is no new object,
  field or per-frame allocation, and the `debugAllocations` /
  `debugRebuilds` paths are untouched. A one-line comment at the translate
  states why.
- **Docs in the painter:** the `_Group` anchor doc (~:172-175) and the
  class doc (~:196-199) now say "centred on the frame bounds' centre x with
  its bottom edge on their top line (fixes X3)".
- **Parent spec,** "Amended at execution": a new **X3** bullet after
  Task 1's F-1 bullet. G3's "centred on the top-most point" is marked
  superseded, citing the fixes spec X3. Task 1's R-C5-1 and F-1 edits are
  untouched.

## Tests

The deliberate X3 changes (TG-L7, TG-V2) and one new test.

- **TG-L7** (`table_group_painter_test.dart`):
  - Expectation: `dy` is now `closeTo(sy - (p.height + kGroupChipPaddingY), 1e-6)`.
  - The scale loop is now `[0.04, 0.06, 0.11]`.
  - The `dx`, `RRect`, paint and hiding assertions are unchanged.
  - The title changed because the old one stated the superseded
    placement. It is now "TG-L7 the chip is centred on the frame bounds'
    centre x, its bottom edge on their top line (fixes X3), filled
    gripMove; it is skipped when the frame is narrower on screen than it
    (G3)".
- **TG-L11 (new)**, "M-TGF-8, M-TGF-9: at 0.04 and 0.125 px/mm each
  chip's bottom edge lies on its frame bounds' top line, centred on their
  centre x, above every member's box (fixes X3)".
  - Fixture: the GroupSpy seam (translations and `rrects`) over
    `groupedPlan(duplicate: true)` with the off-origin camera, turned and
    mirrored tables, and two groups:
    - `G7 = {7, 12}`, labelled `Window`;
    - `G3 = {3, 20, 9}`: 3 is carried by two tables (a file duplicate)
      and 9 is hidden.
  - The map is given in non-draw order (G3 first). The chips pair by draw
    order: G7 (lowest handle 12) before G3.
  - The anchor is computed independently from `cornersOf` over the
    visible members.
  - For each chip, at 0.04 and 0.125 px/mm, it asserts:
    - the bottom `t.dy + r.bottom` is ≤ the anchor's screen y + 1e-6
      (M-TGF-8);
    - the bottom is `closeTo(sy, 1e-6)` (M-TGF-9);
    - the rect's horizontal centre is the anchor's screen x;
    - every member box corner's screen y is ≥ bottom + margin·scale (no
      member covered).
- **TG-V2** (`table_groups_look_test.dart`):
  - **Fixture:** table 20 moved up by `kChairRowsUp = 8` px
    (`kChairRowsUp / pxPerMm` = 64 mm) via the new constant: its
    placement is `placementAt(kAnchorX, kAnchorY + kChairRowsUp / pxPerMm + 750, 0)`.
    Its chair line now lies on row 292 (layer-local; pixel centre
    292.5). The chip spans `[285.5, 300.5]` there.
  - **Premises:**
    - the chip's bottom (`t.dy + rrect.bottom`) is the anchor row centre,
      `kAnchorRow + 0.5`;
    - the chair row is `o.dy + kAnchorRow - kChairRowsUp`;
    - all four inset corners of the sampled pixel `(sx, ay)` are inside
      the chip's `RRect`, shifted to global pixels (so the rounded corners
      are excluded too);
    - the row lies strictly between `chip.top` and `chip.bottom`;
    - **new:** the reference pixel `ax - 22` is clear of the chip. Without
      that premise, the "chair line is drawn" premise could pass on the
      chip's own colour.
  - **Expectation:** unchanged (the chip's colour at `(sx, ay)`).
  - The header comment and `lookController`'s doc are updated.
- **TG-V3** and every other look test pass **unedited** with table 20
  moved (TG-V3 reads `insideTop(20)`).

## Mutant table

Each mutant was a scratch edit through
`scratchpad/tgf-task2/mut.sh`. It backs the file up, applies the edit,
runs
`flutter test test/service/table_group_painter_test.dart test/host/table_groups_look_test.dart`,
`cp`s the backup back and `diff`s it. Every mutant printed "RESTORED OK".
Outputs are `scratchpad/tgf-task2/<name>.out` and `<name>.diff`.

| Mutant | Site | Change | Red | Excerpt |
|---|---|---|---|---|
| M-TGF-8 chip still centred | painter :425 | `sy - p.height / 2` (the old translate) | TG-L7, TG-L11, TG-V2 (`+15 -3`) | TG-L11: `Expected: a value less than or equal to <375.59737514293204>  Actual: <383.09737414293204>` `group 0 at 0.04 px/mm: the chip ends on or above the anchor (M-TGF-8)` |
| M-TGF-9 chip floating | painter :425 | `sy - (p.height + kGroupChipPaddingY) - 2 * kGroupChipPaddingY` | TG-L7, TG-L11, TG-V2 (`+15 -3`) | TG-L11: `Expected: a numeric value within <0.000001> of <375.59737414293204>  Actual: <371.59737414293204>` `group 0 at 0.04 px/mm: the chip rests on the anchor (M-TGF-9)` |
| M-TG-22 chips in the underlay | service_view.dart :311-336 | the chips' `CustomPaint` moved into the underlay `Stack` after the status layer, `overlay:` removed | TG-V1, TG-V2 (`+16 -2`) | TG-V2: `Expected: a value less than or equal to <3>  Actual: <209>` `the chip: 0x000000, want 0x7a3fd1`, at the new sample (row 292). The premises all held. |
| own: padX for padY | painter :425 | `sy - (p.height + kGroupChipPaddingX)` (a 3 px float) | TG-L7, TG-L11, TG-V2 (`+15 -3`) | TG-L11: `Expected: ... within <0.000001> of <375.59737414293204>  Actual: <372.59737414293204>` `(M-TGF-9)` |
| own: anchor without margin | painter :343 | `_Group` anchorY `maxY` instead of `maxY + kGroupFrameMarginMm` (chip on the members' box top, inside the frame) | TG-L7, TG-L11, TG-V2 (`+15 -3`) | TG-L11: `Expected: a value less than or equal to <375.59737514293204>  Actual: <381.59737414293204>` `(M-TGF-8)` |

Under M-TGF-8 and M-TGF-9, TG-V2 goes red on its first premise (the
chip's bottom at `kAnchorRow + 0.5`: `Actual: <308.0>` / `<296.5>`). Its
colour expectation is reserved for M-TG-22.

## Gates (Flutter 3.47.6, `CI=true`, real output tails; scratchpad/tgf-task2/gate-*.out)

| Package | test | analyze | format |
|---|---|---|---|
| packages/jet_cad_floor_plan | `06:22 +1283: All tests passed!` (Task 1 +1282, plus TG-L11) | No issues found! | 208 files, 0 changed |
| apps/floor_planner | `07:13 +201: All tests passed!` | No issues found! | 44 files, 0 changed |
| apps/restaurant_demo | `01:52 +28: All tests passed!` | No issues found! | 3 files, 0 changed |
| packages/jet_cad_restaurant_symbols | `00:03 +94: All tests passed!` | No issues found! | 13 files, 0 changed |
| apps/dev_harness_2d | `00:55 +82: All tests passed!` | No issues found! | 22 files, 0 changed |
| packages/jet_cad_2d_flutter | not re-run (the plan re-runs it at the exit); render diff since `d8d06ed` is empty | | |

The first planner run hit my 10-minute background limit: three packages
ran in parallel and it was killed mid-run. Those partial lines read "Bad
state: Cannot add event while adding stream", the artefact of the kill.
I re-ran the planner alone, and the counts above come from that run.

## Proposed rulings

- **R-C2-1 — TG-L7's title is reworded.** The old title, "the chip is
  centred on the frame's top-most point", states the superseded placement.
  The new one names X3's placement. The body change is the deliberate
  expectation change and the 0.04 scale.
  - Cost if wrong: a reviewer who reads "only the expectation" strictly
    wants the old title back. The title would then be false, with no
    behavioural effect.
- **R-C2-2 — M-TGF-8/9 at 0.125 live in a new test, TG-L11.** TG-L7's
  loop gained only the spec's 0.04. 0.125 was not added there, to keep the
  deliberate change to TG-L7 minimal. TG-L11 carries both scales for
  M-TGF-8/9, with two groups and a no-member-covered check.
  - Cost if wrong: none functional. The mutants are killed by TG-L7 at
    0.04 as well.
- **R-C2-3 — TG-V2 gained a premise the spec did not name.** The
  reference pixel `ax - 22` is now asserted clear of the chip. The
  existing "chair line is drawn" premise reads non-white, so a chip
  covering that pixel would satisfy it vacuously. Only premises were
  added; the colour expectation is unchanged.
  - Cost if wrong: one extra `expect`.

## Found, not fixed

- TG-V2's first premise (the chip's bottom at the anchor row) means
  M-TGF-8/9-style mutants turn TG-V2 red on a premise, not on pixels.
  That is intended: its pixel expectation is owed to M-TG-22, which leaves
  every premise holding and fails on the colour.
- The painter class doc still says each frame "translates to each chip's
  anchor". That stays accurate: the translate is derived from the anchor.

## Where the reviewer should look hardest

- TG-V2's geometry. The test font gives the chip `p.height = 11`, so the
  chip spans layer rows `[285.5, 300.5]` and the chair line is at 292.5:
  6.5 px from the top, 8 px from the bottom, so beyond the 4 px corner
  radius. Every pixel-level claim is asserted as a premise, not just
  argued.
- TG-L11 pairs anchors with chips by draw order (G7, then G3). If the
  draw order were wrong, the anchors would mismatch and the test would go
  red. That is a feature, but check that the pairing assumption is right
  (12 has a lower handle than 3 in `groupedPlan`).
