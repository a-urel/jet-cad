# Task 3 report — the look (G3)

Implementer, 2026-10-04, on `claude/dreamy-gates-2kgh4o` from `e85ded9`.

## Commits

- `b464204` feat(table-groups): Task 3 — group frames, label chips and the group status (not pushed)

## Files changed (all in `packages/jet_cad_floor_plan`)

- `lib/src/planner_view.dart`: adds an optional `overlay` slot. It is a `Positioned.fill` placed after `DraftCanvas` and before the
  selection overlay. A null overlay adds no child.
- `lib/src/service/table_group_painter.dart` (**new**). It holds:
  - `TableGroupPainter` with a `TableGroupLayer { frames, chips }` mode;
  - `groupLabel`, `convexHull` and `offsetHull`;
  - the constants `kGroupFrameMarginMm = 150`, `kGroupFrameStrokePixels = 2`, `kGroupChipPaddingX/Y = 5/2` and
    `kGroupChipRadius = 4`.
- `lib/src/service/table_status_painter.dart`: adds the `tableGroups` and `groupStatuses` parameters. It resolves each visible
  table's effective status, draws the group caption once under the lead, and adds both to the rebuild key and `shouldRepaint`. It
  also gains a `debugRebuilds` counter.
- `lib/src/host/service_view.dart`: the status painter's repaint merge gains `tableGroups` and `groupStatuses`. The underlay is now a
  `Stack(fit: expand)` with `table-group-layer` under `table-status-layer`, each in its own `RepaintBoundary`. The overlay is
  `table-group-chips`. The two group painters share one repaint merge: camera, `tableGroups`, document changes and `_paper`.
- `test/service/table_status_painter_test.dart`: mechanical. The `painterFor` helper gains
  `tableGroups: ValueNotifier(const {})` and `groupStatuses: ValueNotifier(const {})`. No expectation changed.
- `test/service/table_group_painter_test.dart` (**new**, 11 tests) and `test/host/table_groups_look_test.dart` (**new**, 6 tests).

`PlannerShell`, the engine, the render package, the allocation invariant tests and the goldens were not touched.

## What was built

**The frames** (`TableGroupLayer.frames`, the underlay, below the status fills).
- **Rebuild.** Members come from the service view's own `TablePicker` candidates, through `TableGroupLookup` from Task 1. The picker
  already drops hidden tables, singular transforms and empty boxes. Each group with at least two visible members (`visibleMembers`)
  is framed.
- **Hull.** The rebuild transforms the four corners of each member's cached `box` by the node's transform and takes their convex hull
  (monotone chain). Collinear and duplicate points are dropped within `TablePicker.tolerance`.
- **Offset.** `offsetHull(hull, 150)` builds a closed path. Each vertex gets an exact circular arc (`Path.arcTo`, a conic, not a
  polyline) from the incoming edge's outward normal to the outgoing one's. The offset edges join the arcs. One point gives a circle,
  two give a stadium.
- **Order.** Frames are sorted by each group's lowest member handle.
- **Per frame.** The painter fills one reused `Float64List` with the camera matrix and sets `_paint.strokeWidth = 2 / scale` in place
  on its one reused stroke `Paint`. The paint's colour is set at rebuild time to `PaperPalette.forPaper(paper.value).gripMove`. Then
  `save; transform; drawPath × n; restore`. There is no fill.

**The chips** (`TableGroupLayer.chips`, the overlay).
- **Text.** It is `groupLabel`: the group's `label`, else the visible members' distinct numbers in `inLeadOrder` joined by `+`.
- **Paragraph.** It uses the status caption size and `maxLines: 1`. It is laid out at infinite width, then at
  `ceil(maxIntrinsicWidth)`, and cached by `(text, ink)`. Unused entries are evicted at rebuild time.
- **Ink.** `kStatusCaptionOnDark`/`OnLight`, chosen by `foregroundFor(gripMove rgb)`.
- **RRect.** Built at rebuild time in paragraph coordinates, padded 5/2 px with radius 4.
- **Anchor.** Computed at rebuild time: the centre x of the hull's bounds, and the hull's maximum y + 150. These are the offset
  outline's exact bounds; `Path.getBounds` is not used, because the arcs' control points reach further.
- **Per frame.** Skipped when `(hull width + 300) · scale < rrect.width`. Otherwise
  `save; translate(sx − w/2, sy − h/2); drawRRect; drawParagraph(Offset.zero); restore`. No `Offset` or `RRect` is created per frame.

**Rebuild key** (both layers): the groups map's identity, `stateId`, the tables' `mutationRevision`, and `paper.value`.
`debugAllocations` counts every Path, Paint, Paragraph, RRect and matrix. `debugRebuilds` counts rebuilds.

