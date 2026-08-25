# Plan 3h — final whole-branch review, single fix wave

Date: 2026-08-26. Worked directly on `main`. **No production code changed** —
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` is byte-identical to
`ee61d86` at the end of this wave. All six findings were in the test tree or
in the record.

Every command below ran with `CI=true`, from the package directory named.
`lib/src/tile_cache.dart` was copied to `/tmp/3h_fix/tile_cache.dart.orig`
before the first mutation and restored from that copy after each one —
**never `git checkout`** — with `diff` and `git status --porcelain` verified
empty after every restore.

Baseline before any change, and again after every restore:
`00:05 +372 ~1: All tests passed!`

---

## Important 1 — `canvas.translate` now has a witness

### The fix

**`packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`** —
`fillingGrid`'s extent widened from world `x ∈ [20, 320], y ∈ [10, 240]` to
`x ∈ [-52, 380], y ∈ [-52, 300]`, spacing unchanged at 16 world units.

**The derivation, written into the doc comment.** `tileCamera()` is
`Transform2(1.4, 0, 0, -1.4, -37.0, 323.0)`, i.e.

```
sx = 1.4 * wx - 37        sy = -1.4 * wy + 323
```

so **one world unit is 1.4 screen pixels** and the resting visible world box
is `x ∈ [26.4, 312.1]`, `y ∈ [16.4, 230.7]`. `TileRig.panBy` adds its offset
to the camera's translation, so a pan of `d` screen pixels slides the drawing
by `d` on screen; an edge of the grid stays outside the viewport under that
pan only while its own screen distance past that viewport edge exceeds `|d|`.
At the new extent:

| edge   | world   | screen | past the viewport edge by |
|--------|---------|--------|---------------------------|
| left   | x = -52 | -109.8 | 109.8 px |
| right  | x = 380 |  495.0 |  95.0 px |
| top    | y = 300 |  -97.0 |  97.0 px |
| bottom | y = -52 |  395.8 |  95.8 px |

The largest offset the sweep pans is **71**, so every edge clears the whole
sweep by at least **24 screen pixels**. The bounds are a whole number of steps
apart end to end (`-52 + 16*22 = 300`, `-52 + 16*27 = 380`), so the outermost
line lands exactly on the extent the table measures. The predecessor extent
cleared the *resting* box by 9 to 13 screen pixels — less than any swept
offset — which is why `Offset(-41, 0)` and `Offset(0, -41)` entered across
bare canvas, and those two are precisely the only offsets whose strip does not
start at (0, 0).

**`packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`** — the new
seventh anti-vacuity clause:

- `InkReport.liveStripInk` — live-capture ink inside `debugLastStrip`.
- `int inkInside(Uint8List pixels, Rect logical)` — logical → device via
  `kTileDpr`, clipped to the capture.
- `measureFallbackAgreement` takes `int minimumStripInk = 200` and asserts
  `report.liveStripInk >= minimumStripInk` **before** the whole-frame ink
  floors, with the reason naming the band.

Measured band ink, correct code, new fixture (throwaway harness
`test/tmp_measure_test.dart`, added, used and **deleted**; never staged):

```
TEMP fillingGrid Offset(37.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 69.0, 300.0) bandInk=7032 ratio=0.8065 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 50, stripInk: 0)
TEMP fillingGrid Offset(53.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 85.0, 300.0) bandInk=9012 ratio=0.8387 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 52, stripInk: 0)
TEMP fillingGrid Offset(71.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 103.0, 300.0) bandInk=11096 ratio=0.8710 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 54, stripInk: 0)
TEMP fillingGrid Offset(0.0, 37.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 69.0) bandInk=9552 ratio=0.9063 InkReport(live: 42992, tiled: 42992, stray: 0, uncovered: 0, differing: 0, liveTri: 64, tiledTri: 58, stripInk: 0)
TEMP fillingGrid Offset(0.0, 53.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 85.0) bandInk=12232 ratio=0.9375 InkReport(live: 42992, tiled: 42992, stray: 0, uncovered: 0, differing: 0, liveTri: 64, tiledTri: 60, stripInk: 0)
TEMP fillingGrid Offset(0.0, 71.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 103.0) bandInk=13528 ratio=0.9355 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 58, stripInk: 0)
TEMP fillingGrid Offset(-41.0, 0.0) strip=Rect.fromLTRB(343.0, 0.0, 400.0, 300.0) bandInk=5260 ratio=0.7742 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 48, stripInk: 0)
TEMP fillingGrid Offset(0.0, -41.0) strip=Rect.fromLTRB(0.0, 247.0, 400.0, 300.0) bandInk=6872 ratio=0.9032 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 56, stripInk: 0)
```

All eight bands carry ink (5260 to 13528 device pixels); the reviewer's table
had 0 at the two negative offsets.

`nearAxisDiagonals`, same harness, unchanged fixture — the numbers Important 3
rests on:

```
TEMP nearAxis Offset(37.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 69.0, 300.0) bandInk=1654 ratio=1.0000 InkReport(live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54, liveTri: 20, tiledTri: 20, stripInk: 0)
TEMP nearAxis Offset(53.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 85.0, 300.0) bandInk=1654 ratio=1.0000 InkReport(live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54, liveTri: 20, tiledTri: 20, stripInk: 0)
TEMP nearAxis Offset(71.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 103.0, 300.0) bandInk=1654 ratio=1.0000 InkReport(live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54, liveTri: 20, tiledTri: 20, stripInk: 0)
TEMP nearAxis Offset(0.0, 37.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 69.0) bandInk=0 ratio=0.0000 InkReport(live: 10212, tiled: 10214, stray: 19, uncovered: 17, differing: 36, liveTri: 20, tiledTri: 0, stripInk: 0)
TEMP nearAxis Offset(0.0, 53.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 85.0) bandInk=0 ratio=0.0000 InkReport(live: 9805, tiled: 9807, stray: 19, uncovered: 17, differing: 36, liveTri: 20, tiledTri: 0, stripInk: 0)
TEMP nearAxis Offset(0.0, 71.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 103.0) bandInk=0 ratio=0.0000 InkReport(live: 8928, tiled: 8930, stray: 19, uncovered: 17, differing: 36, liveTri: 20, tiledTri: 0, stripInk: 0)
TEMP nearAxis Offset(-41.0, 0.0) strip=Rect.fromLTRB(343.0, 0.0, 400.0, 300.0) bandInk=0 ratio=0.0000 InkReport(live: 8685, tiled: 8687, stray: 19, uncovered: 17, differing: 36, liveTri: 20, tiledTri: 0, stripInk: 0)
TEMP nearAxis Offset(0.0, -41.0) strip=Rect.fromLTRB(0.0, 247.0, 400.0, 300.0) bandInk=0 ratio=0.0000 InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 36, liveTri: 20, tiledTri: 0, stripInk: 0)
```

### The proof: delete `tile_cache.dart:841`, and it reddens

Mutation applied with python (the single line
`    canvas.translate(strip.left, strip.top);\n` removed, `assert count == 1`),
nothing else touched.

`CI=true flutter test test/tile_fallback_test.dart` — **RED**:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <2224>
  Offset(-41.0, 0.0): InkReport(live: 41464, tiled: 39240, stray: 0, uncovered: 2224, differing: 2224, liveTri: 62, tiledTri: 48, stripInk: 5260)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_fallback_test.dart 61:7                   main.<fn>

00:00 +0 -1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

`CI=true flutter test` (whole package) — **RED, exactly one failure**:

```
00:05 +371 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

