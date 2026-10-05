# Table groups fixes results

**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`3753ca4` (the table groups merge, a-urel/jet-cad#8). The spec is at
`ee553e1`; the plan and STATUS are at `cfee751`. **Spec:**
[2026-10-05-table-groups-fixes-design.md](../specs/2026-10-05-table-groups-fixes-design.md),
revision 2 (X1–X4, M-TGF-1..10). **Plan:**
[2026-10-05-table-groups-fixes.md](../plans/2026-10-05-table-groups-fixes.md),
three tasks. **Approval:** revision 2 by the human ("Onaylıyorum, planı
yaz", 2026-10-05). **Not merged.**

The slice pays two debts the table groups exit recorded:
- **F-1, the API gap.** A host can now ask which members of a group are
  selectable: `FloorPlanController.selectableMembers(groupId)`.
- **The chip at low zoom.** The group label chip now rests on the frame,
  outside it, so it covers no member's drafting at any zoom.

The document, the file format, the design mode, the engine and the render
package are unchanged. A plan with no groups behaves as before.

## Commits

| Task | Commit | Review |
|---|---|---|
| 1 `selectableMembers` and the demo's grow rule (X1, X2) | `d8d06ed` | **Approved**: no findings, 2 notes. 4 named and 7 of the reviewer's own mutants re-fired, all red |
| 2 The chip outside the frame (X3) | `7a96dc5` | **Approved**: no findings, 2 notes. 3 named and 4 of the reviewer's own mutants re-fired, all red. Only TG-L7 and TG-V2 changed, as X3 says |
| 3 The exit | this commit | — |

What landed, by task:
- **1 (`d8d06ed`).**
  - **Controller.** `FloorPlanController.selectableMembers(String groupId)
    → Set<String>`: an unmodifiable set of the numbers of the group's
    visible, unlocked, live members in the active plan. It reads the
    cached `_groupLookup` (keyed by survey, groups and layer revision), so
    it is fresh at every call. The id is trimmed; an unknown id gives the
    empty set. It works in both modes. `FloorPlanTable` stays flagless
    (14c A-2).
  - **Demo.** `DemoHomeState.mergeGroups(groups, numbers, selectable)`
    applies G6's literal rule. It grows the group when the request
    includes all of exactly one group's selectable members (that set must
    be non-empty), and makes a new `G<n>` otherwise. A grow takes the
    requested numbers out of every other group, and those groups keep
    their id, label and status. `_merge` passes `c.selectableMembers` and
    returns early on an empty request. Ruling R-C5-1 ("touches exactly one
    group") is retired.
  - **Parent spec.** In "Amended at execution", R-C5-1 is marked
    **Retired** and F-1 **closed**.
- **2 (`7a96dc5`).**
  - **Painter.** In `TableGroupPainter`, the chip's per-frame translate is
    now `(sx - p.width / 2, sy - (p.height + kGroupChipPaddingY))`. The
    prebuilt `RRect` then spans `[sy - p.height - 2·padY, sy]`, so its
    bottom edge lies on the anchor: the frame bounds' top line at their
    centre x. Only a constant changed: no new object, no per-frame
    allocation.
  - **Docs.** The painter's docs are updated. The parent spec gains an X3
    bullet, and G3's "centred on the top-most point" is marked
    superseded.

Lib diff `cfee751..7a96dc5`: 3 files, +54 −35 (the controller, the
painter and the demo's `main.dart`). There was one implementer and one
independent reviewer per task. Each reviewer worked in a detached worktree
at `.worktrees/tgf-review`, re-ran the planner, `floor_planner` and demo
gates, and re-fired the named mutants plus their own.

## Gates (Linux container, Flutter 3.47.6, `CI=true`, at `7a96dc5`)

| Package | Branch point (`3753ca4`) | Now | Δ | analyze | format |
|---|---|---|---|---|---|
| render `jet_cad_2d_flutter` | +1304 ~1 −7 | **+1304 ~1 −7** | 0 | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | +1278 | **+1283** | +5 | No issues found! | 208 files (0 changed) |
| restaurant symbols | +94 | **+94** | 0 | No issues found! | 13 files (0 changed) |
| app `apps/floor_planner` | +201 | **+201** | 0 | No issues found! | 44 files (0 changed) |
| demo `apps/restaurant_demo` | +24 | **+28** | +4 | No issues found! | 3 files (0 changed) |
| `apps/dev_harness_2d` | +82 | **+82** | 0 | No issues found! | 22 files (0 changed) |

- **Summary lines:**
  - render: `01:52 +1304 ~1 -7: Some tests failed.`
  - planner: `05:59 +1283: All tests passed!`
  - symbols: `00:03 +94: All tests passed!`
  - app: `02:32 +201: All tests passed!`
  - demo: `00:27 +28: All tests passed!`
  - harness: `00:54 +82: All tests passed!`
- **Render's 7 failures** are the standing set, unchanged:
  `text_ladder_golden_test.dart` rungs 1–5 and
  `text_lod_ladder_golden_test.dart` rungs 1–2, all
  `RenderBackend.canvas`.
- **Untouched.** `git diff 3753ca4 -- packages/jet_cad_2d_flutter
  packages/jet_cad_2d` is empty (0 bytes). So the engine, the render
  package, both allocation invariants, the Paint-identity tests and the
  goldens are as merged. The engine (`jet_cad_2d`, `dart test`) was not
  re-run, since its diff is empty. No `analysis_options.yaml` is
  committed.
- **The counts add up.**
  - Planner: 4 (Task 1: TG-C13..C16) + 1 (Task 2: TG-L11) = 5.
  - Demo: 4 (Task 1: D21..D24).
  - TG-L7 and TG-V2 were changed in place, so they add nothing to the
    count.

**Web builds** (`apps/restaurant_demo`, at `7a96dc5`):
- `CI=true flutter build web --release`: `Compiling lib/main.dart for the
  Web...  116.7s` / `✓ Built build/web`.
- For the smoke, with `--no-web-resources-cdn -o build/web_nocdn`:
  `Compiling lib/main.dart for the Web...  104.0s` / `✓ Built
  build/web_nocdn`.

## Named mutants (spec M-TGF-1..10)

Every named mutant is **killed**. Each was fired by the implementer as a
scratch edit: a `cp` backup, the mutation, a run of the named test file, a
`cp` back, then `diff` exiting 0 ("RESTORED OK"). The reviewers re-fired
the ones marked ✓r independently, in their worktree.

Abbreviations:
- P = `packages/jet_cad_floor_plan`; demo = `apps/restaurant_demo`.
- Test files:
  - C = `test/host/table_groups_controller_test.dart`;
  - L = `test/service/table_group_painter_test.dart`;
  - V = `test/host/table_groups_look_test.dart`;
  - D = `test/demo_test.dart`.

| Mutant | Task | Variants fired | Killing tests | Red evidence |
|---|---|---|---|---|
| **M-TGF-1** locked or hidden member included | 1 | a: `selectableMembers` → `visibleMembers` ✓r; b: the group's raw members | C TG-C13, TG-C14, TG-C16 | a `Expected: Set:['12', '3'] Actual: Set:['12', '3', '8']`; b `Actual: Set:['12', '3', '8', '9']` |
| **M-TGF-2** untrimmed id | 1 | `groupId` not trimmed ✓r | C TG-C14 | `Expected: Set:['12', '3'] Actual: Set:[]` |
| **M-TGF-3** decided per number, not per table | 1 | a: each number decided by its first visible table ✓r; b: a number counts only when every carrier is selectable | C TG-C15 (a: on the `lockFive: true` variant only, R-C1-1) | `Expected: Set:['12', '3', '8'] Actual: Set:['12', '3']` |
| **M-TGF-4** grows on "touches one group" (R-C5-1) | 1 | `whole` = the groups touched ✓r | D D21, D23 | D21 `Actual: {'G7': TableGroup({12, 3, 7, 20}, null)}`: grown, where a new `G8 = {3, 20}` is expected |
| **M-TGF-5** never grows / lock-blind / drops the label (**D18**) | 1 | a: `id = nextGroupId(...)` always ✓r; b: every member, locked ones included, must be requested ✓r; c: the grown group's `label:` dropped ✓r | D **D18** (a also D16, D23, D24; b also D20, D24; c also D24) | a `Expected: {'G7': TableGroup({12, 3, 8, 9, 20}, Window)} Actual: {'G7': ...({8, 9}, Window), 'G8': ...({12, 3, 20}, null)}`; c `Actual: {'G7': TableGroup({12, 3, 8, 9, 20}, null)}` |
| **M-TGF-6** vacuous grow | 1 | `s.isNotEmpty &&` dropped ✓r | D D22 | `Actual: {'G9': TableGroup({8, 9, 20, 5}, Back)}` |
| **M-TGF-7** grow keeps the number in its old group, or loses its label or status | 1 | a: the other groups keep the requested numbers ✓r; b: the remainder's `label:` dropped; c: `gone` = the changed groups, not the removed ones | D D23 (b also D20) | a `ArgumentError: … Table number "5" is in two groups, "G7" and …` (from `validateTableGroups`, as the spec predicts); b `Actual: {'G7': …({12, 3, 5}, null), 'G1': …({11}, null)}`; c `Actual: {} Which: … is missing map key 'G1'` |
| **M-TGF-8** chip still centred | 2 | translate `sy - p.height / 2` (the old one) ✓r | L TG-L7, TG-L11; V TG-V2 (premise) | `+15 -3`. TG-L11 `group 0 at 0.04 px/mm: the chip ends on or above the anchor (M-TGF-8)`, `Expected: a value less than or equal to <375.597…> Actual: <383.097…>` |
| **M-TGF-9** chip off the frame (floating) | 2 | translate `… - 2 * kGroupChipPaddingY` ✓r; own: padX for padY (a 3 px float) | L TG-L7, TG-L11; V TG-V2 (premise) | `+15 -3`. TG-L11 `the chip rests on the anchor (M-TGF-9)`, `Expected: … within <0.000001> of <375.597…> Actual: <371.597…>` |
| **M-TGF-10** `selectableMembers` stale | 1 | a: memo keyed by the id only ✓r; b: `_groupLookup` keyed by the survey only; c: the layer revision key dropped; d: memo keyed by (id, groups) | C TG-C16 (b also TG-C9, TG-C12; c also TG-C12) | a `Expected: Set:['20', '12', '5'] Actual: Set:['12', '3', '7']`; c `Expected: Set:['20', '12', '5'] Actual: Set:[]`; d `Expected: empty Actual: Set:['12', '20', '5']` |
| M-TG-22 (still killed) chips in the underlay | 2 | the chips' `CustomPaint` moved into the underlay `Stack` ✓r | V TG-V1, TG-V2 | TG-V2 on its **colour** expectation, every premise holding, at the new sample (row 292): `the chip: 0x000000, want 0x7a3fd1`, `Actual: <209>` |

**M-TGF-5 is D18** (`demo_test`). In it, `G7 = {12, 3, 8 locked,
9 hidden}` labelled `Window` grows with `20` and keeps its label. D18 is
cited, not duplicated, and was re-fired under the new rule (variants a–c
above).

## Extras

**Mutants beyond the named ones.**
- **Task 1 implementer: 4.** X2's no-op grow (strict superset required)
  and X2's empty-request guard removed (both red in D24); M-TGF-10c and
  -10d above (the layer revision key dropped; a memo keyed by id and
  groups), which go beyond the spec's two keys.
- **Task 2 implementer: 2.** padX for padY, and the anchor without the
  margin (the chip on the members' box top, inside the frame). Both are
  red in TG-L7, TG-L11 and TG-V2.

**The reviewers' own mutants, all red.**
- **Review 1: 7.**
  - the first fully-requested group wins (D17, D20);
  - the new-group write overwrites (D18, D24);
  - the subset reversed (D16, D18, D23);
  - the empty guard removed (D24);
  - the result modifiable (TG-C13);
  - empty outside the selection mode (TG-C13, TG-C16);
  - the lookup not keyed by the survey (TG-C12, TG-C16).
- **Review 2: 4.**
  - the chip horizontally off-centre by padX (TG-L7, TG-L11);
  - the anchor x from the hull's top vertex: TG-L7 moves only 0.23 px,
    TG-L11 102 px on G3's slanted pair;
  - the draw-order sort removed (TG-L5, TG-L11);
  - the rect top on the anchor, so the chip hangs into the frame (TG-L7,
    TG-L11, TG-V2).

**No survivor** in either task, so there are no "b" commits.

**Tests added.**
- **Planner +5:**
  - TG-C13 `selectableMembers` gives the visible, unlocked members, in
    both modes; a locked-and-hidden-only group gives none; the set is
    unmodifiable;
  - TG-C14 the id is trimmed; an unknown id gives the empty set;
  - TG-C15 a number carried by an unlocked and a locked table is
    selectable, in both handle orders;
  - TG-C16 freshness: the same id with new members, a design layer
    locked before a mode switch, and a raw layer edit;
  - TG-L11 at 0.04 and 0.125 px/mm, each chip's bottom is on its frame
    bounds' top line, centred, above every member's box. It has two
    groups given in non-draw order, a file duplicate and a hidden member.
- **Demo +4:**
  - D21 a host sets groups under a live selection: a new group;
  - D22 no selectable member: no grow;
  - D23 a grow takes 5 from a labelled `G1` with a status;
  - D24 a no-op grow and an empty request through
    `FloorPlanView.onMergeRequested`.

**Existing tests changed.** Only the two that X3 names:
- TG-L7: the new translate, 0.04 added to its scale loop, and its title
  (R-C2-1);
- TG-V2: table 20 moved up 8 px, with new premises; its colour
  expectation is unchanged.

The demo test's import gains `FloorPlanView`. No other expectation
changed.

## Rulings (accepted by the task reviews; ledger `.superpowers/sdd/2026-10-05-table-groups-fixes/progress.md`)

- **R-C1-1.** TG-C15 also runs a `lockFive` variant, in which the locked
  carrier comes first in handle order. Only that variant kills the "first
  table decides" mutant; the spec's literal variant alone lets it survive.
- **R-C1-2.** The empty-request guard is in `_merge`, not in the static
  `mergeGroups`, whose doc states that the numbers are not empty.
- **R-C2-1.** TG-L7's title is reworded to X3's placement, since the old
  title stated the superseded one.
- **R-C2-2.** M-TGF-8/9 at 0.125 px/mm live in a new TG-L11, which keeps
  the change to TG-L7 minimal.
- **R-C2-3.** TG-V2 gains a premise that its reference pixel is clear of
  the chip, which closes a vacuous pass.
- **Review notes (no action).**
  - Review 1:
    - no test covers a host-only grow that empties another group; it goes
      through code shared with the new-group path, which D17 and D20 pin;
    - a direct empty `mergeGroups` call gives a memberless group, which
      `setTableGroups` refuses.
  - Review 2:
    - TG-L11's per-corner check is implied by its bottom check, and is
      kept as X3's statement;
    - under M-TGF-8/9, TG-V2 goes red on a premise; its pixel
      expectation belongs to M-TG-22.

## Chromium smoke (Task 3)

**Setup.**
- **Build.** The smoke used the `--no-web-resources-cdn` build above
  (`build/web_nocdn`), as the earlier exits did: the release build
  fetches CanvasKit from `www.gstatic.com`, which this container's proxy
  blocks for Chromium.
- **Serving and browser.**
  - The build was served with `python3 -m http.server` and driven by the
    table groups exit's Playwright driver (`drive.js`, reused).
  - Chromium came from `/opt/pw-browsers`, in a 1440×900 context at device
    pixel ratio 1, locale `en-US`, with `colorScheme: 'light'` and one
    `'dark'` repeat.
  - There were no page errors and no external requests.
- **Driving.** Each run: Service; then `1,2` in "Table numbers", Select
  and Merge; then `1,3`, Select and Merge (a grow); then Bill.
  - **The default fit:** no zoom, about 0.04 px/mm. At that scale the
    150 mm frame margin is about 6 px.
  - **The closer zoom:** seven wheel steps, about 0.08 px/mm. Table 1 to
    table 2 is 186 px there, against 95 px at the fit.

The screenshots are in
[2026-10-05-table-groups-fixes/](2026-10-05-table-groups-fixes/). What
each one shows (pixel rows sampled from the PNGs):

- **`demo_fit_1_merge.png`.** Default fit, after the merge of `1,2`.
  - The purple frame (`#7A3FD1`) encloses tables 1 and 2 and their
    chairs.
  - The `1+2` chip sits on the frame's top edge, above it, centred on
    the frame: between the two tables, where nothing is drawn anyway.
    Sampled at x = 150, the chip fills rows 348–363 and the frame stroke
    is rows 364–365, so the chip's bottom meets the stroke.
  - The panel reads `Groups: G1: 1+2`; the log reads `Merged {1, 2} as
    G1`.
- **`demo_fit_2_grow.png`.** Default fit, after `1,3` → Merge.
  - G1 grew to the row 1–2–3; the log reads `Merged {1, 2, 3} as G1`.
  - The `1+2+3` chip is now centred over **table 2**, the case the old
    placement got wrong. It sits wholly above the frame: table 2's upper
    chairs are fully visible below the frame line, with no purple on
    them.
- **`demo_fit_3_bill.png`.** The same, after Bill.
  - The three tops are filled Bill, and one `Bill` caption sits under
    table 1, the lead.
  - **The chip is clear of the chairs.** Sampled down x = 190–214 (over
    table 2): the chip fills rows 348–363, then the frame stroke rows
    364–365, then 3 white rows (366–368), then table 2's upper chair
    edges at rows 369–373.
  - The `Bill` caption still falls across table 1's lower chairs and is
    hard to read. That is the pre-existing low-zoom caption placement
    (14c), not the chip.
- **`demo_fit_before_after_crop.png`.** A 3× crop of the group at the
  default fit.
  - **Top:** the table groups exit's `demo_light_fit_3_bill.png`, at
    `9c09121`. The chip straddles the frame line and covers the top of
    table 2's upper chairs.
  - **Bottom:** this build. The chip sits on the frame line and every
    chair is visible.
  - Everything else in the crop is the same.
- **`demo_fit_dark_3_bill.png`.** The same frame with `colorScheme:
  'dark'`.
  - The app bar, the service bar and the panel are dark, with readable
    text.
  - The paper stays White, so the inside of the paper is
    **pixel-identical** to the light run's. A difference over x 16–580,
    y 290–687 found 0 differing pixels. The colours follow the paper.
- **`demo_zoom_3_bill.png`.** The closer zoom, for comparison (about
  0.08 px/mm), after merge, grow and Bill.
  - The chip, at its fixed screen size, is now small against the group.
  - It sits on the frame's top edge above table 2. Sampled at x = 240,
    it fills rows 268–284, the frame stroke is at 284–285, and the
    chairs start at row 294, about 9 px below.
  - The frame's left edge is about 16 px from the canvas edge. The
    `Bill` caption under table 1 is small but legible here.

**Nothing looked broken.** At both zooms the chip rests on the frame,
above it, and covers no member. The merge, grow and Bill flow behaves as
before under the new grow rule (both logs read "as G1"), and the dark
scheme changes only the chrome. **The weak spots seen:**
- **The chip touches the frame stroke.** At the fit its bottom meets the
  2 px stroke, so the stroke and the chip read as one shape. This is what
  X3 specifies (the bottom on the bounds' top line), and it reads as a
  tab on the frame.
- **The `Bill` caption** on table 1's lower chairs at the fit
  (pre-existing, 14c).
- **The small chip text** next to the large table numbers when zoomed
  (unchanged).

Not exercised: a group at the top of the view (the clipped chip), a
slanted group (the floating chip), Blueprint, and a drag. Those are
unchanged by this slice or listed as accepted risks below.

## Debt

- **Frames jump on release during a drag** (G3, R-17; seen at the table
  groups exit). This slice does not change it.
- **A hull may enclose non-members.** Members far apart give a frame
  spanning the floor between them, and a non-member inside it is not
  tinted (table groups Risks).
- **The chip may float above a slanted frame** (spec Risks). On a
  diagonal group, the frame at the bounds' centre x lies below the
  bounds' top line, so the chip sits a little above the frame instead of
  on it. It still covers no member. Review 2's top-vertex mutant shows
  the size of the effect: 102 px in TG-L11's slanted G3 at 0.125 px/mm.
- **The chip can be clipped at the canvas top edge** (spec Risks). A
  group at the top of the view puts its chip above the canvas, where it is
  clipped; panning shows it. This is accepted.
- **Carried over from the table groups exit, unchanged:**
  - `selectedGroup` goes stale after a raw layer edit;
  - ≥3 identical hull points draw no frame;
  - the low-zoom status caption falls on the chairs (14c);
  - the `shouldRepaint` additions are unpinned by choice.
- **Closed by this slice:**
  - **F-1.** `selectableMembers` closes it. The locked/hidden-only
    remainder group can still be cleared only by the POS. That is by
    design now: it never grows (M-TGF-6) and is not selectable.
  - **The chip at low zoom covering member drafting.**
- **Not run here:** the macOS build, and the engine's `dart test` (its
  diff is empty).

## Owed

- **The human's look on macOS, web and a tablet, never simulated** (spec
  exit gate 5):
  - the chip on the frame at the default fit and zoomed in;
  - a grow under the literal rule, with a locked or hidden member in the
    group;
  - both themes, White and Blueprint.

  The screenshots above are evidence for that look, not a substitute.
- **The merge decision.**
