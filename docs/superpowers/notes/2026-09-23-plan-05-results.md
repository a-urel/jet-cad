# Plan 05 — drawing tools: results

**Plan:** [2026-09-23-drawing-tools.md](../plans/2026-09-23-drawing-tools.md).
**Spec:** [2026-09-23-drawing-tools-design.md](../specs/2026-09-23-drawing-tools-design.md)
(revision 2, amended at execution — see "Spec amendments" below).
**Mutation log:** [plan-05-mutation-log.md](plan-05-mutation-log.md).
**Branch:** `plan-05/drawing-tools`, worktree
`.claude/worktrees/quizzical-jemison-7537de`, cut from `main` at `7dac3b5`.
**Eleven tasks: Tasks 1–8 at `7dac3b5..c4fcac4`; Task 9 at
`6d98d72..5c55000`; Task 10 (the mutation sweep's invariants and greps,
appended to the mutation log) at `3957d52`;
Task 11 runs in two parts (Ruling T11-a) — Steps 1–4 (this note, the spec
amendments, STATUS and the roadmap) are this commit, and the ledger archive
is deferred to after the final whole-branch review and its fix wave, as the
branch's last commit before the merge.**
**Ledger (per-task briefs, reports, mutation backups, every ruling):**
`.superpowers/sdd/2026-09-23-drawing-tools/` (git-ignored while the plan is
in flight; archived to
`docs/superpowers/ledgers/2026-09-23-drawing-tools/` before the merge,
Ruling T11-a).

---

## What was measured

### The four gate lines, pasted with exit codes

Run once, in full, on the tree of Tasks 1–10 (HEAD `3957d52`, `git status
--short` clean), by Task 10, pasted here rather than re-run — Task 10's own
report (`task-10-report.md`) and the mutation log's "Invariants and greps
(Task 10)" section carry the identical transcript, and this note cites both.
Every summary line below is what the command printed.

**`packages/jet_cad_2d`**: `CI=true dart test`:

```
00:03 +911: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +911: All tests passed!
```

Exit 0. `dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 133
files (0 changed) in 0.23 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test`:

```
00:12 +911 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1. **911 pass, 1 pre-existing skip, and exactly the five pre-existing
`text_ladder_golden_test.dart` failures named above (rungs 1–5,
`RenderBackend.canvas`), and nothing else.** This is the same standing
exception `CLAUDE.md`, `implementer-common.md` and every earlier plan's
gate line have carried since the goldens were recorded on 2026-08-24 on SDK
3.47.2 — pixel drift, not a regression. `flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 175
files (0 changed) in 0.32 seconds.` Exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1`:

```
00:19 +82: All tests passed!
```

Exit 0: **82 tests, unchanged from the branch point.** `git diff --stat
7dac3b5..HEAD -- apps/dev_harness_2d` is empty — this plan touches nothing
under the harness. `flutter analyze`:

```
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 22
files (0 changed) in 0.05 seconds.` Exit 0.

**`apps/floor_planner`**: `CI=true flutter test`:

```
00:03 +43: All tests passed!
```

Exit 0: **43 tests.** `flutter analyze`:

```
Analyzing floor_planner...
No issues found! (ran in 1.2s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 12
files (0 changed) in 0.04 seconds.` Exit 0. `flutter build macos --release`:

```
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)
```

Exit 0. `flutter build web --release`:

```
Compiling lib/main.dart for the Web...                             25.6s
✓ Built build/web
```

Exit 0. **Both builds printed `✓ Built`.**

`git status --short` was clean before Task 10's run and clean after it; no
`analysis_options.yaml` was rewritten by any `flutter analyze`/`pub get`
step. The branch's commit trailers were also checked in the same run
(Ruling P-6): `git rev-list --count 7dac3b5..HEAD` printed **13**, and `git
log --format=%B 7dac3b5..HEAD | grep -c "Co-Authored-By: Claude"` also
printed **13** — one trailer per commit, none missing.

### Where the counts differ from the plan's arithmetic, and why

The plan predicted each count as the branch point (`7dac3b5`: engine 894,
render layer 854 + 1 skip + the five goldens, harness 82, app 26) plus the
tests this plan lands. **Report what ran, not the sums** — three of the four
suites landed exactly on the plan's own prediction; the fourth, the app, did
not, and the difference is explained below.

| suite | branch point | planned additions | planned total | ran | difference |
|---|---|---|---|---|---|
| `jet_cad_2d` | 894 | +10 (E) +7 (S) | 911 | **911** | **0** |
| `jet_cad_2d_flutter` | 854 | not summed by the plan (`test/draw/`, counted from the run) | — | **911** | — |
| `dev_harness_2d` | 82 | 0 | 82 | **82** | **0** |
| `apps/floor_planner` | 26 | +12 (A) +2 (SP) | 40 | **43** | **+3** |

