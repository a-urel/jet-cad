# Task 5 report: the live-versus-tiled ink instrument, and criteria 1 and 2

**Files:**
- Created: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` (brief Step 1, verbatim)
- Modified: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` (brief Step 2 verbatim, plus one added test — see Deviations)
- Modified: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` (the carried correction only, one doc comment)

## Carried correction applied

`crossingGrid`'s doc comment claimed "every line below is 90 logical pixels
long." The lines are 190 world units, which at the fixture camera's 1.4 scale
is 266 logical pixels — about eight 32-logical-pixel tiles, not under three.
Fixed in `tile_fixture.dart` and mirrored in criterion 2's own comment in
`tile_cache_test.dart`.

## Step 3: first run of the new tests (criteria 1 and 2)

Per Ruling R5, these were expected to possibly pass on the first run, since
Task 4 already built the mechanism. They did:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +0: loading .../test/tile_cache_test.dart
00:00 +0: a first frame bakes up to its budget and draws the rest live
00:00 +1: a warm frame bakes nothing and blits the whole visible set
00:00 +2: the blit Paint is one instance for the life of the cache
00:00 +3: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

**Green on the first run — not a reason to skip the mutation step**, per R5.

## Mutant M15 — offset a tile's bake camera by one device pixel

In `TileGrid.bakeCameraFor`, changed `m.e - key.x * _tileLogical` to
`m.e - key.x * _tileLogical + 1 / devicePixelRatio` (file copied aside first,
restored from the copy afterward, never `git checkout`).

### Red transcript

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +4 -1: criterion 1: a warm tiled frame equals the live frame exactly [E]
  Expected: <0>
    Actual: <5574>
  InkReport(live: 19860, tiled: 19878, stray: 5574, uncovered: 5556, differing: 11130)

00:00 +4 -1: criterion 1: and it still holds after twenty-three awkward pans
00:00 +4 -2: criterion 1: and it still holds after twenty-three awkward pans [E]
  Expected: <0>
    Actual: <5640>
  InkReport(live: 19722, tiled: 19740, stray: 5640, uncovered: 5622, differing: 11262)

00:00 +4 -2: criterion 2: a fixture crossing tile boundaries still matches
00:00 +4 -3: criterion 2: a fixture crossing tile boundaries still matches [E]
  Expected: <0>
    Actual: <5574>
  InkReport(live: 19860, tiled: 19878, stray: 5574, uncovered: 5556, differing: 11130)

00:00 +4 -3: Some tests failed.
Failing tests:
  .../test/tile_cache_test.dart: criterion 1: a warm tiled frame equals the live frame exactly
  .../test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
  .../test/tile_cache_test.dart: criterion 2: a fixture crossing tile boundaries still matches
```

**Criterion 2 goes red with non-zero stray (5574) and uncovered (5556) counts**,
exactly as the brief requires. All three tests fail, since the offset applies
to every bake regardless of which fixture triggers it. Reproduced identically
on a second, independent run before restoring.

### Restored green

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
$ diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart   # empty, confirmed
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

M15 is killed cleanly by criterion 2 exactly as specified. No deviation here.

## Mutant M17 — drop the injected origin

This is where the brief's assertion needed correcting, and the investigation
was substantial enough to warrant a full account.

### Brief's Step 4 as written: does not fire

In `_bake`, changed `_drawInto(..., origin, null)` to
`_drawInto(..., Vector2.zero(), null)`.

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

Green. Per the brief's own contingency, this means `crossingGrid` is too
close to the world origin — so I moved it, and `tileCamera()`'s translation
with it (to keep the same on-screen picture), out to the brief's named
escape-hatch value.

### Escape hatch as written (`crossingGrid` at 4.5e6): still does not fire

