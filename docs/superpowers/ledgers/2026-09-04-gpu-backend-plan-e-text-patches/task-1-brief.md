### Task 1: The collector records text, and the spec's one word

**Files:**
- Create: `lib/src/gpu/resident_text.dart`
- Modify: `lib/src/gpu/geometry_collector.dart` (constructor, fields, `skippedOps` doc, `text()`)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Modify: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` (Ruling E9's one word)
- Test: `test/gpu/resident_text_test.dart`

**Interfaces:**
- Consumes: `TextMeasurer.measure({text, style})`, `TextLayout.layOutBox(metrics)`
  (`packages/jet_cad_2d/lib/src/document/text_geometry.dart:231`), the collector's
  `_residual`, `_instances`, `devicePixelRatio`.
- Produces: `ResidentTextRecord` (the class restated above);
  `GeometryCollector({..., TextMeasurer? measurer, TextStyleRecord Function(Handle)? textStyleOf})`;
  `List<ResidentTextRecord> get texts` (unmodifiable view); `text()` records
  when both are non-null, counts otherwise (Ruling E2). This task also creates
  `lib/src/gpu/text_patches.dart` holding only the four constants (Step 4);
  Task 2 adds the functions to that same file, so each constant is declared
  exactly once.

- [ ] **Step 1: The spec's one word (Ruling E9)**

In the spec's text section, the sentence *"padded by one device pixel at the
band's upper scale bound so antialiased glyph edges and glyph overhang past the
advance box are inside it"* becomes *"padded by one device pixel at the band's
**lower** scale bound (Plan E's Ruling E9 — one device pixel is most collection
units at the band's floor, the same direction the reach takes) so antialiased
glyph edges and glyph overhang past the advance box are inside it"*. Use a
script with an exact-match assertion, not a hand edit:

```sh
python3 - <<'PY'
p = 'docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md'
s = open(p).read()
old = ("padded by one\n  device pixel at the band's upper scale bound so antialiased glyph edges and\n  glyph overhang past the advance box are inside it.")
assert s.count(old) == 1, s.count(old)
new = ("padded by one\n  device pixel at the band's **lower** scale bound (Plan E's Ruling E9 -- one\n  device pixel is most collection units at the band's floor, the same direction\n  the reach takes) so antialiased glyph edges and glyph overhang past the\n  advance box are inside it.")
open(p, 'w').write(s.replace(old, new))
print('ok')
PY
```

If the assertion fails, read the spec's current wording and adjust `old` — do
not skip the step.

- [ ] **Step 2: Write the failing tests**

Create `test/gpu/resident_text_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/text_patches.dart';

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// Fixed metrics, so the box below is arithmetic rather than font trivia:
/// advance 40, ascent 8, descent 2 -> glyph box (0, -2) .. (40, 8).
class _FixedMeasurer implements TextMeasurer {
  const _FixedMeasurer();
  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      const TextMetrics(advanceWidth: 40, ascent: 8, descent: 2, capHeight: 7);
}

const ResolvedStyle _style = ResolvedStyle(
    argb: 0xFF112233,
    lineweightHundredths: 25,
    linetype: Handle.none,
    linetypeScale: 1);

GeometryCollector _collector({double dpr = 2.0}) => GeometryCollector(
    pixelsPerPaperMm: 3.78,
    devicePixelRatio: dpr,
    measurer: const _FixedMeasurer(),
    textStyleOf: (Handle h) => _standard);

