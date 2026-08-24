# Task 8 report — `DraftCanvas` integration, and the table signal that reaches the frame

**Status: complete, both packages green.**

Criterion 7 is closed. `DraftCanvas` gains `tiles`, `tileDevicePixels` and
`onPaintForTest`; `TileCache.paintFrame` gains `required int tablesRevision`;
the engine's `TableListenable` is adapted into the widget's repaint
`Listenable`; and the live path quantises its camera like the tiled one.

---

## 1. The finding: criterion 7's name promised a claim its assertion could not see

This is the **seventh** instance of the plan's recurring defect — a gate that
cannot see what it claims to measure — and it was in the brief's own test.

The brief's test is named

> `criterion 7: a layer edit repaints and drops the generation`

and asserts exactly one thing:

```dart
expect(paints, greaterThan(paintsBefore), ...);
```

That is the first half. The second half — *the tiles the old layer table was
baked against are thrown away* — has no assertion at all. The two halves are
independently breakable, and I proved it: **M8b** (below) removes the
`_dropGeneration()` from the revision branch in `paintFrame` and leaves
everything else alone. The frame still happens, `paints` still grows, and the
brief's test as written stays **green over a cache that shows stale pixels
forever**. That is precisely the failure mode the brief's own comment warns
about, reintroduced from the other side.

The test therefore also asserts the drop, exactly:

```dart
expect(cache.invalidationCount, invalidationsBefore + tilesBefore, ...);
```

with a preceding `expect(tilesBefore, greaterThan(0))` so "every tile was
dropped" cannot be satisfied vacuously by a cache that never baked one.

Reaching that counter needs the cache the widget actually built, so
`DraftCanvasState.tileCache` is public — for the reason `painter` and `sink`
already are.

**Where the deviation lands.** The brief's assertion is kept verbatim, with its
verbatim `reason`. One assertion was added. Nothing was weakened.

## 2. What "shape would make the claim false" turned up

Two shapes were checked against the fixture:

- **Tiles off.** The brief's criterion only exercises `tiles: true`. But a
  layer carries the colour, lineweight and linetype of every entity that
  references it, so a table edit changes the drawing *whether or not the cache
  is on* — and with `tiles: false` the cache's invalidation is not merely
  unreached, it does not exist. `draft_canvas_test.dart` gains
  **`a table edit repaints with tiles off too`**, which asserts
  `paintBoxOf(tester).debugNeedsPaint` after a layer add on a default canvas.
  M8 kills it too, and it is the arm that says the adapter is not a tile-cache
  accessory.
- **Re-attach.** See §4.

One shape was checked and deliberately **not** built: a pixel-level assertion
that the post-edit frame is not stale. It is already implied — criterion 2
(landed) requires a rebaked tiled frame to equal the live frame with zero
differing pixels, and criterion 7 now requires every pre-edit tile to be gone.
A tile that is gone and a rebake that is exact leave no third place for a stale
pixel to hide. Recording this rather than building it.

## 3. Where the revision drop goes, and why it is `_dropGeneration` and not
`_dropEverything`

The brief's step 2 says "a change drops everything". I used **`_dropGeneration()`**
— the tiles go, the lattice stays — and the reasoning is the file's own, one
method up:

> *A definition edit is not a scale change. Clearing `_grid` here would renumber
> every key for no reason, bump `generation`, and throw away the one thing — the
> anchor — that lets the refilled tiles blit at whole device pixels against the
> cameras already on screen.*

Every word of that holds for a table edit. It is also what criterion 9 already
pins: *"a load starts a new generation, an edit does not."* A layer edit is an
edit. `_dropEverything()` would have made criterion 9's own distinction
incoherent — a colour change would have counted as a document replacement.

Dropping the *whole* generation rather than a subset is still right: a
lineweight or linetype change moves a stroke's extent, so a tile that never
baked an entity can still owe pixels for it — the same argument the definition
arm gives.

