# Plan 10 mutation log -- the spec's 51 mutants, the plan-owned additions and the tasks' extras

**Tally, after fix round 1: 362 mutants fired, each edit defined afresh
against `749c277` (Task 18, approved) and fired there, none copied from the
ledger: 331 killed, 26 equivalent (fired, and they survive as argued or as
ruled), 5 accepted (cost) (fired, green; they change only what the code
costs, and a ruling accepts each), 0 surviving at HEAD, no false
equivalent.** Four kills came after a fixture fix, each in its own commit:
`M-10hover` (`ee610fd`, `TT6`), and, in fix round 1 (the audit of
`d1a81d8`), `X11-feet` and `rv14b-splitOnce` (`4b12f65`, `RA1` and `DE1`),
with `X14-sc-boxGuard` re-fired at the killer the first run missed
(`SD6`). Plus 4 controls (M-10b's least-absolute-area form, and the
degenerate rectangle under M-10a, M-10b and M-10c), which behave as the
spec says, and 8 re-fires (5 after the first run: 4 at the killer the first
run's command missed, including `M-10hover` at the fixed `TT6`, and 1 wider
equivalence probe; 3 in fix round 1). 374 fires in all; 374 restores, every
one `diff` exit 0 and `git diff --quiet` exit 0.

**Fix round 1** (the audit of `d1a81d8`, which found no fabrication: its 69
re-fires reproduced at the logged test and line). Its findings, fixed:

- **I-1, three false equivalents.** `X14-sc-boxGuard` is byte-identical to
  `X6-readAlways`, killed at `SD6` (`place_test.dart 704`, `(0, 2)` against
  `(0, 0)`); the first run fired it at `RK1` only. `X11-feet` is not a
  one-ulp no-op: at a tie it moves the label (28.12 against 28.13 ft² for
  1,524 × 1,714.5 mm, exactly 28.125 ft²); `RA1` gains the case, red at
  `room_label_test.dart 193`. `rv14b-splitOnce` is reached by a star of
  1,002 small columns tied to one column; `DE1` gains it at all six
  placements (1.9 s for the six, so all six were kept), red at
  `room_tie_test.dart 428` (1,004 holes against 1,003).
- **m-1.** `rv16-noMemo` is plan-10 code (the Room section's Area memo),
  not a probe of 07/08 code: fired, green, accepted (cost). N/A is 16.
- **m-2.** Cost-only survivors are listed as "accepted (cost)", each with
  its ruling, not as equivalents.
- **m-3.** The index repeated the spec table; fixed.

The app gate after fix round 1, at `4b12f65` with this log's edit
uncommitted: `01:24 +348: All tests passed!` (the new cases sit inside
`RA1` and `DE1`); `flutter analyze` `No issues found!`; `dart format`
81 files, 0 changed; `✓ Built build/web`; line exit 0.

- **The spec's 51 named mutants:** one per site or form (Ruling
  10-26): M-10dissolve at three (the engine's planner in the spec's form
  and in the plan's "never asks" form, and `RoomType.dissolves`),
  M-10pagekey at two (the engine's comparison, `RoomType.pageKey`),
  M-10offset at two (`RoomType.generate`'s anchor, `RoomGrips`' pole),
  M-10sep at two (the tracer, the inputs), M-10preview at two (the path,
  the point cross), M-10grow and M-10pin in two forms each, M-10trim once
  (one site, `trimSeparator`, fired against both the tool's `ST2` and the
  grips' `GR5`), M-10ring once (one site, fired against `OL1` and `OL4`),
  plus M-10inputbox's literal form (equivalent, Task 6): 60 fires, and
  M-10b's control besides. **All 51 are killed at HEAD** (58 fires red at `749c277`,
  `M-10hover` red at `ee610fd`, the literal form green), every
  killer the plan's Mutant assignment table names red at every site it
  reaches, with three recorded exceptions, each consistent with a ruling:
  `M-10cert`'s `DF1` stays green (the Task 14 re-review: its app-level
  killers are `FZ1` and `LZ2`, not `DF1`); `M-10offset`'s grip site is
  green under `RL3` (a model-level test that never uses the grip; `GR1`
  kills it); `M-10pagekey`'s room site is green under `RN6`, an extra
  command this task added (`RA2`, the ledger's killer, kills it).
- **The one survivor, a finding, fixed:** `M-10hover` (the hover never
  short-circuits on the bounding box) survived `TT6` at `749c277`. Task
  15's fix round added the outer-contour cache, which answers a hover
  outside every contour with the same verdict and no trace; once any
  hover had built the contours, the bounding-box short-circuit's absence
  changed nothing `TT6` counted. The fixture was fixed, not the mutant
  (`ee610fd`): `TT6` first hovers its four points outside the box on a
  fresh generation, asserts each premise (outside the box), and asserts
  no trace **and no contour build**. Both runs are logged below:
  `M-10hover` green at `749c277`, red at `ee610fd` (`debugContourBuilds`
  1 against 0, `room_tool_test.dart 555`).
- **The plan-owned additions** (decision 29, Tasks 14b and 14c): every
  `X14b-*` and `X14c-*` is killed (`DE1` for the 14b set, `TN1` for the
  14c set; `RG2` also kills `X14c-noSlitCheck`), and their reviewers'
  extras are killed, equivalent or accepted (cost) as ruled.
- **The tasks' extras:** 302 fired (the plan's `X1-` to `X18-` and every
  implementer's and reviewer's mutant the ledger names whose edit exists or
  whose name determines it): 272 killed, 25 equivalent, 5 accepted (cost).
- **Controls** (not counted): the degenerate rectangle under M-10a, M-10b
  and M-10c, and M-10b's least-absolute-area form. See "Controls".
- **N/A, not fired: 16** mutants the ledger names whose edits were never
  written down and whose names do not determine them (the Task 15 review's
  `O2`-`O9`, four variants of the Task 15 re-review, the Task 16 review's
  four probes of pre-existing numeric-field code), and the reviews' probes
  and proposed fixes, which are not mutants. See "N/A".

**Reconciled with the ledger** (every ruling honoured, and where this run
disagrees with what the ledger recorded):

- `M-10cert`: app-level killers `FZ1` (`room_follow_test.dart 935`) and
  `LZ2` (`room_localise_test.dart 424`), not `DF1`, as ruled.
- `X12-noSeed` (= `X14-noSeedBox`): killed in `DG2` (`236`), `FZ1` green,
  as ruled (Task 12 review m-5).
- `rv1-idx` and `X5-noStored`: fired at `RG3` and `RG4` as ruled; both red
  at both.
- `M-10b`'s absolute-area form: the equivalent control, green at `RT1` and
  `RT2`.
- `X11-canonical`: red at `RT2`, `RT3`, `RT4`, `RT6`, `RT7`, `RT8`; `LZ1`
  fired too and green, which is the ruling's own argument (far inputs
  never move the walk's start).
- `X10-collinear`: red at `RT8` (`590`), green at `RT1`, as Task 10 found
  (the plan named `RT1`).
- **Four ledger records that this run corrects:**
  - `rv13-exactStep`, ruled equivalent at Task 13's review, is **killed**
    now: `RG2` red (`room_dissolve_test.dart 403`). Task 14c made a hole
    left out of a step-1 tint observable (`RG2`'s unturned north-west
    column is left out, and `room.tint` must say so); `tint.step == 1`
    alone no longer reports it.
  - `rv14-noStep3`, killed by `FZ1` at Task 14, survives `FZ1` now: Task
    14b removed every step-3 outline `FZ1` reached (its census after 14b:
    1,855 step 1, 0 step 2, 0 step 3). Re-fired at the step-3 fixtures
    that remain (an outer ring pinched at a vertex): `TN1`, `RG2`, `DG3`
    all red.
  - `t3-nullKeys` was fired first at `PG2` and survived; its Task 3 red
    was in `PG1`. Re-fired over the whole page test: `PG1` red.
  - `rv13-degDxOnly` was fired first at `DG1` and the diagnostics file,
    and survived; its Task 13 review killer is `RL3` (the room with a
    `(5.5, NaN)` offset). Re-fired there: red.
- **A re-sited rule that is equivalent at HEAD, and a first-run
  equivalence the audit refuted:**
  - `t10-holeLen` (Task 10's "a hole with fewer than 3 vertices is not a
    hole") became, in Task 14b, `if (!(areaOf(loop) < 0)) continue;`.
    Removing it survives `RT8`, and survives the whole trace, tie, tint,
    localise and dissolve suites, `FZ1` and `SP7`. Since Task 14b a free
    tree leaves no loop at all (`_splitDoubled` removes every doubled
    pair), so the residue the rule dropped cannot arise; and a split outer
    or hole cycle leaves the ring plus clockwise loops only, which is why
    the Task 14b review's `rv14b-holesPositive` ("either sign kept") is
    equivalent too. `rv10-holeLen4` (the triangle hole), re-sited at the
    same rule, is killed (`RT8 635`).
  - `rv14b-splitOnce` (a loop that is not whole is kept only past 1,000
    loops) survived `DE1`-`DE3` and the trace suite at `749c277`, and the
    first run argued it equivalent: "no plan of this feature reaches"
    1,000 loops in one walk. That was wrong -- a room is not bounded in
    islands, and a star of 1,002 tied columns reaches it in about 0.3 s a
    placement. `DE1` now holds that star (`4b12f65`); the mutant is red.

**Findings for the controller** (none changes code in `packages/`):

- **F1 -- `M-10hover` survived; fixed by a fixture** (above, `ee610fd`).
  The spec's D19 amendment in Task 20 (T-8's cache adopted) should say that
  the bounding-box short-circuit now saves the contour build, not a trace.
- **F2 -- the `spike_rooms` grep is not empty.** It matches a provenance
  comment in `apps/floor_planner/test/support/room_fixture.dart:2`
  (``// `test/spike_rooms/support.dart`: plans written in plan
  millimetres, placed``), and a git-ignored build cache under
  `apps/floor_planner/build/`. No file, import or path of the spike's test
  directory exists on the branch. Not a defect; proposal: reword the
  comment to name the spike branch's file without the directory (a
  one-line comment change in the fixture), or accept the grep's output as
  it stands. Left for the controller.
- **F3 -- `DF1`'s `expectSameTrace` still has no killer** (the Task 14
  re-review's note, unchanged): `M-10cert` is green there.

**Tree.** Every fire but one ran against `plan-10/rooms` at `749c277`
(Task 18, approved) with a clean worktree, but, during the control and app
batches, one untracked throwaway file,
`apps/floor_planner/test/t19_control_test.dart` (the degenerate-rectangle
controls, "Controls" below), deleted afterwards. The exception is
`M-10hover`'s re-fire at the fixed `TT6`: it ran with that fix in the
worktree, uncommitted, and the fix was committed unchanged right after as
`ee610fd` (`room_tool_test.dart` passed whole, `flutter analyze` and
`dart format` clean, before the commit). `git status --short` was empty
before the first batch, and after every batch until that fix. This task's
carried text edits (`d255acb`) came after every fire.

