# Plan 3i — the zoom frame — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the tiled frame into a **moving** regime that draws only the
carry-over composite and a **resting** regime that walks the visible region in
tile-row bands and slices each band into tiles.

**Architecture:** `TileCache.paintFrame` gains a regime classifier keyed on the
whole quantised camera. A moving frame blits the composite and returns. A
resting frame — camera unchanged for two frames, viewport not covered — drops
the composite, then for each tile row walks once into a picture, rasterises it,
and copies band-local sub-rectangles out into tile images. `packages/jet_cad_2d`
is not touched.

**Tech Stack:** Dart 3, Flutter, `dart:ui` (`Picture`, `PictureRecorder`,
`Image.toImageSync`, `Canvas.drawImageRect`), `package:vector_math`.

**Spec:** [docs/superpowers/specs/2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md](../specs/2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md)
at `d3ee5e6`, after five external reviews across two rounds. **Read it.** It
carries the nine decisions, eleven criteria, eleven mutants, five
anti-degenerate clauses and five accepted gaps this plan implements.

## Global Constraints

- **Work directly on `main`** in `/Users/ahmeturel/Projects/oss/jet-cad`, no
  worktree — the arrangement of Plans 3e, 3f, 3f.1, 3g and 3h, on the human's
  standing consent.
- **`package:jet_cad_2d` is pure Dart** — no Flutter, no `dart:ui`, ever.
  **This plan does not touch it.**
- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.** A bake is not a steady-state frame; a *moving* frame is.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace.
- **Never `git checkout` a file to revert a mutation.** Copy the file aside,
  mutate, restore from the copy. Sanctioned exception:
  `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which
  `flutter drive` rewrites every run — never staged, never reverted.
- **Prefix every test command with `CI=true`** — otherwise Dart's analytics
  phone-home blocks the runner for minutes at ~0% CPU.
- **Never synthesize test output.** Reviewers verify claims independently; a
  fabricated transcript invalidates the task.
- `unused_import` is an **ERROR** in `packages/jet_cad_2d_flutter`.
- **No pre-existing golden PNG may be regenerated.**
- **This plan may not amend `CLAUDE.md`.**
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d       && CI=true dart test && CI=true dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd apps/dev_harness_2d       && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed lib test
```

**The pinned measurement viewport is 1600x1200 logical at `devicePixelRatio`
2** — 3200x2400 device. Every memory figure in the spec is priced against it.
The 800x600 numbers in `STATUS.md` are a *test* viewport and are not
interchangeable.

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | Modify. The regime classifier, the band pass, the slice, the shared `_baked` record, the extended `liveBytes`. |
| `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` | Create. Criterion 1, the classifier's own unit tests, M1 and M4. |
| `packages/jet_cad_2d_flutter/test/tile_band_test.dart` | Create. Band geometry, the padded query, the origin, the slice. M9, M10, M11, M3. |
| `packages/jet_cad_2d_flutter/test/tile_settle_test.dart` | Modify. Criterion 3 grows a one-frame assertion; the file already exists from `967fa3b`. |
| `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` | Modify. Criterion 10, M5. |
| `packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart` | Create. Criteria 5, 6 and 11; M7. |
| `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart` | Create. Criterion 7, M6. |
| `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart` | Modify. A fixture with entities larger than one tile and strokes that cross a band edge (anti-degenerate clauses 1 and 2). |
| `apps/dev_harness_2d/lib/measurement_rig.dart` | Modify. The `tile zoom` phase §5 pins, and the interleaved arrangement. |
| `apps/dev_harness_2d/lib/main.dart` | Modify. One define for the interleaved arm count. |
| `docs/superpowers/notes/2026-08-26-plan-3i-results.md` | Create. |
| `docs/superpowers/notes/plan-3i-mutation-log.md` | Create. |
| `STATUS.md` | Modify, last task only. |

---

