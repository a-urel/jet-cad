### Task 4: `stripFor`, the arithmetic half

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Modify: `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:**
- Produces: `Rect stripFor(Rect uncovered, Size viewport)` — top-level, public, in `tile_cache.dart`.

**Why a pure function.** It converts the clamp from a device observation into a unit assertion. Mutant **M1** — drop the clamp — has no other witness: the fallback's pixels are identical either way and only its cost and the vertex buffer's high-water mark move.

- [ ] **Step 1: Write the failing tests**

In `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`, add inside `main()`:

```dart
  group('stripFor', () {
    const viewport = Size(400, 300);

    test('pads an interior rect on every side', () {
      // kTileSlack is 32.0. An interior rect keeps the whole pad, because a
      // stroke whose centreline is outside the strip still inks pixels inside
      // it -- the reason `_bake` pads its own query.
      expect(stripFor(const Rect.fromLTRB(100, 80, 200, 180), viewport),
          const Rect.fromLTRB(68, 48, 232, 212));
    });

    test('clamps to the viewport rather than growing past it', () {
      // The mutant this exists for. A union that already spans the frame,
      // padded, would ask for 464 x 364 where the untiled path asks for
      // 400 x 300 -- a third more area than the baseline the narrowing is
      // meant to undercut, measured as the vertex buffer doubling to 384 MiB.
      expect(stripFor(Offset.zero & viewport, viewport), Offset.zero & viewport);
    });

    test('clamps one edge at a time', () {
      // A band entering from the left: clamped on the left, padded on the
      // right. Asserting the whole rect rather than one edge, so a mutation
      // that clamped all four sides unconditionally is also caught.
      expect(stripFor(const Rect.fromLTRB(0, 0, 40, 300), viewport),
          const Rect.fromLTRB(0, 0, 72, 300));
    });

    test('a strip touching the bottom-right clamps there and pads inward', () {
      expect(stripFor(const Rect.fromLTRB(360, 260, 400, 300), viewport),
          const Rect.fromLTRB(328, 228, 400, 300));
    });
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: a compile error, `The function 'stripFor' isn't defined`.

- [ ] **Step 3: Write the function**

Add to `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, top level, near `kTileSlack`. Add `import 'dart:math' as math;` if it is not already imported.

```dart
/// The rectangle the live fallback walks: [uncovered] grown by [kTileSlack] on
/// every side, then clamped to [viewport].
///
/// **The pad**, for `_bake`'s reason: a stroke whose centreline is outside the
/// rectangle still inks pixels inside it, and the painter's index query is a
/// rect intersection on entity bounds. `_bake` states the rule at its own call
/// site -- "The query is padded; the clip is not." Plan 3g's F1 is what an
/// unpadded query cost, at six of forty-one swept zoom factors.
///
/// **The clamp**, and it was found by measuring rather than by reasoning.
/// `uncovered` is a *bounding rectangle* (`paintFrame` accumulates it with
/// `expandToInclude`), so an L-shaped uncovered set bounds to the whole frame;
/// padding that asks for 464 x 364 logical pixels where the untiled path asks
/// for 400 x 300. An unclamped arm doubled the vertex buffer's high-water mark
/// from 192.00 MiB to 384.00 on a run whose every other counter matched.
/// **The pad belongs on interior edges; on the viewport's own edge the
/// full-frame walk is the ceiling.**
///
/// Pure, so the clamp has a unit witness. Nothing else in this plan can see
/// it: the fallback's pixels are identical clamped or not, and only its cost
/// moves.
Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
      math.max(0.0, uncovered.left - kTileSlack),
      math.max(0.0, uncovered.top - kTileSlack),
      math.min(viewport.width, uncovered.right + kTileSlack),
      math.min(viewport.height, uncovered.bottom + kTileSlack),
    );
```

- [ ] **Step 4: Run them and watch them pass**

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: `+4: All tests passed!`

- [ ] **Step 5: Fire mutant M1**

```sh
cp lib/src/tile_cache.dart /tmp/tile_cache.m1
```

Edit `stripFor` to drop the clamp — replace the two `math.min(...)` arguments with `uncovered.right + kTileSlack` and `uncovered.bottom + kTileSlack`, and the two `math.max(...)` with `uncovered.left - kTileSlack` and `uncovered.top - kTileSlack`. Run:

```sh
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

Expected: **three of the four tests fail** — every one except `pads an interior rect`. Record the exact failure output for the mutation log. Restore:

```sh
cp /tmp/tile_cache.m1 lib/src/tile_cache.dart
CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
```

- [ ] **Step 6: Full suite, analyze, format, commit**

```sh
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/tile_cache.dart test/tile_cache_test.dart
git commit -m "feat: stripFor, the fallback walk's padded and clamped rectangle

Pure, because the clamp has no other witness: the fallback's pixels are
identical clamped or not and only its cost moves. Mutant M1 -- drop the clamp
-- reddens three of the four cases.

The clamp was found by measuring. uncovered is a bounding rectangle built with
expandToInclude, so an L-shaped uncovered set bounds to the whole frame, and
padding that asks for 464 x 364 where the untiled path asks for 400 x 300. An
unclamped arm doubled the vertex buffer to 384 MiB with every other counter
unchanged."
```

---