- **Engine: exact match.** Task 1's `drafting.dart` builders and
  `SweepTracker` added **E1–E10** (894 → 904), and Task 2's
  `sweep_tracker_test.dart` added **S1–S6 plus the differential** (904 →
  911). `894 + 10 + 7 = 911`, exactly the plan's own sum.
- **Render layer: the plan deliberately did not sum this one** ("count them
  from the run; the per-flipY loops double some"), so there is no
  arithmetic to be off from. The per-task path, from the ledger:
  854 → **873** (Task 3, `+19`: `PlacementTool`/`LineTool`'s B- and
  L-series, doubled by `flipY`) → **892** (Task 4, `+19`: the polyline,
  rectangle and overlay series) → **903** (Task 5, `+11`: circle and arc,
  net of Ruling T5-a's AR5 replacement) → **911** (Task 6, `+8`: the text
  tool). Tasks 7–9 add nothing here — they touch only `apps/floor_planner`.
  Net: **+57** over the branch point.
- **App, +3 over the plan's sum: Task 7's fix round added A13, A14 and
  A15.** The plan wrote 12 tests for Task 7 (A1–A12); the task's own review
  found two gaps the plan itself implied but did not test —
  Ruling T7-b (a window switch must not cancel a pending text) and Ruling
  T7-c (Escape must reach the shortcut guard's map, not just the letters
  and the undo keys) — and the fix round closed them with three new tests
  rather than two, because the lifecycle guard's null-state behaviour
  (Ruling T7-b) needed both a positive test (A13, the window switch
  survives) and its own regression test bundled with the Escape gap's fix
  (A15, an ordinary in-app blur still cancels, covering the null-state
  change). A10, already in the plan's 12, was **amended** in place for
  Ruling T7-a rather than added. So Task 7 alone landed 15 tests (A1–A15,
  26 → 41), not the plan's 12, and Task 8 added the sample-plan pair
  (SP1, SP2; 41 → 43) exactly as planned. `26 + 15 + 2 = 43`.
- **Harness: exact match, by construction.** No task's file list touches
  `apps/dev_harness_2d`, and `git diff --stat 7dac3b5..HEAD --
  apps/dev_harness_2d` is empty.

### The differential

`SweepTracker` is checked against a brute-force reference (64 sub-samples
per step, seed `0x5EED0005`, 500 trials, sign exact and magnitude within
`Tolerance.standard.angular`; a trial within `1e-6` of a multiple of `2π` is
skipped and counted). The test's printed line (Task 2's report, and the
gate run above):

```
SWEEP differential: checked 500, skipped 0
```

500 checked, 0 skipped — no trial in this seeded run landed close enough to
a multiple of `2π` to need the skip rule. This is the same test named as
`AR1–AR4`'s and `S2–S6`'s differential witness for exit criterion 8 below.

### Mutation tally

