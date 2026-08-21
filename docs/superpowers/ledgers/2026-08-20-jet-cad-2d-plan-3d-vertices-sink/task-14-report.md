# Task 14 report — the mutation log

Executed by the controller directly (no subagent dispatched, per the brief).

## What was done

Read the task brief, `progress.md` (all 13 prior tasks' entries), the design
document's mutant table (spec lines 440-460), the spike's own note
(`docs/superpowers/notes/2026-08-20-vertices-sink-spike.md`), and Plan 3c's
mutation log as the model to follow.

Discovered that the code carries fifty-three `// MUTATION:` comments across
five test files, most inherited verbatim from the spike and extended by
Tasks 2, 4, 5, 6, 8 and 9 as they touched `vertices_draw_sink.dart`,
`vertices_join_test.dart`, `point_shape_test.dart` and
`render_backend_test.dart`. That is the concrete, checkable trace of "the
spike's 33" — the spike's own note gives only an aggregate tally (33/32/1),
with no surviving per-mutant diff to replay (the runner that produced it was
session-local and never committed) — so this task ran the comments for real
against today's code rather than assert the historical count.

Wrote a backup-based Python runner, `scratchpad/mutate14.py` (session-local,
not committed): copies the target file aside, applies the edit, runs the
narrowest test file, restores from the copy in a `finally` block. **`git
checkout` was never used to revert anything in this task.** `git status
--porcelain` was read after every run and confirmed clean except for the
three intentional, non-mutation edits this task keeps.

Constructed and ran 34 mutation-test cycles (12 covering the design
document's 14 named mutants — `J1`-`J9`, `B1`, `B2`, `A1`, `V1`, `P1` — plus
22 more for the spike-heritage set), which collapse to 33 distinct mutations
once one duplicate pair (`S15`/`S17b`, the same code line under two names) is
merged. Two survivors surfaced (`A1`: the `Paint` object's lifetime has no
test that can see it; `S2`: the historic colour-reordering bug has no test
that reads what `flush()` actually submits, only the pre-flush buffer, which
is always correct by construction). Both are closed with a new/extended test,
re-run against the widened suite, and confirmed killed. Two mutations are
cited from the codebase's own "confirmed empirically" record (Task 2's
dispose-order swap, Task 8's unfalsifiable observer-timing window) rather
than re-run, and two are recorded as not independently reproducible with the
reasoning given (no discrete local-space code path exists in either the width
or the join math to mutate — both were removed by construction when the sink
was built to transform points before computing geometry).

Wrote `docs/superpowers/notes/plan-3d-mutation-log.md`, modelled on
`docs/superpowers/notes/plan-3c-mutation-log.md`'s two-part shape (a named
table, run fresh; a larger inherited set, run fresh) with a tally table, full
per-mutant killer/assertion detail, the two closed survivors' before/after
transcripts, the two cited mutations with their sourcing, the two
not-independently-reproducible entries with their reasoning, and a note on
what this log does not cover (the seam join, `P1`, `J5`, `J8`, `J9` have no
coverage through any frame path — Task 11's finding, restated so a reader of
this log does not assume otherwise).

## Mutants: total, killed, survived, not applicable

- **39 mutants accounted for.**
- **34 killed** (32 outright, plus `A1` and `S2` after a fix round each).
- **0 survived unresolved.**
- **1 recorded as a deliberate control**, confirming a documented
  layered-guard property rather than an open gap (`E20_one`).
- **2 cited** from the codebase's own confirmed-empirical record, not
  independently re-run (Task 2's dispose-order swap; Task 8's
  observer-timing window).
- **2 recorded as not independently reproducible**, with the reason given
  (no discrete code path to mutate — the width and join math both operate
  purely in already-transformed device space, by construction).
- **0 not applicable** in the "no site exists" sense Plan 3c's `S10` used;
  every mutant named in this task's scope has a real site.

Of the 34 mutations run as fresh executions in this task (before the
`S15`/`S17b` merge), all were re-run at least once (twice for `A1` and `S2`,
once before and once after the fix); none of the results are taken from a
report's transcript without independent verification, except the two cited
entries above, which name their source explicitly.

## Every survivor and what was done

