# Task 11 report — the device run, the budget, and the exit gate

## What this task did

Scored Plan B's pre-committed exit gate against the device run the human
already performed and handed me (`/tmp/t11-gspike.log`), wrote the results
note, fixed a harness defect the run's own transcript exposed, added a
diagnostic-only counter the brief asked for, updated `STATUS.md`, and ran
the full three-package gate. **Did not re-run the device spike** — read the
log, recomputed every number independently, and did not take any figure on
trust (found the orchestrator's own numbers all checked out against the log,
byte for byte).

## Sequence

1. Read `STATUS.md`, the task-11 brief, the log, `pmset` output (Low Power
   Mode: `0`, off).
2. Read `geometry_collector.dart` and confirmed no collinear-join counter
   existed (`_emitJoin`'s own comment: "No collinearity test here,
   deliberately"). Added `debugCollinearJoins`, a diagnostic-only counter
   mirroring the shader's degenerate predicate in collection-space `double`
   arithmetic, plus two unit tests (a straight-through vertex, an exact
   reversal). `flutter test test/gpu/geometry_collector_test.dart` — 26
   passed.
3. Measured the collinear count off-device: a temporary,
   never-committed test (`apps/dev_harness_2d/test/zz_scratch_collinear_probe_test.dart`,
   deleted before the final commit) rebuilt the exact GSPIKE corpus
   (`ENTITIES=10000 SPIKE_DEFS=20 SPIKE_INSTANCES=150`, harness's default
   1400x900 viewport) through `GeometryCollector` directly and printed
   `instanceCount=109068 skippedOps=0 debugCollinearJoins=0` — the first two
   numbers match the device run exactly, confirming the reconstruction is
   faithful. Zero collinear joins on this corpus: `generateDocument`'s
   entities are rectangles/rotated instances and flattened circles/arcs
   whose chords turn by a constant nonzero angle by construction, so there
   is no source of an exactly-straight three-point run.
4. Found and fixed the harness defect: `apps/dev_harness_2d/lib/gpu_arm.dart`'s
   `GSPIKE note:` line and the file-header comment above it both still said
   arm C "draws only strokes... No joins, no caps, no antialiasing" — false
   after Plan B. Corrected both, keeping what is still true (butt caps only,
   no antialiasing, dash spans baked at collection camera). No test pinned
   the old string (checked with grep), so nothing else needed touching.
5. Committed the code stage (`72b938a`) separately from docs, per the
   working method's "commit in stages."
6. Ran the full three-package gate (`dart test`/`flutter test`,
   `analyze`, `format --set-exit-if-changed`) — all green, transcripts in
   the results note. `git status --short` clean of `analysis_options.yaml`
   at every check.
7. Gathered evidence for all 11 exit-gate criteria by reading the actual
   committed test files and running the relevant suites (not by trusting
   task reports' claims uncritically) — cross-checked against
   `plan-b-mutation-log.md` for criterion 10, against the design spec
   (`2026-08-29-gpu-resident-render-backend-design.md`) for budget numbers,
   and against `task-10-report.md` for the Task 10 Step 2 "3x arm" claim in
   my own brief, which turned out to be imprecise — see below.
8. Wrote `docs/superpowers/notes/2026-08-30-plan-b-results.md`.
9. Updated `STATUS.md`: header, a new `## Plan B` TL;DR section, the
   branch/worktree map, and `## Resume here` (rewritten to lead with "a
   human must still look at the window").
10. Final commit: `docs STATUS.md` only, per the brief's own `git add`
    line.

## A correction to my own brief, found and stated rather than silently
   worked around

The orchestrator's task text said criterion 4's evidence is "the expander's
5x test, and the same corpus compared at 3x in Task 10 Step 2." Reading
`task-10-report.md` directly: Task 10 Step 2's own brief made adding a 3x
arm to the pixel differential *conditional* on M-B10 surviving at the
suite's existing (non-identity, dpr=2.0) comparison. It did not survive —
it died decisively on the first firing (`differing: 95` and `differing:
552`) — so **no 3x arm was added**; a throwaway, never-committed probe at
true identity (`devicePixelRatio: 1.0`) confirmed the mutation would have
been unkillable there, which is what makes the suite's dpr-2.0 default the
thing actually protecting this path. The results note states this
precisely rather than repeating the "3x arm" claim as given.

## Buffer arithmetic discrepancy, noted rather than silently reconciled

Plan A's own historical note (`2026-08-29-gpu-arm-10k-measurement.md`)
records `buffer=2.06 MB` at `segments=59875` with `kFloatsPerInstance=10`.
`59875 × 10 × 4 = 2,395,000` bytes `= 2.28 MiB`, not `2.06 MB`. I did not
find or invent a resolution for this ~10% gap in Plan A's own record — the
results note carries it forward as an open discrepancy rather than
pretending it reconciles. This run's own figure checks out exactly:
`109068 × 12 × 4 = 5,235,264` bytes `= 4.9926 MiB`, matching the harness's
printed `4.99 MB`.

## Concerns / things a reviewer should re-check

- **Criterion 9's decode evidence** (shader bundle OpenGL ES 100 stage) is
  Task 7's byte-pattern check (`#version 100` occurrence count via a Python
  script reading the raw bundle bytes), not a full structured
  flatbuffer/vtable decode the way Plan A's Task 4 reviewer did once for
  the original bundle. I scored criterion 9 PASS on this evidence and said
  so explicitly rather than silently treating it as equivalent rigor.
- **The rebuild MISS's cause is a hypothesis** (cold pipeline creation vs.
  a genuine per-rebuild cost) — I did not attempt to force a second rebuild
  in this session to settle it, since the orchestrator's instructions were
  explicit that the device run is not to be re-run and this harness
  performs exactly one collection per process launch by construction
  (`_buildResidentGeometry` runs once, from `initState`'s post-frame
  callback).
- **The walk-time divergence** (5.7 ms here vs. Plan A's 14.7 ms, same
  nominal corpus size, more instances emitted) is recorded as unexplained.
  I considered and rejected inventing an explanation for it.
- Criterion 11 is scored UNMET as instructed. I did not look at the window
  myself — I have no way to run the macOS app interactively from this
  session, and the instructions were explicit that a human, not an agent,
  is the instrument this criterion requires.

## Final gate transcript

See the results note's own "The final gate, all three packages" section —
pasted verbatim there rather than duplicated here.

---

## Final fix wave

Applied after the whole-branch review found four Important items and one
Minor worth folding into one commit before merge. None changes a byte the
GPU draws.

### I1 — M-B16: `_coveredArgb`'s `lineweightScale` factor had no killing test

`packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart:150-155`.
Every `GeometryCollector` this branch's tests construct for a colour
assertion omits `lineweightScale`, so it defaults to `1.0` and the factor
is the identity everywhere the two existing gates
(`collector_differential_test.dart`, `resident_pixel_differential_test.dart`)
look. `_halfWidthFor` has a dedicated test pinned at
`lineweightScale: 2` (`geometry_collector_test.dart` — `lineweightScale
multiplies the logical width before the clamp`); `_coveredArgb` had none.

**Fix, in order:**

1. `collector_differential_test.dart`'s `_referenceCoveredArgb` gained a
   `lineweightScale` parameter, applied exactly as
   `VerticesDrawSink._coveredArgb` applies its own — the oracle was fixed
   before the new test was written, so a collector that dropped the factor
   and an oracle that never modelled it could not agree for the wrong
   reason.
2. A new test, `collector_differential_test.dart` — `fades a hairline
   stroke by lineweightScale as well as by dpr, not just the identity
   default every other gate in this file exercises`.

   **The arithmetic** (`pixelsPerPaperMm = kLogicalPixelsPerMm =
   3.7795275590551185`, `devicePixelRatio = 2.0` — this file's own
   constant, which `_referenceCoveredArgb` reads directly rather than
   taking dpr as a parameter — `lineweightHundredths = 25`, this file's own
   default lineweight, `lineweightScale = 0.2`):

   - Unscaled device width — what a collector that dropped the factor
     would compute, since removing `lineweightScale *` leaves the
     expression as if the factor were always `1.0` regardless of what was
     configured: `25/100 * 3.7795275590551185 * 2.0 = 1.8897637795275593`
     device px. That is above `kMinStrokeDevicePixels` (1.0), so the
     mutant returns the style's alpha unchanged (255).
   - Scaled device width — correct: `25/100 * 3.7795275590551185 * 0.2 *
     2.0 = 0.37795275590551186` device px. That is below the floor, so the
     correct collector fades: `coverage = (0.37795275590551186 *
     2).clamp(0, 1) = 0.7559055118110237`, `alpha = round(255 *
     0.7559055118110237) = 193` (0xC1).

   The two arms disagree on a non-boundary alpha (255 vs 193, not a
   clamp-to-0-or-255 coincidence), which is what makes the factor
   load-bearing in this fixture rather than incidental.

3. **Fired M-B16** — deleted `lineweightScale *` from `_coveredArgb` only
   (`cp lib/src/gpu/geometry_collector.dart /tmp/geometry_collector.dart.orig.bak`
   taken first):

   ```diff
      int _coveredArgb(int argb, int lineweightHundredths) {
        final deviceWidth = lineweightHundredths /
            100.0 *
            pixelsPerPaperMm *
   -        lineweightScale *
            devicePixelRatio;
   ```

   ```
   $ flutter test test/gpu/collector_differential_test.dart
   00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
   00:00 +1: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor
   00:00 +2: fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises
   00:00 +2 -1: fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises [E]
     Expected: a numeric value within <0.51> of <193.0>
       Actual: <255.0>
        Which:  differs by <62.0>
     a collector that dropped lineweightScale from the fade formula would leave this at 255, not 193

     package:matcher                                     expect
     package:flutter_test/src/widget_tester.dart 473:18  expect
     test/gpu/collector_differential_test.dart 131:5     main.<fn>

   00:00 +2 -1: Some tests failed.
   exit=0
   ```

   (The harness's own process exit is 0 because `flutter test` always exits
   0 for a run it completed; the `-1` in the summary line and the `[E]`
   block are the actual failure signal, matched against the printed
   `Expected`/`Actual` pair above.)

   Confirmed the mutant is invisible to everything else on the branch —
   re-ran both files the finding named:

   ```
   $ flutter test test/gpu/geometry_collector_test.dart
   ...
   00:00 +26: All tests passed!

   $ flutter test test/gpu/resident_pixel_differential_test.dart
   00:00 +0: the resident arm draws the reference drawing
   00:00 +1: the seam join is load-bearing on the circle
   00:00 +2: All tests passed!
   ```

   Both fully green under the mutation — only the new test kills it.

   **Restoration:**

   ```
   $ md5 lib/src/gpu/geometry_collector.dart
   MD5 (lib/src/gpu/geometry_collector.dart) = 19e0d2cfdede8a10c9df2d73f2f04857
   $ cp /tmp/geometry_collector.dart.orig.bak lib/src/gpu/geometry_collector.dart
   $ md5 lib/src/gpu/geometry_collector.dart
   MD5 (lib/src/gpu/geometry_collector.dart) = 690b9f918f55df1da84060b1441c9a83
   ```

   The pre-mutation backup and the post-restore file hash identically
   (`690b9f918f55df1da84060b1441c9a83`); the mutated file's hash
   (`19e0d2cfdede8a10c9df2d73f2f04857`) differs from both, confirming the
   mutation actually changed the file and the restore actually reverted
   it. `git diff lib/src/gpu/geometry_collector.dart` after restoring shows
   only the I2 doc fix below (the `lineweightScale *` line is present,
   unchanged from `HEAD`) — nothing from the mutation survived.

Logged as **M-B16** in `docs/superpowers/notes/plan-b-mutation-log.md`: a
new row in the summary table, the summary paragraph's counts updated
(fifteen named mutants → sixteen, eighteen firings → nineteen, sixteen dead
→ seventeen dead), and a full `## M-B16` section in the file's own format,
inserted after `## M-B15` and before "The instrument's structural blind
spot".

### I2 — `data` getter's doc understated the copy cost by 2.3x

`geometry_collector.dart:69-77`. The doc's parenthetical read `59,875
segments … roughly 2.3 MB … (59,875 × [kFloatsPerInstance] × 4 bytes)`.
`kFloatsPerInstance` is 12 in this plan (it was 10 in Plan A, when the
sentence was written); `59,875 × 12 × 4 = 2,874,000` bytes ≈ 2.74 MiB —
already off from the "2.3 MB" the prose states — and 59,875 was Plan A's
*strokes-only* segment count, not this plan's corpus, which measures
**109,068 instances** (`docs/superpowers/notes/2026-08-30-plan-b-results.md`
— joins roughly doubled the count, and circles/arcs/points are now
collected instead of skipped). Rewrote the doc with this plan's own
figures: `109,068 × 12 × 4 = 5,235,264` bytes ≈ **5.23 MB**, and noted in
passing that the 59,875 in the old text was Plan A's pre-join figure, not
a typo of this plan's own number.

### I3 — a forward reference that came true, left in future tense

`instance_record.dart:68-70` read: `` `test/gpu/resident_pixel_differential_test.dart`
(Task 9, not written yet) is the one that **will** compare the expander's
output against the reference sink pixel for pixel. `` That file has existed
since Task 9. Changed to: `` (Task 9) is the one that compares the
expander's output against the reference sink pixel for pixel. `` — dropped
the now-false "not written yet" and the future tense.

### M5 — the corner-vertex count `6` was unlinked from `kCornerVertices`

`gpu_draw_backend.dart:245` hardcoded `pass.draw(6, ...)`; the same literal
recurred, independently, in `test/support/instance_expander.dart` at the
five sites the finding named (`:44, 86, 87, 106, 227`).

Added `ResidentGeometry.cornerVertexCount` (`resident_geometry.dart`):

```dart
static int get cornerVertexCount =>
    kCornerVertices.length ~/ kFloatsPerCorner;
```

- `gpu_draw_backend.dart`'s draw call now reads
  `pass.draw(ResidentGeometry.cornerVertexCount, instanceCount: ...)`.
- `instance_expander.dart`'s five sites (the `_corners()` generator's
  count, the two buffer-size multiplications, the per-instance vertex loop
  bound, and the flat vertex index `vi`) all now read
  `ResidentGeometry.cornerVertexCount` (or a local `cornerVertexCount`
  captured from it once per call) instead of a literal `6`. Verified no
  bare `6` remains in that file (`grep -n '\b6\b'` — no matches).
- `resident_geometry_test.dart` gained a pinning test, `cornerVertexCount
  is derived from the table, and equals six`, asserting both the concrete
  value and the `kCornerVertices.length ~/ kFloatsPerCorner` relationship
  itself — so a future seventh corner (Plans C/D) moves this assertion
  from 6 to 7 instead of leaving the draw call silently one vertex short.

### Full gate

```
$ cd packages/jet_cad_2d_flutter && flutter test; echo "TEST_EXIT=$?"
...
00:08 +479: All tests passed!
TEST_EXIT=0

$ flutter analyze; echo "ANALYZE_EXIT=$?"
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
ANALYZE_EXIT=0

$ dart format --output=none --set-exit-if-changed .; echo "FORMAT_EXIT=$?"
Formatted 89 files (0 changed) in 0.16 seconds.
FORMAT_EXIT=0
```

(`dart format` initially reported `Formatted 89 files (2 changed)` —
`resident_geometry.dart` and `collector_differential_test.dart`, both new
code from this wave — and was re-run to apply the formatting before the
gate above, which is the clean, post-format run.)

`apps/dev_harness_2d` was not touched by this wave, so its gate was not
run. `packages/jet_cad_2d` was not touched. `git status` before staging
showed no `analysis_options.yaml`.

### Files changed

```
docs/superpowers/notes/plan-b-mutation-log.md
packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart
packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart
packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart
packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart
packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart
packages/jet_cad_2d_flutter/test/support/instance_expander.dart
```