**The status painter.**
- **Surveying.** When either map is non-empty it surveys the plan. It iterates `survey.tables`, which are ascending by handle. A
  table's effective status is `groupStatuses[groupOf[number]] ?? tableStatuses[number]`.
- **Fills.** Each statused visible table with a top is filled.
- **Caption.** A group status's caption goes only on the lead: `inLeadOrder` over that group's visible members **with a top**, so
  ties go to the lower handle. A table status's caption is drawn as before.
- **Unchanged parts.** Paint and caption caching, eviction (SP9) and draw order are as before.

## Tests added

`test/service/table_group_painter_test.dart`. It uses painters directly with recording canvases.
- **Fixture.** Tables 12, 3, 7, 20 and 9 (9 on a hidden layer) in handle order, turned and mirrored, about 40 m off the origin. The
  camera is at 0.06 px/mm. Variants: a file duplicate 3, and a 3 with no top.
- **TG-L1 (M-TG-10, M-TG-11).**
  - Group Bill over 3's own Ordered fills 12, 3 and 7 Bill; 20 keeps its own.
  - Two captions: G7's is centred under 3 (numeric lead), 20's under 20.
  - Clearing the group status gives 3 Ordered with its own caption.
  - Restoring the group status and then changing only the groups (3 leaves) gives 3 Ordered.
- **TG-L2 (M-TG-11b).** With the lead 3 duplicated, there are four fills and one caption, under the first 3.
- **TG-L3.** 3 has no top, so the caption goes under 7, among two fills.
- **TG-L4 (M-TG-12).**
  - Fixture: the asymmetric `skewTable` (box 200..2100 × 300..1000, base (400, 400)). Member A is mirrored and turned 37°; member B is
    turned 74° and not mirrored. Non-member C is beside them.
  - The path is drawn under exactly the camera matrix.
  - Every member corner pushed 0.9·margin in 8 directions is contained.
  - Extreme corners pushed 0.9·m along an axis are in; pushed 1.1·m they are out.
  - C is excluded: its centre and 164 points on its box outline are outside.
  - Premises: C's centre is inside the members' AABB, and C is between m and 2m from the hull.
- **TG-L5 (M-TG-12, -13, -21).**
  - Groups with one visible member get no frame: a hidden member, or 99 not in the plan.
  - Two frames are drawn in lowest-member-handle order whatever the map's order.
  - The stroke is 2/0.06, then 2/0.13. It is one reused stroke Paint.
  - The colour is 0xFF7A3FD1, then 0xFFC4A0FF after a paper flip to Blueprint.
- **TG-L6 (M-TG-14).**
  - The text is `3+7+12` with the hidden 9 left out, and `3+7+12` with the duplicate.
  - The label `'  Window table for the Smiths party '` gives `Window table for the Smi` (24 characters).
  - The paragraph is one line, has not exceeded max lines, and `width >= maxIntrinsicWidth`.
- **TG-L7.**
  - The chip translation is `(sx − w/2, sy − h/2)` of an anchor computed independently from the members' corners, at two scales.
  - The RRect is exact and the fill is gripMove.
  - The chip is hidden at 0.004 px/mm (premise checked).
- **TG-L8.** Chip ink, read in pixels: white glyphs on light gripMove, 0x202020 on dark gripMove (on Blueprint).
- **TG-L9 (M-TG-15).**
  - Over ten frames with the camera moving, the frames, chips and status painters keep `debugAllocations` and `debugRebuilds`
    unchanged and pass identical objects.
  - A groups change rebuilds each group painter exactly once, and the chip text follows.
- **TG-L10.** Units for `convexHull` (point, segment, collinear and interior points) and `offsetHull` (circle, stadium, rounded corner
  in and out).
- **premise.** The lead order of {12, 3, 7} is 3, 7, 12.

`test/host/table_groups_look_test.dart`. It runs the real `FloorPlanView`/`ServiceView` under the palette fixture's seed at DPR 1.
- **Fixture.** A 1:20 page. Members 12, 3 and 7 are turned and mirrored. Table 20 is not a member; its lower chair's bottom line runs
  through G7's chip. Table 9 is on a hidden layer. The camera is at 0.125 px/mm, off the origin, and puts the chip's row on pixel
  centres.
- **TG-V1.**
  - Design mode: none of the three layer keys exists.
  - Selection mode: the underlay `Stack` children are `[table-group-layer, table-status-layer]`.
  - In the drawing-area `Stack`, the chips sit after `DraftCanvas` and before the selection overlay.
