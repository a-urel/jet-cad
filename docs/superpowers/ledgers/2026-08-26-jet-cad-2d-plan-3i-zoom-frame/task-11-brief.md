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