On the old fixture the same deletion was green at `+372 ~1`. Restored from
`/tmp/3h_fix/tile_cache.dart.orig`; `diff` empty; suite back to `+372 ~1`.

### The re-bracketed `kTriangleBudgetRatio`

The wider fixture moved correct code's worst ratio from 0.833 to **0.9375**,
so the old `0.9` no longer passes correct code and had to be re-derived.

| pan | correct code | under M5 (grow the walk) |
|---|---|---|
| (37, 0)  | 50/62 = 0.8065 | 80/62 = 1.2903 |
| (53, 0)  | 52/62 = 0.8387 | 80/62 = 1.2903 |
| (71, 0)  | 54/62 = 0.8710 | 80/62 = 1.2903 |
| (0, 37)  | 58/64 = 0.9063 | 80/64 = 1.2500 |
| (0, 53)  | 60/64 = **0.9375** | 80/64 = 1.2500 |
| (0, 71)  | 58/62 = 0.9355 | 76/62 = 1.2258 |
| (-41, 0) | 48/62 = 0.7742 | 54/62 = 0.8710 |
| (0, -41) | 56/62 = 0.9032 | 62/62 = **1.0000** |

**Lower endpoint, measured.** `kTriangleBudgetRatio = 0.9375` — **RED**:

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <60.0>
    Actual: <60>
     Which: is not a value less than <60.0>
  pan Offset(0.0, 53.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 42992, tiled: 42992, stray: 0, uncovered: 0, differing: 0, liveTri: 64, tiledTri: 60, stripInk: 12232)