`_tablesRevision` starts at `-1`. A revision starts at zero and only increases,
so no document can present that value: the first frame always takes the drop
branch, over an empty cache, where it costs and asserts nothing. A sentinel of
`0` would have made the first frame's behaviour depend on whether the document
had been given its standard tables yet.

`invalidationCount`'s doc comment is updated: it now counts the table arm too,
because it is the same event through a different door.

## 4. The listener, and both teardown paths

**Where the adapter removes its listener.**

- `_TableListenableAdapter.dispose()` calls `source.removeListener(_forward)`
  **before** `super.dispose()` (`draft_canvas.dart`, the adapter class).
- `DraftCanvasState._detach()` calls `_tables.dispose()`, alongside
  `_changes.dispose()` and `tileCache?.dispose()`.
- `_detach()` is called from **both** teardown paths — `dispose()` and
  `didUpdateWidget`'s re-attach branch — and it is one method precisely so the
  two cannot drift.

The `didUpdateWidget` condition gained `widget.tiles != oldWidget.tiles ||
widget.tileDevicePixels != oldWidget.tileDevicePixels`.

**How it is verified on both paths.** Not by inspection, and not by a proxy.
`DocumentTables` had no instrument at all for this, so one was added:

- `_TablesNotifier.listenerCount` and `DocumentTables.debugListenerCount`
  (`tables.dart`), documented as test-only in the same prose style as
  `TileCache.holds` / `tilesHolding` / `debugBlitPaint`. No `@visibleForTesting`
  annotation, matching that convention.

`draft_canvas_test.dart`'s **`the table adapter detaches on both teardown
paths`** then walks the whole lifecycle:

| step | assertion |
| --- | --- |
| before mounting | `debugListenerCount == 0` — the baseline is examined, not assumed |
| mounted, `tiles: true` | `== 1`, and `tileCache` is non-null |
| re-attach via `tileDevicePixels: 128` | `== 1` |
| re-attach again via `tileDevicePixels: 256` | `== 1` |
| after both | the cache is `isNot(same(firstCache))` |
| unmounted | `== 0` |
| a layer edit after unmount | `returnsNormally` |

The re-attach is done **twice** on purpose: once leaves "leaks one per
re-attach" and "attaches one, correctly" indistinguishable to anything phrased
as `greaterThan(0)`; a second one makes the *growth* the thing measured.

The last row is the other half of the ruling: removal is not the same as
disposal. A `ChangeNotifier` disposed while still subscribed does not go quiet —
the next table mutation calls it and `notifyListeners` throws out of the
caller's `add`. A document outlives its canvases, so that must not happen.

## 5. Deviation: sixteen text goldens re-recorded

**This is the one deviation with a footprint, and it is a direct consequence of
the ruling that the live path must quantise.**

`_DraftCustomPainter.paint`'s non-tiled branch now draws
`quantiseCamera(camera.value, devicePixelRatio)`. Sixteen golden PNGs moved —
all of them text ladders; the stroke, dash and fill ladders did not move at all.

**Diagnosis, not assumption.** `lib/src/draft_canvas.dart` was copied to
`/tmp/draft_canvas.dart.bak`, the single line replaced by
`final quantised = camera.value; // DIAGNOSIS ONLY`, and the golden suite run:

```
00:01 +35: .../test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:01 +35: All tests passed!
```

Restored by `cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart`, proven by
`diff` (empty) — never by `git checkout`. So the live-path quantisation is the
whole cause, and nothing else in this task touches those pixels.

**The magnitude is exact, and it is the documented worst case.** A probe over
the goldens' own camera:

```
dpr=1.0 raw e=10.0 f=292.5 -> e=10.0 f=293.0
        dLogical=(0.0, 0.5)                  dDevice=(0.0, 0.5)
dpr=3.0 raw e=10.0 f=292.5 -> e=10.0 f=292.6666666666667
        dLogical=(0.0, 0.16666666666668561)  dDevice=(0.0, 0.5000000000000568)
```

