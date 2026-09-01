# Task 7 report: the fill corpus in the pixel gate, and spec criterion 4

Branch `plan-d/fills`. Work confined to `packages/jet_cad_2d_flutter/test`, as
instructed. `lib/src/vertices_draw_sink.dart` untouched; `packages/jet_cad_2d`
untouched.

## Files touched

- `test/gpu/fill_order_test.dart` — new. The brief's three tests (one
  corrected, see below) plus `sortByKind`.
- `test/support/gpu_comparison.dart` — new `paintFillFixture`,
  `collectFillFixture`, `renderFillFixture`, `countDifferingPixels`, a shared
  `_reorderedInstances` helper (factored out of `measureResidentColor`'s
  previously-inline reorder loop, now also used by `renderFillFixture`), and
  a new public `kFillFixtureDevicePixelRatio` constant. One new import,
  `fixtures.dart show fillFixture, kViewport`.
- `test/gpu/resident_pixel_differential_test.dart` — one new test, "the fill
  corpus agrees per channel," per the brief's Step 1 addition.
- `test/gpu/collector_differential_test.dart` — `_checkAgainstOracle` extended
  with `FillPolygonOp`/`FillCircleOp` handling, a new `_ExpectedInstance.fill`
  constructor, fill-specific branches in the per-instance loop (half-width
  must be exactly 0, colour is `style.argb` raw, never `_referenceCoveredArgb`),
  and one new test that walks `fillFixture()` through the extended oracle.

## Verifying `permute` reorders whole records, before trusting any number

Task 6 shipped `measureResidentColor`'s `permute` with no exercising caller.
Before writing this task's gates on top of it, I wrote a throwaway test (not
committed — created, run, deleted, confirmed via `git status --short` and
`diff` against nothing stray afterward) with three enormous, fully-overlapping
strokes (red, green, blue, drawn in that order) and a `permute` that reverses
the buffer:

```
UNPERMUTED: ResidentColorAgreement(union: 8000, withinTwo: 8000 (100.000%), overEight: 0, referenceInk: 8000)
REVERSED:   ResidentColorAgreement(union: 8000, withinTwo: 0 (0.000%), overEight: 8000, referenceInk: 8000)
```

Unpermuted, the resident arm ends on blue — same as the reference, which
always draws the closure in the order given — so the two agree exactly.
Reversed, the resident arm ends on **red** (the original first stroke, now
drawn last) while the reference still ends on blue: 100% of the union
disagrees, at full per-channel distance. That is only possible if every one
of the 16 floats in a record — both the geometry (which strokes still overlap
identically, since they share one segment) and the colour together — moved to
its new index at the correct `kFloatsPerInstance` stride; a scalar-only
reorder (e.g. colour but not position) or a wrong-stride slide would have
produced a garbled or partially-correct picture, not a clean full-record
swap. `_reorderedInstances` (the code this exercised, then factored out
verbatim into a shared helper) is exactly the loop `measureResidentColor` had
inline before this task.

## The brief's first test had a lock-in bug against the real fixture

The brief's sample loop tracks `lastFill` (correctly, updated on every fill
seen) but locks `strokeAfterFill` at the *first* stroke seen after *any*
fill, via a `strokeAfterFill < 0` guard. Run verbatim against
`collectFillFixture()`, it failed:

```
Expected: a value greater than <58>
  Actual: <3>
```

Diagnosed by printing the kind sequence (155 instances):
`SFFSJSJSJSSFFFFFF...FFSJSJSJ...SJ` — `AddRegionCommand.apply` adds a
region's boundary as its own ordinary, independently-visible entity ("fill
first," `commands.dart`), so fill 901's boundary (902, a closed polygon) is
drawn as a stroke+join run *immediately* after fill 901 — long before fill
904 (the translucent circle) is reached. The lock-in guard latches onto 902's
outline (index 3) and never looks again, so it compares that early index
against `lastFill`, which keeps advancing to 904's own last instance (58) —
a false negative on a real, working corpus.

I fixed the loop to scan the whole buffer for the *last* stroke instead of
the first post-fill one (`lastStroke=153`, from 905's own boundary outline,
comfortably after `lastFill=58`), and documented why in the test itself. This
is a logic correction, not a threshold moved to force a pass — the
underlying property (`strokeInkInsideFill`'s already-measured 337-pixel
overlap between 903 and fill 901) was never in question, only the sample
loop's ability to see it.

## Measured numbers

Captured via temporary `print` calls, then reverted (`diff` against a saved
copy was empty before the final commit):

- **`submitting the buffer out of walk order changes the rendering`**:
  `differing = 9297` (gate: `> 200`).
