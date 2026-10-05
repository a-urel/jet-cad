# Table groups results

**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`4490cd9`; the plan starts at `eed5856`. **Spec:**
[2026-10-04-table-groups-design.md](../specs/2026-10-04-table-groups-design.md),
revision 2, with "Amended at execution" added at Task 6. **Plan:**
[2026-10-04-table-groups.md](../plans/2026-10-04-table-groups.md), six
tasks. **Approval:** revision 2 by the human ("Onaylıyorum, planı yaz",
2026-10-04). **Not merged.**

A POS can now link tables into **groups** at runtime, outside the
document:
- `setTableGroups` (keyed by a POS group id), `setGroupStatus` and
  `selectedGroup` on the controller; `onGroupTap`, `onMergeRequested` and
  `onSplitRequested` on `FloorPlanView`;
- in the selection mode a group shows as a purple frame round its members
  with one label chip, and a group status overrides the members' own;
- a tap, a long press and a drag act on the whole group; selecting by
  number expands to the group;
- Merge and Split on the service bar only ask the host;
- the demo merges, grows, splits and sets group statuses.

The document, the file format, the design mode, the engine and the
render package are unchanged. A plan with no groups behaves as before.

## Commits

| Task | Commits | Review |
|---|---|---|
| 1 Model and controller (G1, G2, G4 selection, G5 rule) | `638048b`, `f98532f` (1b) | **Approved**, 2 minor: Merge's group-id unit tag unpinned (R-3 survived; 1b test, red); `selectedGroup`'s notification order documented (1b) |
| 2 Select, tap, move (G4) | `c5eb454`, `e85ded9` (2b) | **Approved**, 1 minor: the drag start's and long press's stale-map guards unpinned (R-X1, R-X2 survived; 2b TG-G12..14, both red) |
| 3 The look (G3) | `b464204`, `9d80fc7` (3b) | **Approved**, 1 minor: frame order by the highest member survived TG-L5 (O2; 3b interleaves the groups, red); 3 notes |
| 4 Toolbar (G5) | `5261b9c`, `cda29b7` (4b) | **Approved**, 2 minor: R-C4-1's gap and the flags' dispose unpinned (M1, M2 survived; 4b TB6, TB7, both red) |
| 5 Demo (G6) | `eecc823`, `9c09121` (5b) | **Approved**, 2 minor: Free on a group and R-C5-4 unpinned (R1..R3 survived; 5b D16 addition and D20, all red); 3 notes. The first review run was lost to a container restart and re-run clean |
| 6 The exit | this commit | — |

Every "b" commit is test-only except `f98532f`, which also adds one doc
paragraph to `selectedGroup`. Each was written by the controller from the
reviewer's probe, its mutant re-fired red and the file restored.

What landed, by task:
- **1 (`638048b`, `f98532f`).** `TableGroup` (trimmed members, a 24-cluster
  label, value equality); `service/table_groups.dart`:
  `validateTableGroups` (overlap, blank and colliding ids, empty groups
  throw before anything is assigned), `TableGroupLookup` (visible and
  selectable members, the Split rule), `mergeQualifies` (units),
  `tableNumberOrder` / `inLeadOrder` (numeric when all digits, never
  `int.parse`). The controller: `setTableGroups`, `setGroupStatus`,
  `selectedGroup`, and `_select` expanding numbers to groups in the
  selection mode only, through the existing live / visible / unlocked
  filter.
- **2 (`c5eb454`, `e85ded9`).** `TableSelectTool` takes `groups`: a plain
  tap selects the group's selectable members; a modifier tap and a long
  press add or remove the whole group in one `replace`; `onTableTap` then
  `onGroupTap`; a locked member reports both and selects nothing. A drag
  moves every involved group's selectable members in one `Move`, and is
  spent (nothing replaced, nothing moved) when an involved group has a
  locked visible member. The lookup is keyed on the picker's candidates
  and the groups map.