With `crossingGrid`'s lines relocated to `4.5e6 + [10, 200]` and
`tileCamera()`'s translation offset by `1.4 * 4.5e6` to compensate (same
on-screen picture, verified: `liveInk`/`tiledInk` unchanged from the
near-origin runs):

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: All tests passed!
```

Still green, with the mutation active. The brief's assertion that 4.5e6 is
far enough is wrong for this specific instrument.

### Why: an exact algebraic identity, not a "not far enough yet"

I did not stop at "still green" — a report claiming a mutant is unfirable
without a mechanism is not evidence, so I traced it to source.

`crossingGrid`'s entities are all `EntityKind.line`, which `DraftPainter`
routes through `_emitScreenSpace` (`draft_painter.dart:589`), not through the
generic `_localOriginFor`/`chain` path. `_emitScreenSpace` computes, per
point:

```dart
_points[i*2] = toScreen.a*x + toScreen.c*y + toScreen.e - _screenOrigin.x;
```

then hands `_points` to `sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y))` and `sink.polyline(_points, ...)`.
`VerticesDrawSink.polyline` (the sink `TileRig` actually uses — production's
default per its own docstring) applies the residual itself, entirely in Dart:

```dart
final px = a*points[0] + c*points[1] + e;   // e == _screenOrigin.x
```

Substituting: `px = (toScreen.a*x + toScreen.c*y + toScreen.e - _screenOrigin.x) + _screenOrigin.x`.
For M17, `_screenOrigin.x = camera.worldToScreen(Vector2.zero()).x`, which is
*exactly* `toScreen.e` (multiplying by zero is exact), so this is
algebraically `toScreen.a*x + toScreen.c*y + toScreen.e` regardless of what
`_screenOrigin` was — **the origin cancels out of the final coordinate as a
pure identity**, independent of its value, for any point/line/polyline/circle/
arc/fill entity under any placement (I checked `_flatten`/`fillPolygon`/
`fillCircle` in `vertices_draw_sink.dart` too; they all apply the residual the
same way). The intermediate values are large for M17 (~6.3 million at 4.5e6)
but the *cancellation happens entirely in Dart `double` arithmetic*, never in
a `Float32` slot — `VerticesDrawSink` writes only the final, already-small
result into its `Float32List _positions` buffer. `flutter_test`'s software
Skia is never handed the large intermediate value at all, so it has nothing
to round away. This is a different failure shape from M3/G1 (no antialiasing)
but the same root cause: **the instrument cannot reproduce a floating-point
behavior that only a GPU/Impeller backend would exhibit.**

I confirmed this is not merely "not far enough" by sweeping magnitude, restoring
`tile_cache.dart` to baseline between each check:
- At `1e12` (lines only): still green, both mutant and baseline — consistent with the identity above (float64 has ~15 significant digits; no rounding is expected below ~2^52 ≈ 4.5e15).
- At `1e15` (lines only): the *pan-loop* test (23 iterations of `panBy`) goes red under M17 — **but reproducibly goes red identically on the restored, non-mutated baseline too** (same InkReport numbers, confirmed on 3 repeated runs). This is `ViewportTransform`'s own translation losing precision under repeated float64 addition at that magnitude, unrelated to M17. It is not a legitimate kill: a criterion that reds on correct code is not gating anything.
- Adding a text entity (routing through `CanvasDrawSink`, the one sink in this pipeline that does push a residual through a real `canvas.transform` + `Path`) at 4.5e6 with a fractional coordinate (matching this codebase's own convention in `draft_painter_root_test.dart`/`large_coordinate_test.dart`): still green for the single-shot tests; the pan-loop test again failed **identically in both mutant and baseline**, for the same reason above.
- A standalone probe (not part of this task's committed code) confirmed the mechanism *can* show up: a bare `Path.moveTo` with a genuinely huge coordinate plus a `canvas.transform` with a huge, algebraically-cancelling translate *did* produce 167 differing pixels through real `dart:ui` rendering. But this exact shape never occurs in this codebase's reachable sinks from `TileCache`: `VerticesDrawSink` (the production default) never lets a huge value reach a `Float32` slot, and `CanvasDrawSink`'s only consumer here — text — never carries a huge *Path point* (text draws at a fixed local `Offset.zero`; only the transform is huge, and a transform-only huge value did not reproduce the loss in my testing).

This also cross-references cleanly against four **pre-existing** tests in this
same package — `large_coordinate_test.dart`, `viewport_transform_test.dart`,
`draft_painter_root_test.dart`, and Task 1's `draft_painter_rebase_test.dart`
— all of which validate this exact "4.5e6, float32 spacing ~0.5" precision
claim, and **none of which render through a real `dart:ui` `Canvas`** for that
check: they inspect coordinates directly via a `RecordingDrawSink`/spy, or
synthetically apply `Float32List` rounding by hand (`f32()` in
`large_coordinate_test.dart`). That is independent, pre-existing evidence that
this codebase's own test authors already knew real-canvas pixel comparison
does not reproduce this precision loss in `flutter_test`.

### The fix: a numeric wiring check, not a pixel one

Following the same pattern Task 4 used for M13 (brief's own test couldn't see
the mutation; fixed by adding a test with a different observation mechanism,
not by changing the production code), I added one more test:
**"M17 regression: a bake hands the sink a residual, not a raw
site-plan-magnitude coordinate"**. It subclasses `VerticesDrawSink` to record
the largest absolute coordinate ever handed to `polyline` (then forwards to
the real implementation), and asserts it stays under `1e5` for a line placed
at `4.5e6` (the magnitude this codebase already treats as its "site-plan"
convention). This is the same methodology `large_coordinate_test.dart` and
`draft_painter_rebase_test.dart` already use — reading the coordinate that
reaches the sink, not the pixel it eventually produces — applied here to
`TileCache._bake`'s wiring specifically, which none of the existing tests
cover (they test `DraftPainter`'s own rebase, not `TileCache`'s threading of
it through a per-tile bake).

### Red transcript (new test, M17 active)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +7 -1: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate [E]
  Expected: a value less than <100000.0>
    Actual: <4500400.0>
     Which: is not a value less than <100000.0>
  a residual, not a world coordinate -- if `_bake` drops the injected origin, `_emitScreenSpace` hands the sink the raw 4500000-magnitude world value instead, which this bound catches even though it renders to the same pixel

00:00 +7 -1: Some tests failed.
Failing tests:
  .../test/tile_cache_test.dart: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
```

