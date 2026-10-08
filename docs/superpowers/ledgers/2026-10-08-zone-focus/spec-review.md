# Spec review: 2026-10-08-zone-focus-design.md (revision 1)

Reviewer: independent. Spec and code at `0cfc87e` (the spec's facts are dated
`14616d9`; the code they cite is unchanged since then). I worked in a clone at
`/tmp/zone-spec-review/repo` with Flutter 3.47.6 / Dart 3.13.5. I edited nothing
in the repository except this file. Monépro's spec 103 was read at `develop @ 88c96e0`.

## Verdict: **Approve with fixes**

The design is sound. Framing by number on the existing fit machinery is correct,
including the post-frame order it relies on. A paper-coloured veil in the overlay
slot fades exactly what it should, in both themes. `Path.combine` is safe on both
web renderers Flutter 3.47 has.

Three findings are important:
- **V-1.** Z15's argument for keeping faded tables interactive rests on a false
  premise, and Q-Z2 asks the human on that premise.
- **V-2.** The spec does not say which box the veil uses, and its killer cannot
  tell the right box from the wrong one.
- **V-3.** About a dozen requirements have no named mutant.

None of them needs a redesign.

## What I ran (results of record)

- **E1. `Path.combine` and winding on the tester.** I ran a throw-away
  `flutter test` in the clone, then deleted it.
  - Two overlapping squares wound the same way, in one non-zero path: the overlap
    `contains` → `true`.
  - The same squares with one wound the other way, as a mirrored instance's
    corners come out: the overlap → `false`. It cancels.
  - `Path.combine(difference, union, focused)` holds a faded-only point and drops
    a point inside the focused square.
  - The difference of two empty paths returns an empty path and does not throw.
  - The difference with an empty focused path keeps the union.

  This confirms that Z13's orientation normalisation is required, not cosmetic.
- **E2. Web renderers in the SDK.**
  - `packages/flutter_tools/lib/src/web/compile.dart:186-191`: `WebRendererMode`
    is `{canvaskit, skwasm}`. The HTML renderer is gone.
  - `bin/cache/flutter_web_sdk/lib/ui/path.dart:54-55`: `Path.combine` →
    `EnginePath.combined`.
    - `primitives/path.dart:586-596` records the operation lazily.
    - `canvaskit/path.dart:298-307` resolves it with `canvasKit.Path.MakeFromOp`.
    - `skwasm/skwasm_impl/path.dart:242-243` resolves it with `pathCombine`.
  - Native: `sky_engine/lib/ui/painting.dart:3157-3163` throws a `StateError` when
    the operation fails ("check for NaN values"). Its documentation names no
    platform limitation.

## Facts checked

The following are **correct** at `0cfc87e`:
- F-1: D21 `:239-242`, A `:835`, B.1 `:879-882`, B.2 `:886-890`, §10 `:787-791`.
- F-2, F-3, F-5, F-6 (picker `:174`, `:177-180`), F-9, F-10, F-11, F-12, F-14.
- F-15: I parsed `salon.json` and `teras.json`.
  - Salon 1–3: def 18, y = 1625.
  - Salon 4–5: def 35, bottom left.
  - Salon 6–7: def 54, x = 2975.
  - Salon 8–11: def 65, y = −2790.
  - Teras 1–6.
  - `CHANGELOG.md:9-11` reads "Nothing yet".

Small inaccuracies are in V-13.

The post-frame order in F-5 holds:
1. `FloorPlanView.build` registers the measurement during build
   (`floor_plan_view.dart:203` → `:104`).
2. `PlannerView` registers its first-frame fit during layout (`planner_view.dart:212`).
3. Post-frame callbacks run in registration order, so the fit lands after the
   correction.

An old view's request-time callback (`planner_view.dart:164`) runs first. It returns
on `!mounted` (`:171`), because `finalizeTree` unmounts the old view before
post-frame callbacks run. It then calls no `fitted()`, so `_fitPending` survives for
the new view. The design relies on that guard, and no test pins it (V-3d).

## Findings

### V-1 (important) — Z15, Q-Z2: the one-liner does not make a faded table inert

**Fact.** In `TableSelectTool._tap`, a tap **selects first**
(`selection.replace`/`toggle`, `table_select_tool.dart:275-286`) and only then calls
`onTableTap` (`:290`). Gating `onTableTap` in the host still leaves all of these:
- the selection changes, so `selectedTables` fires. The probe's own `showOrders`
  listener (`tool/ci/host_probe/lib/main.dart:97, 189-192`) reacts to it;
