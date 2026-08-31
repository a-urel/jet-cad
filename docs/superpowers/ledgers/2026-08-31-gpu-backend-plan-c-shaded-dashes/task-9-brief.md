### Task 9: The fragment stage gets an instrument

**Files:**
- Modify: `test/support/triangle_rasterizer.dart`
- Modify: `test/support/gpu_comparison.dart`
- Test: `test/support/triangle_rasterizer_test.dart`

**Interfaces:**
- Produces: `TriangleRasterizer.observe(positions, colors, {Float32List? dash})`
  and `measureResidentAgreement(..., {required double dashScale})`.

**Why this is its own task.** Every gate in this package rasterises through
`TriangleRasterizer`, and it has never had a fragment stage worth the name —
`_fill` sets a pixel whenever it is inside the triangle. A dash is the first
thing this backend draws that a *fragment* decides. Without this task the
resident arm's dashes are invisible to every pixel gate in the suite, and Task
10 would compare two arms neither of which dashed.

- [ ] **Step 1: Write the failing tests**

In `test/support/triangle_rasterizer_test.dart`:

```dart
  test('without dash varyings, nothing changes', () {
    // The existing tests in this file are the regression suite for this
    // claim; this one pins the contract explicitly.
    final r = TriangleRasterizer(16, 16);
    r.observe(oneTrianglePositions, oneTriangleColors);
    expect(inkCount(r), unchangedFromBefore);
  });

  test('a fragment outside the element\'s extent is not inked', () {
    // One axis-aligned quad, 20 px long, period 10, element [0, 0.5): the
    // left half of each 10 px cycle is inked and the right half is not.
    final r = TriangleRasterizer(24, 8);
    r.observe(quadPositions, quadColors, dash: quadDashVaryings);
    expect(r.inked(2, 4), isTrue);
    expect(r.inked(7, 4), isFalse);
    expect(r.inked(12, 4), isTrue);
    expect(r.inked(17, 4), isFalse);
  });

  test('t is interpolated barycentrically, not taken from a vertex', () {
    // A triangle whose three vertices carry t = 0, 1 and 2. The pixel at the
    // centroid must read 1.0. Taking any single vertex's value would read
    // 0, 1 or 2, and only one of those three is right by accident.
    expect(tAtCentroid, closeTo(1.0, 1e-3));
  });

  test('a negative fracStart disables the test for that triangle only', () {
    // Two triangles in one observe call, one solid and one dashed. The solid
    // one must ink its gap positions.
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

- [ ] **Step 3: Implement the fragment test**

`observe` gains `{Float32List? dash}` — three floats per vertex, same vertex
order as `positions`. `_fill` gains the triangle's three `(t, start, end)`
triples and, inside its pixel loop, after the three edge functions pass:

```dart
        if (hasDash) {
          // Barycentric weights from the edge functions already computed.
          // `w0` is the edge (a, b) against p, which is proportional to the
          // weight of the OPPOSITE vertex, c -- getting that correspondence
          // wrong reads a plausible number at every pixel and the wrong one
          // at all but the centroid.
          final sum = w0 + w1 + w2;
          if (sum <= 0) continue;
          final t = (w1 * ta + w2 * tb + w0 * tc) / sum;
          final f = t - t.floorToDouble(); // `fract`
          if (f < startA || f >= endA) continue;
        }
```

`startA`/`endA` come from vertex `a`; all three vertices of a triangle carry
the same element extent by construction, and **the implementer must assert
that** rather than assume it:

```dart
      assert(startA == startB && startA == startC,
          'every vertex of one instance carries the same element extent; '
          'a triangle whose vertices disagree came from two instances');
```

**Update the class doc.** `gpu_comparison.dart`'s header lists three things
that instrument cannot measure, and one of them — *"geometry added INSIDE the
existing footprint is invisible"* — is now **more** true, not less: a dash gap
removes ink, which the differential does see, but a wrongly-*kept* fragment
inside another primitive's footprint still does not move a pixel. Say so.

- [ ] **Step 4: Thread the varyings through `gpu_comparison.dart`**

`measureResidentAgreement` gains `{required double dashScale}`, passes it to
`expandInstances`, and hands `expanded.dashVaryings` to
`residentRaster.observe`.

**And it gains the harder half: the two arms now reach the same picture by two
different routes.** The reference arm must be given spans and the resident arm
the pattern. The closure the caller passes takes a `DrawSink` and can branch on
`sink.shadesDashes` — which is exactly what the painter does, so the honest
form of this helper is to **drive `DraftPainter` itself** rather than a
hand-written closure. Add a second entry point beside the existing one:

```dart
/// Draws [document] through both arms with the real painter, at [camera].
///
/// **The two arms take different routes through `DraftPainter` and that is
/// the point.** `VerticesDrawSink.shadesDashes` is false, so the painter cuts
/// the spans; `GeometryCollector.shadesDashes` is true, so the painter hands
/// over the pattern. A closure written here that dashed for one arm and not
/// the other would be a third implementation of that branch, and the branch
/// is what this comparison is for.
ResidentAgreement measurePaintedAgreement(
  DraftDocument document, {
  required ViewportTransform camera,
  required Size size,
  required double devicePixelRatio,
  required double pixelsPerPaperMm,
}) { ... }
```

Its `dashScale` is `1.0`: both arms are painted at the same camera the buffer
is collected at, so the live-to-collection ratio is exactly 1. **Say that in
the code**, and have Task 10 assert it rather than leaving a literal `1.0`
unexplained.

- [ ] **Step 5: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the coverage rasterizer learns the one thing a fragment decides"
```

---