From [plan-05-mutation-log.md](plan-05-mutation-log.md): **30 fired, 30
killed, 0 survived, 0 equivalent** — 26 named mutants (M-05a…M-05z) plus
M-05w′, the reviewer-noted second form of M-05w, from the original sweep
(Task 9), plus M-05aa, M-05ab and the F-3 kill from the final
whole-branch review's fix wave. M-05w′ first fired as a **survivor**
against the original PL8 fixture (Task 9); fix round 1 (Ruling T9-a)
changed PL8's fixture geometry only (test-only: the first vertex moved to
`anchor + Offset(13, 0)`, the close click to `anchor + Offset(5, 0)`), and
both M-05w and M-05w′ were re-fired against the new fixture and both now
go red. Task 10's own review independently re-fired five of the
twenty-seven (M-05a, M-05i, M-05u — by test-name analogy to Plan 03's
practice — the exact re-fired set is Task 10's own report) and got the
same failures each time.

**The final fix wave's three mutants** (Rulings F-1, F-2, F-3): M-05aa
(the kitchen counter moved back to its old, colliding coordinates — killed
by `SP3`), M-05ab (the F3/F mid-shape exception dropped from
`PlacementTool.onKey` — killed by `B10` and `A16`), and the F-3 kill (the
returning tool's `_hoverVisible = false` dropped from `cancel` — killed by
`B11`). Detail in the mutation log's "Final fix wave" section.

---

## Exit gate

The spec's fourteen criteria and where each is witnessed:

| # | criterion | witness |
|---|---|---|
| 1 | each tool, documented geometry, both cameras | B1, L1, PL1, PL3, R1, C1, AR1, TX1 |
| 2 | one shape, one undo step; redo, same handles | E4, L1, L4, PL1, PL4, R3, C2, TX2, A11 |
| 3 | a snapped start is exact | B2, L1 |
| 4 | Escape, tool switch, dispose: byte-identical | B4, B9, PL9, TX5, A6, A10 |
| 5 | a rectangle round-trips closed, plain and filled | E5, R5 |
| 6 | text at the requested cap height | E7 |
| 7 | the palette and shortcuts reach all seven tools and Fill; an idle Escape returns | A1, A2, A4 |
| 8 | the arc's direction follows the pointer; the differential | S2–S6, AR1–AR4, the differential (`SWEEP differential: checked 500, skipped 0`) |
| 9 | Fill: regions, the fallback, the kinds that ignore it | E9, PL4, PL5, R3, R4, C2, AR5 |
| 10 | the sample plan's furniture is filled over the finishes | SP1, SP2, SP3 |
| 11 | every mutant killed | [plan-05-mutation-log.md](plan-05-mutation-log.md): 30 fired, 30 killed |
| 12 | the allocation invariants unedited; the overlay's structural test | Task 10's greps (invariant 4 and the allocation tests unedited), OV1, OV2 |
| 13 | the four gate lines, the five goldens only, both builds | above, from Task 10's run |
| 14 | the human's look | **OWED (this task): not looked at; the human looks after this branch is presented** |

**13 of 14 PASS.** Criteria 1–13 are PASS, each with its witness above.
Criterion 14 is OWED, itemised per platform below, and is never marked done
by this task.

### Review Focus items and their tests

Five inputs the spec implies but no exit criterion names by itself, each
with the test in the task that owns the code:

1. **A shortcut letter or cmd+Z typed into the page panel's scale field**
   must not switch tools or undo the document — `A9` (Task 7), backed by
   Ruling 05-8 (the guard also wraps the page panel and maps the undo
   keys).
2. **Two drawing-tool shortcuts in a row mid-shape.** The plan's own text
   predicted "switching must cancel the pending polyline byte-identically
   and arm Line"; **Ruling T7-a supersedes that prediction**, because spec
   D3 outranks the plan's own Review Focus wording — every key-down
   mid-shape is swallowed, so a letter does not switch tools at all while
   a shape is pending. `A10` (Task 7, renamed and amended in the fix
   round) now asserts that pressing `L` mid-polyline is ignored and the
   `PolylineTool` instance stays pending, and that a **palette** switch
   still cancels byte-identically.
3. **A pan or zoom mid-shape followed by a click** must land at the new
   camera's world point, not a stale hover — `B6` (Task 3), one of the two
   Important findings fixed in that task's own review round
   (Ruling T3-a).
4. **A polyline closed on a tiny triangle**, all three vertices inside
   each other's aperture: the first vertex (close) must win over the last
   (finish open) once at least three vertices are placed — `PL7` (Task 4).
5. **Undo right after a commit**, tool still armed, nothing pending: cmd+Z
   must reach the shell and remove exactly that shape, and the idle tool
   must not swallow it — `A11` (Task 7).

### Debt

- **The text field's font jump.** `TextEntryOverlay`'s `TextField` renders
  in Flutter's own default text style while it is being typed; the
  committed entity renders through the engine's paragraph pipeline at the
  requested cap height. The two are never reconciled, so the string's
  apparent size (and possibly its face) changes the instant Enter commits
  it. This is exactly what look item 10 asks a human to judge, on every
  platform.
- **No fill preview.** Per spec D13, "the rubber band does not show the
  fill; the preview is the outline only." A rectangle, circle or closed
  polyline drawn with Fill on shows only its outline while pending; the
  grey fill appears only on commit. Not a defect — the spec says so — but
  worth a human's eye at look item 4.
- **The app camera in `planner_grips_test.dart` is still a reflection.**
  Plan 03's b/c-transposition finding was closed for the render layer on
  `fix/grip-camera-bc-swap` (six render-layer test files gained an
  unflipped `gripCamera(flipY: false)` pass), but the app-level grips test
  fixture was never touched by that fix and still uses a reflecting
  camera. Plan 05 does not touch `planner_grips_test.dart` and inherits
  this exactly as Plan 03 left it.
- **The sample-plan count margin (Ruling 05-12).** The rebuild turns 30
  furniture entities into 8 filled regions (16 entities: 8 boundaries + 8
  fills), dropping the sample plan's live count from 523 (measured at
  `5ea98dd`) to **509** (`SP1` in `startup_plan_test.dart`, exactly
  `523 − 14`). `startup_plan_test`'s `[500, 1000]` bound and
  `planner_shell_test`'s `>= 500` bound both still pass, with a margin of
  **9** entities. A later cut to the sample plan that removes ten or more
  entities would need to re-check both bounds.
