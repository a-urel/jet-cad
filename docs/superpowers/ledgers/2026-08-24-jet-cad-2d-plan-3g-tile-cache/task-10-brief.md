## Task 10: The cap, eviction, and criteria 12 and 13

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- Create: `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`

**Interfaces:** produces `TileCache.liveBytes`, `evictionCount`, `blitDestinationCount`.

- [ ] **Step 1: Write the failing invariants**

Create `packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart`:

```dart
// Criteria 12 and 13, always on.
//
// **Criterion 13 is a field read and not a heap measurement, and `STATUS.md`
// says why.** There is no working Flutter-side allocation meter -- trap 5 --
// and `paint_allocation_test.dart` reads one field,
// `VerticesDrawSink.debugCapacityVertices`, which can see neither a `Paint`
// nor a `Rect`. So this pins the `Paint`'s identity and the per-frame
// destination count instead, the same shape `VerticesDrawSink.debugPaint`
// already uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/tile_fixture.dart';

void main() {
  test('criterion 12: the cap holds and eviction is real, not theoretical',
      () async {
    // A cap of eight tiles at 64 device pixels: 8 * 64 * 64 * 4 = 131,072 B.
    // Small on purpose -- the point is that the policy runs, and a production
    // cap would need a corpus this suite cannot afford.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: 131072);
    addTearDown(rig.dispose);

    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, -32);
      rig.paintOnce();
      expect(rig.cache.liveBytes, lessThanOrEqualTo(131072),
          reason: 'pan $i');
    }
    expect(rig.cache.evictionCount, greaterThan(0),
        reason: 'anti-degenerate clause 7: a cap nothing reaches is not a cap');
  });

  test('criterion 12: a pan back to reclaimed tiles draws live, not blank',
      () async {
    // Anti-degenerate clause 7. This is the failure that would ship as an
    // intermittent blank strip: no settled-frame criterion can see it.
    final rig = TileRig(
        tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: 131072);
    addTearDown(rig.dispose);
    rig.paintOnce();
    for (var i = 0; i < 6; i++) {
      rig.panBy(-64, 0);
      rig.paintOnce();
    }
    rig.cache.resetCounters();
    for (var i = 0; i < 6; i++) {
      rig.panBy(64, 0);
      rig.paintOnce();
    }
    expect(rig.cache.liveDrawCount, greaterThan(0),
        reason: 'the camera returned to tiles the cap reclaimed');
  });

  test('criterion 13: allocation is viewport-bounded and the Paint is one',
      () async {
    final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
    addTearDown(rig.dispose);
    rig.paintOnce();
    final paint = rig.cache.debugBlitPaint;
    rig.cache.resetCounters();
    rig.paintOnce();
    final first = rig.cache.blitDestinationCount;
    rig.cache.resetCounters();
    rig.paintOnce();

    expect(identical(rig.cache.debugBlitPaint, paint), isTrue);
    expect(rig.cache.blitDestinationCount, first,
        reason: 'two identical frames allocate the same number of rects: '
            'bounded by the viewport over the tile size, not by entity count');
    expect(first, lessThan(200),
        reason: 'a viewport quantity. If this grows with the document, the '
            'per-entity half of the rule is broken.');
  });
}
```

- [ ] **Step 2: Implement LRU**

Track insertion/use order and `liveBytes = _tiles.length * tileDevicePixels * tileDevicePixels * 4 + (carry-over bytes)`. Evict least-recently-blitted, never a tile blitted this frame. Import `dart:math` here if the eviction loop needs it; not before — `unused_import` is an error.

- [ ] **Step 3: Fire M6**

Delete the eviction call. Criterion 12's cap assertion must go red. Restore from a copy.

- [ ] **Step 4: Green and commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
git commit -m "feat: the cap, eviction, and the two invariants that run every suite

Criterion 13 is a field read and not a heap measurement. STATUS records that
there is no working Flutter-side allocation meter and that trap 5 needs a
direct assertion instead; paint_allocation_test reads one field that can see
neither a Paint nor a Rect. So the Paint's identity and the per-frame
destination count are pinned, the shape VerticesDrawSink.debugPaint uses.

The eviction test pans away and back. That path -- the camera returning to
tiles the cap reclaimed -- is the one that would have shipped as an
intermittent blank strip, and no settled-frame criterion can see it."
```

---

