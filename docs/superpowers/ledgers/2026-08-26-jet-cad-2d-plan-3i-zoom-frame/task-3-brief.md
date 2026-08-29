## Task 3: The wheel clause — two unchanged frames, not one

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`

**Interfaces:**
- Consumes: `_restGateSteps` and `debugRestGateSteps` from Task 2.
- Produces: nothing new. The threshold moves from `>= 1` to `>= 2`.

**Why this is its own task.** A mouse wheel delivers isolated notches. With a
one-frame gate, every notch is one moving frame followed immediately by a
resting frame — a full bake per notch, discarded by the next notch, and
invisible to any criterion that only watches moving frames. Two consecutive
unchanged cameras cost one frame of latency and make a continuously spun wheel
bake nothing.

- [ ] **Step 1: Write the failing test**

```dart
  // A wheel spun steadily: one scale change per frame, with a single
  // unchanged frame between notches. Under a one-frame gate this bakes on
  // every second frame.
  testWidgets('a steadily spun wheel never arms the rest gate', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    h.cache.resetCounters();

    for (var notch = 0; notch < 6; notch++) {
      h.camera.zoomAt(const Offset(120, 90), 1.1); // the moving frame
      await t.pump();
      await t.pump(); // one unchanged frame before the next notch
    }

    expect(h.cache.bakeCount, 0,
        reason: 'a wheel that keeps turning must never reach two consecutive '
            'unchanged frames, so it must never bake');
  });

  test('the gate needs two unchanged frames, not one', () {
    // The threshold itself, stated where a reader can see it: one unchanged
    // frame is the in-between frame and draws like a moving one.
    expect(kRestGateFrames, 2);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: FAIL — `kRestGateFrames` undefined, and once defined at 1 the wheel
test reads `bakeCount` of 6.

- [ ] **Step 3: Raise the threshold**

```dart
/// Consecutive unchanged frames before a rest bake is permitted.
///
/// **Two, and the mouse wheel is why.** A wheel delivers isolated notches, so
/// at one every notch would be a moving frame followed immediately by a
/// resting frame: a full bake per notch, discarded by the next, and invisible
/// to any criterion that only watches moving frames. Two costs one frame of
/// latency (~16.7 ms) and makes a continuously spun wheel bake nothing.
const int kRestGateFrames = 2;
```

and in `paintFrame`:

```dart
    final resting = _restGateSteps >= kRestGateFrames && !_viewportCovered;
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: PASS.

- [ ] **Step 5: Fire M4 and record it**

M4 is "the rest bake fires on every frame, not only at rest": replace the
`resting` expression with `!_viewportCovered`. Expected: the wheel test and the
moving-frame test both go red. Restore from the copy, record verbatim output in
the mutation log under **M4**.

- [ ] **Step 6: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "feat(tiles): a rest bake needs two unchanged frames, for the wheel"
```

---