`4500400.0` is exactly `o + 400` — the raw, un-rebased world x-coordinate of
the line's far endpoint — confirming the mechanism precisely. Criteria 1 and
2 stayed green under this same mutation run, confirming the new test is not
redundant with them (same relationship Task 4 documented between its own two
Paint-identity tests).

### Restored green (new test + criteria 1/2, full file)

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
$ diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart   # empty, confirmed
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
...
00:00 +4: criterion 1: a warm tiled frame equals the live frame exactly
00:00 +5: criterion 1: and it still holds after twenty-three awkward pans
00:00 +6: criterion 2: a fixture crossing tile boundaries still matches
00:00 +7: M17 regression: a bake hands the sink a residual, not a raw site-plan-magnitude coordinate
00:00 +8: All tests passed!
```

**Nothing about `TileCache`'s production code was wrong.** `_bake` correctly
threads `origin` through in the unmutated source; the deviation is entirely in
which instrument can observe a defect in it. I did not change any production
file other than during the temporary, restored mutations.

## Wall-clock cost

```
$ cd packages/jet_cad_2d_flutter && time CI=true flutter test test/tile_cache_test.dart
...
00:00 +8: All tests passed!
CI=true flutter test test/tile_cache_test.dart  1.95s user 0.51s system 101% cpu 2.42s total
```

All eight tests (four counting tests plus the four pixel/wiring tests added in
this task) run in under a second of actual test time; the ~2.4s wall clock is
`flutter test`'s own harness startup, matching Task 4's ~1.8–2.0s baseline
before this task's tests existed.

## Full suite, both packages, green

```
$ cd packages/jet_cad_2d && CI=true dart test        # 797 tests, all pass
$ cd packages/jet_cad_2d && CI=true dart analyze     # No issues found!
$ cd packages/jet_cad_2d && CI=true dart format --output=none --set-exit-if-changed .   # 113 files, 0 changed

$ cd packages/jet_cad_2d_flutter && CI=true flutter test   # 322 tests pass, 1 skipped (pre-existing rig-tag skip)
$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze   # No issues found!
$ cd packages/jet_cad_2d_flutter && CI=true dart format --output=none --set-exit-if-changed .   # 60 files, 0 changed
```

`git status` confirmed clean of `analysis_options.yaml` changes before every
stage; only `tile_comparison.dart` (new), `tile_cache_test.dart`, and
`tile_fixture.dart` are touched.

## Deviations, summarized

1. **The carried correction** (doc comment) was applied as instructed.
2. **M17, as scoped in the brief, is not observable through
   `expectTiledEqualsLive`'s pixel comparison at any magnitude that keeps the
   test legitimate** — proven both algebraically (an exact Float64 identity
   independent of the rebase origin's value, for every entity kind
   `VerticesDrawSink` draws) and empirically (a five-point magnitude sweep,
   with the one point that did redden shown to also red the unmutated
   baseline). This is the same category of gap as M3/G1 — a production
   floating-point behavior `flutter_test`'s software Skia does not
   reproduce — but for translation precision rather than antialiasing.
   `crossingGrid` and `tileCamera()` were **not** relocated to 4.5e6 in the
   committed fixture, since that relocation buys nothing for M17 and was
   only ever motivated by trying to fire it; the fixture stays at its
   original near-origin coordinates, unmodified beyond the carried
   correction.
3. **Fix applied:** one additional test, using a `VerticesDrawSink` subclass
   that inspects the actual coordinate magnitude `_bake` hands the sink
   (mirroring `large_coordinate_test.dart`'s and `draft_painter_rebase_test.dart`'s
   existing methodology, applied here to `TileCache._bake`'s wiring
   specifically). This test kills M17 cleanly and is not redundant with
   criteria 1/2 (both stay green under the same mutation that reds it).
4. This finding should be flagged to whoever tracks Plan 3g's mutant coverage
   table and Task 13's mutation log: M17 is killed, but not by a criterion-1
   pixel comparison — by a new, targeted wiring test. If the plan's own
   accounting expects "M17 → Task 5, fired by criterion 1" literally, that
   line needs the same correction this report gives it.

No other deviations. `analysis_options.yaml` was never touched or staged.