**Procedure, per mutant.** The driver is `t19-fire.py` in the session
scratchpad (`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan10/`, adapted from 08's `t14-fire.py`); the mutants are
defined in `t19-m-engine.py`, `t19-m-render.py`, `t19-m-app.py`,
`t19-m-app2.py`, `t19-m-extra.py` and `t19-m-ctl.py` beside it, with the
helpers in `t19-common.py`. For each mutant, in order:

1. `cp` every file the mutant touches to `t19/t19-<id>-<basename>`, and
   refuse to run if such a backup already exists (one backup per file per
   mutant).
2. Apply each edit. Each `old` string must occur exactly once, or nothing is
   written. `t19-check.py` dry-ran every definition against `749c277` first:
   all 366 apply.
3. Print `diff <backup> <file>`. That diff is the edit, pasted below.
4. Run each command with `CI=true`: `dart test` for `packages/jet_cad_2d`,
   `flutter test` otherwise. A command names one test file and one test by
   `--plain-name`, or a whole file where the ledger names no single killer
   (or an equivalent is shown green over the whole file).
5. Save each run's whole output to `t19/t19-<id>-run<n>.log`.
6. `cp` every backup back, then `diff` it against the file and run
   `git diff --quiet -- <file>`.

Every restore below printed `diff` exit 0 and `git diff --quiet` exit 0
(370 restores, none other). The red lines are copied from each run's saved
log by `t19-tomd.py`: the failing test's `[E]` line, the matcher's
`Expected` / `Actual` / `Which` lines, the test-file locations, and the
run's summary line, at most sixteen lines per command. A line longer than
240 characters is cut, and says so; the full text is in the log.

**Baselines.** Each of the 139 distinct commands was first run on the
clean tree (`t19-baseline-engine.txt`, `-render.txt`, `-app.txt`,
`-extra2.txt`; the control file in place for the app's): 138 exited 0.
Of the 114 narrowed commands, 108 match exactly one test (`+1`); six
match the tests whose names contain their id -- `GR1 ` (+4: `GR1`, its
shell twin, and `GR6`, whose name repeats "GR1 and GR2"), `GR2 ` (+3),
`GR4 ` (+2), `GR5 ` (+4), `RN5 ` (+2) and `WS7 ` (+2, Wall and Box); each
red line below names the test that failed. The one exception is the
whole render suite (`rv8-r1-slotNull`'s command), which exits 1 on the
clean tree with the standing Linux failures only (`+940 ~1 -7`, Ruling
10-25); that mutant is judged by its extra reds (`+923 ~1 -24`). So each
red below is the mutant's doing.

**How the edits were recovered.** The tasks' reports are not kept in the
ledger, only its one-line summaries, so each edit was taken, in this order
of preference, from:

- the definition files the tasks left in the scratchpad, re-applied
  unchanged where they still match `749c277`: Task 10's `t10-mutants.json`,
  the Task 10 review's `rv10-mutants.json`, Task 11's `t11-sites/`, Task 13's
  fragments and its review's `rv13-*.edits`, Task 14's `t14-mutants.json`
  and `t14f-mutants.json`, Task 14b's and 14c's `t14b-mutate.py`,
  `t14c-mutate.py`, their reviews' `rv14b-mutants.json` and
  `rv14c-mutants.json`, Task 15's `t15-m/` and `t15f-m/`, Task 16's
  `t16-*-old/new.txt`, Task 17's `t17-m/` and its review's `rv17-m/`, Task
  18's `t18-o/n-*.txt` and its review's `rv18-m/`, Tasks 4-7's `.old/.new`
  fragments and Task 8's review's `rv8-*.py`;
- the task's own log where its driver wrote the diff (Task 9's
  `t9-mut.sh` logs);
- a definition that no longer matches because later tasks moved the code
  (Task 10's tracer was re-cut by Tasks 11, 14b and 15; the trigger by Task
  6): the same rule's edit at its current site, marked **re-sited**;
- the ledger's one-line name, or the plan's or spec's definition, written
  against the current code, marked **reconstructed** (the edit was passed on
  a command line and not kept: Tasks 1-3, 12, parts of 9 and 11, some
  reviewers'). A reconstruction reproduces the ledger's recorded red line
  where the ledger gives one (e.g. `rv1-summary`: `Capability.components` at
  `text_test.dart 81`, exactly).

## The spec's 51 mutants, reconciled (the plan's Mutant assignment table)

Each row: the task that first fired it, the killers the plan names, and this run's fires at `749c277` (`M-10hover`'s second at `ee610fd`): each command green or red, with the first test-file location of its red. The full red lines are in the entries below.

| # | mutant | first fired (task) | killers the plan names | fired at 749c277: site / form -> each command, exit, first red location | status |
|---|---|---|---|---|---|
| 1 | M-10f | 1 | RG3, TX1, RA2 | `M-10f` KILLED: RG3 red (room_follow_test.dart 266), TX1 red (text_test.dart 73), RA2 red (room_object_test.dart 559) | killed |
| 2 | M-10textadd | 1 | TX1, RG1 | `M-10textadd` KILLED: TX1 red (text_test.dart 39), RG1 red (room_object_test.dart 209) | killed |
| 3 | M-10attrs | 2 | AT1, RG1 | `M-10attrs` KILLED: AT1 red (attributes_test.dart 124), RG1 red (room_object_test.dart 203) | killed |
| 4 | M-10page | 3 | PG1, RA2 | `M-10page` KILLED: PG1 red (page_test.dart 146), RA2 red (room_object_test.dart 578) | killed |
| 5 | M-10pagekey | 3 | PG2 (engine); RA2 (room, Task 12) | `M-10pagekey@engine` KILLED: PG2 red (page_test.dart 334)<br>`M-10pagekey@room` PARTIAL: RA2 red (room_object_test.dart 589), room_object_test.dart red (room_object_test.dart 589), RN6 green | killed |
| 6 | M-10pagelate | 3 | PG1 | `M-10pagelate` KILLED: PG1 red (page_test.dart 146) | killed |
| 7 | M-10dissolve | 4 | DV1, RD1-RD3 | `M-10dissolve@engine` KILLED: DV1 red (dissolve_test.dart 187), RD1 red (room_dissolve_test.dart 533), RD2 red (room_dissolve_test.dart 567), RD3 red (room_dissolve_test.dart 602)<br>`M-10dissolve@engine-noAsk` KILLED: DV1 red (dissolve_test.dart 172)<br>`M-10dissolve@room` KILLED: RD1 red (room_dissolve_test.dart 533), RD2 red (room_dissolve_test.dart 567), RD3 red (room_dissolve_test.dart 602), DF1 red (room_follow_test.dart 693) | killed |
| 8 | M-10detach | 4 | DV1 | `M-10detach` KILLED: DV1 red (dissolve_test.dart 187) | killed |
| 9 | M-10snap | 5 | SV1-SV3, SD3 | `M-10snap` KILLED: SV1 red (before_view_test.dart 92), SV2 red (before_view_test.dart 118), SV3 red (before_view_test.dart 140), SD3 red (place_test.dart 368) | killed |
| 10 | M-10nbr | 5 | RS6, SD4 | `M-10nbr@engine` KILLED: RS6 red (room_follow_test.dart 537), SD4 red (place_test.dart 416) | killed |
| 11 | M-10before | 5 | SD2, RD4, RD8 | `M-10before@engine` KILLED: SD2 red (place_test.dart 346), RD4 red (room_dissolve_test.dart 633), RD8 red (room_dissolve_test.dart 764) | killed |
| 12 | M-10e | 5 | RG3, SD5 | `M-10e` KILLED: RG3 red (room_follow_test.dart 267), SD5 red (place_test.dart 453) | killed |
| 13 | M-10cand | 5 | SD1, RG1, SP7 | `M-10cand` KILLED: SD1 red (place_test.dart 306), RG1 red (room_object_test.dart 173), SP7 red (startup_plan_test.dart 541) | killed |
| 14 | M-10allK | 6 | SD9 | `M-10allK` KILLED: SD9 red (place_test.dart 781) | killed |
| 15 | M-10inputbox | 6 | SD11 | `M-10inputbox` KILLED: SD11 red (place_test.dart 865)<br>`M-10inputbox (literal form)` EQUIV-GREEN: place_test.dart green | killed (the spec's value form); the literal form is equivalent (Aabb2 has identity ==, ruled at Task 6) |
| 16 | M-10bulk | 7 | SD7 | `M-10bulk` KILLED: SD7 red (place_test.dart 552) | killed |
| 17 | M-10ring | 8 | OL1, OL4 | `M-10ring@render` KILLED: OL1 red (outline_cache_test.dart 527), OL4 red (room_paint_test.dart 578) | killed |
| 18 | M-10ringdup | 8 | OL2 | `M-10ringdup` KILLED: OL2 red (outline_cache_test.dart 632) | killed |
| 19 | M-10preview | 8 | OL5 | `M-10preview@path` KILLED: OL5 red (selection_overlay_test.dart 711)<br>`M-10preview@cross` KILLED: OL5 red (selection_overlay_test.dart 716) | killed |
| 20 | M-10a | 10 | RT1, RT7, SP7 | `M-10a` KILLED: RT1 red (room_trace_test.dart 208), RT7 red (room_trace_test.dart 497), SP7 red (startup_plan_test.dart 555) | killed |
| 21 | M-10b | 10 | RT1, RT2 | `M-10b` KILLED: RT1 red (room_trace_test.dart 208), RT2 red (room_trace_test.dart 257)<br>`M-10b-abs (control: revision 1's least absolute area)` EQUIV-GREEN: RT1 green, RT2 green | killed; the least-absolute-area form is the spec's equivalent control, green as the spec says |
| 22 | M-10d | 10 | RT1, RT2 | `M-10d` KILLED: RT1 red (room_trace_test.dart 29), RT2 red (room_trace_test.dart 29) | killed |
| 23 | M-10holes | 10 | RT3, RT4, SP7 | `M-10holes` KILLED: RT3 red (room_trace_test.dart 275), RT4 red (room_trace_test.dart 326), SP7 red (startup_plan_test.dart 555) | killed |
| 24 | M-10holesign | 10 | RT3 | `M-10holesign` KILLED: RT3 red (room_trace_test.dart 275) | killed |
| 25 | M-10seedface | 10 | RT4 | `M-10seedface` KILLED: RT4 red (room_trace_test.dart 350) | killed |
| 26 | M-10local | 10 | RT1 | `M-10local` KILLED: RT1 red (room_trace_test.dart 208) | killed |
| 27 | M-10tol | 10 | RT1 | `M-10tol` KILLED: RT1 red (room_trace_test.dart 208) | killed |
| 28 | M-10sep | 10 | RT8, SP7 | `M-10sep@tracer` KILLED: RT8 red (room_trace_test.dart 566), SP7 red (startup_plan_test.dart 555)<br>`M-10sep@inputs` KILLED: RT8 red (room_trace_test.dart 566), SP7 red (startup_plan_test.dart 555) | killed |
| 29 | M-10cert | 11 | LZ2 (app level: FZ1, LZ2, ruling at Task 14's re-review; DF1 fired, green as ruled) | `M-10cert` PARTIAL: LZ2 red (room_localise_test.dart 424), FZ1 red (room_follow_test.dart 935), DF1 green | killed (LZ2, FZ1); DF1 green, as ruled at Task 14's re-review |
| 30 | M-10c | 11 | RL1 | `M-10c` KILLED: RL1 red (room_label_test.dart 88) | killed |
| 31 | M-10centroid | 11 | RL1 | `M-10centroid` KILLED: RL1 red (room_label_test.dart 88) | killed |
| 32 | M-10tintcolour | 12 | RR3, RG1 | `M-10tintcolour` KILLED: RR3 red (room_paint_test.dart 459), RG1 red (room_object_test.dart 189) | killed |
| 33 | M-10offset | 12 | GR1, RL3 | `M-10offset@generate` KILLED: GR1 red (room_grips_test.dart 264), RL3 red (room_object_test.dart 441)<br>`M-10offset@grip` PARTIAL: GR1 red (room_grips_test.dart 252), RL3 green | killed at both sites (RL3 reaches only the generate site, as expected) |
| 34 | M-10offsetref | 12 | RL3 | `M-10offsetref` KILLED: RL3 red (room_object_test.dart 441) | killed |
| 35 | M-10slit | 13 | RG2, SP5 | `M-10slit` KILLED: RG2 red (room_dissolve_test.dart 195), SP5 red (startup_plan_test.dart 486) | killed |
| 36 | M-10shared | 13 | RS4, RD5 | `M-10shared` KILLED: RS4 red (room_follow_test.dart 400), RD5 red (room_dissolve_test.dart 669) | killed |
| 37 | M-10share2 | 13 | DG1 | `M-10share2` KILLED: DG1 red (room_diagnostics_test.dart 99) | killed |
| 38 | M-10objects | 13 | DG1 | `M-10objects` KILLED: DG1 red (room_diagnostics_test.dart 99) | killed |
| 39 | M-10name | 15 | TT4 | `M-10name` KILLED: TT4 red (room_tool_test.dart 485) | killed |
| 40 | M-10occupied | 15 | TT3 | `M-10occupied` KILLED: TT3 red (room_tool_test.dart 444) | killed |
| 41 | M-10seedsnap | 15 | TT5 | `M-10seedsnap` KILLED: TT5 red (room_tool_test.dart 512) | killed |
| 42 | M-10notice | 15 | TT7 | `M-10notice` KILLED: TT7 red (room_tool_test.dart 700) | killed |
| 43 | M-10hover | 15 | TT6 | `M-10hover` SURVIVED: TT6 green<br>`M-10hover (after TT6's fix)` KILLED: TT6 red (room_tool_test.dart 555) | killed after Task 19's TT6 fix (`ee610fd`); survived TT6 at 749c277 |
| 44 | M-10hoverunion | 15 | TT6 | `M-10hoverunion` KILLED: TT6 red (room_tool_test.dart 548) | killed |
| 45 | M-10trim | 15 | ST2 (the tool), GR5 (the grips) | `M-10trim (trimSeparator: the tool and the grips)` KILLED: ST2 red (separator_tool_test.dart 260), GR5 red (room_grips_test.dart 532) | killed |
| 46 | M-10pin | 16 | RN4 | `M-10pin (the shared _commit site)` KILLED: RN4 red (room_panel_test.dart 293), RN5 red (room_panel_test.dart 382), OS2 red (opening_panel_test.dart 371), WS7 red (selection_panel_test.dart 557)<br>`M-10pin (Room-only variant)` KILLED: RN4 red (room_panel_test.dart 293) | killed |
| 47 | M-10movable | 17 | GR4 | `M-10movable` KILLED: GR4 red (room_grips_test.dart 436) | killed |
| 48 | M-10gripframe | 17 | GR6 | `M-10gripframe` KILLED: GR6 red (room_grips_test.dart 636) | killed |
| 49 | M-10grow | 18 | LZ3 | `M-10grow (all-inputs form)` KILLED: LZ3 red (room_cost_test.dart 144)<br>`M-10grow (infinite first box)` KILLED: LZ3 red (room_cost_test.dart 144) | killed |
| 50 | M-10visible | 18 | RR1 | `M-10visible` KILLED: RR1 red (room_paint_test.dart 358) | killed |
| 51 | M-10tintalpha | 18 | RR2 | `M-10tintalpha` KILLED: RR2 red (room_paint_test.dart 432) | killed |

## Controls

**M-10b's least-absolute-area form** (the spec's M-10b note: "equivalent
... fired once as a control"): `RT1` and `RT2` green. Its entry is under
Task 10.

**The degenerate rectangle** (spec 10 Testing; plan Task 19 "Controls"): a
throwaway test, `apps/floor_planner/test/t19_control_test.dart`, never
committed and deleted after the run (its text is `t19_control_test.dart`
in the scratchpad). Four equal, centred, axis-aligned walls at the origin,
drawn anticlockwise: centrelines (-2000, -1500)..(2000, 1500), 200 mm
centre-justified; seed (0.5, 0.25). Two oracles:

- `CTL shape`: the kind of test the fixture invites -- a Traced face, a
  four-point ring, no hole, and the label point (the pole) within 10 mm of
  the box centre;
- `CTL area`: the net area against hand arithmetic, (1,900 + 1,900) x
  (1,400 + 1,400) = 3,800 x 2,800 = 10,640,000 mm².

Both green on the clean tree (baseline). Under the mutants:

| mutant | `CTL shape` | `CTL area` |
|---|---|---|
| M-10a (centrelines) | green | red: `Actual: <12000000.0>` (4,000 x 3,000) |
| M-10b (least signed area wins) | green | red: `Actual: <-13440000.0>` (the outer contour, -4,200 x 3,200) |
| M-10c (the label at the box centre) | green | green |

So the degenerate rectangle hides all three from a shape oracle, and hides
M-10c from any oracle (its pole **is** its box centre and its centroid):
exactly why it may appear only as a control. The hand-arithmetic oracle
still sees M-10a and M-10b on it, which is the roadmap's M-10a trap turned
round: the oracle, not the fixture, does the work there. The entries are
under "Controls: the degenerate rectangle".

## Equivalents (26, fired, green)

Each fired against its task's killers or the whole file named, green; the
ruling that made it so is named. None is new except where marked.

| mutant | argument / ruling |
|---|---|
| `rv3-noLive`, `rv3-beforeLive` | Task 3 ruling: the `lost`/`touched`/`_closure` filter drops what the live filter would |
| `X5-referrerFirst` | planned equivalent (Task 5), ruled |
| `M-10inputbox (literal form)` | `Aabb2` has identity `==`: never equal, always changed (Task 6 ruling) |
| `t7-noContribFilter` | a memo entry only: `placeBoxOf` never asks a non-contributor's type (Task 7) |
| `rv8-askAll` | the preview only asks keys with an outline (Task 8 review) |
| `X10-noSweepReject` | no answer changes (planned, Task 10) |
| `t10-freeSep`, `rv10-noSign` | subsumed by the vertex-count rule, then by Task 14b's split (Task 10 re-review) |
| `rv10-noPreRotate`, `rv10-collinearNoAlong` | Task 10 review |
| `t10-holeLen` (re-sited) | **new at HEAD**: argued in the header; green over seven commands |
| `t11-noFinal` (= `t14f-firstCert`) | equivalent on every fixture (Tasks 11 and 14) |
| `rv12-tintSeedW` | exact up to rounding (Task 12 review) |
| `rv13-noFiniteSkip`, `rv13-sharedNoSelfSeedW`, `rv13-tintReportLocalSeed` | Task 13 review |
| `t13-noLocalTri` | unreachable honestly (Task 13 ruling; the seam exercises the guard) |
| `rv14b-holesPositive`, `rv14b-holeSortFirst` | Task 14b review |
| `rv14c-endOnEndAOnly`, `rv14c-endOnEndBOnly` | Task 14c re-review |
| `rv15f-worldFrame`, `rv15f-dropTrees` | Task 15 re-review |
| `X18-pageLate`, `rv18-pageAfterDispose` | byte-identical encoding: the fallback page is 1:50 m (Task 18 and its review) |

## Accepted (cost) (5, fired, green)

Each changes what the code costs, not what it answers; no test pins that
cost, and a ruling accepts it.

| mutant | the cost | ruling |
|---|---|---|
| `rv7-wide` | the sweep's window 1.5 mm wider: more pair tests, under `SD7`'s bound | Task 7 m-1 ("one size proves not quadratic") |
| `X14-sc-runReturn` | an edit that touches no object builds the after-view and plans an empty closure | Task 14's finding (the three guards back each other up; the three together are killed at `RK1`), fix round 1's m-2 |
| `X14-sc-seedGuard` | an edit with no seeds builds the before-view and walks an empty K | the same |
| `rv14c-noSkipSame` | the same slit is checked twice | Task 14c re-review |
| `rv16-noMemo` | the Room section scans the live slots for the Area on every rebuild | fix round 1's m-1 |

**Reclassified killed:** `rv13-exactStep` (see the header), and, in fix
round 1 (the audit of `d1a81d8`), three the first run called equivalent:
`X14-sc-boxGuard` (the same edit as `X6-readAlways`; red at `SD6`, which
the first run did not fire), `X11-feet` (not a no-op at a tie; `4b12f65`
adds `RA1`'s tie case, red) and `rv14b-splitOnce` (a star of 1,002 tied
columns reaches it; `4b12f65` adds it to `DE1`, red).

## N/A (not fired)

Mutants the ledger names whose edits were never written down, and whose
names do not determine them (their drivers took the edit from a file or a
command line that was not kept):

- the Task 15 review's `O2`-`O9` (8; its `O1` is `t15f-O1`, fired and
  killed);
- the Task 15 re-review's second form of `f-parity` (`parityBox`,
  `parityInv`) and its `onePassJ`, `singlePassJ` variants (4; the named
  forms `t15f-parity`, `rv15f-onePass`, `t15f-singlePass` are fired and
  killed);
- the Task 16 review's `numNoValid`, `isTextPos`, `numShowStr`,
  `loadNoValue` (4): probes of the numeric fields' pre-existing code (07/08
  `SE`, `WS`, `OS` tests), not of a plan-10 rule. (Its `noMemo` is plan-10
  code, the Room section's Area memo: fired in fix round 1, accepted
  (cost).)

Not mutants, and so not fired: the reviews' probes and proposed fixes --
`rv7-countFirst`/`countFirstCont` (Task 7 I-1's fix, adopted),
`rv11-X11-canonical-adv`, `rv11-exp-strict`, `rv13-otherLocalProbe`,
`rv13-otherLocalFull`, `rv14c-bisectH` and `rv14c-fixCoincident` (the
fixes Task 14c adopted), `rv14c-bothSides`, `angleFirst`, `noVside`,
`returnOnly`, `sectorOnly`, the `*-probe` runs of Tasks 17 and 18's
reviews, and reviewers' re-fires of mutants listed here under their own
names (`rv12-regen-*`, `rv11-X11-ringOnly2`, `rv11-margin0`). Aliases fired
once under one name are marked `(= ...)` in the index.

## Where the lines move after this task's commits

The red lines below were read at `749c277`, except `M-10hover (after TT6's
fix)`, read at `ee610fd`. `ee610fd` inserts 24 lines into
`room_tool_test.dart` at line 535 and replaces 6 lines at 574 with one, so
at `ee610fd` and after, a cited `room_tool_test.dart` line from 535 to 573
sits 24 lower and one from 580 on sits 19 lower (e.g. `M-10hoverunion`'s
548 is 572, `M-10notice`'s 700 is 719); lines up to 534 (`TT3`, `TT4`,
`TT5`) do not move. `d255acb` adds one line to `room_inputs.dart` at 233,
so an edit's diff line there from 234 on sits one lower; no test line
moves (`LZ3`'s rename keeps its line count).

Fix round 1's `4b12f65` inserts 17 lines into `room_label_test.dart` after
line 178 (`RA1`'s end; no line cited above moves) and 66 into
`room_tie_test.dart` after line 367 (`DE1`'s end): a cited
`room_tie_test.dart` line from 368 on sits 66 lower (`DE2`'s 379 is 445,
`DE3`'s 505 is 571). The fix round's own red lines are read at `4b12f65`.

## Part B -- invariants and greps

Run from the repository root at `d255acb` (this task's two commits on top
of `749c277`), with `BASE=418d4c7`, by `t19-greps.sh` (the plan's list,
verbatim). The output, as printed:

```
$ grep -rnE "^\s*(import|export)\s+.(package:flutter|dart:ui)" packages/jet_cad_2d/lib apps/floor_planner/lib/parametric/wall_geometry.dart apps/floor_planner/lib/parametric/opening_geometry.dart apps/floor_planner/lib/parametric/room_trace.dart apps/floor_planner/lib/parametric/room_label.dart apps/floor_planner/lib/parametric/room_inputs.dart ; echo "exit $?"
exit 1

$ git diff 418d4c7 -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
0

$ grep -rn "Tolerance.standard" apps/floor_planner/lib/parametric/wall*.dart apps/floor_planner/lib/parametric/opening*.dart apps/floor_planner/lib/parametric/room*.dart apps/floor_planner/lib/parametric/separator*.dart
apps/floor_planner/lib/parametric/room_inputs.dart:196:final double _engineNeighbourOverlap = Tolerance.standard.linear;

$ grep -rn "handleSeed.next" packages/jet_cad_2d/lib/src/parametric/ ; echo "exit $?"
exit 1

$ grep -rnE "debugPlaceBoxCalls\s*(=|\+\+|\+=)" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:738:    debugPlaceBoxCalls++;
packages/jet_cad_2d/lib/src/parametric/regeneration.dart:35:int debugPlaceBoxCalls = 0;

$ grep -rnE "debugReadBoxCalls\s*(=|\+\+|\+=)" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:752:    debugReadBoxCalls++;
packages/jet_cad_2d/lib/src/parametric/regeneration.dart:40:int debugReadBoxCalls = 0;

$ grep -rnE "\.placeBox\(" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:739:    final box = type.placeBox(v, h);

$ grep -rn "TrueColor" apps/floor_planner/lib/parametric/room*.dart apps/floor_planner/lib/parametric/separator*.dart ; echo "exit $?"
exit 1

$ grep -rnE "EntityFlags\.unpickable|\bunpickable\s*=|readsPage|policyFor" packages apps ; echo "exit $?"
exit 1

$ git diff 418d4c7 --stat -- packages/jet_cad_2d/lib
 packages/jet_cad_2d/lib/src/document/style.dart    |  12 +
 .../lib/src/parametric/parametric_system.dart      | 357 +++++++++++++++++++--
 .../lib/src/parametric/regeneration.dart           | 334 +++++++++++++++++--
 3 files changed, 661 insertions(+), 42 deletions(-)

$ git diff 418d4c7 --stat -- packages/jet_cad_2d_flutter/lib
 .../jet_cad_2d_flutter/lib/src/grip_cache.dart     | 36 ++++++++++++----
 .../jet_cad_2d_flutter/lib/src/outline_cache.dart  | 48 ++++++++++++++++++++--
 .../lib/src/selection_overlay.dart                 | 11 ++++-
 3 files changed, 83 insertions(+), 12 deletions(-)

$ git diff 418d4c7 --stat -- apps/floor_planner/test/wall_*_test.dart apps/floor_planner/test/opening_*_test.dart apps/floor_planner/test/support/wall_fixture.dart apps/floor_planner/test/support/opening_fixture.dart apps/floor_planner/test/selection_panel_test.dart apps/floor_planner/test/page_panel_test.dart apps/floor_planner/test/box_test.dart apps/floor_planner/test/planner_box_test.dart apps/floor_planner/test/planner_grips_test.dart | wc -l
0

$ git diff 418d4c7 --stat -- apps/floor_planner/test/planner_shell_test.dart apps/floor_planner/test/planner_draw_test.dart
 apps/floor_planner/test/planner_shell_test.dart | 35 ++++++++++++++++++++++---
 1 file changed, 31 insertions(+), 4 deletions(-)

$ grep -rn "spike_rooms" apps packages ; echo "exit $?"
apps/floor_planner/test/support/room_fixture.dart:2:// `test/spike_rooms/support.dart`: plans written in plan millimetres, placed
grep: apps/floor_planner/build/test_cache/build/99f5cb803d2032707ba73bec2a719151.cache.dill.track.dill: binary file matches
exit 0

$ git rev-list --count 418d4c7..HEAD
50

$ git log --format=%B 418d4c7..HEAD | grep -c '^Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>$'
50

$ git log --format=%B 418d4c7..HEAD | grep -c '^Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv$'
50

$ git log --name-only --format= 418d4c7..HEAD | grep -c 'analysis_options.yaml'
0

```

Against the plan's comments: every line prints what its comment says,
except `spike_rooms` (finding F2, above). The `Tolerance.standard` grep
prints exactly Ruling 10-10's one line; `debugPlaceBoxCalls` and
`debugReadBoxCalls` print the declaration and one increment each;
`.placeBox(` has one call, in `_Registration.placeBoxOf`; the engine's
`lib` changes only `parametric_system.dart`, `regeneration.dart` and
`document/style.dart`, the render layer's only `outline_cache.dart`,
`grip_cache.dart` and `selection_overlay.dart`; 07's and 08's listed app
test files are unedited; `planner_shell_test.dart` carries exactly
`2eb2da6`, the edit the controller ruled on (Ruling 10-22); 50 commits,
each with both trailers; no `analysis_options.yaml` committed.

**Confirmed by reading:**

- `packages/jet_cad_2d/lib/jet_cad_2d.dart` exports
  `src/parametric/parametric_system.dart` (line 59) and
  `src/document/style.dart` (line 30) whole, with no `show` or `hide`, and
  is unchanged since `418d4c7` (`git diff --stat` empty): `Generated.text`,
  the place roles, `objectsOf` and `ReservedHandles.dashedLinetype`
  (`style.dart:121`) are all exported.
- Both allocation invariant tests are unedited (the grep's `0`) and green,
  in the gates and alone:
  `(cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart)`
  `00:04 +5: All tests passed!`;
  `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart)`
  `00:01 +3: All tests passed!`.
- Every task's ledger entry carries its deferred minors (Ruling 10-26):
  each "carried to Task N" ruling reaches Task N's dispatch ("+ carried
  items") and Task N's report names it (Tasks 2, 4-7, 10-18); Task 18's
  two, carried to this task, are `d255acb`.

**The gates** at `d255acb`, Linux container (Ruling 10-25), each summary
line and exit read from the run's log:

- **[engine]** `00:12 +1037 -2: Some tests failed.`; analyze `No issues found!`; format `Formatted 155 files (0 changed) in 0.45 seconds.`; line exit 0.
- **[render]** `00:39 +940 ~1 -7: Some tests failed.`; analyze `No issues found! (ran in 1.1s)`; format `Formatted 177 files (0 changed) in 0.50 seconds.`; line exit 0.
- **[harness]** `00:28 +82: All tests passed!`; analyze `No issues found! (ran in 1.1s)`; format `Formatted 22 files (0 changed) in 0.09 seconds.`; line exit 0.
- **[app]** `01:21 +348: All tests passed!`; analyze `No issues found! (ran in 1.0s)`; format `Formatted 81 files (0 changed) in 0.38 seconds.`; `✓ Built build/web`; line exit 0.

The engine's two reds are the standing hash tests
(`test/testing/generate_document_test.dart`), the render layer's seven the
standing `text_ladder` rungs 1-5 and `text_lod_ladder` rungs 1-2, plus its
one skip: nothing else.

## Every other mutant, indexed (302 extras)

The verdict at `749c277` from the driver (`PARTIAL` = some command red, which is a kill; `EQUIV-*` = expected green), each command, and the final disposition. Their entries follow, by task.

| mutant | verdict at 749c277 | each command: exit, first red location | final |
|---|---|---|---|
| `X1-plain` | KILLED | TX1 red (text_test.dart 123) | killed |
| `X1-geomOnly` | KILLED | TX1 red (text_test.dart 73) | killed |
| `X1-tag` | KILLED | TX1 red (text_test.dart 74) | killed |
| `rv1-always` | KILLED | TX1 red (text_test.dart 55) | killed |
| `rv1-attrib` | KILLED | TX1 red (text_test.dart 124) | killed |
| `rv1-attrs` | KILLED | TX1 red (text_test.dart 40) | killed |
| `rv1-summary` | KILLED | TX1 red (text_test.dart 81) | killed |
| `rv1-flags` | KILLED | AT1 red (attributes_test.dart 113) | killed |
| `rv1-idx` | KILLED | AT1 red (attributes_test.dart 134); RG3 red (room_follow_test.dart 266); RG4 red (room_object_test.dart 289) | killed |
| `X2-boundary` | KILLED | AT1 red (attributes_test.dart 113) | killed |
| `X2-default` | KILLED | AT1 red (attributes_test.dart 145) | killed |
| `X2-linetype` | KILLED | AT1 red (attributes_test.dart 116) | killed |
| `X2-lineweight` | KILLED | AT1 red (attributes_test.dart 116) | killed |
| `X2-alpha` | KILLED | AT1 red (attributes_test.dart 111) | killed |
| `rv2-callsite` | KILLED | AT1 red (attributes_test.dart 113) | killed |
| `rv2-fillb` | KILLED | AT1 red (attributes_test.dart 111) | killed |
| `rv2-alphabnd` | KILLED | AT1 red (attributes_test.dart 113) | killed |
| `rv2-textflags` | KILLED | AT1 red (attributes_test.dart 124) | killed |
| `rv2-readd` | KILLED | AT1 red (attributes_test.dart 158) | killed |
| `rv2-ltconst` | KILLED | AT1 red (attributes_test.dart 111) | killed |
| `rv2-color` | KILLED | RG11 red (regions_test.dart 472) | killed |
| `X3-afterKey` | KILLED | PG1 red (page_test.dart 146) | killed |
| `X3-allTypes` | KILLED | PG2 red (page_test.dart 334) | killed |
| `X3-dangling` | KILLED | PG1 red (page_test.dart 299) | killed |
| `t3-nullKeys` | SURVIVED | PG2 green | killed (re-fire: PG1, whole page_test) |
| `rv3-firstType` | KILLED | PG1 red (page_test.dart 193) | killed |
| `rv3-noShort` | KILLED | PG1 red (page_test.dart 270) | killed |
| `rv3-noLive` | EQUIV-GREEN | page_test.dart green | equivalent (green, as ruled) |
| `rv3-beforeLive` | EQUIV-GREEN | page_test.dart green | equivalent (green, as ruled) |
| `X4-generate` | KILLED | DV1 red (dissolve_test.dart 189) | killed |
| `X4-lostAsk` | KILLED | DV1 red (dissolve_test.dart 298) | killed |
| `X4-order` | KILLED | DV1 red (dissolve_test.dart 231) | killed |
| `rv4-break` | KILLED | DV1 red (dissolve_test.dart 278) | killed |
| `rv4-soloOnly` | KILLED | DV1 red (dissolve_test.dart 172) | killed |
| `rv4-noNode` | KILLED | DV1 red (dissolve_test.dart 187) | killed |
| `rv4-noFills` | KILLED | DV1 red (dissolve_test.dart 231) | killed |
| `rv5-paramsLive` | KILLED | before_view_test.dart red (before_view_test.dart 118) | killed |
| `rv5-toWorldLive` | KILLED | before_view_test.dart red (before_view_test.dart 92) | killed |
| `X5-open` | KILLED | SD1 red (place_test.dart 316) | killed |
| `X5-afterView` | KILLED | SV1 red (before_view_test.dart 87) | killed |
| `X5-noStored` | KILLED | RG4 red (room_object_test.dart 289); RG3 red (room_follow_test.dart 266) | killed |
| `X5-referrerFirst` | EQUIV-GREEN | place_test.dart green; references_test.dart green; cascade_test.dart green; before_view_test.dart green | equivalent (green, as ruled) |
| `t5-finite` | KILLED | SD1 red (place_test.dart 279) | killed |
| `t5-noBoth` | KILLED | SD8 red (place_test.dart 581) | killed |
| `t5-kNoBefore (= rv6-noBeforeNbr)` | KILLED | SD4 red (place_test.dart 426) | killed |
| `t5-kNoAfter (= rv6-noAfterNbr)` | KILLED | place_test.dart red (place_test.dart 416) | killed |
| `rv5-kNoSeeds` | KILLED | place_test.dart red (place_test.dart 289) | killed |
| `rv5-beforeOnly` | KILLED | place_test.dart red (place_test.dart 289) | killed |
| `rv5-noMemo` | KILLED | SD6 red (place_test.dart 734) | killed |
| `rv5-desc` | KILLED | SD5b red (place_test.dart 620) | killed |
| `X6-memoHit` | KILLED | SD6 red (place_test.dart 734) | killed |
| `X6-readAlways` | KILLED | SD6 red (place_test.dart 704) | killed |
| `X6-noReaderCheck (= rv6-rc)` | KILLED | SD10 red (place_test.dart 802) | killed |
| `t6-inputView (= rv6-view)` | KILLED | SD11 red (place_test.dart 865) | killed |
| `t6-oneSide` | KILLED | SD1 red (place_test.dart 289) | killed |
| `t6-afterOnlyBox` | KILLED | SD2 red (place_test.dart 346) | killed |
| `rv6-rcBefore` | KILLED | SD10 red (place_test.dart 821) | killed |
| `rv6-rodLocal` | KILLED | SD11b red (place_test.dart 916) | killed |
| `rv6-slabOwnInput` | KILLED | place_test.dart red (place_test.dart 416) | killed |
| `X7-sweepEdge` | KILLED | SD7 red (place_test.dart 568) | killed |
| `X7-store` | KILLED | OB1 red (objects_of_test.dart 111) | killed |
| `X7-default` | KILLED | RP2 red (reserved_handles_test.dart 35) | killed |
| `rv7-cont` | KILLED | SD7 red (place_test.dart 552) | killed |
| `rv7-sortMax` | KILLED | SD7 red (place_test.dart 568) | killed |
| `rv7-le` | KILLED | SD7 red (place_test.dart 568) | killed |
| `rv7-objAll` | KILLED | OB1 red (objects_of_test.dart 111) | killed |
| `rv7-wide` | EQUIV-GREEN | SD7 green | accepted (cost): Task 7 ruling m-1 |
| `t7-sweepNarrow` | KILLED | SD7 red (place_test.dart 568) | killed |
| `t7-sweepNoY` | KILLED | SD7 red (place_test.dart 568) | killed |
| `t7-sweepOneSide` | KILLED | SD7 red (place_test.dart 568) | killed |
| `t7-sweepUnsorted (= rv7-lsort)` | KILLED | SD7 red (place_test.dart 568) | killed |
| `t7-noSweep` | KILLED | SD7 red (place_test.dart 552) | killed |
| `t7-storeLost` | KILLED | OB1 red (objects_of_test.dart 129) | killed |
| `t7-objNoMemo` | KILLED | OB1 red (objects_of_test.dart 112) | killed |
| `t7-objGrowable` | KILLED | OB1 red (objects_of_test.dart 115) | killed |
| `t7-objOneMemo` | KILLED | OB1 red (objects_of_test.dart 114) | killed |
| `t7-noContribFilter` | EQUIV-GREEN | place_test.dart green; objects_of_test.dart green | equivalent (green, as ruled) |
| `X8-owner` | KILLED | OL2 red (outline_cache_test.dart 636) | killed |
| `X8-flagOnly` | KILLED | OL2 red (outline_cache_test.dart 637) | killed |
| `X8-noCache@path` | KILLED | OL5 red (selection_overlay_test.dart 726) | killed |
| `X8-noCache@cross` | KILLED | OL5 red (selection_overlay_test.dart 731) | killed |
| `X8-firstOnly` | KILLED | OL5 red (selection_overlay_test.dart 711) | killed |
| `t8-noClear` | KILLED | OL5 red (selection_overlay_test.dart 773) | killed |
| `t8-rebuildAlways` | KILLED | OL3 red (outline_cache_test.dart 704) | killed |
| `t8-rotAll` | KILLED | MV2 red (object_grips_test.dart 459) | killed |
| `rv8-kindPoly` | KILLED | OL1 red (outline_cache_test.dart 527) | killed |
| `rv8-identity` | KILLED | OL1 red (outline_cache_test.dart 527) | killed |
| `rv8-rotNone (= rv8-r1-rotNone)` | KILLED | OL5 red (selection_overlay_test.dart 768) | killed |
| `rv8-picking` | KILLED | OL2 red (outline_cache_test.dart 641) | killed |
| `rv8-askAll` | EQUIV-GREEN | selection_overlay_test.dart green; outline_cache_test.dart green; object_grips_test.dart green | equivalent (green, as ruled) |
| `t8-fillMovable (= rv8-r1-fillMovable)` | KILLED | OL5 red (selection_overlay_test.dart 711) | killed |
| `rv8-r1-rotFill` | KILLED | OL5 red (selection_overlay_test.dart 764) | killed |
| `rv8-r1-slotNull` | KILLED | the render suite: `+923 ~1 -24` against `+940 ~1 -7` clean, 17 extra reds (e.g. grip_cache_test.dart 87, MV2, MV3) | killed |
| `X9-world` | KILLED | RT5 red (room_inputs_test.dart 341) | killed |
| `X9-nested` | KILLED | RI1 red (room_inputs_test.dart 208) | killed |
| `X9-sepReach` | KILLED | SR4 red (separator_test.dart 138) | killed |
| `X9-dupName` | KILLED | SR5 red (separator_test.dart 193) | killed |
| `X9-allWalls` | KILLED | RI1 red (room_inputs_test.dart 158) | killed |
| `t9-handle6` | KILLED | SR5 red (separator_test.dart 181) | killed |
| `t9-sepDegenerate` | KILLED | SR2 red (separator_test.dart 109) | killed |
| `t9-stale` | KILLED | RI1 red (room_inputs_test.dart 234) | killed |
| `t9-contrib` | KILLED | RI1 red (room_inputs_test.dart 103) | killed |
| `t9-localCheck` | KILLED | room_inputs_test.dart red (room_inputs_test.dart 315) | killed |
| `t9-invalidateNoop` | KILLED | RI1 red (room_inputs_test.dart 234) | killed |
| `t9-invalidateNoStale (= rv9-r1-invNoStale)` | KILLED | RI1 red (room_inputs_test.dart 234) | killed |
| `t9-invalidateOnly (= rv9-r1-invNoGen)` | KILLED | RI1 red (room_inputs_test.dart 250) | killed |
| `rv9-eqTol` | KILLED | RI2 red (room_inputs_test.dart 282) | killed |
| `rv9-noSort` | KILLED | RI1 red (room_inputs_test.dart 103) | killed |
| `rv9-sweepY` | KILLED | RI1 red (room_inputs_test.dart 103) | killed |
| `rv9-globalMemo` | KILLED | room_inputs_test.dart red (room_inputs_test.dart 103); RG4 red (room_object_test.dart 289) | killed |
| `rv9-eqNoSource` | KILLED | RI2 red (room_inputs_test.dart 286) | killed |
| `rv9-eqNoClosed` | KILLED | RI2 red (room_inputs_test.dart 288) | killed |
| `rv9-eqNoY` | KILLED | RI2 red (room_inputs_test.dart 282) | killed |
| `rv9-hashConst` | KILLED | RI2 red (room_inputs_test.dart 270) | killed |
| `rv9-sepLenGe` | KILLED | DG4 red (room_diagnostics_test.dart 363) | killed |
| `rv9-wallFinite` | KILLED | DG4 red (room_diagnostics_test.dart 425) | killed |
| `X10-collinear` | PARTIAL | RT1 green; RT8 red (room_trace_test.dart 590) | killed |
| `X10-spike (re-sited: _splitDoubled, Task 14b)` | KILLED | RT8 red (room_trace_test.dart 590) | killed |
| `X10-lowest` | KILLED | RT9 red (room_trace_test.dart 720) | killed |
| `X10-noSweepReject` | EQUIV-GREEN | room_trace_test.dart green; room_localise_test.dart green | equivalent (green, as ruled) |
| `t10-canon` | KILLED | room_trace_test.dart red (room_trace_test.dart 217) | killed |
| `t10-holeOrder` | KILLED | room_trace_test.dart red (room_trace_test.dart 304) | killed |
| `t10-counter` | PARTIAL | room_trace_test.dart red (room_trace_test.dart 207); LZ3 green | killed |
| `t10-nested` | KILLED | room_trace_test.dart red (room_trace_test.dart 369) | killed |
| `t10-freeSep` | EQUIV-GREEN | room_trace_test.dart green; DE1 green | equivalent (green, as ruled) |
| `t10-unsorted` | KILLED | room_trace_test.dart red (room_trace_test.dart 720) | killed |
| `t10-holeLen (re-sited: the loop-area rule, Task 14b)` | SURVIVED | RT8 green | equivalent (re-fired wide: green over 7 commands) |
| `rv10-holeLen4 (re-sited likewise)` | KILLED | RT8 red (room_trace_test.dart 635) | killed |
| `rv10-angular` | KILLED | RT8 red (room_trace_test.dart 659) | killed |
| `rv10-sweepNoTol` | KILLED | RT8 red (room_trace_test.dart 688) | killed |
| `rv10-yNoTol` | KILLED | RT8 red (room_trace_test.dart 688) | killed |
| `rv10-noTieBreak` | KILLED | RT6 red (room_trace_test.dart 471) | killed |
| `rv10-holeSrc` | KILLED | RT4 red (room_trace_test.dart 334) | killed |
| `rv10-srcMergeDrop` | KILLED | RT7 red (room_trace_test.dart 537) | killed |
| `rv10-sourcesUnsorted` | KILLED | RT7 red (room_trace_test.dart 537) | killed |
| `rv10-nestedNoSeed` | KILLED | room_trace_test.dart red (room_trace_test.dart 374) | killed |
| `rv10-seedCheckLate` | KILLED | room_trace_test.dart red (room_trace_test.dart 703) | killed |
| `rv10-noPreRotate` | EQUIV-GREEN | room_trace_test.dart green | equivalent (green, as ruled) |
| `rv10-collinearNoAlong` | EQUIV-GREEN | room_trace_test.dart green | equivalent (green, as ruled) |
| `rv10-noSign` | EQUIV-GREEN | room_trace_test.dart green; DE1 green | equivalent (green, as ruled) |
| `X11-canonical` | PARTIAL | LZ1 green; RT2 red (room_trace_test.dart 260); RT3 red (room_trace_test.dart 283); RT4 red (room_trace_test.dart 345); RT6 red (room_trace_test.dart 413); RT7 red (room_trace_test.dart 507); RT8 red (room_trace_test.dart 644) | killed |
| `X11-noUnion` | KILLED | LZ1 red (room_localise_test.dart 353); room_localise_test.dart red (room_localise_test.dart 353) | killed |
| `X11-ringOnly` | KILLED | TN1 red (room_tint_test.dart 335) | killed |
| `X11-comma` | KILLED | RA1 red (room_label_test.dart 175) | killed |
| `X11-feet` | EQUIV-GREEN | RA1 green; RA2 green | killed after `4b12f65`: RA1's tie case red (room_label_test.dart 193) |
| `t11-viewBoundsNull` | KILLED | room_localise_test.dart red (room_localise_test.dart 346) | killed |
| `t11-docBoundsNull` | KILLED | room_localise_test.dart red (room_localise_test.dart 346) | killed |
| `t11-slitLeft` | KILLED | room_tint_test.dart red (room_tint_test.dart 259) | killed |
| `t11-farthest` | KILLED | room_tint_test.dart red (room_tint_test.dart 260) | killed |
| `t11-holesAsc` | KILLED | room_tint_test.dart red (room_tint_test.dart 260) | killed |
| `t11-skipStep2` | KILLED | room_tint_test.dart red (room_tint_test.dart 471) | killed |
| `t11-noSplitPole` | KILLED | room_label_test.dart red (room_label_test.dart 88) | killed |
| `t11-noHoleDist` | KILLED | room_label_test.dart red (room_label_test.dart 134) | killed |
| `t11-margin0` | KILLED | LZ1 red (room_localise_test.dart 353) | killed |
| `t11-noFinal (= t14f-firstCert)` | EQUIV-GREEN | room_localise_test.dart green; FZ1 green; DF1 green | equivalent (green, as ruled) |
| `t11-r1-noVertexRule` | KILLED | TN1 red (room_tint_test.dart 335) | killed |
| `rv11-seedGuard` | KILLED | LZ4 red (room_localise_test.dart 464) | killed |
| `rv11-noSelf` | KILLED | TN1 red (room_tint_test.dart 335) | killed |
| `rv11-prec40` | KILLED | RL1 red (room_label_test.dart 90); RL2 red (room_label_test.dart 134) | killed |
| `rv11-r1-endsIncluded` | KILLED | TN1 red (room_tint_test.dart 253) | killed |
| `X12-alpha` | KILLED | RG1 red (room_object_test.dart 190) | killed |
| `X12-fillFlag` | KILLED | RG1 red (room_object_test.dart 191) | killed |
| `X12-swap` | KILLED | RG1 red (room_object_test.dart 209) | killed |
| `X12-noSeed (= X14-noSeedBox)` | PARTIAL | DG2 red (room_diagnostics_test.dart 236); FZ1 green | killed |
| `t12-noScale` | KILLED | RL4 red (room_object_test.dart 523) | killed |
| `t12-noRot` | KILLED | RL4 red (room_object_test.dart 521) | killed |
| `t12-localLines` | KILLED | RL4 red (room_object_test.dart 527) | killed |
| `t12-tintLinear` | KILLED | RG1 red (room_object_test.dart 226) | killed |
| `t12-defaultPage` | KILLED | RX1 red (room_object_test.dart 619) | killed |
| `t12-keyScaleOnly` | PARTIAL | room_object_test.dart red (room_object_test.dart 599); RN6 green | killed |
| `t12-keyUnitOnly` | PARTIAL | room_object_test.dart red (room_object_test.dart 560); RN6 green | killed |
| `t12-negZero` | KILLED | room_object_test.dart red (room_object_test.dart 217) | killed |
| `t12-nonFinite` | KILLED | RL3 red (room_object_test.dart 447) | killed |
| `t12-margin0 (= X14-margin0)` | PARTIAL | RG7 red (room_object_test.dart 413); FZ1 green | killed |
| `rv12-memoGlobal` | KILLED | RG4 red (room_object_test.dart 289); RG3 red (room_follow_test.dart 266) | killed |
| `rv12-scaleA` | KILLED | RL4 red (room_object_test.dart 523) | killed |
| `rv12-offsetWorld` | KILLED | RL4 red (room_object_test.dart 539) | killed |
| `rv12-dxOnly` | KILLED | RL3 red (room_object_test.dart 449) | killed |
| `rv12-tintSeedW` | EQUIV-GREEN | room_object_test.dart green; room_dissolve_test.dart green; startup_plan_test.dart green | equivalent (green, as ruled) |
| `X13-higher` | KILLED | DG1 red (room_diagnostics_test.dart 119) | killed |
| `X13-holeSeed` | KILLED | DG1 red (room_diagnostics_test.dart 174) | killed |
| `X13-brokenWarn1` | KILLED | DG2 red (room_diagnostics_test.dart 200) | killed |
| `X13-brokenWarn2` | KILLED | DG2 red (room_diagnostics_test.dart 200) | killed |
| `rv12-poleNoHoles` | KILLED | RG2 red (room_dissolve_test.dart 204) | killed |
| `rv12-noLocalGuard` | KILLED | RG2 red (room_dissolve_test.dart 229); DG3 red (room_diagnostics_test.dart 314) | killed |
| `rv12-step3Region` | KILLED | RG2 red (room_dissolve_test.dart 258); DG3 red (room_diagnostics_test.dart 331) | killed |
| `r1-otherLocal` | KILLED | DG1 red (room_diagnostics_test.dart 151) | killed |
| `r1-noBrokenSkip` | KILLED | DG2 red (room_diagnostics_test.dart 274) | killed |
| `r1-otherSelfT` | KILLED | DG1 red (room_diagnostics_test.dart 151) | killed |
| `rv13-otherLocal` | KILLED | DG1 red (room_diagnostics_test.dart 151) | killed |
| `rv13-diagFresh` | KILLED | room_diagnostics_test.dart red (room_diagnostics_test.dart 314) | killed |
| `rv13-ringOnlyHoles` | KILLED | room_diagnostics_test.dart red (room_diagnostics_test.dart 241) | killed |
| `rv13-degDxOnly` | SURVIVED | DG1 green; room_diagnostics_test.dart green | killed (re-fire at RL3) |
| `rv13-brokenNoSource` | KILLED | DG2 red (room_diagnostics_test.dart 200) | killed |
| `rv13-unboundedOnly` | KILLED | DG2 red (room_diagnostics_test.dart 220) | killed |
| `rv13-seedInWallOnly` | KILLED | DG2 red (room_diagnostics_test.dart 220) | killed |
| `rv13-noFiniteSkip` | EQUIV-GREEN | room_diagnostics_test.dart green; room_dissolve_test.dart green | equivalent (green, as ruled) |
| `rv13-exactStep` | EQUIV-RED | room_diagnostics_test.dart green; room_dissolve_test.dart red (room_dissolve_test.dart 403) | killed (RG2): no longer equivalent since Task 14c |
| `rv13-sharedNoSelfSeedW` | EQUIV-GREEN | room_diagnostics_test.dart green; room_dissolve_test.dart green | equivalent (green, as ruled) |
| `rv13-tintReportLocalSeed` | EQUIV-GREEN | room_diagnostics_test.dart green; room_dissolve_test.dart green | equivalent (green, as ruled) |
| `t13-noLocalTri (= rv13-own-noLocalTri)` | EQUIV-GREEN | room_dissolve_test.dart green; room_diagnostics_test.dart green; FZ1 green | equivalent (green, as ruled) |
| `t13-diagOwnTint` | KILLED | DG3 red (room_diagnostics_test.dart 314) | killed |
| `t13-seamIgnored` | KILLED | RG2 red (room_dissolve_test.dart 229); DG3 red (room_diagnostics_test.dart 314) | killed |
| `t13-degenerateAnd` | KILLED | room_diagnostics_test.dart red (room_diagnostics_test.dart 119) | killed |
| `t13-sepDiagNone` | KILLED | DG4 red (room_diagnostics_test.dart 384) | killed |
| `t13-noStep2` | KILLED | RG2 red (room_dissolve_test.dart 218); room_tint_test.dart red (room_tint_test.dart 471) | killed |
| `t13-noRingTest` | KILLED | room_diagnostics_test.dart red (room_diagnostics_test.dart 241); room_dissolve_test.dart red (room_dissolve_test.dart 211) | killed |
| `X14-noShortCircuit (three sites)` | KILLED | RK1 red (room_cost_test.dart 210) | killed |
| `X14-sc-runReturn` | EQUIV-GREEN | RK1 green | accepted (cost): Task 14 finding (the guards back each other up), fix round 1's ruling m-2 |
| `X14-sc-seedGuard` | EQUIV-GREEN | RK1 green | accepted (cost): Task 14 finding, fix round 1's ruling m-2 |
| `X14-sc-boxGuard` | EQUIV-GREEN | RK1 green | killed: re-fired at SD6, red (place_test.dart 704); = `X6-readAlways` |
| `rv14-noStep3` | SURVIVED | FZ1 green | killed (re-fire: TN1, RG2, DG3) |
| `t14f-unit` | KILLED | DF1 red (room_follow_test.dart 755); RA2 red (room_object_test.dart 559) | killed |
| `t14f-outerArea` | KILLED | DF1 red (room_follow_test.dart 755); FZ1 red (room_follow_test.dart 936); RS2 red (room_follow_test.dart 335) | killed |
| `X14b-noSplit` | KILLED | DE1 red (room_tie_test.dart 192); DE2 red (room_tie_test.dart 379); DE3 red (room_tie_test.dart 505) | killed |
| `X14b-oneHalf` | KILLED | DE1 red (room_tie_test.dart 190); DE2 red (room_tie_test.dart 388); DE3 red (room_tie_test.dart 507) | killed |
| `X14b-dropInner` | KILLED | DE1 red (room_tie_test.dart 190); DE2 red (room_tie_test.dart 388); DE3 red (room_tie_test.dart 507) | killed |
| `X14b-noSources` | PARTIAL | DE1 red (room_tie_test.dart 329); DE2 green; DE3 green | killed |
| `X14b-coincident` | KILLED | DE1 red (room_tie_test.dart 190); DE2 red (room_tie_test.dart 388); DE3 red (room_tie_test.dart 489) | killed |
| `rv14b-ringFirst` | PARTIAL | DE1 red (room_tie_test.dart 190); DE2 red (room_tie_test.dart 379); DE3 red (room_tie_test.dart 505); room_trace_test.dart green | killed |
| `rv14b-holesPositive` | EQUIV-GREEN | DE1 green; DE2 green; DE3 green; room_trace_test.dart green | equivalent (green, as ruled) |
| `rv14b-noOuterSplit` | KILLED | DE1 red (room_tie_test.dart 192); DE2 red (room_tie_test.dart 379); DE3 red (room_tie_test.dart 505); room_trace_test.dart red (room_trace_test.dart 590) | killed |
| `rv14b-noHoleSplit` | PARTIAL | DE1 red (room_tie_test.dart 291); DE2 green; DE3 green; room_trace_test.dart red (room_trace_test.dart 618) | killed |
| `rv14b-holeSortFirst` | EQUIV-GREEN | DE1 green; DE2 green; DE3 green; room_trace_test.dart green | equivalent (green, as ruled) |
| `rv14b-splitOnce` | SURVIVED | DE1 green; DE2 green; DE3 green; room_trace_test.dart green | killed after `4b12f65`: DE1's star red (room_tie_test.dart 428) |
| `X14c-noSlitCheck` | KILLED | TN1 red (room_tint_test.dart 399); RG2 red (room_dissolve_test.dart 396) | killed |
| `X14c-noSectorH` | PARTIAL | TN1 red (room_tint_test.dart 403); RG2 green | killed |
| `X14c-noSectorV` | PARTIAL | TN1 red (room_tint_test.dart 412); RG2 green | killed |
| `X14c-noEndOnEnd` | PARTIAL | TN1 red (room_tint_test.dart 650); RG2 green | killed |
| `rv14c-noTouch` | PARTIAL | TN1 red (room_tint_test.dart 714); RG2 green | killed |
| `rv14c-noLater` | KILLED | TN1 red (room_tint_test.dart 714) | killed |
| `rv14c-endOnEndAOnly` | EQUIV-GREEN | TN1 green; RG2 green | equivalent (green, as ruled) |
| `rv14c-endOnEndBOnly` | EQUIV-GREEN | TN1 green; RG2 green | equivalent (green, as ruled) |
| `rv14c-endOnEndTight` | PARTIAL | TN1 red (room_tint_test.dart 660); RG2 green | killed |
| `rv14c-noSecondClear` | KILLED | TN1 red (room_tint_test.dart 446) | killed |
| `rv14c-bisectAlways` | KILLED | TN1 red (room_tint_test.dart 714) | killed |
| `rv14c-noSkipSame` | EQUIV-GREEN | TN1 green; RG2 green | accepted (cost): Task 14c re-review |
| `X15-stale` | KILLED | TT6 red (room_tool_test.dart 607) | killed |
| `X15-predict` | KILLED | TT1 red (room_tool_test.dart 78) | killed |
| `X15-guardMS` | KILLED | SG1 red (room_tool_test.dart 888); RN3 red (room_panel_test.dart 248) | killed |
| `t15-bandUntrimmed` | KILLED | separator_tool_test.dart red (separator_tool_test.dart 340) | killed |
| `t15-noCancelClear` | KILLED | room_tool_test.dart red (room_tool_test.dart 715) | killed |
| `t15-highest` | KILLED | room_tool_test.dart red (room_tool_test.dart 442) | killed |
| `t15-noHoles` | KILLED | room_tool_test.dart red (room_tool_test.dart 381) | killed |
| `t15-noLength` | KILLED | separator_tool_test.dart red (separator_tool_test.dart 341) | killed |
| `t15-localSeed` | KILLED | room_tool_test.dart red (room_tool_test.dart 442) | killed |
| `t15-oneBand` | KILLED | separator_tool_test.dart red (separator_tool_test.dart 341) | killed |
| `t15-postInv` | KILLED | room_tool_test.dart red (room_tool_test.dart 249) | killed |
| `t15-noRefresh` | KILLED | room_tool_test.dart red (room_tool_test.dart 277) | killed |
| `t15-sepInv` | KILLED | separator_tool_test.dart red (separator_tool_test.dart 302) | killed |
| `t15-clickInv` | KILLED | room_tool_test.dart red (room_tool_test.dart 461) | killed |
| `t15f-contourStale` | KILLED | TT8 red (room_tool_test.dart 824) | killed |
| `t15f-parity` | KILLED | TT8 red (room_tool_test.dart 769) | killed |
| `t15f-mostPositive` | KILLED | TT8 red (room_tool_test.dart 769) | killed |
| `t15f-singlePass` | KILLED | ST5 red (separator_tool_test.dart 402) | killed |
| `t15f-holdingOnly` | KILLED | ST5 red (separator_tool_test.dart 443) | killed |
| `t15f-O1 (= rv15-O1)` | KILLED | ST6 red (separator_tool_test.dart 478) | killed |
| `t15f-marker` | KILLED | TT5 red (room_tool_test.dart 510) | killed |
| `rv15f-onePass` | KILLED | ST5 red (separator_tool_test.dart 443) | killed |
| `rv15f-worldFrame` | EQUIV-GREEN | TT8 green; TT6 green | equivalent (green, as ruled) |
| `rv15f-dropTrees` | EQUIV-GREEN | TT8 green; TT6 green | equivalent (green, as ruled) |
| `X16-untrimmed` | KILLED | RN2 red (room_panel_test.dart 199); RN5 red (room_panel_test.dart 334) | killed |
| `X16-noBlur` | KILLED | RN4 red (room_panel_test.dart 293) | killed |
| `X16-sameCommand` | KILLED | RN2 red (room_panel_test.dart 185) | killed |
| `X16-staleArea` | KILLED | RN6 red (room_panel_test.dart 474) | killed |
| `X16-geometry` | KILLED | RN5 red (room_panel_test.dart 356) | killed |
| `X15-guardMS (the map variant)` | KILLED | RN3 red (room_panel_test.dart 261) | killed |
| `rv16-noSort` | KILLED | RN6 red (room_panel_test.dart 530) | killed |
| `rv16-loadNoValueRoom` | KILLED | RN2 red (room_panel_test.dart 209) | killed |
| `rv16-suffixMm` | KILLED | RN1 red (room_panel_test.dart 155) | killed |
| `rv16-numKbd` | KILLED | RN1 red (room_panel_test.dart 154) | killed |
| `rv16-noMemo` | EQUIV-GREEN (fix round 1) | room_panel_test.dart green | accepted (cost): fix round 1's ruling m-1 |
| `X17-autoGate` | KILLED | GR2 red (room_grips_test.dart 379) | killed |
| `X17-noNull` | KILLED | GR1 red (room_grips_test.dart 279) | killed |
| `X17-moveSep` | KILLED | GR5 red (room_grips_test.dart 492) | killed |
| `t17-autoNoAperture` | KILLED | GR2 red (room_grips_test.dart 379) | killed |
| `t17-nameSlot` | KILLED | room_grips_test.dart red (room_grips_test.dart 305) | killed |
| `t17-onGrip` | KILLED | room_grips_test.dart red (room_grips_test.dart 276) | killed |
| `t17-sepKeptTrim` | KILLED | GR5 red (room_grips_test.dart 519) | killed |
| `t17-sepNoInvalidate` | KILLED | GR5 red (room_grips_test.dart 574) | killed |
| `t17-sepOnGrip` | KILLED | room_grips_test.dart red (room_grips_test.dart 555) | killed |
| `t17-clickContours` | KILLED | TT9 red (room_tool_test.dart 852) | killed |
| `t17-commitContours` | KILLED | TT9 red (room_tool_test.dart 852) | killed |
| `t17-listenerContours` | KILLED | TT9 red (room_tool_test.dart 856) | killed |
| `rv17-sepWorld` | KILLED | room_grips_test.dart red (room_grips_test.dart 523) | killed |
| `rv17-sepSnapAlways` | KILLED | room_grips_test.dart red (room_grips_test.dart 540) | killed |
| `rv17-nameMax` | KILLED | room_grips_test.dart red (room_grips_test.dart 233) | killed |
| `rv17-previewStale` | KILLED | room_grips_test.dart red (room_grips_test.dart 281) | killed |
| `rv17-apertureLocal` | KILLED | GR6 red (room_grips_test.dart 681) | killed |
| `rv17-defaultPage` | KILLED | GR1 red (room_grips_test.dart 320) | killed |
| `X18-noDashed` | KILLED | RR4 red (room_paint_test.dart 484) | killed |
| `X18-order` | KILLED | SP5 red (startup_plan_test.dart 452); startup_plan_test.dart red (startup_plan_test.dart 204) | killed |
| `X18-pageLate` | EQUIV-GREEN | startup_plan_test.dart green; room_paint_test.dart green | equivalent (green, as ruled) |
| `t18-areaHeight` | KILLED | SP7 red (startup_plan_test.dart 561) | killed |
| `t18-columnInDoorway` | KILLED | SP4 red (startup_plan_test.dart 371) | killed |
| `t18-poleOff` | KILLED | SP7 red (startup_plan_test.dart 567) | killed |
| `rv18-alpha20` | KILLED | RR2 red (room_paint_test.dart 432) | killed |
| `rv18-growStart16k` | KILLED | LZ3 red (room_cost_test.dart 144) | killed |
| `rv18-growSlow` | KILLED | LZ3 red (room_cost_test.dart 144) | killed |
| `rv18-certMargin1000` | KILLED | LZ3 red (room_cost_test.dart 144) | killed |
| `rv18-noDissolveUnbounded` | KILLED | planner_shell_test.dart red (planner_shell_test.dart 304); RD2 red (room_dissolve_test.dart 567) | killed |
| `rv18-pageAfterDispose` | EQUIV-GREEN | startup_plan_test.dart green | equivalent (green, as ruled) |

## The entries

### Tasks 1-7 -- the engine

#### M-10f — the planner never rewrites a matched TEXT's string (spec; killers RG3, TX1, RA2)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10f-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  556c556
  <         if (g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
  ---
  >         if (false && g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RG3 ')` (exit 1; log `t19-M-10f-run1.log`)

  ```
  00:00 +0 -1: RG3 the shared partition moved 500 mm: both rooms' areas and labels follow, same handles, one undo step [E]
    Expected: ['Room 1', '12.73 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '12.73 m²'
    test/room_follow_test.dart 266:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-M-10f-run2.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: 'Bath'
      Actual: 'Küche 2'
       Which: is different.
              Expected: Bath
                Actual: Küche 2
    test/parametric/text_test.dart 73:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RA2 ')` (exit 1; log `t19-M-10f-run3.log`)

  ```
  00:00 +0 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: ['Room 1', '116.57 ft²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '116.57 ft²'
    test/room_object_test.dart 559:9                    main.<fn>.expectLabels
    test/room_object_test.dart 579:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### M-10textadd — the planner adds records without the string (spec; killers TX1, RG1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10textadd-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  413c413
  <     draftRecord(handle, owner, kind, color: g.color, text: g.text).copyWith(
  ---
  >     draftRecord(handle, owner, kind, color: g.color).copyWith(
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-M-10textadd-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: 'Küche 2'
      Actual: ''
       Which: is different. Both strings start the same, but the actual value is missing the following trailing characters: Küche 2
    test/parametric/text_test.dart 39:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-M-10textadd-run2.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: 'Room 1'
      Actual: ''
       Which: is different. Both strings start the same, but the actual value is missing the following trailing characters: Room 1
    test/room_object_test.dart 209:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X1-plain — the plain form accepts TEXT

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-X1-plain-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  228c228
  <     if (kind == EntityKind.text || kind == EntityKind.attrib) {
  ---
  >     if (kind == EntityKind.attrib) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-X1-plain-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: throws <Instance of 'ArgumentError'>
      Actual: <Closure: () => Generated>
       Which: returned <Instance of 'Generated'>
    test/parametric/text_test.dart 123:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-geomOnly — a string change planned as SetEntityGeometryCommand only

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X1-geomOnly-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  557c557
  <           out.add(SetEntityTextCommand(existing[i], g.text, ''));
  ---
  >           out.add(SetEntityGeometryCommand(existing[i], g.payload));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-X1-geomOnly-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: 'Bath'
      Actual: 'Küche 2'
       Which: is different.
              Expected: Bath
                Actual: Küche 2
    test/parametric/text_test.dart 73:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X1-tag — the rewrite writes the tag 'x'

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X1-tag-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  557c557
  <           out.add(SetEntityTextCommand(existing[i], g.text, ''));
  ---
  >           out.add(SetEntityTextCommand(existing[i], g.text, 'x'));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-X1-tag-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: ''
      Actual: 'x'
       Which: is different. Both strings start the same, but the actual value also has the following trailing characters: x
    test/parametric/text_test.dart 74:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-always — a matched TEXT is rewritten whether or not its string differs

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv1-always-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  556c556
  <         if (g.kind == EntityKind.text && t.entities.textAt(slot) != g.text) {
  ---
  >         if (g.kind == EntityKind.text) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-rv1-always-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: empty
      Actual: ['1000']
    test/parametric/text_test.dart 55:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-attrib — the plain form accepts ATTRIB

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv1-attrib-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  228c228
  <     if (kind == EntityKind.text || kind == EntityKind.attrib) {
  ---
  >     if (kind == EntityKind.text) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-rv1-attrib-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: throws <Instance of 'ArgumentError'>
      Actual: <Closure: () => Generated>
       Which: returned <Instance of 'Generated'>
    test/parametric/text_test.dart 124:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-attrs — textAttrs not written on add (Task 1 review; the same edit as M-10attrs, fired against TX1)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv1-attrs-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  417,418c417
  <         lineweight: g.lineweight,
  <         textAttrs: g.textAttrs);
  ---
  >         lineweight: g.lineweight);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-rv1-attrs-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: <33>
      Actual: <0>
    test/parametric/text_test.dart 40:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-summary — a text-only plan does not mark the edit's geometry changed

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept). It reproduces the review's red line exactly (`Capability.components` at text_test.dart 81).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv1-summary-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  884c884,885
  <   edit._geometryChanged = plan.isNotEmpty || !identical(r, r0);
  ---
  >   edit._geometryChanged =
  >       plan.any((c) => c is! SetEntityTextCommand) || !identical(r, r0);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/text_test.dart --plain-name 'TX1 ')` (exit 1; log `t19-rv1-summary-run1.log`)

  ```
  00:00 +0 -1: TX1 a generated TEXT is added with its string and textAttrs; a string change rewrites it in place, one undo step; a caller's text edit is refused; the plain form refuses TEXT and ATTRIB [E]
    Expected: Capability:<Capability.geometry>
      Actual: Capability:<Capability.components>
    test/parametric/text_test.dart 81:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-flags — flags not written on add (Task 1 review m-1, carried to Task 2)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv1-flags-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  415d414
  <         flags: boundary ? g.boundaryFlags : g.flags,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv1-flags-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <0> instead of <1>
    test/parametric/attributes_test.dart 113:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv1-idx — TEXT children matched in reverse order (Task 1 review m-2; Task 19 fires it against RG3 as ruled)

The edit is Task 14's `t14-mutants.json` entry, which fired it against RG3.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv1-idx-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  544c544,546
  <       final existing = byKind[g.kind];
  ---
  >       final existing = g.kind == EntityKind.text
  >           ? byKind[g.kind]?.reversed.toList()
  >           : byKind[g.kind];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv1-idx-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: empty
      Actual: ['1000']
    test/parametric/attributes_test.dart 134:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RG3 ')` (exit 1; log `t19-rv1-idx-run2.log`)

  ```
  00:00 +0 -1: RG3 the shared partition moved 500 mm: both rooms' areas and labels follow, same handles, one undo step [E]
    Expected: ['Room 1', '12.73 m²']
      Actual: ['12.73 m²', 'Room 1']
       Which: at location [0] is '12.73 m²' instead of 'Room 1'
    test/room_follow_test.dart 266:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG4 ')` (exit 1; log `t19-rv1-idx-run3.log`)

  ```
  00:00 +0 -1: RG4 a room's children keep their handles across a wall move, undo, redo and purge [E]
    Expected: ['Room 1', '11.78 m²']
      Actual: ['11.78 m²', 'Room 1']
       Which: at location [0] is '11.78 m²' instead of 'Room 1'
    test/room_object_test.dart 289:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### M-10attrs — textAttrs not written on add (spec; killers AT1, RG1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10attrs-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  417,418c417
  <         lineweight: g.lineweight,
  <         textAttrs: g.textAttrs);
  ---
  >         lineweight: g.lineweight);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-M-10attrs-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['textAttrs'] is <0> instead of <33>
    test/parametric/attributes_test.dart 124:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-M-10attrs-run2.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: <33>
      Actual: <0>
    test/room_object_test.dart 203:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X2-boundary — the boundary takes the fill's flags, ignoring boundaryFlags

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X2-boundary-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  415c415
  <         flags: boundary ? g.boundaryFlags : g.flags,
  ---
  >         flags: g.flags,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-X2-boundary-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <0> instead of <1>
    test/parametric/attributes_test.dart 113:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-default — boundaryFlags defaults to 0

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-X2-default-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  259c259
  <         boundaryFlags = boundaryFlags ?? flags,
  ---
  >         boundaryFlags = boundaryFlags ?? 0,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-X2-default-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <0> instead of <1>
    test/parametric/attributes_test.dart 145:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-linetype — linetype not written on add

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X2-linetype-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  416d415
  <         linetype: g.linetype,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-X2-linetype-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['linetype'] is <2> instead of <4>
    test/parametric/attributes_test.dart 116:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-lineweight — lineweight not written on add

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X2-lineweight-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  417d416
  <         lineweight: g.lineweight,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-X2-lineweight-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['lineweight'] is <-1> instead of <35>
    test/parametric/attributes_test.dart 116:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X2-alpha — transparency not written on add

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X2-alpha-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414d413
  <         transparency: g.transparency,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-X2-alpha-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['transparency'] is <-1> instead of <229>
    test/parametric/attributes_test.dart 111:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-callsite — the boundary call site does not pass boundary: true

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-callsite-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  535,536c535
  <                 Handle.checked(++reserved), h, EntityKind.polyline, g,
  <                 boundary: true),
  ---
  >                 Handle.checked(++reserved), h, EntityKind.polyline, g),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-callsite-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <0> instead of <1>
    test/parametric/attributes_test.dart 113:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-fillb — the fill record takes the boundary's flags

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-fillb-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  533c533,534
  <             fill: _recordOf(Handle.checked(++reserved), h, EntityKind.fill, g),
  ---
  >             fill: _recordOf(Handle.checked(++reserved), h, EntityKind.fill, g,
  >                 boundary: true),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-fillb-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <1> instead of <0>
    test/parametric/attributes_test.dart 111:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-alphabnd — the boundary record's transparency not written

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-alphabnd-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414c414
  <         transparency: g.transparency,
  ---
  >         transparency: boundary ? kByLayer : g.transparency,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-alphabnd-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['transparency'] is <-1> instead of <229>
    test/parametric/attributes_test.dart 113:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-textflags — a TEXT's flags not written

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-textflags-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  415c415,417
  <         flags: boundary ? g.boundaryFlags : g.flags,
  ---
  >         flags: boundary
  >             ? g.boundaryFlags
  >             : (kind == EntityKind.text ? 0 : g.flags),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-textflags-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['flags'] is <0> instead of <1>
    test/parametric/attributes_test.dart 124:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-readd — a matched child is removed and re-added instead of rewritten

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-readd-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  549c549,554
  <           out.add(SetEntityGeometryCommand(existing[i], g.payload));
  ---
  >           out
  >             ..add(RemoveEntityCommand(existing[i]))
  >             ..add(AddEntityCommand(
  >                 record: _recordOf(Handle.checked(++reserved), h, g.kind, g),
  >                 payload: g.payload));
  >           continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-readd-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: [1001, 1002, 1003, 1004, 1005]
      Actual: [1001, 1002, 2006, 2007, 2008]
       Which: at location [2] is <2006> instead of <1003>
    test/parametric/attributes_test.dart 158:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-ltconst — the linetype written as a constant

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-ltconst-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  416c416
  <         linetype: g.linetype,
  ---
  >         linetype: ReservedHandles.continuousLinetype,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/attributes_test.dart --plain-name 'AT1 ')` (exit 1; log `t19-rv2-ltconst-run1.log`)

  ```
  00:00 +0 -1: AT1 each record attribute is written on add and none is rewritten on a match; a region's boundary flags stand apart from its fill's [E]
    Expected: {
      Actual: {
       Which: at location ['linetype'] is <4> instead of <2>
    test/parametric/attributes_test.dart 111:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv2-color — the colour not written on add (red outside AT1: regions_test RG11)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv2-color-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  413c413
  <     draftRecord(handle, owner, kind, color: g.color, text: g.text).copyWith(
  ---
  >     draftRecord(handle, owner, kind, text: g.text).copyWith(
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/regions_test.dart --plain-name 'RG11 ')` (exit 1; log `t19-rv2-color-run1.log`)

  ```
  00:00 +0 -1: RG11 a generated child is added in its Generated colour, region halves alike, and a regeneration never rewrites it; ByLayer by default (07 D3) [E]
    Expected: [17970262, 17970262, 23413537, 23413537]
      Actual: [-1, -1, -1, -1]
       Which: at location [0] is <-1> instead of <17970262>
    test/parametric/regions_test.dart 472:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10page — no page seeds (spec; killers PG1, RA2)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10page-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  863,865d862
  <     if (before.page != after.page) {
  <       seeds.addAll(_pageSeeds(t, types, before, after));
  <     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-M-10page-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: a numeric value within <0.000001> of <1000>
      Actual: <499.99999999999955>
       Which:  differs by <500.00000000000045>
    test/parametric/page_test.dart 146:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RA2 ')` (exit 1; log `t19-M-10page-run2.log`)

  ```
  00:00 +0 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: <1>
      Actual: <0>
    test/room_object_test.dart 578:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10pagekey@engine — every page change seeds every object of every page-key type: the key comparison dropped (spec; engine site; killer PG2)

The edit is Task 3's `t3-mutant.py` form, re-written against HEAD's call-site guard (Task 4, carried from Task 3's review).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10pagekey_engine-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270c270
  <     if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
  ---
  >     if (r.type.pageKey(after.page) == null) continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG2 ')` (exit 1; log `t19-M-10pagekey_engine-run1.log`)

  ```
  00:00 +0 -1: PG2 a paper-colour change and a grid change call no generate of a page-key client [E]
    Expected: <1>
      Actual: <2>
    test/parametric/page_test.dart 334:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10pagelate — the page seeds added after the early return (spec; killer PG1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10pagelate-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  863,865d862
  <     if (before.page != after.page) {
  <       seeds.addAll(_pageSeeds(t, types, before, after));
  <     }
  869a867,869
  >     if (before.page != after.page) {
  >       seeds.addAll(_pageSeeds(t, types, before, after));
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-M-10pagelate-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: a numeric value within <0.000001> of <1000>
      Actual: <499.99999999999955>
       Which:  differs by <500.00000000000045>
    test/parametric/page_test.dart 146:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-afterKey — the key compared as pageKey(after.page) twice

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X3-afterKey-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270c270
  <     if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
  ---
  >     if (r.type.pageKey(after.page) == r.type.pageKey(after.page)) continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-X3-afterKey-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: a numeric value within <0.000001> of <1000>
      Actual: <499.99999999999955>
       Which:  differs by <500.00000000000045>
    test/parametric/page_test.dart 146:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-allTypes — a page change seeds every object of every type (the plan says PG1; Task 3 found PG2's line 148)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X3-allTypes-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270d269
  <     if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG2 ')` (exit 1; log `t19-X3-allTypes-run1.log`)

  ```
  00:00 +0 -1: PG2 a paper-colour change and a grid change call no generate of a page-key client [E]
    Expected: <1>
      Actual: <2>
    test/parametric/page_test.dart 334:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X3-dangling — the page seeds added before _checkDangling (the spike's order, Ruling 10-4)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X3-dangling-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  854a855,857
  >     if (before.page != after.page) {
  >       seeds.addAll(_pageSeeds(t, types, before, after));
  >     }
  863,865d865
  <     if (before.page != after.page) {
  <       seeds.addAll(_pageSeeds(t, types, before, after));
  <     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-X3-dangling-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    DanglingReferenceError: 3E8 references 1389, which is not a live parametric object
    test/parametric/page_test.dart 299:10                            main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t3-nullKeys — a type whose key is null on both sides is seeded anyway

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t3-nullKeys-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270c270,273
  <     if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
  ---
  >     if (r.type.pageKey(before.page) == r.type.pageKey(after.page) &&
  >         r.type.pageKey(after.page) != null) {
  >       continue;
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG2 ')` (exit 0; log `t19-t3-nullKeys-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). Its Task 3 red was in `PG1`, not `PG2`: re-fired over the whole page test (`t3-nullKeys (whole page_test)`), `PG1` red. Final: killed.

#### rv3-firstType — only the first type whose key changed is seeded (Task 3 review, carried to Task 4)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv3-firstType-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  273a274
  >     return;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-rv3-firstType-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: <8>
      Actual: <7>
    test/parametric/page_test.dart 193:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-noShort — the page == short-circuit dropped (Task 3 review, carried to Task 4)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv3-noShort-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  863,865c863
  <     if (before.page != after.page) {
  <       seeds.addAll(_pageSeeds(t, types, before, after));
  <     }
  ---
  >     seeds.addAll(_pageSeeds(t, types, before, after));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart --plain-name 'PG1 ')` (exit 1; log `t19-rv3-noShort-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: <26>
      Actual: <28>
    test/parametric/page_test.dart 270:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv3-noLive — the live-after filter dropped (equivalent, ruled at Task 3: lost/touched/_closure filter)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv3-noLive-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  272c272
  <       if (after.objects.containsKey(h)) yield h;
  ---
  >       yield h;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart)` (exit 0; log `t19-rv3-noLive-run1.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

#### rv3-beforeLive — the live filter against the before-survey (equivalent, ruled at Task 3)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv3-beforeLive-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  272c272
  <       if (after.objects.containsKey(h)) yield h;
  ---
  >       if (before.objects.containsKey(h)) yield h;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart)` (exit 0; log `t19-rv3-beforeLive-run1.log`)

  ```
  00:00 +2: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

#### M-10dissolve@engine — `dissolves` always false, as the planner sees it (spec form; engine site; killers DV1, RD1-RD3)

The spec's form ("`dissolves` always false") at the engine's one call: the answer is ignored. This is Task 4's `t4-own-ignore` and the Task 4 review's `rv4-ignore` (one edit).

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10dissolve_engine-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  496c496
  <     if (registration.dissolves(view, h)) {
  ---
  >     if (registration.dissolves(view, h) && h.value < 0) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-M-10dissolve_engine-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: null
      Actual: GroupNode:<GroupNode(3E8, 0 children)>
    test/parametric/dissolve_test.dart 86:3   expectDissolved
    test/parametric/dissolve_test.dart 187:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD1 ')` (exit 1; log `t19-M-10dissolve_engine-run2.log`)

  ```
  00:00 +0 -1: RD1 a wall moved onto a room's seed dissolves it in the same undo step [E]
    Expected: null
      Actual: RoomParams:<RoomParams((1512.5, 1987.25), Room 1, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 533:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD2 ')` (exit 1; log `t19-M-10dissolve_engine-run3.log`)

  ```
  00:00 +0 -1: RD2 a face opened to the outside dissolves its room [E]
    Expected: null
      Actual: RoomParams:<RoomParams((1512.5, 1987.25), Room 1, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 567:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD3 ')` (exit 1; log `t19-M-10dissolve_engine-run4.log`)

  ```
  00:00 +0 -1: RD3 deleting E4 dissolves the Hall and Bedroom 1 in one step [E]
    Expected: null
      Actual: RoomParams:<RoomParams((14500.0, 10500.0), Hall, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 602:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### M-10dissolve@engine-noAsk — `_plan` never asks `dissolves` (the plan's wording of the engine site)

Task 4's `M-10dissolve` form: the whole dissolve arm removed.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10dissolve_engine-noAsk-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  496,501d495
  <     if (registration.dissolves(view, h)) {
  <       out
  <         ..addAll(_subtreeRemoval(t, s, h))
  <         ..add(registration.detach(h));
  <       continue;
  <     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-M-10dissolve_engine-noAsk-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: <1>
      Actual: <0>
    test/parametric/dissolve_test.dart 172:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10detach — the dissolve leaves the component (spec; killer DV1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10detach-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  498,499c498
  <         ..addAll(_subtreeRemoval(t, s, h))
  <         ..add(registration.detach(h));
  ---
  >         ..addAll(_subtreeRemoval(t, s, h));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-M-10detach-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: null
      Actual: <Instance of 'Fuse'>
    test/parametric/dissolve_test.dart 87:3   expectDissolved
    test/parametric/dissolve_test.dart 187:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X4-generate — a dissolving object is generated as well

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X4-generate-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  500d499
  <       continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-X4-generate-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: <4>
      Actual: <5>
    test/parametric/dissolve_test.dart 189:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X4-lostAsk — `dissolves` asked of lost objects too

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X4-lostAsk-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  846a847,849
  >     for (final h in lost) {
  >       before.objects[h]!.dissolves(ParametricView._(t, after), h);
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-X4-lostAsk-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: <0>
      Actual: <1>
    test/parametric/dissolve_test.dart 298:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X4-order — the detach planned before the removals (killed by DV1's replay order, ff7d9c0)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X4-order-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  498,499c498,499
  <         ..addAll(_subtreeRemoval(t, s, h))
  <         ..add(registration.detach(h));
  ---
  >         ..add(registration.detach(h))
  >         ..addAll(_subtreeRemoval(t, s, h));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-X4-order-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: ['entity 1001', 'entity 1002', 'entity 1003', 'node 1000', 'detach 1000']
      Actual: ['detach 1000', 'entity 1001', 'entity 1002', 'entity 1003', 'node 1000']
       Which: at location [0] is 'detach 1000' instead of 'entity 1001'
    test/parametric/dissolve_test.dart 231:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv4-break — nothing after a dissolving object in the closure is planned (Task 4 review, carried to Task 5)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv4-break-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  500c500
  <       continue;
  ---
  >       break;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-rv4-break-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: <3>
      Actual: <2>
    test/parametric/dissolve_test.dart 278:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv4-soloOnly — `dissolves` asked only when the closure is the object alone

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv4-soloOnly-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  496c496
  <     if (registration.dissolves(view, h)) {
  ---
  >     if (closure.length == 1 && registration.dissolves(view, h)) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-rv4-soloOnly-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: <3>
      Actual: <2>
    test/parametric/dissolve_test.dart 172:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv4-noNode — the dissolve removes the leaves only, not the node

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv4-noNode-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  498c498
  <         ..addAll(_subtreeRemoval(t, s, h))
  ---
  >         ..addAll(_subtreeRemoval(t, s, h).whereType<RemoveEntityCommand>())
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-rv4-noNode-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: null
      Actual: GroupNode:<GroupNode(3E8, 0 children)>
    test/parametric/dissolve_test.dart 86:3   expectDissolved
    test/parametric/dissolve_test.dart 187:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv4-noFills — the fill is left to the boundary's removal (killed by the replay line only)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv4-noFills-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  498c498,500
  <         ..addAll(_subtreeRemoval(t, s, h))
  ---
  >         ..addAll(_subtreeRemoval(t, s, h).where((c) => !(c is RemoveEntityCommand &&
  >             t.entities.kindAt(t.entities.slotOf(c.handle)!) ==
  >                 EntityKind.fill)))
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/dissolve_test.dart --plain-name 'DV1 ')` (exit 1; log `t19-rv4-noFills-run1.log`)

  ```
  00:00 +0 -1: DV1 a dissolving object is removed and its component detached in the edit, one undo step; undo restores every handle; the guard and the cleanup are untouched; drift() names a loaded one [E]
    Expected: ['entity 1001', 'entity 1002', 'entity 1003', 'node 1000', 'detach 1000']
      Actual: ['entity 1003', 'node 1000', 'detach 1000']
       Which: at location [0] is 'entity 1003' instead of 'entity 1001'
    test/parametric/dissolve_test.dart 231:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10snap — the before-view reads the live stores (spec; killers SV1-SV3, SD3)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-M-10snap-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382,385c382,383
  <   U? paramsOf<U extends Component>(Handle h) {
  <     final c = _survey.params[h];
  <     return c is U ? c : null;
  <   }
  ---
  >   U? paramsOf<U extends Component>(Handle h) =>
  >       _survey.objects.containsKey(h) ? _target.components.get<U>(h) : null;
  390c388
  <   Transform2 toWorld(Handle h) => _survey.toWorld[h] ?? _worldOf(_target, h);
  ---
  >   Transform2 toWorld(Handle h) => _worldOf(_target, h);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart --plain-name 'SV1 ')` (exit 1; log `t19-M-10snap-run1.log`)

  ```
  00:00 +0 -1: SV1 the before-view reads a moved object's transform as it was [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/before_view_test.dart 92:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart --plain-name 'SV2 ')` (exit 1; log `t19-M-10snap-run2.log`)

  ```
  00:00 +0 -1: SV2 the before-view reads a re-parameterised object's parameters as they were [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/before_view_test.dart 118:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart --plain-name 'SV3 ')` (exit 1; log `t19-M-10snap-run3.log`)

  ```
  00:00 +0 -1: SV3 the before-view reads a deleted object as it was [E]
    Expected: false
      Actual: <true>
    test/parametric/before_view_test.dart 140:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD3 ')` (exit 1; log `t19-M-10snap-run4.log`)

  ```
  00:00 +0 -1: SD3 a contributor moved far regenerates the reader it left (the before-view) [E]
    Expected: empty
      Actual: [
    test/parametric/place_test.dart 368:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### rv5-paramsLive — paramsOf reads the live store

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv5-paramsLive-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382,385c382,383
  <   U? paramsOf<U extends Component>(Handle h) {
  <     final c = _survey.params[h];
  <     return c is U ? c : null;
  <   }
  ---
  >   U? paramsOf<U extends Component>(Handle h) =>
  >       _survey.objects.containsKey(h) ? _target.components.get<U>(h) : null;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart)` (exit 1; log `t19-rv5-paramsLive-run1.log`)

  ```
  00:00 +1 -1: SV2 the before-view reads a re-parameterised object's parameters as they were [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/before_view_test.dart 118:5  main.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5-toWorldLive — toWorld reads the live tree (= t7-toWorldLive)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv5-toWorldLive-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  390c390
  <   Transform2 toWorld(Handle h) => _survey.toWorld[h] ?? _worldOf(_target, h);
  ---
  >   Transform2 toWorld(Handle h) => _worldOf(_target, h);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart)` (exit 1; log `t19-rv5-toWorldLive-run1.log`)

  ```
  00:00 +0 -1: SV1 the before-view reads a moved object's transform as it was [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/parametric/before_view_test.dart 92:5  main.<fn>
  00:00 +1 -2: SV3 the before-view reads a deleted object as it was [E]
    Expected: false
      Actual: <true>
    test/parametric/before_view_test.dart 140:5  main.<fn>
  00:00 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10nbr@engine — the trigger's K is the seeds only (spec; killers RS6, SD4)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10nbr_engine-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  320,324c320
  <   final k = {
  <     ...seeds,
  <     for (final s in seeds) ...before.neighboursOf(s),
  <     for (final s in seeds) ...after.neighboursOf(s),
  <   }.toList()
  ---
  >   final k = {...seeds}.toList()
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RS6 ')` (exit 1; log `t19-M-10nbr_engine-run1.log`)

  ```
  00:00 +0 -1: RS6 the fallback two-hop: moving X squares W's far end and opens a notch into R2, at six placements [E]
    Expected: ['R2', '18.71 m²']
      Actual: ['R2', '18.70 m²']
       Which: at location [1] is '18.70 m²' instead of '18.71 m²'
    test/room_follow_test.dart 537:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD4 ')` (exit 1; log `t19-M-10nbr_engine-run2.log`)

  ```
  00:00 +0 -1: SD4 the two-hop: a seed that changes a neighbouring contributor's place box at a far end regenerates the reader there [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 416:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10before@engine — the trigger uses after boxes only (spec; killers SD2, RD4, RD8)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10before_engine-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  338d337
  <     if (was != null) boxes.add(was);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD2 ')` (exit 1; log `t19-M-10before_engine-run1.log`)

  ```
  00:00 +0 -1: SD2 a contributor moved out of a reader's field regenerates the reader (its before box) [E]
    Expected: <4>
      Actual: <3>
    test/parametric/place_test.dart 346:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD4 ')` (exit 1; log `t19-M-10before_engine-run2.log`)

  ```
  00:00 +0 -1: RD4 deleting the column keeps Living, closes its hole, and reports nothing [E]
    Expected: ['Living', '22.06 m²']
      Actual: ['Living', '21.90 m²']
       Which: at location [1] is '21.90 m²' instead of '22.06 m²'
    test/room_dissolve_test.dart 633:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD8 ')` (exit 1; log `t19-M-10before_engine-run3.log`)

  ```
  00:00 +0 -1: RD8 a separator moved 60 m away merges the two rooms it split [E]
    Expected: ['Room 1', '29.15 m²']
      Actual: ['Room 1', '11.02 m²']
       Which: at location [1] is '11.02 m²' instead of '29.15 m²'
    test/room_dissolve_test.dart 764:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### M-10e — the trigger adds only the lowest-handle reader each contributor touches (spec, redefined; killers RG3, SD5)

Task 14's form (`t14-mutants.json`): each box adds only the first, lowest-handle, reader it touches.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10e-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  342c342,343
  <   final out = <Handle>[];
  ---
  >   final out = <Handle>{};
  >   final reads = <Handle, Aabb2>{};
  345c346
  <     final read = r.readBoxOf(
  ---
  >     reads[h] = r.readBoxOf(
  347,349c348,352
  <     for (final b in boxes) {
  <       if (read.intersects(b)) {
  <         out.add(h);
  ---
  >   }
  >   for (final b in boxes) {
  >     for (final e in reads.entries) {
  >       if (e.value.intersects(b)) {
  >         out.add(e.key);
  354c357
  <   return out;
  ---
  >   return out.toList()..sort(_byValue);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RG3 ')` (exit 1; log `t19-M-10e-run1.log`)

  ```
  00:00 +0 -1: RG3 the shared partition moved 500 mm: both rooms' areas and labels follow, same handles, one undo step [E]
    Expected: ['Room 2', '16.53 m²']
      Actual: ['Room 2', '18.43 m²']
       Which: at location [1] is '18.43 m²' instead of '16.53 m²'
    test/room_follow_test.dart 267:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD5 ')` (exit 1; log `t19-M-10e-run2.log`)

  ```
  00:00 +0 -1: SD5 two readers touched by one contributor both regenerate [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 453:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10cand — `placedIn` by reach instead of place box (spec; killers SD1, RG1, SP7)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-M-10cand-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  425c425
  <           if (placeBoxOf(h) case final b?) (h, b),
  ---
  >           if (placeBoxOf(h) != null) (h, _survey.reach[h]!),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD1 ')` (exit 1; log `t19-M-10cand-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 306:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-M-10cand-run2.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_object_test.dart 173:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-M-10cand-run3.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: ['Hall', 'Bedroom 1', 'Bedroom 2', 'Kitchen', 'Bath', 'Living', 'Dining']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/startup_plan_test.dart 541:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### X5-open — `placedIn` excludes a box that only touches

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-X5-open-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  416c416,420
  <         if (b.intersects(box)) h,
  ---
  >         if (b.minX < box.maxX &&
  >             b.maxX > box.minX &&
  >             b.minY < box.maxY &&
  >             b.maxY > box.minY)
  >           h,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD1 ')` (exit 1; log `t19-X5-open-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 316:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X5-afterView — the before places read from the after-view

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X5-afterView-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  329c329
  <     final was = beforeView.placeBoxOf(h);
  ---
  >     final was = afterView.placeBoxOf(h);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart --plain-name 'SV1 ')` (exit 1; log `t19-X5-afterView-run1.log`)

  ```
  00:00 +0 -1: SV1 the before-view reads a moved object's transform as it was [E]
    Expected: an object with length of <2>
      Actual: [
       Which: has length of <1>
    test/parametric/before_view_test.dart 87:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X5-noStored — `stored` passed as an empty box (planned re-fire at RG4/RG3; fired at RG4 in Task 12 and RG3 in Task 14)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X5-noStored-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  346c346
  <         after.params[h]!, after.toWorld[h]!, _storedBox(t, after, h));
  ---
  >         after.params[h]!, after.toWorld[h]!, Aabb2.empty());
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG4 ')` (exit 1; log `t19-X5-noStored-run1.log`)

  ```
  00:00 +0 -1: RG4 a room's children keep their handles across a wall move, undo, redo and purge [E]
    Expected: ['Room 1', '11.78 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '11.78 m²'
    test/room_object_test.dart 289:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RG3 ')` (exit 1; log `t19-X5-noStored-run2.log`)

  ```
  00:00 +0 -1: RG3 the shared partition moved 500 mm: both rooms' areas and labels follow, same handles, one undo step [E]
    Expected: ['Room 1', '12.73 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '12.73 m²'
    test/room_follow_test.dart 266:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X5-referrerFirst — readers added after the referrer step (equivalent, ruled at Task 5)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X5-referrerFirst-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  393d392
  <     ...triggered,
  398a398
  >     ...triggered,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 0; log `t19-X5-referrerFirst-run1.log`)

  ```
  00:00 +13: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/references_test.dart)` (exit 0; log `t19-X5-referrerFirst-run2.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/cascade_test.dart)` (exit 0; log `t19-X5-referrerFirst-run3.log`)

  ```
  00:00 +17: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/before_view_test.dart)` (exit 0; log `t19-X5-referrerFirst-run4.log`)

  ```
  00:00 +3: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 4 commands red).

#### t5-finite — a non-finite place box is not turned into null

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t5-finite-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  741,746c741
  <     return box.minX.isFinite &&
  <             box.minY.isFinite &&
  <             box.maxX.isFinite &&
  <             box.maxY.isFinite
  <         ? box
  <         : null;
  ---
  >     return box;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD1 ')` (exit 1; log `t19-t5-finite-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: empty
      Actual: [5001]
    test/parametric/place_test.dart 279:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t5-noBoth — the catalog does not refuse a type that both contributes and reads

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t5-noBoth-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  472c472
  <     if (type.contributesPlace && type.readsPlaces) {
  ---
  >     if (false) {
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD8 ')` (exit 1; log `t19-t5-noBoth-run1.log`)

  ```
  00:00 +0 -1: SD8 the catalog refuses a type that both contributes and reads [E]
    Expected: throws <Instance of 'ArgumentError'>
      Actual: <Closure: () => void>
       Which: returned <null>
    test/parametric/place_test.dart 581:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t5-kNoBefore (= rv6-noBeforeNbr) — K without the seeds' before neighbours

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t5-kNoBefore____rv6-noBeforeNbr_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  322d321
  <     for (final s in seeds) ...before.neighboursOf(s),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD4 ')` (exit 1; log `t19-t5-kNoBefore____rv6-noBeforeNbr_-run1.log`)

  ```
  00:00 +0 -1: SD4 the two-hop: a seed that changes a neighbouring contributor's place box at a far end regenerates the reader there [E]
    Expected: empty
      Actual: [
    test/parametric/place_test.dart 426:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t5-kNoAfter (= rv6-noAfterNbr) — K without the seeds' after neighbours

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t5-kNoAfter____rv6-noAfterNbr_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  323d322
  <     for (final s in seeds) ...after.neighboursOf(s),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 1; log `t19-t5-kNoAfter____rv6-noAfterNbr_-run1.log`)

  ```
  00:00 +3 -1: SD4 the two-hop: a seed that changes a neighbouring contributor's place box at a far end regenerates the reader there [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 416:5  main.<fn>
  00:00 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5-kNoSeeds — K without the seeds themselves

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv5-kNoSeeds-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  321d320
  <     ...seeds,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 1; log `t19-rv5-kNoSeeds-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 289:5  main.<fn>
  00:00 +0 -2: SD2 a contributor moved out of a reader's field regenerates the reader (its before box) [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 335:5  main.<fn>
  00:00 +0 -3: SD3 a contributor moved far regenerates the reader it left (the before-view) [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 360:5  main.<fn>
  00:00 +1 -4: SD5 two readers touched by one contributor both regenerate [E]
  ... (37 more kept lines in the log)
  00:00 +2 -11: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5-beforeOnly — the trigger uses before boxes only

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv5-beforeOnly-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  339d338
  <     if (now != null) boxes.add(now);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 1; log `t19-rv5-beforeOnly-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 289:5  main.<fn>
  00:00 +0 -2: SD2 a contributor moved out of a reader's field regenerates the reader (its before box) [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 335:5  main.<fn>
  00:00 +0 -3: SD3 a contributor moved far regenerates the reader it left (the before-view) [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 360:5  main.<fn>
  00:00 +0 -4: SD4 the two-hop: a seed that changes a neighbouring contributor's place box at a far end regenerates the reader there [E]
  ... (38 more kept lines in the log)
  00:00 +2 -11: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5-noMemo — no place-box memo per view (survived at Task 5; pinned by Task 6's SD6, X6-memoHit's case)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv5-noMemo-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  397d396
  <     if (_placeBoxes.containsKey(h)) return _placeBoxes[h];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD6 ')` (exit 1; log `t19-rv5-noMemo-run1.log`)

  ```
  00:00 +0 -1: SD6 the trigger's counts: no seeds, no call; a non-contributor edit, no call; a contributor edit, one place box per contributor of K live before and one per contributor live after, and one read box per live reader; the first pl [cut; the full line is in the log]
    Expected: (int, int):<(4, 2)>
      Actual: (int, int):<(6, 2)>
    test/parametric/place_test.dart 734:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv5-desc — placedIn lists contributors in descending order (Task 5 review, carried to Task 6: SD5b)

Re-sited at HEAD: the order comes from `_placeAll`'s walk over the survey, reversed here.

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv5-desc-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  423c423,424
  <       for (final MapEntry(key: h, value: r) in _survey.objects.entries)
  ---
  >       for (final MapEntry(key: h, value: r)
  >           in _survey.objects.entries.toList().reversed)
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD5b ')` (exit 1; log `t19-rv5-desc-run1.log`)

  ```
  00:00 +0 -1: SD5b placedIn lists two contributors of one kind in ascending handle order, not in creation order [E]
    Expected: [
      Actual: [
       Which: at location [0] is Aabb2:<Aabb2(9607.306377534282, 5838.676334448557 .. 10255.291474787402, 6252.437606899584)> which has `minX` with value <9607.306377534282> which  differs by <960.137331588794>
    test/parametric/place_test.dart 620:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10allK — every contributor in K adds its boxes, changed or not (spec; killer SD9)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10allK-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  332c332,333
  <     if (was != null &&
  ---
  >     if (false &&
  >         was != null &&
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD9 ')` (exit 1; log `t19-M-10allK-run1.log`)

  ```
  00:00 +0 -1: SD9 an unchanged neighbour in K adds nothing: a contributor moved away from a reader, whose unchanged neighbour touches the reader, regenerates no reader [E]
    Expected: <4>
      Actual: <5>
    test/parametric/place_test.dart 781:9  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10inputbox — `placeInput`'s default returns the place box (spec, the value form; killer SD11)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-M-10inputbox-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150c150,153
  <   Object placeInput(ParametricView view, Handle self) => Object();
  ---
  >   Object placeInput(ParametricView view, Handle self) {
  >     final b = view.placeBoxOf(self);
  >     return b == null ? Object() : (b.minX, b.minY, b.maxX, b.maxY);
  >   }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD11 ')` (exit 1; log `t19-M-10inputbox-run1.log`)

  ```
  00:00 +0 -1: SD11 the diagonal flip: a contributor whose segment changes inside an unchanged box regenerates the reader it splits, with the default placeInput and with an override [E]
    Expected: <3>
      Actual: <2>
    test/parametric/place_test.dart 865:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10inputbox (literal form) — `placeInput`'s default returns the Aabb2 itself (equivalent: Aabb2 has identity ==, ruled at Task 6)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-M-10inputbox__literal_form_-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150c150,151
  <   Object placeInput(ParametricView view, Handle self) => Object();
  ---
  >   Object placeInput(ParametricView view, Handle self) =>
  >       view.placeBoxOf(self) ?? Object();
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 0; log `t19-M-10inputbox__literal_form_-run1.log`)

  ```
  00:00 +13: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

#### X6-memoHit — a memo hit counted as a call

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-X6-memoHit-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  397c397,400
  <     if (_placeBoxes.containsKey(h)) return _placeBoxes[h];
  ---
  >     if (_placeBoxes.containsKey(h)) {
  >       debugPlaceBoxCalls++;
  >       return _placeBoxes[h];
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD6 ')` (exit 1; log `t19-X6-memoHit-run1.log`)

  ```
  00:00 +0 -1: SD6 the trigger's counts: no seeds, no call; a non-contributor edit, no call; a contributor edit, one place box per contributor of K live before and one per contributor live after, and one read box per live reader; the first pl [cut; the full line is in the log]
    Expected: (int, int):<(4, 2)>
      Actual: (int, int):<(6, 2)>
    test/parametric/place_test.dart 734:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-readAlways — `readBox` asked even when L is empty

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X6-readAlways-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  341d340
  <   if (boxes.isEmpty) return const [];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD6 ')` (exit 1; log `t19-X6-readAlways-run1.log`)

  ```
  00:00 +0 -1: SD6 the trigger's counts: no seeds, no call; a non-contributor edit, no call; a contributor edit, one place box per contributor of K live before and one per contributor live after, and one read box per live reader; the first pl [cut; the full line is in the log]
    Expected: (int, int):<(0, 0)>
      Actual: (int, int):<(0, 2)>
    test/parametric/place_test.dart 704:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X6-noReaderCheck (= rv6-rc) — the no-reader check removed

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X6-noReaderCheck____rv6-rc_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  319c319
  <   if (seeds.isEmpty || after.readers == 0) return const [];
  ---
  >   if (seeds.isEmpty) return const [];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD10 ')` (exit 1; log `t19-X6-noReaderCheck____rv6-rc_-run1.log`)

  ```
  00:00 +0 -1: SD10 a document with no live reader makes no place-box call on a contributor edit [E]
    Expected: (int, int):<(0, 0)>
      Actual: (int, int):<(2, 0)>
    test/parametric/place_test.dart 802:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t6-inputView (= rv6-view) — the before input read from the after-view

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t6-inputView____rv6-view_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  334c334
  <         before.objects[h]!.type.placeInput(beforeView, h) ==
  ---
  >         before.objects[h]!.type.placeInput(afterView, h) ==
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD11 ')` (exit 1; log `t19-t6-inputView____rv6-view_-run1.log`)

  ```
  00:00 +0 -1: SD11 the diagonal flip: a contributor whose segment changes inside an unchanged box regenerates the reader it splits, with the default placeInput and with an override [E]
    Expected: <3>
      Actual: <2>
    test/parametric/place_test.dart 865:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t6-oneSide — a contributor live on one side only counts as unchanged

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t6-oneSide-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  331c331
  <     if (was == null && now == null) continue;
  ---
  >     if (was == null || now == null) continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD1 ')` (exit 1; log `t19-t6-oneSide-run1.log`)

  ```
  00:00 +0 -1: SD1 a contributor moved into a reader's field regenerates the reader; placedIn is by place box, closed, and skips a non-finite box [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 289:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t6-afterOnlyBox — the before box added only when there is no after box

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t6-afterOnlyBox-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  338c338
  <     if (was != null) boxes.add(was);
  ---
  >     if (was != null && now == null) boxes.add(was);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD2 ')` (exit 1; log `t19-t6-afterOnlyBox-run1.log`)

  ```
  00:00 +0 -1: SD2 a contributor moved out of a reader's field regenerates the reader (its before box) [E]
    Expected: <4>
      Actual: <3>
    test/parametric/place_test.dart 346:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv6-rcBefore — the reader count read from the before-survey (Task 6 review, carried to Task 7: SD10 compound)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv6-rcBefore-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  319c319
  <   if (seeds.isEmpty || after.readers == 0) return const [];
  ---
  >   if (seeds.isEmpty || before.readers == 0) return const [];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD10 ')` (exit 1; log `t19-rv6-rcBefore-run1.log`)

  ```
  00:00 +0 -1: SD10 a document with no live reader makes no place-box call on a contributor edit [E]
    Expected: (int, int):<(0, 0)>
      Actual: (int, int):<(2, 0)>
    test/parametric/place_test.dart 821:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv6-rodLocal — Rod's exact input taken in its local frame (a test client; Task 6 review, carried to Task 7: SD11b)

- **file:** `packages/jet_cad_2d/test/parametric/support/clients.dart`; backup `t19-rv6-rodLocal-clients.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1143,1144c1143
  <     final (a, b) = p.worldEnds(view.toWorld(self));
  <     return (a.x, a.y, b.x, b.y);
  ---
  >     return (p.ax, p.ay, p.bx, p.by);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD11b ')` (exit 1; log `t19-rv6-rodLocal-run1.log`)

  ```
  00:00 +0 -1: SD11b an exact contributor moved into, across and out of a reader's field regenerates the reader each time: its input is its world segment, read from each view's snapshot transform [E]
    Expected: <2>
      Actual: <1>
    test/parametric/place_test.dart 916:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/test/parametric/support/clients.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv6-slabOwnInput — Slab gains an exact placeInput of its own rectangle, not of its grown box (a test client)

The Task 6 review's `rv6-o-slabIn`/`rv6-n-slabIn` fragments.

- **file:** `packages/jet_cad_2d/test/parametric/support/clients.dart`; backup `t19-rv6-slabOwnInput-clients.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1046a1047,1056
  >   @override
  >   Object placeInput(ParametricView view, Handle self) {
  >     final p = view.paramsOf<Slab>(self);
  >     final m = view.toWorld(self);
  >     if (p == null) return Object();
  >     final a = m.transformPoint(Vector2(p.x, p.y));
  >     final b = m.transformPoint(Vector2(p.x + p.w, p.y + p.h));
  >     return (a.x, a.y, b.x, b.y);
  >   }
  >
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 1; log `t19-rv6-slabOwnInput-run1.log`)

  ```
  00:00 +3 -1: SD4 the two-hop: a seed that changes a neighbouring contributor's place box at a far end regenerates the reader there [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 416:5  main.<fn>
  00:00 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/test/parametric/support/clients.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10bulk — the bulk pass replaced by per-object neighboursOf (spec; killer SD7)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-M-10bulk-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  164,184d163
  <     const tol = Tolerance.standard;
  <     final boxes = reach.entries.toList()
  <       ..sort((p, q) => p.value.minX.compareTo(q.value.minX));
  <     final found = <Handle, List<Handle>>{};
  <     for (var i = 0; i < boxes.length; i++) {
  <       final MapEntry(key: ha, value: a) = boxes[i];
  <       final bound = a.maxX - tol.linear;
  <       for (var j = i + 1; j < boxes.length; j++) {
  <         final MapEntry(key: hb, value: b) = boxes[j];
  <         // Counted before the window check: the check is the predicate's
  <         // first conjunct, so every evaluation of it is a pair test.
  <         debugOverlapTests++;
  <         if (!(b.minX < bound)) break;
  <         if (a.minX < b.maxX - tol.linear &&
  <             a.minY < b.maxY - tol.linear &&
  <             b.minY < a.maxY - tol.linear) {
  <           (found[ha] ??= []).add(hb);
  <           (found[hb] ??= []).add(ha);
  <         }
  <       }
  <     }
  186,187c165
  <       _neighbours[h] ??= List.unmodifiable(
  <           (found[h] ?? const <Handle>[]).toList()..sort(_byValue));
  ---
  >       neighboursOf(h);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-M-10bulk-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: a value less than <10000>
      Actual: <42009>
       Which: is not a value less than <10000>
    test/parametric/place_test.dart 552:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X7-sweepEdge — the sweep's window closed at maxX, not maxX - tolerance

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X7-sweepEdge-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  176c176
  <         if (!(b.minX < bound)) break;
  ---
  >         if (!(b.minX < a.maxX)) break;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-X7-sweepEdge-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: []
      Actual: [215]
       Which: at location [0] is [215] which longer than expected
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X7-store — `objectsOf` read from the component store, not the survey

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-X7-store-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  437,440c437,438
  <       _objectsOf[U] ??= List.unmodifiable([
  <         for (final MapEntry(key: h, value: c) in _survey.params.entries)
  <           if (c is U) h,
  <       ]);
  ---
  >       _objectsOf[U] ??= List.unmodifiable(
  >           _target.components.withComponent<U>().toList()..sort(_byValue));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-X7-store-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: [5100, 5200, 5300]
      Actual: [5100, 5200, 5300, 6100]
       Which: at location [3] is [5100, 5200, 5300, 6100] which longer than expected
    test/parametric/objects_of_test.dart 111:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X7-default — the dashed record added to the default tables

- **file:** `packages/jet_cad_2d/lib/src/document/tables.dart`; backup `t19-X7-default-tables.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  614a615,620
  >       ))
  >       ..add(const LinetypeRecord(
  >         handle: ReservedHandles.dashedLinetype,
  >         name: 'DASHED',
  >         description: 'Dashed __ __ __',
  >         pattern: DashPattern(dashes: [12, -6], totalLength: 18),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/document/reserved_handles_test.dart --plain-name 'RP2 ')` (exit 1; log `t19-X7-default-run1.log`)

  ```
  00:00 +0 -1: RP2 the default tables are unchanged: no record at the dashed handle, which is reserved [E]
    Expected: [2, 3, 4]
      Actual: [2, 3, 4, 6]
       Which: at location [3] is [2, 3, 4, 6] which longer than expected
    test/document/reserved_handles_test.dart 35:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/document/tables.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-cont — the sweep continues past the window instead of breaking (Task 7 review I-1)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv7-cont-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  176c176
  <         if (!(b.minX < bound)) break;
  ---
  >         if (!(b.minX < bound)) continue;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-rv7-cont-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: a value less than <10000>
      Actual: <23115>
       Which: is not a value less than <10000>
    test/parametric/place_test.dart 552:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-sortMax — the sweep sorted by maxX (Task 7 review I-2)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv7-sortMax-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  166c166
  <       ..sort((p, q) => p.value.minX.compareTo(q.value.minX));
  ---
  >       ..sort((p, q) => p.value.maxX.compareTo(q.value.maxX));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-rv7-sortMax-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: [18, 20, 38, 39, 40]
      Actual: [18, 20, 39, 40]
       Which: at location [2] is <39> instead of <38>
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-le — the window closed at <= instead of <

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv7-le-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  176c176
  <         if (!(b.minX < bound)) break;
  ---
  >         if (!(b.minX <= bound)) break;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-rv7-le-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: []
      Actual: [215]
       Which: at location [0] is [215] which longer than expected
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-objAll — objectsOf lists every object

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-rv7-objAll-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  439c439
  <           if (c is U) h,
  ---
  >           if (c is U || c is! U) h,
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-rv7-objAll-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: [5100, 5200, 5300]
      Actual: [5100, 5200, 5300, 7000]
       Which: at location [3] is [5100, 5200, 5300, 7000] which longer than expected
    test/parametric/objects_of_test.dart 111:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv7-wide — the window widened by 1.5 mm (a cost mutant; survives SD7's bound, accepted at Task 7: "one size proves not quadratic")

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-rv7-wide-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  176,177c176,177
  <         if (!(b.minX < bound)) break;
  <         if (a.minX < b.maxX - tol.linear &&
  ---
  >         if (!(b.minX < a.maxX + 1.5)) break;
  >         if (b.minX < bound && a.minX < b.maxX - tol.linear &&
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 0; log `t19-rv7-wide-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red). Final: accepted (cost), Task 7 ruling m-1.

#### t7-sweepNarrow — the window narrowed by one tolerance

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t7-sweepNarrow-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  170c170
  <       final bound = a.maxX - tol.linear;
  ---
  >       final bound = a.maxX - 2 * tol.linear;
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-t7-sweepNarrow-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: [217]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-sweepNoY — the sweep drops the y test

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t7-sweepNoY-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  178d177
  <             a.minY < b.maxY - tol.linear &&
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-t7-sweepNoY-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: [19, 38, 39]
      Actual: [19, 38, 39, 58, 59, 78, 79, 99, 119, 120, 140, 160, 161, 181, 201, 202]
       Which: at location [3] is [19, 38, 39, 58, 59, 78, 79, 99, 119, 120, 140, 160, 161, 181, 201, 202] which longer than expected
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-sweepOneSide — a found pair recorded on one side only

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t7-sweepOneSide-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  181d180
  <           (found[hb] ??= []).add(ha);
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-t7-sweepOneSide-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: [19, 38, 39]
      Actual: [19, 39]
       Which: at location [1] is <39> instead of <38>
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-sweepUnsorted (= rv7-lsort) — the neighbour lists left unsorted

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t7-sweepUnsorted____rv7-lsort_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  187c187
  <           (found[h] ?? const <Handle>[]).toList()..sort(_byValue));
  ---
  >           (found[h] ?? const <Handle>[]).toList());
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-t7-sweepUnsorted____rv7-lsort_-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: [19, 38, 39]
      Actual: [38, 39, 19]
       Which: at location [0] is <38> instead of <19>
    test/parametric/place_test.dart 568:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-noSweep — the first placedIn does not run the bulk pass

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-noSweep-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  421d420
  <     _survey.sweepNeighbours();
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD7 ')` (exit 1; log `t19-t7-noSweep-run1.log`)

  ```
  00:00 +0 -1: SD7 the bulk pass gives every object the lists neighboursOf gives, with fewer than n²/4 overlap tests on a spread layout [E]
    Expected: a value less than <10000>
      Actual: <41607>
       Which: is not a value less than <10000>
    test/parametric/place_test.dart 552:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-storeLost — objectsOf read from the live store with a live-node filter

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-storeLost-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  437,440c437,443
  <       _objectsOf[U] ??= List.unmodifiable([
  <         for (final MapEntry(key: h, value: c) in _survey.params.entries)
  <           if (c is U) h,
  <       ]);
  ---
  >       _objectsOf[U] ??= List.unmodifiable(_target.components
  >           .withComponent<U>()
  >           .where((h) =>
  >               _target.tree[h] == null ||
  >               _target.tree[h]!.parent == _target.tree.root)
  >           .toList()
  >         ..sort(_byValue));
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-t7-storeLost-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: [5100]
      Actual: [5100, 5200]
       Which: at location [1] is [5100, 5200] which longer than expected
    test/parametric/objects_of_test.dart 129:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-objNoMemo — objectsOf not memoised

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-objNoMemo-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  437c437
  <       _objectsOf[U] ??= List.unmodifiable([
  ---
  >       List.unmodifiable([
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-t7-objNoMemo-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: true
      Actual: <false>
    test/parametric/objects_of_test.dart 112:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-objGrowable — objectsOf returns a growable list

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-objGrowable-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  437c437
  <       _objectsOf[U] ??= List.unmodifiable([
  ---
  >       _objectsOf[U] ??= [
  440c440
  <       ]);
  ---
  >       ];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-t7-objGrowable-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: throws <Instance of 'UnsupportedError'>
      Actual: <Closure: () => void>
       Which: returned <null>
    test/parametric/objects_of_test.dart 115:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-objOneMemo — one memo slot for every type

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-objOneMemo-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  437c437
  <       _objectsOf[U] ??= List.unmodifiable([
  ---
  >       _objectsOf[Component] ??= List.unmodifiable([
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart --plain-name 'OB1 ')` (exit 1; log `t19-t7-objOneMemo-run1.log`)

  ```
  00:00 +0 -1: OB1 objectsOf lists exactly the live objects carrying a type, ascending: not a lost, a re-parented or a misplaced one [E]
    Expected: [7000]
      Actual: [5100, 5200, 5300]
       Which: at location [0] is <5100> instead of <7000>
    test/parametric/objects_of_test.dart 114:5  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t7-noContribFilter — placedIn asks every object for a box, not only contributors (equivalent: a memo entry only, ruled at Task 7)

- **file:** `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; backup `t19-t7-noContribFilter-parametric_system.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  424,425c424
  <         if (r.type.contributesPlace)
  <           if (placeBoxOf(h) case final b?) (h, b),
  ---
  >         if (placeBoxOf(h) case final b?) (h, b),
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart)` (exit 0; log `t19-t7-noContribFilter-run1.log`)

  ```
  00:00 +13: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/objects_of_test.dart)` (exit 0; log `t19-t7-noContribFilter-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).


### Task 8 -- the render layer

#### M-10ring@render — OutlineCache's fill arm returns on every fill (spec; killers OL1, OL4)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-M-10ring_render-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  381d380
  <       _addFill(out, slot, t, filters);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL1 ')` (exit 1; log `t19-M-10ring_render-run1.log`)

  ```
  00:00 +0 -1: OL1 a selected group with a fill whose boundary is invisible outlines the boundary's loop, under a rotated, translated, scaled group at the corpus far origin [E]
    Expected: <12>
      Actual: <0>
    test/outline_cache_test.dart 105:3                  expectCoords
    test/outline_cache_test.dart 527:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'OL4 ')` (exit 1; log `t19-M-10ring_render-run2.log`)

  ```
  Expected: true
    Actual: <false>
  00:02 +0 -1: OL4 selecting a sample-plan room outlines its labels and its ring; Living's outline holds the column's hole [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10ringdup — the fill arm also adds a visible boundary's geometry (spec; killer OL2)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-M-10ringdup-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414d413
  <     if (filters.acceptsEntity(boundary, const QueryFilter.rendering())) return;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL2 ')` (exit 1; log `t19-M-10ringdup-run1.log`)

  ```
  00:00 +0 -1: OL2 a visible boundary is outlined once; a hidden fill, a missing boundary and a boundary with another owner outline nothing; a visible fill whose boundary sits on a hidden layer outlines its loop; a visible boundary on a locke [cut; the full line is in the log]
    Expected: <12>
      Actual: <24>
    test/outline_cache_test.dart 105:3                  expectCoords
    test/outline_cache_test.dart 632:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10preview@path — the move preview draws every selected key (spec; the path site; killer OL5)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; backup `t19-M-10preview_path-selection_overlay.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  231d230
  <       if (grips?.isMovable(key) == false) continue;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-M-10preview_path-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: an object with length of <1>
      Actual: [_NativePath:Path, _NativePath:Path, _NativePath:Path, _NativePath:Path]
       Which: has length of <4>
    test/selection_overlay_test.dart 711:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10preview@cross — the point-cross preview draws every selected key (spec; the cross site; killer OL5)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; backup `t19-M-10preview_cross-selection_overlay.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  199d198
  <         if (grips?.isMovable(key) == false) continue;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-M-10preview_cross-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: empty
      Actual: [Instance of 'RecordedCall', Instance of 'RecordedCall']
    test/selection_overlay_test.dart 716:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-owner — no owner test

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-X8-owner-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  413d412
  <     if (entities.ownerAt(boundary) != entities.ownerAt(slot)) return;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL2 ')` (exit 1; log `t19-X8-owner-run1.log`)

  ```
  00:00 +0 -1: OL2 a visible boundary is outlined once; a hidden fill, a missing boundary and a boundary with another owner outline nothing; a visible fill whose boundary sits on a hidden layer outlines its loop; a visible boundary on a locke [cut; the full line is in the log]
    Expected: empty
      Actual: [
    test/outline_cache_test.dart 636:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-flagOnly — the rule keys on the boundary's flag, not on rendering()

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-X8-flagOnly-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414c414
  <     if (filters.acceptsEntity(boundary, const QueryFilter.rendering())) return;
  ---
  >     if (entities.flagsAt(boundary) & EntityFlags.invisible == 0) return;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL2 ')` (exit 1; log `t19-X8-flagOnly-run1.log`)

  ```
  00:00 +0 -1: OL2 a visible boundary is outlined once; a hidden fill, a missing boundary and a boundary with another owner outline nothing; a visible fill whose boundary sits on a hidden layer outlines its loop; a visible boundary on a locke [cut; the full line is in the log]
    Expected: <12>
      Actual: <0>
    test/outline_cache_test.dart 105:3                  expectCoords
    test/outline_cache_test.dart 637:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-noCache@path — no grip cache skips every key (path site)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; backup `t19-X8-noCache_path-selection_overlay.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  231c231
  <       if (grips?.isMovable(key) == false) continue;
  ---
  >       if (grips?.isMovable(key) != true) continue;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-X8-noCache_path-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: an object with length of <4>
      Actual: []
       Which: has length of <0>
    test/selection_overlay_test.dart 726:7              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-noCache@cross — no grip cache skips every key (cross site)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; backup `t19-X8-noCache_cross-selection_overlay.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  199c199
  <         if (grips?.isMovable(key) == false) continue;
  ---
  >         if (grips?.isMovable(key) != true) continue;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-X8-noCache_cross-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: an object with length of <2>
      Actual: []
       Which: has length of <0>
    test/selection_overlay_test.dart 731:7              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X8-firstOnly — isMovable from the any-key flag

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-X8-firstOnly-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  263c263
  <   bool isMovable(SelectionKey key) => _movableKeys.contains(key);
  ---
  >   bool isMovable(SelectionKey key) => _movable;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-X8-firstOnly-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: an object with length of <1>
      Actual: [_NativePath:Path, _NativePath:Path, _NativePath:Path, _NativePath:Path]
       Which: has length of <4>
    test/selection_overlay_test.dart 711:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t8-noClear — the movable set not cleared on rebuild (= rv8-noClear)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-t8-noClear-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  333d332
  <     _movableKeys.clear();
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-t8-noClear-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: false
      Actual: <true>
    test/selection_overlay_test.dart 773:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t8-rebuildAlways — the outline cache rebuilt every frame (OL3)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-t8-rebuildAlways-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  104c104
  <     if (_stale || origin != _origin) {
  ---
  >     if (true) {
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL3 ')` (exit 1; log `t19-t8-rebuildAlways-run1.log`)

  ```
  Expected: true
    Actual: <false>
  00:00 +0 -1: OL3 steady state: a selected group with an invisible-boundary fill rebuilds no path across frames [E]
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t8-rotAll — the rotation grip for every selection

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-t8-rotAll-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  375c375
  <     _movable = _movableKeys.isNotEmpty;
  ---
  >     _movable = true;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart --plain-name 'MV2 ')` (exit 1; log `t19-t8-rotAll-run1.log`)

  ```
  00:00 +0 -1: MV2 (X11-rotgrip, M-08i) the rotation grip needs a movable key: an immovable group alone has a box but is not rotatable, and its grip is neither hit nor pressed; beside a movable key it is [E]
    Expected: false
      Actual: <true>
    test/object_grips_test.dart 459:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-kindPoly — the boundary outlined as a polyline whatever its kind

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-rv8-kindPoly-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  415c415
  <     _addGeometry(out, boundary, entities.kindAt(boundary), t);
  ---
  >     _addGeometry(out, boundary, EntityKind.polyline, t);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL1 ')` (exit 1; log `t19-rv8-kindPoly-run1.log`)

  ```
  00:00 +0 -1: OL1 a selected group with a fill whose boundary is invisible outlines the boundary's loop, under a rotated, translated, scaled group at the corpus far origin [E]
    Expected: <12>
      Actual: <14>
    test/outline_cache_test.dart 105:3                  expectCoords
    test/outline_cache_test.dart 527:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-identity — the boundary outlined without the fill's transform

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-rv8-identity-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  415c415
  <     _addGeometry(out, boundary, entities.kindAt(boundary), t);
  ---
  >     _addGeometry(out, boundary, entities.kindAt(boundary), Transform2.identity());
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL1 ')` (exit 1; log `t19-rv8-identity-run1.log`)

  ```
  00:00 +0 -1: OL1 a selected group with a fill whose boundary is invisible outlines the boundary's loop, under a rotated, translated, scaled group at the corpus far origin [E]
    Expected: a numeric value within <0.000001> of <4500021.508667025>
      Actual: <12.5>
       Which:  differs by <4500009.008667025>
    test/outline_cache_test.dart 107:5                  expectCoords
    test/outline_cache_test.dart 527:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-rotNone (= rv8-r1-rotNone) — the rotation flag never set

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-rv8-rotNone____rv8-r1-rotNone_-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  375d374
  <     _movable = _movableKeys.isNotEmpty;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-rv8-rotNone____rv8-r1-rotNone_-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: true
      Actual: <false>
    test/selection_overlay_test.dart 768:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-picking — the boundary test uses picking(), not rendering() (Task 8 review M1)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; backup `t19-rv8-picking-outline_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414c414
  <     if (filters.acceptsEntity(boundary, const QueryFilter.rendering())) return;
  ---
  >     if (filters.acceptsEntity(boundary, const QueryFilter.picking())) return;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart --plain-name 'OL2 ')` (exit 1; log `t19-rv8-picking-run1.log`)

  ```
  00:00 +0 -1: OL2 a visible boundary is outlined once; a hidden fill, a missing boundary and a boundary with another owner outline nothing; a visible fill whose boundary sits on a hidden layer outlines its loop; a visible boundary on a locke [cut; the full line is in the log]
    Expected: <12>
      Actual: <24>
    test/outline_cache_test.dart 105:3                  expectCoords
    test/outline_cache_test.dart 641:5                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/outline_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-askAll — movableKey asked of keys without an outline too (equivalent for the preview, ruled at Task 8)

Re-sited at HEAD: the Task 8 review's `rv8-askAll.py` targets the pre-fix line; the same move (out of the outline branch) is applied to HEAD's line.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-rv8-askAll-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  348c348,352
  <         if (!fill && movableKey(document, key, objects)) _movableKeys.add(key);
  ---
  >       }
  >       if (!(slot != null &&
  >               document.entities.kindAt(slot) == EntityKind.fill) &&
  >           movableKey(document, key, objects)) {
  >         _movableKeys.add(key);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart)` (exit 0; log `t19-rv8-askAll-run1.log`)

  ```
  00:00 +13: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/outline_cache_test.dart)` (exit 0; log `t19-rv8-askAll-run2.log`)

  ```
  00:00 +15: All tests passed!
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/object_grips_test.dart)` (exit 0; log `t19-rv8-askAll-run3.log`)

  ```
  00:00 +11: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 3 commands red).

#### t8-fillMovable (= rv8-r1-fillMovable) — a fill leaf counted movable (Task 8 review M2)

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-t8-fillMovable____rv8-r1-fillMovable_-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  348c348
  <         if (!fill && movableKey(document, key, objects)) _movableKeys.add(key);
  ---
  >         if (movableKey(document, key, objects)) _movableKeys.add(key);
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-t8-fillMovable____rv8-r1-fillMovable_-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: an object with length of <1>
      Actual: [_NativePath:Path, _NativePath:Path]
       Which: has length of <2>
    test/selection_overlay_test.dart 711:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-r1-rotFill — the rotation flag from movableKey alone, fills included

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD.

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-rv8-r1-rotFill-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  348a349
  >         if (movableKey(document, key, objects)) _movable = true;
  375d375
  <     _movable = _movableKeys.isNotEmpty;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_overlay_test.dart --plain-name 'OL5 ')` (exit 1; log `t19-rv8-r1-rotFill-run1.log`)

  ```
  00:00 +0 -1: OL5 the move preview strokes only the keys the move moves [E]
    Expected: false
      Actual: <true>
    test/selection_overlay_test.dart 764:5              main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv8-r1-slotNull — every leaf treated as a fill

The Task 8 reviewer's `rv8-*.py` edit, re-applied at HEAD. Judged against the render suite's standing failures: `+940 ~1 -7` clean, `+923 ~1 -24` under the mutant (17 more reds, e.g. grip_cache_test.dart 87, MV2, MV3).

- **file:** `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; backup `t19-rv8-r1-slotNull-grip_cache.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  347c347
  <             slot != null && document.entities.kindAt(slot) == EntityKind.fill;
  ---
  >             slot != null;
  ```
- **command:** `(cd packages/jet_cad_2d_flutter && CI=true flutter test test)` (exit 1; log `t19-rv8-r1-slotNull-run1.log`)

  ```
  00:05 +111 -1: packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas) [E]
  00:05 +117 -2: packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas) [E]
  00:06 +118 -3: packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas) [E]
  00:06 +119 -4: packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas) [E]
  00:06 +120 -5: packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas) [E]
  00:08 +143 ~1 -7: packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1 (RenderBackend.canvas) [E]
  00:08 +143 ~1 -7: packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart: a click on a grip or on the rotation grip changes nothing (D12, M-03as); the cursor says what a press would do [E]
    Expected: SystemMouseCursor:<SystemMouseCursor(grab)>
      Actual: _DeferringMouseCursor:<defer>
    test/select_tool_drag_test.dart 92:5                main.<fn>
  00:08 +153 ~1 -8: packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart: a rotation turns about the selection box centre, far from the origin (M-03j) [E]
    Expected: PressClass:<PressClass.rotationGrip>
      Actual: PressClass:<PressClass.empty>
    test/select_tool_drag_test.dart 370:5               main.<fn>
  00:08 +153 ~1 -9: packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart: shift steps the rotation by 15° (M-03w) [E]
    test/select_tool_drag_test.dart 402:49  main.<fn>
  ... (53 more kept lines in the log)
  00:40 +923 ~1 -24: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d_flutter/lib/src/grip_cache.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red). Red beyond the standing failures: `+923 ~1 -24` against `+940 ~1 -7` clean. Final: killed.


### Tasks 9-14c -- the app: inputs, tracer, localised trace and tint, the room, dissolving and diagnostics, following, decision 29

#### X9-world — 07's world outline() instead of the local ring

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-X9-world-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  99c99
  <       final ring = localOutlineOf(WorldWall(h, p, toWorld), walls).ring;
  ---
  >       final ring = outline(WorldWall(h, p, toWorld), walls).ring;
  101c101
  <       final world = [for (final q in ring) toWorld.transformPoint(q)];
  ---
  >       final world = [...ring];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RT5 ')` (exit 1; log `t19-X9-world-run1.log`)

  ```
  00:00 +0 -1: RT5 a wall whose local ring falls back is traced as drawn: its input is its stored band in world, not 07's world outline [E]
    Expected: [
      Actual: [
       Which: at location [0][1] is <1200814.6496720125> instead of <1200814.6496720128>
    test/room_inputs_test.dart 341:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-nested — RoomInputs keeps non-live components

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-X9-nested-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  369,372c369
  <       for (final h in doc.components.withComponent<T>())
  <         if (doc.tree[h] case final GroupNode node
  <             when node.parent == doc.tree.root)
  <           h,
  ---
  >       for (final h in doc.components.withComponent<T>()) h,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-X9-nested-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: [18, 22, 26, 30, 34]
      Actual: [18, 22, 26, 30, 34, 5100, 5200]
       Which: at location [5] is [18, 22, 26, 30, 34, 5100, 5200] which longer than expected
    test/room_inputs_test.dart 27:3                     expectAdaptersAgree
    test/room_inputs_test.dart 208:20                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-sepReach — a separator's reach is its segment's box

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator.dart`; backup `t19-X9-sepReach-separator.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  72c72,73
  <   Aabb2 reach(SeparatorParams params, Transform2 toWorld) => Aabb2.empty();
  ---
  >   Aabb2 reach(SeparatorParams params, Transform2 toWorld) => Aabb2.fromPoints(
  >       [toWorld.transformPoint(params.start), toWorld.transformPoint(params.end)]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_test.dart --plain-name 'SR4 ')` (exit 1; log `t19-X9-sepReach-run1.log`)

  ```
  00:00 +0 -1: SR4 a separator's reach is empty: no wall lists it as a neighbour [E]
    Expected: not contains <34>
      Actual: [22, 30, 34]
    test/separator_test.dart 138:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-dupName — ensureDashedLinetype adds when the name is taken

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator.dart`; backup `t19-X9-dupName-separator.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  147d146
  <   if (linetypes.byName(kDashedLinetypeRecord.name) != null) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_test.dart --plain-name 'SR5 ')` (exit 1; log `t19-X9-dupName-run1.log`)

  ```
  00:00 +0 -1: SR5 ensureDashedLinetype adds the DASHED record once, and adds nothing when handle 6 or the name DASHED is taken [E]
    test/separator_test.dart 193:5                          main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X9-allWalls — the document adapter takes every live wall as a neighbour (Task 9 review I-1: RI1's wide node cluster)

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-X9-allWalls-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  306c306,307
  <         for (final n in _neighbours[w.handle]!) byHandle[n]!,
  ---
  >         for (final o in walls)
  >           if (o.handle != w.handle) o,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-X9-allWalls-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: RoomInput:<RoomInput(C8, band, [[3000.0,-100.0], [3000.0,100.0], [100.0,100.0], [-100.0,-100.0]])>
      Actual: RoomInput:<RoomInput(C8, band, [[3000.0,-100.0], [3000.0,100.0], [100.0,100.0], [0.0,-100.0]])>
    test/room_inputs_test.dart 31:5                     expectAdaptersAgree
    test/room_inputs_test.dart 158:20                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-handle6 — ensureDashedLinetype adds when the handle is taken

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator.dart`; backup `t19-t9-handle6-separator.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  146d145
  <   if (linetypes.contains(kDashedLinetypeRecord.handle)) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_test.dart --plain-name 'SR5 ')` (exit 1; log `t19-t9-handle6-run1.log`)

  ```
  00:00 +0 -1: SR5 ensureDashedLinetype adds the DASHED record once, and adds nothing when handle 6 or the name DASHED is taken [E]
    test/separator_test.dart 181:5                          main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-sepDegenerate — a degenerate separator generates its polyline

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator.dart`; backup `t19-t9-sepDegenerate-separator.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  96d95
  <     if (roomInputInView(view, self) == null) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_test.dart --plain-name 'SR2 ')` (exit 1; log `t19-t9-sepDegenerate-run1.log`)

  ```
  00:00 +0 -1: SR2 a separator generates one open polyline, ByLayer, linetype dashedLinetype, lineweight 35, written once on add [E]
    Expected: empty
      Actual: [21]
    test/separator_test.dart 109:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-stale — RoomInputs never goes stale on a document change

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD. At HEAD the listener calls invalidate().

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t9-stale-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  217c217
  <     _changes = document.changes.listen((_) => invalidate());
  ---
  >     _changes = document.changes.listen((_) {});
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-t9-stale-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: not RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
      Actual: RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
    test/room_inputs_test.dart 234:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-contrib — walls do not contribute places

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/wall.dart`; backup `t19-t9-contrib-wall.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  154c154
  <   bool get contributesPlace => true;
  ---
  >   bool get contributesPlace => false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-t9-contrib-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: [58]
      Actual: [18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58]
       Which: at location [0] is <18> instead of <58>
    test/room_inputs_test.dart 27:3                     expectAdaptersAgree
    test/room_inputs_test.dart 103:22                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-localCheck — the local ring's simple-ccw check skipped

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/wall_geometry.dart`; backup `t19-t9-localCheck-wall_geometry.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  474c474
  <   if (isSimpleCcw(local)) {
  ---
  >   if (isSimpleCcw(local) || true) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart)` (exit 1; log `t19-t9-localCheck-run1.log`)

  ```
  00:00 +2 -1: RT5 a wall whose local ring falls back is traced as drawn: its input is its stored band in world, not 07's world outline [E]
    test/room_inputs_test.dart 315:18                                main.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/wall_geometry.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-invalidateNoop — invalidate() does nothing

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t9-invalidateNoop-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  237,240c237
  <   void invalidate() {
  <     _stale = true;
  <     _generation++;
  <   }
  ---
  >   void invalidate() {}
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-t9-invalidateNoop-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: not RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
      Actual: RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
    test/room_inputs_test.dart 234:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-invalidateNoStale (= rv9-r1-invNoStale) — invalidate() bumps the generation only

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t9-invalidateNoStale____rv9-r1-invNoStale_-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  238d237
  <     _stale = true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-t9-invalidateNoStale____rv9-r1-invNoStale_-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: not RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
      Actual: RoomInput:<RoomInput(22, band, [[4501283.688401923,1204781.698870357], [4501191.637916577,1204742.625757508], [4502676.416204838,1201244.7073143893], [4502768.466690183,1201283.7804272384]])>
    test/room_inputs_test.dart 234:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t9-invalidateOnly (= rv9-r1-invNoGen) — invalidate() marks stale without bumping the generation

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t9-invalidateOnly____rv9-r1-invNoGen_-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  239d238
  <     _generation++;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-t9-invalidateOnly____rv9-r1-invNoGen_-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: a value greater than <0>
      Actual: <0>
       Which: is not a value greater than <0>
    test/room_inputs_test.dart 250:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-eqTol — RoomInput == within 1e-3 (Task 9 review I-2)

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-eqTol-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  62,63c62,63
  <       if (other.points[i].x != points[i].x ||
  <           other.points[i].y != points[i].y) {
  ---
  >       if ((other.points[i].x - points[i].x).abs() > 1e-3 ||
  >           (other.points[i].y - points[i].y).abs() > 1e-3) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI2 ')` (exit 1; log `t19-rv9-eqTol-run1.log`)

  ```
  00:00 +0 -1: RI2 a RoomInput is equal only to the same source, kind and points, bit for bit; equal inputs hash alike [E]
    Expected: false
      Actual: <true>
    test/room_inputs_test.dart 282:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-noSort — the document adapter's place list unsorted (Task 9 review m-1)

The edit is the one Task 9's `t9-mut.sh` wrote into its log, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-noSort-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  313,314c313
  <     final order = _inputs.keys.toList()
  <       ..sort((a, b) => a.value.compareTo(b.value));
  ---
  >     final order = _inputs.keys.toList();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-rv9-noSort-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: [18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 56]
      Actual: [18, 22, 26, 30, 34, 38, 42, 46, 50, 56, 54]
       Which: at location [9] is <56> instead of <54>
    test/room_inputs_test.dart 27:3                     expectAdaptersAgree
    test/room_inputs_test.dart 103:22                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-sweepY — the document adapter's sweep drops the y test

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-sweepY-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  342,344c342
  <         if (a.minX < b.maxX - tol &&
  <             a.minY < b.maxY - tol &&
  <             b.minY < a.maxY - tol) {
  ---
  >         if (a.minX < b.maxX - tol) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI1 ')` (exit 1; log `t19-rv9-sweepY-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: [22, 30, 34, 50]
      Actual: [22, 26, 30, 34, 38, 42, 46, 50, 54]
       Which: at location [1] is <26> instead of <30>
    test/room_inputs_test.dart 38:5                     expectAdaptersAgree
    test/room_inputs_test.dart 103:22                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-globalMemo — roomInputInView memoised across views

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-globalMemo-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  131a132
  > final Map<Handle, RoomInput?> _globalInputs = {};
  133c134
  <   final memo = _inputsByView[view] ??= <Handle, RoomInput?>{};
  ---
  >   final memo = _globalInputs;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart)` (exit 1; log `t19-rv9-globalMemo-run1.log`)

  ```
  00:00 +0 -1: RI1 the view and document adapters give the same inputs, place boxes and wall neighbours, bit for bit, on every fixture at every placement [E]
    Expected: RoomInput:<RoomInput(12, band, [[26000.0,8000.0], [25750.0,8250.0], [12250.0,8250.0], [12000.0,8000.0]])>
      Actual: RoomInput:<RoomInput(12, band, [[6100.0,-100.0], [5900.0,100.0], [100.0,100.0], [-100.0,-100.0]])>
    test/room_inputs_test.dart 31:5                     expectAdaptersAgree
    test/room_inputs_test.dart 103:22                   main.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG4 ')` (exit 1; log `t19-rv9-globalMemo-run2.log`)

  ```
  00:00 +0 -1: RG4 a room's children keep their handles across a wall move, undo, redo and purge [E]
    Expected: ['Room 1', '11.78 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '11.78 m²'
    test/room_object_test.dart 289:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv9-eqNoSource — == ignores the source

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-eqNoSource-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  56d55
  <         other.source != source ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI2 ')` (exit 1; log `t19-rv9-eqNoSource-run1.log`)

  ```
  00:00 +0 -1: RI2 a RoomInput is equal only to the same source, kind and points, bit for bit; equal inputs hash alike [E]
    Expected: false
      Actual: <true>
    test/room_inputs_test.dart 286:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-eqNoClosed — == ignores closed

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-eqNoClosed-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  57d56
  <         other.closed != closed ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI2 ')` (exit 1; log `t19-rv9-eqNoClosed-run1.log`)

  ```
  00:00 +0 -1: RI2 a RoomInput is equal only to the same source, kind and points, bit for bit; equal inputs hash alike [E]
    Expected: false
      Actual: <true>
    test/room_inputs_test.dart 288:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-eqNoY — == ignores y

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-eqNoY-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  62,63c62
  <       if (other.points[i].x != points[i].x ||
  <           other.points[i].y != points[i].y) {
  ---
  >       if (other.points[i].x != points[i].x) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI2 ')` (exit 1; log `t19-rv9-eqNoY-run1.log`)

  ```
  00:00 +0 -1: RI2 a RoomInput is equal only to the same source, kind and points, bit for bit; equal inputs hash alike [E]
    Expected: false
      Actual: <true>
    test/room_inputs_test.dart 282:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-hashConst — hashCode not a function of the points' values

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept). A literally constant hash would satisfy RI2 (equal inputs hash alike), so the name is read as a hash of the point list's identity.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-hashConst-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  71,72c71
  <   int get hashCode => Object.hash(source, closed,
  <       Object.hashAll([for (final p in points) Object.hash(p.x, p.y)]));
  ---
  >   int get hashCode => Object.hash(source, closed, points);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_inputs_test.dart --plain-name 'RI2 ')` (exit 1; log `t19-rv9-hashConst-run1.log`)

  ```
  00:00 +0 -1: RI2 a RoomInput is equal only to the same source, kind and points, bit for bit; equal inputs hash alike [E]
    Expected: <440949839>
      Actual: <449369863>
    test/room_inputs_test.dart 270:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-sepLenGe — a separator exactly roomTrace.linear long counts (Task 9 review m-2, carried to Task 13: DG4)

Task 13's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-sepLenGe-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  108c108
  <       if (!((e - s).length > roomTrace.linear)) return null;
  ---
  >       if (!((e - s).length >= roomTrace.linear)) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG4 ')` (exit 1; log `t19-rv9-sepLenGe-run1.log`)

  ```
  00:00 +0 -1: DG4 separator.degenerate for a short or non-finite separator, room.degenerate for a non-finite label [E]
    Expected: empty
      Actual: [45]
    test/room_diagnostics_test.dart 363:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv9-wallFinite — a wall with a non-finite ring keeps an input (Task 9 review m-2, carried to Task 13: DG4)

Task 13's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv9-wallFinite-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  102d101
  <       if (!world.every(_finite)) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG4 ')` (exit 1; log `t19-rv9-wallFinite-run1.log`)

  ```
  00:00 +0 -1: DG4 separator.degenerate for a short or non-finite separator, room.degenerate for a non-finite label [E]
    Expected: null
      Actual: RoomInput:<RoomInput(2F, band, [[1000.0,1.5000000000000004e+307], [NaN,Infinity], [NaN,Infinity], [0.0,1.5000000000000004e+307]])>
    test/room_diagnostics_test.dart 425:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10a — centrelines traced instead of the uncut bands (spec; killers RT1, RT7, SP7)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-M-10a-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  100a101,105
  >       if (ring.isNotEmpty) {
  >         return RoomInput(
  >             h, [toWorld.transformPoint(p.start), toWorld.transformPoint(p.end)],
  >             closed: false);
  >       }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 1; log `t19-M-10a-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <1769525.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 208:21                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT7 ')` (exit 1; log `t19-M-10a-run2.log`)

  ```
  00:00 +0 -1: RT7 four thicknesses and a justification mix trace to the inner faces [E]
    Expected: a value less than or equal to <0.01>
      Actual: <1906250.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 497:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-M-10a-run3.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: a numeric value within <0.01> of <21996100.0>
      Actual: <23765625.0>
       Which:  differs by <1769525.0>
    test/startup_plan_test.dart 555:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### M-10b — cycles of either sign accepted, the least signed area wins (spec, redefined; killers RT1, RT2)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10b-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  194d193
  <     if (!(areas[c] > 0)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 1; log `t19-M-10b-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <147996100.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 208:21                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT2 ')` (exit 1; log `t19-M-10b-run2.log`)

  ```
  00:00 +0 -1: RT2 an L of six walls drawn in mixed directions, and the same L with a door, a window and a gap, is one room [E]
    Expected: a value less than or equal to <0.01>
      Actual: <48080000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 257:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10b-abs (control: revision 1's least absolute area) — the least absolute area wins (the spec's M-10b note: equivalent, fired once as a control)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10b-abs__control__revision_1_s_least_absolute_area_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  194d193
  <     if (!(areas[c] > 0)) continue;
  196c195
  <     if (outer == null || areas[c] < areas[outer]) outer = c;
  ---
  >     if (outer == null || areas[c].abs() < areas[outer].abs()) outer = c;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 0; log `t19-M-10b-abs__control__revision_1_s_least_absolute_area_-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT2 ')` (exit 0; log `t19-M-10b-abs__control__revision_1_s_least_absolute_area_-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### M-10d — the stored cut pieces traced instead of the uncut bands (spec; killers RT1, RT2)

Task 10's `t10-mutants.json` entry, re-applied at HEAD. Fired in RoomInputs._refresh (roomInputOf has no document), as Task 10 ruled.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-M-10d-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  303a304
  >     var extra = 1 << 40;
  305,307c306,330
  <       _inputs[w.handle] = roomInputOf(w.handle, w.params, w.toWorld, walls: [
  <         for (final n in _neighbours[w.handle]!) byHandle[n]!,
  <       ]);
  ---
  >       final pieces = <List<Vector2>>[];
  >       for (final slot in doc.entities.liveSlots) {
  >         if (doc.entities.ownerAt(slot) != w.handle ||
  >             doc.entities.kindAt(slot) != EntityKind.fill) {
  >           continue;
  >         }
  >         final fill = doc.geometry.read(doc.entities.geomIndexAt(slot));
  >         final boundary = Handle(fill.scalars[0].toInt());
  >         final c = doc.geometry
  >             .read(doc.entities.geomIndexAt(doc.entities.slotOf(boundary)!))
  >             .coords;
  >         pieces.add([
  >           for (var i = 0; i < c.length ~/ 2 - 1; i++)
  >             w.toWorld.transformPoint(Vector2(c[2 * i], c[2 * i + 1])),
  >         ]);
  >       }
  >       if (pieces.isEmpty) {
  >         _inputs[w.handle] = null;
  >         continue;
  >       }
  >       _inputs[w.handle] = RoomInput(w.handle, pieces.first, closed: true);
  >       for (final piece in pieces.skip(1)) {
  >         _inputs[Handle(extra++)] = RoomInput(w.handle, piece, closed: true);
  >       }
  >       if (byHandle.isEmpty) roomInputOf(w.handle, w.params, w.toWorld);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 1; log `t19-M-10d-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: <Instance of 'Traced'>
      Actual: Unbounded:<Unbounded()>
       Which: is not an instance of 'Traced'
    test/room_trace_test.dart 29:3                      traceAt
    test/room_trace_test.dart 206:19                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT2 ')` (exit 1; log `t19-M-10d-run2.log`)

  ```
  00:00 +0 -1: RT2 an L of six walls drawn in mixed directions, and the same L with a door, a window and a gap, is one room [E]
    Expected: <Instance of 'Traced'>
      Actual: Unbounded:<Unbounded()>
       Which: is not an instance of 'Traced'
    test/room_trace_test.dart 29:3                      traceAt
    test/room_trace_test.dart 256:19                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10holes — holes ignored (spec; killers RT3, RT4, SP7)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10holes-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  223c223
  <     if (!nested) holeCycles.add(c);
  ---
  >     if (!nested && holeCycles.length < 0) holeCycles.add(c);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT3 ')` (exit 1; log `t19-M-10holes-run1.log`)

  ```
  00:00 +0 -1: RT3 a column island is a hole: subtracted and anticlockwise [E]
    Expected: a value less than or equal to <0.01>
      Actual: <160000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 275:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT4 ')` (exit 1; log `t19-M-10holes-run2.log`)

  ```
  00:00 +0 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: a value less than or equal to <0.01>
      Actual: <490000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 326:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-M-10holes-run3.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: a numeric value within <0.01> of <21897500.0>
      Actual: <22057500.0>
       Which:  differs by <160000.0>
    test/startup_plan_test.dart 555:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### M-10holesign — holes not reversed: their area adds (spec; killer RT3)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10holesign-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  285,288c285
  <     holes.add(_rotated((
  <       pts: [for (var i = n - 1; i >= 0; i--) r.pts[i]],
  <       src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
  <     )));
  ---
  >     holes.add(_rotated(r));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT3 ')` (exit 1; log `t19-M-10holesign-run1.log`)

  ```
  00:00 +0 -1: RT3 a column island is a hole: subtracted and anticlockwise [E]
    Expected: a value less than or equal to <0.01>
      Actual: <320000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 275:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10seedface — the largest face holding the seed (spec; killer RT4)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10seedface-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  196c196
  <     if (outer == null || areas[c] < areas[outer]) outer = c;
  ---
  >     if (outer == null || areas[c] > areas[outer]) outer = c;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT4 ')` (exit 1; log `t19-M-10seedface-run1.log`)

  ```
  00:00 +0 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: a value less than or equal to <0.01>
      Actual: <17880000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 350:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10local — no local frame (spec; killer RT1 at +1e9 mm)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10local-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  150,151c150,151
  <   final o = seed.clone();
  <   final s0 = Vector2.zero();
  ---
  >   final o = Vector2.zero();
  >   final s0 = seed.clone();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 1; log `t19-M-10local-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <68.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 208:21                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10tol — roomTrace.linear 1e-12 (spec; killer RT1 off the origin)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-M-10tol-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  28c28
  < const Tolerance roomTrace = Tolerance(linear: 1e-6, angular: 1e-12);
  ---
  > const Tolerance roomTrace = Tolerance(linear: 1e-12, angular: 1e-12);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 1; log `t19-M-10tol-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <15015000.000000738>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 208:21                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10sep@tracer — separators dropped, at the tracer (spec; killers RT8, SP7)

Task 10's `t10-mutants.json` entry, re-applied at HEAD. Anchored on traceRoom's own sort: `outerContours` has a second copy of the sort line since Task 15.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10sep_tracer-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  154c154
  <   final sorted = [...inputs]
  ---
  >   final sorted = [...inputs.where((i) => i.closed)]
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-M-10sep_tracer-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <18130000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 566:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-M-10sep_tracer-run2.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: a numeric value within <0.01> of <21897500.0>
      Actual: <44941100.0>
       Which:  differs by <23043600.0>
    test/startup_plan_test.dart 555:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10sep@inputs — separators dropped, at the inputs (spec; killers RT8, SP7)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-M-10sep_inputs-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  108a109
  >       if (s.x == s.x) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-M-10sep_inputs-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <18130000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 566:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-M-10sep_inputs-run2.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: a numeric value within <0.01> of <21897500.0>
      Actual: <44941100.0>
       Which:  differs by <23043600.0>
    test/startup_plan_test.dart 555:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X10-collinear — no collinear clean-up (the plan says RT1; Task 10 found RT8)

Re-sited at HEAD: the clean-up loop's flag is a local of `clean` since Task 14b.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X10-collinear-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  239c239
  <     var changed = true;
  ---
  >     var changed = false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT1 ')` (exit 0; log `t19-X10-collinear-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-X10-collinear-run2.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <5>
    test/room_trace_test.dart 76:3                      expectRing
    test/room_trace_test.dart 590:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### X10-spike (re-sited: _splitDoubled, Task 14b) — no spike removal

Task 14b subsumed the spike loop in `_splitDoubled`; a spike is a doubled pair with nothing between its halves, so the mutant skips exactly those pairs.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X10-spike__re-sited___splitDoubled__Task_14b_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1041c1041,1043
  <       if (j == null || j < i) continue;
  ---
  >       if (j == null || j < i || j == i + 1 || (i == 0 && j == hs.length - 1)) {
  >         continue;
  >       }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-X10-spike__re-sited___splitDoubled__Task_14b_-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <7>
    test/room_trace_test.dart 76:3                      expectRing
    test/room_trace_test.dart 590:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X10-lowest — SeedInWall names the highest source

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X10-lowest-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  161c161
  <   for (var k = 0; k < sorted.length; k++) {
  ---
  >   for (var k = sorted.length - 1; k >= 0; k--) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT9 ')` (exit 1; log `t19-X10-lowest-run1.log`)

  ```
  00:00 +0 -1: RT9 a seed in a band, on a band's edge or on a separator is SeedInWall; a seed no ring closes around is Unbounded [E]
    Expected: <Instance of 'SeedInWall'> with `source`: <18>
      Actual: SeedInWall:<SeedInWall(26)>
       Which: has `source` with value <38>
    test/room_trace_test.dart 720:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X10-noSweepReject — the sweep's y reject dropped (equivalent: no answer changes, planned)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X10-noSweepReject-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382d381
  <       if (si.maxY < sj.minY - tol || sj.maxY < si.minY - tol) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-X10-noSweepReject-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 0; log `t19-X10-noSweepReject-run2.log`)

  ```
  00:10 +3: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### t10-canon — no canonical rotation

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-canon-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1057c1057
  <   if (n == 0) return r;
  ---
  >   if (n >= 0) return r;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-t10-canon-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 217:9                     main.<fn>
  00:00 +0 -2: RT2 an L of six walls drawn in mixed directions, and the same L with a door, a window and a gap, is one room [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 260:9                     main.<fn>
  00:00 +0 -3: RT3 a column island is a hole: subtracted and anticlockwise [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
  ... (27 more kept lines in the log)
  00:00 +1 -7: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-holeOrder — holes left unsorted

Re-sited at HEAD: the sort is `holes.sort(_byPoints)` since Task 11.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-holeOrder-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  290d289
  <   holes.sort(_byPoints);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-t10-holeOrder-run1.log`)

  ```
  00:00 +2 -1: RT3 a column island is a hole: subtracted and anticlockwise [E]
    Expected: a value less than <0>
      Actual: <1>
       Which: is not a value less than <0>
    test/room_trace_test.dart 64:7                      expectCanonical
    test/room_trace_test.dart 304:7                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-counter — debugTracedSegments not counted

Re-sited at HEAD: the count is taken from `_arrange`'s result since Task 15.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-counter-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  187c187
  <   debugTracedSegments += segments;
  ---
  >   debugTracedSegments += 0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-t10-counter-run1.log`)

  ```
  00:00 +0 -1: RT1 the sample plan's six rooms, with its fifteen openings, trace to their net floor areas at six placements [E]
    Expected: <36>
      Actual: <0>
    test/room_trace_test.dart 207:9                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 0; log `t19-t10-counter-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### t10-nested — nested components counted as holes

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-nested-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  219c219
  <         nested = true;
  ---
  >         nested = false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-t10-nested-run1.log`)

  ```
  00:00 +3 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: a value less than or equal to <0.01>
      Actual: <10000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 369:7                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-freeSep — a component with no area kept as a hole (equivalent since Task 10's fix round: the vertex-count rule subsumes it)

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-freeSep-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  211c211
  <     if (!(areas[c] < 0)) continue; // no area: not a contour
  ---
  >     if (!(areas[c] <= 0)) continue; // no area: not a contour
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-t10-freeSep-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 0; log `t19-t10-freeSep-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### t10-unsorted — inputs not sorted by source

Anchored on traceRoom's own sort.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-unsorted-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  154,155c154
  <   final sorted = [...inputs]
  <     ..sort((a, b) => a.source.value.compareTo(b.source.value));
  ---
  >   final sorted = [...inputs];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-t10-unsorted-run1.log`)

  ```
  00:01 +7 -1: RT9 a seed in a band, on a band's edge or on a separator is SeedInWall; a seed no ring closes around is Unbounded [E]
    Expected: <Instance of 'SeedInWall'> with `source`: <18>
      Actual: SeedInWall:<SeedInWall(26)>
       Which: has `source` with value <38>
    test/room_trace_test.dart 720:7                     main.<fn>
  00:01 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t10-holeLen (re-sited: the loop-area rule, Task 14b) — a hole with no area kept (Task 10 review I-1's rule)

Task 10's rule ("a hole whose spike-cleaned ring has fewer than 3 vertices is not a hole") became, in Task 14b, `if (!(areaOf(loop) < 0)) continue;`: the mutant removes it.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-holeLen__re-sited__the_loop-area_rule__Task_14b_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  280d279
  <     if (!(areaOf(loop) < 0)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 0; log `t19-t10-holeLen__re-sited__the_loop-area_rule__Task_14b_-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). Equivalent at HEAD (the header's argument); re-fired wide (`t10-holeLen (wide)`), green over seven commands. Final: equivalent.

#### rv10-holeLen4 (re-sited likewise) — a three-point hole dropped (Task 10 re-review m-r1, carried to Task 11)

Re-sited at the same Task 14b rule: loops of fewer than 4 half-edges are dropped.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-holeLen4__re-sited_likewise_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  280c280
  <     if (!(areaOf(loop) < 0)) continue;
  ---
  >     if (!(areaOf(loop) < 0) || loop.length < 4) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-rv10-holeLen4__re-sited_likewise_-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <500000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 635:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-angular — the parallel test without roomTrace.angular

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-angular-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  359c359
  <     if (den.abs() <= roomTrace.angular * di.length * dj.length) return;
  ---
  >     if (den.abs() <= 0.9 * di.length * dj.length) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-rv10-angular-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <26217500.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 659:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-sweepNoTol — the sweep window without the tolerance

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-sweepNoTol-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  377c377
  <     final right = si.maxX + tol;
  ---
  >     final right = si.maxX;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-rv10-sweepNoTol-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <14820000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 688:11                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-yNoTol — the y reject without the tolerance

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-yNoTol-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382c382
  <       if (si.maxY < sj.minY - tol || sj.maxY < si.minY - tol) continue;
  ---
  >       if (si.maxY < sj.minY || sj.maxY < si.minY) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-rv10-yNoTol-run1.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0.01>
      Actual: <18620000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 688:11                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-noTieBreak — no tie-break in the canonical rotation

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-noTieBreak-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1063c1063
  <       if (c != 0) break;
  ---
  >       break;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT6 ')` (exit 1; log `t19-rv10-noTieBreak-run1.log`)

  ```
  00:00 +0 -1: RT6 a column pushed against the ring is part of the boundary, walked around, not a hole [E]
    Expected: [
      Actual: [
       Which: at location [1] is (double, double):<(300.0, 600.0)> instead of (double, double):<(7900.0, 100.0)>
    test/room_trace_test.dart 471:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-holeSrc — a hole's sources not moved with its edges

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-holeSrc-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  287c287
  <       src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
  ---
  >       src: [for (var i = n - 1; i >= 0; i--) r.src[i]],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT4 ')` (exit 1; log `t19-rv10-holeSrc-run1.log`)

  ```
  00:00 +0 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: [34]
      Actual: [46]
       Which: at location [0] is <46> instead of <34>
    test/room_trace_test.dart 108:5                     expectEdgeSources
    test/room_trace_test.dart 334:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-srcMergeDrop — a merged edge keeps one source

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-srcMergeDrop-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  248c248
  <           src[prev] = {...src[prev], ...src[i]};
  ---
  >           src[prev] = {...src[prev]};
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT7 ')` (exit 1; log `t19-rv10-srcMergeDrop-run1.log`)

  ```
  00:00 +0 -1: RT7 four thicknesses and a justification mix trace to the inner faces [E]
    Expected: [26, 30]
      Actual: [30]
       Which: at location [0] is <30> instead of <26>
    test/room_trace_test.dart 108:5                     expectEdgeSources
    test/room_trace_test.dart 537:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-sourcesUnsorted — sources not ascending

Task 10's `t10-mutants.json` entry, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-sourcesUnsorted-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1073c1073
  <     Set.unmodifiable(s.toList()..sort((a, b) => a.value.compareTo(b.value)));
  ---
  >     Set.unmodifiable(s.toList());
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT7 ')` (exit 1; log `t19-rv10-sourcesUnsorted-run1.log`)

  ```
  00:00 +0 -1: RT7 four thicknesses and a justification mix trace to the inner faces [E]
    Expected: [26, 30]
      Actual: [30, 26]
       Which: at location [0] is <30> instead of <26>
    test/room_trace_test.dart 108:5                     expectEdgeSources
    test/room_trace_test.dart 537:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-nestedNoSeed — the nesting test ignores the seed

The Task 10 review's `rv10-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-nestedNoSeed-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  218c218
  <       if (pointInRing(p, pts) && !pointInRing(s0, pts)) {
  ---
  >       if (pointInRing(p, pts)) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-rv10-nestedNoSeed-run1.log`)

  ```
  00:00 +3 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: a value less than or equal to <0.01>
      Actual: <10000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_trace_test.dart 36:3                      expectArea
    test/room_trace_test.dart 374:7                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-seedCheckLate — the seed-in-band check skipped

The Task 10 review's `rv10-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-seedCheckLate-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  165c165
  <     if (closed && n >= 3 && pointInRing(s0, pts)) {
  ---
  >     if (closed && n >= 3 && pointInRing(s0, pts) && k < 0) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-rv10-seedCheckLate-run1.log`)

  ```
  00:00 +7 -1: RT9 a seed in a band, on a band's edge or on a separator is SeedInWall; a seed no ring closes around is Unbounded [E]
    Expected: <Instance of 'SeedInWall'> with `source`: <18>
      Actual: Traced:<Traced(area 1200000.0, 4 ring points, 0 holes)>
       Which: is not an instance of 'SeedInWall'
    test/room_trace_test.dart 703:7                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv10-noPreRotate — no rotation before the collinear clean-up (equivalent, Task 10 review)

The Task 10 review's `rv10-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-noPreRotate-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  229c229
  <     final ring = _rotated((
  ---
  >     final ring = ((
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv10-noPreRotate-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

#### rv10-collinearNoAlong — the collinear test without the along bound (equivalent, Task 10 review)

The Task 10 review's `rv10-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-collinearNoAlong-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  247c247
  <         if (distToSegment(b, a, c) <= tol && along > 0 && along < d.dot(d)) {
  ---
  >         if (distToSegment(b, a, c) <= tol) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv10-collinearNoAlong-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

#### rv10-noSign — the contour sign check dropped (equivalent since Task 10's fix round: a NaN guard)

The Task 10 review's `rv10-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv10-noSign-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  211d210
  <     if (!(areas[c] < 0)) continue; // no area: not a contour
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv10-noSign-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 0; log `t19-rv10-noSign-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### M-10cert — D7 returns its first Traced result (spec; killer LZ2; FZ1 and DF1 per the Task 14 re-review ruling)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10cert-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  601a602
  >   return face;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart --plain-name 'LZ2 ')` (exit 1; log `t19-M-10cert-run1.log`)

  ```
  00:00 +0 -1: LZ2 the triangle: the column beyond the first growth box is found by the certificate [E]
    Expected: a numeric value within <0.01> of <32766900.233162623>
      Actual: <32926900.233162627>
       Which:  differs by <160000.00000000373>
    test/room_localise_test.dart 424:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 1; log `t19-M-10cert-run2.log`)

  ```
  00:00 +0 -1: FZ1 a seeded random run: no edit is refused because of rooms, drift() stays empty, every tint triangulates and is step 1 [E]
    Expected: <8>
      Actual: <4>
    test/room_follow_test.dart 935:11                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'DF1 ')` (exit 0; log `t19-M-10cert-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (2 of 3 commands red).

#### M-10c — the label at the ring's box centre (spec; killer RL1)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-M-10c-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  76c76
  <   return (point: Vector2(best.x, best.y) + o, distance: best.d);
  ---
  >   return (point: Vector2(minX + w / 2, minY + ht / 2) + o, distance: best.d);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RL1 ')` (exit 1; log `t19-M-10c-run1.log`)

  ```
  00:00 +0 -1: RL1 the thin L's label point is inside it, 585.786 from its boundary, at six placements [E]
    Expected: true
      Actual: <false>
    test/room_label_test.dart 88:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10centroid — the label at the centroid (spec; killer RL1)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-M-10centroid-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  76c76
  <   return (point: Vector2(best.x, best.y) + o, distance: best.d);
  ---
  >   return (point: _centroid(r) + o, distance: best.d);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RL1 ')` (exit 1; log `t19-M-10centroid-run1.log`)

  ```
  00:00 +0 -1: RL1 the thin L's label point is inside it, 585.786 from its boundary, at six placements [E]
    Expected: true
      Actual: <false>
    test/room_label_test.dart 88:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-canonical — no canonical order (Ruling 10-7): its killer moved from LZ1 to RT2/3/4/6/7/8 (Task 11 ruling)

Re-sited at HEAD: the hole sort is `holes.sort(_byPoints)`. LZ1 is fired too, and stays green: far inputs never move the walk's start (the ruling's argument).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X11-canonical-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  290d289
  <   holes.sort(_byPoints);
  1057c1056
  <   if (n == 0) return r;
  ---
  >   if (n >= 0) return r;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart --plain-name 'LZ1 ')` (exit 0; log `t19-X11-canonical-run1.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT2 ')` (exit 1; log `t19-X11-canonical-run2.log`)

  ```
  00:00 +0 -1: RT2 an L of six walls drawn in mixed directions, and the same L with a door, a window and a gap, is one room [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 260:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT3 ')` (exit 1; log `t19-X11-canonical-run3.log`)

  ```
  00:00 +0 -1: RT3 a column island is a hole: subtracted and anticlockwise [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 283:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT4 ')` (exit 1; log `t19-X11-canonical-run4.log`)

  ```
  00:00 +0 -1: RT4 a hollow column is a hole; its courtyard is not a hole of the room, and is its own face [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 345:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT6 ')` (exit 1; log `t19-X11-canonical-run5.log`)

  ```
  00:00 +0 -1: RT6 a column pushed against the ring is part of the boundary, walked around, not a hole [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 413:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT7 ')` (exit 1; log `t19-X11-canonical-run6.log`)

  ```
  00:00 +0 -1: RT7 four thicknesses and a justification mix trace to the inner faces [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 507:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart --plain-name 'RT8 ')` (exit 1; log `t19-X11-canonical-run7.log`)

  ```
  00:00 +0 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: a value less than or equal to <0>
      Actual: <1>
       Which: is not a value less than or equal to <0>
    test/room_trace_test.dart 53:7                      expectCanonical
    test/room_trace_test.dart 644:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (6 of 7 commands red).

#### X11-noUnion — growth stops at the first B without U

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X11-noUnion-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  598c598
  <     if (result is SeedInWall || _holds(b, u)) return result;
  ---
  >     return result;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart --plain-name 'LZ1 ')` (exit 1; log `t19-X11-noUnion-run1.log`)

  ```
  00:00 +0 -1: LZ1 the localised trace equals the all-inputs trace bit for bit on every fixture at every placement, with and without 200 far walls [E]
    Expected: Type:<Traced>
      Actual: Type:<Unbounded>
    test/room_localise_test.dart 353:13                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 1; log `t19-X11-noUnion-run2.log`)

  ```
  00:00 +0 -1: LZ1 the localised trace equals the all-inputs trace bit for bit on every fixture at every placement, with and without 200 far walls [E]
    Expected: Type:<Traced>
      Actual: Type:<Unbounded>
    test/room_localise_test.dart 353:13                 main.<fn>
  00:00 +0 -2: LZ2 the triangle: the column beyond the first growth box is found by the certificate [E]
    Expected: <Instance of 'Traced'>
      Actual: Unbounded:<Unbounded()>
       Which: is not an instance of 'Traced'
    test/room_localise_test.dart 422:7                  main.<fn>
  00:00 +0 -3: LZ4 a seed with a non-finite coordinate, and a source with nothing placed, trace Unbounded at once [E]
    Expected: a string starting with 'Traced'
      Actual: 'Unbounded()'
    test/room_localise_test.dart 453:7                  main.<fn>
  00:00 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X11-ringOnly — bridges tested against the outer ring only

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X11-ringOnly-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  807,808c807
  <       keyholed,
  <       for (var j = k; j < order.length; j++) holes[order[j]],
  ---
  >       ring,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-X11-ringOnly-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <0.5>
      Actual: <0.35355339059333346>
       Which:  differs by <0.14644660940666654>
    test/room_tint_test.dart 72:5                       expectKeyhole
    test/room_tint_test.dart 335:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-comma — the area format's grouping

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-X11-comma-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  168c168
  <         '${(mm2 / 1e6).toStringAsFixed(2)} m²',
  ---
  >         '${(mm2 / 1e6).toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => "${m[1]},")} m²',
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RA1 ')` (exit 1; log `t19-X11-comma-run1.log`)

  ```
  00:00 +0 -1: RA1 the area format in each of the five units [E]
    Expected: '1234.57 m²'
      Actual: '1,234.57 m²'
       Which: is different.
              Expected: 1234.57 m²
                Actual: 1,234.57 m² ...
    test/room_label_test.dart 175:9                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X11-feet — 304.8 squared as an integer product (planned equivalent; killed after fix round 1)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-X11-feet-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  171c171
  <         '${(mm2 / (304.8 * 304.8)).toStringAsFixed(2)} ft²',
  ---
  >         '${(mm2 / (3048 * 3048 / 100)).toStringAsFixed(2)} ft²',
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RA1 ')` (exit 0; log `t19-X11-feet-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RA2 ')` (exit 0; log `t19-X11-feet-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red). The planned "one-ulp difference no label shows" is wrong at a tie (fix round 1, the audit's I-1): re-fired at `RA1`'s new tie case, red (`r1-X11-feet`). Final: killed.

#### t11-viewBoundsNull — the view source's U is null

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t11-viewBoundsNull-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  184c184
  <     return u.isEmpty ? null : u;
  ---
  >     return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 1; log `t19-t11-viewBoundsNull-run1.log`)

  ```
  00:00 +0 -1: LZ1 the localised trace equals the all-inputs trace bit for bit on every fixture at every placement, with and without 200 far walls [E]
    Expected: true
      Actual: <false>
    test/room_localise_test.dart 346:11                 main.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-docBoundsNull — the document adapter's U is null

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t11-docBoundsNull-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  322c322
  <     _bounds = u.isEmpty ? null : u;
  ---
  >     _bounds = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 1; log `t19-t11-docBoundsNull-run1.log`)

  ```
  00:00 +0 -1: LZ1 the localised trace equals the all-inputs trace bit for bit on every fixture at every placement, with and without 200 far walls [E]
    Expected: true
      Actual: <false>
    test/room_localise_test.dart 346:11                 main.<fn>
  00:00 +0 -2: LZ2 the triangle: the column beyond the first growth box is found by the certificate [E]
    Expected: <Instance of 'Traced'>
      Actual: Unbounded:<Unbounded()>
       Which: is not an instance of 'Traced'
    test/room_localise_test.dart 422:7                  main.<fn>
  00:00 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-slitLeft — the slit on the bridge's left

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-slitLeft-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  818c818
  <       final slit = Vector2(d.y, -d.x) * kSlit; // to the bridge's right
  ---
  >       final slit = Vector2(-d.y, d.x) * kSlit; // to the bridge's right
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 1; log `t19-t11-slitLeft-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <0.5>
      Actual: <0.17795166716094465>
       Which:  differs by <0.3220483328390553>
    test/room_tint_test.dart 72:5                       expectKeyhole
    test/room_tint_test.dart 259:30                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-farthest — the farthest vertex bridged first

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-farthest-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  803c803
  <             (keyholed[a] - h).length2.compareTo((keyholed[b] - h).length2);
  ---
  >             (keyholed[b] - h).length2.compareTo((keyholed[a] - h).length2);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 1; log `t19-t11-farthest-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/room_tint_test.dart 260:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-holesAsc — holes joined in ascending order of their rightmost x

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-holesAsc-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  784c784
  <     final c = right[b].compareTo(right[a]);
  ---
  >     final c = right[a].compareTo(right[b]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 1; log `t19-t11-holesAsc-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: true
      Actual: <false>
    test/room_tint_test.dart 260:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-skipStep2 — D9's step 2 skipped

Re-sited at HEAD: step 2 is `takes(2, ring)` since Task 13.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-skipStep2-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  858d857
  <   if (takes(2, ring)) return Tint(2, ring, leftOut);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 1; log `t19-t11-skipStep2-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <2>
      Actual: <3>
    test/room_tint_test.dart 471:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-noSplitPole — the pole search never splits a cell

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-t11-noSplitPole-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  68c68
  <     if (!(c.max - best.d > precision)) continue;
  ---
  >     continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart)` (exit 1; log `t19-t11-noSplitPole-run1.log`)

  ```
  00:00 +0 -1: RL1 the thin L's label point is inside it, 585.786 from its boundary, at six placements [E]
    Expected: true
      Actual: <false>
    test/room_label_test.dart 88:7                      main.<fn>
  00:00 +0 -2: RL2 a column at the box centre moves the label point off it [E]
    Expected: a value less than or equal to <10>
      Actual: <100.0>
       Which: is not a value less than or equal to <10>
    test/room_label_test.dart 134:7                     main.<fn>
  00:00 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-noHoleDist — the pole ignores the holes' distance

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-t11-noHoleDist-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  85c85
  <   for (final r in [ring, ...holes]) {
  ---
  >   for (final r in [ring]) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart)` (exit 1; log `t19-t11-noHoleDist-run1.log`)

  ```
  00:00 +1 -1: RL2 a column at the box centre moves the label point off it [E]
    Expected: a value less than or equal to <10>
      Actual: <100.0>
       Which: is not a value less than or equal to <10>
    test/room_label_test.dart 134:7                     main.<fn>
  00:00 +2 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-margin0 — the certificate margin 0 (killed by LZ1 after 9eb913e)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-margin0-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  551c551
  < const double kCertificateMargin = 1;
  ---
  > const double kCertificateMargin = 0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart --plain-name 'LZ1 ')` (exit 1; log `t19-t11-margin0-run1.log`)

  ```
  00:01 +0 -1: LZ1 the localised trace equals the all-inputs trace bit for bit on every fixture at every placement, with and without 200 far walls [E]
    Expected: [[18, 34], [22], [26], [30]]
      Actual: [[18], [22], [26], [30]]
       Which: at location [0][1] is [18] which shorter than expected
    test/room_localise_test.dart 353:13                 main.<fn>
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t11-noFinal (= t14f-firstCert) — D7 skips the canonical re-trace (equivalent on every fixture, ruled at Tasks 11 and 14)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-noFinal____t14f-firstCert_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  619c619
  <   if (_sameHandles(traced, c)) return face;
  ---
  >   return face;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 0; log `t19-t11-noFinal____t14f-firstCert_-run1.log`)

  ```
  00:10 +3: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-t11-noFinal____t14f-firstCert_-run2.log`)

  ```
  00:08 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'DF1 ')` (exit 0; log `t19-t11-noFinal____t14f-firstCert_-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 3 commands red).

#### t11-r1-noVertexRule — the bridge's vertex rule dropped (Task 11 review I-1)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t11-r1-noVertexRule-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  876,882c876
  <     for (final p in r) {
  <       if (distToSegment(p, h, v) <= tol &&
  <           (p - h).length > tol &&
  <           (p - v).length > tol) {
  <         return true;
  <       }
  <     }
  ---
  >     // t11-r1-noVertexRule
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-t11-r1-noVertexRule-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <0.5>
      Actual: <0.35355339059333346>
       Which:  differs by <0.14644660940666654>
    test/room_tint_test.dart 72:5                       expectKeyhole
    test/room_tint_test.dart 335:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv11-seedGuard — a non-finite seed is not Unbounded at once (Task 11 review m-2: LZ4)

Task 11's `t11-sites/` fragment, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv11-seedGuard-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  578c578
  <   if (u == null || !seed.x.isFinite || !seed.y.isFinite) {
  ---
  >   if (u == null) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart --plain-name 'LZ4 ')` (exit 1; log `t19-rv11-seedGuard-run1.log`)

  ```
  00:05 +0 -1: LZ4 a seed with a non-finite coordinate, and a source with nothing placed, trace Unbounded at once [E]
    Expected: 'Unbounded()'
      Actual: <null>
       Which: not an <Instance of 'String'>
    test/room_localise_test.dart 464:9                  main.<fn>
  00:05 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv11-noSelf — the joining hole is not an obstacle to its own bridge

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv11-noSelf-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  808c808
  <       for (var j = k; j < order.length; j++) holes[order[j]],
  ---
  >       for (var j = k + 1; j < order.length; j++) holes[order[j]],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv11-noSelf-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a numeric value within <1e-9> of <0.5>
      Actual: <0.35355339059333346>
       Which:  differs by <0.14644660940666654>
    test/room_tint_test.dart 72:5                       expectKeyhole
    test/room_tint_test.dart 335:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv11-prec40 — the pole's precision 40 mm

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-rv11-prec40-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  28c28
  <     {double precision = 10}) {
  ---
  >     {double precision = 40}) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RL1 ')` (exit 1; log `t19-rv11-prec40-run1.log`)

  ```
  00:00 +0 -1: RL1 the thin L's label point is inside it, 585.786 from its boundary, at six placements [E]
    Expected: a value less than or equal to <10>
      Actual: <13.065248556337224>
       Which: is not a value less than or equal to <10>
    test/room_label_test.dart 90:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RL2 ')` (exit 1; log `t19-rv11-prec40-run2.log`)

  ```
  00:00 +0 -1: RL2 a column at the box centre moves the label point off it [E]
    Expected: a value less than or equal to <10>
      Actual: <18.75>
       Which: is not a value less than or equal to <10>
    test/room_label_test.dart 134:7                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv11-r1-endsIncluded — the vertex rule blocks at the bridge's own ends

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv11-r1-endsIncluded-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  877,879c877
  <       if (distToSegment(p, h, v) <= tol &&
  <           (p - h).length > tol &&
  <           (p - v).length > tol) {
  ---
  >       if (distToSegment(p, h, v) <= tol) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv11-r1-endsIncluded-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: empty
      Actual: [0, 1]
    test/room_tint_test.dart 253:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10tintcolour — the tint a TrueColor, not ACI 7 (spec; killers RR3, RG1)

The Task 18 review's fragment (`rv18-m/tc`).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10tintcolour-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  105c105
  < const DraftColor kRoomTintColor = IndexedColor(7);
  ---
  > const DraftColor kRoomTintColor = TrueColor(0x000000);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'RR3 ')` (exit 1; log `t19-M-10tintcolour-run1.log`)

  ```
  Expected: a numeric value within <2.0> of <53.839215686274514>
    Actual: <28>
     Which:  differs by <25.839215686274514>
  00:02 +0 -1: RR3 on Blueprint the tint lifts the paper: white at about 10% [E]
  00:02 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-M-10tintcolour-run2.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: IndexedColor:<IndexedColor(7)>
      Actual: TrueColor:<TrueColor(0x000000)>
    test/room_object_test.dart 189:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10offset@generate — the stored label offset ignored, at RoomType.generate's anchor (spec; killers GR1, RL3)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10offset_generate-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  287c287
  <         toWorld.transformPoint(toLocal.transformPoint(pole) + _offsetOf(p));
  ---
  >         toWorld.transformPoint(toLocal.transformPoint(pole) + Vector2.zero());
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR1 ')` (exit 1; log `t19-M-10offset_generate-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: a value less than <0.000001>
      Actual: <708.4315725601167>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 264:7                     main.<fn>
  Expected: a value less than <0.000001>
    Actual: <708.4315725601167>
     Which: is not a value less than <0.000001>
  00:01 +0 -2: GR1 (shell) the label grip is shown at the anchor and a drag stores the offset in one undo step, origin [E]
  Expected: a value less than <0.000001>
    Actual: <708.4315725595843>
     Which: is not a value less than <0.000001>
  00:02 +0 -3: GR1 (shell) the label grip is shown at the anchor and a drag stores the offset in one undo step, corpus far origin, 23 deg, own groups [E]
  00:02 +0 -4: GR6 the label grip under a rotated, translated, scaled room group: GR1 and GR2 again [E]
    Expected: a value less than <0.000001>
      Actual: <708.4315725595>
  ... (3 more kept lines in the log)
  00:02 +0 -4: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 1; log `t19-M-10offset_generate-run2.log`)

  ```
  00:00 +0 -1: RL3 a label offset rides with the pole across a wall move [E]
    Expected: a value less than <0.000001>
      Actual: <342.6737697869506>
       Which: is not a value less than <0.000001>
    test/room_object_test.dart 441:9                    main.<fn>.expectRides
    test/room_object_test.dart 453:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10offsetref — the offset taken from the seed, not the pole (spec; killer RL3)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10offsetref-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  287c287
  <         toWorld.transformPoint(toLocal.transformPoint(pole) + _offsetOf(p));
  ---
  >         toWorld.transformPoint(p.seed + _offsetOf(p));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 1; log `t19-M-10offsetref-run1.log`)

  ```
  00:00 +0 -1: RL3 a label offset rides with the pole across a wall move [E]
    Expected: a value less than <0.000001>
      Actual: <1624.9616341624808>
       Which: is not a value less than <0.000001>
    test/room_object_test.dart 441:9                    main.<fn>.expectRides
    test/room_object_test.dart 453:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10pagekey@room — every page change seeds every room: RoomType.pageKey is the whole page (spec; app site; Task 12 found RA2)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10pagekey_room-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  236c236
  <     return (p.displayUnit, p.scaleDenominator);
  ---
  >     return p;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RA2 ')` (exit 1; log `t19-M-10pagekey_room-run1.log`)

  ```
  00:00 +0 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: <0>
      Actual: <1>
    test/room_object_test.dart 589:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart)` (exit 1; log `t19-M-10pagekey_room-run2.log`)

  ```
  00:00 +8 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: <0>
      Actual: <1>
    test/room_object_test.dart 589:7                    main.<fn>
  00:00 +9 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN6 ')` (exit 0; log `t19-M-10pagekey_room-run3.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (2 of 3 commands red).

#### X12-alpha — transparency 26, the alpha, not 229

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X12-alpha-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  305c305
  <             transparency: kRoomTintTransparency,
  ---
  >             transparency: 26,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-X12-alpha-run1.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: <229>
      Actual: <26>
    test/room_object_test.dart 190:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-fillFlag — invisible on the fill, not the boundary

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X12-fillFlag-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  306c306
  <             boundaryFlags: EntityFlags.invisible),
  ---
  >             flags: EntityFlags.invisible),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-X12-fillFlag-run1.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: <0>
      Actual: <1>
    test/room_object_test.dart 191:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-swap — the area label before the name

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X12-swap-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  308,310d307
  <           label(anchorW + Vector2(0, kRoomLineOffset * hName), hName), p.name,
  <           textAttrs: kRoomLabelAttrs),
  <       Generated.text(
  312a310,312
  >           textAttrs: kRoomLabelAttrs),
  >       Generated.text(
  >           label(anchorW + Vector2(0, kRoomLineOffset * hName), hName), p.name,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-X12-swap-run1.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: 'Room 1'
      Actual: '10.83 m²'
       Which: is different.
              Expected: Room 1
                Actual: 10.83 m²
    test/room_object_test.dart 209:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X12-noSeed (= X14-noSeedBox) — the read box without the seed (killed in DG2, Task 12 review m-5 ruling; FZ1 cannot)

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X12-noSeed____X14-noSeedBox_-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  224,225c224
  <     final box =
  <         s.x.isFinite && s.y.isFinite ? stored.expandedToPoint(s) : stored;
  ---
  >     final box = stored;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-X12-noSeed____X14-noSeedBox_-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: ['Wall room', '11.78 m²']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 236:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-X12-noSeed____X14-noSeedBox_-run2.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### t12-noScale — label heights not divided by the group's scale

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-noScale-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  295c295
  <           scalars: Float64List.fromList([h / scale, rotation, 1, 0]));
  ---
  >           scalars: Float64List.fromList([h, rotation, 1, 0]));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL4 ')` (exit 1; log `t19-t12-noScale-run1.log`)

  ```
  00:00 +0 -1: RL4 under a rotated, translated, scaled room group the labels are horizontal in world and sized on paper [E]
    Expected: a numeric value within <1e-9> of <125.0>
      Actual: <187.5>
       Which:  differs by <62.5>
    test/room_object_test.dart 523:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-noRot — labels not counter-rotated

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-noRot-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  290c290
  <     final rotation = -math.atan2(toWorld.b, toWorld.a) + 0.0;
  ---
  >     final rotation = 0.0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL4 ')` (exit 1; log `t19-t12-noRot-run1.log`)

  ```
  00:00 +0 -1: RL4 under a rotated, translated, scaled room group the labels are horizontal in world and sized on paper [E]
    Expected: a numeric value within <1e-12> of <0>
      Actual: <0.4014257279586958>
       Which:  differs by <0.4014257279586958>
    test/room_object_test.dart 521:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-localLines — label lines offset in local, not world, directions

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-localLines-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  308c308,312
  <           label(anchorW + Vector2(0, kRoomLineOffset * hName), hName), p.name,
  ---
  >           label(
  >               toWorld.transformPoint(toLocal.transformPoint(anchorW) +
  >                   Vector2(0, kRoomLineOffset * hName)),
  >               hName),
  >           p.name,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL4 ')` (exit 1; log `t19-t12-localLines-run1.log`)

  ```
  00:00 +0 -1: RL4 under a rotated, translated, scaled room group the labels are horizontal in world and sized on paper [E]
    Expected: a numeric value within <0.000001> of <0>
      Actual: <-51.28346061427146>
       Which:  differs by <51.28346061427146>
    test/room_object_test.dart 527:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-tintLinear — the tint mapped without the seed

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-tintLinear-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  182c182
  <       [for (final q in r) seed + toLocal.transformDirection(q)];
  ---
  >       [for (final q in r) toLocal.transformDirection(q)];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG1 ')` (exit 1; log `t19-t12-tintLinear-run1.log`)

  ```
  00:00 +0 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: a value less than <0.00001>
      Actual: <2252.769143188001>
       Which: is not a value less than <0.00001>
    test/room_object_test.dart 67:5                     expectTintRect
    test/room_object_test.dart 226:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-defaultPage — the fallback page is 1:100

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-defaultPage-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  135c135
  < final PageComponent _defaultPage = PageComponent();
  ---
  > final PageComponent _defaultPage = PageComponent(scaleDenominator: 100);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RX1 ')` (exit 1; log `t19-t12-defaultPage-run1.log`)

  ```
  00:00 +0 -1: RX1 a room with no page reads 1:50 and metres [E]
    Expected: <125>
      Actual: <250.0>
    test/room_object_test.dart 619:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-keyScaleOnly — pageKey the scale only

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-keyScaleOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  236c236
  <     return (p.displayUnit, p.scaleDenominator);
  ---
  >     return p.scaleDenominator;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart)` (exit 1; log `t19-t12-keyScaleOnly-run1.log`)

  ```
  00:00 +8 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: <1>
      Actual: <0>
    test/room_object_test.dart 599:7                    main.<fn>
  00:00 +9 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN6 ')` (exit 0; log `t19-t12-keyScaleOnly-run2.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### t12-keyUnitOnly — pageKey the unit only

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-keyUnitOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  236c236
  <     return (p.displayUnit, p.scaleDenominator);
  ---
  >     return p.displayUnit;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart)` (exit 1; log `t19-t12-keyUnitOnly-run1.log`)

  ```
  00:00 +8 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: <250.0>
      Actual: <125.0>
    test/room_object_test.dart 560:9                    main.<fn>.expectLabels
    test/room_object_test.dart 604:7                    main.<fn>
  00:00 +9 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN6 ')` (exit 0; log `t19-t12-keyUnitOnly-run2.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### t12-negZero — the rotation keeps -0.0

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-negZero-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  290c290
  <     final rotation = -math.atan2(toWorld.b, toWorld.a) + 0.0;
  ---
  >     final rotation = -math.atan2(toWorld.b, toWorld.a);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart)` (exit 1; log `t19-t12-negZero-run1.log`)

  ```
  00:00 +1 -1: RG1 a room generates its tint, its name and its area, in that order, with their attributes, at six placements [E]
    Expected: false
      Actual: <true>
    test/room_object_test.dart 217:7                    main.<fn>
  00:00 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-nonFinite — a non-finite label offset used as is

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-nonFinite-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  428c428
  <       (final dx, final dy) when dx.isFinite && dy.isFinite => Vector2(dx, dy),
  ---
  >       (final dx, final dy) => Vector2(dx, dy),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 1; log `t19-t12-nonFinite-run1.log`)

  ```
  00:00 +0 -1: RL3 a label offset rides with the pole across a wall move [E]
    Expected: a value less than <0.000001>
      Actual: <NaN>
       Which: is not a value less than <0.000001>
    test/room_object_test.dart 447:9                    main.<fn>.expectRides
    test/room_object_test.dart 453:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t12-margin0 (= X14-margin0) — the read box not grown by 2 mm (Task 12 review I-1: RG7)

Task 14's `t14-mutants.json` form.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t12-margin0____X14-margin0_-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  226c226
  <     return box.expandedBy(kRoomReadMargin);
  ---
  >     return box.expandedBy(0);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG7 ')` (exit 1; log `t19-t12-margin0____X14-margin0_-run1.log`)

  ```
  00:00 +0 -1: RG7 a room's read box reaches past a stored tint that rounds inside its face: a separator moved away from it rebuilds it [E]
    Expected: ['Room 1', '22.94 m²']
      Actual: ['Room 1', '22.56 m²']
       Which: at location [1] is '22.56 m²' instead of '22.94 m²'
    test/room_object_test.dart 413:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-t12-margin0____X14-margin0_-run2.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### rv12-memoGlobal — the trace memo shared across views

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-memoGlobal-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  158a159
  > final Map<Handle, TraceResult> _globalTraces = {};
  160c161
  <   final memo = _tracesByView[view] ??= <Handle, TraceResult>{};
  ---
  >   final memo = _globalTraces;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RG4 ')` (exit 1; log `t19-rv12-memoGlobal-run1.log`)

  ```
  00:00 +0 -1: RG4 a room's children keep their handles across a wall move, undo, redo and purge [E]
    Expected: ['Room 1', '11.78 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '11.78 m²'
    test/room_object_test.dart 289:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RG3 ')` (exit 1; log `t19-rv12-memoGlobal-run2.log`)

  ```
  00:00 +0 -1: RG3 the shared partition moved 500 mm: both rooms' areas and labels follow, same handles, one undo step [E]
    Expected: ['Room 1', '12.73 m²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '12.73 m²'
    test/room_follow_test.dart 266:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv12-scaleA — the group scale read as the transform's a

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-scaleA-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  288c288
  <     final scale = toWorld.scaleMagnitude;
  ---
  >     final scale = toWorld.a;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL4 ')` (exit 1; log `t19-rv12-scaleA-run1.log`)

  ```
  00:00 +0 -1: RL4 under a rotated, translated, scaled room group the labels are horizontal in world and sized on paper [E]
    Expected: a numeric value within <1e-9> of <125.0>
      Actual: <135.79504717566203>
       Which:  differs by <10.795047175662035>
    test/room_object_test.dart 523:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-offsetWorld — the label offset added in world (Task 12 review m-1: RL4)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-offsetWorld-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  287c287
  <         toWorld.transformPoint(toLocal.transformPoint(pole) + _offsetOf(p));
  ---
  >         pole + _offsetOf(p);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL4 ')` (exit 1; log `t19-rv12-offsetWorld-run1.log`)

  ```
  00:00 +0 -1: RL4 under a rotated, translated, scaled room group the labels are horizontal in world and sized on paper [E]
    Expected: a value less than <0.000001>
      Actual: <30.147773070701916>
       Which: is not a value less than <0.000001>
    test/room_object_test.dart 539:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-dxOnly — the offset's finiteness checked on dx only (Task 12 review m-2: RL3)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-dxOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  428c428
  <       (final dx, final dy) when dx.isFinite && dy.isFinite => Vector2(dx, dy),
  ---
  >       (final dx, final dy) when dx.isFinite => Vector2(dx, dy),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 1; log `t19-rv12-dxOnly-run1.log`)

  ```
  00:00 +0 -1: RL3 a label offset rides with the pole across a wall move [E]
    Expected: a value less than <0.000001>
      Actual: <NaN>
       Which: is not a value less than <0.000001>
    test/room_object_test.dart 449:9                    main.<fn>.expectRides
    test/room_object_test.dart 453:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-tintSeedW — the tint mapped through the world seed (equivalent up to rounding, Task 12 review)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-tintSeedW-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  182c182
  <       [for (final q in r) seed + toLocal.transformDirection(q)];
  ---
  >       [for (final q in r) toLocal.transformPoint(q + seedW)];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart)` (exit 0; log `t19-rv12-tintSeedW-run1.log`)

  ```
  00:00 +10: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-rv12-tintSeedW-run2.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 0; log `t19-rv12-tintSeedW-run3.log`)

  ```
  00:01 +12: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 3 commands red).

#### M-10slit — the exact keyhole, slit 0 (spec; killers RG2, SP5)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10slit-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  681c681
  < const double kSlit = 0.5;
  ---
  > const double kSlit = 0.0;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-M-10slit-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: an object with length of <10>
      Actual: [
       Which: has length of <4>
    test/room_dissolve_test.dart 88:3                   expectKeyhole
    test/room_dissolve_test.dart 195:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP5 ')` (exit 1; log `t19-M-10slit-run2.log`)

  ```
  00:00 +0 -1: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say, then a column, a separator and seven rooms as spec 10 D23 says; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: empty
      Actual: [
    test/startup_plan_test.dart 486:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10shared — a room whose face holds another room's seed dissolves (spec; killers RS4, RD5)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10shared-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  242,243c242,254
  <   bool dissolves(ParametricView view, Handle self) =>
  <       _traceOf(view, self) is! Traced;
  ---
  >   bool dissolves(ParametricView view, Handle self) {
  >     final t = _traceOf(view, self);
  >     if (t is! Traced) return true;
  >     final p = view.paramsOf<RoomParams>(self)!;
  >     final seedW = view.toWorld(self).transformPoint(p.seed);
  >     final ring = [for (final q in t.ring) q - seedW];
  >     for (final o in view.objectsOf<RoomParams>()) {
  >       if (o == self) continue;
  >       final q = view.toWorld(o).transformPoint(view.paramsOf<RoomParams>(o)!.seed) - seedW;
  >       if (pointInRing(q, ring)) return true;
  >     }
  >     return false;
  >   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RS4 ')` (exit 1; log `t19-M-10shared-run1.log`)

  ```
  00:00 +0 -1: RS4 the room's own partition moved into the west wall's band merges the two rooms [E]
    Expected: ['Room 1', '29.64 m²']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_follow_test.dart 400:9                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD5 ')` (exit 1; log `t19-M-10shared-run2.log`)

  ```
  00:00 +0 -1: RD5 a partition pulled back 160 mm leaves both rooms in one face, reported once [E]
    Expected: ['Room 1', '29.27 m²']
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_dissolve_test.dart 669:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### M-10share2 — room.shared reported by both rooms of a pair (spec; killer DG1)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10share2-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  405c405
  <     if (other.value <= self.value) continue;
  ---
  >     if (other == self) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-M-10share2-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [
      Actual: [
       Which: at location [2] is Diagnostic:<[warning] room.shared: Study and Den share a space> instead of Diagnostic:<[warning] room.shared: Study and Nook share a space>
    test/room_diagnostics_test.dart 99:9                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10objects — diagnose's objectsOf<RoomParams>() replaced by [self] (spec; Ruling 10-27; killer DG1)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10objects-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  404c404
  <   for (final other in view.objectsOf<RoomParams>()) {
  ---
  >   for (final other in [self]) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-M-10objects-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 99:9                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-higher — room.shared reported by the higher handle

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X13-higher-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  405c405
  <     if (other.value <= self.value) continue;
  ---
  >     if (other.value >= self.value) continue;
  418,419c418,419
  <       message: '${p.name} and ${o.name} share a space',
  <       handles: [self, other],
  ---
  >       message: '${o.name} and ${p.name} share a space',
  >       handles: [other, self],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-X13-higher-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [
      Actual: [
       Which: at location [1] is Diagnostic:<[warning] room.degenerate: room 27 ("Study") has a label offset that is not finite: its labels sit at the pole> instead of Diagnostic:<[warning] room.shared: Den and Nook share a space>
    test/room_diagnostics_test.dart 119:9               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-holeSeed — a seed inside a hole counts as sharing

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X13-holeSeed-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  410d409
  <     if (holes.any((h) => pointInRing(q, h))) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-X13-holeSeed-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: empty
      Actual: [Diagnostic:[warning] room.shared: Hall and Courtyard share a space]
    test/room_diagnostics_test.dart 174:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-brokenWarn1 — room.broken a warning (the SeedInWall arm)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X13-brokenWarn1-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  342c342
  <           severity: DiagnosticSeverity.error,
  ---
  >           severity: DiagnosticSeverity.warning,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-X13-brokenWarn1-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.broken: room 2B ("Wall room") has its seed in 22, a wall or a separator: it has no face> instead of Diagnostic:<[error] room.broken: room 2B ("Wall room") has its seed in 22, a wall  [cut; the full line is in the log]
    test/room_diagnostics_test.dart 200:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X13-brokenWarn2 — room.broken a warning (the Unbounded arm)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-X13-brokenWarn2-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  350c350
  <           severity: DiagnosticSeverity.error,
  ---
  >           severity: DiagnosticSeverity.warning,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-X13-brokenWarn2-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [1] is Diagnostic:<[warning] room.broken: room 2C ("Outside") has no bounded face around its seed> instead of Diagnostic:<[error] room.broken: room 2C ("Outside") has no bounded face around its seed>
    test/room_diagnostics_test.dart 200:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-poleNoHoles — the pole ignores the holes (Task 12 review m-3, carried to Task 13: RG2)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-poleNoHoles-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  285c285
  <     final pole = poleOfInaccessibility(trace.ring, trace.holes).point;
  ---
  >     final pole = poleOfInaccessibility(trace.ring, const []).point;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-rv12-poleNoHoles-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: a value less than <0.000001>
      Actual: <1454.9153718883426>
       Which: is not a value less than <0.000001>
    test/room_dissolve_test.dart 204:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv12-noLocalGuard — the local-frame triangulation guard and its seam dropped (Task 12 review m-4, carried to Task 13)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-noLocalGuard-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  185,187c185
  <       accepts: (step, points) =>
  <           !(debugTintFailedSteps?.contains(step) ?? false) &&
  <           _triangulates(local(points)));
  ---
  >       );
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-rv12-noLocalGuard-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <10>
    test/room_dissolve_test.dart 59:3                   expectTintRect
    test/room_dissolve_test.dart 229:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG3 ')` (exit 1; log `t19-rv12-noLocalGuard-run2.log`)

  ```
  00:00 +0 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 314:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv12-step3Region — step 3 stored as a region (Task 12 review m-4, carried to Task 13)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv12-step3Region-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  299c299
  <       if (tint.step == 3)
  ---
  >       if (false)
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-rv12-step3Region-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.fill> instead of EntityKind:<EntityKind.text>
    test/room_dissolve_test.dart 258:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG3 ')` (exit 1; log `t19-rv12-step3Region-run2.log`)

  ```
  00:00 +0 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.fill> instead of EntityKind:<EntityKind.text>
    test/room_diagnostics_test.dart 331:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### r1-otherLocal — another room's seed not mapped through its own group (Task 13 fix round)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-r1-otherLocal-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  407c407
  <     final q = view.toWorld(other).transformPoint(o.seed) - seedW;
  ---
  >     final q = o.seed - seedW;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-r1-otherLocal-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [Diagnostic:[warning] room.shared: Den and Bay share a space]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 151:9               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### r1-noBrokenSkip — room.shared counts a broken room (Task 13 review m-1)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-r1-noBrokenSkip-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  414d413
  <     if (_traceOf(view, other) is! Traced) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-r1-noBrokenSkip-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.shared: Room 1 and Edge share a space> instead of Diagnostic:<[error] room.broken: room 2B ("Edge") has its seed in 22, a wall or a separator: it has no face>
    test/room_diagnostics_test.dart 274:9               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### r1-otherSelfT — another room's seed mapped through self's group

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-r1-otherSelfT-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  407c407
  <     final q = view.toWorld(other).transformPoint(o.seed) - seedW;
  ---
  >     final q = view.toWorld(self).transformPoint(o.seed) - seedW;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-r1-otherSelfT-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [Diagnostic:[warning] room.shared: Den and Bay share a space]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 151:9               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-otherLocal — another room's local seed less self's world seed (Task 13 review I-1)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-otherLocal-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  407c407
  <     final q = view.toWorld(other).transformPoint(o.seed) - seedW;
  ---
  >     final q = o.seed - seedW;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 1; log `t19-rv13-otherLocal-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [Diagnostic:[warning] room.shared: Den and Bay share a space]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 151:9               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-diagFresh — diagnose traces afresh

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-diagFresh-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382,383c382,384
  <   final (:tint, local: _) = _storedTint(
  <       trace, p.seed, toWorld.transformPoint(p.seed), toWorld.invert());
  ---
  >   final seedW = toWorld.transformPoint(p.seed);
  >   final tint = tintOf([for (final q in trace.ring) q - seedW],
  >       [for (final h in trace.holes) [for (final q in h) q - seedW]]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 1; log `t19-rv13-diagFresh-run1.log`)

  ```
  00:00 +2 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 314:7               main.<fn>
  00:00 +3 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-ringOnlyHoles — room.shared ignores holes

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-ringOnlyHoles-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  409d408
  <     if (!pointInRing(q, ring)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 1; log `t19-rv13-ringOnlyHoles-run1.log`)

  ```
  00:00 +1 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.shared: Store and Wall room share a space> instead of Diagnostic:<[error] room.broken: room 2C ("Outside") has no bounded face around its seed>
    test/room_diagnostics_test.dart 241:7               main.<fn>
  00:00 +3 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-degDxOnly — room.degenerate on dx only

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-degDxOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  365c365
  <       if (p.label case (final dx, final dy) when !dx.isFinite || !dy.isFinite)
  ---
  >       if (p.label case (final dx, final _) when !dx.isFinite)
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG1 ')` (exit 0; log `t19-rv13-degDxOnly-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-rv13-degDxOnly-run2.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 2 commands red). Its Task 13 review killer is `RL3`: re-fired there (`rv13-degDxOnly (at RL3, ...)`), red. Final: killed.

#### rv13-brokenNoSource — room.broken names no source

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-brokenNoSource-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  346c346
  <           handles: [self, source],
  ---
  >           handles: [self],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-rv13-brokenNoSource-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[error] room.broken: room 2B ("Wall room") has its seed in 22, a wall or a separator: it has no face> instead of Diagnostic:<[error] room.broken: room 2B ("Wall room") has its seed in 22, a wall or [cut; the full line is in the log]
    test/room_diagnostics_test.dart 200:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-unboundedOnly — room.broken for Unbounded only

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-unboundedOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  243c243
  <       _traceOf(view, self) is! Traced;
  ---
  >       _traceOf(view, self) is Unbounded;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-rv13-unboundedOnly-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [43, 44]
      Actual: [44]
       Which: at location [0] is <44> instead of <43>
    test/room_diagnostics_test.dart 220:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-seedInWallOnly — room.broken for SeedInWall only

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-seedInWallOnly-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  243c243
  <       _traceOf(view, self) is! Traced;
  ---
  >       _traceOf(view, self) is SeedInWall;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG2 ')` (exit 1; log `t19-rv13-seedInWallOnly-run1.log`)

  ```
  00:00 +0 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [43, 44]
      Actual: [43]
       Which: at location [1] is [43] which shorter than expected
    test/room_diagnostics_test.dart 220:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10dissolve@room — `RoomType.dissolves` always false (spec; app site; killers RD1-RD3; DF1 also)

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10dissolve_room-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  242,243c242
  <   bool dissolves(ParametricView view, Handle self) =>
  <       _traceOf(view, self) is! Traced;
  ---
  >   bool dissolves(ParametricView view, Handle self) => false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD1 ')` (exit 1; log `t19-M-10dissolve_room-run1.log`)

  ```
  00:00 +0 -1: RD1 a wall moved onto a room's seed dissolves it in the same undo step [E]
    Expected: null
      Actual: RoomParams:<RoomParams((1512.5, 1987.25), Room 1, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 533:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD2 ')` (exit 1; log `t19-M-10dissolve_room-run2.log`)

  ```
  00:00 +0 -1: RD2 a face opened to the outside dissolves its room [E]
    Expected: null
      Actual: RoomParams:<RoomParams((1512.5, 1987.25), Room 1, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 567:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD3 ')` (exit 1; log `t19-M-10dissolve_room-run3.log`)

  ```
  00:00 +0 -1: RD3 deleting E4 dissolves the Hall and Bedroom 1 in one step [E]
    Expected: null
      Actual: RoomParams:<RoomParams((14500.0, 10500.0), Hall, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 602:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'DF1 ')` (exit 1; log `t19-M-10dissolve_room-run4.log`)

  ```
  00:00 +0 -1: DF1 twenty scripted edits on the sample plan: a regeneration from scratch agrees with the incremental one [E]
    Expected: {'Bath': 11}
      Actual: {}
       Which: has different length and is missing map key 'Bath'
    test/room_follow_test.dart 693:5                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### rv13-noFiniteSkip — room.shared without the finite check (equivalent, Task 13 review)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-noFiniteSkip-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  408d407
  <     if (!q.x.isFinite || !q.y.isFinite) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-rv13-noFiniteSkip-run1.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-rv13-noFiniteSkip-run2.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### rv13-exactStep — room.tint by step only (equivalent, Task 13 review)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-exactStep-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  384c384
  <   if (tint.isExact) return null;
  ---
  >   if (tint.step == 1) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-rv13-exactStep-run1.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 1; log `t19-rv13-exactStep-run2.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_dissolve_test.dart 403:9                  main.<fn>
  00:00 +8 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-RED (1 of 2 commands red). Ruled equivalent at Task 13's review; red at `RG2` now (Task 14c made a hole left out of a step-1 tint observable). Final: killed.

#### rv13-sharedNoSelfSeedW — room.shared in world, not self-relative (equivalent, Task 13 review)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-sharedNoSelfSeedW-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  399c399
  <   final seedW = view.toWorld(self).transformPoint(p.seed);
  ---
  >   final seedW = p.seed;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-rv13-sharedNoSelfSeedW-run1.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-rv13-sharedNoSelfSeedW-run2.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### rv13-tintReportLocalSeed — room.tint mapped through the local seed (equivalent, Task 13 review)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-tintReportLocalSeed-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  383c383
  <       trace, p.seed, toWorld.transformPoint(p.seed), toWorld.invert());
  ---
  >       trace, p.seed, p.seed, toWorld.invert());
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-rv13-tintReportLocalSeed-run1.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-rv13-tintReportLocalSeed-run2.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### t13-noLocalTri (= rv13-own-noLocalTri) — the local triangulation check without the seam (equivalent by unreachability, ruled at Task 13)

The Task 13 review's `rv13-*.edits`, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t13-noLocalTri____rv13-own-noLocalTri_-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  186,187c186
  <           !(debugTintFailedSteps?.contains(step) ?? false) &&
  <           _triangulates(local(points)));
  ---
  >           !(debugTintFailedSteps?.contains(step) ?? false));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-t13-noLocalTri____rv13-own-noLocalTri_-run1.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 0; log `t19-t13-noLocalTri____rv13-own-noLocalTri_-run2.log`)

  ```
  00:00 +4: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-t13-noLocalTri____rv13-own-noLocalTri_-run3.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 3 commands red).

#### t13-diagOwnTint — diagnose computes its own tint

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t13-diagOwnTint-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  382,383c382,385
  <   final (:tint, local: _) = _storedTint(
  <       trace, p.seed, toWorld.transformPoint(p.seed), toWorld.invert());
  ---
  >   final seedW = toWorld.transformPoint(p.seed);
  >   final tint = tintOf([for (final q in trace.ring) q - seedW], [
  >     for (final h in trace.holes) [for (final q in h) q - seedW]
  >   ]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG3 ')` (exit 1; log `t19-t13-diagOwnTint-run1.log`)

  ```
  00:00 +0 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 314:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t13-seamIgnored — the seam ignored

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t13-seamIgnored-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  856c856
  <       _triangulates(r) && (accepts == null || accepts(step, r));
  ---
  >       _triangulates(r);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-t13-seamIgnored-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <10>
    test/room_dissolve_test.dart 59:3                   expectTintRect
    test/room_dissolve_test.dart 229:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG3 ')` (exit 1; log `t19-t13-seamIgnored-run2.log`)

  ```
  00:00 +0 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 314:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### t13-degenerateAnd — room.degenerate only when both components are non-finite

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t13-degenerateAnd-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  365c365
  <       if (p.label case (final dx, final dy) when !dx.isFinite || !dy.isFinite)
  ---
  >       if (p.label case (final dx, final dy) when !dx.isFinite && !dy.isFinite)
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 1; log `t19-t13-degenerateAnd-run1.log`)

  ```
  00:00 +0 -1: DG1 room.shared is reported once per pair, by the lower handle; three rooms in one face give three entries [E]
    Expected: [
      Actual: [
       Which: at location [3] is [
    test/room_diagnostics_test.dart 119:9               main.<fn>
  00:00 +2 -2: DG4 separator.degenerate for a short or non-finite separator, room.degenerate for a non-finite label [E]
    Expected: [
      Actual: [Diagnostic:[warning] room.shared: Room 2 and Store share a space]
       Which: at location [1] is [Diagnostic:[warning] room.shared: Room 2 and Store share a space] which shorter than expected
    test/room_diagnostics_test.dart 389:5               main.<fn>
  00:00 +2 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t13-sepDiagNone — separator.degenerate never reported

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator.dart`; backup `t19-t13-sepDiagNone-separator.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  110c110
  <         if (roomInputInView(view, self) == null)
  ---
  >         if (false)
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG4 ')` (exit 1; log `t19-t13-sepDiagNone-run1.log`)

  ```
  00:00 +0 -1: DG4 separator.degenerate for a short or non-finite separator, room.degenerate for a non-finite label [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_diagnostics_test.dart 384:5               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t13-noStep2 — step 2 never taken

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t13-noStep2-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  858d857
  <   if (takes(2, ring)) return Tint(2, ring, leftOut);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-t13-noStep2-run1.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.text> instead of EntityKind:<EntityKind.fill>
    test/room_dissolve_test.dart 218:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 1; log `t19-t13-noStep2-run2.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <2>
      Actual: <3>
    test/room_tint_test.dart 471:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### t13-noRingTest — room.shared without the ring test

Task 13's fragment (`t13-*.old/.new`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t13-noRingTest-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  409d408
  <     if (!pointInRing(q, ring)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart)` (exit 1; log `t19-t13-noRingTest-run1.log`)

  ```
  00:00 +1 -1: DG2 a loaded room whose seed is in a wall is room.broken, and drift() names it; an unrelated edit is not refused [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.shared: Store and Wall room share a space> instead of Diagnostic:<[error] room.broken: room 2C ("Outside") has no bounded face around its seed>
    test/room_diagnostics_test.dart 241:7               main.<fn>
  00:00 +3 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 1; log `t19-t13-noRingTest-run2.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: empty
      Actual: [
    test/room_dissolve_test.dart 211:7                  main.<fn>
  00:00 +3 -2: RD4 deleting the column keeps Living, closes its hole, and reports nothing [E]
    Expected: empty
      Actual: [
    test/room_dissolve_test.dart 641:7                  main.<fn>
  00:00 +4 -3: RD6 the Living | Dining separator pulled 50 mm short leaves both rooms in one face [E]
    Expected: [Diagnostic:[warning] room.shared: Living and Dining share a space]
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.shared: Hall and Bedroom 1 share a space> instead of Diagnostic:<[warning] room.shared: Living and Dining share a space>
    test/room_dissolve_test.dart 696:7                  main.<fn>
  00:00 +6 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X14-noShortCircuit (three sites) — the three short circuits removed together (RK1)

Task 14's `t14-mutants.json` entry.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X14-noShortCircuit__three_sites_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  319c319
  <   if (seeds.isEmpty || after.readers == 0) return const [];
  ---
  >   if (after.readers == 0) return const [];
  341d340
  <   if (boxes.isEmpty) return const [];
  869d867
  <     if (seeds.isEmpty && cleanup.isEmpty) return r;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'RK1 ')` (exit 1; log `t19-X14-noShortCircuit__three_sites_-run1.log`)

  ```
  00:00 +0 -1: RK1 a line drawn among the sample plan's rooms makes no place-box or read-box call [E]
    Expected: <0>
      Actual: <14>
    test/room_cost_test.dart 210:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X14-sc-runReturn — `_run`'s early return removed alone (accepted (cost): the other two guards back it up, Task 14 finding)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X14-sc-runReturn-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  869d868
  <     if (seeds.isEmpty && cleanup.isEmpty) return r;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'RK1 ')` (exit 0; log `t19-X14-sc-runReturn-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red). Final: accepted (cost): Task 14's finding, fix round 1's ruling m-2.

#### X14-sc-seedGuard — `_triggered`'s seed guard removed alone (accepted (cost), Task 14 finding)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X14-sc-seedGuard-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  319c319
  <   if (seeds.isEmpty || after.readers == 0) return const [];
  ---
  >   if (after.readers == 0) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'RK1 ')` (exit 0; log `t19-X14-sc-seedGuard-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red). Final: accepted (cost): Task 14's finding, fix round 1's ruling m-2.

#### X14-sc-boxGuard — `_triggered`'s empty-L return removed alone (called equivalent at Task 14; = X6-readAlways, killed at SD6)

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-X14-sc-boxGuard-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  341d340
  <   if (boxes.isEmpty) return const [];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'RK1 ')` (exit 0; log `t19-X14-sc-boxGuard-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red). Not equivalent: the edit is `X6-readAlways`'s; re-fired at `SD6`, red (`r1-X14-sc-boxGuard`). Final: killed.

#### rv14-noStep3 — step 3 reported as step 2 (Task 14 review: FZ1's sole killer)

The Task 14 review's `rv14-m-nostep3.py`.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14-noStep3-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  859c859
  <   return Tint(3, ring, leftOut);
  ---
  >   return Tint(2, ring, leftOut);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-rv14-noStep3-run1.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). Task 14b removed every step-3 outline `FZ1` reached; re-fired at `TN1`, `RG2`, `DG3`, all red. Final: killed.

#### t14f-unit — the area label in metres whatever the page

Task 14 fix round's `t14f-mutants.json`.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t14f-unit-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  312c312
  <           formatArea(trace.area, page.displayUnit),
  ---
  >           formatArea(trace.area, DisplayUnit.meters),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'DF1 ')` (exit 1; log `t19-t14f-unit-run1.log`)

  ```
  00:00 +0 -1: DF1 twenty scripted edits on the sample plan: a regeneration from scratch agrees with the incremental one [E]
    Expected: ['Hall', '339.22 ft²']
      Actual: ['Hall', '31.51 m²']
       Which: at location [1] is '31.51 m²' instead of '339.22 ft²'
    test/room_follow_test.dart 755:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RA2 ')` (exit 1; log `t19-t14f-unit-run2.log`)

  ```
  00:00 +0 -1: RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates the labels in one undo step [E]
    Expected: ['Room 1', '116.57 ft²']
      Actual: ['Room 1', '10.83 m²']
       Which: at location [1] is '10.83 m²' instead of '116.57 ft²'
    test/room_object_test.dart 559:9                    main.<fn>.expectLabels
    test/room_object_test.dart 579:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### t14f-outerArea — the area label from the outer area, holes not subtracted

Task 14 fix round's `t14f-mutants.json`.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t14f-outerArea-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  312c312
  <           formatArea(trace.area, page.displayUnit),
  ---
  >           formatArea(trace.outerArea, page.displayUnit),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'DF1 ')` (exit 1; log `t19-t14f-outerArea-run1.log`)

  ```
  00:00 +0 -1: DF1 twenty scripted edits on the sample plan: a regeneration from scratch agrees with the incremental one [E]
    Expected: ['Kitchen', '223.62 ft²']
      Actual: ['Kitchen', '224.59 ft²']
       Which: at location [1] is '224.59 ft²' instead of '223.62 ft²'
    test/room_follow_test.dart 755:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 1; log `t19-t14f-outerArea-run2.log`)

  ```
  00:00 +0 -1: FZ1 a seeded random run: no edit is refused because of rooms, drift() stays empty, every tint triangulates and is step 1 [E]
    Expected: ['Living', '44.94 m²']
      Actual: ['Living', '45.10 m²']
       Which: at location [1] is '45.10 m²' instead of '44.94 m²'
    test/room_follow_test.dart 936:11                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'RS2 ')` (exit 1; log `t19-t14f-outerArea-run3.log`)

  ```
  00:00 +0 -1: RS2 a freestanding wall drawn inside after the click is a hole [E]
    Expected: ['Room 2', '18.33 m²']
      Actual: ['Room 2', '18.43 m²']
       Which: at location [1] is '18.43 m²' instead of '18.33 m²'
    test/room_follow_test.dart 335:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### X14b-noSplit — only adjacent doubled pairs (spikes) split (plan-owned, Task 14b, decision 29)

Task 14b's `t14b-mutate.py` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14b-noSplit-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1041a1042
  >       if (j != i + 1 && !(i == 0 && j == hs.length - 1)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-X14b-noSplit-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <160000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 192:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-X14b-noSplit-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.polyline> instead of EntityKind:<EntityKind.fill>
    test/room_tie_test.dart 379:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-X14b-noSplit-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: [39, 40, 41, 42]
      Actual: [41, 42, 44]
       Which: at location [0] is <41> instead of <39>
    test/room_tie_test.dart 505:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### X14b-oneHalf — one half of a doubled pair kept (plan-owned, Task 14b, decision 29)

Task 14b's `t14b-mutate.py` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14b-oneHalf-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1043c1043
  <         ..add([...hs.sublist(0, i), ...hs.sublist(j + 1)])
  ---
  >         ..add([...hs.sublist(0, i), ...hs.sublist(j)])
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-X14b-oneHalf-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <4335425.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 190:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-X14b-oneHalf-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '25.14 m²']
       Which: at location [1] is '25.14 m²' instead of '29.48 m²'
    test/room_tie_test.dart 388:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-X14b-oneHalf-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '25.14 m²']
       Which: at location [1] is '25.14 m²' instead of '29.48 m²'
    test/room_tie_test.dart 507:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### X14b-dropInner — the loop between a doubled pair dropped (plan-owned, Task 14b, decision 29)

Task 14b's `t14b-mutate.py` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14b-dropInner-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1043,1044c1043
  <         ..add([...hs.sublist(0, i), ...hs.sublist(j + 1)])
  <         ..add(hs.sublist(i + 1, j));
  ---
  >         ..add([...hs.sublist(0, i), ...hs.sublist(j + 1)]);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-X14b-dropInner-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <160000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 190:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-X14b-dropInner-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '29.64 m²']
       Which: at location [1] is '29.64 m²' instead of '29.48 m²'
    test/room_tie_test.dart 388:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-X14b-dropInner-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '29.64 m²']
       Which: at location [1] is '29.64 m²' instead of '29.48 m²'
    test/room_tie_test.dart 507:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### X14b-noSources — a reversed hole's sources not moved with its edges (plan-owned, Task 14b, decision 29)

Task 14b's `t14b-mutate.py` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14b-noSources-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  287c287
  <       src: [for (var i = n - 1; i >= 0; i--) r.src[(i - 1 + n) % n]],
  ---
  >       src: [for (var i = n - 1; i >= 0; i--) r.src[i]],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-X14b-noSources-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: [34]
      Actual: [38]
       Which: at location [0] is <38> instead of <34>
    test/room_tie_test.dart 105:5                       expectSources
    test/room_tie_test.dart 329:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 0; log `t19-X14b-noSources-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 0; log `t19-X14b-noSources-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 3 commands red).

#### X14b-coincident — pairs by coincident input sets, not twins (the nearest analogue of the brief's mutant, accepted at Task 14b) (plan-owned, Task 14b, decision 29)

Task 14b's `t14b-mutate.py` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14b-coincident-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  268c268,269
  <   final outerLoops = _splitDoubled(cycles[outer]);
  ---
  >   String key(int h) => _ascending(edges[from[h] < to[h] ? (from[h], to[h]) : (to[h], from[h])]!).map((e) => e.value).join(',');
  >   final outerLoops = _splitDoubled(cycles[outer], key);
  278c279
  <     for (final c in holeCycles) ..._splitDoubled(cycles[c]),
  ---
  >     for (final c in holeCycles) ..._splitDoubled(cycles[c], key),
  1032c1033
  < List<List<int>> _splitDoubled(List<int> cycle) {
  ---
  > List<List<int>> _splitDoubled(List<int> cycle, String Function(int) key) {
  1037c1038
  <     final at = {for (var k = 0; k < hs.length; k++) hs[k]: k};
  ---
  >     final at = {for (var k = 0; k < hs.length; k++) key(hs[k]): k};
  1040,1041c1041,1042
  <       final j = at[hs[i] ^ 1];
  <       if (j == null || j < i) continue;
  ---
  >       final j = at[key(hs[i])];
  >       if (j == null || j <= i) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-X14b-coincident-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <14660000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 190:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-X14b-coincident-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '14.82 m²']
       Which: at location [1] is '14.82 m²' instead of '29.48 m²'
    test/room_tie_test.dart 388:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-X14b-coincident-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: ['Room 1', '29.48 m²']
      Actual: ['Room 1', '29.64 m²']
       Which: at location [1] is '29.64 m²' instead of '29.48 m²'
    test/room_tie_test.dart 489:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### rv14b-ringFirst — the outer ring taken as the first loop, not the largest

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-ringFirst-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270,272d269
  <   for (final l in outerLoops) {
  <     if (areaOf(l) > areaOf(ringLoop)) ringLoop = l;
  <   }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-rv14b-ringFirst-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <29640000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 190:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-rv14b-ringFirst-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: [
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_tie_test.dart 379:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-rv14b-ringFirst-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: [39, 40, 41, 42]
      Actual: []
       Which: at location [0] is [] which shorter than expected
    test/room_tie_test.dart 505:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv14b-ringFirst-run4.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (3 of 4 commands red).

#### rv14b-holesPositive — loops of either sign kept as holes (equivalent, Task 14b review)

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-holesPositive-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  280c280
  <     if (!(areaOf(loop) < 0)) continue;
  ---
  >     if (!(areaOf(loop) != 0)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 0; log `t19-rv14b-holesPositive-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 0; log `t19-rv14b-holesPositive-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 0; log `t19-rv14b-holesPositive-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv14b-holesPositive-run4.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 4 commands red).

#### rv14b-noOuterSplit — the outer cycle not split

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-noOuterSplit-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  268c268
  <   final outerLoops = _splitDoubled(cycles[outer]);
  ---
  >   final outerLoops = [cycles[outer]];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-rv14b-noOuterSplit-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: a value less than or equal to <0.01>
      Actual: <160000.0>
       Which: is not a value less than or equal to <0.01>
    test/room_tie_test.dart 192:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 1; log `t19-rv14b-noOuterSplit-run2.log`)

  ```
  00:00 +0 -1: DE2 a room with a tied island keeps its fill: step 1, its area, no room.tint, its label clear of the island, at six placements [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.polyline> instead of EntityKind:<EntityKind.fill>
    test/room_tie_test.dart 379:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 1; log `t19-rv14b-noOuterSplit-run3.log`)

  ```
  00:00 +0 -1: DE3 the Separator tool's transient: wall → column keeps the fill, column → wall splits the room; same handles; undone step by step [E]
    Expected: [39, 40, 41, 42]
      Actual: [41, 42, 44]
       Which: at location [0] is <41> instead of <39>
    test/room_tie_test.dart 505:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-rv14b-noOuterSplit-run4.log`)

  ```
  00:00 +6 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: an object with length of <4>
      Actual: [
       Which: has length of <7>
    test/room_trace_test.dart 76:3                      expectRing
    test/room_trace_test.dart 590:9                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### rv14b-noHoleSplit — hole contours not split

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-noHoleSplit-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  278c278
  <     for (final c in holeCycles) ..._splitDoubled(cycles[c]),
  ---
  >     for (final c in holeCycles) cycles[c],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-rv14b-noHoleSplit-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: an object with length of <2>
      Actual: [
       Which: has length of <1>
    test/room_tie_test.dart 291:9                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 0; log `t19-rv14b-noHoleSplit-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 0; log `t19-rv14b-noHoleSplit-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 1; log `t19-rv14b-noHoleSplit-run4.log`)

  ```
  00:00 +6 -1: RT8 a separator splits a face drawn face to face and centreline to centreline; 50 mm short it merges them [E]
    Expected: empty
      Actual: [
    test/room_trace_test.dart 618:7                     main.<fn>
  00:00 +7 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (2 of 4 commands red).

#### rv14b-holeSortFirst — holes sorted before cleaning (equivalent, Task 14b review)

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-holeSortFirst-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  290c290
  <   holes.sort(_byPoints);
  ---
  >   holes.sort((a, b) => _lex(a.pts.first, b.pts.first));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 0; log `t19-rv14b-holeSortFirst-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 0; log `t19-rv14b-holeSortFirst-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 0; log `t19-rv14b-holeSortFirst-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv14b-holeSortFirst-run4.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 4 commands red).

#### rv14b-splitOnce — one doubled pair split per walk

The Task 14b review's `rv14b-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14b-splitOnce-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1047c1047
  <     if (whole && hs.isNotEmpty) loops.add(hs);
  ---
  >     if (hs.isNotEmpty && (whole || loops.length > 1000)) loops.add(hs);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 0; log `t19-rv14b-splitOnce-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE2 ')` (exit 0; log `t19-rv14b-splitOnce-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE3 ')` (exit 0; log `t19-rv14b-splitOnce-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-rv14b-splitOnce-run4.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 4 commands red). Not equivalent (fix round 1, the audit's I-1): re-fired at `DE1`'s new star, red (`r1-rv14b-splitOnce`). Final: killed.

#### X14c-noSlitCheck — the slit's clear check dropped (plan-owned, Task 14c)

Task 14c's `t14c-mutate.py` / the review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14c-noSlitCheck-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  835c835
  <       if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], later)) {
  ---
  >       if (false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-X14c-noSlitCheck-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <1>
      Actual: <2>
    test/room_tint_test.dart 399:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-X14c-noSlitCheck-run2.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: true
      Actual: <false>
    test/room_dissolve_test.dart 396:9                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X14c-noSectorH — H's slit end not placed in its sector (plan-owned, Task 14c)

Task 14c's `t14c-mutate.py` / the review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14c-noSectorH-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  836c836
  <         final hs = _slitEnd(h, v - h, hole[(hi + n - 1) % n] - h, slit);
  ---
  >         final hs = h + slit;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-X14c-noSectorH-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: Vector2:<[-4900.5,-1900.25]>
      Actual: Vector2:<[2899.5,-1900.25]>
    test/room_tint_test.dart 403:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-X14c-noSectorH-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### X14c-noSectorV — V's slit end not placed in its sector (plan-owned, Task 14c)

Task 14c's `t14c-mutate.py` / the review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14c-noSectorV-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  837,838c837
  <         final vs =
  <             _slitEnd(v, keyholed[(i + 1) % keyholed.length] - v, h - v, slit);
  ---
  >         final vs = v + slit;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-X14c-noSectorV-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a value less than <1e-9>
      Actual: <0.6169719321455456>
       Which: is not a value less than <1e-9>
    test/room_tint_test.dart 412:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-X14c-noSectorV-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### X14c-noEndOnEnd — the end-on-end clause dropped (plan-owned, Task 14c)

Task 14c's `t14c-mutate.py` / the review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-X14c-noEndOnEnd-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  934,937d933
  <       (a - c).length <= tol ||
  <       (a - d).length <= tol ||
  <       (b - c).length <= tol ||
  <       (b - d).length <= tol ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-X14c-noEndOnEnd-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <1>
      Actual: <2>
    test/room_tint_test.dart 650:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-X14c-noEndOnEnd-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### rv14c-noTouch — the touching clauses dropped (re-targeted in round 2) (plan-owned, Task 14c)

Task 14c's `t14c-mutate.py` / the review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-noTouch-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  937,940c937
  <       (b - d).length <= tol ||
  <       inside(c, a, b) ||
  <       inside(a, c, d) ||
  <       inside(b, c, d);
  ---
  >       (b - d).length <= tol;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14c-noTouch-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: not Vector2:<[-5000.0,-5000.0]>
      Actual: Vector2:<[-5000.0,-5000.0]>
    test/room_tint_test.dart 714:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-rv14c-noTouch-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### rv14c-noLater — the slit checked against the ring only, not the holes not yet joined (Task 14c review m-1)

Task 14c's form at both `_clear` calls.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-noLater-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  835c835
  <       if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], later)) {
  ---
  >       if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], const [])) {
  841c841
  <         if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], later)) continue;
  ---
  >         if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], const [])) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14c-noLater-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: not Vector2:<[-5000.0,-5000.0]>
      Actual: Vector2:<[-5000.0,-5000.0]>
    test/room_tint_test.dart 714:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv14c-endOnEndAOnly — end-on-end for a only (equivalent, Task 14c re-review)

The review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-endOnEndAOnly-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  936,937d935
  <       (b - c).length <= tol ||
  <       (b - d).length <= tol ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 0; log `t19-rv14c-endOnEndAOnly-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-rv14c-endOnEndAOnly-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### rv14c-endOnEndBOnly — end-on-end for b only (equivalent, Task 14c re-review)

The review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-endOnEndBOnly-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  934,935d933
  <       (a - c).length <= tol ||
  <       (a - d).length <= tol ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 0; log `t19-rv14c-endOnEndBOnly-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-rv14c-endOnEndBOnly-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### rv14c-endOnEndTight — the end-on-end clause at zero distance

The review's `rv14c-mutants.json` entry.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-endOnEndTight-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  934,937c934,937
  <       (a - c).length <= tol ||
  <       (a - d).length <= tol ||
  <       (b - c).length <= tol ||
  <       (b - d).length <= tol ||
  ---
  >       (a - c).length == 0 ||
  >       (a - d).length == 0 ||
  >       (b - c).length == 0 ||
  >       (b - d).length == 0 ||
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14c-endOnEndTight-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: a value greater than <0.000001>
      Actual: <1.9633621422111153e-12>
       Which: is not a value greater than <0.000001>
    test/room_tint_test.dart 127:7                      expectSimple
    test/room_tint_test.dart 660:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-rv14c-endOnEndTight-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### rv14c-noSecondClear — the sector slit not re-checked

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-noSecondClear-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  841d840
  <         if (!_clear(candidate, [i + n, i + n + 1, i + n + 2], later)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14c-noSecondClear-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <1>
      Actual: <2>
    test/room_tint_test.dart 446:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv14c-bisectAlways — the slit end always on the bisector

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-bisectAlways-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  909d908
  <   if (sweep > math.pi / 2 && sweep < 1.5 * math.pi) return o + perp;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14c-bisectAlways-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: not Vector2:<[-5000.0,-5000.0]>
      Actual: Vector2:<[-5000.0,-5000.0]>
    test/room_tint_test.dart 714:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv14c-noSkipSame — the same slit re-checked (accepted (cost), Task 14c re-review)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14c-noSkipSame-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  839d838
  <         if (hs == h + slit && vs == v + slit) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 0; log `t19-rv14c-noSkipSame-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 0; log `t19-rv14c-noSkipSame-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red). Final: accepted (cost), Task 14c re-review.


### Tasks 15-18 -- the app: tools, the Room section, grips, the sample plan

#### M-10name — Room N as the largest N plus one (spec; killer TT4)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10name-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  356,359c356
  <     var n = 1;
  <     while (used.contains(n)) {
  <       n++;
  <     }
  ---
  >     final n = used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT4 ')` (exit 1; log `t19-M-10name-run1.log`)

  ```
  00:00 +0 -1: TT4 a new room takes the lowest unused Room N [E]
    Expected: 'Room 2'
      Actual: 'Room 4'
       Which: is different.
              Expected: Room 2
                Actual: Room 4
    test/room_tool_test.dart 485:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10occupied — the Room tool places in an occupied face (spec; killer TT3)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10occupied-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  193c193
  <     if (verdict != _Verdict.room) return;
  ---
  >     if (verdict == _Verdict.none) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT3 ')` (exit 1; log `t19-M-10occupied-run1.log`)

  ```
  00:00 +0 -1: TT3 no room in a band, in an unbounded face or in an occupied face [E]
    Expected: <6>
      Actual: <7>
    test/room_tool_test.dart 444:9                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10seedsnap — the seed is the snapped point (spec; killer TT5)

Re-sited at HEAD (the click passes `contours: false` since Task 17): the verdict and the seed read the snapped point.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10seedsnap-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  191c191
  <     final verdict = _verdictAt(_raw, contours: false);
  ---
  >     final verdict = _verdictAt(point, contours: false);
  194c194
  <     final seed = _raw.clone();
  ---
  >     final seed = point.clone();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT5 ')` (exit 1; log `t19-M-10seedsnap-run1.log`)

  ```
  00:00 +0 -1: TT5 the seed is the raw point with object snap on beside a vertex [E]
    Bad state: No element
    test/room_tool_test.dart 512:29  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10notice — the Room tool sets no status notice (spec; killer TT7)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10notice-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  227c227
  <       _notice.value = verdict == _Verdict.occupied ? _occupied : null;
  ---
  >       _notice.value = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT7 ')` (exit 1; log `t19-M-10notice-run1.log`)

  ```
  Expected: 'Room — Already a room: Kitchen'
    Actual: 'Room'
     Which: is different. Both strings start the same, but the actual value is missing the following
  00:01 +0 -1: TT7 a click in an occupied face places nothing and the status line says so; hovering there shows it; it clears on leaving the face and on deactivation [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10hover — the hover never short-circuits (spec; killer TT6)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10hover-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  251c251
  <     if (u == null || !u.containsPoint(p)) return _Verdict.none;
  ---
  >     if (u == null) return _Verdict.none;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 0; log `t19-M-10hover-run1.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 1 commands red). Finding F1: survived `TT6`; the fixture was fixed (`ee610fd`) and the re-fire is red. Final: killed.

#### M-10hoverunion — the short-circuit tests the union of place boxes, not their bounding box (spec; killer TT6)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10hoverunion-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  251c251,253
  <     if (u == null || !u.containsPoint(p)) return _Verdict.none;
  ---
  >     if (u == null || inputs.placedIn(Aabb2.raw(p.x, p.y, p.x, p.y)).isEmpty) {
  >       return _Verdict.none;
  >     }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 1; log `t19-M-10hoverunion-run1.log`)

  ```
  00:00 +0 -1: TT6 steady hovers re-trace nothing; outside the bounding box of every place box nothing is traced; the Kitchen seed, outside every place box but inside that box, is traced and previewed; a band's verdict is reused; an Unbounded [cut; the full line is in the log]
    Expected: a value greater than <0>
      Actual: <0>
       Which: is not a value greater than <0>
    test/room_tool_test.dart 548:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10trim (trimSeparator: the tool and the grips) — no band trimming (spec; one site, trimSeparator, reached by the tool (ST2) and the grips (GR5))

The Task 17 review's fragment (`rv17-m/M-10trim`).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-M-10trim__trimSeparator__the_tool_and_the_grips_-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  406c406
  <   if (objectSnap) {
  ---
  >   if (false) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart --plain-name 'ST2 ')` (exit 1; log `t19-M-10trim__trimSeparator__the_tool_and_the_grips_-run1.log`)

  ```
  00:00 +0 -1: ST2 an end inside a band is trimmed to the face with object snap on, and kept as placed with it off [E]
    Expected: a value less than <1e-8>
      Actual: <99.75>
       Which: is not a value less than <1e-8>
    test/separator_tool_test.dart 260:13                main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR5 ')` (exit 1; log `t19-M-10trim__trimSeparator__the_tool_and_the_grips_-run2.log`)

  ```
  00:00 +0 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, origin [E]
    Expected: a value less than <0.000001>
      Actual: <60.210000000000036>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 532:13                    main.<fn>
  Expected: a value less than <0.000001>
    Actual: <60.210000000000036>
     Which: is not a value less than <0.000001>
  00:01 +0 -2: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, origin [E]
  00:01 +0 -3: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: a value less than <0.000001>
      Actual: <60.210000000304944>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 532:13                    main.<fn>
  Expected: a value less than <0.000001>
    Actual: <60.210000000454656>
  ... (3 more kept lines in the log)
  00:02 +0 -4: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X15-stale — the caches never dropped on a rebuild

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-X15-stale-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  243,247d242
  <       _face = null;
  <       _faceVerdict = _Verdict.none;
  <       _occupied = null;
  <       _facePreview = const [];
  <       _band = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 1; log `t19-X15-stale-run1.log`)

  ```
  00:00 +0 -1: TT6 steady hovers re-trace nothing; outside the bounding box of every place box nothing is traced; the Kitchen seed, outside every place box but inside that box, is traced and previewed; a band's verdict is reused; an Unbounded [cut; the full line is in the log]
    Expected: <3>
      Actual: <2>
    test/room_tool_test.dart 607:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X15-predict — the handle predicted at hover

The Task 15 review's `rv15-predict.py` edits, re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-X15-predict-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  109a110
  >   int _pred = 0;
  183a185
  >     _pred = inputs.document.handleSeed.current.value + 1;
  199c201,202
  <         final h = doc.handleSeed.next();
  ---
  >         final h = Handle(_pred);
  >         doc.handleSeed.raiseTo(h);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT1 ')` (exit 1; log `t19-X15-predict-run1.log`)

  ```
  00:00 +0 -1: TT1 M places one room with one click, one undo step, named Room 1, seeded at the raw point; the tool stays active and Esc returns to Select [E]
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X15-guardMS — M and S missing from the shell's letter guard (killed by SG1, Task 15 ruling, and RN3)

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/shortcut_guard.dart`; backup `t19-X15-guardMS-shortcut_guard.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  15,16d14
  <   LogicalKeyboardKey.keyM,
  <   LogicalKeyboardKey.keyS,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'SG1 ')` (exit 1; log `t19-X15-guardMS-run1.log`)

  ```
  Expected: 'Text'
    Actual: 'Room'
     Which: is different.
            Expected: Text
              Actual: Room
  00:01 +0 -1: SG1 M and S typed into a text entry switch no tool (the shell's guard, X15-guardMS) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN3 ')` (exit 1; log `t19-X15-guardMS-run2.log`)

  ```
  Expected: an object with length of <13>
    Actual: Set:[
     Which: has length of <15>
  00:01 +0 -1: RN3 every shell letter types into the Name field (X15-guardMS: M and S included) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/shortcut_guard.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### t15-bandUntrimmed — the separator preview untrimmed

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator_tool.dart`; backup `t19-t15-bandUntrimmed-separator_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  70,74c70,71
  <     final trimmed = trimSeparator(points.first, hoverPoint, inputs,
  <         objectSnap: _objectSnap(_context));
  <     if (trimmed == null) return;
  <     _bandStart.setFrom(trimmed.$1);
  <     _bandEnd.setFrom(trimmed.$2);
  ---
  >     _bandStart.setFrom(points.first);
  >     _bandEnd.setFrom(hoverPoint);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart)` (exit 1; log `t19-t15-bandUntrimmed-run1.log`)

  ```
  00:01 +2 -1: ST3 both ends in one band, or a trimmed length within the tolerance, places nothing [E]
    Expected: null
      Actual: (Vector2, Vector2):<([1500.25,-40.5], [6500.75,60.25])>
    test/separator_tool_test.dart 340:7                 main.<fn>
  00:01 +5 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-noCancelClear — cancel keeps the notice

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-noCancelClear-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  379d378
  <     if (!_disposed) _notice.value = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-noCancelClear-run1.log`)

  ```
  Expected: 'Select'
    Actual: 'Select — Already a room: Kitchen'
     Which: is different. Both strings start the same, but the actual value also has the following
  00:03 +6 -1: TT7 a click in an occupied face places nothing and the status line says so; hovering there shows it; it clears on leaving the face and on deactivation [E]
  00:10 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-highest — the occupant named by the highest handle

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-highest-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  282d281
  <         break;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-highest-run1.log`)

  ```
  00:01 +2 -1: TT3 no room in a band, in an unbounded face or in an occupied face [E]
    Expected: 'Already a room: Pantry'
      Actual: 'Already a room: Kitchen'
       Which: is different.
              Expected: ... y a room: Pantry
                Actual: ... y a room: Kitchen
    test/room_tool_test.dart 442:9                      main.<fn>
  00:10 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-noHoles — the cached face ignores holes

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-noHoles-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  340c340
  <     final holes = f.holes;
  ---
  >     final holes = const <List<Vector2>>[];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-noHoles-run1.log`)

  ```
  00:01 +1 -1: TT2 the hover preview is the ring the room gets, bit for bit (the tied island of decision 29 included) [E]
    Expected: <7>
      Actual: <6>
    test/room_tool_test.dart 381:7                      main.<fn>
  00:03 +6 -2: TT8 the outer-contour cache answers every hover as the trace does, at every placement; a change drops it [E]
    Expected: empty
      Actual: [
    test/room_tool_test.dart 776:15                     main.<fn>
  00:03 +8 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-noLength — trimSeparator returns a degenerate result

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t15-noLength-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  413d412
  <   if (!((e - s).length > roomTrace.linear)) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart)` (exit 1; log `t19-t15-noLength-run1.log`)

  ```
  00:01 +2 -1: ST3 both ends in one band, or a trimmed length within the tolerance, places nothing [E]
    Expected: empty
      Actual: [34]
    test/separator_tool_test.dart 341:7                 main.<fn>
  00:01 +5 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-localSeed — an occupant's seed read locally

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-localSeed-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  279c279
  <       final s = doc.tree.accumulatedTransform(h).transformPoint(r.seed);
  ---
  >       final s = r.seed;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-localSeed-run1.log`)

  ```
  00:01 +2 -1: TT3 no room in a band, in an unbounded face or in an occupied face [E]
    Expected: 'Already a room: Pantry'
      Actual: 'Already a room: Kitchen'
       Which: is different.
              Expected: ... y a room: Pantry
                Actual: ... y a room: Kitchen
    test/room_tool_test.dart 442:9                      main.<fn>
  00:09 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-oneBand — both ends in one band not refused

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t15-oneBand-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  409c409
  <     if (inA.any(inB.contains)) return null;
  ---
  >
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart)` (exit 1; log `t19-t15-oneBand-run1.log`)

  ```
  00:01 +2 -1: ST3 both ends in one band, or a trimmed length within the tolerance, places nothing [E]
    Expected: empty
      Actual: [34]
    test/separator_tool_test.dart 341:7                 main.<fn>
  00:01 +5 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-postInv — no invalidate after the Room tool's execute

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-postInv-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  219d218
  <     inputs.invalidate();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-postInv-run1.log`)

  ```
  Expected: empty
    Actual: [Instance of 'GeometryPayload']
  00:00 +0 -1: TT1 M places one room with one click, one undo step, named Room 1, seeded at the raw point; the tool stays active and Esc returns to Select [E]
  00:09 +7 -2: TT9 a click and the re-read after a document change build no outer contours: a click needs only the trace (Task 15's review) [E]
    Expected: 'Already a room: Room 1'
      Actual: <null>
       Which: not an <Instance of 'String'>
    test/room_tool_test.dart 851:7                      main.<fn>
  00:09 +8 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-noRefresh — the tool never re-reads after a document change

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-noRefresh-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  367c367
  <     if (_disposed || (_preview.isEmpty && _notice.value == null)) return;
  ---
  >     return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-noRefresh-run1.log`)

  ```
  Expected: 'Room'
    Actual: 'Room — Already a room: Room 1'
     Which: is different. Both strings start the same, but the actual value also has the following
  00:01 +0 -1: TT1 M places one room with one click, one undo step, named Room 1, seeded at the raw point; the tool stays active and Esc returns to Select [E]
  00:09 +7 -2: TT9 a click and the re-read after a document change build no outer contours: a click needs only the trace (Task 15's review) [E]
    Expected: null
      Actual: 'Already a room: Room 1'
    test/room_tool_test.dart 861:7                      main.<fn>
  00:09 +8 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-sepInv — no invalidate at the separator's second click

Task 15's fragment (`t15-m/`), re-applied at HEAD.

- **file:** `apps/floor_planner/lib/parametric/separator_tool.dart`; backup `t19-t15-sepInv-separator_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  85d84
  <     inputs.invalidate();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart)` (exit 1; log `t19-t15-sepInv-run1.log`)

  ```
  00:01 +1 -1: ST2 an end inside a band is trimmed to the face with object snap on, and kept as placed with it off [E]
    Expected: a value less than <0.000001>
      Actual: <130.5>
       Which: is not a value less than <0.000001>
    test/separator_tool_test.dart 302:7                 main.<fn>
  00:01 +5 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15-clickInv — no invalidate at the Room tool's click

Re-sited at HEAD like M-10seedsnap.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15-clickInv-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  190d189
  <     inputs.invalidate();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart)` (exit 1; log `t19-t15-clickInv-run1.log`)

  ```
  00:01 +2 -1: TT3 no room in a band, in an unbounded face or in an occupied face [E]
    Expected: <5>
      Actual: <6>
    test/room_tool_test.dart 461:7                      main.<fn>
  00:09 +9 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-contourStale — the contour cache kept across generations

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15f-contourStale-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  248d247
  <       _contours = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT8 ')` (exit 1; log `t19-t15f-contourStale-run1.log`)

  ```
  00:06 +0 -1: TT8 the outer-contour cache answers every hover as the trace does, at every placement; a change drops it [E]
    Expected: <2>
      Actual: <1>
    test/room_tool_test.dart 824:5                      main.<fn>
  00:06 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-parity — the contour test by parity over contours

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15f-parity-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  323a324
  >     var inside = false;
  331c332
  <       if (pointInRingXY(x, y, contours[i])) return true;
  ---
  >       if (pointInRingXY(x, y, contours[i])) inside = !inside;
  333c334
  <     return false;
  ---
  >     return inside;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT8 ')` (exit 1; log `t19-t15f-parity-run1.log`)

  ```
  00:00 +0 -1: TT8 the outer-contour cache answers every hover as the trace does, at every placement; a change drops it [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/room_tool_test.dart 769:15                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-mostPositive — the most positive cycle as a component's contour

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t15f-mostPositive-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  652c652
  <     if (best == null || areas[c] < areas[best]) contour[comp[c]] = c;
  ---
  >     if (best == null || areas[c] > areas[best]) contour[comp[c]] = c;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT8 ')` (exit 1; log `t19-t15f-mostPositive-run1.log`)

  ```
  00:00 +0 -1: TT8 the outer-contour cache answers every hover as the trace does, at every placement; a change drops it [E]
    Expected: an object with length of <1>
      Actual: []
       Which: has length of <0>
    test/room_tool_test.dart 769:15                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-singlePass — trimSeparator trims once

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t15f-singlePass-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  425,428c425
  <     final more = [
  <       for (final band in _bandsTouching(end, inputs))
  <         if (used.add(band)) band,
  <     ];
  ---
  >     final more = <RoomInput>[];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart --plain-name 'ST5 ')` (exit 1; log `t19-t15f-singlePass-run1.log`)

  ```
  00:00 +0 -1: ST5 an end trimmed through a mitre, or through two joints, lies on the face the walk entered by, with no wall behind it [E]
    Expected: a value less than <0.000001>
      Actual: <39.3208955223879>
       Which: is not a value less than <0.000001>
    test/separator_tool_test.dart 402:9                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-holdingOnly — re-trim only while the end is inside a band, not on its edge

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t15f-holdingOnly-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  426c426
  <       for (final band in _bandsTouching(end, inputs))
  ---
  >       for (final band in _bandsHolding(end, inputs))
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart --plain-name 'ST5 ')` (exit 1; log `t19-t15f-holdingOnly-run1.log`)

  ```
  00:00 +0 -1: ST5 an end trimmed through a mitre, or through two joints, lies on the face the walk entered by, with no wall behind it [E]
    Expected: a value less than <0.000001>
      Actual: <83.9565525932532>
       Which: is not a value less than <0.000001>
    test/separator_tool_test.dart 443:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-O1 (= rv15-O1) — the last crossing, not the first

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-t15f-O1____rv15-O1_-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  477c477
  <   var best = double.infinity;
  ---
  >   var best = double.negativeInfinity;
  488c488
  <       if (t >= 0 && t <= 1 && u >= 0 && u <= 1 && t < best) best = t;
  ---
  >       if (t >= 0 && t <= 1 && u >= 0 && u <= 1 && t > best) best = t;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart --plain-name 'ST6 ')` (exit 1; log `t19-t15f-O1____rv15-O1_-run1.log`)

  ```
  00:00 +0 -1: ST6 an end inside two crossing walls stops at the first of their faces the walk meets [E]
    Expected: a numeric value within <0.000001> of <-100>
      Actual: <-51.367307692307804>
       Which:  differs by <48.632692307692196>
    test/separator_tool_test.dart 478:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t15f-marker — the Room tool paints a snap marker

Task 15 fix round's fragment (`t15f-m/`).

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t15f-marker-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  169,170d168
  <   @override
  <   void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport) {}
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT5 ')` (exit 1; log `t19-t15f-marker-run1.log`)

  ```
  00:00 +0 -1: TT5 the seed is the raw point with object snap on beside a vertex [E]
    Expected: empty
      Actual: [Symbol:Symbol("drawRect")]
    test/room_tool_test.dart 510:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv15f-onePass — trimSeparator's re-trim loop runs once (Task 15 re-review Minor A, carried to Task 17: ST5 chamfer)

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-rv15f-onePass-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  424,431c424,429
  <   while (true) {
  <     final more = [
  <       for (final band in _bandsTouching(end, inputs))
  <         if (used.add(band)) band,
  <     ];
  <     if (more.isEmpty) return end;
  <     end = _entry(from, end, more);
  <   }
  ---
  >   final more = [
  >     for (final band in _bandsTouching(end, inputs))
  >       if (used.add(band)) band,
  >   ];
  >   if (more.isEmpty) return end;
  >   return _entry(from, end, more);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/separator_tool_test.dart --plain-name 'ST5 ')` (exit 1; log `t19-rv15f-onePass-run1.log`)

  ```
  00:00 +0 -1: ST5 an end trimmed through a mitre, or through two joints, lies on the face the walk entered by, with no wall behind it [E]
    Expected: a value less than <0.000001>
      Actual: <83.9565525932532>
       Which: is not a value less than <0.000001>
    test/separator_tool_test.dart 443:7                 main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv15f-worldFrame — the outer contours built in the world frame (equivalent, Task 15 re-review)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-rv15f-worldFrame-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  306,307c306
  <       _contourOrigin.setValues(
  <           u.minX + (u.maxX - u.minX) / 2, u.minY + (u.maxY - u.minY) / 2);
  ---
  >       _contourOrigin.setValues(0, 0);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT8 ')` (exit 0; log `t19-rv15f-worldFrame-run1.log`)

  ```
  00:06 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 0; log `t19-rv15f-worldFrame-run2.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### rv15f-dropTrees — outer contours of components with no area dropped (equivalent, Task 15 re-review)

Reconstructed at HEAD from its name and the ledger (the edit was passed on the command line and not kept).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv15f-dropTrees-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  656c656,657
  <     for (final c in contour.values) [for (final h in cycles[c]) verts[from[h]]],
  ---
  >     for (final c in contour.values)
  >       if (areas[c] < 0) [for (final h in cycles[c]) verts[from[h]]],
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT8 ')` (exit 0; log `t19-rv15f-dropTrees-run1.log`)

  ```
  00:07 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 0; log `t19-rv15f-dropTrees-run2.log`)

  ```
  00:01 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### M-10pin (the shared _commit site) — the Room section's target read at focus loss (spec; the shared `_commit`; RN4 and 07's/08's pins)

Task 16's `t16-pin` fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-M-10pin__the_shared__commit_site_-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  455c455
  <     final target = f.pinned;
  ---
  >     final target = _targetOf(f.kind);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN4 ')` (exit 1; log `t19-M-10pin__the_shared__commit_site_-run1.log`)

  ```
  Expected: 'Larder'
    Actual: 'Kitchen'
     Which: is different.
            Expected: Larder
              Actual: Kitchen
  00:01 +0 -1: RN4 the Name field's target is pinned at focus gain (M-10pin, X16-noBlur) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN5 ')` (exit 1; log `t19-M-10pin__the_shared__commit_site_-run2.log`)

  ```
  Expected: 'Room 2'
    Actual: 'Snug  room'
     Which: is different.
            Expected: Room 2
              Actual: Snug  room ...
  00:02 +0 -1: RN5 an empty name reverts; runtime is read-only; a refused edit reverts (X16-untrimmed) [E]
  00:02 +1 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/opening_panel_test.dart --plain-name 'OS2 ')` (exit 1; log `t19-M-10pin__the_shared__commit_site_-run3.log`)

  ```
  Expected: OpeningParams:<OpeningParams(door on 12 at 1730.0, 870.0, end, right)>
    Actual: OpeningParams:<OpeningParams(door on 12 at 1730.0, 900.0, end, right)>
  00:01 +0 -1: OS2 (M-08pin) the commit target is pinned at focus gain: select A, type in Width, select B without taking the focus, blur: A changes, B does not; the same for Position; a pinned opening that dies drops the text [E]
  00:01 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/selection_panel_test.dart --plain-name 'WS7 ')` (exit 1; log `t19-M-10pin__the_shared__commit_site_-run4.log`)

  ```
  Expected: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
    Actual: WallParams:<WallParams((589.5107255699113, 444.89701554295607) -> (-2120.8749622078612,
  00:01 +0 -1: WS7 (Wall) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p); a pinned wall that dies drops the text [E]
  Expected: [150, 70.0]
    Actual: [120.0, 70.0]
     Which: at location [0] is <120.0> instead of <150>
  00:02 +0 -2: WS7 (Box) the commit target is pinned at focus gain: a selection change while a field has focus does not redirect its commit (M-07p) [E]
  00:02 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (4 of 4 commands red).

#### M-10pin (Room-only variant) — the Name field's target read at focus loss, the numeric fields kept pinned

Task 16's `t16-pinroom` fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-M-10pin__Room-only_variant_-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  455c455
  <     final target = f.pinned;
  ---
  >     final target = f.isText ? _targetOf(f.kind) : f.pinned;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN4 ')` (exit 1; log `t19-M-10pin__Room-only_variant_-run1.log`)

  ```
  Expected: 'Larder'
    Actual: 'Kitchen'
     Which: is different.
            Expected: Larder
              Actual: Kitchen
  00:01 +0 -1: RN4 the Name field's target is pinned at focus gain (M-10pin, X16-noBlur) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X16-untrimmed — the name stored untrimmed

Task 16's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-X16-untrimmed-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  249c249
  <     if (f.isText) return t.isEmpty ? null : t;
  ---
  >     if (f.isText) return t.isEmpty ? null : f.text.text;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN2 ')` (exit 1; log `t19-X16-untrimmed-run1.log`)

  ```
  Expected: <1>
    Actual: <2>
  00:01 +0 -1: RN2 Enter commits the name in one undo step and hands focus back; Esc works after [E]
  00:01 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN5 ')` (exit 1; log `t19-X16-untrimmed-run2.log`)

  ```
  Expected: 'Snug  room'
    Actual: '  Snug  room \t'
     Which: is different.
            Expected: Snug  room ...
              Actual:   Snug  ro ...
  00:02 +0 -1: RN5 an empty name reverts; runtime is read-only; a refused edit reverts (X16-untrimmed) [E]
  00:03 +1 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X16-noBlur — no commit on focus loss

Task 16's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-X16-noBlur-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  431c431
  <     _commit(f);
  ---
  >     if (!f.isText) _commit(f);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN4 ')` (exit 1; log `t19-X16-noBlur-run1.log`)

  ```
  Expected: 'Larder'
    Actual: 'Kitchen'
     Which: is different.
            Expected: Larder
              Actual: Kitchen
  00:01 +0 -1: RN4 the Name field's target is pinned at focus gain (M-10pin, X16-noBlur) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X16-sameCommand — an unchanged name issues a command

Task 16's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-X16-sameCommand-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  368d367
  <       if (next == p) return;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN2 ')` (exit 1; log `t19-X16-sameCommand-run1.log`)

  ```
  Expected: <1>
    Actual: <2>
  00:01 +0 -1: RN2 Enter commits the name in one undo step and hands focus back; Esc works after [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X16-staleArea — the Area line not refreshed

Task 16's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-X16-staleArea-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  163d162
  <       _areaRoom = null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN6 ')` (exit 1; log `t19-X16-staleArea-run1.log`)

  ```
  Expected: '130.91 ft²'
    Actual: '12.16 m²'
     Which: is different.
            Expected: 130.91 ft²
              Actual: 12.16 m²
  00:01 +0 -1: RN6 the Area line shows the area label's string: after a page change to ft-in it reads the label's ft² string [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X16-geometry — the name field needs components only

Task 16's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-X16-geometry-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  239c239
  <           _Kind.name => const RoomType().editCapability,
  ---
  >           _Kind.name => Capability.components,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN5 ')` (exit 1; log `t19-X16-geometry-run1.log`)

  ```
  Expected: true
    Actual: <false>
  00:02 +0 -1: RN5 an empty name reverts; runtime is read-only; a refused edit reverts (X16-untrimmed) [E]
  00:02 +1 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X15-guardMS (the map variant) — M and S skipped in the text-entry shortcut map

Task 16's `t16-guard2` fragment.

- **file:** `apps/floor_planner/lib/shortcut_guard.dart`; backup `t19-X15-guardMS__the_map_variant_-shortcut_guard.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  47c47,48
  <             SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
  ---
  >             if (key != LogicalKeyboardKey.keyM && key != LogicalKeyboardKey.keyS)
  >               SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN3 ')` (exit 1; log `t19-X15-guardMS__the_map_variant_-run1.log`)

  ```
  Expected: false
    Actual: <true>
  00:01 +0 -1: RN3 every shell letter types into the Name field (X15-guardMS: M and S included) [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/shortcut_guard.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv16-noSort — the Area lookup unsorted (Task 16 review M1, carried to Task 17: RN6)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-rv16-noSort-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  502c502
  <     ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
  ---
  >     ];
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN6 ')` (exit 1; log `t19-rv16-noSort-run1.log`)

  ```
  Expected: '6.27 m²'
    Actual: 'Store'
     Which: is different.
            Expected: 6.27 m²
              Actual: Store
  00:01 +0 -1: RN6 the Area line shows the area label's string: after a page change to ft-in it reads the label's ft² string [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv16-loadNoValueRoom — the Name field reloads regardless of value (Task 16 review M2: RN2)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-rv16-loadNoValueRoom-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  523c523
  <       if (target == f.loadedTarget && value == f.loadedValue) continue;
  ---
  >       if (target == f.loadedTarget && (f.isText || value == f.loadedValue)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN2 ')` (exit 1; log `t19-rv16-loadNoValueRoom-run1.log`)

  ```
  Expected: 'Kitchen'
    Actual: 'Pantry'
     Which: is different.
            Expected: Kitchen
              Actual: Pantry
  00:01 +0 -1: RN2 Enter commits the name in one undo step and hands focus back; Esc works after [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv16-suffixMm — the Name field shows an mm suffix (Task 16 review M3: RN1)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-rv16-suffixMm-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  599c599
  <             labelText: label, suffixText: f.isText ? null : 'mm'),
  ---
  >             labelText: label, suffixText: 'mm'),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN1 ')` (exit 1; log `t19-rv16-suffixMm-run1.log`)

  ```
  Expected: null
    Actual: 'mm'
  00:01 +0 -1: RN1 the Room section shows for exactly one room: hidden for none, two rooms, a room and a wall, a wall, a separator [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv16-numKbd — the Name field's keyboard numeric (Task 16 review M3: RN1)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-rv16-numKbd-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  600,602c600
  <         keyboardType: f.isText
  <             ? TextInputType.text
  <             : const TextInputType.numberWithOptions(decimal: true),
  ---
  >         keyboardType: const TextInputType.numberWithOptions(decimal: true),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart --plain-name 'RN1 ')` (exit 1; log `t19-rv16-numKbd-run1.log`)

  ```
  Expected: TextInputType:<TextInputType(name: TextInputType.text, signed: null, decimal: null)>
    Actual: TextInputType:<TextInputType(name: TextInputType.number, signed: false, decimal: true)>
  00:01 +0 -1: RN1 the Room section shows for exactly one room: hidden for none, two rooms, a room and a wall, a wall, a separator [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10movable — rooms movable by the select tool (spec; killer GR4)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-M-10movable-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  94,95c94
  <   bool movable(DraftDocument d, Handle group) =>
  <       d.components.get<RoomParams>(group) == null;
  ---
  >   bool movable(DraftDocument d, Handle group) => true;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR4 ')` (exit 1; log `t19-M-10movable-run1.log`)

  ```
  Expected: false
    Actual: <true>
  00:01 +0 -1: GR4 a body drag on a selected room moves nothing; rooms alone have no rotation grip; a wall selected with a room moves and the room re-traces, origin [E]
  Expected: false
    Actual: <true>
  00:02 +0 -2: GR4 a body drag on a selected room moves nothing; rooms alone have no rotation grip; a wall selected with a room moves and the room re-traces, corpus far origin, 23 deg, own groups [E]
  00:02 +0 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10gripframe — the label grip subtracts the world line offset from the local point (spec; killer GR6)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-M-10gripframe-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  117c117
  <         toWorld.transformPoint(q) - Vector2(0, kRoomLineOffset * hNameW);
  ---
  >         toWorld.transformPoint(q - Vector2(0, kRoomLineOffset * hNameW));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR6 ')` (exit 1; log `t19-M-10gripframe-run1.log`)

  ```
  00:00 +0 -1: GR6 the label grip under a rotated, translated, scaled room group: GR1 and GR2 again [E]
    Expected: a value less than <0.000001>
      Actual: <61.155266717332886>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 636:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10offset@grip — the stored label offset ignored, at RoomGrips' pole (spec; second site)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-M-10offset_grip-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  102c102
  <     poleL = toLocal.transformPoint(anchorW) - _offsetOf(params);
  ---
  >     poleL = toLocal.transformPoint(anchorW);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR1 ')` (exit 1; log `t19-M-10offset_grip-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: a value less than <0.000001>
      Actual: <342.8291250754521>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 252:7                     main.<fn>
  Expected: a numeric value within <0.000001> of <375.3699999999999>
    Actual: <685.7399999999998>
     Which:  differs by <310.3699999999999>
  00:01 +0 -2: GR1 (shell) the label grip is shown at the anchor and a drag stores the offset in one undo step, origin [E]
  Expected: a numeric value within <0.000001> of <110.77473753131926>
    Actual: <421.144737531431>
     Which:  differs by <310.37000000011176>
  00:02 +0 -3: GR1 (shell) the label grip is shown at the anchor and a drag stores the offset in one undo step, corpus far origin, 23 deg, own groups [E]
  00:02 +0 -4: GR6 the label grip under a rotated, translated, scaled room group: GR1 and GR2 again [E]
    Expected: (double, double):<(250.24666666530072, 400.5399999999348)>
      Actual: (double, double):<(560.6166666653007, 254.9299999999348)>
  ... (2 more kept lines in the log)
  00:02 +0 -4: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 0; log `t19-M-10offset_grip-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### X17-autoGate — the return to auto gated on F3

Task 17's fragment.

- **file:** `apps/floor_planner/lib/main.dart`; backup `t19-X17-autoGate-main.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  263c263,265
  <           labelAperture: () => kSnapAperturePixels / _camera.value.scale,
  ---
  >           labelAperture: () => _snap.objectSnap
  >               ? kSnapAperturePixels / _camera.value.scale
  >               : 0,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR2 ')` (exit 1; log `t19-X17-autoGate-run1.log`)

  ```
  Expected: null
    Actual: (double, double):<(26.66666666666697, -20.000000000000227)>
  00:01 +0 -1: GR2 a drop within the aperture of the pole returns the label to auto, with object snap on and off, origin [E]
  Expected: null
    Actual: (double, double):<(26.666666666977108, -20.00000000023283)>
  00:02 +0 -2: GR2 a drop within the aperture of the pole returns the label to auto, with object snap on and off, corpus far origin, 23 deg, own groups [E]
  00:02 +1 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/main.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X17-noNull — a no-change drop returns a command

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-X17-noNull-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  65d64
  <     if (next == s.params.label) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR1 ')` (exit 1; log `t19-X17-noNull-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<RoomParams>'>
    test/room_grips_test.dart 279:7                     main.<fn>
  00:01 +3 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X17-moveSep — SeparatorGrips.movable false

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-X17-moveSep-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  78c78
  <   bool movable(DraftDocument d, Handle group) => true;
  ---
  >   bool movable(DraftDocument d, Handle group) => false;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR5 ')` (exit 1; log `t19-X17-moveSep-run1.log`)

  ```
  00:00 +0 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, origin [E]
    Expected: true
      Actual: <false>
    test/room_grips_test.dart 492:7                     main.<fn>
  Expected: true
    Actual: <false>
  00:01 +0 -2: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, origin [E]
  00:01 +0 -3: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: true
      Actual: <false>
    test/room_grips_test.dart 492:7                     main.<fn>
  Expected: true
    Actual: <false>
  00:02 +0 -4: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, corpus far origin, 23 deg, own groups [E]
  00:02 +0 -4: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-autoNoAperture — the return to auto needs an exact drop

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-t17-autoNoAperture-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  135c135
  <     if ((pW - poleW).length <= apertureW) return null;
  ---
  >     if ((pW - poleW).length <= 0) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR2 ')` (exit 1; log `t19-t17-autoNoAperture-run1.log`)

  ```
  Expected: null
    Actual: (double, double):<(26.66666666666697, -20.000000000000227)>
  00:01 +0 -1: GR2 a drop within the aperture of the pole returns the label to auto, with object snap on and off, origin [E]
  Expected: null
    Actual: (double, double):<(26.666666666977108, -20.00000000023283)>
  00:02 +0 -2: GR2 a drop within the aperture of the pole returns the label to auto, with object snap on and off, corpus far origin, 23 deg, own groups [E]
  00:02 +0 -3: GR6 the label grip under a rotated, translated, scaled room group: GR1 and GR2 again [E]
    Expected: empty
      Actual: [(EntityKind, GeometryPayload):(EntityKind.line, Instance of 'GeometryPayload')]
    test/room_grips_test.dart 661:5                     main.<fn>
  00:02 +0 -3: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-nameSlot — the name TEXT found by first slot

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-t17-nameSlot-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  151c151
  <       if (best == null || h.value < best.value) {
  ---
  >       if (best == null) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-t17-nameSlot-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: a value less than <0.000001>
      Actual: <157.5>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 305:7                     main.<fn>
  00:03 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-onGrip — a drop on the grip returns a command

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-t17-onGrip-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  63d62
  <     if (world.x == s.anchorW.x && world.y == s.anchorW.y) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-t17-onGrip-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<RoomParams>'>
    test/room_grips_test.dart 276:7                     main.<fn>
  00:03 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-sepKeptTrim — the kept end re-trimmed

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-t17-sepKeptTrim-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  106,107c106,107
  <     final w = start ? trimmed.$1 : trimmed.$2;
  <     final local = d.tree.accumulatedTransform(group).invert().transformPoint(w);
  ---
  >     final inv = d.tree.accumulatedTransform(group).invert();
  >     final s = inv.transformPoint(trimmed.$1), e = inv.transformPoint(trimmed.$2);
  109,111c109,110
  <     return start
  <         ? (p.copyWith(start: local), (w, kept))
  <         : (p.copyWith(end: local), (kept, w));
  ---
  >     final w = start ? trimmed.$1 : trimmed.$2;
  >     return (p.copyWith(start: s, end: e), start ? (w, kept) : (kept, w));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR5 ')` (exit 1; log `t19-t17-sepKeptTrim-run1.log`)

  ```
  00:01 +2 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: (double, double):<(-6098.257246690802, -213.32499427208677)>
      Actual: (double, double):<(-6098.257246690337, -213.32499427208677)>
    test/room_grips_test.dart 519:11                    main.<fn>
  00:01 +3 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-sepNoInvalidate — the grips do not invalidate at release

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-t17-sepNoInvalidate-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  60d59
  <     inputs.invalidate();
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR5 ')` (exit 1; log `t19-t17-sepNoInvalidate-run1.log`)

  ```
  00:00 +0 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, origin [E]
    Expected: a value less than <0.000001>
      Actual: <130.21000000000004>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 574:7                     main.<fn>
  00:01 +1 -2: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: a value less than <0.000001>
      Actual: <130.20999999933093>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 574:7                     main.<fn>
  00:01 +2 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-sepOnGrip — a separator drop on the grip returns a command

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-t17-sepOnGrip-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  59d58
  <     if (world.x == end.x && world.y == end.y) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-t17-sepOnGrip-run1.log`)

  ```
  00:03 +10 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: null
      Actual: <Instance of 'SetComponentCommand<SeparatorParams>'>
    test/room_grips_test.dart 555:7                     main.<fn>
  00:04 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-clickContours — the click builds contours (Task 15 re-review Minor B)

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t17-clickContours-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  191c191
  <     final verdict = _verdictAt(_raw, contours: false);
  ---
  >     final verdict = _verdictAt(_raw);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT9 ')` (exit 1; log `t19-t17-clickContours-run1.log`)

  ```
  00:00 +0 -1: TT9 a click and the re-read after a document change build no outer contours: a click needs only the trace (Task 15's review) [E]
    Expected: <1>
      Actual: <2>
    test/room_tool_test.dart 852:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-commitContours — the post-commit re-read builds contours

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t17-commitContours-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  220c220
  <     _show(_verdictAt(_raw, contours: false));
  ---
  >     _show(_verdictAt(_raw));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT9 ')` (exit 1; log `t19-t17-commitContours-run1.log`)

  ```
  00:00 +0 -1: TT9 a click and the re-read after a document change build no outer contours: a click needs only the trace (Task 15's review) [E]
    Expected: <1>
      Actual: <2>
    test/room_tool_test.dart 852:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t17-listenerContours — the change listener builds contours

Task 17's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-t17-listenerContours-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  369c369
  <     _show(_verdictAt(_pointer, contours: false));
  ---
  >     _show(_verdictAt(_pointer));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT9 ')` (exit 1; log `t19-t17-listenerContours-run1.log`)

  ```
  00:00 +0 -1: TT9 a click and the re-read after a document change build no outer contours: a click needs only the trace (Task 15's review) [E]
    Expected: <1>
      Actual: <2>
    test/room_tool_test.dart 856:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-sepWorld — the separator grip in local, not world

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-rv17-sepWorld-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  107c107
  <     final local = d.tree.accumulatedTransform(group).invert().transformPoint(w);
  ---
  >     final local = w;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-rv17-sepWorld-run1.log`)

  ```
  00:03 +10 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: a value less than <0.000001>
      Actual: <4668134.8729264885>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 523:11                    main.<fn>
  Expected: a value less than <0.000001>
    Actual: <3713394.567890138>
     Which: is not a value less than <0.000001>
  00:04 +10 -2: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, corpus far origin, 23 deg, own groups [E]
  00:04 +11 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-sepSnapAlways — the separator grip trims with F3 off

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/separator_grips.dart`; backup `t19-rv17-sepSnapAlways-separator_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  103,104c103,104
  <         ? trimSeparator(world, kept, inputs, objectSnap: objectSnap())
  <         : trimSeparator(kept, world, inputs, objectSnap: objectSnap());
  ---
  >         ? trimSeparator(world, kept, inputs, objectSnap: true)
  >         : trimSeparator(kept, world, inputs, objectSnap: true);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-rv17-sepSnapAlways-run1.log`)

  ```
  00:03 +8 -1: GR5 a separator's end grips move one end, trimmed to a face with object snap on, origin [E]
    Expected: (double, double):<(5800.37, 3960.21)>
      Actual: (double, double):<(5807.390946347478, 3900.0)>
    test/room_grips_test.dart 540:13                    main.<fn>
  Expected: a value less than <0.000001>
    Actual: <60.617965881528576>
     Which: is not a value less than <0.000001>
  00:03 +8 -2: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, origin [E]
  00:03 +8 -3: GR5 a separator's end grips move one end, trimmed to a face with object snap on, corpus far origin, 23 deg, own groups [E]
    Expected: (double, double):<(-5779.058914140798, -536.3647526567802)>
      Actual: (double, double):<(-5747.772292394657, -484.44476529816166)>
    test/room_grips_test.dart 540:13                    main.<fn>
  Expected: a value less than <0.000001>
    Actual: <60.617965881812985>
     Which: is not a value less than <0.000001>
  00:04 +8 -4: GR5 (shell) a separator end dragged into a band is trimmed with F3 on and kept as placed with it off; a separator alone gets a rotation grip, corpus far origin, 23 deg, own groups [E]
  ... (1 more kept lines in the log)
  00:04 +9 -4: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/separator_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-nameMax — the name TEXT found by the highest handle

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-rv17-nameMax-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  151c151
  <       if (best == null || h.value < best.value) {
  ---
  >       if (best == null || h.value > best.value) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-rv17-nameMax-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: a value less than <0.000001>
      Actual: <157.5>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 233:7                     main.<fn>
  Expected: a value less than <0.000001>
    Actual: <157.5>
     Which: is not a value less than <0.000001>
  00:01 +0 -2: GR1 (shell) the label grip is shown at the anchor and a drag stores the offset in one undo step, origin [E]
  Expected: a value less than <0.000001>
    Actual: <157.5>
     Which: is not a value less than <0.000001>
  00:02 +0 -3: GR2 a drop within the aperture of the pole returns the label to auto, with object snap on and off, origin [E]
  Expected: a value less than <0.000001>
    Actual: <157.5>
     Which: is not a value less than <0.000001>
  ... (11 more kept lines in the log)
  00:04 +7 -6: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-previewStale — the label grip's preview not refreshed

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-rv17-previewStale-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  73c73
  <     if (!identical(d, _draggingDocument) || !identical(grip, _draggingGrip)) {
  ---
  >     if (_draggingGrip == null) {
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart)` (exit 1; log `t19-rv17-previewStale-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: empty
      Actual: [(EntityKind, GeometryPayload):(EntityKind.line, Instance of 'GeometryPayload')]
    test/room_grips_test.dart 281:7                     main.<fn>
  00:03 +12 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-apertureLocal — the aperture compared in local space (Task 17 review M1, carried to Task 18: GR6)

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-rv17-apertureLocal-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  135d134
  <     if ((pW - poleW).length <= apertureW) return null;
  136a136
  >     if (l.length <= apertureW) return null;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR6 ')` (exit 1; log `t19-rv17-apertureLocal-run1.log`)

  ```
  00:00 +0 -1: GR6 the label grip under a rotated, translated, scaled room group: GR1 and GR2 again [E]
    Expected: non-empty
      Actual: []
    test/room_grips_test.dart 681:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv17-defaultPage — the grip reads the default page (Task 17 review M2, carried to Task 18: GR1)

The Task 17 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_grips.dart`; backup `t19-rv17-defaultPage-room_grips.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  115c115
  <     final hNameW = kRoomNamePaperMm * _pageOf(d).scaleDenominator;
  ---
  >     final hNameW = kRoomNamePaperMm * _defaultPage.scaleDenominator;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_grips_test.dart --plain-name 'GR1 ')` (exit 1; log `t19-rv17-defaultPage-run1.log`)

  ```
  00:00 +0 -1: GR1 the label grip sits at the anchor, and a drag stores the offset in one undo step [E]
    Expected: a value less than <0.000001>
      Actual: <87.5>
       Which: is not a value less than <0.000001>
    test/room_grips_test.dart 320:7                     main.<fn>
  00:01 +3 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_grips.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10grow (all-inputs form) — no growth: straight to every contributor (spec; killer LZ3)

Task 18's fragment (`t18-o/n-grow1`).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10grow__all-inputs_form_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  587c587
  <   var r = kGrowthStart;
  ---
  >   var r = double.infinity;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 1; log `t19-M-10grow__all-inputs_form_-run1.log`)

  ```
  00:00 +0 -1: LZ3 a room's rebuild on the sample plan traces fewer segments than the bound set from the plan's run [E]
    Expected: a value less than or equal to <100>
      Actual: <114>
       Which: is not a value less than or equal to <100>
    test/room_cost_test.dart 144:7                      main.<fn>.moveP5
    test/room_cost_test.dart 169:31                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10grow (infinite first box) — no growth: the first box infinite (spec; killer LZ3)

Task 18's fragment (`t18-o/n-grow2`).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-M-10grow__infinite_first_box_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  585a586,590
  >   return traceRoom(seed, inputsOf(source.placedIn(Aabb2.raw(
  >       double.negativeInfinity,
  >       double.negativeInfinity,
  >       double.infinity,
  >       double.infinity))));
  586a592
  >   // ignore: dead_code
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 1; log `t19-M-10grow__infinite_first_box_-run1.log`)

  ```
  00:00 +0 -1: LZ3 a room's rebuild on the sample plan traces fewer segments than the bound set from the plan's run [E]
    Expected: a value less than or equal to <100>
      Actual: <402>
       Which: is not a value less than or equal to <100>
    test/room_cost_test.dart 144:7                      main.<fn>.moveP5
    test/room_cost_test.dart 173:12                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10visible — the tint's boundary visible (spec; killer RR1)

Task 18's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10visible-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  306c306
  <             boundaryFlags: EntityFlags.invisible),
  ---
  >             boundaryFlags: 0),
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'RR1 ')` (exit 1; log `t19-M-10visible-run1.log`)

  ```
  Expected: Set:[SelectionKey:SelectionKey( 244)]
    Actual: Set:[SelectionKey:SelectionKey( 273)]
     Which: does not contain SelectionKey:<SelectionKey( 244)>
  00:02 +0 -1: RR1 inside a room a click picks what it picked before, except on a label; a window band over bare floor selects nothing and over a label selects the room [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### M-10tintalpha — the tint's transparency not written (spec; killer RR2)

Task 18's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-M-10tintalpha-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  305d304
  <             transparency: kRoomTintTransparency,
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'RR2 ')` (exit 1; log `t19-M-10tintalpha-run1.log`)

  ```
  Expected: a numeric value within <2.0> of <229.0>
    Actual: <0>
     Which:  differs by <229.0>
  00:02 +0 -1: RR2 on white paper the tint is the foreground at about 10%: bare floor #E5E5E5, furniture tinted, not hidden; the keyhole's bridge is not stroked [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X18-noDashed — the DASHED record not written

Task 18's fragment.

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t19-X18-noDashed-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  60c60
  <   ensureDashedLinetype(doc);
  ---
  >   // ensureDashedLinetype(doc);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'RR4 ')` (exit 1; log `t19-X18-noDashed-run1.log`)

  ```
  Expected: a numeric value within <2.0> of <229.0>
    Actual: <0>
     Which:  differs by <229.0>
  00:01 +0 -1: RR4 the separator paints dashes at 1:50 [E]
  00:01 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### X18-order — the column built after the rooms

Task 18's fragment.

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t19-X18-order-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  177d176
  <   p.wall(x0 + 11500, y0 + 6000, x0 + 11900, y0 + 6000, 400);
  202a202
  >   p.wall(x0 + 11500, y0 + 6000, x0 + 11900, y0 + 6000, 400);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP5 ')` (exit 1; log `t19-X18-order-run1.log`)

  ```
  00:00 +0 -1: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say, then a column, a separator and seven rooms as spec 10 D23 says; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: a value greater than <628>
      Actual: <591>
       Which: is not a value greater than <628>
    test/startup_plan_test.dart 452:5                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 1; log `t19-X18-order-run2.log`)

  ```
  00:01 +6 -1: SP2 every furniture fill draws over every floor-finish line (M-05r); the nine walls' pieces are built first, below both (08 D18); the column, the separator and the rooms come after the furniture, in that order (10 D23) [E]
    Expected: a value greater than <631>
      Actual: <591>
       Which: is not a value greater than <631>
    test/startup_plan_test.dart 204:7                   main.<fn>
  00:01 +8 -2: SP5 the sample plan is nine walls, seven doors and eight windows, exactly as spec 08 D18's tables say, then a column, a separator and seven rooms as spec 10 D23 says; no gap, no box; drift() and diagnostics() are empty [E]
    Expected: a value greater than <628>
      Actual: <591>
       Which: is not a value greater than <628>
    test/startup_plan_test.dart 452:5                   main.<fn>
  00:01 +10 -2: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### X18-pageLate — the page set after the rooms (equivalent: byte-identical encoding, the fallback page is 1:50 m; Task 18 and its review)

Task 18's fragment.

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t19-X18-pageLate-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  189,193d188
  <   PageComponent.register(doc.components);
  <   doc.header.units = DrawingUnits.millimeters;
  <   doc.commands.execute(SetComponentCommand<PageComponent>(
  <       doc.rootHandle, startupPage(doc.extents)));
  < 
  202a198,201
  >   PageComponent.register(doc.components);
  >   doc.header.units = DrawingUnits.millimeters;
  >   doc.commands.execute(SetComponentCommand<PageComponent>(
  >       doc.rootHandle, startupPage(doc.extents)));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 0; log `t19-X18-pageLate-run1.log`)

  ```
  00:01 +12: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart)` (exit 0; log `t19-X18-pageLate-run2.log`)

  ```
  00:05 +6: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 2 commands red).

#### t18-areaHeight — the area label 2.5 mm

Task 18's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t18-areaHeight-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  115c115
  < const double kRoomAreaPaperMm = 2.0;
  ---
  > const double kRoomAreaPaperMm = 2.5;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-t18-areaHeight-run1.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: <100.0>
      Actual: <125.0>
    test/startup_plan_test.dart 561:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t18-columnInDoorway — the column in a doorway

Task 18's fragment.

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t19-t18-columnInDoorway-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  177c177
  <   p.wall(x0 + 11500, y0 + 6000, x0 + 11900, y0 + 6000, 400);
  ---
  >   p.wall(x0 + 11100, y0 + 4200, x0 + 11500, y0 + 4200, 400);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP4 ')` (exit 1; log `t19-t18-columnInDoorway-run1.log`)

  ```
  00:00 +0 -1: SP4 every doorway is clear of furniture and of the column for 900 mm on both sides (Ruling F-8, 10 D23) [E]
    Expected: false
      Actual: <true>
    test/startup_plan_test.dart 371:11                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### t18-poleOff — the labels 3 m off the pole

Task 18's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-t18-poleOff-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  285c285
  <     final pole = poleOfInaccessibility(trace.ring, trace.holes).point;
  ---
  >     final pole = poleOfInaccessibility(trace.ring, trace.holes).point + Vector2(3000, 0);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 1; log `t19-t18-poleOff-run1.log`)

  ```
  00:00 +0 -1: SP7 each sample-plan room's net area matches the table to 1e-2 mm², its labels are 125 and 100 high, and its label point lies in its face [E]
    Expected: true
      Actual: <false>
    test/startup_plan_test.dart 567:7                   main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv18-alpha20 — transparency 204

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv18-alpha20-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  109c109
  < const int kRoomTintTransparency = 229;
  ---
  > const int kRoomTintTransparency = 204;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_paint_test.dart --plain-name 'RR2 ')` (exit 1; log `t19-rv18-alpha20-run1.log`)

  ```
  Expected: a numeric value within <2.0> of <229.0>
    Actual: <204>
     Which:  differs by <25.0>
  00:02 +0 -1: RR2 on white paper the tint is the foreground at about 10%: bare floor #E5E5E5, furniture tinted, not hidden; the keyhole's bridge is not stroked [E]
  00:02 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv18-growStart16k — kGrowthStart 16,000

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv18-growStart16k-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  547c547
  < const double kGrowthStart = 1000;
  ---
  > const double kGrowthStart = 16000;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 1; log `t19-rv18-growStart16k-run1.log`)

  ```
  00:00 +0 -1: LZ3 a room's rebuild on the sample plan traces fewer segments than the bound set from the plan's run [E]
    Expected: a value less than or equal to <100>
      Actual: <114>
       Which: is not a value less than or equal to <100>
    test/room_cost_test.dart 144:7                      main.<fn>.moveP5
    test/room_cost_test.dart 169:31                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv18-growSlow — growth by 1.25

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv18-growSlow-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  599c599
  <     r *= 2;
  ---
  >     r *= 1.25;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 1; log `t19-rv18-growSlow-run1.log`)

  ```
  00:00 +0 -1: LZ3 a room's rebuild on the sample plan traces fewer segments than the bound set from the plan's run [E]
    Expected: a value less than or equal to <100>
      Actual: <114>
       Which: is not a value less than or equal to <100>
    test/room_cost_test.dart 144:7                      main.<fn>.moveP5
    test/room_cost_test.dart 169:31                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv18-certMargin1000 — the certificate margin 1,000

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv18-certMargin1000-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  551c551
  < const double kCertificateMargin = 1;
  ---
  > const double kCertificateMargin = 1000;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'LZ3 ')` (exit 1; log `t19-rv18-certMargin1000-run1.log`)

  ```
  00:00 +0 -1: LZ3 a room's rebuild on the sample plan traces fewer segments than the bound set from the plan's run [E]
    Expected: a value less than or equal to <100>
      Actual: <101>
       Which: is not a value less than or equal to <100>
    test/room_cost_test.dart 144:7                      main.<fn>.moveP5
    test/room_cost_test.dart 169:31                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv18-noDissolveUnbounded — rooms dissolve only when SeedInWall (red in the shell's undo tests, Ruling 10-22)

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv18-noDissolveUnbounded-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  243c243
  <       _traceOf(view, self) is! Traced;
  ---
  >       _traceOf(view, self) is SeedInWall;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart)` (exit 1; log `t19-rv18-noDissolveUnbounded-run1.log`)

  ```
  Expected: null
    Actual: GroupNode:<GroupNode(255, 0 children)>
  00:04 +10 -1: cmd+Z undoes a Delete through the command log [E]
  Expected: null
    Actual: GroupNode:<GroupNode(255, 0 children)>
  00:05 +10 -2: ctrl+Z after deleting two walls brings both back in one step [E]
  00:05 +10 -2: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RD2 ')` (exit 1; log `t19-rv18-noDissolveUnbounded-run2.log`)

  ```
  00:00 +0 -1: RD2 a face opened to the outside dissolves its room [E]
    Expected: null
      Actual: RoomParams:<RoomParams((1512.5, 1987.25), Room 1, null)>
    test/room_dissolve_test.dart 157:3                  expectDissolved
    test/room_dissolve_test.dart 567:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (2 of 2 commands red).

#### rv18-pageAfterDispose — the page set after the plan's build (equivalent, as X18-pageLate)

The Task 18 review's fragment.

- **file:** `apps/floor_planner/lib/startup_plan.dart`; backup `t19-rv18-pageAfterDispose-startup_plan.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  189,192d188
  <   PageComponent.register(doc.components);
  <   doc.header.units = DrawingUnits.millimeters;
  <   doc.commands.execute(SetComponentCommand<PageComponent>(
  <       doc.rootHandle, startupPage(doc.extents)));
  207a204,207
  >   PageComponent.register(doc.components);
  >   doc.header.units = DrawingUnits.millimeters;
  >   doc.commands.execute(SetComponentCommand<PageComponent>(
  >       doc.rootHandle, startupPage(doc.extents)));
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart)` (exit 0; log `t19-rv18-pageAfterDispose-run1.log`)

  ```
  00:01 +12: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/startup_plan.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).


### Re-fires after the first run

`t3-nullKeys` over the whole page test; `rv13-degDxOnly` at `RL3`; `rv14-noStep3` at `TN1`, `RG2`, `DG3`; `t10-holeLen` wide (the equivalence probe); `M-10hover` at `TT6` as fixed (the fix in the worktree, committed unchanged as `ee610fd` right after).

#### t3-nullKeys (whole page_test) — t3-nullKeys re-fired against the whole page test

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-t3-nullKeys__whole_page_test_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  270c270,273
  <     if (r.type.pageKey(before.page) == r.type.pageKey(after.page)) continue;
  ---
  >     if (r.type.pageKey(before.page) == r.type.pageKey(after.page) &&
  >         r.type.pageKey(after.page) != null) {
  >       continue;
  >     }
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/page_test.dart)` (exit 1; log `t19-t3-nullKeys__whole_page_test_-run1.log`)

  ```
  00:00 +0 -1: PG1 a page change seeds exactly the types whose key changed, in one undo step; a page-only edit regenerates; a seeded object with a dead reference does not refuse it [E]
    Expected: <2>
      Actual: <3>
    test/parametric/page_test.dart 149:5  main.<fn>
  00:00 +1 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv13-degDxOnly (at RL3, its Task 13 killer) — room.degenerate on dx only, re-fired at RL3 (the Task 13 review's killer, room_object_test 475 then)

The first round ran DG1 and the diagnostics file only; the review's log names RL3.

- **file:** `apps/floor_planner/lib/parametric/room.dart`; backup `t19-rv13-degDxOnly__at_RL3__its_Task_13_killer_-room.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  365c365
  <       if (p.label case (final dx, final dy) when !dx.isFinite || !dy.isFinite)
  ---
  >       if (p.label case (final dx, final _) when !dx.isFinite)
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_object_test.dart --plain-name 'RL3 ')` (exit 1; log `t19-rv13-degDxOnly__at_RL3__its_Task_13_killer_-run1.log`)

  ```
  00:00 +0 -1: RL3 a label offset rides with the pole across a wall move [E]
    Expected: [
      Actual: [
       Which: at location [2] is [
    test/room_object_test.dart 475:7                    main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv14-noStep3 (at the step-3 fixtures left after Task 14b) — step 3 reported as step 2, re-fired at TN1, RG2 and DG3

FZ1 killed it at Task 14 (60 real step-3 outlines); Task 14b's split removed every one of them (FZ1's census after 14b: 1,855 step 1, 0 step 2, 0 step 3), so FZ1 can no longer see it. Step 3 now arises only from an outer ring pinched at a vertex: TN1's pinched ring, RG2's 45° column and DG3.

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-rv14-noStep3__at_the_step-3_fixtures_left_after_Task_14b_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  859c859
  <   return Tint(3, ring, leftOut);
  ---
  >   return Tint(2, ring, leftOut);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart --plain-name 'TN1 ')` (exit 1; log `t19-rv14-noStep3__at_the_step-3_fixtures_left_after_Task_14b_-run1.log`)

  ```
  00:00 +0 -1: TN1 tintOf: a pinched ring takes step 3, a pinched hole step 2; a second hole whose view is blocked by the first bridges to the growing ring; a hole with no visible vertex is left out and reported; an acute hole whose nearest b [cut; the full line is in the log]
    Expected: <3>
      Actual: <2>
    test/room_tint_test.dart 204:7                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart --plain-name 'RG2 ')` (exit 1; log `t19-rv14-noStep3__at_the_step-3_fixtures_left_after_Task_14b_-run2.log`)

  ```
  00:00 +0 -1: RG2 a room's holes and the tint's fallback chain: one column, two columns, and step 2 with room.tint, at six placements [E]
    Expected: [
      Actual: [
       Which: at location [0] is EntityKind:<EntityKind.fill> instead of EntityKind:<EntityKind.text>
    test/room_dissolve_test.dart 258:7                  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_diagnostics_test.dart --plain-name 'DG3 ')` (exit 1; log `t19-rv14-noStep3__at_the_step-3_fixtures_left_after_Task_14b_-run3.log`)

  ```
  00:00 +0 -1: DG3 room.tint reports a fallback step and a hole left out [E]
    Expected: [
      Actual: [
       Which: at location [0] is Diagnostic:<[warning] room.tint: room 26 ("Room 1"): its tint covers its holes: the keyholed ring does not triangulate> instead of Diagnostic:<[warning] room.tint: room 26 ("Room 1"): its tint is an unfilled o [cut; the full line is in the log]
    test/room_diagnostics_test.dart 323:7               main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (3 of 3 commands red).

#### t10-holeLen (wide) — the loop-area rule removed, fired wide (equivalence probe)

Since Task 14b a free tree leaves no loop at all (`_splitDoubled` removes every doubled pair), so the zero-area residue Task 10's rule dropped cannot arise; and a split outer or hole cycle leaves the ring plus clockwise loops only (the Task 14b review's `rv14b-holesPositive`, "either sign kept", is equivalent for the same reason).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-t10-holeLen__wide_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  280d279
  <     if (!(areaOf(loop) < 0)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_trace_test.dart)` (exit 0; log `t19-t10-holeLen__wide_-run1.log`)

  ```
  00:00 +8: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart)` (exit 0; log `t19-t10-holeLen__wide_-run2.log`)

  ```
  00:00 +3: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tint_test.dart)` (exit 0; log `t19-t10-holeLen__wide_-run3.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_localise_test.dart)` (exit 0; log `t19-t10-holeLen__wide_-run4.log`)

  ```
  00:10 +3: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_dissolve_test.dart)` (exit 0; log `t19-t10-holeLen__wide_-run5.log`)

  ```
  00:01 +9: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_follow_test.dart --plain-name 'FZ1 ')` (exit 0; log `t19-t10-holeLen__wide_-run6.log`)

  ```
  00:10 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart --plain-name 'SP7 ')` (exit 0; log `t19-t10-holeLen__wide_-run7.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 7 commands red).

#### M-10hover (after TT6's fix) — the hover never short-circuits, re-fired against TT6 as fixed by Task 19

Fix: TT6 first hovers its four points outside the bounding box on a fresh generation and asserts no trace and no contour build (`debugContourBuilds` 0), with the premise that each point is outside the box.

- **file:** `apps/floor_planner/lib/parametric/room_tool.dart`; backup `t19-M-10hover__after_TT6_s_fix_-room_tool.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  251c251
  <     if (u == null || !u.containsPoint(p)) return _Verdict.none;
  ---
  >     if (u == null) return _Verdict.none;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tool_test.dart --plain-name 'TT6 ')` (exit 1; log `t19-M-10hover__after_TT6_s_fix_-run1.log`)

  ```
  00:00 +0 -1: TT6 steady hovers re-trace nothing; outside the bounding box of every place box nothing is traced; the Kitchen seed, outside every place box but inside that box, is traced and previewed; a band's verdict is reused; an Unbounded [cut; the full line is in the log]
    Expected: (({int previews, int segments, int traces}), int):<((previews: 0, segments: 0, traces: 0), 0)>
      Actual: (({int previews, int segments, int traces}), int):<((previews: 0, segments: 0, traces: 0), 1)>
    test/room_tool_test.dart 555:5                      main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_tool.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).


### Controls: the degenerate rectangle

#### CTL-M-10a — control: M-10a on the degenerate rectangle

- **file:** `apps/floor_planner/lib/parametric/room_inputs.dart`; backup `t19-CTL-M-10a-room_inputs.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  100a101,105
  >       if (ring.isNotEmpty) {
  >         return RoomInput(
  >             h, [toWorld.transformPoint(p.start), toWorld.transformPoint(p.end)],
  >             closed: false);
  >       }
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL shape')` (exit 0; log `t19-CTL-M-10a-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL area')` (exit 1; log `t19-CTL-M-10a-run2.log`)

  ```
  00:00 +0 -1: CTL area: the net area is the inner faces by hand [E]
    Expected: a numeric value within <0.01> of <10640000>
      Actual: <12000000.0>
       Which:  differs by <1360000.0>
    test/t19_control_test.dart 41:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_inputs.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### CTL-M-10b — control: M-10b on the degenerate rectangle

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-CTL-M-10b-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  194d193
  <     if (!(areas[c] > 0)) continue;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL shape')` (exit 0; log `t19-CTL-M-10b-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL area')` (exit 1; log `t19-CTL-M-10b-run2.log`)

  ```
  00:00 +0 -1: CTL area: the net area is the inner faces by hand [E]
    Expected: a numeric value within <0.01> of <10640000>
      Actual: <-13440000.0>
       Which:  differs by <24080000.0>
    test/t19_control_test.dart 41:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### CTL-M-10c — control: M-10c on the degenerate rectangle

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-CTL-M-10c-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  76c76
  <   return (point: Vector2(best.x, best.y) + o, distance: best.d);
  ---
  >   return (point: Vector2(minX + w / 2, minY + ht / 2) + o, distance: best.d);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL shape')` (exit 0; log `t19-CTL-M-10c-run1.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/t19_control_test.dart --plain-name 'CTL area')` (exit 0; log `t19-CTL-M-10c-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** SURVIVED (0 of 2 commands red).

### Fix round 1 (the audit of `d1a81d8`)

Fired at `4b12f65` (the two new test cases committed; the library files as at `749c277`), with a clean worktree before and after. Each command was baselined on that tree (`t19-baseline-r1.txt`): all five exit 0, each narrowed one `+1`, `room_panel_test.dart` `+8`.

#### r1-X14-sc-boxGuard (at SD6; = X6-readAlways) — `_triggered`'s empty-L return removed, re-fired at SD6 (fix round 1, the audit's I-1)

Byte-identical to `X6-readAlways`, killed at `SD6` in Task 6. The first run fired it at `RK1` only, and so called it equivalent.

- **file:** `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; backup `t19-r1-X14-sc-boxGuard__at_SD6____X6-readAlways_-regeneration.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  341d340
  <   if (boxes.isEmpty) return const [];
  ```
- **command:** `(cd packages/jet_cad_2d && CI=true dart test test/parametric/place_test.dart --plain-name 'SD6 ')` (exit 1; log `t19-r1-X14-sc-boxGuard__at_SD6____X6-readAlways_-run1.log`)

  ```
  00:00 +0 -1: SD6 the trigger's counts: no seeds, no call; a non-contributor edit, no call; a contributor edit, one place box per contributor of K live before and one per contributor live after, and one read box per live reader; the first pl [cut; the full line is in the log]
    Expected: (int, int):<(0, 0)>
      Actual: (int, int):<(0, 2)>
    test/parametric/place_test.dart 704:7  main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_cost_test.dart --plain-name 'RK1 ')` (exit 0; log `t19-r1-X14-sc-boxGuard__at_SD6____X6-readAlways_-run2.log`)

  ```
  00:00 +1: All tests passed!
  ```
- **restore:** `cp` the backup to `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** PARTIAL (1 of 2 commands red).

#### r1-X11-feet (at RA1 with the tie case) — 304.8 squared as an integer product, re-fired at RA1 with its new tie case (fix round 1, the audit's I-1)

`4b12f65` adds to `RA1` a 1,524 × 1,714.5 mm room, exactly 28.125 ft², its tie premises asserted: D11's double product reads 28.12, the integer square 28.13.

- **file:** `apps/floor_planner/lib/parametric/room_label.dart`; backup `t19-r1-X11-feet__at_RA1_with_the_tie_case_-room_label.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  171c171
  <         '${(mm2 / (304.8 * 304.8)).toStringAsFixed(2)} ft²',
  ---
  >         '${(mm2 / (3048 * 3048 / 100)).toStringAsFixed(2)} ft²',
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_label_test.dart --plain-name 'RA1 ')` (exit 1; log `t19-r1-X11-feet__at_RA1_with_the_tie_case_-run1.log`)

  ```
  00:00 +0 -1: RA1 the area format in each of the five units [E]
    Expected: '28.12 ft²'
      Actual: '28.13 ft²'
       Which: is different.
              Expected: 28.12 ft²
                Actual: 28.13 ft²
    test/room_label_test.dart 193:5                     main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_label.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### r1-rv14b-splitOnce (at DE1 with the star) — a loop that is not whole kept only past 1,000 loops, re-fired at DE1 with its new star (fix round 1, the audit's I-1)

`4b12f65` adds to `DE1` a star: a column with 1,002 small columns tied to it by separators, traced at all six placements (about 1.9 s in all): 1,003 holes, 600,403,200 mm² by hand. The mutant keeps one loop too many (1,004).

- **file:** `apps/floor_planner/lib/parametric/room_trace.dart`; backup `t19-r1-rv14b-splitOnce__at_DE1_with_the_star_-room_trace.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  1047c1047
  <     if (whole && hs.isNotEmpty) loops.add(hs);
  ---
  >     if (hs.isNotEmpty && (whole || loops.length > 1000)) loops.add(hs);
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_tie_test.dart --plain-name 'DE1 ')` (exit 1; log `t19-r1-rv14b-splitOnce__at_DE1_with_the_star_-run1.log`)

  ```
  00:00 +0 -1: DE1 a doubled edge is split out of the walk: the island it ties is a hole, the area unchanged, the ties in no source set, at six placements [E]
    Expected: an object with length of <1003>
      Actual: [
       Which: has length of <1004>
    test/room_tie_test.dart 428:7                       main.<fn>
  00:00 +0 -1: Some tests failed.
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/parametric/room_trace.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** KILLED (1 of 1 commands red).

#### rv16-noMemo — the Room section's Area memo dropped (`if (room == _areaRoom) return _areaText;`, `selection_panel.dart:495`): accepted (cost)

Plan-10 code (Task 16), not a probe of 07/08 code as the first run said: the memo saves a scan of the live slots per rebuild; the Area line reads the same string either way. Fix round 1's ruling (m-1): accepted (cost).

- **file:** `apps/floor_planner/lib/selection_panel.dart`; backup `t19-rv16-noMemo-selection_panel.dart`
- **edit** (`diff <backup> <file>`):

  ```diff
  495d494
  <     if (room == _areaRoom) return _areaText;
  ```
- **command:** `(cd apps/floor_planner && CI=true flutter test test/room_panel_test.dart)` (exit 0; log `t19-rv16-noMemo-run1.log`)

  ```
  00:04 +8: All tests passed!
  ```
- **restore:** `cp` the backup to `apps/floor_planner/lib/selection_panel.dart`; `diff` exit 0; `git diff --quiet` exit 0.
- **result:** EQUIV-GREEN (0 of 1 commands red).