- a context click selects through `contextSelect` (`:56-62`);
- a long press toggles (`:369-392`);
- a drag replaces the selection and moves the table (`:203-231`, `:362-365`);
- Merge offers the table.

So "the host gets the same effect with one line" is false. Q-Z2 asks the human
on that premise.

**Fix.**
- Rewrite Z15's *Why*. The focus is presentation. A host that wants faded
  tables to be ignored gates:
  - `onTableTap` and `onTableContextMenu`;
  - its `selectedTables` listener, against `controller.tableFocus.value` (the
    trimmed copy, not a host variable);
  - moves, with `serviceMoves: false` if it wants none.
- Say that selection, drags and Merge stay ungated.
- Restate Q-Z2 with those facts.

**My view on Q-Z2: keep them interactive.**
- A waiter under "My tables" still has to act on a colleague's table: transfer,
  merge, a covering shift.
- A zone framing already puts the other zones mostly off screen.
- An inert table would turn its box into a dead zone. A tap there would fall
  through to the floor, clear the selection or start a pan, which looks broken.

### V-2 (important) — Z2, Z13, M-Z18, M-Z17: the veil's box is the oriented quad, not `transformedBy`

**Fact.** Z2 frames with `definitionBounds.transformedBy(node.transform)`. That is
the axis-aligned world bound of the four corners (`aabb2.dart:100-108`), and Z2
calls it "the one notion of a table's extent, shared with the pick (14c B-2) and
the group frame (G3)". Neither of those uses it:
- The picker tests the definition box through the inverse transform
  (`table_picker.dart:209-213`). B-2 says "its world bounds are never used"
  (`2026-10-03-selection-mode-design.md:341-344`).
- The group frame hulls the four transformed corners
  (`table_group_painter.dart:290-306`).

For framing, the axis-aligned bound is right: it is conservative and a camera
needs a rectangle. For the veil, it is wrong:
- On the 37° fixture it covers about 1.5× the table's area and veils floor and
  neighbours.
- Subtracted as a focused box, it unveils more of each faded neighbour.

Z13's "counter-clockwise whatever the mirror" implies quads, but nothing says so.

M-Z18's killer passes with axis-aligned boxes too: "inside the transformed box
only is veiled, inside the untransformed box only is not".

**Fix.**
- Z13: each table contributes the **four transformed corners** of its definition
  box, as `TableGroupPainter` does, reversed when `det < 0`.
- Z2: the framed box is the axis-aligned bound of those same corners. Drop the
  "one notion" sentence, or say "the same corners".
- Add a killer to M-Z18: a point inside the turned table's world axis-aligned bound
  but outside its quad (a corner triangle) is **not** veiled.
- Build M-Z17's overlap with the turned table, so subtracting axis-aligned boxes
  goes red.

### V-3 (important) — Testing: requirements with no named mutant

`CLAUDE.md`'s bar is one named mutant per requirement. These have none:
- **a. Z4, "an earlier pending request stays".** Mutant: a failed call resets the
  target or `_fitPending`. Killer: with no view, `fitToTables({'3'})`, then
  `fitToTables({'nope'})` → false; mount: 3 is framed.
- **b. Z6, page fallback.** Mutant: `framingFor` null and no fit, or the old
  camera kept, or `fitted()` not called. Killer:
  1. In the design mode with no view, `fitToTables({'3'})`.
  2. Undo the placement of 3, or hide its layer.
  3. Mount: the page is fitted, and `takeFitOnStart()` then answers false.
- **c. Z8, `newPlan` resets the target.** M-Z9 covers `load` only. Add `newPlan`.
- **d. Z8, `setMode` with a view mounted.** M-Z14 covers only the no-view path.
  - Killer: a mounted design view; `fitToTables` then `setMode(selection)` in one
    synchronous step; pump twice. The box is centred in the selection canvas
    within 1e-6 px.
  - Mutants: the `!mounted` guard in `PlannerView._fit` removed
    (`planner_view.dart:171`); the measurement registered after the fit.
- **e. Z1, Z10: trimming and blanks of the request.** `fitToTables({' 3 ', ''})`
  frames 3; `setTableFocus({' 7 '})` focuses 7. Mutant: the input is not trimmed.
  The fixture's ` 7 ` label tests the survey's trim, not this one.
- **f. Z10, "stored unmodifiable".** Mutant: the host's set is aliased. Killer:
  mutating the passed set after the call changes neither `tableFocus.value` nor
  the veil.