- **TG-V2 (M-TG-22).**
  - The groups are set after the camera, so the chips must repaint on the groups.
  - The pixel on the chair line inside the chip's left padding is gripMove (within 3).
  - Premise: the same row, outside the chip, shows the chair line (more than 100 from white).
- **TG-V3 (M-TG-10).**
  - 3 Ordered, then `setGroupStatus(Bill)`, read with the camera identical and `stateId` unchanged: 3 and 12 show over(Bill, White),
    20 its own Eating.
  - Cleared: 3 Ordered.
  - Bill back, then `setTableGroups` with 3 removed (groups only): 3 Ordered, 12 still Bill.
- **TG-V4 (M-TG-21).**
  - Blueprint under the light theme: the frame's paint is 0xFFC4A0FF, and the left-most frame pixel is within 12 of 0xC4A0FF and more
    than 40 from 0x7A3FD1.
  - The reverse holds for White under the dark theme.
- **TG-V5 (M-TG-13).** G9 = {12, 9 hidden} with a group status gives no frame path and no chip, one status path, and 12's pixel Bill.
- **TG-V6 (M-TG-3).**
  - G9 = {3, 99} draws no frame.
  - Switch to design, place a table and number it 99, switch back: one frame containing 99's and 3's base points, chip text `3+99`.

## Gate results

Logs are in the scratch dir as `tg-task3/gate-*.log`.

| Package | Test (real summary line) | Expected | Analyze | Format |
|---|---|---|---|---|
| render `jet_cad_2d_flutter` (not edited) | `01:12 +1304 ~1 -7: Some tests failed.` | +1304 ~1 -7 | No issues found! | 0 changed, exit 0 |
| planner `jet_cad_floor_plan` | `03:38 +1271: All tests passed!` | +1254 after 2b, +17 new | No issues found! | 0 changed, exit 0 |
| `jet_cad_restaurant_symbols` | `00:02 +94: All tests passed!` | +94 | No issues found! | exit 0 |
| `apps/floor_planner` | `01:29 +201: All tests passed!` | +201 | No issues found! | exit 0 |
| `apps/restaurant_demo` | `00:10 +18: All tests passed!` | +18 | No issues found! | exit 0 |
| `apps/dev_harness_2d` | `00:34 +82: All tests passed!` | +82 | No issues found! | exit 0 |

The render package's 7 failures are the standing set: `text_ladder_golden_test.dart` rungs 1 to 5 and `text_lod_ladder_golden_test.dart`
rungs 1 and 2. `analysis_options.yaml` is not modified in this checkout and nothing of it was staged.

## Mutant table

**Method.** For each mutant:
1. `cp` the file to `tg-task3/<name>.bak`;
2. make one exact-string Python replacement (the count must be 1);
3. run `flutter test test/service/table_group_painter_test.dart test/host/table_groups_look_test.dart test/service/table_status_painter_test.dart`
   (29 tests);
4. `cp` the backup back and check that `diff` is clean.

"restored ok" was printed for all 38. The driver is `tg-task3/mutants.py` and its output is in `tg-task3/mutants.log`, with full runs
in `tg-task3/<name>.out`. No run was a compile failure. Line numbers are of the committed files.

Abbreviations: P = `table_group_painter.dart`, SP = `table_status_painter.dart`, SV = `service_view.dart`,
C = `floor_plan_controller.dart`, PV = `planner_view.dart`.