- **3 (`b464204`, `9d80fc7`).** `TableGroupPainter` with a frames layer (the
  underlay, under the status fills) and a chips layer (the new
  `PlannerView.overlay`, above `DraftCanvas`): convex hull of the members'
  `definitionBounds` corners, offset 150 mm with exact round joins, 2 px in
  `paper.gripMove`; the chip centred on the frame's top-most point, hidden
  when wider than the frame. The status painter iterates the tables,
  resolves the group status first and captions the lead only.
- **4 (`5261b9c`, `cda29b7`).** Merge (`Icons.merge_type`) and Split
  (`Icons.call_split`) after Redo, shown only with their callbacks, their
  flags following `selectedTables`, `tableGroups` and `selectedGroup`.
- **5 (`eecc823`, `9c09121`).** The demo: `mergeGroups` (grow the one
  touched group, else a new `G<n>`), Split, group statuses through
  `selectedGroup`, a Groups line and the `onGroupTap` log.

Lib diff `eed5856..9c09121`: 11 files, +1376 −70 (10 in
`jet_cad_floor_plan`, plus the demo's `main.dart`). One implementer and one
independent reviewer per task; each reviewer worked in a detached
worktree, re-ran the gates (review 5 only the demo's and the planner's
analyze, as its brief scoped) and re-fired a sample of the named mutants
plus their own.

## Gates (Linux container, Flutter 3.47.6, `CI=true`, at `9c09121`)

| Package | Branch point (`0e0ae65` code) | Now | Δ | analyze | format |
|---|---|---|---|---|---|
| render `jet_cad_2d_flutter` | +1304 ~1 −7 | **+1304 ~1 −7** | 0 | No issues found! | 218 files (0 changed) |
| planner `jet_cad_floor_plan` | +1213 | **+1278** | +65 | No issues found! | 208 files (0 changed) |
| restaurant symbols | +94 | **+94** | 0 | No issues found! | 13 files (0 changed) |
| app `apps/floor_planner` | +201 | **+201** | 0 | No issues found! | 44 files (0 changed) |
| demo `apps/restaurant_demo` | +18 | **+23** | +5 | No issues found! | 3 files (0 changed) |
| `apps/dev_harness_2d` | +82 | **+82** | 0 | No issues found! | 22 files (0 changed) |
| engine `jet_cad_2d` (`dart test`) | +1241 −2 | **+1241 −2** | 0 | — | — |

- **Summary lines:** render `01:08 +1304 ~1 -7: Some tests failed.`;
  planner `03:52 +1278: All tests passed!`; symbols `00:02 +94: All tests
  passed!`; app `01:34 +201: All tests passed!`; demo `00:17 +23: All tests
  passed!`; harness `00:38 +82: All tests passed!`; engine `00:22 +1241 -2:
  Some tests failed.`
- **Render's 7 failures** are the standing set, unchanged:
  `text_ladder_golden_test.dart` rungs 1–5 and
  `text_lod_ladder_golden_test.dart` rungs 1–2, all `RenderBackend.canvas`.
- **The engine's 2 failures** are the standing pair in
  `generate_document_test.dart` ("the default document is the one Plan 2
  measured, byte for byte"; "both text fractions default to zero and change
  nothing").
- **Untouched.** `git diff 4490cd9 -- packages/jet_cad_2d_flutter
  packages/jet_cad_2d` is empty (0 bytes), so the engine, the render
  package, both allocation invariants, the Paint-identity tests and the
  goldens are as merged. No `analysis_options.yaml` is committed.
- **The counts add up.** Planner: 27 (T1) + 11 (T2) + 3 (2b) + 17 (T3) + 5
  (T4) + 2 (4b) = 65. Demo: 4 (T5) + 1 (5b) = 5.

**Web builds** (`CI=true flutter build web --release`, at `9c09121`):
- `apps/floor_planner`: `Compiling lib/main.dart for the Web... 83.1s` / `✓ Built build/web`
- `apps/restaurant_demo`: `Compiling lib/main.dart for the Web... 61.0s` / `✓ Built build/web`
- For the smoke, `apps/restaurant_demo` with `--no-web-resources-cdn -o
  build/web_nocdn`: `Compiling lib/main.dart for the Web... 62.5s` / `✓
  Built build/web_nocdn`.

## Named mutants (spec M-TG-1..22)

Every named mutant is **killed**, except M-TG-19, the invariant check. Each
was fired by the implementer as a scratch edit (`cp` backup, one exact
replacement, run, `cp` back, `diff` exit 0); the reviewers re-fired a sample
(marked ✓r). P = `packages/jet_cad_floor_plan`, demo =
`apps/restaurant_demo`. Test files: U `test/service/table_groups_test.dart`,
C `test/host/table_groups_controller_test.dart`, G
`test/host/table_groups_gesture_test.dart`, L
`test/service/table_group_painter_test.dart`, V
`test/host/table_groups_look_test.dart`, TB
`test/host/table_groups_toolbar_test.dart`.

| Mutant | Task | Variants fired | Killing tests | Red evidence |
|---|---|---|---|---|
| **M-TG-1** overlap accepted | 1 | a: overlap check `&& false`; b: assigned before validation ✓r | U TG-U5; C TG-C1, TG-C2 | `+25 -2` each; TG-C1 "keeping the old groups and not notifying" |
| **M-TG-2** untrimmed keys | 1 | a: ids; b: members; c: group status ids | TG-U1, U3..U6; TG-C1..C3 | a `+23 -4`, b `+22 -5`, c `+26 -1` (TG-C3) |
| **M-TG-3** unknown numbers dropped | 3 | members filtered to the plan's numbers in `setTableGroups` | V TG-V6 | `+28 -1`, `Bad state: No element` (no frame for `3+99`) |
| **M-TG-4** plain tap selects one member | 2 | `_memberKeys` → `{key}` | G TG-G1, G9, G10 | red in all three |
| **M-TG-5** modifier tap via `toggle` | 2 | `toggle(_memberKeys)` ✓r | G TG-G3 | `Expected: {1C, 1E, 18, 20} Actual: {20, 18, 1E}` (12 missing) |
| **M-TG-5b** long press via `toggle` | 2 | `toggle(_memberKeys)` | G TG-G4 | red |
| **M-TG-6** `onGroupTap` missing / wrong | 2 | a: removed; b: wrong number; c: before `onTableTap`; d: locked reports no group; e: locked selects its group; plus `FloorPlanView` dropping it (M-C2-5) | G TG-G1, G2, G3, G9 | each red |
| **M-TG-7** drag moves only the hit | 2 | `_moving = [hit]`; b: drag start selects `{key}` ✓r | G TG-G5, G8, G11; ST3 | red |
| **M-TG-8** locked member moved | 2 | the `hasLockedVisibleMember` return removed | G TG-G6, G7 | red; also M-C2-1 (spent drag replaces) `Expected: {20} Actual: {22}` |
| **M-TG-8b** locked group moved through another table | 2 | only the hit's group checked ✓r | G TG-G7 | red |
| **M-TG-8c** half-selected group moved in part | 2 | the involved-groups expansion removed ✓r | G TG-G8 | `Expected: … -2159.957… Actual: <-1459.957…> differs by <700.0…>` |
| **M-TG-9** `select` not expanded | 1 | `_expandGroups(numbers)` → `numbers` ✓r; mode: expanded in design ✓r | C TG-C1, C3, C5..C7, C11, C12 | `+20 -7`; mode `+26 -1` (TG-C5) |
| **M-TG-9b** expansion unfiltered | 1 | expanded members bypass the filter ✓r | C TG-C7, TG-C12 | `+25 -2` |
| **M-TG-10** group status not overriding | 3 | a: own over group; b: `groupStatuses` out of the repaint merge ✓r; c: out of the key ✓r; d: early return kept; e/f: groups out of merge / key | L TG-L1..L3; V TG-V3, V5 | b `3 Bill: 0xffd166, want 0xef8886` (read with no camera or document change) |
| **M-TG-11** caption repeated | 3 | a: on every member ✓r; b: string order; c: by handle; e: lead among members without a top | L TG-L1..L3, L9 | `+25 -4` (a) |
| **M-TG-11b** caption under every duplicate | 3 | d: every carrier of the lead's number leads | L TG-L2, L9 | `Expected: length <1> Actual: [Paragraph, Paragraph]` |
| **M-TG-12** frame missing or wrong | 3, 3b | a: every visible table; b: transposed; c: inverse transform; d: AABB ✓r; e/f: margin ×2 / 0; g: bevel joins ✓r; h: map order; i: world stroke; O2 (3b): highest-member order | L TG-L4, L5, L10; V TG-V2..V6 | d `Expected: false Actual: <true>` (the non-member inside); O2 after 3b `Expected: true Actual: <false>` |
| **M-TG-13** frame for one visible member | 3 | `< 2` → `isEmpty` | L TG-L5, L9; V TG-V5, V6 | `+25 -4` |
| **M-TG-14** label text | 3 | a: handle order; b: not distinct; c: label ignored; d: wrapped layout | L TG-L6, L9; V TG-V2 | `+27 -2` each |
| **M-TG-15** per-frame allocation / rebuild | 3 | a: frames rebuilt per frame; b: status rebuilt per frame ✓r (survived until `debugRebuilds`); c/d: key lacks groups / paper | L TG-L9, L5, L6, L8; V TG-V2, V4 | b re-fired `+8 -1 … TG-L9 ten steady frames` |
| **M-TG-16** Merge enabled wrongly | 1, 1b, 4 | rule: by number, threshold 1, grouped count nothing, blanks counted, unit tag (1b); bar: `length >= 2`, keys `>= 2` ✓r, `isNotEmpty`, payload minus grouped | U TG-U10, U11; TB1, TB2..TB5 | TB1 `Expected: (false, true) Actual: (true, true)` (one whole group); payload `Expected: {5, 20} Actual: {20}` |
| **M-TG-17** Split enabled wrongly | 1, 4 | rule: unnumbered ignored, visible not selectable, subset, superset, controller never sees unnumbered, design mode (R-C1-2); bar: selectable-blind, payload `keys.first` | U TG-U12, U13; C TG-C7..C9; TB3, TB4 | payload `Expected: ['split G7'] Actual: ['split G9']` |
| **M-TG-17b** flags stale | 1, 4 | `_refreshSelectedGroup` out of `setTableGroups`; bar sources `[selectedTables]` ✓r, Merge's only ✓r, without `selectedGroup` ✓r | C TG-C9; TB1, TB3..TB5 | TB4 `Expected: (false, true) Actual: (true, false)` |
| **M-TG-17c** lookup stale in the tool | 2 | groups identity ignored ✓r; candidates ignored (M-C2-2) | G TG-G9, TG-G10 | `Expected: {22, 20} Actual: {20}` |
| **M-TG-18** buttons without callbacks | 4, 4b | each `if (on… != null)` dropped; callbacks cached in `late final` ✓r; M1 (4b): the trailing gap unconditional | TB5, TB6 | `Found 1 widget with key [<'service-merge'>]`; M1 `Expected: <8> Actual: <16.0>` |
| **M-TG-19** groups leak into the document | 1 | invariant check, not counted | C TG-C10 | green: `designJson()` and the service copy byte-identical with groups, a label and a group status |
| **M-TG-20** groups lost on mode / reset / load | 1 | cleared on `setMode` (groups; statuses), `resetLayout`, `load` | C TG-C5, TG-C11, TG-C12 | `+25 -1` / `+25 -2` |
| **M-TG-21** frame colour from the theme | 3 | a: light set always ✓r; b: theme surface as the paper | L TG-L5, L8; V TG-V4 | b `Actual: <4286201809>` (= `0xFF7A3FD1` on Blueprint) |
| **M-TG-22** chip under the drafting | 3 | chips in the underlay ✓r | V TG-V1, TG-V2 | `the chip: 0x000000, want 0x7a3fd1` (the chair line over it) |

## Extras

**Mutants beyond the named ones.** The implementers fired 128 in all (Task
1: 46, Task 2: 21, Task 3: 38, Task 4: 12, Task 5: 11); 47 of them are not
M-TG variants: Task 1: 23 (G2's blank / colliding / empty / orphan rules,
M-C1-1..17: label trim and grapheme cut, ordered equality and hash, member
order, hidden / locked counting, the lead comparator's four mutants, the
lookup cache's three keys), Task 2: 7 (M-C2-1..7), Task 3: 5 (overlay
dropped, group repaint without groups, chip anchor, chip never hidden, chip
ink inverted), Task 4: 1 (the notification-order trap), Task 5: 11 (M1..M11:
grow vs new, numbering, Split's status, status routing, `onGroupTap` log,
R-C5-2, the label kept on grow, display order, the id from the groups
before the drop, unselected members kept). One first-pass survivor (M-TG-15b)
was turned red by the `debugRebuilds` seam before the commit.

**The reviewers fired 24 of their own:** review 1: 6 (R-3 survived), review 2:
5 (R-X1, R-X2 survived the committed suite), review 3: 6 (O2 survived),
review 4: 3 (M1, M2 survived), review 5: 4 (R1, R2, R3 survived). **Every
survivor was killed by its "b" test**: 1b, 2b (TG-G12, TG-G13), 3b (TG-L5
interleaved), 4b (TB6, TB7), 5b (D16's Free, D20).

**Tests added:** planner +65 (Task 1: 27; Task 2: 11; 2b: 3; Task 3: 17;
Task 4: 5; 4b: 2; 1b and 3b extend existing tests), demo +5 (Task 5: 4; 5b:
1). Existing tests changed only mechanically (invariant 2): the barrel
test gains `'TableGroup'`; `table_select_tool_test.dart` gains the
`groups` parameter, three null record fields and one `ValueNotifier`
import; `table_status_painter_test.dart`'s helper gains the two maps. No
expectation changed.

## Rulings (accepted by the task reviews; ledger `.superpowers/sdd/2026-10-04-table-groups/progress.md`)

- **R-C1-1.** `table_groups.dart` has no Flutter import of its own; it reaches Flutter only through `TableGroup`. *(Spec amended.)*
- **R-C1-2.** `selectedGroup` is always null in the design mode. *(Spec amended.)*
- **R-C1-3.** Numeric lead ties: stripped string, then the original, then the handle. *(Spec amended.)*
- **Notification order.** `selectedGroup` updates after `selectedTables` / `tableGroups` notify; documented in 1b. *(Spec amended.)*
- **R-C2-1.** A half-selected group's drag grows the moved set, not the selection. *(Spec amended.)*
- **R-C2-2.** The tool's lookup is keyed on the picker's candidates list identity plus the groups map.
- **R-C2-3, R-C2-4.** A modifier removal removes every visible member's key; the tool's members come from the picker's candidates. *(R-C2-4 amended.)*
- **R-C3-1..R-C3-7.** Frames and labels from the picker's candidates; the group painters take the `_paper` ARGB notifier; the survey skipped only when both maps are empty; one painter class with a layer mode; exact `arcTo` joins; chip padding 5/2 px, radius 4; M-TG-22's chair line is a neighbour's. *(R-C3-1, -2, -3, -5, -6 amended.)*
- **R-C4-1..R-C4-3.** The second gap only with Merge or Split shown; Split's press null-guards; both flags built eagerly. *(R-C4-1, -2 amended.)*
- **R-C5-1.** The demo grows the group when the request touches exactly one group. *(Spec amended, with F-1.)*
- **R-C5-2..R-C5-4.** A merge that empties a group removes its status; one `Merged {…} as G<n>` line in reading order; a remainder keeps its id and label. *(R-C5-2, -4 amended.)*

## Chromium smoke (Task 6)

**Setup.**
- **Build.** The release build fetches CanvasKit from `www.gstatic.com`,
  which this container's proxy blocks for Chromium, so the smoke ran on
  the `--no-web-resources-cdn` build above (`build/web_nocdn`), as the
  dark theme exit did.
- **Serving and browser.** `python3 -m http.server`; Playwright from
  `/opt/node-tools` with the Chromium in `/opt/pw-browsers`; a 1440×900
  context at device pixel ratio 1, locale `en-US`, `colorScheme: 'light'`
  and, for the repeats, `'dark'`. No page errors and no external requests
  on any run.
- **Driving.** Flutter web draws to a canvas, so tables were selected
  through the demo's "Table numbers" field and its Select button, and the
  service bar's Merge and Split by their positions (they sit after Redo,
  at x ≈ 120 and 160). Each run: Service; seven wheel steps of zoom (about
  0.08 px/mm, twice the fit); `1,2` → Select → Merge; `1,3` → Select → Merge; Bill; a
  mouse drag on table 2 by (+80, −110) px with a screenshot before the
  release; Split.
- **Blueprint.** The Blueprint swatch is reachable in the demo's design
  mode, so one light run picked it before switching to Service.

The screenshots are in
[2026-10-04-table-groups/](2026-10-04-table-groups/). What each one
shows (colours sampled from the PNGs):

- **`demo_light_1_merge.png`.** Merge of `1,2`.
  - A purple frame (`#7A3FD1`, the light `gripMove`, sampled) with round
    corners encloses tables 1 and 2 and their chairs, about 10 px clear of
    the chairs at this zoom. There is no fill.
  - The chip `1+2` sits centred on the frame's top edge: white text on
    purple, small (about 8 px glyphs) but readable.
  - Both tables keep their blue selection outlines. On the bar Merge is
    now disabled and Split enabled (the selection is exactly G1). The panel
    reads `Groups: G1: 1+2`; the log `Salon: Merged {1, 2} as G1`.
- **`demo_light_2_grow.png`.** `1,3` selected `{1, 2, 3}` (1 expanded to
  G1), Merge grew G1.
  - One frame now spans the row 1–2–3, the chip reads `1+2+3` at the top
    centre (over table 2). Table 3 is inside with a margin equal to the
    others'.
  - The log reads `Merged {1, 2, 3} as G1` (grown, not a G2).
- **`demo_light_3_bill.png`.** Bill on the selected group.
  - All three tops are filled Bill (`#EF8886` sampled on table 2).
  - One caption, `Bill`, under table **1** only (the lead), not under 2 or
    3. At this zoom the caption sits low on the top, its baseline touching
    the lower chair edges and the selection outline (the 14c caption rule,
    pre-existing).
  - Panel: `G1: 1+2+3 (Bill)`; log `Salon: Bill for G1`.
- **`demo_light_4a_drag_mid.png`.** Mid-drag, before the release.
  - All three members' outlines follow the pointer as amber preview
    outlines, up and to the right.
  - The frame, the chip and the Bill fills stay at the old place (G3:
    they jump on release). The preview tables overlap the old frame's top
    edge. This is the spec'd behaviour; it reads as "the group is being
    moved", but the frame left behind is noticeable.
- **`demo_light_4b_drag_released.png`.** After the release.
  - The three tables moved together by one step; the frame, the chip and
    the fills jumped with them, and 4, 5, 6 and 7 did not move.
  - Undo is now enabled; the log reads `Salon: layout changed` once.
- **`demo_light_5_split.png`.** Split.
  - The frame, the chip and the fills are gone; the tables stay where the
    drag put them and stay selected.
  - Merge is enabled again (three ungrouped tables) and Split disabled.
    `Groups: none`; log `Salon: Split G1`.
- **`demo_dark_1_merge.png`** and **`demo_dark_3_bill.png`.** The same two
  frames with `colorScheme: 'dark'`.
  - The app bar, the service bar and the panel are dark with readable
    text.
  - The paper stays White, so the frame, the chip and the fills are the
    light set, with the light run's sampled values (`#7A3FD1` frame,
    `#EF8886` fill): the paper decides, not the theme (M-TG-21).
- **`demo_light_blueprint_3_bill.png`.** Blueprint, light scheme, after
  merge, grow and Bill.
  - The frame is the dark set's lavender, `#C4A0FF` sampled (M-TG-21's
    value). The chip is lavender with dark ink (`#222223` sampled in the
    glyphs), readable.
  - The fills are the darker Bill composite (`#953946`) with white numbers
    and a white `Bill` caption under 1 only. Selection outlines are light
    blue. Nothing is unreadable.
