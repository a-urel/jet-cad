### Task 7: The fill corpus in the pixel gate, and spec criterion 4

**Files:**
- Modify: `test/gpu/resident_pixel_differential_test.dart`
- Create: `test/gpu/fill_order_test.dart`
- Modify: `test/gpu/collector_differential_test.dart`

**Interfaces:**
- Consumes: `fillFixture()` (Task 4), `measureResidentColor` and its
  `permute` (Task 6), `kKindFill`.

**Spec criterion 4, verbatim:** *"Submitting the buffer out of walk order
changes the rendering on the fill-overlap corpus, and the test asserts it
does."* This is the criterion no earlier plan could write a failing case for.

- [ ] **Step 1: Write the failing tests**

`test/gpu/fill_order_test.dart`:

```dart
/// Spec criterion 4: emission order is the drawing, and a permutation of the
/// buffer is a different picture.
///
/// **This file exists because of fills.** A permutation of strokes preserves
/// the union of covered pixels, so the coverage instrument cannot see it --
/// `gpu_comparison.dart` says so. A fill covers a stroke, so reordering the
/// two changes the colour of every pixel they share. Without a fill in the
/// corpus this whole file passes vacuously, which is why the first test
/// below asserts the corpus's own overlap before the second asserts the
/// permutation changes it.
void main() {
  test('the fill corpus really does have a stroke drawn over a fill', () {
    final c = collectFillFixture();
    final data = c.data;
    var lastFill = -1, strokeAfterFill = -1;
    for (var i = 0; i < c.instanceCount; i++) {
      final kind = data[i * kFloatsPerInstance + InstanceFieldOffset.kind];
      if (kind == kKindFill) lastFill = i;
      if (kind == kKindStroke && lastFill >= 0 && strokeAfterFill < 0) {
        strokeAfterFill = i;
      }
    }
    expect(lastFill, greaterThanOrEqualTo(0), reason: 'no fill was collected');
    expect(strokeAfterFill, greaterThan(lastFill),
        reason: 'no stroke is emitted after a fill, so no permutation of '
            'this corpus could change a pixel and criterion 4 would pass '
            'vacuously');
  });

  test('submitting the buffer out of walk order changes the rendering', () {
    // In walk order the higher-handle stroke is drawn after the fill and is
    // visible over it. Sorted by kind -- which is what a separate pipeline
    // per kind would submit -- every fill is drawn last and covers it.
    final inOrder = renderFillFixture();
    final byKind = renderFillFixture(permute: sortByKind);

    final differing = countDifferingPixels(inOrder, byKind);
    expect(differing, greaterThan(200),
        reason: 'a permutation that changed no pixel would mean this gate '
            'cannot fail, whatever it reads');
  });

  test('the resident arm matches the reference in walk order and only there',
      () {
    final ordered = measureResidentColor(paintFillFixture,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    expect(ordered.withinTwoFraction, greaterThanOrEqualTo(0.995),
        reason: ordered.toString());

    final permuted = measureResidentColor(paintFillFixture,
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: _ppmm,
        permute: sortByKind);
    expect(permuted.withinTwoFraction, lessThan(0.995),
        reason: 'if a kind-sorted buffer still matched the reference, this '
            'backend would have no order to preserve and the single-draw-call '
            'design would be unnecessary: ${permuted.toString()}');
  });
}
```

`sortByKind` returns a stable permutation of instance indices ordered by the
record's `kind` slot — the order three pipelines would submit in. Write it in
this file; it is a test-only ordering and must never appear in `lib/`.

Add to `resident_pixel_differential_test.dart`:

```dart
  test('the fill corpus agrees per channel', () {
    final r = measureResidentColor(paintFillFixture,
        size: _size, devicePixelRatio: _dpr, pixelsPerPaperMm: _ppmm);
    expect(r.withinTwoFraction, greaterThanOrEqualTo(0.995), reason: r.toString());
    expect(r.overEight, 0, reason: r.toString());
    expect(r.referenceInk, greaterThan(5000), reason: r.toString());
  });
```

And to `collector_differential_test.dart`, extend the existing record-level
walk to the fill fixture: every instance's `kind`, `argb` and three points
must match the reference's triangle stream, in order.

**A fill's colour is gated here as well as in the pixel gate, and the reason
belongs in the test's comment.** Only the resident arm has `_coveredArgb`
within reach of a fill — the reference passes `style.argb` straight through
(`vertices_draw_sink.dart:752-757`) — so a faded fill is a real difference
the colour instrument would also see. The record-level assertion is kept
because it names the wrong *value*, where the pixel gate only reports a
percentage.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/fill_order_test.dart
```
Expected: compile failure first, then a real failure if the corpus's overlap
is too small — which is a corpus defect, and Task 4's guard is where it gets
fixed, not here.

- [ ] **Step 3: Implement the helpers**

`collectFillFixture`, `renderFillFixture`, `paintFillFixture` and
`countDifferingPixels` go in `test/support/gpu_comparison.dart` beside the
measurement, so `fill_order_test.dart` holds assertions and nothing else.
`paintFillFixture(DrawSink sink)` paints `fillFixture()` through
`DraftPainter` at the fitted camera — the fills only exist through the painter,
which is what resolves a fill entity to its boundary's triangulation.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git status --short
git add test/gpu/fill_order_test.dart test/gpu/resident_pixel_differential_test.dart test/gpu/collector_differential_test.dart test/support/gpu_comparison.dart
git commit -m "test(gpu): emission order is the drawing, and a fill proves it"
```

---