| Mutant | Site | Change | Red tests | Summary |
|---|---|---|---|---|
| M-TG-3 unknown numbers dropped | C:227 | `setTableGroups` filters members to the plan's current numbers | TG-V6 | `+28 -1` |
| M-TG-10a own status over group | SP:168 | `groupStatus ?? map[n]` → `map[n] ?? groupStatus` | TG-L1, TG-V3 | `+27 -2` |
| M-TG-10b no repaint on group statuses | SV:117 | `_c.groupStatuses` out of the status repaint merge | TG-V3 | `+28 -1` |
| M-TG-10c key lacks groupStatuses | SP:287 | identity check removed | TG-L1, TG-V3 | `+27 -2` |
| M-TG-10d early return kept | SP:153 | `map.isNotEmpty \|\| groupMap.isNotEmpty` → `map.isNotEmpty` | TG-L2, TG-L3, TG-V5 | `+26 -3` |
| M-TG-10e no repaint on groups (status) | SV:115 | `_c.tableGroups` out of the status merge | TG-V3 | `+28 -1` |
| M-TG-10f key lacks groups (status) | SP:286 | identity check removed | TG-L1, TG-V3 | `+27 -2` |
| M-TG-11a caption on every member | SP:201 | lead condition → `true` | TG-L1, L2, L3, L9 | `+25 -4` |
| M-TG-11b lead by string order | SP:187 | sort by `number.compareTo` | TG-L1, L2, L3 | `+26 -3` |
| M-TG-11c lead by handle | SP:187 | `list.first` | TG-L1, L2, L3 | `+26 -3` |
| M-TG-11d caption under every duplicate | SP:187 | every member carrying the lead's number leads | TG-L2, TG-L9 | `+27 -2` |
| M-TG-11e lead among members without a top | SP:174 | lead candidates added before the no-top skip | TG-L3 | `+28 -1` |
| M-TG-12a frame around every visible table | P:285 | members = all candidates | TG-L4, L6, L7, V2, V6 | `+24 -5` |
| M-TG-12b corners transposed | P:300 | `a·x+b·y+e`, `c·x+d·y+f` | TG-L4, L7, V2, V3, V6 | `+24 -5` |
| M-TG-12c picker's inverse as transform | P:291 | `node.transform` → `candidate.inverse` | TG-L4, L5, L7, L8, V2, V4, V6 | `+22 -7` |
| M-TG-12d AABB, not hull | P:304 | hull replaced by the corners' bounding rectangle | TG-L4 | `+28 -1` |
| M-TG-12e margin doubled | P:321 | `offsetHull(hull, 2 * margin)` | TG-L4, TG-V4 | `+27 -2` |
| M-TG-12f no margin | P:321 | `offsetHull(hull, 1)` | TG-L4, TG-V4 | `+27 -2` |
| M-TG-12g bevel joins | P:147 | `arcTo` → two `lineTo`s (chord) | TG-L10, L4, V4 | `+26 -3` |
| M-TG-12h map order | P:347 | `out.sort(...)` removed | TG-L5 | `+28 -1` |
| M-TG-12i world stroke | P:400 | `strokeWidth = 2` (not `/ scale`) | TG-L5, TG-V4 | `+27 -2` |
| M-TG-13 frame for one member | P:286 | `members.length < 2` → `members.isEmpty` | TG-L5, L9, V5, V6 | `+25 -4` |
| M-TG-14a handle order | P:48 | `inLeadOrder(members)` → `members` | TG-L6, L9 | `+27 -2` |
| M-TG-14b not distinct | P:49 | `if (seen.add(n)) n` → `n` | TG-L6, L9 | `+27 -2` |
| M-TG-14c label ignored | P:45 | `if (label != null) return label;` removed | TG-L6, TG-V2 | `+27 -2` |
| M-TG-14d wrapped layout | P:365 | relayout at width 120 | TG-L6, TG-V2 | `+27 -2` |
| M-TG-15a frames rebuild per frame | P:375 | `if (true \|\| ...)` | TG-L9 | `+28 -1` |
| M-TG-15b status rebuild per frame | SP:283 | `if (true \|\| ...)` | TG-L9 (second run) | `+28 -1` |
| M-TG-15c key lacks groups (group painters) | P:377 | identity → `false` | TG-L5, L6, L9, V2, V4 | `+24 -5` |
| M-TG-15d key lacks paper | P:378 | paper check → `false` | TG-L5, TG-L8 | `+27 -2` |
| M-TG-21a light set always | P:267 | `forPaper(paper.value)` → `PaperPalette.light` | TG-L5, L8, V4 | `+26 -3` |
| M-TG-21b theme surface as paper | SV:138 | group painters' `paper: ValueNotifier(_surfaceArgb)` | TG-V4 | `+28 -1` |
| M-TG-22 chips in the underlay | SV:286 | chips moved into the underlay `Stack` above the status layer, no overlay | TG-V1, TG-V2 | `+27 -2` |
| M-PV overlay dropped | PV:259 | `PlannerView` does not mount `overlay` | TG-V1, V2, V5, V6 | `+25 -4` |
| M-SV group painters no repaint on groups | SV:127 | `_c.tableGroups` out of `_groupRepaint` | TG-V2, TG-V4 | `+27 -2` |
| M-chip anchor without margin | P:340 | `maxY + margin` → `maxY` | TG-L7, TG-V2 | `+27 -2` |
| M-chip never hidden | P:415 | the width skip removed | TG-L7 | `+28 -1` |
| M-chip ink inverted | P:282 | OnDark/OnLight swapped | TG-L8 | `+28 -1` |

**One survivor on the first pass, then fixed.**
- M-TG-15b (the status painter rebuilt every frame) first ran green: `00:02 +29: All tests passed!`. The status painter caches every
  `Path`, `Paint` and `Paragraph`, so a per-frame rebuild creates nothing that `debugAllocations` counts. That is true of SP1 as well,
  before this task.
