## Task 2: A moving frame draws the composite and nothing else

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — `paintFrame`
- Test: `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`

**Interfaces:**
- Consumes: `sameQuantisedCamera` from Task 1.
- Produces: `int get liveDrawCount` already exists as `liveDraws`; this task adds
  `int get debugRestGateSteps` so a test can see the gate arm. The private field
  `_lastQuantised` holds the previous frame's camera and `_restGateSteps` counts
  consecutive unchanged frames.

**The behaviour.** A frame whose camera changed, and a frame that has matched
only once, both draw the composite and return. Neither bakes and neither walks
live. On a zoom **out** the composite shrinks and leaves a ring, and that ring
stays background until the gesture ends — the human's decision, spec D3.

- [ ] **Step 1: Write the failing test**

Append to `tile_regime_test.dart`. The helper is shared with every later test
in this file and with Task 3's.

```dart
/// Everything a tiled-frame test needs to drive and read one canvas.
class TiledHarness {
  TiledHarness(this.cache, this.camera, this.document);
  final TileCache cache;
  final CameraController camera;
  final DraftDocument document;

  /// Moves one entity onto tiles it did not occupy, for Task 10.
  ///
  /// **Onto disjoint tiles, not merely somewhere else.** An edit that extends
  /// a line rather than moving it makes the new tile set a superset of the
  /// old, and then "the old position was condemned" is true of an
  /// implementation that condemns nothing -- the trap
  /// `tile_invalidation_test.dart` already documents at its head.
  void moveOneEntityOntoDisjointTiles() {
    document.commands.execute(TransformNodeCommand(
      handle: kMovableHandle,
      transform: Transform2(1, 0, 0, 1, 220, 0),
    ));
  }
}

/// Pumps a tiled canvas over `fillingGrid`, which inks every tile of
/// [kTileViewport] at [tileCamera] -- so "nothing was drawn" can never be
/// mistaken for "there was nothing to draw".
Future<TiledHarness> pumpTiled(
  WidgetTester t, {
  DraftDocument Function(FlutterTextMeasurer)? document,
  ViewportTransform? camera,
}) async {
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = (document ?? fillingGrid)(measurer);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final controller = CameraController(camera ?? tileCamera());
  addTearDown(controller.dispose);

  await t.pumpWidget(MediaQuery(
    data: const MediaQueryData(devicePixelRatio: kTileDpr),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: kTileViewport.width,
        height: kTileViewport.height,
        child: DraftCanvas(
          document: doc,
          index: index,
          camera: controller,
          tiles: true,
          tileDevicePixels: 64,
        ),
      ),
    ),
  ));
  await t.pump();
  final state = t.state<DraftCanvasState>(find.byType(DraftCanvas));
  return TiledHarness(state.tileCache!, controller, doc);
}

/// Pumps until the canvas stops asking for frames, bounded.
///
/// The bound is not decoration: an implementation that asks forever would
/// otherwise hang the suite instead of failing it.
Future<void> settle(WidgetTester t, TiledHarness h) async {
  for (var i = 0; i < 40 && t.binding.hasScheduledFrame; i++) {
    await t.pump();
  }
  expect(t.binding.hasScheduledFrame, isFalse,
      reason: 'the settle must terminate');
}

void main() {
  // ... the Task 1 unit tests stay here ...

  testWidgets('a moving frame bakes nothing and walks nothing', (t) async {
    final h = await pumpTiled(t);
    // Settle first, so the failure below cannot be "there was nothing to do".
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue);

    h.cache.resetCounters();
    for (var i = 0; i < 8; i++) {
      h.camera.zoomAt(const Offset(120, 90), 1.05);
      await t.pump();
    }

    expect(h.cache.bakeCount, 0, reason: 'a moving frame must bake nothing');
    // `liveDrawCount` and not the painter's leaf counter: `DraftPainter.paint`
    // zeroes its own counters on entry, so a frame that never calls it leaves
    // the previous frame's number standing and the assertion would pass for
    // the wrong reason. The cache's counter increments where the live walk
    // actually happens.
    expect(h.cache.liveDrawCount, 0,
        reason: 'a moving frame must draw no live geometry either -- the '
            'uncovered region bounds to the whole viewport, so a live walk '
            'there is a full-viewport walk, 31.5-41.6 ms at 500,000 entities');
    expect(h.cache.carryOverBlitCount, greaterThan(0),
        reason: 'and it must still show something');
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: FAIL — `bakeCount` is 8, one per frame, and `liveDrawCount` is 8 too,
because today's moving frame bakes one tile and then falls through to the live
walk.

- [ ] **Step 3: Gate the frame**

In `paintFrame`, immediately after `_lastCamera = quantised;`:

```dart
    // **Three frame kinds, and only one of them bakes.** A frame whose camera
    // changed is *moving*. A frame that has matched once and not yet twice is
    // the one in between. Both draw the composite and nothing else: no bake,
    // and no live walk.
    //
    // The live walk is excluded deliberately and the measurement is why. On a
    // moving frame the new generation is empty, so every visible key misses
    // and `uncovered` accumulates by `expandToInclude` into the **whole
    // viewport** rather than a ring; `stripFor` then clamps to the viewport.
    // "Walk the uncovered region" is therefore a full-viewport live walk --
    // 31.5-41.6 ms at 500,000 entities -- on every zoom-out frame.
    final previous = _lastQuantised;
    _restGateSteps =
        previous != null && sameQuantisedCamera(previous, quantised)
            ? _restGateSteps + 1
            : 0;
    _lastQuantised = quantised;
    final resting = _restGateSteps >= 1 && !_viewportCovered;
```

and immediately after the carry-over blit block, before the visible-key loop:

```dart
    if (!resting) {
      // Nothing else this frame. The composite is already down; a zoom out
      // leaves its ring as background until the gesture ends (spec D3).
      return;
    }
```

Add the two fields beside `_lastCamera`:

```dart
  /// The previous frame's quantised camera, for the rest gate.
  ViewportTransform? _lastQuantised;

  /// Consecutive frames whose quantised camera did not change.
  ///
  /// Zero on the frame that changed. **One** is the frame in between, which
  /// draws like a moving frame. **Two** arms the rest bake. The second frame
  /// is the mouse wheel's: a wheel delivers isolated notches, so without it
  /// every notch is one moving frame followed immediately by a resting frame,
  /// a full bake per notch discarded by the next.
  int _restGateSteps = 0;

  /// The rest gate's counter, for tests. See [_restGateSteps].
  int get debugRestGateSteps => _restGateSteps;
```

**Note the `>= 1` and not `>= 2` in this task.** Task 3 raises it, with the
wheel test that justifies it. Landing the wheel clause here would leave two
behaviours untested in one commit.

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: PASS.

- [ ] **Step 5: Fire M1 and record it**

Copy the file aside, delete the `if (!resting) return;` block, re-run, restore
from the copy. **Never `git checkout`.**

```bash
cd /Users/ahmeturel/Projects/oss/jet-cad
cp packages/jet_cad_2d_flutter/lib/src/tile_cache.dart /tmp/tile_cache.green
# edit, run, then:
cp /tmp/tile_cache.green packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
```

Expected: the moving-frame test goes red. Record the verbatim output in
`docs/superpowers/notes/plan-3i-mutation-log.md` under **M1**.

- [ ] **Step 6: Run the whole package and commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "feat(tiles): a moving frame draws the composite and nothing else"
```

---

