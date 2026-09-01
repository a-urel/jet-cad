### Task 6: The pixel instrument learns colour

**Files:**
- Modify: `test/support/gpu_comparison.dart`
- Test: `test/gpu/resident_pixel_differential_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class ResidentColorAgreement {
    final int union;        // pixels either arm inked
    final int withinTwo;    // per-channel difference <= 2
    final int overEight;    // per-channel difference > 8
    final int referenceInk;
    double get withinTwoFraction;
  }

  ResidentColorAgreement measureResidentColor(
      void Function(DrawSink) corpus,
      {required Size size,
      required double devicePixelRatio,
      required double pixelsPerPaperMm,
      List<int> Function(List<int> order)? permute});
  ```

**Why this exists** (Ruling D8): `gpu_comparison.dart`'s own doc records that
its coverage measurement cannot see order, and that *"the per-channel half of
the design document's criterion 1 is not something this file can gate"*. Both
sentences stop being true here, and both must be **rewritten in this task**,
not left standing next to a measurement that contradicts them.

`permute` reorders the *instance* buffer before expansion, so a caller can
submit the same instances out of walk order. It is `null` for every ordinary
measurement; Task 7 is its only caller.

- [ ] **Step 1: Write the failing test**

In `test/gpu/resident_pixel_differential_test.dart`:

```dart
  test('the two arms agree per channel, not merely on coverage', () {
    final r = measureResidentColor(_corpus,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    // Spec criterion 1: per-channel difference <= 2 on >= 99.5% of pixels,
    // <= 8 on the rest.
    expect(r.withinTwoFraction, greaterThanOrEqualTo(0.995), reason: r.toString());
    expect(r.overEight, 0, reason: r.toString());
    // Anti-vacuity: an instrument that measured an empty picture would pass
    // both lines above.
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
  });

  test('the colour measurement can actually fail', () {
    // The control arm Plan 3i's Ruling 14 requires: an instrument whose
    // failing case is never exercised reads 1.00 and proves nothing. Here
    // the resident arm is fed a deliberately recoloured buffer.
    final r = measureResidentColor(_corpus,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        debugTintResident: 0x00202020);
    expect(r.withinTwoFraction, lessThan(0.995), reason: r.toString());
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_pixel_differential_test.dart
```
Expected: compile failure — `measureResidentColor` is undefined.

- [ ] **Step 3: Implement the measurement**

In `gpu_comparison.dart`, beside `measureResidentAgreement`:

```dart
/// A per-channel comparison of the two arms' rasterised colour.
///
/// **This is the half of spec criterion 1 that coverage cannot reach.**
/// `TriangleRasterizer._fill` is last-write-wins with no blending, so a
/// pixel's final colour is the colour of the *last* triangle to cover it --
/// which makes this the only measurement in the suite that can see emission
/// order at all. Both arms share the rasterizer, so the absence of blending
/// cancels exactly the way MSAA does in the device comparison.
class ResidentColorAgreement {
  ResidentColorAgreement(
      this.union, this.withinTwo, this.overEight, this.referenceInk);

  /// Pixels either arm inked. The comparison runs over these: a pixel
  /// neither arm touched is background on both sides and says nothing.
  final int union;

  /// Pixels whose every channel differs by at most 2.
  final int withinTwo;

  /// Pixels with any channel differing by more than 8 -- spec criterion 1
  /// allows none.
  final int overEight;

  final int referenceInk;

  double get withinTwoFraction => union == 0 ? 1.0 : withinTwo / union;

  @override
  String toString() => 'union=$union withinTwo=$withinTwo '
      '(${(withinTwoFraction * 100).toStringAsFixed(3)}%) '
      'overEight=$overEight referenceInk=$referenceInk';
}
```

`measureResidentColor` runs the same two arms `measureResidentAgreement`
does — `VerticesDrawSink` with the rasterizer attached as its observer, and
`GeometryCollector` expanded through `expandInstances` into a second
rasterizer — then walks both `pixels` buffers once:

```dart
  var union = 0, withinTwo = 0, overEight = 0, referenceInk = 0;
  for (var i = 0; i < reference.pixels.length; i++) {
    final a = reference.pixels[i], b = resident.pixels[i];
    if (a != 0) referenceInk++;
    if (a == 0 && b == 0) continue;
    union++;
    var worst = 0;
    for (var shift = 0; shift < 32; shift += 8) {
      final d = (((a >> shift) & 0xFF) - ((b >> shift) & 0xFF)).abs();
      if (d > worst) worst = d;
    }
    if (worst <= 2) withinTwo++;
    if (worst > 8) overEight++;
  }
```

`debugTintResident` adds its argument to the resident arm's every written
colour before rasterisation — **test-only, and it must never appear in
`lib/`**, exactly as `TriangleRasterizer.debugDisableDashTest` is documented.

- [ ] **Step 4: Rewrite the two doc paragraphs that are now false**

`gpu_comparison.dart`'s header says colour and order are unmeasurable.
Replace both paragraphs, keeping their history:

```dart
/// **Colour agreement was unmeasurable until Plan D, and the limitation is
/// recorded rather than deleted.** Until [measureResidentColor] existed this
/// file could only compare coverage, so [ResidentAgreement.differing] and
/// [ResidentAgreement.overEight] were always the same number and neither
/// measured colour. That is still true of [ResidentAgreement] itself --
/// it is a coverage instrument and stays one. [ResidentColorAgreement] is
/// the per-channel measurement, and it is what spec criterion 1's first
/// clause is gated by.
///
/// **Draw order likewise.** Coverage cannot see a permutation that preserves
/// the union of footprints, which is every permutation of strokes. It can be
/// seen in colour, and only once the corpus contains a fill: a large opaque
/// shape drawn over a stroke changes that stroke's pixels' colour without
/// changing whether they are inked. `test/gpu/fill_order_test.dart` is the
/// gate; this instrument is what makes it possible.
```

- [ ] **Step 5: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/support/gpu_comparison.dart test/gpu/resident_pixel_differential_test.dart
git commit -m "test(gpu): the pixel instrument compares colour, not only coverage"
```

---