```

`kTriangleBudgetRatio = 0.94` — **GREEN**:

```
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

**Upper endpoint.** The lowest ratio the mutant produces at an offset the gate
can see is **1.0000**, at `Offset(0, -41)`.

**Chosen: `0.97`** — the midpoint of `(0.9375, 1.0000]`, 0.0325 above the
first value that fails correct code and 0.0300 below the first value the
mutant would slip past. Two triangles of headroom at the tightest offset (62
of 64 allowed, 60 emitted). `Offset(-41, 0)` is a hole and is named in the
constant's doc comment: the mutant only moves it 0.7742 → 0.8710, so the gate
is a sweep-level gate that kills M5/M4 at seven of eight offsets.

### Re-measured mutants (all on the new fixture, 2026-08-26)

**M1 — drop the clamp. KILLED, and more fully than before.** Whole suite
`+368 ~1 -4`: the three `stripFor` cases **plus** `criterion 2 and 2c`, which
the old fixture could not see —

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <60.14>
    Actual: <66>
     Which: is not a value less than <60.14>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 66, stripInk: 7032)
```

**M2 — drop the pad. Pixel sweep GREEN, whole suite RED.**

```
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

```
00:04 +369 ~1 -3: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor clamps one edge at a time
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor pads an interior rect on every side
```

Per-offset under M2 (harness), all eight bands non-empty and all zeros:

```
TEMP fillingGrid Offset(37.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 37.0, 300.0) bandInk=3072 ratio=0.7419 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 46, stripInk: 0)
TEMP fillingGrid Offset(53.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 53.0, 300.0) bandInk=5052 ratio=0.7742 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 48, stripInk: 0)
TEMP fillingGrid Offset(71.0, 0.0) strip=Rect.fromLTRB(0.0, 0.0, 71.0, 300.0) bandInk=7136 ratio=0.8065 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 50, stripInk: 0)
TEMP fillingGrid Offset(0.0, 37.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 37.0) bandInk=5720 ratio=0.8750 InkReport(live: 42992, tiled: 42992, stray: 0, uncovered: 0, differing: 0, liveTri: 64, tiledTri: 56, stripInk: 0)
TEMP fillingGrid Offset(0.0, 53.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 53.0) bandInk=8400 ratio=0.9063 InkReport(live: 42992, tiled: 42992, stray: 0, uncovered: 0, differing: 0, liveTri: 64, tiledTri: 58, stripInk: 0)
TEMP fillingGrid Offset(0.0, 71.0) strip=Rect.fromLTRB(0.0, 0.0, 400.0, 71.0) bandInk=9696 ratio=0.9032 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 56, stripInk: 0)
TEMP fillingGrid Offset(-41.0, 0.0) strip=Rect.fromLTRB(375.0, 32.0, 400.0, 300.0) bandInk=2224 ratio=0.7097 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 44, stripInk: 0)
TEMP fillingGrid Offset(0.0, -41.0) strip=Rect.fromLTRB(32.0, 279.0, 400.0, 300.0) bandInk=2752 ratio=0.8065 InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 50, stripInk: 0)
```

**M3 — shrink the query 20px. KILLED**, whole suite `+365 ~1 -7`, the same
seven tests as the previous record:

```
+155 -1: test/invariants/tile_budget_test.dart: criterion 12: a frame at the cap still equals the live frame [E]
+261 ~1 -2: test/tile_cache_test.dart: stripFor pads an interior rect on every side [E]
+261 ~1 -3: test/tile_cache_test.dart: stripFor clamps to the viewport rather than growing past it [E]
+261 ~1 -4: test/tile_cache_test.dart: stripFor clamps one edge at a time [E]
+261 ~1 -5: test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward [E]
+290 ~1 -6: test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame [E]
+290 ~1 -7: test/tile_fallback_test.dart: criterion 2b: the near-axis arm stays inside the tiled path's bound [E]
```

Targeted, `criterion 2 and 2c` now trips the **new** clause first, because a
20 px shrink inverts the strip at `Offset(-41, 0)`:

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value greater than or equal to <200>
    Actual: <0>
     Which: is not a value greater than or equal to <200>
  pan Offset(-41.0, 0.0): the live frame carries no ink inside the band the fallback owes (Rect.fromLTRB(395.0, 52.0, 387.0, 300.0)), so every pixel assertion below is satisfied by a fallback that could have drawn nothing: InkReport(live: 41464, tiled: 40340, stray: 0, uncovered: 1124, differing: 1124, liveTri: 62, tiledTri: 40, stripInk: 0)
00:00 +0 -2: criterion 2b: the near-axis arm stays inside the tiled path's bound [E]
  Expected: a value less than or equal to <60>
    Actual: <417>
  Offset(37.0, 0.0): InkReport(live: 10703, tiled: 10344, stray: 29, uncovered: 388, differing: 417, liveTri: 20, tiledTri: 0, stripInk: 0)
```

**The pixel path still kills M3 independently** — measured by temporarily
passing `minimumStripInk: 0` at the criterion-2 call site (reverted
immediately, `diff` against the pre-edit copy empty, never staged):

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <124>
  Offset(37.0, 0.0): InkReport(live: 41464, tiled: 41340, stray: 0, uncovered: 124, differing: 124, liveTri: 62, tiledTri: 44, stripInk: 1352)
```

**M4 — narrow the clip, not the query. DIES**, targeted and whole-package:

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <60.14>
    Actual: <80>
     Which: is not a value less than <60.14>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 80, stripInk: 7032)
```

```
00:04 +371 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

M4's **device** arm was not re-run (no `flutter drive` executed anywhere in
this wave); a fixture cannot move a timing, and its figures stand.

**M5 — grow the walk. KILLED**, identical figures to M4 (both end up handing
`_drawInto` the full viewport):

```
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <60.14>
    Actual: <80>
     Which: is not a value less than <60.14>
  pan Offset(37.0, 0.0): ... InkReport(live: 41464, tiled: 41464, stray: 0, uncovered: 0, differing: 0, liveTri: 62, tiledTri: 80, stripInk: 7032)
```

```
00:04 +371 ~1 -1: Some tests failed.
```

---

## Important 2 — M2's ruling reworded

`docs/superpowers/notes/plan-3h-mutation-log.md` M2 section and `STATUS.md`
now read:

> **Ruling: SURVIVES THE PIXEL SWEEP; DIES AT THE SUITE LEVEL on the pad's
> value.**

with both transcripts above quoted verbatim, an explicit sentence that the
three `stripFor` cases are also counted in M3's kill and that scoring them for
one mutant and dropping them for the other was the inconsistency being
removed, and a note that the narrow H5 claim is the one criterion 1b rests on.
`STATUS.md`'s "Unit, survives" bullet is replaced by the two-part statement
with the `+369 ~1 -3` figure.

**Does the wider fixture change what M2 does? No.** M2 is still green on the
pixel sweep, and now *non-vacuously* so: every one of the eight bands carries
2224–9696 device pixels of live ink and the sweep still reads all zeros. Gap
H5 does not need restating in substance — it needs the narrower wording it now
has, and it is strictly better evidenced than before.

---

## Important 3 — H3 restated

`STATUS.md` H3 now says what the near-axis arm actually exercises. From the
`nearAxisDiagonals` table above: the only offsets with any band ink are
`(37,0)`, `(53,0)`, `(71,0)` (1654 each), and all three have
`strip.topLeft == (0, 0)`, where `canvas.translate` is a no-op. The other five
bands are empty. **The near-axis arm never exercises the translate**, so
"bounded on the near-axis arm" was not a statement about G5 at all.

