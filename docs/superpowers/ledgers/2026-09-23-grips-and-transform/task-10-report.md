# Task 10 report — mutation testing (Plan 03, grips-and-transform)

## Status: DONE

## What was implemented

Fired every named mutant from the brief's table (M-03a … M-03aa, the spec's
27; M-03ab … M-03ax, the plan's 23, Ruling 03-17) plus everything the
controller's addendum added on top: two rows re-expressed against code that
had moved since the brief was written (M-03ab, M-03as), one row split into
"which test actually kills it" (M-03ah / M-03ah′ / C2-doesn't-catch-it),
M-03ai's ordinal tie-break logged as an equivalent mutant by construction,
and ten controller-added mutants (M-03ay … M-03bg, including M-03bf′) each
behind a new test written test-first (RED under the mutant, GREEN restored)
and landed in its own commit, exactly as the addendum specifies. No
production code changed anywhere in this task.

Full mutant-by-mutant log, in the same order as fired: `docs/superpowers/notes/plan-03-mutation-log.md`.

**Tally: 62 mutants exercised — fired 60, killed 60, survived 1 (M-03e,
designed), equivalent 1 (M-03ai's ordinal-clause variant, by construction).**

## Method

For every mutant: `cp` the source file to
`.superpowers/sdd/2026-09-23-grips-and-transform/mutation-backups/<basename>.<id>`,
apply the one edit by hand (via a small Python string-replace script run
with literal paths — the interactive shell here refuses inline scripts
built from shell variables), run only the named test file(s) with
`CI=true`, paste the failing test names and summary line, `cp` the backup
back, then `diff` the backup against the restored file and paste its
(empty) output. Every mutant in the log below shows this sequence; I did
not synthesize any output — every pasted transcript is the literal
`flutter test` / `dart test` output from the command shown.

For the controller-added mutants (Task 1/3/4/7/8 review findings), the
sequence was: write the test, run it against the **unmutated** tree first
(GREEN, to confirm the test is valid before touching anything), apply the
mutant, run again (RED — pasted), restore, run again (GREEN, pasted),
`diff` confirms a clean restore, then commit the test file alone in its own
`test(...)`-prefixed commit.

## Deviations from the brief (all per the controller's addendum, which is
binding and was read before starting)

1. **M-03ab** — the brief's row assumed `interaction_layer.dart` still
   wrapped the whole subtree in a `ListenableBuilder`. Since Task 7's fix
   for a mid-drag-removal assert, the cursor is mirrored into a
   `ValueNotifier<MouseCursor>` rendered by a `ValueListenableBuilder`
   around just the `MouseRegion`. Re-expressed the same idea: render
   `MouseRegion(cursor: _tool.cursor, ...)` directly, no builder, no
   mirror. Fired.
2. **M-03as** — `_pressGrip` (int) became `GripRef? _pressRef`, re-found
   live at the slop. Re-expressed: record `_pressRef` on a grip hit but
   fall through instead of returning `PressClass.grip`. Fired (T1 and four
   cascading tests).
3. **M-03ah** — per the addendum, C2 (`grip_cache_test.dart`) cannot kill
   this mutant because `GripCache.box` calls the same mutated
   `worldBoundsOf` and compares against its own mutated output; O1
   (`outline_cache_test.dart`) is the real killer, since it compares
   against an independent `arcBounds` expectation. Confirmed both ways:
   O1 fires, C2 stays green (7/7 passed). Logged both, plus the separate
   `M-03ah′` variant (the `_Point` case's body → `break;`), which O1 *and*
   C2 both catch.
4. **M-03ai** — fired the named mutant (`h > bestHandle` → `h < bestHandle`,
   caught by both C6 and T10), then additionally fired the addendum's
   named equivalent — dropping the `ref.ordinal < bestOrdinal` tie clause
   entirely — and confirmed it survives (27/27 passed). Logged as
   `EQUIVALENT — by construction`, with the reason: `_grips` is built in
   ascending ordinal per key, so for any fixed handle a later-seen
   candidate at the same distance can only have a *greater* ordinal — the
   dropped clause could never have fired. Does not count against the
   "only M-03e survives" rule.
5. **Ten controller-added mutants** (M-03ay, M-03az, M-03ba, M-03bb,
   M-03bc, M-03bd, M-03be, M-03bf, M-03bf′, M-03bg) — M-03bc and M-03bd
   were already guarded by existing tests (the extended T14 and the M-03at
   test respectively), so no new test was needed for those two; the other
   seven mutant-ids needed a new test each, written test-first and
   committed separately. None of the seven exposed a production bug — every
   one is GREEN on the unmutated tree and RED under its mutant, so no
   `DONE_WITH_CONCERNS` branch was triggered.
6. One self-review finding, fixed in its own commit: the M-03be test
   commit (`d96a73d`) landed one line short of `dart format`'s liking (a
   long multi-line `expect` call). Caught when running the render-layer
   gate line, fixed with `dart format`, and committed separately
   (`7dcb36a`) rather than amending, per the repo's git-safety rule against
   amending.

## New test files (all test-only; no production `.dart` file changed)

- `packages/jet_cad_2d/test/document/grips_test.dart` — M-03ay
- `packages/jet_cad_2d/test/index/drag_snap_test.dart` — M-03az
- `packages/jet_cad_2d_flutter/test/grip_cache_test.dart` — M-03ba, M-03bb
- `packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart` — M-03be
- `packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart` — M-03bf, M-03bf′, M-03bg

Each of these five files' diff against HEAD (32fa2cd) is test-only:

```
$ git diff --stat 32fa2cd -- '*.dart'
 packages/jet_cad_2d/test/document/grips_test.dart  | 13 +++
 packages/jet_cad_2d/test/index/drag_snap_test.dart | 38 +++++++++
 .../jet_cad_2d_flutter/test/grip_cache_test.dart   | 40 ++++++++++
 .../test/select_tool_drag_test.dart                | 27 +++++++
 .../test/selection_overlay_grips_test.dart         | 93 ++++++++++++++++++++++
 5 files changed, 211 insertions(+)
```

## Gate lines (run once, after every mutation was restored and every new
test committed)