void main() {
  test('a text op becomes one record carrying the residual, flat', () {
    final c = _collector();
    // Rotated, sheared, non-uniform, off-origin: an identity residual would
    // leave b == c == 0 and hide a transposed element.
    const t = Transform2(2, 3, 5, 7, 110, -40);
    c.beginResidual(t, debugHandle: const Handle(901));
    c.text('WC', const Handle(11), _style);
    c.endResidual();

    expect(c.texts, hasLength(1));
    expect(c.skippedOps, 0, reason: 'text is recorded now, not counted');
    final r = c.texts.single;
    expect(r.text, 'WC');
    expect(r.style, const Handle(11));
    expect(r.argb, 0xFF112233);
    expect([r.a, r.b, r.c, r.d, r.e, r.f], [2, 3, 5, 7, 110, -40]);
  });

  test('the instance index is the number of instances written before it', () {
    final c = _collector();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 50, 0, 50, 40]), 3, _style,
        closed: false);
    c.endResidual();
    final before = c.instanceCount;
    expect(before, greaterThan(0));
    c.beginResidual(Transform2.translation(20, 20));
    c.text('A', const Handle(11), _style);
    c.endResidual();
    c.beginResidual(Transform2.translation(10, 10));
    c.polyline(Float64List.fromList([0, 0, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.texts.single.instanceIndex, before,
        reason: 'instances at or past this index were emitted AFTER the label');
  });

  test('the box is the four transformed corners, padded at the band floor', () {
    // dpr 2, band floor 0.5: one device pixel is 1 / (2 * 0.5) = 1.0
    // collection unit of padding.
    final c = _collector(dpr: 2.0);
    // A pure rotation by 90 degrees about the origin, then a translation:
    // glyph box (0,-2)..(40,8) rotates to (-8,0)..(2,40), so a classifier
    // that transformed only min and max corners (instead of all four) gets
    // a box with a negative width.
    final t = Transform2.translation(100, 200)
        .multiply(Transform2.rotation(3.141592653589793 / 2));
    c.beginResidual(t);
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(100 - 8 - 1, 1e-6));
    expect(r.boxMaxX, closeTo(100 + 2 + 1, 1e-6));
    expect(r.boxMinY, closeTo(200 + 0 - 1, 1e-6));
    expect(r.boxMaxY, closeTo(200 + 40 + 1, 1e-6));
  });

  test('the pad is one device pixel at the band floor, not at the ceiling', () {
    // The pad must be the LARGEST one device pixel is inside the band:
    // 1 / (dpr * kBandLowerScale). At dpr 1 and floor 0.5 that is 2.0
    // collection units; a pad taken at the ceiling would be 0.5.
    final c = _collector(dpr: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, closeTo(0 - 1 / (1.0 * kBandLowerScale), 1e-9));
    expect(r.boxMaxX, closeTo(40 + 1 / (1.0 * kBandLowerScale), 1e-9));
  });

  test('a mirrored residual still yields min <= max', () {
    final c = _collector();
    c.beginResidual(const Transform2(-1, 0, 0, 1, 0, 0));
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    final r = c.texts.single;
    expect(r.boxMinX, lessThan(r.boxMaxX));
    expect(r.boxMinX, closeTo(-40 - 1, 1e-6));
  });

  test('without a measurer, text is counted and not recorded (Ruling E2)', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.identity());
    c.text('WC', const Handle(11), _style);
    c.endResidual();
    expect(c.texts, isEmpty);
    expect(c.skippedOps, 1);
  });

  test('the text list is in emission order and is not sortable by handle', () {
    final c = _collector();
    for (final s in ['C', 'A', 'B']) {
      c.beginResidual(Transform2.identity());
      c.text(s, const Handle(11), _style);
      c.endResidual();
    }
    expect(c.texts.map((r) => r.text), ['C', 'A', 'B']);
    expect(() => c.texts.add(c.texts.first), throwsUnsupportedError,
        reason: 'the list handed out is a view; nobody reorders it');
  });

  test('the band constants and the pad are what the spec says', () {
    expect(kBandLowerScale, 0.5);
    expect(kBandUpperScale, 2.0);
    expect(kTextBoxPadDevicePixels, 1.0);
    expect(kMiterLimit, VerticesDrawSink.kMiterLimit,
        reason: 'a copy, pinned to the oracle so it cannot drift');
  });
}
```

- [ ] **Step 3: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_text_test.dart
```
Expected: a compile error — `text_patches.dart` does not exist, `texts` and
`measurer` are not defined.