- **A platform pointer-cancel drops the whole pending shape (Ruling F-4,
  final review).** `InteractionLayer._onCancel` (02, frozen by invariant 4)
  maps every `PointerCancelEvent` straight to `tool.cancel(ctx)` --
  the same call Escape makes. For a `PlacementTool` that means
  `clearShape()`: a system gesture taking over, or a window losing pointer
  capture, mid-polyline loses every vertex placed so far, not just the one
  in flight. Not fixed in this fix wave: the controller ruled it debt, to
  be picked up if 02's API is ever reopened.

---

## Criterion 14: the human's look — OWED

**Not looked at. The human looks after this branch is presented.** No
device run and no visual judgement was simulated to fill it in. Run it on
each platform:

- **macOS:** `cd apps/floor_planner && flutter run -d macos --release`;
- **Chrome:** `cd apps/floor_planner && flutter run -d chrome --release`;
- **Firefox:** `build/web`, served statically (`cd
  apps/floor_planner/build/web && python3 -m http.server`).

Thirteen items per platform (the final review added 11–13, Rulings F-1,
F-2 and F-5). Record each as **seen / not seen / could not judge**.

### macOS: `flutter run -d macos --release`

1. Every tool once. The palette highlights the active tool, and the top
   bar names it. ☐ seen ☐ not seen ☐ could not judge
2. A line chain snapped onto a wall end, and ended by clicking its start.
   ☐ seen ☐ not seen ☐ could not judge
3. A polyline closed by clicking its first vertex, with Fill on and then
   off. ☐ seen ☐ not seen ☐ could not judge
4. A rectangle and a circle with Fill on: grey fills under their outlines.
   ☐ seen ☐ not seen ☐ could not judge
5. An arc drawn clockwise, then counter-clockwise, then across the
   left-hand horizontal. ☐ seen ☐ not seen ☐ could not judge
6. Text: T, click, type "Living room" (it contains `l`, `v`, `r`), Enter.
   Then Escape on a second one, and a canvas click on a third.
   ☐ seen ☐ not seen ☐ could not judge
7. Escape mid-shape and then undo: one step per shape.
   ☐ seen ☐ not seen ☐ could not judge
8. The filled furniture over the tiles and the parquet.
   ☐ seen ☐ not seen ☐ could not judge
9. Whether the browser also takes any single letter, or F. **Not
   applicable on macOS** — recorded here only to keep the item numbering
   aligned with Chrome and Firefox below.
   ☐ not applicable
10. Whether the text field's position and font jump on commit are
    acceptable. ☐ seen ☐ not seen ☐ could not judge
11. Every door's leaf and swing arc, clear of the counter, the beds and
    the sofa (Ruling F-1). ☐ seen ☐ not seen ☐ could not judge
12. F3 pressed mid-polyline: the OSNAP indicator flips and the polyline
    stays pending (Ruling F-2). ☐ seen ☐ not seen ☐ could not judge
13. A text placed near the canvas's top and right edges: whether the
    field clips (Ruling F-5). ☐ seen ☐ not seen ☐ could not judge

### Chrome: `flutter run -d chrome --release`

1. Every tool once. The palette highlights the active tool, and the top
   bar names it. ☐ seen ☐ not seen ☐ could not judge
2. A line chain snapped onto a wall end, and ended by clicking its start.
   ☐ seen ☐ not seen ☐ could not judge
3. A polyline closed by clicking its first vertex, with Fill on and then
   off. ☐ seen ☐ not seen ☐ could not judge
4. A rectangle and a circle with Fill on: grey fills under their outlines.
   ☐ seen ☐ not seen ☐ could not judge
5. An arc drawn clockwise, then counter-clockwise, then across the
   left-hand horizontal. ☐ seen ☐ not seen ☐ could not judge
6. Text: T, click, type "Living room", Enter. Then Escape on a second one,
   and a canvas click on a third. ☐ seen ☐ not seen ☐ could not judge
7. Escape mid-shape and then undo: one step per shape.
   ☐ seen ☐ not seen ☐ could not judge
8. The filled furniture over the tiles and the parquet.
   ☐ seen ☐ not seen ☐ could not judge