- **g. Z16, repaint on the focus.** Mutant: `tableFocus` missing from the merge.
  Killer: count the painter's listener calls, as view test V17 does; a
  `setTableFocus` repaints.
- **h. Z16, rebuild on a service move, an undo, a layer change.** Mutant: the
  rebuild keyed on the focus only. Killer: move a faded table; the veil follows.
  Undo it; the veil follows back.
- **i. Z14, the group painter keyed on the focus.** Mutant: the rebuild key or
  `_groupRepaint` misses `tableFocus`. Killer: set the focus after the first
  paint; the faded frame paint is used. M-Z24 also checks only the frame, so add
  the faded chip.
- **j. Z12, "locked tables fade".** M-Z19 covers unnumbered and hidden only.
- **k. Z2, "locked ones included" in the framing.** M-Z2 covers hidden only.
  Killer: `{'L'}` (locked) returns true and frames it.

### V-4 (minor) — Z14, Z16: the group painter's rebuild key and repaint are unstated

**Fact.**
- `TableGroupPainter` rebuilds on state, tables revision, the groups' identity and
  the paper (`table_group_painter.dart:378-387`).
- `ServiceView._groupRepaint` merges camera, groups, `_changed` and `_paper`
  (`service_view.dart:200-201`).

Z14's "set a flag per group at rebuild" needs both of them to include the focus.
Z16 lists only the veil's merge.

**Fix.** State both changes in Z14. The mutant is V-3i.

### V-5 (minor) — Z13: the rejected style-override is argued on wrong grounds

**Fact.**
- `contextFor(instance, inherited)` is called once per instance
  (`draft_painter.dart:437`).
- `StyleContext` carries `transparency` (`style_context.dart:30-31`).
- `styleFor` reads it for BYBLOCK leaves (`style_resolver.dart:196-199`).

So a wrapper can mark a faded instance in its context and fade in `styleFor`. A
label's slot also names its owner instance (`entities.ownerAt`). "Cannot tell
instances apart" and "misses the number label" are therefore not why it fails.

**Fix.** Argue it on the real grounds:
- Status fills, captions and chips are separate painters that a resolver never
  reaches.
- Swapping the resolver on each focus change rebuilds `DraftCanvas`'s painter
  (`planner_view.dart:46-49`) and puts a per-instance lookup on the gated frame
  path.
- Alpha fades toward whatever lies beneath (status fill, walls), not toward the
  paper.
- Leaves with an explicit transparency ignore the context.

The decision stands.

### V-6 (minor) — R-1, Q-Z6: answered; `Path.combine` is supported on both web renderers

**Fact.** E2: CanvasKit and skwasm both implement it through Skia PathOps, and the
HTML renderer no longer exists in 3.47. E1: the tester behaves as Z13 needs.

**Fix.**
- Downgrade R-1 to a web smoke check (the demo built for web, with a focus) in the
  exit gate. It need not be the first task, nor a fork between Z13 and the
  `saveLayer` fallback.
- Add one line: native `combine` throws `StateError` on a NaN path. The picker's
  rule skips a non-finite **determinant** (`table_picker.dart:175-176`) but not a
  non-finite translation, so skip any quad with a non-finite corner.

### V-7 (minor) — Z5, Z7: a fit uses the size captured at request time

**Fact.** `_onFitRequest` captures `size` when the request arrives and posts
`_fit(size)` (`planner_view.dart:157-165`).

A zone tab that also changes the layout in the same frame frames at the old size.
Examples: Monépro showing or hiding "unplaced tables" beside the view, or the
demo's side panel.

**Fix.** `_fit` reads `_size` when the callback runs; the post-frame callback runs
after this frame's layout. Add a test that changes the view's width and calls
`fitToTables` in the same step.

### V-8 (minor) — Z14: captions can leave the box

**Fact.** Captions are in screen space:
- they sit `max(11, half·scale + 2)` px below the label;
- they are 11 px tall;
- they are checked against the top's **width** only
  (`table_status_painter.dart:327-340`).

At low zoom, the lower part of a faded table's caption can fall outside its box
and stay unveiled. A focused table's caption can fall into a faded neighbour's box
and be veiled.

**Fix.** Record it as a risk (R-5) and make it part of Q-Z3's look. If it shows,
the status painter can skip the captions of faded tables.

### V-9 (minor) — Z18: hidden-layer tables are "placed" yet invisible

**Fact.** `tables` includes hidden-layer tables (`TableSurvey` ignores layers,
`table_index.dart:72-98`). `fitToTables` excludes them, and so does the veil.