- [ ] **Step 4: Create `lib/src/gpu/text_patches.dart` with the constants only**

```dart
import 'dart:typed_data';

import 'instance_record.dart';
import 'resident_text.dart';

/// **Provisional, and Plan F's to move.** The spec leaves the watermark band
/// un-committed as a number (open question 3); Plan E needs a floor to expand
/// an instance's reach at and a ceiling to size a patch target at, and takes
/// these two until Plan F measures the band. Every function in this file
/// takes them as parameters with these defaults, so a test can pin either
/// edge and Plan F can move them without touching a call site.
const double kBandLowerScale = 0.5;
const double kBandUpperScale = 2.0;

/// The label box is padded by this many device pixels, taken at the band's
/// LOWER scale (Ruling E9): one device pixel is most collection units at the
/// band's floor, so that is the conservative pad. It covers antialiased glyph
/// edges and glyph overhang past the advance box.
const double kTextBoxPadDevicePixels = 1.0;

/// The miter limit the shader's join branch is bounded by -- a miter tip is
/// never further than `halfWidth * kMiterLimit` from its vertex
/// (`vertices_draw_sink.dart:460, 544-552`). **A copy, not a reference**, by
/// the same rule `GeometryCollector.kMinStrokeDevicePixels` states: the two
/// arms arrive at their numbers separately and the differential is what
/// catches a drift. `resident_text_test.dart` pins this to
/// `VerticesDrawSink.kMiterLimit`.
const double kMiterLimit = 4.0;
```

(The two imports are unused until Task 2 adds the functions; `dart analyze`
flags unused imports as **info**, not error, so this task's gate stays green.
If it does not on this toolchain, leave the imports out and Task 2 adds them.)

- [ ] **Step 5: Create `lib/src/gpu/resident_text.dart`**

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// One text op, as the resident backend keeps it between rebuilds.
///
/// **Allocated at rebuild, read on the frame** (Ruling E1). The frame walks
/// the list and reads fields; nothing here is built per frame.
///
/// [a]..[f] are the residual the painter pushed for this op -- `chain ∘
/// textLocal` (`draft_painter.dart:960-966`), glyph space (y up, origin on
/// the baseline) to **collection** space. Stored flat rather than as a
/// `Transform2` so a frame never composes one per op (invariant 1).
///
/// [boxMinX]..[boxMaxY] is the label's glyph box in collection space: the
/// four corners of `TextLayout.layOutBox`'s box under the residual,
/// re-bounded (a rotated label's axis-aligned bound), padded by
/// `kTextBoxPadDevicePixels` at the band's floor (Ruling E9).
///
/// [instanceIndex] is the number of instances the collector had written when
/// this op arrived. Instances at or past it were emitted **after** the
/// label; that index is the whole basis of `classifyTextPatches`.
class ResidentTextRecord {
  const ResidentTextRecord({
    required this.text,
    required this.style,
    required this.argb,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.e,
    required this.f,
    required this.boxMinX,
    required this.boxMinY,
    required this.boxMaxX,
    required this.boxMaxY,
    required this.instanceIndex,
  });

  final String text;
  final Handle style;
  final int argb;
  final double a, b, c, d, e, f;
  final double boxMinX, boxMinY, boxMaxX, boxMaxY;
  final int instanceIndex;
}
```

- [ ] **Step 6: The collector**

In `geometry_collector.dart`:

Add imports:
```dart
import 'resident_text.dart';
import 'text_patches.dart';
```

Extend the constructor and fields:
```dart
  GeometryCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
    this.measurer,
    this.textStyleOf,
  });

  /// The measurer the label's glyph box is read through, and the style
  /// lookup its `fontFamily` comes from -- the same pair `CanvasDrawSink`
  /// requires. **Optional (Ruling E2):** with either null, [text] counts the
  /// op in [skippedOps] exactly as it did before Plan E, so a collector wired
  /// without a measurer shows as a number rather than a missing picture.
  final TextMeasurer? measurer;
  final TextStyleRecord Function(Handle)? textStyleOf;

  final List<ResidentTextRecord> _texts = <ResidentTextRecord>[];

  /// Reused per text op, never per frame: `TextLayout` is caller-owned and
  /// refilled in place (`text_geometry.dart`'s own ownership rule).
  final TextLayout _textLayout = TextLayout();

  /// Every text op this walk recorded, in emission order. A view: the list
  /// is the draw order and nobody reorders it.
  List<ResidentTextRecord> get texts => List.unmodifiable(_texts);
