# Task 11 report — mutation testing, the two allocation gates, the greps

Branch: `plan-04/page-grid-rulers`, worktree
`/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers`.
Started at HEAD `39c88bd`, committed the log at `ba8d6ac`.

## Tally

23 fired, 0 survived, 0 anchors missing.

- All 22 named mutants (M-04a through M-04v) fired exactly as the spec's
  "Named mutants" table and the two amendments describe.
- The tile-cache twin of M-04r (`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:1876`,
  same edit as M-04r, run against `test/tile_invalidation_test.dart`) also fired.
- M-04c was fired against both `grid_scale_test.dart` and
  `page_chrome_painter_test.dart`'s seeded differential, per the amendment —
  both went red.
- M-04g was fired at `grid_scale.dart:86` against `grid_scale_test.dart`'s
  `minor is null under the minor threshold` test, per Ruling 04-7 and the
  amendment — went red.
- M-04q's mutation (`if (floorMm != null) {` → `if (false) {`) produced a
  compile-time null-safety error rather than a runtime assertion failure
  (the untouched branch body still dereferences `floorMm` as non-nullable
  under the old flow-typing), so the test file failed to load. This is a
  legitimate red — the named test did not pass — and is recorded verbatim
  in the log rather than tweaked to force a runtime assertion.
- Every anchor in `task-11-anchors.md` was found at the exact line stated,
  re-verified with `grep -n` before editing; no drift from 9f08c10.

Full per-mutant detail (production line, exact edit, test command, pasted
failing-test name(s) and the pasted summary line, and the restore
confirmation) is in `docs/superpowers/notes/plan-04-mutation-log.md`.

## Discipline followed

For every mutant: the target file was `cp`-backed up to
`.superpowers/sdd/2026-09-22-page-grid-rulers/mutation-backups/` (created for
this task, never under `lib/`), the one edit was applied by hand, the named
test file was run with `CI=true` (`dart test` for `jet_cad_2d`, `flutter
test` for `jet_cad_2d_flutter` and `apps/floor_planner`), the failing test's
name and the summary line were pasted from the actual run, the file was
restored with `cp` from the backup, and `diff -q` against the backup
confirmed the restore before moving to the next mutant. No `.dart` file was
ever restored with `git checkout --`.

## Four extra checks

### Allocation gate 1 — `jet_cad_2d`
```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: forEachInRect does not allocate in steady state
00:01 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: All tests passed!
EXIT: 0
```

### Allocation gate 2 — `jet_cad_2d_flutter`
```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=65ms
00:00 +3: All tests passed!
EXIT: 0
```

### Untouched-files diff (must be empty)
```
$ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart
(no output)
EXIT: 0
```
Empty, as required — none of these files were touched by Plan 04.

### TileCache diff (one hunk, the D13 skip)
```
$ git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 packages/jet_cad_2d_flutter/lib/src/tile_cache.dart | 8 +++++---
 1 file changed, 5 insertions(+), 3 deletions(-)
EXIT: 0
```

### `dart:ui` grep over the three engine files (must print nothing)
```
$ grep -rn "dart:ui" packages/jet_cad_2d/lib/src/document/page_component.dart packages/jet_cad_2d/lib/src/document/page_geometry.dart packages/jet_cad_2d/lib/src/geometry/grid_scale.dart
(no output)
EXIT: 1
```
`grep` exits 1 on no match, which is the expected result here.

## Working-tree state before commit

`git status --short` showed only `docs/superpowers/notes/plan-04-mutation-log.md`
as untracked before staging; the `mutation-backups/` directory lives under
`.superpowers/sdd/2026-09-22-page-grid-rulers/`, which is git-ignored, so it
never appeared in status. No `analysis_options.yaml` rewrite was observed
after any `flutter test` run in this task, so no `git checkout --` on that
file was needed.

## Commit

`ba8d6ac` — `docs: Plan 04 mutation log — twenty-two named mutants`, trailer
`Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` confirmed via
`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`. Tree clean after the
commit (`git status --short` empty).

## Self-review

- Twenty-two entries plus the tile twin: present (23 `###` mutant sections
  in the log).
- Every entry ends `restored: diff clean` — checked while writing the log,
  each restore was confirmed by an actual `diff -q` call before the next
  mutant was touched.
- Tree clean except the log at commit time: confirmed.
- No synthesized output: every pasted result line above and in the log is
  copied from an actual command run in this session; no transcript was
  fabricated.

## Follow-up — M-04q re-fired with a compiling mutant (Ruling 04-18)

The coordinator flagged that M-04q as originally logged — `grid_scale.dart:61`,
`if (floorMm != null) {` → `if (false) {` — only produced a compile-time
null-safety error (the test file failed to *load*), which is not evidence of
a behavioural kill and must not count as FIRED.

Re-fired with a compiling mutation instead: inside `ladderFor`'s
`if (floorMm != null)` block, the element expression
`floorMm * m * math.pow(10.0, k)` → `m * math.pow(10.0, k)` (the floor is
dropped from the ladder's values; the branch still runs and still returns a
list, so the file compiles).

```
$ cp packages/jet_cad_2d/lib/src/geometry/grid_scale.dart <backup>
$ # edit applied
$ cd packages/jet_cad_2d && CI=true dart test test/geometry/grid_scale_test.dart
00:00 +4: pick imperial divisor is 4 even with a floor
00:00 +4 -1: pick imperial divisor is 4 even with a floor [E]
  Expected: <304.8>
    Actual: <500.0>
00:00 +5 -2: pick a floor is exact when it fits and the ladder climbs from it [E]
  Expected: <250>
    Actual: <500.0>
00:00 +10 -2: Some tests failed.
```
FIRED — `pick a floor is exact when it fits and the ladder climbs from it`
goes red exactly as specified (expects 250 at 0.3 px/mm; the metric values
without the floor give 500), plus `pick imperial divisor is 4 even with a
floor` also failed.

Restored: `cp` from the backup, `diff -q` against it printed nothing (clean).
`git status --short` after the restore was empty.

`docs/superpowers/notes/plan-04-mutation-log.md` was updated in place: the
M-04q section now records this compiling mutation as the counted result,
with the original compile-failure attempt kept immediately below it,
labelled "First attempt failed to compile — not counted; Ruling 04-18," and
its output preserved for the record. The head count stays at 23 fired — this
is a re-fire of the same mutant id, not an addition.

`git status --short` before committing showed only the modified log file.
Committed as `563fdd4` — `docs: mutation log — M-04q re-fired with a
compiling mutant (Ruling 04-18)`, trailer `Co-Authored-By: Claude Fable 5.1
<noreply@anthropic.com>` confirmed via `git log -1 --format=%B | grep -c
"Fable 5.1"` → `1`. Tree clean after the commit.
