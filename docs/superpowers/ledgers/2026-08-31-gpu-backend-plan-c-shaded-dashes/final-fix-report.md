# Plan C whole-branch review — fix wave

Branch `plan-c/shaded-dashes`, starting commit `83810b3`. Six findings,
committed in stages as each went green:

| commit | finding(s) |
|---|---|
| `a04259a` | 1 |
| `895604b` | 2 |
| `70ba26d` | 3, 4 |
| `66c8022` | 5 |
| `f703239` | 6 |

---

## Finding 1 — a dashed circle's closing chord carries the PREVIOUS chord's phase

**Change.** `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`,
`_flatten`. The chord loop stops at `last = steps - 1` for a closed sweep and
never assigns `_pendingSegPeriod` / `_pendingSegPhase` / `_pendingJoinPeriod`
/ `_pendingJoinPhase` for the closing chord (chord `steps`, drawn by
`_endRun`'s own `_runTo` call). Added an assignment immediately before the
`_endRun` call, guarded by `_dashActive && closed && arcStep > 0`, using the
same phase law the loop uses, evaluated for chord `steps`:

```dart
if (_dashActive && closed && arcStep > 0) {
  final cdx = _runFirstX - px, cdy = _runFirstY - py;
  final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
  _pendingSegPeriod = _dashPeriodLocal * factor;
  _pendingSegPhase = ((arcStep * (steps - 1)) % _dashPeriodLocal) * factor;
  _pendingJoinPeriod = _pendingSegPeriod;
  _pendingJoinPhase = _pendingSegPhase;
}
```

`px, py` is the loop's last point (`steps - 1`); `_runFirstX, _runFirstY` is
point `0`. Same explicit parenthesisation as the loop.

**Test added.** `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`,
`'a dashed circle carries a running phase all the way through its closing
chord -- the pair the loop never assigns'`. Asserts a constant phase advance
between every adjacent chord pair for a **closed** circle (r=65, `dashed`
pattern, `patternToLocal=1.7`), including the pair the defect corrupts
(chord `steps - 1` → the closing chord). The wrap from the closing chord back
to chord one is deliberately *not* asserted — a circle's circumference is not
generally an exact multiple of the dash period, so that one seam has a
genuine, expected discontinuity; asserting it produced a false failure during
development (delta 0.7366 vs. expected 11.33) which is why the loop bound is
`phases.length - 1`, not a modulo wrap.

**Kill demonstrated, red first:**

```
$ cd packages/jet_cad_2d_flutter && git stash push -- lib/src/gpu/geometry_collector.dart
$ flutter test test/gpu/geometry_collector_test.dart --plain-name "closing chord back to chord one"
...
00:00 +0: a dashed circle carries a running phase all the way through its closing chord -- the pair the loop never assigns
00:00 +0 -1: a dashed circle carries a running phase all the way through its closing chord -- the pair the loop never assigns [E]
  Expected: a numeric value within <0.001> of <11.330246557195562>
    Actual: <0.0>
     Which:  differs by <11.330246557195562>
  chord 34 to chord 35 must advance by the same one-chord step everywhere, including into the closing chord at the very end of this list; a stale phase left behind on the closing chord shows up as a near-zero (or doubled) delta at exactly that one pair
...
00:00 +0 -1: Some tests failed.
```

This matches the reviewer's live measurement exactly: 36 chords, delta 0.0 at
the last pair where 11.33 was expected everywhere else.

**Green after the fix:**

```
$ git stash pop
$ flutter test test/gpu/geometry_collector_test.dart --plain-name "closing chord"
00:00 +0: a dashed circle carries a running phase all the way through its closing chord -- the pair the loop never assigns
00:00 +1: All tests passed!
```

Full file, `dart analyze`, `dart format --set-exit-if-changed`: all clean
(see "End-of-branch gates" below).

---

## Finding 2 — `style.linetypeScale` is a deletable multiplicand

**Change.** No production code changed (the multiplicand was already correct
at all five sites — `draft_painter.dart:663, 803, 829, 858, 875`); the gap
was that no test in the package pinned `linetypeScale` away from `1.0`.

- `packages/jet_cad_2d_flutter/test/draft_painter_test.dart`: `dashedFixture`
  gained a `linetypeScale` parameter (default `1.0`, unaffected for every
  other caller). `'a shading sink is handed the undashed polyline inside a
  bracket, and the bracket carries the painter's own dash scale'` now builds
  the fixture with `linetypeScale: 2.5`, and the arithmetic-identity
  assertion's `expected` computation uses `2.5 *` instead of `1.0 *`.
- `packages/jet_cad_2d_flutter/test/support/fixtures_test.dart`: added a
  fifth non-degeneracy check beside the existing `globalLinetypeScale` one —
  `shadedDashFixture(linetypeScale: 2.5)`'s entity 913 record actually
  carries `linetypeScale: 2.5` (via `doc.entities.slotOf`/`.read`). This
  affordance existed in `fixtures.dart` already but nothing called it with a
  non-default value.

**Kill demonstrated by hand, on `_dashScale` specifically (as instructed),
red first:**

```
$ cd packages/jet_cad_2d_flutter
$ cp lib/src/draft_painter.dart /tmp/.../draft_painter.dart.bak
```

Edited `_dashScale` to:
```dart
double _dashScale(ResolvedStyle style, Transform2 toScreen) =>
    document.header.globalLinetypeScale *
    toScreen.scaleMagnitude;
```

```
$ flutter test test/draft_painter_test.dart --plain-name "carries the painter's own dash scale"
00:00 +0: a shading sink is handed the undashed polyline inside a bracket, and the bracket carries the painter's own dash scale
00:00 +0 -1: a shading sink is handed the undashed polyline inside a bracket, and the bracket carries the painter's own dash scale [E]
  Expected: a numeric value within <1e-9> of <5.0>
    Actual: <2.0>
     Which:  differs by <3.0>
...
00:00 +0 -1: Some tests failed.
```

**Restored from the `cp` backup (never `git checkout --`), green again:**

```
$ cp /tmp/.../draft_painter.dart.bak lib/src/draft_painter.dart
$ git diff --stat lib/src/draft_painter.dart      # empty -- confirmed clean restore
$ flutter test test/draft_painter_test.dart --plain-name "carries the painter's own dash scale"
00:00 +0: a shading sink is handed the undashed polyline inside a bracket, and the bracket carries the painter's own dash scale
00:00 +1: All tests passed!
```

`dart analyze`, `dart format --set-exit-if-changed` on the two changed test
files: clean. Full `draft_painter_test.dart` + `fixtures_test.dart` run: 16
passed, 0 failed.

---

## Finding 3 — stale camera-invariance comment

**Change.** `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:622-626`
(the `sink.shadesDashes` branch inside the polyline-drawing path). Replaced
the claim that handing a shading sink spans "would freeze the dash count at
whatever camera this walk ran under" with the corrected framing: the dash
count is camera-invariant (`_dashScale` folds in `toScreen.scaleMagnitude`,
points are already in screen space, so period and distance scale together —
measured three ways in
`docs/superpowers/notes/2026-08-31-plan-c-results.md`); what baking spans
would actually freeze is the **collapse** decision, since `kDashCollapsePx`
is a screen-space threshold. Wording matches `apps/dev_harness_2d/lib/gpu_arm.dart:31-60`,
which already carries the corrected phrasing.

Confirmed by `grep -rn "freeze the dash count\|stretch under zoom"` that the
old phrasing existed nowhere else on the branch except `gpu_arm.dart`'s own
(already-correct) mention of what it used to say — this was the only
surviving stale instance.

`dart analyze` / `dart format`: clean. `draft_painter_test.dart`: 16 passed
(no assertions target comment text, but confirms the edit changed nothing
behavioural).

---

## Finding 4 — stale byte-offset / shader-bundle comment

**Change.** `packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart:126-133`.
Corrected "the four dash floats are the ninth-through-twelfth bytes" to
"floats 13–16 ... bytes 48–63" (`InstanceFieldOffset.dashPeriod` through
`dashFracEnd`, 4 bytes each, offset 48). Removed the false claim that
`shaders/cad_stroke.vert` / `assets/shaders/cad.shaderbundle` still declared
`kind`/`half_width` as separate attributes with no `dash` attribute and would
fail pipeline creation on a device — confirmed both files already declare
`kind_half` (a `vec2`) and `dash` (a `vec4`) via:

```
$ grep -n "dash\|kind_half\|half_width" shaders/cad_stroke.vert
46:in vec2 kind_half;   // (kind, half width in device pixels)
51:in vec4 dash;        // (period, phase, fracStart, fracEnd), collection units
```

`dart analyze` / `dart format`: clean.
`flutter test test/gpu/resident_geometry_test.dart`: 14 passed, including
`'kInstanceVertexLayout writeStroke and the vertex layout agree on where
every field lands'`, which independently confirms the byte offsets now
stated in the comment.

---

## Finding 5 — M-C11's mutation-log justification overstated its reach

**Change.** `docs/superpowers/notes/plan-c-mutation-log.md`. "Survivor, not
equivalent" kept as the label. Replaced "no gate in this suite can reach it"
with "no *pixel* gate can reach it, and no targeted unit test was written",
and named the reachable gate explicitly:
`triangle_rasterizer_test.dart` drives `v_dash` directly and could set all
three vertices' `t` to exactly `endA` — the exact fragment M-C11 differs on —
so a gate that *could* reach this mutant exists in the suite, unfired.

Docs-only change; no test gates apply. Confirmed no other occurrence of the
old phrase in `docs/`.

---

## Finding 6 — a wrong kill claimed in a committed test comment

**File.** `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`,
`'without dash varyings, nothing changes'`.

**The originally-named mutation does not kill it, confirmed:** the fixture
calls `observe(...)` with no `dash:` argument, so `ta` and `startA` are both
`null` inside `_fill`. "Default `hasDash` to `ta != null` alone" still
evaluates to `false` in that state (`ta` is null either way), so nothing
observable changes — the claim was argued, never fired.

**Mutation found that does kill it, fired and confirmed by hand:** swap the
order of `_fill`'s guard clauses,
`!debugDisableDashTest && ta != null && startA! >= 0` →
`!debugDisableDashTest && startA! >= 0 && ta != null`. Since `startA` is also
`null` in this fixture, evaluating `startA!` before the null check that was
guarding it throws.

Red, with the swap applied:
```
$ cp test/support/triangle_rasterizer.dart /tmp/.../triangle_rasterizer.dart.bak
# edited: hasDash = !debugDisableDashTest && startA! >= 0 && ta != null;
$ flutter test test/support/triangle_rasterizer_test.dart --plain-name "without dash varyings, nothing changes"
00:00 +0: without dash varyings, nothing changes
00:00 +0 -1: without dash varyings, nothing changes [E]
  Null check operator used on a null value
  test/support/triangle_rasterizer.dart 152:52      TriangleRasterizer._fill
  test/support/triangle_rasterizer.dart 102:7       TriangleRasterizer.observe
  test/support/triangle_rasterizer_test.dart 343:9  main.<fn>
00:00 +0 -1: Some tests failed.
```

Restored from the `cp` backup, green again:
```
$ cp /tmp/.../triangle_rasterizer.dart.bak test/support/triangle_rasterizer.dart
$ git diff --stat test/support/triangle_rasterizer.dart   # empty
$ flutter test test/support/triangle_rasterizer_test.dart --plain-name "without dash varyings, nothing changes"
00:00 +0: without dash varyings, nothing changes
00:00 +1: All tests passed!
```

Updated the comment to name and describe this confirmed mutation instead,
and to say plainly that the previously-committed comment named a mutation
that does not kill the test (the second such correction in this file, after
one during Task 9). `dart analyze` / `dart format`: clean. Full
`triangle_rasterizer_test.dart`: 17 passed.

---

## End-of-branch gates

```
$ cd packages/jet_cad_2d_flutter
$ git status --short
   (clean)
$ flutter test
...
00:07 +540: All tests passed!
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
$ dart format --output=none --set-exit-if-changed .
Formatted 91 files (0 changed) in 0.18s

$ cd ../../apps/dev_harness_2d
$ flutter test --concurrency=1
...
00:17 +72: All tests passed!
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)
```

No `analysis_options.yaml` was touched at any point (`git status --short`
checked before every commit). `packages/jet_cad_2d` was not touched.
Draw order (emission order) was not reordered anywhere. Every mutation
demonstration used a `cp` backup and restore, never `git checkout --`.