Such a table appears neither on the plan nor in Monépro's "unplaced tables" panel,
and its zone tab returns false. The host cannot see why: `FloorPlanTable` has no
visibility, and 14c A-2's "a host reads its layers itself" has no API behind it
(the barrel shows no layers).

**Fix.** Either say this in the guide (do not hide table layers in a served plan),
or add `visible` to `FloorPlanTable`, now that A-2's deferral has a consumer. Put
the choice to the human as Q-Z8.

### V-10 (minor) — Q-Z4, Z18: the code-to-number constraints

**Fact.** 14a T4 (`2026-10-03-table-identity-design.md:177-181`) defines a number:
trimmed, non-empty, at most **8 UTF-16 code units**, no control character, equal
by exact `==`.

A `pos_tables.code` outside those rules can never be a table's number.

**Fix.** Add the constraints to Q-Z4, for Monépro's spec, and to the guide's zone
section. Z18's citation should read "14a T4 (umbrella D2a)".

### V-11 (minor) — Z1, Z7: one candidate rule for both modes

**Fact.** "Visible tables" means the picker's candidates: visible layer, finite
non-zero determinant, non-empty box (`table_picker.dart:170-181`). The design mode
has no picker, so `framingFor` would re-implement the rule. A singular-transform
table would give a degenerate or NaN box.

**Fix.** Extract the rule, for example a static `TablePicker.candidatesOf`, and use
it in `framingFor`, the veil and the picker. Note that the design mode calls
`definitionBounds` with one `leavesByOwner` scan per call, at call rate.

### V-12 (nit) — Z7: `fitted()` and `framingFor` assume the performing view is the active one

**Fact.** `framingFor` resolves against `_active`. `fitted()` accepts any view's
call (`floor_plan_controller.dart:351`).

Two `FloorPlanView`s of one controller, or a host post-frame callback that calls
`setMode` before the view's `_fit`, lets a stale, still-mounted view perform the
framing at its own size and clear `_fitPending`.

**Fix.** Either state that one view per controller is assumed (the shared camera
already makes two views unsupported), or pass the view's document to `framingFor`
and ignore a stale view.

### V-13 (nit) — Facts: precision

- **F-7.** The root-level check is `table_index.dart:77`; `:78` is the nested
  branch.
- **F-13.** "Act on any picked table" is too broad. A locked table is picked and
  reported but never selected or moved (`table_select_tool.dart:180-185, 276`;
  `contextSelect` `:58`).
- **F-4.** It omits `_placeNominally` (`floor_plan_controller.dart:156-165`), which
  also assigns the camera unclamped.
- **F-6.** `aabb2.dart:100-103` should be `:100-108`.
- **F-1.** §2's range is `:148-155`.

### V-14 (nit) — Z3: the margin's rationale

**Fact.** The chip is screen-sized: 11 px text plus padding
(`table_group_painter.dart:26, 331-336`). It sits above the frame, which stands
150 mm out (`:20, 343, 425`).

In world terms, the 500 mm margin holds the chip only at zooms above about
0.1 px/mm. For a large zone, the 5 % fit margin does the work.

**Fix.** Reword the rationale. The values stay Q-Z3's.

### V-15 (nit) — M-Z4, M-Z5: tolerances and the binding axis

**Fact.** Growing about a centre 40 m off the origin can leave the span an ulp
away from 3000, so "exactly" may fail.

In M-Z5, two tables 10 m apart have a y span under 3 m, so the minimum span
applies there. Only the x axis shows the margin if it binds.

**Fix.**
- Use `closeTo` with a relative 1e-12.
- Say that M-Z5's viewport makes x bind.

### V-16 (nit) — API shape

- `fitToTables(Iterable<String>)`, `setTableFocus(Set<String>?)` and
  `select(Set<String>)` differ. Use `Set` for all three, as `select` does.
- "Blanks dropped" makes `setTableFocus({''})` the empty focus, so every table
  fades. Say so.
- Say whether an equal set notifies. Statuses always replace and notify, so the
  focus can do the same.

### V-17 (nit) — Z20, Z21: guide blocks and the probe

If Z15's gating line goes into a fenced `dart` block, `check_guide`
(`tool/ci/lib/guide.dart:34-45`) requires it in the probe. Z21 lists three methods
only, so make the two agree.

The zone section could add one line: a framing frames only the numbers given, so a
group that straddles zones is cut unless the host adds its members.

### V-18 (nit) — Z14: a simpler faded chip