## Task 1: The rest gate

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` (create)

**Interfaces:**
- Consumes: `quantiseCamera(camera, dpr)` and `ViewportTransform`, both already
  in `tile_cache.dart` / `viewport_transform.dart`.
- Produces: on `TileCache`, `bool get debugRestGateArmed`, and the private
  `_restGateSteps` counter that Task 8 reads. `ViewportTransform` equality is
  compared field-by-field through the new top-level
  `bool sameQuantisedCamera(ViewportTransform a, ViewportTransform b)`.

**Why a top-level function and not `==`:** `ViewportTransform` has no value
equality and giving it one would change behaviour everywhere it is used as a
map key or compared for identity. This comparison is local to the gate.

- [ ] **Step 1: Write the failing test**

```dart
// packages/jet_cad_2d_flutter/test/tile_regime_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  ViewportTransform at(double scale, double e, double f) => ViewportTransform(
      worldToScreenMatrix: Transform2(scale, 0, 0, -scale, e, f));

  test('the same camera compares same', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 20)), isTrue);
  });

  test('a scale change compares different', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.5, 10, 20)), isFalse);
  });

  // Translation is in the comparison and not only scale. Immediately after a
  // zoom the generation is empty, so a pan that follows keeps the scale and
  // does not cover the viewport: under a scale-only rule two same-scale pan
  // frames would satisfy every rest condition and spend a full bake while the
  // camera is still moving.
  test('a translation change compares different', () {
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 11, 20)), isFalse);
    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 21)), isFalse);
  });

  test('the skew terms are compared too', () {
    final a = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.1, 0, -1.4, 10, 20));
    final b = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0.2, 0, -1.4, 10, 20));
    expect(sameQuantisedCamera(a, b), isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: FAIL to compile — `sameQuantisedCamera` is not defined.

- [ ] **Step 3: Add the comparison**

In `tile_cache.dart`, beside `quantiseCamera`:

```dart
/// Whether two quantised cameras describe the same view, field by field.
///
/// Not `operator ==` on [ViewportTransform]: that type is used as a map key
/// and compared for identity elsewhere, and giving it value equality would
/// change behaviour far outside this gate.
///
/// **Translation is compared, not only scale.** Immediately after a zoom the
/// generation is empty, so a pan that follows keeps the scale and does not
/// cover the viewport; a scale-only comparison would let two same-scale pan
/// frames arm the rest gate and spend a full bake while the camera is still
/// moving. These are stored values, so the comparison is exact `==` and not
/// `Tolerance`.
bool sameQuantisedCamera(ViewportTransform a, ViewportTransform b) {
  final x = a.worldToScreenMatrix, y = b.worldToScreenMatrix;
  return x.a == y.a &&
      x.b == y.b &&
      x.c == y.c &&
      x.d == y.d &&
      x.e == y.e &&
      x.f == y.f;
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_regime_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Run the whole package and commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_regime_test.dart
git commit -m "feat(tiles): compare a whole quantised camera, not only its scale"
```

---

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

## Task 4: `liveBytes` counts a live band image

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart` (create)

**Interfaces:**
- Produces: on `TileCache`, the private `Image? _band` and its byte
  contribution inside `liveBytes`. Task 6 assigns `_band`; this task teaches
  the meter to see it **before** the thing it measures exists.

**Why the instrument comes first.** `liveBytes` sums `_tiles` and `_carryOver`
and nothing else. A resident band image would be invisible to it, and criterion
7 — the byte ceiling inside the rest frame — would read green inside exactly
the window it exists for. A gate that goes blind when the design changes under
it is this project's recurring defect; this task closes it in advance.

- [ ] **Step 1: Write the failing test**

```dart
// packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('a live band image is counted in liveBytes', () {
    final cache = TileCache(tileDevicePixels: 64);
    addTearDown(cache.dispose);
    final before = cache.liveBytes;

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFF00FF00));
    final picture = recorder.endRecording();
    final band = picture.toImageSync(256, 64);
    picture.dispose();

    cache.debugSetBand(band);
    expect(cache.liveBytes, before + 256 * 64 * 4,
        reason: 'a resident band image is 4 bytes a pixel like every other '
            'image this cache holds, and the ceiling has to see it');

    cache.debugSetBand(null);
    expect(cache.liveBytes, before);
    band.dispose();
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/tile_bytes_test.dart`
Expected: FAIL to compile — `debugSetBand` is not defined.

- [ ] **Step 3: Extend the meter**

```dart
  /// The band image the current rest bake is slicing, if one is resident.
  ///
  /// Null on every frame that is not inside a band's slice loop. Held as a
  /// field rather than a local **so that [liveBytes] can see it**: the ceiling
  /// is consulted per sliced tile, and a source image invisible to the meter
  /// would let the peak run past `kTileCacheBytes` inside the one frame the
  /// meter exists to bound.
  Image? _band;

  /// Test seam for the byte meter. See [_band].
  @visibleForTesting
  void debugSetBand(Image? band) => _band = band;
```

and in `liveBytes`:

```dart
  int get liveBytes {
    final carryOver = _carryOver;
    final band = _band;
    return _tiles.length * _tileBytes +
        (carryOver == null ? 0 : carryOver.width * carryOver.height * 4) +
        (band == null ? 0 : band.width * band.height * 4);
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/tile_bytes_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): the byte meter sees a resident band image"
```

---

## Task 5: Band geometry

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart` (create)

**Interfaces:**
- Produces: on `TileGrid`,
  `List<TileBand> bandsFor(ViewportTransform camera, Size viewport)`, and the
  value type

  ```dart
  class TileBand {
    const TileBand({required this.row, required this.keys, required this.deviceRect});
    final int row;
    final List<TileKey> keys;
    /// In the grid's device space, the same space `deviceDeltaFrom` returns.
    final Rect deviceRect;
  }
  ```

  Task 6 walks each band; Task 7 slices it.

**The rule.** One band per tile row of `visibleKeys`, full union width. Bands
are what keep the peak at ~56 MiB instead of the 96 MiB a single union image
would cost — see spec D5, and note that `visibleKeys` yields a *full
rectangle*, so the union has the tile set's own area, not the viewport's.

- [ ] **Step 1: Write the failing test**

```dart
// packages/jet_cad_2d_flutter/test/tile_band_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/tile_fixture.dart';

void main() {
  TileGrid gridAt(ViewportTransform camera) => TileGrid(
      anchor: camera, devicePixelRatio: kTileDpr, tileDevicePixels: 64);

  test('the bands partition the visible keys, in row order, without gaps', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final grid = gridAt(camera);
    final bands = grid.bandsFor(camera, kTileViewport);
    final fromBands = bands.expand((b) => b.keys).toList();
    final visible = grid.visibleKeys(camera, kTileViewport).toList();

    expect(fromBands.toSet(), visible.toSet(),
        reason: 'every visible key belongs to exactly one band');
    expect(fromBands.length, visible.length, reason: 'and to only one');
    for (var i = 1; i < bands.length; i++) {
      expect(bands[i].row, bands[i - 1].row + 1,
          reason: 'rows are contiguous and ascending');
      expect(bands[i].deviceRect.top, bands[i - 1].deviceRect.bottom,
          reason: 'and the bands touch without gap or overlap');
    }
  });

  test('a band is one tile tall and the full union width', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    for (final band in bands) {
      expect(band.deviceRect.height, 64.0);
      expect(band.deviceRect.width, band.keys.length * 64.0);
    }
  });

  // The overhang is the point. `visibleKeys` yields every key the viewport
  // touches, including keys that extend past it, and a source sized to the
  // viewport has no pixels for those. This is M7's territory.
  test('the union overhangs the viewport, and the bands carry the overhang',
      () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
    final union = bands
        .map((b) => b.deviceRect)
        .reduce((a, b) => a.expandToInclude(b));
    final device = Rect.fromLTWH(0, 0, kTileViewport.width * kTileDpr,
        kTileViewport.height * kTileDpr);
    expect(union.contains(device.topLeft), isTrue);
    expect(union.right, greaterThanOrEqualTo(device.right));
    expect(union.bottom, greaterThanOrEqualTo(device.bottom));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL to compile — `bandsFor` and `TileBand` are not defined.

- [ ] **Step 3: Implement**

On `TileGrid`, beside `visibleKeys`:

```dart
/// One tile row of the visible region: every key in it, and the device
/// rectangle they span.
class TileBand {
  const TileBand(
      {required this.row, required this.keys, required this.deviceRect});