- **`the resident arm matches the reference in walk order and only there`**:
  - unpermuted: `ResidentColorAgreement(union: 393051, withinTwo: 393051 (100.000%), overEight: 0, referenceInk: 393051)`
  - permuted (`sortByKind`): `ResidentColorAgreement(union: 393051, withinTwo: 383754 (97.635%), overEight: 9297, referenceInk: 393051)`

The differing-pixel count (9297) and the permuted `overEight` (9297) are the
same number by construction — both come from the same kind-sorted resident
render disagreeing with the walk-order one over the same footprint.

## The sorted-buffer mutation, and its verbatim failure output

Per the testing bar, I mutated `GeometryCollector.data` (backed up first with
`cp` to `/tmp/geometry_collector.dart.bak`, restored the same way afterward —
never `git checkout --`) to sort the returned buffer by `kind` (stable,
tie-broken on original index) instead of returning it in walk order:

```dart
Float32List get data {
  final raw = _buffer.sublist(0, _instances * kFloatsPerInstance);
  final order = List<int>.generate(_instances, (i) => i)
    ..sort((a, b) {
      final ka = raw[a * kFloatsPerInstance + InstanceFieldOffset.kind];
      final kb = raw[b * kFloatsPerInstance + InstanceFieldOffset.kind];
      final c = ka.compareTo(kb);
      return c != 0 ? c : a.compareTo(b);
    });
  final sorted = Float32List(_instances * kFloatsPerInstance);
  for (var i = 0; i < _instances; i++) {
    final from = order[i] * kFloatsPerInstance;
    final to = i * kFloatsPerInstance;
    sorted.setRange(to, to + kFloatsPerInstance, raw, from);
  }
  return sorted;
}
```

`flutter test test/gpu/fill_order_test.dart` against this mutant — all three
tests go red:

```
00:00 +0: the fill corpus really does have a stroke drawn over a fill
00:00 +0 -1: the fill corpus really does have a stroke drawn over a fill [E]
  Expected: a value greater than <154>
    Actual: <53>
     Which: is not a value greater than <154>
  no stroke is emitted after the last fill, so no permutation of this corpus could change a pixel and criterion 4 would pass vacuously

00:00 +0 -1: submitting the buffer out of walk order changes the rendering
00:00 +0 -2: submitting the buffer out of walk order changes the rendering [E]
  Expected: a value greater than <200>
    Actual: <0>
     Which: is not a value greater than <200>
  a permutation that changed no pixel would mean this gate cannot fail, whatever it reads

00:00 +0 -2: the resident arm matches the reference in walk order and only there
00:00 +0 -3: the resident arm matches the reference in walk order and only there [E]
  Expected: a value greater than or equal to <0.995>
    Actual: <0.9763465809780411>
     Which: is not a value greater than or equal to <0.995>
  ResidentColorAgreement(union: 393051, withinTwo: 383754 (97.635%), overEight: 9297, referenceInk: 393051)

00:00 +0 -3: Some tests failed.
```

All three tests in the file the mutation targets die (the first because
`data` itself is now always kind-sorted, so `lastFill`/`lastStroke` in the
corpus's own kind sequence no longer reflect walk order at all; the second
and third because the "in order" and "by kind" renders collapse to the same
picture once `data` ignores walk order unconditionally — `differing` reads
`0` because both arms are now identically sorted). `lib/` restored via `cp`
from the backup; `git diff --stat packages/jet_cad_2d_flutter/lib/` and
`git status --short packages/jet_cad_2d_flutter/lib/` both empty afterward.

## Design notes on the helpers

- **`paintFillFixture(DrawSink sink)`** goes through the real `DraftPainter`,
  camera fit to `kViewport` (the same 800×600 `fillFixture`'s own guard tests
  use) — not hand-rolled `sink.fillPolygon`/`sink.circle` calls, per the
  brief's own instruction: a fill only resolves to its boundary's
  triangulation through `DraftPainter._drawFill`.
- **`collectFillFixture()`** paints into a fresh `GeometryCollector` at a new
  public constant, `kFillFixtureDevicePixelRatio = 2.0`, and returns it.
- **`renderFillFixture({permute})`** is deliberately narrower than
  `measureResidentColor`: it renders the resident arm only (collector →
  `expandInstances` → `TriangleRasterizer`), with no reference-sink
  comparison, since the "does a permutation move a pixel at all" question
  the second test asks needs only the resident arm's own buffer compared
  against itself.
- **`sortByKind`** lives in `fill_order_test.dart`, not `lib/`, per the
  brief. Because `permute`'s contract only hands it the identity index list
  (never the underlying kind data), it re-collects the fixture internally to
  read each index's `kind`. This is safe because `devicePixelRatio` affects
  a record's `halfWidth`, never its `kind` or its position in the walk, so a
  second collection at a different dpr reproduces the same kind sequence.
  Ties are broken explicitly on original index (Dart's `List.sort` is not
  documented stable), which is what makes it "the order three pipelines
  would submit in" rather than an arbitrary reshuffling within a kind.
