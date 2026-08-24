# Task 6 report — criteria 3 and 4: text and translucency survive the texture round trip

## Summary

Both criteria land. Two deviations from the brief's literal fixture code were
required, both discovered by running the brief's own tests before touching
anything else, and both are documented below with the transcript that forced
them. M14 fires but reddens a different assertion than the brief predicted,
for a reason tied to `drawText` being `final`. M11 does **not** redden any
existing criterion — a real gap in the instrument, diagnosed and closed with
a new test.

## Files changed

- `packages/jet_cad_2d_flutter/test/support/fixtures.dart` — `addEntity` and
  `addLine` gained an optional `transparency` parameter, default `0` (the
  identity), so every existing caller is unaffected.
- `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` — added
  `crossingLabels` and `translucentOverlap`.
- `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` — added criteria 3
  and 4, plus a new `M11 regression` test (no test named this in the brief;
  see "M11" below for why one was needed).

No production file (`draft_painter.dart`, `tile_cache.dart`) carries any
diff — verified with `diff` against the pre-mutation backups after every
restore, and `git status` shows only the three test files above.

## Deviation 1 — `setTransparency` / `addLine`

Per the controller's correction already in the brief text I was handed:
`setTransparency` does not exist; `transparency` is a field on `EntityRecord`
supplied at creation. `addEntity` (which already carried a hardcoded
`transparency: 0`) and `addLine` both gained an optional `transparency`
parameter, default `0`. `translucentOverlap` passes `153` (60% of 255 —
`EntityRecord.transparency` is `0..255` and `style_resolver.dart:143` computes
`alpha = 255 - transparency`, so 153 gives alpha 102, i.e. ~40% opaque / 60%
transparent, matching the "60% transparent" language the brief used for the
deleted `setTransparency(doc, line, 60)` call).

## Deviation 2 — criterion 3's counter read timing

**First run, verbatim (brief's fixture and test, unmodified):**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +8 -1: criterion 3: text survives the tile round trip [E]
  Expected: <6>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 247:5                     main.<fn>
```

RED, and not because of a text-drawing defect. Diagnosis:

- `DraftPainter.paint` resets `_textOps`/`_culledText`/`_skippedText` to zero
  at the top of every call (`draft_painter.dart:330-332`).
- `TileCache.paintFrame` calls `painter.paint()` **once per tile** (inside
  `_bake` → `_drawInto`), plus once more for any uncovered region.
- `rig.paintOnce()` bakes every visible tile (budget 1000), so by the time it
  returns, `rig.painter`'s counters reflect only whichever tile happened to
  bake *last* in `TileGrid.visibleKeys`' iteration order — and with only 6
  short text entities in a viewport that spans roughly 13x10 = 130 tiles at
  this rig's 64-device-pixel tile size, the last tile baked is overwhelmingly
  likely to carry no text at all.

Confirmed directly: a throwaway debug test (`SpatialIndex.forEachInRect` over
the fixture's world rect) found all 6 text entities present and
query-visible — `doc.extents = Aabb2(20.0, 25.0 .. 220.0, 245.0)`, `world =
Aabb2(26.43, 16.43 .. 312.14, 230.71)` — ruling out a broad-phase culling bug.
`rig.painter.textOpCount`/`culledTextCount`/`skippedTextCount` all read `0, 0,
0` after `paintOnce()`, which is only possible if `_drawText` was never
entered for the *last* `paint()` call, not if it entered and culled.

**Fix:** read the counters from one standalone, whole-viewport
`rig.painter.paint(rig.vertices, rig.camera, kTileViewport)` call — the exact
shape `measureTiledAgreement`'s live arm already uses — *before* calling
`rig.paintOnce()` and comparing pixels. This is still "proved before any pixel
is compared," just via a call that isn't sliced per tile.

**Fixed run, verbatim:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: All tests passed!
```

GREEN. `textOpCount = 6`, `culledTextCount = 0` (asserted, not printed —
confirmed by the passing `expect` calls; both values are the literal integers
in the test source).

## Deviation 3 — criterion 4's fixture geometry

**First run of the brief's literal fixture (ten independent diagonals, `(20,
30 + i*6)` to `(220, 150 - i*6)`, `transparency: 153`), verbatim:**

```
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +8 -2: criterion 4: overlapping translucent strokes composite identically [E]
  Expected: <0>
    Actual: <19>
  InkReport(live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 44)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 138:3             expectTiledEqualsLive