What the tree has instead, after Important 1: the widened `fillingGrid`
carries band ink at all eight offsets including the two whose strips start at
(343, 0) and (0, 247), and criterion 2 gates those at **exactly zero**
differing pixels — stronger than a bound, but only for axis-aligned geometry.
The combination G5 is about — a **near-axis slope** walked through a
**translated** strip — remains untested by either arm. H3 is recorded as open
and narrower than it was.

---

## Minor 1 — the clip mutant recorded as M6 / gap H6

Fired: `canvas.clipRect(uncovered, …)` removed and
`canvas.clipRect(strip, …)` inserted after `_lastStrip = strip;`. Whole widget
suite:

```
00:05 +372 ~1: All tests passed!
```

Identical to baseline: **SURVIVES**. Recorded as a full section (M6) in
`plan-3h-mutation-log.md` with the diff, the ruling, and why it cannot be
closed from this repository (the difference is pure overdraw of pixels already
carrying the same ink, so no pixel oracle sees it; it does not change what is
queried, so the triangle count does not either). Recorded in `STATUS.md` as
**gap H6**, and the tally now reads **six fired, four killed, two survivors**,
over a chosen six.

---

## Minor 2 — `checkTriangleBudget` defaults to `true`

`tile_comparison.dart`: `measureFallbackAgreement` and
`sweepFallbackAgreement` both take `bool checkTriangleBudget = true` and the
new `int minimumStripInk = 200`. `tile_fallback_test.dart`'s criterion 2/2c
call now passes neither and takes the defaults; `criterion 2b` passes
`checkTriangleBudget: false, minimumStripInk: 0` explicitly, with the reasons
at the call site (ratio of exactly 1.0 or 0 on `nearAxisDiagonals`; five of
eight bands empty) and a pointer to H3.

---

## Minor 3 — `fillingGrid`'s doc comment corrected

Folded into Important 1's derivation. The comment no longer says the fixture
"strictly contains" the visible box; it gives the camera equations, the 1.4
world→screen factor, the four screen-pixel clearances, the largest swept
offset they are compared against, and a paragraph on what the predecessor
extent did and why it cost the translate its witness.

---

## Final gates

`git status --porcelain` immediately before staging:

```
 M STATUS.md
 M docs/superpowers/notes/2026-08-25-plan-3h-results.md
 M docs/superpowers/notes/plan-3h-mutation-log.md
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
 M packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
 M packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
```

No `analysis_options.yaml`, no `project.pbxproj`, **no golden PNG** — and the
golden tag was run to prove nothing was regenerated.

`packages/jet_cad_2d_flutter`:

```
=== flutter test ===
00:05 +372 ~1: All tests passed!
=== golden tag ===
00:03 +35: All tests passed!
=== analyze ===
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
=== format ===
Formatted 65 files (0 changed) in 0.09 seconds.
```

`packages/jet_cad_2d`:

```
=== dart test ===
00:02 +797: All tests passed!
=== analyze ===
Analyzing jet_cad_2d...
No issues found!
=== format ===
Formatted 113 files (0 changed) in 0.14 seconds.
```

---

## Concerns handed forward

1. **The triangle gate is tighter than it was**: two triangles of headroom at
   `Offset(0, 53)` where it had four. That is a consequence of the fixture
   widening moving correct code's worst ratio to 0.9375, and of refusing a
   bound above 1.0. Deterministic, bracketed on both sides, but brittle to any
   future edit of `fillingGrid` or `kFallbackOffsets`. Recorded as the one
   remaining deferred minor.
2. **`criterion 2b` now opts out of both fallback gates.** It carries no
   triangle signal and cannot carry the band-ink clause, because
   `nearAxisDiagonals` leaves five of eight bands empty. Widening *that*
   fixture would change the `<= 60` bound it shares with
   `tile_cache_test.dart`, a different contract, so it was left alone and the
   gap is recorded (H3) rather than papered over. A future plan that wants G5
   bounded under a translated strip needs a near-axis fixture wide enough to
   fill the negative-offset bands, plus its own re-derived bound.
3. **H6 needs an oracle this repository does not have** — a fill-rate counter,
   or a device timing sensitive to a `kTileSlack`-sized overdraw.
