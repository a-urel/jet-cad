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