  final int row;
  final List<TileKey> keys;

  /// In the grid's device space — the space [TileGrid.deviceDeltaFrom]
  /// returns, whose origin is the grid's anchor and not the viewport.
  final Rect deviceRect;
}
```

```dart
  /// [visibleKeys] grouped into one band per tile row.
  ///
  /// **A band and not the whole union**, because the union has the tile set's
  /// own area — `visibleKeys` yields a full rectangle — so one image for it
  /// plus the tiles it is sliced into peaks at exactly `kTileCacheBytes` with
  /// no headroom. One row at a time is 8 MiB at the reference viewport against
  /// the union's 48.
  List<TileBand> bandsFor(ViewportTransform camera, Size viewport) {
    final byRow = <int, List<TileKey>>{};
    for (final key in visibleKeys(camera, viewport)) {
      (byRow[key.y] ??= <TileKey>[]).add(key);
    }
    final rows = byRow.keys.toList()..sort();
    return [
      for (final row in rows)
        TileBand(
          row: row,
          keys: byRow[row]!..sort((a, b) => a.x.compareTo(b.x)),
          deviceRect: Rect.fromLTWH(
            byRow[row]!.first.x * tileDevicePixels.toDouble(),
            row * tileDevicePixels.toDouble(),
            byRow[row]!.length * tileDevicePixels.toDouble(),
            tileDevicePixels.toDouble(),
          ),
        ),
    ];
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): group the visible keys into tile-row bands"
```

---

## Task 6: The band bake — padded query, hard clip, viewport-derived origin

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart`

**Interfaces:**
- Consumes: `TileBand` from Task 5; `_drawInto(canvas, size, camera, painter,
  sink, vertices, origin, onVisit)`, already in the file; `kTileSlack`, already
  a top-level constant.
- Produces: on `TileCache`,

  ```dart
  Image _bakeBand(
    TileBand band,
    TileGrid grid,
    ViewportTransform quantised,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    List<int> visitedInto,
  );
  ```

  `visitedInto` is filled with the handles the walk touched, for Task 8.

**Three things this task decides, all of them from the spec's D4:**

1. **The query is padded and the clip is not.** A stroke whose centreline lies
   just outside the band still inks inside it. `_bake` already does this — its
   comment states the rule — and dropping it here is **M9**.
2. **The rebase origin is the viewport's**, passed in, never derived from the
   band. A band-derived origin gives each band its own `float32` residual and
   can cross a power-of-two step. Dropping this is **M11**.
3. **The clip is hard.** An antialiased clip edge would make two adjacent
   bands' `source-over` fall short of full coverage along the shared row — the
   same seam `_bake` avoids the same way.

- [ ] **Step 1: Write the failing test**

```dart
  // M9's gate. A stroke whose centreline sits outside the band still inks
  // inside it, so the query has to reach past the band's edge. The fixture
  // puts a thick horizontal stroke one logical pixel above a band boundary.
  testWidgets('a stroke centred outside the band still inks inside it',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    expect(differingPixels(tiled, live), 0,
        reason: 'an unpadded band query drops the half of a boundary stroke '
            'that belongs to the band below it');
  });

  // M11's gate. Placed where the view span crosses a power-of-two step, so a
  // band-derived origin and a viewport-derived one disagree in float32.
  testWidgets('every band shares the viewport-derived rebase origin',
      (t) async {
    final h = await pumpTiled(t, camera: rebaseBoundaryCamera());
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    expect(differingPixels(tiled, live), 0,
        reason: 'a per-band origin gives each band its own residual, and the '
            'rows disagree along their shared edge');
  });
```

`captureTiled`, `captureLive`, `differingPixels` and `rebaseBoundaryCamera` are
added in Task 9 and used here; **write Task 9's helpers first if this task is
executed before it.** They live in
`packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` beside the
existing `measureFallbackAgreement`.

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL — `_bakeBand` does not exist yet, so nothing bakes and the
captures differ everywhere.

- [ ] **Step 3: Implement**