Engine:
```
$ cd packages/jet_cad_2d && dart test
...
00:03 +890: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 130 files (0 changed) in 0.23 seconds.
(exit 0)
```
890 = the dispatch's baseline 888 + the two new engine tests (M-03ay,
M-03az).

Render layer:
```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:12 +851 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)

$ dart format --output=none --set-exit-if-changed .
Formatted 159 files (0 changed) in 0.34 seconds.
(exit 0)
```
851 passed + 1 skip + 5 standing golden failures = the dispatch's baseline
846 + 1 + 5, plus the five new render-layer tests (M-03ba, M-03bb, M-03be,
M-03bf/M-03bf′ share one test, M-03bg) all passing. Exactly the five
standing `text_ladder_golden_test.dart` failures the standing instructions
name as not mine.

App (not named in CLAUDE.md's gate lines, but exercised for several
mutants' app-side kill, so run for completeness):
```
$ cd apps/floor_planner && flutter test
...
00:01 +26: All tests passed!

$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.3s)

$ dart format --output=none --set-exit-if-changed .
Formatted 8 files (0 changed) in 0.03 seconds.
(exit 0)
```
26 = the dispatch's baseline, unchanged (no app test file was touched).

## Tree cleanliness

```
$ git status --short
(clean, before the log commit)
```
Only the new test files (each already committed separately) and the
mutation log were ever new/modified; `git diff --stat 32fa2cd -- '*.dart'`
(above) lists only test files. No `analysis_options.yaml` was touched.

## Self-review

- Every mutation was applied via a byte-for-byte `cp`/restore/`diff`
  cycle; no mutant edit was ever left in place past its own test run.
- Every "FIRED" claim in the log is backed by pasted real command output
  naming the specific failing test; every "SURVIVED"/"EQUIVALENT" claim is
  backed by a pasted `All tests passed!` line.
- The seven new tests each target the exact mutant they're named for —
  none is a generic "does the code run" test — and each was shown RED
  under its own mutant before being trusted, not just assumed from reading
  the code.
- M-03bg needed a non-obvious testing technique (`Path.computeMetrics()`'s
  exact start point, rather than `Path.getBounds()`, whose conic
  control-point approximation is documented elsewhere in this codebase as
  imprecise for a partial arc sweep) to get a tight, unambiguous kill
  signal rather than a fuzzy one.
- Draw order / `Tolerance` non-negotiables: untouched — this task changed
  no production code.

## Concerns

None. No new test exposed a production defect; the `DONE_WITH_CONCERNS`
branch was never needed.