- **`A1` — allocate the `Paint` per flush instead of once for the sink's
  life.** `paint_allocation_test.dart` measures buffer capacity only; a
  `Paint` object is not part of either buffer, so a fresh one per flush was
  invisible to it. **Closed**: added `VerticesDrawSink.debugPaint` (a getter
  exposing `_paint`), and pinned its identity across the subject frame in
  `paint_allocation_test.dart`. Re-run: killed, `identical` reads false.
- **`S2` — group the vertices by colour before flushing.** The existing test
  (`'draw order survives batching'`) reads `debugColors()` before any
  `flush()` runs, so it can only ever see emission order, which is correct
  by construction and cannot observe a reorder introduced inside `flush()`
  itself — exactly where the sink's real, historic bug lived. **Closed**:
  added `'draw order survives the flush itself, not just the pre-flush
  buffer'`, which attaches `sink.observer` and reads the colours actually
  submitted. Re-run: killed, order comes back green/red/red instead of
  red/green/red.

No other survivor was left open. `E20_one` is not a survivor needing
closure — it is a deliberate single-bail control, already predicted and
explained by the test file's own comment, re-run here to verify the claim
rather than take it on faith.

## `// MUTATION:` comments checked against what actually happens

Every comment this task turned into a real mutation was checked against the
observed assertion, not assumed correct. All matched. Two are worth naming
because their prior review history already flagged and fixed exactly this
class of problem: `J7`'s comment (line ~131 of `vertices_join_test.dart`)
was rewritten in Task 4's fix round from "drop the bevel triangle" (a
count-only defect) to "swap the bevel triangle's two outer corners for the
inner ones" (a geometric defect that survives the count check) — this task
re-ran the corrected version and confirmed it dies on the geometric probe,
not a count, exactly as the comment now claims. No new incorrect comment was
found in this task's run.

## Full three-package gate

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
00:02 +720: All tests passed!
Analyzing jet_cad_2d... No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
00:02 +237 ~1: All tests passed!
Analyzing jet_cad_2d_flutter... No issues found! (ran in 0.9s)
Formatted 44 files (0 changed) in 0.05 seconds.

$ cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
Analyzing dev_harness_2d... No issues found! (ran in 0.8s)
Formatted 3 files (0 changed) in 0.01 seconds.
```

`jet_cad_2d` unchanged at 720 (this task touches no file in that package).
`jet_cad_2d_flutter` moved from 236 passed / 1 skipped to **237 passed / 1
skipped** — the `S2`-closing test is the one net new test; the `A1`-closing
assertion extends an existing test rather than adding one.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — added
  `Paint get debugPaint => _paint;`. No behaviour change.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` —
  pins `debugPaint`'s identity across the subject frame.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — one new
  test pinning flush-time colour order via the observer.
- `docs/superpowers/notes/plan-3d-mutation-log.md` — new, this task's
  deliverable.

`analysis_options.yaml` untouched in all three packages, confirmed by
`git status --porcelain` before commit.

## Concerns

