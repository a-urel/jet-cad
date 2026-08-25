### Task 5: The narrowing

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart` (criterion 1 and 1b records)

**Interfaces:**
- Consumes: `stripFor`, `debugLastStrip`, the Task 3 sweep.
- Produces: a `paintFrame` whose fallback walks the strip.

**The change.** In `paintFrame`'s fallback branch, replace

```dart
    canvas.save();
    canvas.clipRect(uncovered, doAntiAlias: false);
    _lastStrip = Offset.zero & viewport;
    _drawInto(
        canvas, viewport, quantised, painter, sink, vertices, origin, null);
    canvas.restore();
    _liveDraws++;
```

with

```dart
    canvas.save();
    // **The clip is unchanged, and that is a decision.** `_bake` states the
    // rule for itself -- "The query is padded; the clip is not." Drop this
    // line and the pad becomes overdraw onto tiles already blitted: the pixels
    // stay correct, so the sweep still reads zero, and the cost this whole
    // change exists to remove comes back silently.
    canvas.clipRect(uncovered, doAntiAlias: false);
    // **Walk the union, not the viewport.** The clip above only discards
    // drawing; the walk below is what costs. `DraftPainter.paint` derives its
    // index query from `camera.visibleWorld(viewport)`, so handing it the full
    // viewport tessellates the whole frame and throws most of it away -- which
    // is what every fallback did before this line, and why the frame's excess
    // read as a full live walk.
    final strip = stripFor(uncovered, viewport);
    _lastStrip = strip;
    canvas.translate(strip.left, strip.top);
    final q = quantised.worldToScreenMatrix;
    _drawInto(
        canvas,
        Size(strip.width, strip.height),
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
        painter,
        sink,
        vertices,
        origin,
        null);
    canvas.restore();
    _liveDraws++;
```

The camera offset and the canvas translate cancel: a world point mapping to screen `s` under `quantised` maps to `s - strip.topLeft` under the offset camera, and the translate puts it back. This is `_bake`'s own technique, which already does exactly this for a tile.

- [ ] **Step 1: Apply the change**

Make the edit above.

- [ ] **Step 2: Run the sweep — it must stay green**

```sh
CI=true flutter test test/tile_fallback_test.dart
```

Expected: both tests pass. The narrowing is not supposed to move a pixel.

**If criterion 2 fails**, the camera arithmetic is wrong — check the sign of `q.e - strip.left` against `_bake`'s `bake.e + pad` with its `into.translate(-pad, -pad)`. **If criterion 2b fails**, read the numbers before changing anything: the strip's translate reintroduces the `Float32` / `Float64` asymmetry behind Plan 3g's gap G5, and a bound slightly above 60 is a G5 finding, not a narrowing defect. Report it; do not raise the bound.

- [ ] **Step 3: Fire mutant M3 — criterion 1**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m3
```

In `stripFor`, replace `kTileSlack` with `-20.0` at all four call sites — a query 20 logical pixels **inside** the strip. Run:

```sh
CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"
```

Expected: **RED**, with non-zero `uncoveredPixels`. Record the exact numbers. Restore from `/tmp/tile_cache.m3` and confirm green.

**If it stays green, stop and report.** Criterion 1 is the gate that makes every other pixel claim in this plan mean something; a green M3 means the sweep is measuring nothing and the offsets or the fixture need work before anything else proceeds.

- [ ] **Step 4: Fire mutant M2 — criterion 1b**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m2
```

In `stripFor`, replace `kTileSlack` with `0.0` at all four call sites. Run the same test.

**Two outcomes, both acceptable, and the plan pre-commits to each:**

- **RED** — criterion 1b passes. Record the numbers.
- **GREEN** — M2 survives. This is the spec's anticipated gap **H5**, and it is not a failure of this task. `pad = 0` does not delete geometry the way M3's shrink does: the query is a rect intersection on entity bounds, so dropping the pad loses only entities lying wholly outside the strip whose **half stroke width** bleeds into it, and F1 appeared at only six of forty-one swept zoom factors. **Record H5 in the task report with the measured zeros**, keep the pad on `_bake`'s argument, and proceed. Do not invent a fixture to force a kill.

Restore from `/tmp/tile_cache.m2` either way and confirm green.

- [ ] **Step 5: Full suite, analyze, format**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

Expected: the same pass count as before this task plus nothing new — the narrowing changes no test's outcome.

- [ ] **Step 6: Commit**

```sh
git add lib/src/tile_cache.dart test/tile_fallback_test.dart
git commit -m "perf: the live fallback walks the uncovered strip, not the viewport

paintFrame clipped to the uncovered union and handed DraftPainter the whole
viewport, and the painter derives its index query from exactly that, so every
fallback tessellated the entire frame and the clip discarded most of it.

The clip is deliberately unchanged: _bake states the rule at its own call site,
and dropping it turns the pad into overdraw onto tiles already blitted, which
the sweep reads as zero because the pixels stay correct.

M3 -- a query shrunk 20 logical pixels -- reddens the sweep, which is what
makes every other pixel claim here mean anything."
```

---


---

## Controller amendment — binding

Task 3 landed under a controller ruling, so the code you are replacing is not
quite what "The change" quotes above. What is actually in `paintFrame`'s
fallback branch right now is:

```dart
    canvas.save();
    canvas.clipRect(uncovered, doAntiAlias: false);
    _lastStrip = stripFor(uncovered, viewport);
    _drawInto(
        canvas, viewport, quantised, painter, sink, vertices, origin, null);
    canvas.restore();
    _liveDraws++;
```

The strip is already computed and already recorded; what is missing is that
nothing walks it. Replace that block with the "with" block given above,
verbatim, including its two comments. In the result, `final strip =
stripFor(uncovered, viewport);` and `_lastStrip = strip;` replace the single
recording line — do not leave a duplicate `stripFor` call behind.

Also amend `debugLastStrip`'s doc comment: its first line currently reads "the
rectangle the fallback **owes**", which was true only while the walk was still
the whole viewport. It now reads:

```dart
  /// The rectangle the fallback walked on the most recent frame, or `null` if
  /// no fallback ran. Test-only, and **read-only**.
```

Keep the rest of that doc comment unchanged.

Finally: Step 6 stages `test/tile_fallback_test.dart`, but no step here edits
it. That is expected — staging an unchanged file is a no-op. The criterion 1
and 1b records the Files block mentions go in your **task report**, and Task 8
copies them into the mutation log. Do not invent an edit to that file to
justify the `git add`.