```dart
  /// Walks one band into one image.
  ///
  /// Modelled on [_bake] and sharing all three of its rules, at band scale.
  Image _bakeBand(
    TileBand band,
    TileGrid grid,
    ViewportTransform quantised,
    DraftPainter painter,
    CanvasDrawSink sink,
    VerticesDrawSink? vertices,
    Vector2 origin,
    List<int> visitedInto,
  ) {
    final dpr = grid.devicePixelRatio;
    final width = band.deviceRect.width / dpr;
    final height = band.deviceRect.height / dpr;
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.scale(dpr);
    // **Hard, and for `_bake`'s reason.** An antialiased clip edge would make
    // two adjacent bands' `source-over` fall short of full coverage along the
    // row they share: a seam, in the one place this design exists to remove
    // one.
    into.clipRect(Rect.fromLTWH(0, 0, width, height), doAntiAlias: false);

    // **The query is padded; the clip is not.** A stroke whose centreline lies
    // just outside the band still inks inside it. `kTileSlack` is the same
    // slack `_bake` uses and the same slack the invalidation rule uses --
    // padding one alone makes them disagree.
    const pad = kTileSlack;
    into.save();
    into.translate(-pad, -pad);

    final m = quantised.worldToScreenMatrix;
    final bandCamera = ViewportTransform(
      worldToScreenMatrix: Transform2(
        m.a,
        m.b,
        m.c,
        m.d,
        m.e - band.deviceRect.left / dpr + pad,
        m.f - band.deviceRect.top / dpr + pad,
      ),
    );

    _drawInto(
      into,
      Size(width + 2 * pad, height + 2 * pad),
      bandCamera,
      painter,
      sink,
      vertices,
      // **The viewport's origin, never the band's.** Rebasing is frame-global
      // by construction: a per-band origin gives each band its own
      // quantisation step and `float32` residuals the live frame does not
      // have, and can cross a power-of-two step between one row and the next.
      origin,
      (handle) => visitedInto.add(handle.value),
    );
    into.restore();

    final picture = recorder.endRecording();
    final image = picture.toImageSync(
        band.deviceRect.width.round(), band.deviceRect.height.round());
    _imagesAlive++;
    picture.dispose();
    return image;
  }
```

**The `onVisit` callback is deliberately simpler than `_bake`'s.** `_bake`
climbs owners so a container transform reaches the tile through direction one.
A band records the same information for a wider region, and Task 8 shares one
record across the band's tiles, so the owner climb happens once there rather
than per tile.

- [ ] **Step 4: Run it and watch it pass**

Run after Task 8 wires it in; on its own this step's expectation is that
`_bakeBand` compiles and the package stays green.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): walk one band into one image, padded query and hard clip"
```

---

## Task 7: The slice — band-local, integral, unfiltered

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_band_test.dart`

**Interfaces:**
- Consumes: `_bakeBand` from Task 6, `TileBand` from Task 5.
- Produces: on `TileCache`,
  `Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid)`.

**The rule that matters.** A key's device rectangle is in **grid** space, whose
origin is the generation's anchor, and it goes negative the moment a same-scale
pan moves the visible key range. The copy therefore reads
`keyDeviceRect - band.deviceRect.topLeft`. Reading the grid-space rectangle
directly is **M10**, and a pure zoom script never produces the case — which is
why Task 9 carries an arm that pans between the last scale change and the rest
bake.

- [ ] **Step 1: Write the failing test**

```dart
  test('a slice rectangle is band-local and integral', () {
    final camera = quantiseCamera(tileCamera(), kTileDpr);
    final grid = gridAt(camera);
    final band = grid.bandsFor(camera, kTileViewport).first;
    for (final key in band.keys) {
      final src = grid.sliceSourceRect(band, key);
      expect(src.left, greaterThanOrEqualTo(0.0),
          reason: 'band-local, so never negative however the keys are '
              'numbered -- a same-scale pan takes key.x negative');
      expect(src.top, 0.0);
      expect(src.width, 64.0);
      expect(src.height, 64.0);
      expect(src.left, src.left.roundToDouble(),
          reason: 'integral by construction: `deviceDeltaFrom` rounds, and a '
              'tile side is `tileDevicePixels / dpr` exactly');
    }
    expect(grid.sliceSourceRect(band, band.keys.first).left, 0.0);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: FAIL to compile — `sliceSourceRect` is not defined.

- [ ] **Step 3: Implement**

On `TileGrid`:

```dart
  /// Where [key]'s pixels sit **inside** [band]'s image.
  ///
  /// Band-local, not grid-space. A key's device rectangle is measured from the
  /// generation's anchor and goes negative as soon as a same-scale pan moves
  /// the visible range; the band image starts at (0, 0) whatever the keys are
  /// numbered. Integral by construction — [deviceDeltaFrom] rounds, and a tile
  /// side is `tileDevicePixels` exactly.
  Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
        0,
        tileDevicePixels.toDouble(),
        tileDevicePixels.toDouble(),
      );