- **`collector_differential_test.dart`'s new fill handling** reuses
  `_flattenedLocalPoints` (already shared with the CircleOp/ArcOp cases) for
  `FillCircleOp`'s fan, rather than a third copy of the step-count formula —
  Ruling D5 ties a filled circle's tessellation to its own outline's, so one
  perimeter deriver serves both.

## Gate commands, verbatim

### `flutter test` (global constraint gate 1)

```
00:10 +560 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:10 +561 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:10 +562 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:10 +563 ~1: All tests passed!
TEST_EXIT=0
```

563 passed, 1 pre-existing skip (unrelated to this task), 0 failures.

Targeted runs:

```
$ flutter test test/gpu/fill_order_test.dart
00:00 +0: the fill corpus really does have a stroke drawn over a fill
00:00 +1: submitting the buffer out of walk order changes the rendering
00:00 +2: the resident arm matches the reference in walk order and only there
00:00 +3: All tests passed!

$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: the two arms agree per channel, not merely on coverage
00:00 +3: the colour measurement can actually fail
00:00 +4: the fill corpus agrees per channel
00:00 +5: All tests passed!

$ flutter test test/gpu/collector_differential_test.dart
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +1: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor
00:00 +2: fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises
00:00 +3: the fill fixture -- every instance's kind, argb and three points match the reference's triangle stream, in order
00:00 +4: All tests passed!
```

### `flutter analyze` (global constraint gate 2)

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.4s)
ANALYZE_EXIT=0
```

### `dart format --output=none --set-exit-if-changed .` (global constraint gate 3)

First run printed `Formatted 92 files (2 changed)` — `fill_order_test.dart`
and `gpu_comparison.dart` — a real failure, not a status line. Ran
`dart format` (no `--set-exit-if-changed`) on exactly those two files, then
re-ran the check:

```
Formatted 92 files (0 changed) in 0.15 seconds.
FORMAT_EXIT=0
```

All three global gates green.

## Anything the plan did not anticipate

- The brief's first test's loop had the lock-in bug described above — a real
  defect in the sample code, not a corpus defect. Fixed and documented in
  place rather than reproduced verbatim, per this task's own instruction not
  to tune numbers to force a pass; the underlying property was independently
  already true and already measured (`strokeInkInsideFill`'s 337 pixels).
- `AddRegionCommand.apply` adding a region's boundary as its own
  independently-visible entity means `fillFixture`'s walk is far busier than
  "two fills and two strokes" — 155 instances total, most of them the two
  boundaries' own stroke+join runs. `_checkAgainstOracle`'s existing
  `PolylineOp`/`CircleOp` handling already covered both boundaries with no
  new code; only `FillPolygonOp`/`FillCircleOp` needed new cases.
- `measureResidentColor`'s `permute` reorder loop was previously inlined
  directly in that function; factored into a shared `_reorderedInstances` so
  `renderFillFixture` uses the identical code path rather than a second copy
  that could drift from it.
- `git status --short` before staging showed exactly the four files named in
  the brief's commit step, no `analysis_options.yaml`, no stray temp/backup
  files (the throwaway permute-verification test and the diagnostic kind-dump
  test were both deleted after use, and `lib/geometry_collector.dart`'s
  mutation was reverted via `cp` from a backup, confirmed byte-identical by
  `git diff`/`git status` showing no change to `lib/`).

## Commit

```
git add packages/jet_cad_2d_flutter/test/gpu/fill_order_test.dart \
        packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart \
        packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart \
        packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart
git commit -m "test(gpu): emission order is the drawing, and a fill proves it"
```

---

## Fix round 1/5

Independent review of `9c639b5` confirmed the gate is real, and found one
Important gap plus three Minors. All four fixed in one commit.

### 1. Important — `permute`'s stride now has a permanent test

Added two tests to `test/gpu/fill_order_test.dart`, after the existing three:

- **`the identity permutation renders the same picture as no permutation`**:
  `renderFillFixture(permute: (order) => order)` must render pixel-identical
  to `renderFillFixture()`.
- **`sortByKind is a multiset-equal reordering of the walk-order buffer, not
  a scramble`**: builds `order = sortByKind(...)`, reorders the raw buffer
  through the (now-public) `reorderedInstances`, and compares the two
  buffers as frequency maps of whole 16-float records (`record.join(',')`
  as key) — every record must appear in the sorted buffer exactly as many
  times as in the walk-order one.

Also made `_reorderedInstances` public (`reorderedInstances`) in
`gpu_comparison.dart`, since both the new record-level test and
`renderFillFixture`/`measureResidentColor` now share it — one place, not a
second copy in the test file.

**Which mutation each kills — verified by firing both for real, not
assumed:**

- **Identity test**: mutated `reorderedInstances`'s source index to
  `((order[i] + 1) % instanceCount) * kFloatsPerInstance` (a cyclic shift,
  always in-bounds). Result: the three pre-existing pixel tests **still
  passed** (a cyclic shift composed with `sortByKind`'s output is still a
  bijection, so it still paints "a different enough" picture) — but the new
  identity test failed cleanly:
  ```
  00:00 +3 -1: the identity permutation renders the same picture as no permutation [E]
    Expected: <0>
      Actual: <6902>
    permute: (order) => order must be a true no-op
  ```
  This is the exact false-pass the review warned about: a wrong-stride bug
  that the three original pixel tests cannot distinguish from a correct
  reorder, caught only once the identity case is pinned directly.
- **Multiset test**: mutated `sortByKind` (in the test file) to
  `sorted[sorted.length - 1] = sorted[0];` after sorting — same length,
  no longer a bijection, index 0's record duplicated, the true last record
  dropped. Result: **only** the multiset test failed (`+4 -1`, all four
  others green, identity test included, since it never calls `sortByKind`):
  ```
  Which: has different length and is missing map key '3.0,0.0,607.10498046875,...'
  sortByKind must be a bijection on instance indices: ...
  ```
- A first attempt at the identity-test mutation (`+ 1` on the float index,
  not cyclic) instead threw `Bad state: Too few elements` out of
  `Float32List.setRange` on the last record — also a clean red, but not the
  differing-pixel-count demonstration wanted, so I replaced it with the
  cyclic-shift version above, which stays in-bounds.
- The cyclic-shift experiment also **disproved my own first draft of the
  multiset test's doc comment**, which claimed it kills "a wrong-stride
  slide" — false: a pure index-stride bug composed with any real permutation
  stays bijective and is invisible to multiset-equality (confirmed: it
  passed under that mutation). Corrected the comment in place to say what is
  actually true — the multiset test kills a non-bijective `sortByKind`
  (duplicate + drop), which is a defect class the identity test cannot see
  either, since it never calls `sortByKind` at all. Both tests are needed;
  neither subsumes the other.

All mutations reverted via `cp` from `/tmp/gpu_comparison.dart.bak2` and
`/tmp/fill_order_test.dart.bak2` (never `git checkout --`), confirmed
byte-identical by `diff` before re-editing.

### 2. Minor — "337-device-pixel" → "337-logical-pixel"

Fixed in `gpu_comparison.dart`'s `paintFillFixture` doc: `strokeInkInsideFill`
rasterises `fillFixture()` at `kViewport` with no `devicePixelRatio` argument
(default dpr 1), so the 337 pixels it measured are logical pixels. Reworded
and added a clause naming the dpr explicitly so the claim doesn't need a
reader to check the default.

### 3. Minor — `reorderedInstances` validates `order`

Added `assert(order.length == instanceCount, ...)` at the top of
`reorderedInstances`, naming both the expected and actual lengths in the
message, plus a doc paragraph explaining why (a short list would otherwise
silently zero-pad a tail, a long one would silently ignore its excess, and
either could instead surface as a bare `RangeError` far from the cause).

### 4. Minor — the anti-vacuity comment no longer overclaims

Rewrote the "what this assertion does and does not prove" paragraph in
`fill_order_test.dart`'s first test: `lastStroke > lastFill` only proves a
stroke exists somewhere after the last fill in walk order — true of any
document whose final region's boundary is drawn after its own fill,
independent of whether anything actually overlaps on screen. It stays as an
anti-vacuity floor (and still reddens under the sorted-buffer mutation), but
the comment now names `fixtures_test.dart`'s `strokeInkInsideFill`-based
guard (337 logical pixels) as where the real overlap property is proved,
instead of implying this line proves it.

### Gate commands, verbatim

`flutter test` tail:
```
00:06 +561 ~1: .../tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:06 +562 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:06 +563 ~1: .../tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:06 +564 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:06 +565 ~1: All tests passed!
TEST_EXIT=0
```
565 passed (up from 563 — the two new tests), 1 pre-existing skip, 0 failures.

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
ANALYZE_EXIT=0
```

`dart format --output=none --set-exit-if-changed .`: first run printed
`Formatted 92 files (1 changed)` (`gpu_comparison.dart`, a real failure).
Ran `dart format test/support/gpu_comparison.dart`, then:
```
Formatted 92 files (0 changed) in 0.14 seconds.
FORMAT_EXIT=0
```

`git status --short` before staging: only the two files below, no
`analysis_options.yaml`.

### Commit

```
git add packages/jet_cad_2d_flutter/test/gpu/fill_order_test.dart \
        packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart
git commit -m "test(gpu): fix round 1 -- permute's stride gets a permanent test"
```
