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