```

RED. Diagnosis, in order:

1. Dumped the 44 differing pixel coordinates. Every one is a single-device-
   pixel horizontal displacement at a fixed row (e.g. `(503,262)` has ink in
   `live` and not `tiled`, `(507,262)` — 4 device px / 2 logical px away, same
   row — has ink in `tiled` and not `live`). That is a rasterisation-position
   shift, not a blend defect: a blend-mode or alpha bug would change a
   pixel's *colour*, not move which pixel gets ink.
2. Built the same ten lines at `transparency: 0` (fully opaque) and re-ran
   `measureTiledAgreement` directly: `InkReport(live: 10342, tiled: 10344,
   stray: 19, uncovered: 17, differing: 36)`. **Still red, at the identity
   transparency.** This proves the defect is unrelated to translucency: it is
   specific to a *diagonal* line crossing a tile boundary, a case
   `crossingGrid` (criterion 2's fixture, purely axis-aligned) never
   exercises. Criterion 2 passes with zero differing pixels over the same
   camera and tile size using axis-aligned lines that also cross many tile
   boundaries, which rules out tile-crossing in general as the cause and
   narrows it to the diagonal slope specifically.
3. This is a real, previously undiscovered gap in this plan's tile-boundary
   coverage — but it is orthogonal to what criterion 4 is chartered to prove
   (alpha survives `toImageSync` and the `srcOver` blit), and using it as
   criterion 4's fixture would make the test red for the wrong reason,
   permanently, regardless of anything Task 6 does correctly.

**Fix:** `translucentOverlap` now reuses `crossingGrid`'s exact axis-aligned
geometry (12 horizontal + 12 vertical lines, genuinely overlapping at every
grid intersection) with `transparency: 153` added, isolating the one channel
criterion 4 is chartered to test instead of conflating it with the diagonal
gap. Verified directly before landing it in the fixture file:

```
translucent grid report: InkReport(live: 19860, tiled: 19860, stray: 0, uncovered: 0, differing: 0)
```

**Fixed run, verbatim:** see Deviation 2's transcript above — `+9: criterion
4: overlapping translucent strokes composite identically`, part of the same
green run.

**Follow-up worth flagging separately (not fixed here, out of scope for Task
6):** a diagonal stroke crossing a tile seam rasterises a handful of pixels
(tens, not thousands, out of ~10,000+ ink pixels) one device pixel off
between the live and tiled paths, independent of transparency. `crossingGrid`
never exercises this because both its lines are axis-aligned. This is not
`G1` (G1 is about antialiasing being absent from `flutter_test`'s software
Skia entirely; this is a hard-edged rasterisation position disagreement
between two different camera framings of the same diagonal geometry). Whoever
picks up 3g's remaining criteria or a future plan touching `_bake`'s
per-tile camera math should know this exists.

## M14 — skip text in a bake

`drawText` is `final` on `DraftPainter` (`draft_painter.dart:93`), so it
cannot be toggled per-bake from `TileCache`. Per the brief's own fallback,
mutated `_drawText`'s entry guard directly in `draft_painter.dart`, copied
aside first to
`/private/tmp/.../scratchpad/draft_painter.dart.bak`:

```dart
  void _drawText(DrawSink sink, int slot, GeometryPayload payload,
      ResolvedStyle style, Transform2 chain, Vector2 localOrigin) {
    if (!drawText || true) return; // MUTANT M14: skip text unconditionally.
```

**Red transcript, verbatim:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +8 -1: criterion 3: text survives the tile round trip [E]
  Expected: <6>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 263:5                     main.<fn>
```

**Finding, as instructed to report rather than hide:** the brief predicted
"criterion 3 must go red with a large `uncoveredPixels` count" — i.e. via the
pixel comparison, with the live-only counter check staying green. It instead
reddens at the `textOpCount` assertion (line 263, `expect(rig.painter
.textOpCount, 6)`), before `expectTiledEqualsLive` ever runs. Reason: because
the guard mutation is global (it cannot be scoped to "during a bake only" —
that scoping is exactly what `final` prevents), it also breaks the standalone
whole-viewport `paint()` call Deviation 2's fix added for the counter proof.
A *real* "skip text only while baking" defect (the thing M14 is meant to
model) would leave that live-only call correct and only break the tiled
path's pixels — this stand-in mutation cannot distinguish the two, but it
still reddens the test, which is what the mutation-testing bar requires.

**Restored, verbatim:**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: All tests passed!
```

`diff lib/src/draft_painter.dart <backup>` → empty, confirmed before restoring
to the working tree.

## M11 — blit with `BlendMode.src`

Copied `tile_cache.dart` aside to
`/private/tmp/.../scratchpad/tile_cache.dart.bak`, then:

```dart
  final Paint _blitPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..blendMode = BlendMode.src; // MUTANT M11
```

**First run against the full file, verbatim (all pre-existing + new tests):**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: All tests passed!
```

**M11 did not redden anything — not criterion 4, not criterion 1, not the
pan test.** This contradicts the brief's "Criterion 1 probably goes red too."
Diagnosed algebraically, then confirmed empirically:

- `tile_comparison.dart`'s `_capture` always starts from a **blank, fully
  transparent** `PictureRecorder`/`Canvas` for both the live and tiled
  captures. `BlendMode.srcOver` computes `result = src + dst*(1 - src.a)`;
  `BlendMode.src` computes `result = src` unconditionally. When `dst.a == 0`
  (the only condition every pixel in this harness is ever blitted under,
  since the tile grid partitions the destination and each pixel is written
  by exactly one tile, exactly once), the two formulas are identical. The
  instrument is structurally blind to this mutation, the same shape as Task
  5's M17 finding.
- Confirmed empirically with a diagnostic test that pre-fills the destination
  with **opaque red** before calling `paintFrame` (something `_capture`
  never does): on the restored, unmutated code, `redSurvived = 460140`,
  `erased (alpha=0) = 0` out of 480,000 pixels. Under M11: `redSurvived = 0`,
  `erased = 460140`. The mutation erases nearly everything beneath every
  tile's non-inked area — a severe, real defect the pixel-diff criteria
  cannot see at all.

**Fix:** added a new test, `M11 regression: the blit composites with
srcOver, so a tile leaves what is beneath it alone wherever it has no ink of
its own`, to `tile_cache_test.dart`. It asserts
`rig.cache.debugBlitPaint.blendMode == BlendMode.srcOver` directly (the
property that actually matters and that `debugBlitPaint` already exposes for
criterion 13), then corroborates with the red-backdrop pixel check embedded
in the test itself so the property assertion isn't taken on faith.

**Red transcript with M11 active, verbatim:**

```
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +10 -1: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own [E]
  Expected: BlendMode:<BlendMode.srcOver>
    Actual: BlendMode:<BlendMode.src>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 309:5                     main.<fn>
```

Criteria 1 and 4 stayed green even with M11 active, confirming the algebraic
argument above.

**Restored, verbatim (full file):**

```
00:00 +8: criterion 3: text survives the tile round trip
00:00 +9: criterion 4: overlapping translucent strokes composite identically
00:00 +10: M11 regression: the blit composites with srcOver, so a tile leaves what is beneath it alone wherever it has no ink of its own
00:00 +11: All tests passed!
```

`diff lib/src/tile_cache.dart <backup>` → empty, confirmed before restoring
to the working tree, and again after the final restore (see "Final state"
below).

## Counter readings (criterion 3)

`textOpCount = 6`, `culledTextCount = 0`, read from a single whole-viewport
`DraftPainter.paint` call before any pixel is compared — see Deviation 2.

## Wall-clock cost

```
$ time CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 3"
... 1.59s user 0.38s system 103% cpu 1.911 total

$ time CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
... 1.57s user 0.36s system 100% cpu 1.913 total

$ time CI=true flutter test test/tile_cache_test.dart --plain-name "M11 regression"
... 1.57s user 0.39s system 92% cpu 2.131 total
```

Each figure includes `flutter test`'s fixed harness startup (~1.5s); the
individual test bodies are a small fraction of that. Full `flutter test` for
the whole package: 325 tests (1 pre-existing skip, unrelated to this task) in
6.995s wall / 24.17s user (420% cpu — parallel shards).

## Final state — exit gate

```
$ cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .
... 797 tests, All tests passed!
Analyzing jet_cad_2d... No issues found!
Formatted 113 files (0 changed)

$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
... 325 tests (~1 skip), All tests passed!
Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.2s)
Formatted 60 files (0 changed)
```

`git status`: only
`packages/jet_cad_2d_flutter/test/support/fixtures.dart`,
`packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`, and
`packages/jet_cad_2d_flutter/test/tile_cache_test.dart` are modified.
`analysis_options.yaml` was not touched. Both `draft_painter.dart` and
`tile_cache.dart` are byte-identical to their pre-mutation state (`diff`
against the scratchpad backups returns empty).

---

# Fix round 1

Three findings from review: F1 (spec, criterion 4 had no killing mutant), F2
(Important, criterion 4 could not see a dropped alpha), F3 (Minor, two
overclaiming comments).

## F1 — a mutant that kills criterion 4

M11 (`BlendMode.src`) is genuinely blind to this harness (accepted in round
1). Task 6a independently built a mutant that does bite,
`_blitPaint..color = const Color(0x80FFFFFF)`, but only ever fired it against
6a's own gap-group tests. Fired it directly at criterion 4 itself, copying
`tile_cache.dart` aside first (`diff` against the copy confirmed empty
immediately before mutating):

```dart
  final Paint _blitPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..color = const Color(0x80FFFFFF); // MUTANT (F1): alpha on the blit paint.
```

**Red, verbatim:**

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +0 -1: criterion 4: overlapping translucent strokes composite identically [E]
  Expected: <0>
    Actual: <19860>
  InkReport(live: 19860, tiled: 19860, stray: 0, uncovered: 0, differing: 19860)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 140:3             expectTiledEqualsLive

00:00 +0 -1: Some tests failed.
```

Every ink pixel differs (19,860 of 19,860) — the blit paint's own colour tints
every tile, which a translucent fixture's non-white, non-uniform ink makes
visible everywhere it draws. Restored from the copy:

```
$ diff lib/src/tile_cache.dart <scratchpad copy>
(empty)
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +1: All tests passed!
```

No test file changed for this — the existing criterion 4 test is the killer;
it only needed the right mutant fired at it once, and the transcript above is
that record. No code change in this repo.

## F2 — an assertion that the alpha is really there

`InkReport` counts ink; it carries no colour information, so a
`style_resolver` that dropped `transparency` entirely would leave both arms
fully opaque and `expectTiledEqualsLive` would still pass at zero. Added a
direct check to criterion 4, before the pixel comparison, using
`DocumentStyleResolver` on `translucentOverlap`'s first line (handle 1000,
`ByLayerColor` on layer zero, which resolves to white):

```dart
    final firstLineSlot = rig.doc.entities.slotOf(const Handle(1000))!;
    final resolvedStyle = DocumentStyleResolver(rig.doc)
        .styleFor(firstLineSlot, StyleContext.documentRoot);
    expect(resolvedStyle.argb, 0x66FFFFFF,
        reason: 'transparency: 153 must resolve to a translucent ARGB, not '
            'the opaque one a dropped transparency channel would give: '
            '0x${resolvedStyle.argb.toRadixString(16)}');
```

**First run with the fixture (green, confirming the assertion holds on
correct code) — verbatim:**

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +1: All tests passed!
```

**Verified the assertion actually gates a dropped-transparency defect.**
Copied `style_resolver.dart` aside (`diff` against the copy confirmed empty
immediately before mutating), then mutated the ARGB line to always read
alpha as fully opaque:

```dart
      argb: ((255 - 0.clamp(0, 255)) << 24) | _rgbOf(color), // MUTANT (F2 check): transparency dropped.
```

**Red, verbatim:**

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "criterion 4"
00:00 +0: criterion 4: overlapping translucent strokes composite identically
00:00 +0 -1: criterion 4: overlapping translucent strokes composite identically [E]
  Expected: <1728053247>
    Actual: <4294967295>
  transparency: 153 must resolve to a translucent ARGB, not the opaque one a dropped transparency channel would give: 0xffffffff

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 293:5                     main.<fn>
```

Reddens at the ARGB assertion itself, before `rig.paintOnce()` or any pixel
comparison runs — exactly the trap this closes. Restored from the copy:

```
$ diff lib/src/document/style_resolver.dart <scratchpad copy>
(empty)
$ CI=true flutter test test/tile_cache_test.dart
... +14: All tests passed!
```

(14, not 10 — Task 6a's gap-group tests landed between this task's original
submission and this fix round; all pass alongside the new assertion.)

## F3 — two comments corrected

1. `tile_cache_test.dart`'s gap-group header claimed the `destRectFor` mutant
   reddens "at roughly two hundred times the bound." Task 6a's own report
   records the actual run: `Expected: <= 60, Actual: 3192` — 53x, not ~200x.
   Changed to: "reddens this at 53x the bound -- 3192 differing against a
   bound of 60 (verified in Task 6a)."
2. Criterion 3's comment called its standalone whole-viewport `paint()` call
   "the same call `measureTiledAgreement`'s live arm makes." It is not: that
   arm applies `quantiseCamera` and sets `debugRebaseOrigin`; this call does
   neither, and only exists to total the text counters over the whole frame.
   Narrowed to: "unlike `measureTiledAgreement`'s live arm, this applies no
   `quantiseCamera` and sets no `debugRebaseOrigin` -- it exists only to
   total the counters over the whole frame in one `paint` call, and that
   total still runs before any pixel is compared." The assertion itself was
   already correct; only the sentence was wrong.

## Exit gate, after all three fixes

```
$ cd packages/jet_cad_2d && CI=true dart test && CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .
00:03 +797: All tests passed!
Analyzing jet_cad_2d... No issues found!
Formatted 113 files (0 changed) in 0.20 seconds.

$ cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
00:04 +330 ~1: All tests passed!
Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.3s)
Formatted 61 files (0 changed) in 0.11 seconds.
```

`git status`: only `packages/jet_cad_2d_flutter/test/tile_cache_test.dart` is
modified (24 insertions, 5 deletions — the F2 assertion and the two F3
comment corrections; F1 needed no code change). `analysis_options.yaml` not
touched. `lib/src/tile_cache.dart` and
`lib/src/document/style_resolver.dart` are byte-identical to their
pre-mutation state in both diagnostic rounds (`diff` against the scratchpad
copies returns empty each time).