- The fix adds `debugRebuilds` to `TableStatusPainter`. TG-L9 now asserts that all three painters' `debugRebuilds` are unchanged over
  the ten frames.
- Re-fired: red, `00:00 +8 -1: ... TG-L9 ten steady frames ...`. The summary line in the table is from that re-run.

**Real excerpts.**
- M-TG-22: `the chip: 0x000000, want 0x7a3fd1`, `Actual: <209>` / `Which: is not a value less than or equal to <3>`. The black chair line
  covers the chip.
- M-TG-10b: `3 Bill: 0xffd166, want 0xef8886`, `Actual: <73>`. The layer was not repainted after `setGroupStatus`.
- M-TG-21b: `Actual: <4286201809>` (= 0xFF7A3FD1) at `table_groups_look_test.dart:318`.
- M-TG-3: `Bad state: No element` at `List.single`. No frame path.
- M-TG-11d: `Expected: an object with length of <1>`, `Actual: [_NativeParagraph:Paragraph(), _NativeParagraph:Paragraph()]`.
- M-TG-12d: `Expected: false`, `Actual: <true>`. C is inside the AABB frame.

## Proposed rulings

- **R-C3-1: the frame, its count of two or more, and the label use the picker's candidates.**
  - These are visible tables, excluding singular transforms and empty boxes.
  - A visible member the picker skips therefore does not count towards "two or more visible members" and is not in the label.
  - A group whose only two "members" are one number on two tables (a file duplicate) gets a frame. That is the literal reading of
    G2/G3.
  - Cost if wrong: count from the survey instead; one line.
- **R-C3-2: the group painters take the paper notifier, not ServiceView's built `PaperPalette`.**
  - They take `_paper` (the ARGB notifier the status painter already reads) and call `PaperPalette.forPaper` themselves. That is the
    same function on the same value `PlannerView` gets.
  - The painters are `late final` and built once, so a palette passed by value would go stale on a paper change. The notifier is also
    in the repaint merge.
  - Cost if wrong: none functional.
- **R-C3-3: the status painter skips the survey only when both maps are empty.**
  - The early return on an empty *table* status map is gone, and M-TG-10d kills a mutant that keeps it. The both-empty skip only
    avoids a `TableSurvey` at every document change when nothing can fill.
  - Cost if wrong: drop the guard.
- **R-C3-4: one class with a layer mode; each instance rebuilds itself.**
  - The hull is computed twice per rebuild, once per layer, at rebuild rate.
  - "A groups change rebuilds once" is asserted per painter.
  - Cost if wrong: a shared geometry object.
- **R-C3-5: round joins use exact `Path.arcTo` conics, not a fixed segment count.**
  - The anchor and the chip-hiding width come from the hull grown by the margin, which is the exact bounds of a round offset, not from
    `Path.getBounds`.
  - Cost if wrong: none.
- **R-C3-6: chip padding 5/2 px and radius 4 are my choice.** The spec fixes only the text size and the colours.
- **R-C3-7: M-TG-22's "chair line" is a non-member table's lower chair bottom edge running through the chip.** Table 20 sits above the
  frame. That is the realistic case: a neighbour's chair under a label.

## Found but not fixed / not pinned

- **`shouldRepaint` is unpinned.** The additions to both painters' `shouldRepaint` have no test. `ServiceView` builds each painter
  once (`late final`), so `shouldRepaint` is never called with a different delegate.
- **Drag behaviour is untested.** "During a drag the frames, fills and chips stay and jump on release" holds by construction, because
  the rebuild key is `stateId` and a drag preview makes no command. No test was owed by a named mutant.
- **The status painter's per-frame rebuild was invisible before this task.** `debugAllocations` alone did not catch it (see
  M-TG-15b). `debugRebuilds` now covers it.

## Where to look hardest

- **`offsetHull`'s sweep normalisation** (P ~:140). For a convex counter-clockwise hull each turn is in (0, π]. A two-point hull gives
  ±π, which is normalised to π. TG-L10 covers the stadium and the circle.
- **TG-V2's premise.** The sample sits in the chip's left padding on the chair line's row (row = the anchor's, on a pixel centre). It
  relies on the label `G7` being narrow enough that the padding lies within ±225 mm of the anchor. That is asserted.
- **TG-V4's tolerance.** It allows 12 per channel for a 2 px stroke on a curve. The mutant's distance is far larger.
- **The status painter's lead set.** It is computed only for groups with a status, among visible members with a top. The candidates
  are added after the no-top skip, which is what M-TG-11e checks.