9. Whether the browser also takes any single letter, or F — Chrome binds
   F3 to find-next (Plan 03's debt); the shell here does not bind F3, but
   the shortcut letters (`V L P R C A T F`) and Escape/Enter are worth
   watching for a browser default action stealing one.
   ☐ seen ☐ not seen ☐ could not judge
10. Whether the text field's position and font jump on commit are
    acceptable. ☐ seen ☐ not seen ☐ could not judge
11. Every door's leaf and swing arc, clear of the counter, the beds and
    the sofa (Ruling F-1). ☐ seen ☐ not seen ☐ could not judge
12. F3 pressed mid-polyline: the OSNAP indicator flips and the polyline
    stays pending (Ruling F-2). ☐ seen ☐ not seen ☐ could not judge
13. A text placed near the canvas's top and right edges: whether the
    field clips (Ruling F-5). ☐ seen ☐ not seen ☐ could not judge

### Firefox: `build/web`, served statically

1. Every tool once. The palette highlights the active tool, and the top
   bar names it. ☐ seen ☐ not seen ☐ could not judge
2. A line chain snapped onto a wall end, and ended by clicking its start.
   ☐ seen ☐ not seen ☐ could not judge
3. A polyline closed by clicking its first vertex, with Fill on and then
   off. ☐ seen ☐ not seen ☐ could not judge
4. A rectangle and a circle with Fill on: grey fills under their outlines.
   ☐ seen ☐ not seen ☐ could not judge
5. An arc drawn clockwise, then counter-clockwise, then across the
   left-hand horizontal. ☐ seen ☐ not seen ☐ could not judge
6. Text: T, click, type "Living room", Enter. Then Escape on a second one,
   and a canvas click on a third. ☐ seen ☐ not seen ☐ could not judge
7. Escape mid-shape and then undo: one step per shape.
   ☐ seen ☐ not seen ☐ could not judge
8. The filled furniture over the tiles and the parquet.
   ☐ seen ☐ not seen ☐ could not judge
9. Whether the browser also takes any single letter, or F.
   ☐ seen ☐ not seen ☐ could not judge
10. Whether the text field's position and font jump on commit are
    acceptable. ☐ seen ☐ not seen ☐ could not judge
11. Every door's leaf and swing arc, clear of the counter, the beds and
    the sofa (Ruling F-1). ☐ seen ☐ not seen ☐ could not judge
12. F3 pressed mid-polyline: the OSNAP indicator flips and the polyline
    stays pending (Ruling F-2). ☐ seen ☐ not seen ☐ could not judge
13. A text placed near the canvas's top and right edges: whether the
    field clips (Ruling F-5). ☐ seen ☐ not seen ☐ could not judge

**Nothing above is ticked on the human's behalf.** No finding, no verdict
and no `fix/` branch exists for Plan 05's look, because it has not
happened.

---

## Rulings

### The plan's rulings, 05-1…05-15

Each ruling is one line, with what it costs if it is wrong. The ones marked
**(spec amended)** are written into the spec below.

- **05-1 (spec amended, D8 and the differential):** `SweepTracker` never
  clamps its accumulated travel `τ`; only its sign is read, and the swept
  magnitude already comes from `δ ∈ (0, 2π)`. Cost if wrong: none, the
  magnitude never exceeds `2π` either way.
- **05-2 (spec amended, D4):** a self-snap's hover marker is drawn through
  `drawSnapMarker(..., SnapKind.endpoint, ...)`, the same function object
  snap uses, rather than a bespoke square. Cost: none.
- **05-3:** `commit` takes a builder closure and checks permission before
  calling it, so a denied shape allocates no handle. Cost: one closure per
  commit, off the frame path.
- **05-4:** the base passes self-snap's own stored `Vector2` instance to
  `accept` (never a copy), and the polyline closes by appending exactly
  that instance. Cost: none.
- **05-5:** M-05k is defined as re-deriving the chained line's next start
  through a screen round trip (`screenToWorld(worldToScreen(p))`), fired
  against a fixture whose first end sits at off-lattice coordinates so the
  round trip visibly moves a bit. Cost if wrong: the mutant is equivalent
  at that fixture, and the mutation log says so.
- **05-6 (spec amended, D5):** the palette and the Fill checkbox are
  wrapped in `ExcludeFocus`; "focus stays on the canvas" holds because the
  canvas is `autofocus: true` and re-takes focus on every pointer-down.
  Cost if wrong: a keyboard user cannot tab into the palette (12's
  accessibility work).
- **05-7:** focus leaves the text field with
  `unfocus(disposition: previouslyFocusedChild)`, landing back on the
  canvas's `Focus`. Cost if wrong: focus lands on the scope and the shell's
  shortcuts stop until the next canvas click.
- **05-8 (spec amended, D5 and D9):** the shortcut guard also wraps the
  page panel's scale field, and also maps meta+Z/ctrl+Z, so cmd+Z typed
  into either field never undoes the document. Cost if wrong: cmd+Z inside
  a field does not undo the field's own text on some platforms.
- **05-9 (spec amended, Testing):** M-05v's test asserts that
  `tester.sendKeyEvent(...)` returns `false` and the tool is unchanged,
  because `flutter_test` cannot turn a raw key event into `EditableText`
  input, so "the field reads late" cannot itself be observed under a key
  event. Cost: none; this is the mechanism itself.
- **05-10:** M-05u is detected by the identity of `EditableTextState`
  across a pan, since the text lives in the tool's controller and the
  focus node in the overlay's `State`, and only a remount loses the IME
  connection. Cost: none.
- **05-11 (spec amended, D9):** the text field is 240×32 logical px, and
  "baseline-left" is approximated by the field's bottom-left, at the
  insertion point's screen position, within 0.5 px. Cost: the typed text
  sits a few pixels above the committed text — an open spec question, and
  look item 10.
- **05-12:** the sample plan's live count goes from 523 to 509 (30
  furniture entities become 8 regions, 16 entities). Cost if wrong: a
  later sample-plan cut drops below the 500 floor; the margin is recorded
  above as 9.
