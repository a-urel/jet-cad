## Task 2: `TextMetrics`, the measurer seam, and the metric model

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/text_metrics.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart` (drop `TextMeasurer`/`InsertionPointMeasurer`, import them)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- Test: `packages/jet_cad_2d/test/document/text_metrics_test.dart`

**Interfaces:**
- Consumes: `TextStyleRecord` from `tables.dart`.
- Produces: `TextMetrics({advanceWidth, ascent, descent, capHeight})`, `TextMetrics.zero`; `abstract class TextMeasurer { TextMetrics measure({required String text, required TextStyleRecord style}); }`; `InsertionPointMeasurer`; `MetricModelMeasurer({double advanceRatio = 0.55, double ascentRatio = 0.8, double descentRatio = 0.2, double capRatio = kCapHeightRatio})`; `const double kNominalTextPixels = 100.0`; `const double kCapHeightRatio = 0.7`.

- [ ] **Step 1: Write the failing test**

```dart
// test/document/text_metrics_test.dart
test('the metric model is deterministic and its ascent differs from its descent',
    () {
  const m = MetricModelMeasurer();
  final metrics = m.measure(text: 'WC', style: _style);

  expect(metrics.advanceWidth, closeTo(2 * 0.55 * kNominalTextPixels, 1e-9));
  expect(metrics.ascent, closeTo(0.8 * kNominalTextPixels, 1e-9));
  expect(metrics.descent, closeTo(0.2 * kNominalTextPixels, 1e-9));
  expect(metrics.capHeight, closeTo(0.7 * kNominalTextPixels, 1e-9));
  // A model whose ascent equals its descent hides every vertical
  // justification defect, so this inequality is load-bearing.
  expect(metrics.ascent, isNot(closeTo(metrics.descent, 1e-9)));
});

test('measure returns the identical instance on a repeat call', () {
  const m = MetricModelMeasurer();
  final a = m.measure(text: 'T-0001', style: _style);
  final b = m.measure(text: 'T-0001', style: _style);
  // The pick path measures per candidate. A fresh object per call breaks
  // query_allocation_test.
  expect(identical(a, b), isTrue);
});

test('the insertion-point measurer is a declared lower bound', () {
  expect(const InsertionPointMeasurer().measure(text: 'WC', style: _style),
      same(TextMetrics.zero));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/text_metrics_test.dart`
Expected: FAIL — `MetricModelMeasurer` is undefined.

- [ ] **Step 3: Write `text_metrics.dart`**

```dart
/// The em size every paragraph is laid out at.
///
/// Layout is size-independent here on purpose: height, rotation, width factor
/// and oblique angle are all transforms, so one laid-out paragraph serves the
/// same string at every size. Laying out at the *effective* size instead
/// renders correctly and silently destroys the cache.
const double kNominalTextPixels = 100.0;

/// Cap height as a fraction of the em size.
///
/// DXF's text height is the height of a capital letter; a font's `fontSize` is
/// the em size. `dart:ui` exposes no cap height — `computeLineMetrics` gives
/// ascent and descent only — so this constant stands in for it and the
/// deviation is declared rather than hidden.
const double kCapHeightRatio = 0.7;

@immutable
class TextMetrics {
  const TextMetrics({
    required this.advanceWidth,
    required this.ascent,
    required this.descent,
    required this.capHeight,
  });

  final double advanceWidth;
  final double ascent;
  final double descent;
  final double capHeight;

  static const TextMetrics zero =
      TextMetrics(advanceWidth: 0, ascent: 0, descent: 0, capHeight: 0);
}

/// Supplies font metrics at [kNominalTextPixels].
///
/// Takes the [TextStyleRecord], not a handle: `fontFamily`, `widthFactor` and
/// `obliqueAngle` live on the record, and a measurer is constructed before the
/// document that owns the table, so it cannot look one up.
abstract class TextMeasurer {
  TextMetrics measure({required String text, required TextStyleRecord style});
}

class InsertionPointMeasurer implements TextMeasurer {
  const InsertionPointMeasurer();

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      TextMetrics.zero;
}

/// Deterministic, font-free metrics for engine tests.
class MetricModelMeasurer implements TextMeasurer {
  const MetricModelMeasurer({
    this.advanceRatio = 0.55,
    this.ascentRatio = 0.8,
    this.descentRatio = 0.2,
    this.capRatio = kCapHeightRatio,
  });

  final double advanceRatio;
  final double ascentRatio;
  final double descentRatio;
  final double capRatio;

  // One entry per string length, since that is all this model depends on.
  // Memoised because the pick path measures per candidate and the allocation
  // harness forbids a fresh object there.
  static final Map<int, TextMetrics> _byLength = {};

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      _byLength.putIfAbsent(
          text.length,
          () => TextMetrics(
                advanceWidth: text.length * advanceRatio * kNominalTextPixels,
                ascent: ascentRatio * kNominalTextPixels,
                descent: descentRatio * kNominalTextPixels,
                capHeight: capRatio * kNominalTextPixels,
              ));
}
```

Note for the implementer: the static cache is keyed by length only because the
ratios are `const` defaults in practice. If a test constructs a model with
different ratios, key the map by `(length, advanceRatio, ascentRatio,
descentRatio, capRatio)` — Task 4's measurer-dependence test constructs a second
model, so do this now, not later.

- [ ] **Step 4: Move the seam and re-export**

Delete `TextMeasurer` and `InsertionPointMeasurer` from `extents.dart`, import them there instead, and add `export 'src/document/text_metrics.dart';` plus `export 'src/document/text_scalars.dart';` to `lib/jet_cad_2d.dart`.

- [ ] **Step 5: Run the suite — it will not compile yet**

Run: `cd packages/jet_cad_2d && dart analyze`
Expected: errors at `entityBounds`' text case (it still calls the old four-argument `measure`) and at every `DraftDocument` construction site that passes a measurer. Task 3 and Task 4 close them. **Do not commit a red tree**: finish Step 6 first.

- [ ] **Step 6: Stub the text case so the tree is green**

Temporarily, in `entityBounds`' text case: `return Aabb2(payload.pointAt(0), payload.pointAt(0));` with a `// Task 4 replaces this.` comment. Everything else compiles.

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS — the old text boxes were degenerate points anyway, so no existing expectation moves.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): add the TextMetrics seam and a deterministic metric model"
```

---

