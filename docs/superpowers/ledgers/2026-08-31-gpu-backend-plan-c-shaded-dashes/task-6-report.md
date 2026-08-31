# Task 6 report: the collector shades a dashed circle and arc

Branch: `plan-c/shaded-dashes`.

## What changed and why

`lib/src/gpu/geometry_collector.dart` — `_flatten`:

- Threaded the phase law from the brief's Step 3 through the chord loop:
  `arcStep = r * step.abs()` (local arc length per chord), and for each chord
  while `_dashActive`, `factor = |chord in collection space| / arcStep`,
  `_pendingSegPeriod = _dashPeriodLocal * factor`, and
  `_pendingSegPhase = ((arcStep * (i - 1)) % _dashPeriodLocal) * factor` —
  parenthesised explicitly per the brief's own instruction, so the reduction
  happens before the scaling regardless of how a reader parses `%`/`*`
  precedence. `_pendingJoinPeriod`/`_pendingJoinPhase` mirror the segment's
  values, since the join at a chord's start vertex takes that chord's own
  phase and factor.
- **Found and fixed a real bug in the brief's literal Step 3 code before
  committing it.** The brief's snippet sets `_suppressJoins = true` right
  before calling `_endRun(...)`. `_endRun`'s first action is its own
  `_runTo(_runFirstX, _runFirstY, ...)` call for the closing chord, and
  `_runTo`'s join guard (`if (_runHasDirection && !_suppressJoins)`) honours
  that same flag — so setting `_suppressJoins` before `_endRun` doesn't just
  suppress the seam, it also suppresses the **interior** join at the vertex
  the closing chord starts from. That join is explicitly required to survive
  by the brief's own requirement 1 ("Interior chord joins are still
  emitted... because the reference does chord and join *within* a span").
  Measured with a scratch script before touching the real tests: a 40-radius
  dashed circle (`dashed`, `patternToLocal 0.5`, identity residual, 29
  chords) produced **27** joins under the brief's literal code, not the
  expected 28 (`steps - 1` interior joins, no seam) — one too few, and the
  solid circle's own 29-join count (28 interior + 1 seam) confirmed the
  arithmetic.

  Fix: added a `suppressSeam` parameter to `_endRun`, independent of
  `_suppressJoins`, that gates *only* the explicit closing `_emitJoin` call —
  not the `_runTo` call two lines above it. `_flatten` now leaves
  `_suppressJoins` false for the whole arc/circle walk (interior joins,
  including the one before the closing chord, are never touched) and passes
  `suppressSeam: _dashActive` to `_endRun`. Re-measured after the fix: 28
  joins for the dashed circle, 29 for solid — the required "chords − 1, no
  seam" relationship, confirmed independently by the debug script and then by
  the real test (`a dashed circle emits no seam join`, passing green below).
  `_suppressJoins` itself keeps its old all-joins-off meaning for dashed
  **polylines** (Task 5), which is unaffected — `polyline` never touches
  `suppressSeam` and its own `_suppressJoins = _dashActive` still suppresses
  every join there, seam included, exactly as before.
- `_flatten` resets `_pendingSegPeriod`/`_pendingSegPhase`/
  `_pendingJoinPeriod`/`_pendingJoinPhase` to 0 at the end, mirroring
  `polyline`'s own cleanup — `_flatten` can run again for the next primitive
  inside the same dash bracket.

`test/gpu/geometry_collector_test.dart` — appended the brief's six-test block
under a new `-- dashed circles and arcs (Task 6) --` section, filling in
every placeholder comment against real assertions, and added two small
helpers (`_joinCount`/`_strokeCount`, via a shared `_countKind`) next to the
existing `_kindAt`:

1. **Running phase.** `arc(0,0,40,0,1.2)` under `beginDash(dashed, 0.5)` and a
   pure translation residual. Recomputed the expected per-chord advance from
   the reference's own flattening formula (`VerticesDrawSink.kFlattenTolerance`/
   `kMaxFlattenSegments`, the same constants the existing circle/arc tests
   already use) rather than hardcoding step count — and, notably, the
   expected advance is `2r·sin(step/2)` (the **chord** length), not `r·step`
   (the **local arc** length): under a translation-only residual (scale
   magnitude 1) every chord of a constant-angular-step circular arc has the
   *same* chord length, so `factor` is constant across chords and the phase
   delta collapses to exactly that chord length, not the arc length. Verified
   `arcStep - chordLen < 0.1` (Ruling C4's own stated bound) as a sanity
   check alongside the running-phase assertion.
2. **No seam join on a dashed circle** — `joinCount(dashed) == joinCount(solid) - 1`.
   This is the test that caught the `_endRun`/`suppressSeam` bug above.
3. **Solid circle still has its seam** — guards against "no joins at all"
   passing test 2 vacuously.
4. **Chord count is linetype-independent** — `dashDot` (D == 2) on an arc:
   `strokeCount(dashed) ~/ 2 == strokeCount(solid)`.
5. **Anisotropic per-chord factor** (brief's verbatim fixture) —
   `Transform2.scale(3.0, 1.0)`, `arc(0, 0, 40, 0, math.pi)`: the max/min
   period ratio across all stroke instances is close to `3.0`, which
   `_residual.scaleMagnitude` (`sqrt(3.0 * 1.0) ≈ 1.732`, collapsing to a
   ratio of `1.0` for every chord) cannot produce. This is the test the brief
   flags as load-bearing specifically because an isotropic scale can't
   distinguish the per-chord factor from that getter.
6. **Phase reduced into `[0, period)`** — a full dashed circle (period 9.0
   against a ~251-unit circumference, ~28 wraps) asserts every stroke's phase
   stays within its own period.

## Commands run, verbatim

### `flutter test test/gpu/geometry_collector_test.dart` (targeted)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
...
00:00 +43: the phase is reduced into [0, period) at collection
00:00 +44: All tests passed!
```
Exit code: 0. 44 tests (38 pre-existing + 6 new), all green.

### `flutter test` (whole package)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +509 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +510 ~1: All tests passed!
```
Exit code: 0. 510 passed, 1 skipped (pre-existing skip, unrelated to this
task), 0 failed.

### `flutter analyze`

```
$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit code: 0.

### `dart format --output=none --set-exit-if-changed .`

First run (before formatting the two edited files) printed:
```
Changed lib/src/gpu/geometry_collector.dart
Changed test/gpu/geometry_collector_test.dart
Formatted 89 files (2 changed) in 0.17 seconds.
```
Exit code: 1 — a real failure, not ignored. Ran `dart format` (no
`--set-exit-if-changed`) on the two files to actually apply formatting, then
re-ran the check:
```
$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.17 seconds.
```
Exit code: 0.

`git status --short` before every commit showed only the two intended files
— `analysis_options.yaml` was never touched.

## Mutation-kill transcripts

Both mutations were applied to the **committed, formatted, all-green**
version of `geometry_collector.dart`, backed up first with `cp` (not `git
checkout --`) to
`/private/tmp/claude-501/.../scratchpad/geometry_collector.dart.bak`, restored
the same way afterward, and confirmed byte-identical to the backup with
`diff` post-restore.

### Mutation 1 — running-phase test (reduce after scaling instead of before)

Backup:
```
$ cp lib/src/gpu/geometry_collector.dart /private/tmp/.../scratchpad/geometry_collector.dart.bak
```

Mutation (violates requirement 3 — reduces by the wrong modulus, after
scaling by `factor` instead of before):
```diff
-        _pendingSegPhase = ((arcStep * (i - 1)) % _dashPeriodLocal) * factor;
+        _pendingSegPhase = (arcStep * (i - 1) * factor) % _dashPeriodLocal;
```

Run:
```
$ flutter test test/gpu/geometry_collector_test.dart --plain-name "a dashed arc carries a running phase"
00:00 +0: a dashed arc carries a running phase, and consecutive chords advance it by one chord of arc length
00:00 +0 -1: a dashed arc carries a running phase, and consecutive chords advance it by one chord of arc length [E]
  Expected: a numeric value within <0.001> of <7.9866733317462515>
    Actual: <7.971680641174316>
     Which:  differs by <0.014992690571935086>
  a constant advance is what "running" means; a phase that restarts per chord is dasher.dart's polyline rule applied to a curve, which is the spec's own named mutation
...
00:00 +0 -1: Some tests failed.
```
Killed. Exit code: 1.

Restore:
```
$ cp /private/tmp/.../scratchpad/geometry_collector.dart.bak lib/src/gpu/geometry_collector.dart
$ flutter test test/gpu/geometry_collector_test.dart --plain-name "a dashed arc carries a running phase"
00:00 +0: a dashed arc carries a running phase, and consecutive chords advance it by one chord of arc length
00:00 +1: All tests passed!
```
Green again. Exit code: 0.

### Mutation 2 — anisotropic per-chord-factor test (scaleMagnitude substitution)

Mutation (the exact substitution the brief names as the plausible edit):
```diff
-        final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
+        final factor = t.scaleMagnitude;
```

Run:
```
$ flutter test test/gpu/geometry_collector_test.dart --plain-name "an anisotropic residual scales each chord"
00:00 +0: an anisotropic residual scales each chord's period by that chord's own ratio, not by one number for the whole arc
00:00 +0 -1: an anisotropic residual scales each chord's period by that chord's own ratio, not by one number for the whole arc [E]
  Expected: a numeric value within <0.1> of <3.0>
    Actual: <1.0>
     Which:  differs by <2.0>
  a chord along x is stretched 3x and a chord along y is not; one period for the whole arc would read 1.0 here and would be the scaleMagnitude approximation this fixture exists to reject
...
00:00 +0 -1: Some tests failed.
```
Killed exactly as predicted — the ratio collapses to `1.0`. Exit code: 1.

Restore:
```
$ cp /private/tmp/.../scratchpad/geometry_collector.dart.bak lib/src/gpu/geometry_collector.dart
$ diff /private/tmp/.../scratchpad/geometry_collector.dart.bak lib/src/gpu/geometry_collector.dart && echo "IDENTICAL - restore confirmed"
IDENTICAL - restore confirmed
```

Re-ran the full targeted suite green after both restores (see the 44/44 run
above, which was captured after this point).

## What the brief got wrong

**Step 3's literal code drops one interior join it shouldn't.** Setting
`_suppressJoins = true` immediately before calling `_endRun(...)` suppresses
not only the seam (the intent) but also the interior join `_endRun`'s own
`_runTo` call emits for the closing chord's starting vertex, because that
`_runTo` call checks the same `_suppressJoins` flag. This is a second,
narrower join-suppression than requirement 1 calls for ("Interior chord
joins are still emitted"). I did not commit the brief's literal code; I
added a `suppressSeam` parameter to `_endRun` (see above) so the seam is
suppressed without touching that interior join, and the new "a dashed circle
emits no seam join" test (which compares exact join counts against a solid
circle, not just "some joins exist") is the one that caught it — a looser
test (e.g. only checking `joinCount(dashed) < joinCount(solid)`) would have
passed on the buggy code too.

Everything else in the brief — the phase law, the `factor` definition
(divide by local arc length), the parenthesization requirement, the named
patterns (`dashed`, `dashDot`, `allGap`) — matched what the code needed
verbatim.