- **05-13:** a pointer move with the primary button held is a hover, not a
  drag; only `onPointerDown` places a point. Cost: a press-drag-release
  draws nothing extra (AutoCAD's own behaviour).
- **05-14:** key-ups are always `ignored` except shift, which re-resolves
  the hover. Cost: none; matches 03.
- **05-15:** M-05p's mutant is concrete — `commitShape` executes the
  region's boundary and fill as two separate `AddEntityCommand`s instead of
  one `AddRegionCommand`. Cost: none; it is the realistic "two commands"
  bug.

### The controller's rulings, from the ledger

- **P-1:** this session's worktree hosts the branch, replacing the plan's
  named `.claude/worktrees/plan-05-drawing-tools`, because this session's
  writes are confined to its own worktree. Cost if wrong: none, the branch
  and its history are identical either way.
- **P-2:** the ledger is archived, not deleted, to
  `docs/superpowers/ledgers/2026-09-23-drawing-tools/` as the branch's last
  commit. Cost if wrong: none.
- **P-3:** implementers ran on Sonnet (the plan carries complete code);
  task reviewers ran on Sonnet for Tasks 1–2 (pure engine) and Opus for
  Tasks 3–8 (interaction, focus, key routing); the final review runs on
  Opus. Cost if wrong: a missed defect surfaces at the final review.
- **P-4:** Tasks 9–11 are dispatched too — Task 9 (mutation firing) and
  Task 10 (greps) to one Sonnet implementer each, Task 11's docs to Sonnet
  with the counts verified by the controller. Cost if wrong: none.
- **P-5:** the plan's file table lists PL1–PL8 for Task 4, but the task
  text (PL9, M-05l's test) governs. Cost if wrong: none.
- **P-6:** a commit trailer names the model that actually wrote the
  commit, replacing the plan's fixed "Opus 5.5" trailer and its grep
  check with `grep -c "Co-Authored-By: Claude"`. Why: attribution must be
  truthful (Plan 03's Ruling T2-a). Cost if wrong: none.
- **T3-a:** both of Task 3's Important review findings were fixed in
  place — B6/B7's hover exactness after a pan, and L5's Tolerance fixture
  — because the spec binds Review Focus 3 and the reviewer showed each
  test could not fail under its named mutant otherwise. Cost if wrong: two
  test-only edits.
- **T5-a:** AR5 is replaced by an arc degenerate-radius test, because the
  review found the plan's AR5 could never fail — the fill notifier is
  never passed to `ArcTool`, so "the arc ignores Fill" holds by
  construction regardless of what AR5 checked. The new AR5 kills a real
  mutant, dropping `isDegenerateRadius` in `ArcTool`. Cost if wrong: exit
  criterion 9's "arc ignores Fill" loses its test witness and is argued
  from the constructor instead.
- **T7-a:** spec D3 wins over the plan's own Review Focus 2 — every
  key-down mid-shape is swallowed, so a tool shortcut does not switch
  tools mid-polyline; switching mid-shape needs Escape first, or the
  palette, and `ToolController.activate` cancels byte-identically either
  way. Why: the spec is binding, and Review Focus 2 was the plan's own
  addition, contradicting D3 and B5. Cost if wrong: a user must press
  Escape before a tool letter mid-shape; the look (criterion 14) judges
  it.
- **T7-b:** D9's "any other loss of focus cancels" means a loss of focus
  *inside* the app. While the app is not resumed the field ignores its
  blur, and the focus manager restores it on resume with the text intact;
  a `null` `WidgetsBinding.instance.lifecycleState` (its value before the
  first lifecycle message, and what `flutter_test` resets it to) counts
  as resumed, not as a loss of focus. Why: a window switch otherwise
  cancelled the text and left focus on the root scope, so every shell
  shortcut went dead; the reviewer reproduced it with a probe. Cost if
  wrong: typed text survives a window switch, which a user would likely
  expect anyway.
- **T7-c:** Escape joins the shortcut guard's map, because D9 names
  "Escape … as the shell binds them" and the shell binds Escape. Without
  it, Escape typed into the page-scale field dropped a pending shape
  instead of the field handling it. Cost if wrong: none.
- **T9-a:** PL8's fixture changes in Task 9 — the first vertex moves to
  `anchor + Offset(13, 0)` and the close click to `anchor + Offset(5,
  0)` — because M-05w′ (self-snap applied to the already-resolved point,
  not the raw click) survived the original PL8 geometry by coincidence of
  its exact distances, as the Task 4 reviewer had predicted. The spec
  permits no designed survivor, and the fix is test-only. Cost if wrong:
  none.
- **T10-a:** Task 10's review is the controller re-running its own checks
  rather than a fresh dispatch, because the deliverable is command
  transcripts, not code. Reproduced: both diffs 0, one `Path()` hit, one
  `handleSeed` hit (pre-existing, `startup_plan.dart`'s `_Pen`), 13 of 13
  trailers, the 3 pure-Dart hits pre-existing doc comments. Cost if wrong:
  none.
- **T11-a:** Task 11 runs in two parts. Steps 1–4 (this note, the spec
  amendments, STATUS, the roadmap) come before the final whole-branch
  review; the ledger archive comes after that review and its fix wave, as
  the branch's last commit, exactly as Plan 03 did. Cost if wrong: none.

---

## Deviations from the plan

**Review-driven test changes**, each already recorded above as a ruling:
Task 3's B6/B7 and L5 fixes (Ruling T3-a); Task 5's AR5 replacement
(Ruling T5-a); Task 7's fix round, which renamed/amended A10 and added
A13–A15 (Rulings T7-a, T7-b, T7-c); Task 9's fix round, which changed
PL8's fixture geometry to kill M-05w′ (Ruling T9-a).

**Flutter behaviours that differed from the plan's own code**, from
`task-7-report.md`:
- **The lifecycle guard needed a null check the plan's line did not have.**
  The coordinator's line was `if (lifecycleState != resumed) return;`.
  `WidgetsBinding.instance.lifecycleState` is `null` until the first
  lifecycle message arrives, and `flutter_test` resets it to `null` before
  every test (`resetInternalState`), so the literal line would have
  switched off D9's "any other loss of focus cancels" in every test and on
  a cold app start. The implemented guard adds `lifecycle != null &&`
  before the comparison (Ruling T7-b); A15 pins the difference against the
  literal line as a named mutant, `literalGuard`.
- **`PlannerView`'s root is a `Flow`, not the spec's `Stack`** (Ruling
  T7-d, written into D9's amendment below). With the spec's literal
  `Stack[CameraGestureDetector(…), TextEntryOverlay]`, removing the text
  overlay mid-build while a text was pending raised "markNeedsBuild()
  called during build". A `Flow` orders the overlay's deactivation first,
  at the same paint and hit order (`RenderFlow` hit-tests in reverse child
  order like `Stack`, and is a repaint boundary that clips to its bounds
  the same way), and the assertion does not fire.

**R2's coordinates** (Task 4): moved off a 20 mm grid tie, from 7010 to
7009, because at 7010 the rectangle's second corner coincided with a grid
snap point and the test could not tell a resolved click from a grid-snapped
one apart. The Task 4 reviewer accepted the change as test-only.

**AR5's replacement** (Task 5, Ruling T5-a above): the plan's AR5 asserted
"the arc ignores Fill" by checking the committed arc against a fill
notifier the tool is never given — a test that cannot fail no matter what
the production code does. The task's review replaced it with a test of
`ArcTool`'s degenerate-radius refusal, which does fail under a real named
mutant (dropping `isDegenerateRadius`).

**PL8's fixture** (Task 9, Ruling T9-a above): moved the polyline's first
vertex from its original position to `anchor + Offset(13, 0)` (outside the
10 px snap aperture from the anchor) and the closing click to `anchor +
Offset(5, 0)`, because the original geometry left M-05w′ an undetected
survivor — the anchor's object-snapped endpoint sat close enough to the
polyline's own first vertex, by coincidence, that self-snap still found
the right point even when applied to the wrong (already-resolved) input.

**Only the first test or group in each draw test file loops over both
`flipY` values.** `placement_tool_test.dart`'s B1–B3 (inside the `for
(flipY in ...)` loop) and each tool's first test (`L1`, `PL1`/`PL3`, `R1`,
`C1`, `AR1`, `TX1`) run at both cameras; every later test in the same file
(B4 onward, L2 onward, and so on) runs once, at the file's default
camera. This was true of the branch before this fix wave and stays true
of the tests this wave adds (`B10`, `B11`, `A16` each run once).

---

## Spec amendments

Recorded where each applies, in
[2026-09-23-drawing-tools-design.md](../specs/2026-09-23-drawing-tools-design.md).
Each is a paragraph beginning "**Amended at execution (Plan 05):**" (D3's,
added by the final whole-branch review's fix wave, "**Amended at
execution (Plan 05, final review):**"), appended at the end of the
relevant section. Nothing original is rewritten.

- **D3:** Ruling F-2 (final whole-branch review) — a key-down of F3 or F,
  with no control/meta/alt modifier held, returns `ignored` even mid-shape
  instead of the section's "every other key-down" `handled`, so both
  bubble to the shell (object snap and Fill); neither ever touches the
  document, so D3's reason for swallowing every other key-down does not
  apply to them.
- **D4:** Ruling 05-2 — the self-snap hover marker is drawn through the
  engine's own `drawSnapMarker(..., SnapKind.endpoint, ...)`, which *is*
  the "own endpoint square" D4 calls for, rather than a second, bespoke
  square.
- **D5:** Ruling 05-6 (the palette and Fill checkbox take no focus at all,
  via `ExcludeFocus`, rather than acting on `InteractionLayer`'s private
  focus node) and Ruling 05-8 (the guard also wraps the page panel and
  maps the undo keys). Plus two findings from Task 7's fix round:
  Ruling T7-a (spec D3 outranks this plan's own Review Focus 2 — every
  key-down mid-shape is swallowed, so switching tools mid-shape needs
  Escape or the palette, never a shortcut letter) and Ruling T7-c (Escape
  joins the guard's map alongside the letters and the undo keys, so it
  reaches a focused field's own handling instead of dropping a pending
  shape at the shell).
- **D8 and the differential:** Ruling 05-1 — `SweepTracker`'s accumulated
  travel is never clamped, only its sign is read, and the differential's
  skip rule is stated in terms of the true travel and of `δ`, not of `τ`.
- **D9:** Ruling 05-8 (the guard also covers the text field, so cmd+Z /
  ctrl+Z typed there never reaches the document) and Ruling 05-11 (the
  field is 240×32 logical px, and "baseline-left" is approximated by its
  bottom-left). Plus two findings from Task 7's fix round: Ruling T7-b
  ("any other loss of focus cancels" means a loss of focus *inside* the
  app; a `null` lifecycle state, which is what the state reads before the
  first lifecycle message and what `flutter_test` resets it to, counts as
  resumed, not as a cancelling blur) and Ruling T7-d (`PlannerView`'s root
  is a `Flow`, not a `Stack` — a `Stack` raised "markNeedsBuild() called
  during build" on a mid-build removal with text pending; a `Flow` keeps
  the same paint and hit order while ordering the text overlay's
  deactivation first).
- **Testing:** Ruling 05-9 (M-05v's test asserts the key event is not
  consumed and the tool is unchanged, because `flutter_test` cannot
  observe "the field reads late" under a raw key event) and the
  widget-test additions **A13–A15** from Task 7's fix round: A13 (a
  window switch with text pending: the field, its controller and its text
  survive `inactive` → `resumed`), A14 (Escape typed into the page-scale
  field reaches the field, not the shell — the polyline stays pending),
  and A15 (an ordinary in-app blur, the null-lifecycle case excluded,
  still cancels a pending text, per D9's original rule).

---

## Files this task touched (Steps 1–4)

- `docs/superpowers/notes/2026-09-23-plan-05-results.md`: this file.
- `docs/superpowers/specs/2026-09-23-drawing-tools-design.md`: the six
  "Amended at execution" paragraphs above (five from Steps 1–4, plus D3's
  from the final whole-branch review's fix wave), appended. Nothing was
  rewritten.
- `STATUS.md`: a Plan 05 section, the header, and the "Resume here"
  paragraph.
- `roadmap/05-drawing-tools.md`: the status line.
- `roadmap/00-README.md`: the 05 row in the status table.

Task 11 touched no code. The ledger archive (Step 5's second commit) is
deferred to after the final whole-branch review and its fix wave
(Ruling T11-a).