- **`demo_light_fit_3_bill.png`.** The same group at the default fit
  (about 0.04 px/mm, no zoom).
  - The frame still encloses the three tables, but its margin is only
    about 6 px, and the chip keeps its screen size. So the chip **covers
    the top edge of table 2's upper chairs**: it is in the overlay above
    the drafting, as F-11 intends, which here hides member drafting.
  - The `Bill` caption falls across table 1's lower chairs and is hard to
    read (pre-existing low-zoom caption placement, seen at the dark theme
    exit too).

**Nothing looked broken.** Frames enclose exactly the members, the chip
and the caption are where the spec puts them, Merge / Split enable as G5
says, and the colours follow the paper. **The weak spots seen:**
- at the default fit the chip covers the members' chair lines (above);
- the frame and fills left behind during a drag (spec'd, G3);
- the small chip text (the status caption size) next to the large table
  numbers;
- the low-zoom `Bill` caption on the chairs (pre-existing, 14c).

## Debt

- **F-1, the API gap.** A host cannot ask which members of a group are
  selectable: `FloorPlanTable` has no `locked` / `visible` flag and no call
  exposes `selectableMembers(groupId)`. So G6's literal grow rule cannot
  be written by a host (R-C5-1 stands in for it).
- **A group the demo cannot clear.** A new-group merge can leave a
  remainder made only of locked or hidden members (D20's `G7 = {8, 9}`).
  It cannot be selected, so neither Split nor Merge reaches it; only the
  POS (`setTableGroups`) can clear it. Another facet of F-1.
- **Frames jump on release during a drag** (G3, R-17). Seen in the smoke:
  the preview outlines leave the frame, the chip and the fills behind
  until the release. Moved-but-unselected members of a half-selected group
  show no preview outline at all (R-C2-1).
- **A hull may enclose non-members.** Members far apart give a frame
  spanning the floor between them, and a non-member inside it is not
  tinted (Risks). Not seen in the smoke (the members were adjacent).
- **`selectedGroup` goes stale after a raw layer edit**, like
  `selectedTables`: a host poking `activeDocument` layers (no command, no
  selection change) leaves it until the next selection or document change
  (review 1 probe P3).
- **≥3 identical hull points draw no frame.** `convexHull` returns two
  coincident points for three or more coincident inputs, and
  `offsetHull` then draws nothing (review 3 note 2). Needs every member's
  box to be one point; not realistic, not fixed.
- **The chip at low zoom covers member drafting** (seen in the smoke, at
  the default fit). The 150 mm margin is a few pixels there, and the chip
  keeps its screen size, so it sits over the members' chairs. It is hidden
  only when wider than the whole frame. A larger screen-space clearance or
  a hide threshold on the margin would avoid it; not specified, not fixed.
- **The low-zoom caption** falls on the chairs below the lead (pre-existing,
  14c; seen again).
- **Unpinned by choice:** the `shouldRepaint` additions on the three
  painters (each is built once, so any mutant there is equivalent in the
  product); "frames stay put during a drag" (holds by construction, no
  guard test).
- **Not run here:** the macOS build.

## Owed

- **The human's look on macOS, web and a tablet — never simulated** (spec
  exit gate 5):
  - merge, grow, a group status, a drag and a split in the service mode,
    both themes, White and Blueprint;
  - the frame and chip at the default fit and zoomed in;
  - the long press and the drag on a group by touch (14t's hold-back is
    unchanged, the look is owed).

  The screenshots above are evidence for that look, not a substitute.
- **The merge decision.**