```

`List.unmodifiable` copies; it is called by tests and once per rebuild by the
harness, never per frame — but say so in the doc comment above, the way
`data`'s doc does.

Replace `skippedOps`'s doc:
```dart
  /// Ops this walk could not draw. **Zero on a collector built with a
  /// measurer**, since Plan E: `text` was the last op counted here, and it
  /// now records a [ResidentTextRecord] instead -- unless [measurer] or
  /// [textStyleOf] is null (Ruling E2), in which case it still counts.
  int get skippedOps => _skipped;
```

Replace `text()`:
```dart
  /// Records the label for the compositor (Plan E); draws nothing itself.
  ///
  /// The glyph box is `TextLayout.layOutBox` on the same `measure` the
  /// reference sink's paragraph is laid out against, taken through all four
  /// corners of the residual so a rotated, sheared or mirrored label bounds
  /// correctly (`Aabb2.transformedBy`'s own rule, written out here to avoid
  /// allocating two `Aabb2`s and four `Vector2`s per label at rebuild --
  /// cheap, but this method is on the walk and the walk is measured).
  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    final measurer = this.measurer;
    final textStyleOf = this.textStyleOf;
    if (measurer == null || textStyleOf == null) {
      _skipped++;
      return;
    }
    _textLayout.layOutBox(measurer.measure(text: text, style: textStyleOf(style)));
    final t = _residual;
    final x0 = _textLayout.minX, y0 = _textLayout.minY;
    final x1 = _textLayout.maxX, y1 = _textLayout.maxY;
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    void corner(double x, double y) {
      final cx = t.a * x + t.c * y + t.e, cy = t.b * x + t.d * y + t.f;
      if (cx < minX) minX = cx;
      if (cx > maxX) maxX = cx;
      if (cy < minY) minY = cy;
      if (cy > maxY) maxY = cy;
    }
    corner(x0, y0);
    corner(x1, y0);
    corner(x0, y1);
    corner(x1, y1);
    // Ruling E9: one device pixel at the band's FLOOR, the most collection
    // units a device pixel is anywhere inside the band.
    final pad = kTextBoxPadDevicePixels / (devicePixelRatio * kBandLowerScale);
    _texts.add(ResidentTextRecord(
      text: text,
      style: style,
      argb: resolved.argb,
      a: t.a, b: t.b, c: t.c, d: t.d, e: t.e, f: t.f,
      boxMinX: minX - pad,
      boxMinY: minY - pad,
      boxMaxX: maxX + pad,
      boxMaxY: maxY + pad,
      instanceIndex: _instances,
    ));
  }
```

`resolved.argb` **directly, never `_coveredArgb`** — a label has no stroke
width; the reference passes `resolved.argb` to `paragraphFor`
(`canvas_draw_sink.dart:221`).

Add to `lib/jet_cad_2d_flutter.dart`:
```dart
export 'src/gpu/resident_text.dart';
export 'src/gpu/text_patches.dart';
```

- [ ] **Step 7: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_text_test.dart
```
Expected: all eight PASS. Then the whole suite, analyze, format.

- [ ] **Step 8: Commit**

```sh
git status --short   # no analysis_options.yaml
git add docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md \
  packages/jet_cad_2d_flutter/lib/src/gpu/resident_text.dart \
  packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart \
  packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart \
  packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart \
  packages/jet_cad_2d_flutter/test/gpu/resident_text_test.dart
git commit -m "feat(gpu): the collector records text as a resident list"
```

---

