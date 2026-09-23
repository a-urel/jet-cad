# Task 10 report: the invariants, and the greps

## What I did

Ran every invariant check and grep the brief lists, ran all four gate lines
(including both release builds), checked the branch's commit trailers and
commit count against Ruling P-6, and appended the results to
`docs/superpowers/notes/plan-05-mutation-log.md` under a new heading
"## Invariants and greps (Task 10)". No production or test code changed --
this task is measurement and logging only.

`main` here means the local branch `main`, which was confirmed at `7dac3b5`
(`git rev-parse main` and `git merge-base main HEAD` both print
`7dac3b5fd10e95c858c6e49ff69a5895a205d6aa`), matching the dispatch's stated
branch point.

## Invariants and greps -- commands and exact output

```
$ git diff main -- packages/jet_cad_2d_flutter/lib/src/tool.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart | wc -l
       0
```
Invariant 4 holds.

```
$ git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l
       0
```
The allocation invariant tests are unedited.

```
$ grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l
3
```
Followed up with the un-piped grep to see the hits:
```
$ grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib
packages/jet_cad_2d/lib/src/document/tables.dart:38:/// `package:jet_cad_2d` is pure Dart on purpose — no `dart:ui`, no Flutter —
packages/jet_cad_2d/lib/src/document/text_metrics.dart:16:/// the em size. `dart:ui` exposes no cap height — `computeLineMetrics` gives
packages/jet_cad_2d/lib/src/geometry/dasher.dart:47:/// Pure geometry: no `dart:ui`, no document access, no allocation per call. The
```
All three hits are `///` doc comments *naming* the pure-Dart constraint (they
say the package deliberately avoids `dart:ui`/Flutter); none is an `import`.
Verified there is no `import 'package:flutter` or `import 'dart:ui'` anywhere
under `packages/jet_cad_2d/lib`. The engine stays pure Dart -- the count of 3
is prose, not a violation.

```
$ grep -rn "Path()" packages/jet_cad_2d_flutter/lib/src/draw
packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:47:  final Path band = Path();
```
Exactly one hit, exactly the expected one: `placement_tool.dart`'s reused
`band` field (D12). No other `Path()` construction exists under
`lib/src/draw`, so no `Path()` is constructed on the paint path.

```
$ grep -rn "handleSeed" packages/jet_cad_2d_flutter/lib/src/draw apps/floor_planner/lib
apps/floor_planner/lib/startup_plan.dart:178:        handle: doc.handleSeed.next(),
```
One hit. Per the dispatch's advance note, this is `startup_plan.dart:178`,
inside `_Pen._add` -- the sample plan's own pre-existing line builder, not a
drawing tool (confirmed by reading the surrounding code: `_Pen` is a private
helper class used only to construct the startup sample plan's geometry, and
it predates this plan). There are **no** hits under
`packages/jet_cad_2d_flutter/lib/src/draw` and **no** hits elsewhere in
`apps/floor_planner/lib` (tool code, overlays, shell). Every handle a drawing
tool allocates goes through the drafting builders per Ruling 05-3; none of
the new tool code calls `handleSeed` directly.

```
$ grep -rn "Transform2.*==" packages/jet_cad_2d_flutter/test/draw apps/floor_planner/test/planner_draw_test.dart
```
No hits (empty output). `Transform2` is never compared with `==` in the new
tests.

## Gate lines -- summary lines and exit codes

`main` (`7dac3b5`) branch-point counts from the plan: engine 894; render
layer 854 + 1 skip + 5 goldens; harness 82; app 26.