- The design document's `B1` ("resolve the backend per call site rather than
  once") has no literal single-line mutation to apply — `defaultRenderBackend()`
  is a pure, unconditional function with exactly one call site
  (`draft_canvas.dart`'s `_attach()`), so "a second call site deciding
  independently" is not a line that exists to mutate. The log uses the
  architecturally equivalent proxy the design document's own reasoning names
  (a stale cache from `didUpdateWidget`'s comparison missing `backend`) and
  explains the equivalence; a stricter reviewer might want this called out
  more prominently than a table cell.
- "The spike's 33" is represented by 21 distinct mutations in Part 2 plus the
  12 mutation-runs covering Part 1's 14 named mutants (33 total runs) — a
  numeric match to the spike's own tally that is coincidental, not
  engineered, and the log says so plainly rather than let a reader assume
  this task replayed the spike's original 33 diffs (which do not exist to
  replay).
- Two mutations (`S1`: local-space perpendicular for stroke width; the
  local-space join equivalent) are recorded as not independently
  reproducible because no discrete code path exists to invert — reaching them
  would mean writing new parallel geometry code, not mutating an existing
  line. This is argued from reading the source (`polyline` transforms every
  point before any direction/normal math runs) rather than from a prior
  task's citation, since neither concern is Plan 3d table's own named row (`S1`
  and the join equivalent are both spike-heritage comments, not `J`/`B`/`A`/`V`/`P`
  rows), so this reasoning has not been independently reviewed before.

## Report

Full detail, including every table and every survivor's before/after
transcript, is in `docs/superpowers/notes/plan-3d-mutation-log.md`.

---

## Fix round 1 (post-review)

Three Important findings, all addressed. Real transcripts below for
everything re-run; nothing in this section is synthesized.

### 1 — `A1` closed too narrowly

Reproduced the reviewer's wider mutation myself before touching anything:

```
$ cp lib/src/vertices_draw_sink.dart /tmp/vds_backup.dart
$ python3 - <<'EOF'
[... replaces canvas.drawVertices(vertices, BlendMode.dst, _paint) with
     canvas.drawVertices(vertices, BlendMode.dst,
       Paint()..color = const Color(0xFFFFFFFF)) ...]
EOF
$ flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: All tests passed!
$ flutter test
00:02 +237 ~1: All tests passed!
$ cp /tmp/vds_backup.dart lib/src/vertices_draw_sink.dart
```

Confirmed: the round-1 `debugPaint`-identity test and the entire suite both
stay green under this mutation, exactly as the reviewer found. `debugPaint`
reads the `_paint` field, and the field genuinely never changes when a fresh,
call-site-local `Paint` is passed straight to `drawVertices` instead.

Closed by adding a second test to `paint_allocation_test.dart`, using
`test/support/spy_canvas.dart` (already in the tree) to read the actual
`Paint` object `canvas.drawVertices` receives across two flushes, and
pinning `identical()` on that:

```
$ flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: All tests passed!
```

Re-ran the reviewer's exact mutation against the widened file and the full
suite:

```
$ cp lib/src/vertices_draw_sink.dart /tmp/vds_backup2.dart
$ python3 - <<'EOF'
[... same mutation as above ...]
EOF
$ flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +1 -1: flush hands drawVertices the same Paint object every time, not a call-site-local one [E]
  Expected: true
    Actual: <false>
  flush() must hand drawVertices the one Paint built for the sink's life, not a fresh one per call
00:00 +1 -1: Some tests failed.
$ flutter test
00:02 +237 ~1 -1: Some tests failed.
Failing tests:
  test/invariants/paint_allocation_test.dart: flush hands drawVertices the same Paint object every time, not a call-site-local one
$ cp /tmp/vds_backup2.dart lib/src/vertices_draw_sink.dart
$ git status --porcelain lib/src/vertices_draw_sink.dart   # empty
```

Killed, on the new assertion specifically, everything else (round-1 test
included) staying green. `A1` genuinely closed now.

### 2 — `B1`'s row named one mutation and ran another, silently

No code change; the equivalence argument was already sound (reviewer
confirmed it). Added an explanatory note directly under Part 1's table
(`### B1 — what was actually run, and why it stands in for the tabled
mutant`) stating: `B1`'s literal mutation has no line to invert
(`defaultRenderBackend()` is pure and unconditional with one call site);
what was actually run is the stale-cache proxy (dropping `backend` from
`didUpdateWidget`'s comparison); why that is a defensible substitution for
the same failure mode the design document names; and that the design
document's own stated fixture (reading the backend back from both the widget
and the rig) does not exist as a test anywhere in this suite.

### 3 — two unreachable branches counted as guarded

Re-confirmed both, in isolation, against the *full* suite (not just the
14-test join file) rather than trust the prior narrower run:

```
$ cp lib/src/vertices_draw_sink.dart /tmp/vds_b3.dart
$ sed -i '' 's/    if (mlen == 0) return;/    if (false \&\& mlen == 0) return;/' lib/src/vertices_draw_sink.dart
$ flutter test
00:02 +238 ~1: All tests passed!
$ cp /tmp/vds_b3.dart lib/src/vertices_draw_sink.dart

$ cp lib/src/vertices_draw_sink.dart /tmp/vds_b4.dart
$ sed -i '' 's/    if (cosHalf <= 0) return;/    if (false \&\& cosHalf <= 0) return;/' lib/src/vertices_draw_sink.dart
$ flutter test
00:02 +238 ~1: All tests passed!
$ cp /tmp/vds_b4.dart lib/src/vertices_draw_sink.dart
$ git status --porcelain lib/src/vertices_draw_sink.dart   # empty
```

Both confirmed unreachable given the `dot < kMinMiterCosine` bail
(`progress.md:68`), against the whole suite. Moved out of the `E20_one`
"control" narrative (which is specifically and only about `cross == 0`'s
redundancy with `dot < kMinMiterCosine` for one fixture — that framing was
correct and is kept) into a new section, "Two branches recorded as
unreachable, not guarded," and added to the log's tally as a new category
(2 more items, `41` total accounted for, up from `39`) rather than folded
silently into a kill count.

### Three smaller corrections, also verified before writing

- **`S2`'s residual gap.** Verified the reviewer's claim myself: grouping by
  colour *after* `observer?.call(positions, colors)` and before
  `Vertices.raw(...)` survives the new `S2`-closing test and the full
  238-test suite.
  ```
  $ cp lib/src/vertices_draw_sink.dart /tmp/vds_s2check.dart
  $ python3 - <<'EOF'
  [... inserts colour-grouping between observer?.call and Vertices.raw ...]
  EOF
  $ flutter test test/vertices_draw_sink_test.dart
  00:00 +31: the observer fires once per flush, text included
  00:00 +32: All tests passed!
  $ flutter test
  00:02 +238 ~1: All tests passed!
  $ cp /tmp/vds_s2check.dart lib/src/vertices_draw_sink.dart
  ```
  Reworded the log to say precisely what the new test constrains (the
  observer's view, not `Vertices.raw`'s own argument) and recorded this
  narrower residual gap explicitly rather than leave the overclaim standing.
- **Headline arithmetic.** Fixed "twenty-two kills" to "twenty" (34 named+spike
  kills minus 14 named = 20), and reconciled Part 2's heading (now "21,
  after one duplicate merge") against the "21 rows" text below it — the
  heading previously stated the Part 1+2 combined total (33) as if it were
  Part 2's own count.
- **The seam gap's reason.** Rewrote "What this does not cover" to
  distinguish `J9` (genuinely unreachable — `closed:` is `false` at every
  `polyline` call site) from `J8` (reachable — the painter does call
  `sink.circle` with an implicit closed seam, `draft_painter.dart:588`,
  `:619` — but unobserved by any test that reads the buffer through that
  path), per `progress.md:122`.

### On "the spike's 33"

Rewrote the verdict paragraph and the "what this means" note to state the
substitution once, plainly: the spike's original diffs are unrecoverable,
Part 2 runs 21 mutations drawn from the inherited suite's own `// MUTATION:`
comments (a mix of spike heritage and later tasks' additions to the same
suite, not spike-only), and the 33-cycle total across both parts is reported
once rather than repeated as a "coincidence" three times.

### Gate after the fix round

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
00:02 +720: All tests passed!
Analyzing jet_cad_2d... No issues found!
Formatted 105 files (0 changed) in 0.13 seconds.

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
00:02 +238 ~1: All tests passed!
Analyzing jet_cad_2d_flutter... No issues found! (ran in 0.7s)
Formatted 44 files (0 changed) in 0.05 seconds.

$ cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
Analyzing dev_harness_2d... No issues found! (ran in 0.8s)
Formatted 3 files (0 changed) in 0.01 seconds.
```

`jet_cad_2d_flutter` moved from 237 passed / 1 skipped to **238** passed / 1
skipped (one net new test, `A1`'s round-2 `SpyCanvas` check).

### Files changed in this fix round

- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart` —
  added the `SpyCanvas`-based test that closes `A1` for real; corrected the
  round-1 `MUTATION` comment to state its own narrower scope.
- `docs/superpowers/notes/plan-3d-mutation-log.md` — all three Important
  findings and the three smaller corrections addressed as described above.

`lib/src/vertices_draw_sink.dart` carries no diff from this fix round — every
mutation re-run in it was backed up, applied, tested and restored, confirmed
by `git status --porcelain` after each one.