```

On `TileCache`:

```dart
  /// Copies one tile's pixels out of a band image.
  ///
  /// A texture copy, not a geometry raster — which is the whole difference
  /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
  /// is integral and the destination is the same size, so there is nothing to
  /// interpolate and a sampler would be pure cost.
  Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
    final recorder = PictureRecorder();
    final into = Canvas(recorder);
    into.drawImageRect(
      band,
      grid.sliceSourceRect(from, key),
      Rect.fromLTWH(
          0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
      _blitPaint,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
    _imagesAlive++;
    picture.dispose();
    return image;
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_band_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(tiles): slice a band into tiles with band-local integral rects"
```

---

## Task 8: Wire the rest bake into `paintFrame`

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` — `paintFrame`
- Test: `packages/jet_cad_2d_flutter/test/tile_settle_test.dart`
- Test: `packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart`

**Interfaces:**
- Consumes: `bandsFor`, `_bakeBand`, `_sliceTile`, `_band`, `_restGateSteps`.
- Produces: the resting branch. `_baked` gains one shared `Uint32List` per
  band. Task 10 reads `invalidationCount` against it.

**The order inside the frame is load-bearing.** Drop the composite *first*: the
frame is about to draw real content and does not need it, and at the reference
viewport composite + tiles + band is what keeps the peak at ~56 MiB instead of
running past `kTileCacheBytes`.

- [ ] **Step 1: Write the failing test**

Add to `tile_settle_test.dart`:

```dart
  testWidgets('the settle completes in one frame', (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    expect(h.cache.viewportCovered, isTrue);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();                       // moving
    await t.pump();                       // in between
    final tilesBefore = h.cache.liveTileCount;
    await t.pump();                       // the rest frame
    expect(h.cache.viewportCovered, isTrue,
        reason: 'one rest frame covers the viewport; the tiled fill it '
            'replaces took one frame per tile');
    expect(h.cache.liveTileCount, greaterThan(tilesBefore));
    expect(t.binding.hasScheduledFrame, isFalse,
        reason: 'and nothing is owed afterwards');
  });
```

Add to `tile_bytes_test.dart`:

```dart
  testWidgets('the ceiling holds at every point inside the rest frame',
      (t) async {
    final h = await pumpTiled(t);
    await settle(t, h);
    h.cache.debugOnSliceForTest = () {
      expect(h.cache.liveBytes, lessThanOrEqualTo(kTileCacheBytes),
          reason: 'the band image is resident here and the meter counts it');
    };
    addTearDown(() => h.cache.debugOnSliceForTest = null);

    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();
    await t.pump();
    await t.pump();

    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
        reason: 'no band image outlives its band, and the composite was '
            'dropped before the bake');
  });
```

- [ ] **Step 2: Run both and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_settle_test.dart test/invariants/tile_bytes_test.dart`
Expected: FAIL — the settle still takes one frame per tile, and
`debugOnSliceForTest` is not defined.

- [ ] **Step 3: Implement the resting branch**

Replace the visible-key loop's body for the resting case. After the
`if (!resting) { return; }` guard from Task 2:

```dart
    // **The composite goes first.** The frame is about to draw real content
    // and does not need it, and at the reference viewport keeping it would put
    // composite + tiles + band past `kTileCacheBytes`.
    _dropCarryOver();

    final bands = grid.bandsFor(quantised, viewport);
    for (final band in bands) {
      final visited = <int>[];
      final image =
          _bakeBand(band, grid, quantised, painter, sink, vertices, origin, visited);
      _band = image;
      visited.sort();
      // **One record per band, shared by reference.** `_invalidateTouched`
      // condemns tiles by iterating `_baked`, and a sliced tile with no record
      // is invisible to it: edit an entity after a settle and the stale tile
      // keeps blitting over the corrected drawing. Sharing makes invalidation
      // band-coarse, which is right because a band is exactly the unit a
      // rebake walks.
      final record = Uint32List.fromList(visited);
      for (final key in band.keys) {
        debugOnSliceForTest?.call();
        // The ceiling is consulted before the write, not after the frame --
        // the rule the tile loop already follows. The slice bypasses
        // `budgetedTilesPerFrame`, which rations bakes; a slice is not a bake.
        if (!_makeRoomForOneTile()) break;
        final tile = _sliceTile(image, band, key, grid);
        _tiles[key] = tile;
        _baked[key] = record;
        _lastUsedFrame[key] = _frameSerial;
      }
      _band = null;
      image.dispose();
      _imagesAlive--;
      _bakes++;
    }

    // Now blit what was just produced. The visible-key loop below is unchanged
    // and finds every tile present.
```

Add the test seam beside the other debug members:

```dart
  /// Called once per sliced tile, while the band image is resident.
  ///
  /// The only point at which the byte ceiling can be observed at its peak;
  /// a check after the frame would always read the steady state.
  @visibleForTesting
  void Function()? debugOnSliceForTest;
```

- [ ] **Step 4: Run and watch them pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test`
Expected: PASS, the whole package.

- [ ] **Step 5: Fire M2 and M6**

**M2** — `for (final key in band.keys)` becomes `band.keys.take(1)`. Expected:
the one-frame settle test goes red.
**M6** — delete `image.dispose(); _imagesAlive--;`. Expected: the
`debugImagesAlive` assertion goes red.
Restore from the copy each time. Record both verbatim in the mutation log.

- [ ] **Step 6: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "feat(tiles): a resting frame bakes in bands and slices them into tiles"
```

---

## Task 9: The differential arms — criteria 5, 6 and 11

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart`
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart` (create)

**Interfaces:**
- Produces, in `tile_comparison.dart`:
  `Future<ByteData> captureTiled(WidgetTester t, TiledHarness h)`,
  `Future<ByteData> captureLive(WidgetTester t, TiledHarness h)`,
  `int differingPixels(ByteData a, ByteData b)`, and
  `ViewportTransform rebaseBoundaryCamera()`.
- Produces, in `tile_fixture.dart`: `DraftDocument bandCrossingGrid(
  FlutterTextMeasurer measurer)` — **entities larger than one tile**
  (anti-degenerate clause 2) and thick strokes centred just outside a band
  boundary (M9's fixture).

**Three arms, and the second and third exist because the first cannot see their
defects.**

1. **Settled equals live** — criterion 5.
2. **Sub-tile pan after a settle** — criterion 11's first arm, and **M7's only
   gate**. An edge tile's transparent overhang costs exactly what an opaque
   blit costs, so Plan 3h's p95 pan gate is blind to it; only a pixel
   comparison after a pan smaller than one tile exposes it.
3. **A pan taken between the last scale change and the rest bake** — criterion
   11's second arm and **M10's gate**. It moves the visible key range so a
   key's grid-space rectangle goes negative; the pinned pure-zoom script never
   produces the case.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
void main() {
  testWidgets('a settled generation is identical to a live frame', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0);
  });

  testWidgets('and stays identical after a pan smaller than one tile',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    h.camera.panBy(const Offset(-11, -7)); // under one 32-logical-pixel tile
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'an edge tile sliced from a viewport-sized source blits its '
            'transparent overhang here, and costs the same as an opaque one, '
            'so no timing gate can see it');
  });

  testWidgets('and when a pan lands between the scale change and the bake',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    h.camera.zoomAt(const Offset(120, 90), 1.3);
    await t.pump();                        // moving
    h.camera.panBy(const Offset(-90, -60)); // key range goes negative
    await t.pump();                        // moving again, gate resets
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'a grid-space slice rectangle is negative here and reads off '
            'the front of the band image');
  });

  // Criterion 6, with its teeth: the boundary columns and rows specifically.
  testWidgets('tile boundaries carry no difference of their own', (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    final tiled = await captureTiled(t, h);
    final live = await captureLive(t, h);
    const w = 800, hgt = 600; // kTileViewport at kTileDpr, in device pixels
    expect(
        differingPixelsOnTileEdges(tiled, live,
            tileDevicePixels: 64, width: w, height: hgt),
        0);
    // Not vacuous: the sweep must have looked at ink, not at background.
    expect(
        inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
        greaterThan(200));
  });
}
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_slice_differential_test.dart`
Expected: FAIL to compile — the helpers do not exist yet.

- [ ] **Step 3: Implement the helpers and the fixture**

`captureTiled` renders the widget as it stands. `captureLive` rebuilds the same
document, index and camera with `tiles: false` and captures that. Both go
through `tester.runAsync` and `RenderRepaintBoundary.toImage`, the pattern
`tile_comparison.dart` already uses for its ink measurements.
```dart
/// Pixels whose RGBA differs, over two captures of the same size.
///
/// Exact `==` on stored bytes, never a tolerance: these are recorded values,
/// and a tolerance here is how a seam of one unit hides.
int differingPixels(ByteData a, ByteData b) {
  expect(a.lengthInBytes, b.lengthInBytes);
  var differing = 0;
  for (var i = 0; i < a.lengthInBytes; i += 4) {
    if (a.getUint32(i) != b.getUint32(i)) differing++;
  }
  return differing;
}

/// The same comparison, restricted to the columns and rows a tile boundary
/// falls on and the pixel either side of each.
int differingPixelsOnTileEdges(ByteData a, ByteData b,
    {required int tileDevicePixels, required int width, required int height}) {
  var differing = 0;
  bool onEdge(int v) {
    final m = v % tileDevicePixels;
    return m == 0 || m == 1 || m == tileDevicePixels - 1;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!onEdge(x) && !onEdge(y)) continue;
      final i = (y * width + x) * 4;
      if (a.getUint32(i) != b.getUint32(i)) differing++;
    }
  }
  return differing;
}

/// Ink on those same rows and columns, so the sweep above cannot pass by
/// having looked at background. `live` is the untiled capture.
int inkOnTileEdges(ByteData live,
    {required int tileDevicePixels, required int width, required int height}) {
  var ink = 0;
  bool onEdge(int v) {
    final m = v % tileDevicePixels;
    return m == 0 || m == 1 || m == tileDevicePixels - 1;
  }

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (!onEdge(x) && !onEdge(y)) continue;
      // Opaque and not the white page: a drawn pixel.
      if (live.getUint32((y * width + x) * 4) != 0xFFFFFFFF) ink++;
    }
  }
  return ink;
}
```

`captureTiled` renders the widget as it stands. `captureLive` rebuilds the same
document, index and camera with `tiles: false` and captures that. Both go
through `tester.runAsync` and `RenderRepaintBoundary.toImage`, the pattern
`tile_comparison.dart` already uses.

`bandCrossingGrid` must satisfy anti-degenerate clauses 2 and 5: entities
**longer than one tile** — a 64-device-pixel tile is 32 logical at `kTileDpr`,
so lines of 200 logical units cross six tiles — and a fixture placed at the
far-from-origin coordinates `tile_fixture.dart` already uses, never at (0, 0).

- [ ] **Step 4: Run and watch them pass**

Run: `cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_slice_differential_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Fire M3, M7, M9, M10, M11 and M8**

| Mutant | Edit | Expected |
|---|---|---|
| M3 | `sliceSourceRect` returns `Rect.fromLTWH(0, 0, tile, tile)` | arms 1, 2 and 4 red |
| M7 | `bandsFor` clamps its rects to the viewport | arm 2 red |
| M9 | `const pad = 0.0` in `_bakeBand` | arm 1 red on `bandCrossingGrid` |
| M10 | `sliceSourceRect` drops `- band.deviceRect.left` | arm 3 red |
| M11 | `_bakeBand` derives its own origin from the band | the Task 6 boundary test red |
| M8 | `_sliceTile` uses a `FilterQuality.low` paint | **green — a declared survivor** |

**M8 is expected to survive** and is recorded as such, not as a gate's failure.
With integral source rectangles a bilinear sample and a nearest sample read the
same texels; only a sampler is paid for. Plan 3h's M6 had this shape and was
recorded as gap H6.

- [ ] **Step 6: Commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "test(tiles): differential arms for the slice, the overhang and the pan"
```

---

## Task 10: Criterion 10 — an edit after a settle invalidates

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`

**Interfaces:**
- Consumes: the shared `_baked` record from Task 8.

**Why this is a correctness gate and not a nicety.** `_invalidateTouched`
condemns tiles by iterating `_baked` in both directions. A sliced tile with no
record is invisible to both: edit an entity after a settle and the stale tile
keeps blitting over the corrected drawing, with `invalidationCount` reading
zero. **M5** is exactly that mutation.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('an edit after a sliced settle condemns the sliced tiles',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    final tilesBefore = h.cache.liveTileCount;
    expect(tilesBefore, greaterThan(0),
        reason: 'not vacuous: there must be tiles to condemn');
    final invalidationsBefore = h.cache.invalidationCount;

    h.moveOneEntityOntoDisjointTiles();
    await t.pump();

    expect(h.cache.invalidationCount, greaterThan(invalidationsBefore),
        reason: 'sliced tiles carry the band record, so the edit reaches them');
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'and the drawing is correct afterwards, which is the half a '
            'counter alone cannot show');
  });
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `invalidationCount` unchanged, and the pixels differ.

- [ ] **Step 3: The implementation is Task 8's `_baked[key] = record;`**

If Task 8 landed it, this test passes as written and Step 2's failure must be
produced by firing M5 first. **Fire M5 before claiming this task**: delete
`_baked[key] = record;`, watch this test go red, restore, record the verbatim
output under **M5**.

- [ ] **Step 4: Run the package and commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "test(tiles): an edit after a sliced settle must condemn the slices"
```

---

## Task 11: The rig's `tile zoom` phase

**Files:**
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart`

**Interfaces:**
- Consumes: `runTilePhases(..., required double panStep)`, already in the rig
  from Plan 3h.
- Produces: `Future<ZoomReport> runTileZoomPhase({required CameraController
  camera, required TileCache cache, required Future<void> Function() pumpFrame,
  required Size viewport})`, and

  ```dart
  class ZoomReport {
    final List<double> gestureFrameMs;   // 80 entries
    final int gestureBakes;
    final int gestureLiveDraws;
    final double settleMs;               // totalSpan of the rest frame
    final int settleFrames;
  }
  ```

**The script is pinned by the spec, §5, and is not the implementer's to
choose:**

- **Viewport 1600x1200 logical at `devicePixelRatio` 2.** Every memory figure
  is priced against it. The 800x600 numbers in `STATUS.md` are a test viewport.
- Start from R2's fitted camera, so the zoom arm and the pan arm share a start.
- Focal point at **30% / 70%** of the viewport — off-centre, so the anchor is
  not the trivial centre.
- **40 steps in at factor 1.03, then 40 steps out at 1/1.03.** 1.03^40 = 3.26x
  each way, which crosses at least one power-of-two rebase step
  (anti-degenerate clause 3).
- **One camera change per frame**, matching what a trackpad delivers.
- **Then 30 idle frames**, where criteria 3 and 4 are read.
- **p95 over the 80 gesture frames**, counters reset after the fitted camera
  settles so warm-up is excluded.

- [ ] **Step 1: Write the failing test**

```dart
// apps/dev_harness_2d/test/zoom_script_test.dart
void main() {
  test('the pinned script is 40 in, 40 out, at 1.03', () {
    expect(kZoomSteps, 40);
    expect(kZoomFactor, closeTo(1.03, 1e-12));
    // The span each way, and the reason clause 3 is satisfied: a 3.26x span
    // cannot sit inside one power-of-two rebase step.
    expect(math.pow(kZoomFactor, kZoomSteps), greaterThan(2.0));
  });

  test('the focal point is off-centre', () {
    const viewport = Size(1600, 1200);
    expect(zoomFocusFor(viewport), const Offset(480, 840));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd apps/dev_harness_2d && CI=true flutter test test/zoom_script_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

```dart
/// Steps in each direction. See the plan's Task 11 for why 40 and not fewer:
/// 1.03^40 = 3.26x, which cannot sit inside one power-of-two rebase step.
const int kZoomSteps = 40;

/// Per-step zoom factor, matching what one trackpad update delivers.
const double kZoomFactor = 1.03;

/// Deliberately off-centre, at 30% / 70%. A focal point at the viewport's
/// centre is the degenerate case: the anchor coincides with the rebase
/// origin's own centre and half the residual arithmetic never runs.
Offset zoomFocusFor(Size viewport) =>
    Offset(viewport.width * 0.30, viewport.height * 0.70);
```

and `runTileZoomPhase`, which drives `kZoomSteps` frames in, `kZoomSteps` out,
then 30 idle frames, reading `cache.bakeCount`, `cache.liveDrawCount` and the
frame timings the rig already collects for its other phases.

- [ ] **Step 4: Run it and watch it pass**

- [ ] **Step 5: Commit**

```bash
cd apps/dev_harness_2d && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed lib test
git add -A apps/dev_harness_2d
git commit -m "feat(harness): a pinned tile zoom phase, 40 in and 40 out"
```

---

## Task 12: Criteria 2 and 4 on the device

**Files:**
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`
- Create: `docs/superpowers/notes/2026-08-26-plan-3i-results.md`

**Interfaces:**
- Consumes: `runTileZoomPhase` from Task 11.
- Produces: the interleaved driver
  `Future<void> runInterleaved({required int arms, required Future<void>
  Function() rest, required Future<void> Function() tiled})`.

**Criterion 4's numerator and denominator are named by the spec and are not the
implementer's to choose.** It is **wall clock to a covered viewport, from the
first frame after the gesture ends to the frame that covers it.** The rest-bake
arm is one frame; the tiled arm is today's behaviour with the rest bake
disabled. Work-for-work — 71.97 ms against 32.06 — is *not* the measurement:
that comparison would fail a 3x gate while the behaviour improved by an order
of magnitude, and picking whichever reading passes after the fact is the exact
failure Plan 3h recorded.

**The arrangement is part of the criterion.** Same session, **interleaved**
(rest, tiled, rest, tiled, …), never blocked. The interleaved unit is **one
whole arm**, not one frame, and the report gives every arm's number and not
only the aggregate.

- [ ] **Step 1: Run the arrangement**

```bash
cd apps/dev_harness_2d
# Mains power, Low Power Mode OFF -- `pmset -g | grep lowpowermode` must read 0.
CI=true flutter run -d macos --profile \
  --dart-define=TILES=on --dart-define=ENTITIES=50000 --dart-define=RUN_R2=true \
  --dart-define=ZOOM_ARMS=4
```

Repeat at `ENTITIES=500000` (anti-degenerate clause 4).

- [ ] **Step 2: Record every arm, not the aggregate**

Write `docs/superpowers/notes/2026-08-26-plan-3i-results.md` with a row per arm
per corpus: gesture p95, gesture bakes, gesture live draws, settle wall clock,
settle frames. **Never synthesize output.** If a run is refused — Low Power
Mode, battery — say so and stop rather than estimating.

- [ ] **Step 3: Score criterion 9 — the pan path did not regress**

Plan 3h's `tile pan` and `tile hold` phases run in the same session, from the
same binary, against the same corpora. Their criteria are unchanged and their
thresholds are not this plan's to move. Report both p95 figures beside Plan
3h's recorded ones; a regression is a miss of criterion 9 and is recorded as
one rather than explained away.

**This is the criterion M7 cannot be caught by**, and the plan says so where a
reader might otherwise expect it to: a transparent overhang blits at the cost
of an opaque one, so criterion 9's timing sees nothing. Criterion 11's sub-tile
pan arm is M7's only gate.

- [ ] **Step 4: Score criteria 2 and 4 against their thresholds**

Criterion 2: p95 within 16.67 ms at both corpora. Criterion 4: the ratio at or
above 3x, computed per arm and reported per arm. Record a miss as a miss.
**Do not adjust a threshold to meet a number.**

- [ ] **Step 5: Commit**

```bash
git add -A apps/dev_harness_2d docs/superpowers/notes/2026-08-26-plan-3i-results.md
git commit -m "measure: criteria 2 and 4 on the device, interleaved"
```

---

## Task 13: Criterion 8 — Plan 3h's criterion 3, re-measured

**Files:**
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`
- Modify: `docs/superpowers/notes/2026-08-26-plan-3i-results.md`

**What this is.** Plan 3h's headline criterion read **2.35x against a gate of
2.4x** and missed. At n=3 per arm the measurement cannot settle whether that is
real or noise — nine pairwise ratios spanned 1.82 to 2.84 — and **the 2.4 gate
was itself mis-derived** from a cross-session numerator, the exact comparison a
ratio measured in one session exists to prevent. Plan 3h handed the
re-measurement here.

**The gate is the arrangement and the report, not the number.** If the ratio
still reads below 2.4 at n=9 interleaved, that is an answer and it is recorded
as one. Nothing in this task adjusts the 2.4 gate.

- [ ] **Step 1: Run n=9, interleaved**

Arms alternate narrow, M4, narrow, M4, … — never three-then-three. Blocked
arrangement is what produced the thermal and session-drift ordering bias Plan
3h's own numbers show.

- [ ] **Step 2: Record all nine arms and the pairwise ratios**

Every arm's p95, and the ratio computed per pair, not only the median of
medians. The spread is the finding, whatever the centre reads.

- [ ] **Step 3: State the outcome plainly**

Whether 2.35 was noise, whether the effect is real, and whether the 2.4 gate
was reachable. **The mean is evidence and never a gate** — that is how Plan 3h
recorded the same quantity.

- [ ] **Step 4: Commit**

```bash
git add -A docs/superpowers/notes/2026-08-26-plan-3i-results.md
git commit -m "measure: Plan 3h's criterion 3 at n=9, interleaved"
```

---

## Task 14: The record, and reconciling `STATUS.md`

**Files:**
- Modify: `docs/superpowers/notes/plan-3i-mutation-log.md`
- Modify: `docs/superpowers/notes/2026-08-26-plan-3i-results.md`
- Modify: `STATUS.md`

**Interfaces:** none. This is the plan's exit gate.

- [ ] **Step 1: Complete the mutation log**

Eleven sections, one per mutant, each with the diff, the layer it fired in, the
**verbatim** output, and the ruling. **M8 is recorded as a survivor**, declared
before it was fired, and is not written up as a gate's failure.

- [ ] **Step 2: Score the exit gate**

Eleven criteria. State how many pass, how many miss, and name every miss in the
first paragraph rather than the last. Plan 3h's record leads with its misses
and that is the house style.

- [ ] **Step 3: Reconcile `STATUS.md`**

`STATUS.md` still describes 3i as "zoom, G3, and level-of-detail geometry" and
says the answer is level-of-detail geometry. **This plan declined LOD**, and
the spec says what would put it back: a target of correct geometry while the
fingers are still moving. Update the Plan 3i entry, move G3 to the open-gap
list with that condition attached, and add the new gaps this plan accepted —
the zoom-out background ring, an edit landing mid-gesture, the resting frame's
ungated duration.

Also update **Verified against** to this plan's last code commit, and the
suite counts by running each suite rather than by reading a report.

- [ ] **Step 4: Archive the ledger**

`.superpowers/sdd/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/` is git-ignored and
lives in the worktree. Copy it verbatim to
`docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/`, add a row
to `ledgers/README.md`, and commit **before** clearing it. The ordering is the
lesson every archive note in `STATUS.md` records.

- [ ] **Step 5: Commit**

```bash
git add -A docs/superpowers STATUS.md
git commit -m "docs: Plan 3i's record -- criteria, mutants, and STATUS reconciled"
```

---

## Exit gate

The plan is done when all of these hold:

1. Eleven criteria scored, every miss named in the results note's first
   paragraph.
2. Eleven mutants fired, ten dead, **M8 recorded as the declared survivor**.
3. Five anti-degenerate clauses satisfied by the fixture and the script, each
   with the assertion that proves it.
4. Every suite green: `packages/jet_cad_2d`, `packages/jet_cad_2d_flutter`,
   `apps/dev_harness_2d` — tests, analyze and format.
5. `STATUS.md` reconciled with the spec on LOD, and the ledger archived.