### `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +911: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +911: All tests passed!
```
Exit code: 0. 911 passed -- matches the expected engine count exactly.

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 133 files (0 changed) in 0.23 seconds.
```
Exit code: 0.

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:12 +911 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exit code: 1 (confirmed with `echo "EXIT:$?"` immediately after the command).
This is exactly the standing exception named in `implementer-common.md` and
the plan: the five `text_ladder_golden_test.dart` goldens, rungs 1 through 5,
`RenderBackend.canvas`, and nothing else. Summary `+911 ~1 -5` is 911 pass + 1
skip + 5 goldens, matching the expected count.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.7s)
```
Exit code: 0. (Because this line uses `;` not `&&`, `flutter analyze` runs
regardless of the golden failures, per the gate line's own design.)

```
$ dart format --output=none --set-exit-if-changed .
Formatted 175 files (0 changed) in 0.32 seconds.
```
Exit code: 0.

### `apps/dev_harness_2d`

```
$ CI=true flutter test --concurrency=1
...
00:19 +82: All tests passed!
```
Exit code: 0. 82 passed -- matches the expected harness count exactly.

```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.05 seconds.
```
Exit code: 0.

### `apps/floor_planner`

```
$ CI=true flutter test
...
00:03 +43: All tests passed!
```
Exit code: 0. 43 passed -- matches the expected app count (up from the
branch-point 26; the new tests come from Tasks 7-9's drawing-tool work).

```
$ flutter analyze
Analyzing floor_planner...
No issues found! (ran in 1.2s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Formatted 12 files (0 changed) in 0.04 seconds.
```
Exit code: 0.

```
$ flutter build macos --release
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.3MB)
```
Exit code: 0. Built successfully.

```
$ flutter build web --release
Compiling lib/main.dart for the Web...                             25.6s
✓ Built build/web
```
Exit code: 0. Built successfully.

`git status --short` printed nothing after every one of the above commands
(checked after each `flutter analyze`/`pub get` step in particular, since
those are the ones that can rewrite `analysis_options.yaml`; none did).

## Branch trailers and commit count (Ruling P-6)

```
$ git rev-list --count 7dac3b5..HEAD
13
$ git log --format=%B 7dac3b5..HEAD | grep -c "Co-Authored-By: Claude"
13
```
13 commits on the branch since the branch point, 13 `Co-Authored-By: Claude`
trailers -- exactly one per commit. `git log --oneline 7dac3b5..HEAD`
confirms the 13 commits: `607bb82`, `b7663b7`, `a5ed921`, `beb892a`,
`0ae93ae`, `9247856`, `26722a5`, `a07ca51`, `b06e908`, `1445f9e`, `c4fcac4`,
`6d98d72`, `5c55000`.

## Files changed

- `docs/superpowers/notes/plan-05-mutation-log.md` -- appended the
  "## Invariants and greps (Task 10)" section with the above.

No other file was touched. `git status --short` before this commit shows
only that one file modified.

## Self-review

- Re-read every pasted block against the raw terminal output before writing
  it into the log; none was retyped from memory.
- Confirmed the `handleSeed` and `Path()` greps against the brief's stated
  expectations (one hit each, at the named locations) and explained why the
  `handleSeed` hit is not a tool allocation, per the dispatch's advance note.
- Confirmed the "engine stays pure Dart" grep's 3 hits are all doc-comment
  prose, not imports, by grepping again without the `wc -l` pipe and reading
  each line; also independently grepped for `import 'package:flutter` and
  `import 'dart:ui'` under `packages/jet_cad_2d/lib` and got no hits (not
  shown above as a separate command since the brief only asked for the exact
  four-command sequence, but it backs the "prose, not violation" claim).
- Verified `git status --short` was clean before starting and stayed clean
  after every gate-line command except the log edit itself.
- Verified the commit-count/trailer check per Ruling P-6 as instructed,
  in place of the plan's original "Opus 5.5" text search.

## Concerns

- None. Every check matches its expected value from the brief and the plan
  exactly; the one standing golden failure is exactly the five named tests
  and nothing else.

## Deviations from the brief's literal code

- None. All commands were run exactly as the brief specifies, with one
  addition (an un-piped re-run of the `package:flutter\|dart:ui` and
  `handleSeed` greps, to see and explain the individual hits behind their
  counts) -- this is additional diagnostic output, not a change to the
  brief's commands.