`ViewportTransform.fit(kWorld, kGoldenViewport)` puts these ladders at
`f = 292.5` — **exactly** the half-device-pixel tie, the worst case of the
±0.5 device pixel `quantiseCamera` already documents, and `roundToDouble()`
rounds half away from zero. `e = 10.0` is already integral, so the frame moved
**down by half a device pixel and sideways not at all**. Glyph coverage
resamples at a new subpixel phase; axis-aligned strokes do not cross a
threshold. That is the whole effect.

Pre-regeneration diffs, all sixteen:

```
Golden "text_ladder_1.png":             0.14%,  692px
Golden "text_ladder_2.png":             0.36%, 1747px
Golden "text_ladder_3.png":             0.46%, 2206px
Golden "text_ladder_4.png":             0.27%, 1278px
Golden "text_ladder_5.png":             0.00%,    6px
Golden "text_lod_ladder_1.png":         0.01%,   48px
Golden "text_lod_ladder_2.png":         0.01%,   48px
Golden "text_lod_ladder_3.png":         0.01%,   48px
Golden "vertices/text_ladder_1.png":    0.00%,    2px
Golden "vertices/text_ladder_2.png":    0.10%, 1048px
Golden "vertices/text_ladder_3.png":    0.02%,  182px
Golden "vertices/text_ladder_4.png":    0.19%, 2052px
Golden "vertices/text_ladder_5.png":    0.00%,    3px
Golden "vertices/text_lod_ladder_1.png":0.01%,   69px
Golden "vertices/text_lod_ladder_2.png":0.01%,   69px
Golden "vertices/text_lod_ladder_3.png":0.01%,   69px
```

Regenerated with `CI=true flutter test test/golden --update-goldens`, and `git
status` confirmed exactly those sixteen PNGs changed and nothing else. Both
golden test files carry a header note recording the cause, the exact
displacement and why only text moved, so a future reader is not left guessing
why a pinned drawing was repinned.

**Why re-recording is the right answer rather than exempting the live path.**
The rule is that both paths draw the same camera, so the tiled frame *is* the
live frame. A `DraftCanvas` that quantised only when `tiles` was on would shift
the drawing by half a device pixel every time the flag was toggled, and the
plan's central exactness claim would be false of the shipped widget even though
criterion 1 (which builds its own live frame in `tile_comparison.dart` and
quantises it by hand) would keep passing. That would have been an eighth
instance of the recurring defect. The goldens were pinning the old live path;
the live path legitimately changed.

## 6. Other call sites of `paintFrame` (R1)

R1 named `tile_fixture.dart`. There were **four** call sites, not one:

- `test/support/tile_fixture.dart` — `TileRig.paintOnce`
- `test/support/tile_comparison.dart:94`
- `test/tile_cache_test.dart` × 3

All now pass `tablesRevision: <doc>.tables.mutationRevision`, read live rather
than pinned to a constant: a rig that mutates a table between two frames must be
able to see the second frame invalidate, and a literal there would have made
that untestable through the rig.

## 7. Allocation

`quantiseCamera` on the live path allocates at most one `ViewportTransform` per
*frame* (and returns the same instance when the camera is already quantised —
which is why it was written that way). That is O(1) per frame, not per entity.
`test/invariants/paint_allocation_test.dart` passes unchanged.

---

## Transcripts

### The failing run (criterion 7 before the wiring existed)

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart

00:00 +0 -1: loading .../test/tile_invalidation_test.dart [E]
  Failed to load ".../test/tile_invalidation_test.dart":
  Compilation failed for testPath=.../test/tile_invalidation_test.dart:
  test/tile_invalidation_test.dart:483:13: Error: No named parameter with the name 'tiles'.
              tiles: true,
              ^^^^^
  lib/src/draft_canvas.dart:56:9: Context: Found this candidate, but the arguments don't match.
    const DraftCanvas({
          ^^^^^^^^^^^
  test/tile_invalidation_test.dart:494:66: Error: The getter 'tileCache' isn't defined for the type 'DraftCanvasState'.
   - 'DraftCanvasState' is from 'package:jet_cad_2d_flutter/src/draft_canvas.dart' ('lib/src/draft_canvas.dart').
  Try correcting the name to the name of an existing getter, or defining a getter or field named 'tileCache'.
          tester.state<DraftCanvasState>(find.byType(DraftCanvas)).tileCache!;
                                                                   ^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  .../test/tile_invalidation_test.dart: loading .../test/tile_invalidation_test.dart
```

### The passing run

```
$ cd packages/jet_cad_2d && CI=true dart test
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.15 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:03 +340 ~1: .../test/vertices_differential_test.dart: the comparison is not vacuous
00:03 +341 ~1: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 62 files (0 changed) in 0.08 seconds.
```

341 tests, up from 338 at the start of the task (3 added). 1 skipped, unchanged.

---

## Mutants

Every mutation was made by `cp`-ing the file aside, editing in place, running,
then `cp`-ing back and proving the restore with `diff`. **No `git checkout` was
used at any point.**

### M8 — drop `_tables` from the merge, keep the revision read in `paintFrame`

```dart
_repaint = Listenable.merge([widget.camera, _changes]); // M8
```

```
00:00 +21 -1: .../test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation [E]

  The following TestFailure was thrown running a test:
  Expected: a value greater than <1>
    Actual: <1>
     Which: is not a value greater than <1>
  a layer edit must cause a frame at all -- the half a counter inside paint could never reach

  #4      main.<anonymous closure> (file:///.../test/tile_invalidation_test.dart:515:5)
```

and, in the same run:

```
00:00 +23 -1: .../test/draft_canvas_test.dart: a table edit repaints with tiles off too

  The following TestFailure was thrown running a test:
  Expected: true
    Actual: <false>
  the drawing changed, so a frame is owed
```

**This is the asymmetry the brief asked to be recorded.** The cache's own logic
is untouched by M8 and remains correct in every particular; it is simply never
reached. A revision counter inside `paintFrame` is right and unreachable, and
only a *frame count* can tell the difference. Restored:

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8 RESTORED (no diff)
```

### M8b — keep `_tables` in the merge, delete the drop from the revision branch

The mutant the brief's own test would not have caught.

```dart
// M8b
if (tablesRevision != _tablesRevision) {
  _tablesRevision = tablesRevision;
}
```

```
00:00 +8: criterion 7: a layer edit repaints and drops the generation

  The following TestFailure was thrown running a test:
  Expected: <8>
    Actual: <0>
  every tile baked before the edit was drawn against the old layer table and must have been thrown
  away

  #4      main.<anonymous closure> (file:///.../test/tile_invalidation_test.dart:521:5)
```

The frame-count assertion passed. Only the added assertion went red — the two
halves are separable mutants, which is the whole point of asserting both.
Restored:

```
$ cp /tmp/tile_cache.dart.bak lib/src/tile_cache.dart && diff /tmp/tile_cache.dart.bak lib/src/tile_cache.dart
M8b RESTORED (no diff)
```

### M8c — the adapter disposes without unsubscribing

```dart
@override
void dispose() {
  // M8c: the removal deleted, the disposal kept.
  super.dispose();
}
```

```
00:00 +16: the table adapter detaches on both teardown paths

  The following TestFailure was thrown running a test:
  Expected: <1>
    Actual: <2>
  re-attaching must replace the listener, not add one

  #4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:509:7)
```

Red at the **first** re-attach, on the `didUpdateWidget` path — the leak the
controller's ruling named, caught by count and not by symptom. Restored:

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8c RESTORED (no diff)
```

### M8d — `didUpdateWidget` stops watching `tiles` / `tileDevicePixels`

```dart
        false) { // M8d
```

```
00:00 +16: the table adapter detaches on both teardown paths

  The following TestFailure was thrown running a test:
  Expected: not same instance as <Instance of 'TileCache'>
    Actual: <Instance of 'TileCache'>
  tileDevicePixels is fixed at the cache's construction, so a changed value that reused the cache
  would be ignored outright

  #4      main.<anonymous closure> (file:///.../test/draft_canvas_test.dart:512:5)
```

Restored:

```
$ cp /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart && diff /tmp/draft_canvas.dart.bak lib/src/draft_canvas.dart
M8d RESTORED (no diff)
```

Full suite re-run after every restore: `341 tests, All tests passed!`

---

## Corrections to the brief, collected

1. `DraftColor.indexed(3)` does not exist — `const IndexedColor(3)`, as the
   controller ruled. The other three fields are kept off their defaults.
2. `paintFrame` has **four** call sites, not the one R1 named.
3. `import 'viewport_transform.dart'` is not needed in `draft_canvas.dart` —
   `quantiseCamera` lives in `tile_cache.dart`, and `unused_import` is an error
   in this package.
4. The revision branch should call `_dropGeneration()`, not `_dropEverything()`
   (§3).
5. Criterion 7's assertion did not cover the claim in its own name (§1).
6. Sixteen text goldens must be re-recorded, and the brief did not say so (§5).

## Files touched

- `packages/jet_cad_2d/lib/src/document/tables.dart` — `listenerCount`,
  `debugListenerCount`
- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — `tablesRevision`,
  `_tablesRevision`, `invalidationCount` doc
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` —
  `_TableListenableAdapter`, `tiles`, `tileDevicePixels`, `onPaintForTest`,
  `tileCache`, `_detach`, the tiled branch, the live path's quantisation
- `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` — criterion 7
- `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart` — two tests
- `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`,
  `test/support/tile_comparison.dart`, `test/tile_cache_test.dart` — call sites
- `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`,
  `text_lod_ladder_golden_test.dart` — header notes; 16 PNGs re-recorded

---

# Fix round 1

**One finding, accepted in full: the live path must not quantise, and the
sixteen goldens go back.**

The coordinator narrowed the spec's unqualified "the quantised camera drives
the live path too". The reasoning is correct and I had the trade backwards:
criterion 1's instrument quantises its own live arm explicitly at
`test/support/tile_comparison.dart:81`, so the tiled-equals-live gate never
depended on `DraftCanvas` doing it. What §5 of the original report treated as
"the goldens were pinning the old live path" was in fact an unrequested change
to the **default** rendering path — the one every caller with `tiles` off uses —
bought with sixteen re-recorded PNGs in a repository whose standing gate is
that no pre-existing golden is regenerated. The cost was real and the benefit
was zero. §5 is superseded by this section.

## 1. `DraftCanvas` quantises only in the tiled branch

`_DraftCustomPainter.paint`'s non-tiled branch draws `camera.value` again, as
it did before Plan 3g. The comment that claimed the opposite is replaced by one
that states the asymmetry and why it is deliberate, so the next reader does not
re-derive the unqualified rule from the spec and reintroduce this.

The tiled branch is unchanged and still quantises — **inside**
`TileCache.paintFrame`, which is where it always was:

```
$ grep -n "quantiseCamera" lib/src/draft_canvas.dart lib/src/tile_cache.dart
lib/src/draft_canvas.dart:386:    // `quantiseCamera` belongs to the tiled path and is applied inside
lib/src/tile_cache.dart:75:ViewportTransform quantiseCamera(
lib/src/tile_cache.dart:120:  /// Integral whenever both cameras came through [quantiseCamera], which is
lib/src/tile_cache.dart:348:    final quantised = quantiseCamera(camera, devicePixelRatio);
```

The only remaining mention in `draft_canvas.dart` is prose. `tile_cache.dart:348`
is the single call, at the top of `paintFrame`, and its result flows to the
grid, to every `destRectFor`, and to `_drawInto` — so **the uncovered-region
live draw is unaffected**: it already receives the quantised camera and never
went through the widget's branch. A tiled frame stays internally consistent
between its blits and its live fallback, which is the property criterion 1
actually rests on.

## 2. The sixteen PNGs, restored and then *proven* by running the code

Restored with `git restore --source=a9f60a5 -- packages/jet_cad_2d_flutter/test/golden`.
This is ordinary history recovery of committed content, not the reversion of a
mutation, so the no-`git checkout` rule does not apply — that rule governs
mutation testing, where the point is to prove the restore independently of the
index. The two header notes I had added went with the same restore; the diff
above confirms those files carried nothing else of mine.

Bytes coming back is not the proof that matters. This is:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden

00:00 +19: .../golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:00 +22: .../golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:00 +25: .../golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
00:00 +27: .../golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +29: .../golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
00:01 +30: .../golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.vertices)
00:01 +31: .../golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
00:01 +32: .../golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:01 +33: .../golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:01 +34: .../golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +35: .../golden/text_ladder_golden_test.dart: (tearDownAll)
00:03 +35: All tests passed!
```

All 35 golden-tagged tests pass against the pre-`6ca0789` PNGs — including the
stroke, dash and fill ladders, which never moved and would have caught a
narrowing that overshot. The restored images are what the reverted code
produces.

And the byte-level check the fix round asked for:

```
$ git diff --stat a9f60a5 -- packages/jet_cad_2d_flutter/test/golden
$
```

Empty. Not one file under `test/golden` differs from `a9f60a5` — PNGs or
`.dart`.

## 3. Nothing else depended on the unconditional quantisation

- **Criterion 1 and 2** (`test/tile_cache_test.dart`, via
  `test/support/tile_comparison.dart`): green. Their live arm builds its own
  frame and quantises it by hand; they never called `DraftCanvas`.
- **The uncovered-region live draw**: inside `paintFrame`, already quantised,
  untouched (§1).
- **Tests I added**: none of the three asserts anything about quantisation —
  criterion 7 counts frames and invalidations, the tiles-off test asserts
  `debugNeedsPaint`, the adapter test counts listeners. Nothing to narrow,
  nothing to delete.
- **Everything else**: the whole `jet_cad_2d_flutter` suite is green at the
  same 341 tests as before the fix round, so no test anywhere encoded the wider
  rule.

## 4. The asymmetry this leaves, named so it is not rediscovered

`DraftCanvas` now draws at two cameras that differ by up to half a device pixel
depending on `tiles`. **That is the accepted trade, not an oversight**, and the
direction of the asymmetry is the safe one: the default path is exactly what it
has always been, and only the opt-in path moves. Toggling `tiles` at runtime on
a live canvas would show a sub-pixel shift; nothing in the product does that
today, and a caller that wanted to would be choosing the tiled rendering for
the session, not flipping it per frame. Recorded here rather than guarded,
because a guard would have to assert the shift *exists*, and pinning an
accepted imprecision as a requirement is how it becomes impossible to remove.

## 5. Green, both packages

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
00:05 +340 ~1: .../test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:05 +341 ~1: All tests passed!

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 62 files (0 changed) in 0.08 seconds.
exit=0
```

```
$ cd packages/jet_cad_2d && CI=true dart test
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16 seconds.
exit=0
```

341 and 797, unchanged from the first round. The mutants M8, M8b, M8c and M8d
are unaffected by this change — none of them touched the live branch — and the
suite they kill is the same suite that is green above.

## 6. What is left of §5 of the first round

The diagnosis stands and is worth keeping: `ViewportTransform.fit(kWorld,
kGoldenViewport)` puts the text ladders at `f = 292.5`, exactly the
half-device-pixel rounding tie at the harness `dpr` of 3, so quantising that
camera moves the frame down by half a device pixel and sideways not at all.
That is why those sixteen and only those sixteen moved. It is now a measurement
of a change that was **not** made, and it is the reason the change was not
worth making.