Keep the chips keyed as today. For a group with no focused member, draw the chip,
then the same `RRect` again with the veil's paint.
- The pixels are those of a veil.
- No faded paragraphs are needed.
- The ink rule (`table_group_painter.dart:284-286`) is untouched.
- The faded frame stays one prebuilt `Paint`.

A straddling group's status caption under a faded lead is veiled while its
focused members show the status. Accept that explicitly, or choose the lead among
the focused members.

### V-19 (nit) — Z13, Z16: the paper and the desk

- **Off the sheet.** The canvas outside the sheet is `scheme.surface`
  (`service_view.dart:379-380`), so a table placed off the sheet gets a
  paper-coloured patch. Add this to the Risks.
- **Paper alpha.** `_paper` is ARGB. Use its RGB at 0.6 and ignore its own alpha,
  as `over` does (`table_status_painter.dart:44-58`).
- **Paper changes.** A paper change only recolours the `Paint`; the path does not
  need a rebuild.

## Answers to the review questions

- **Framing box.** For framing, the axis-aligned bound of the four transformed
  corners is right for turned and mirrored tables. The definition box includes
  chairs, and the label sits inside it (14a F-6). For the veil, use the quad
  (V-2).
- **Margin, minimum span, clamp.** The order is sound: margin, then minimum span,
  then fit, then clamp about the centre.
  - The 3 m span makes F-3's flat box unreachable.
  - `kMaxScale` needs `min(W, H) ≥ 315,790` px, and `kMinScale` needs a box over
    950 m on a 1000 px view. So the clamp is dead in practice and harmless.
  - Clamping here while `fitToView` does not is consistent with the camera's
    bounds.
  - Q-Z5: leave the page fit alone.
- **Pending-fit machinery.** Sound, including "last request wins": both bumps read
  the target when they are performed.
  - `load` and `newPlan` resetting the target is right.
  - `setMode` relies on the `!mounted` guard and on the registration order (Facts).
  - `restoreServiceLayout` and `resetLayout` remount and call `takeFitOnStart()`.
    It answers false unless a fit is still pending, which is correct.
  - Gaps: V-3a–d, V-7, V-12.
- **Veil.**
  - It fades the label (drafting) and the status fill and caption (underlay)
    toward the paper and keeps the hue.
  - The dark theme is correct through `displayPaperFor` (`dark_canvas.dart:26-32`).
    `_paper` is refreshed in `didChangeDependencies` and `_onPage`
    (`service_view.dart:267-283`).
  - Overlap: a focused table is never veiled within its quad. A faded table loses
    its overlap with a focused one (R-3). E1 confirms both.
  - Allocation: one `drawPath` per frame meets the non-negotiable.
    `paint_allocation_test.dart` measures `DraftPainter`'s vertices sink in
    `jet_cad_2d_flutter` and does not apply here. 14c R-3's structural recording
    canvas (`table_status_painter_test.dart:145`) is the right gate, and M-Z21
    uses it.
  - The style override: V-5. Web: V-6.
- **Group rules.** The straddling and no-focus rules are consistent with the
  veil's arithmetic: the frame at alpha 0.4 over the paper equals the paper at 0.6
  over the frame. V-4 and V-18 apply.
- **Interaction.** V-1.
- **Persistence and API.** Kept like statuses, not document state: right. On
  null versus empty, trimming and blanks, see V-16. Hidden versus locked is
  consistent between Z2 and Z12. V-9 covers the "placed but invisible" case.
- **Completeness.**
  - The fixtures meet the bar: off the origin, a non-identity camera, turned,
    mirrored, look-alikes.
  - V-2 and V-3 fix the killers that the fixtures alone do not make red.
  - Guide and probe: V-17.
  - CHANGELOG: fine.
  - Demo: the three strings and the per-`Area` state are proportionate.
- **Scope.** Not over-built. For Monépro's zone tabs and its "unplaced tables"
  panel, V-9 and V-10 are the gaps. The faded group chips could be cut (V-18
  makes them cheap).
- **Open questions.**
  - Q-Z1: the camera is `@internal` (`floor_plan_controller.dart:188`), and a
    caption holds 12 characters. D22's several badges will likely need table
    screen rectangles, which belongs in Monépro's phase-2 spec. Agree.
  - Q-Z2: V-1.
  - Q-Z3: the human's look; add V-8 and V-14.
  - Q-Z4: yes, plus T4 (V-10).
  - Q-Z5: no change.
  - Q-Z6: answered (V-6).
  - Q-Z7: agree, no animation.
