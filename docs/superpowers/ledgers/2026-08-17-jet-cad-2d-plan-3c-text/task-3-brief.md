## Task 3: `text_geometry.dart` — one resolution point

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/text_geometry.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`
- Test: `packages/jet_cad_2d/test/document/text_geometry_test.dart`

**Interfaces:**
- Consumes: `TextMetrics`, `TextStyleRecord`, `GeometryPayload`, `scalarOr`.
- Produces: `enum TextJustifyH { left, centre, right, aligned, middle, fit }`, `enum TextJustifyV { baseline, bottom, middle, top }`, `int packTextAttrs({TextJustifyH h, TextJustifyV v, bool overrideWidthFactor, bool overrideOblique})`, `class ResolvedTextAttributes { double height, rotation, widthFactor, obliqueAngle; TextJustifyH h; TextJustifyV v; bool fellBackFromAlignedOrFit; }`, `ResolvedTextAttributes resolveTextAttributes(GeometryPayload payload, int textAttrs, TextStyleRecord style)`, `Transform2 textLocalTransform(ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor)`, `Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics)`.

- [ ] **Step 1: Write the failing tests — one arithmetic expectation per attribute**

```dart
// test/document/text_geometry_test.dart
const _model = MetricModelMeasurer();
final _plain = TextStyleRecord(
    handle: const Handle(7), name: 'STANDARD', fontFamily: 'Roboto');

ResolvedTextAttributes _resolve(
        {double height = 200.0,
        double rotation = 0.0,
        int attrs = 0,
        double? widthFactor,
        double? oblique,
        TextStyleRecord? style}) =>
    resolveTextAttributes(
        GeometryPayload(
            coords: Float64List.fromList([0, 0]),
            scalars: Float64List.fromList(
                [height, rotation, widthFactor ?? 0, oblique ?? 0])),
        attrs,
        style ?? _plain);

test('an unset override bit reads the style, not the scalar', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'WIDE',
      fontFamily: 'Roboto',
      widthFactor: 2.0);
  // Bit 8 clear: the 0.25 sitting in scalars[2] must be ignored.
  final a = _resolve(attrs: 0, widthFactor: 0.25, style: style);
  expect(a.widthFactor, 2.0);

  final b = _resolve(
      attrs: packTextAttrs(overrideWidthFactor: true),
      widthFactor: 0.25,
      style: style);
  expect(b.widthFactor, 0.25);
});

test('a style fixed height overrides the entity height', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'FIXED',
      fontFamily: 'Roboto',
      fixedHeight: 50.0);
  expect(_resolve(height: 200.0, style: style).height, 50.0);
  expect(_resolve(height: 200.0).height, 200.0);
});

test('height scales by cap height, not by the em size', () {
  final attrs = _resolve(height: 210.0);
  final m = _model.measure(text: 'WC', style: _plain);
  final t = textLocalTransform(attrs, m, Vector2.zero());
  // 210 / (0.7 * 100) = 3.0
  expect(t.a, closeTo(3.0, 1e-9));
  expect(t.d, closeTo(3.0, 1e-9));
});

test('centre justification offsets by half the advance width', () {
  final m = _model.measure(text: 'WC', style: _plain); // 110 nominal units
  final left = textLocalTransform(
      _resolve(attrs: packTextAttrs(h: TextJustifyH.left)), m, Vector2.zero());
  final centre = textLocalTransform(
      _resolve(attrs: packTextAttrs(h: TextJustifyH.centre)), m,
      Vector2.zero());
  // Scale is 200 / 70; half the advance is 55 nominal units.
  expect(centre.e - left.e, closeTo(-55.0 * (200.0 / 70.0), 1e-9));
});

test('top justification offsets by the ascent and bottom by the descent', () {
  final m = _model.measure(text: 'WC', style: _plain);
  final scale = 200.0 / 70.0;
  final top = textLocalTransform(
      _resolve(attrs: packTextAttrs(v: TextJustifyV.top)), m, Vector2.zero());
  final bottom = textLocalTransform(
      _resolve(attrs: packTextAttrs(v: TextJustifyV.bottom)), m,
      Vector2.zero());
  expect(top.f, closeTo(-m.ascent * scale, 1e-9));
  expect(bottom.f, closeTo(m.descent * scale, 1e-9));
});

test('72=4 (middle) ignores the vertical code', () {
  final m = _model.measure(text: 'WC', style: _plain);
  final a = textLocalTransform(
      _resolve(
          attrs: packTextAttrs(h: TextJustifyH.middle, v: TextJustifyV.top)),
      m,
      Vector2.zero());
  final b = textLocalTransform(
      _resolve(
          attrs:
              packTextAttrs(h: TextJustifyH.middle, v: TextJustifyV.baseline)),
      m,
      Vector2.zero());
  expect(a.f, closeTo(b.f, 1e-9));
});

test('rotation is not symmetric about its sign', () {
  final m = _model.measure(text: 'WC', style: _plain);
  // 0 and pi are degenerate for a sign flip; 0.4 rad is not.
  final plus = textLocalTransform(_resolve(rotation: 0.4), m, Vector2.zero());
  final minus = textLocalTransform(_resolve(rotation: -0.4), m, Vector2.zero());
  expect(plus.b, closeTo(-minus.b, 1e-9));
  expect(plus.b, isNot(closeTo(0.0, 1e-6)));
});

test('the width factor scales the already-sheared glyph, not the other way', () {
  final style = TextStyleRecord(
      handle: const Handle(7),
      name: 'SLANT',
      fontFamily: 'Roboto',
      widthFactor: 2.0,
      obliqueAngle: 0.3);
  final m = _model.measure(text: 'WC', style: _plain);
  final t = textLocalTransform(_resolve(style: style), m, Vector2.zero());
  final scale = 200.0 / 70.0;
  // Shear first, then the x-scale: c = widthFactor * tan(oblique) * scale.
  expect(t.c, closeTo(2.0 * math.tan(0.3) * scale, 1e-9));
  // The other order would give tan(0.3) * scale, which this pins against.
  expect(t.c, isNot(closeTo(math.tan(0.3) * scale, 1e-6)));
});

test('aligned and fit fall back to left, in the resolver', () {
  final a = _resolve(attrs: packTextAttrs(h: TextJustifyH.aligned));
  expect(a.h, TextJustifyH.left);
  expect(a.fellBackFromAlignedOrFit, isTrue);
});

test('a v3 payload with one scalar resolves to defaults', () {
  final attrs = resolveTextAttributes(
      GeometryPayload(
          coords: Float64List.fromList([0, 0]),
          scalars: Float64List.fromList([120.0])),
      0,
      _plain);
  expect(attrs.height, 120.0);
  expect(attrs.rotation, 0.0);
  expect(attrs.widthFactor, 1.0);
  expect(attrs.obliqueAngle, 0.0);
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/text_geometry_test.dart`
Expected: FAIL — `resolveTextAttributes` is undefined.

- [ ] **Step 3: Implement the resolver**

```dart
const int _kOverrideWidthFactor = 1 << 8;
const int _kOverrideOblique = 1 << 9;

int packTextAttrs({
  TextJustifyH h = TextJustifyH.left,
  TextJustifyV v = TextJustifyV.baseline,
  bool overrideWidthFactor = false,
  bool overrideOblique = false,
}) =>
    (h.index & 0xF) |
    ((v.index & 0xF) << 4) |
    (overrideWidthFactor ? _kOverrideWidthFactor : 0) |
    (overrideOblique ? _kOverrideOblique : 0);

ResolvedTextAttributes resolveTextAttributes(
    GeometryPayload payload, int textAttrs, TextStyleRecord style) {
  var h = TextJustifyH.values[textAttrs & 0xF];
  var fellBack = false;
  if (h == TextJustifyH.aligned || h == TextJustifyH.fit) {
    // Both need a second point the payload does not carry. The fallback lives
    // here, not in the painter, so the box and the glyphs agree.
    h = TextJustifyH.left;
    fellBack = true;
  }
  final v = h == TextJustifyH.middle
      // DXF ignores the vertical code when 72 = 4.
      ? TextJustifyV.baseline
      : TextJustifyV.values[(textAttrs >> 4) & 0xF];

  return ResolvedTextAttributes(
    height: style.fixedHeight != 0 ? style.fixedHeight : scalarOr(payload, 0, 0),
    rotation: scalarOr(payload, 1, 0),
    widthFactor: (textAttrs & _kOverrideWidthFactor) != 0
        ? scalarOr(payload, 2, style.widthFactor)
        : style.widthFactor,
    obliqueAngle: (textAttrs & _kOverrideOblique) != 0
        ? scalarOr(payload, 3, style.obliqueAngle)
        : style.obliqueAngle,
    h: h,
    v: h == TextJustifyH.middle ? TextJustifyV.middle : v,
    fellBackFromAlignedOrFit: fellBack,
  );
}
```

- [ ] **Step 4: Implement the transform and the local box**

```dart
/// Composed innermost-first:
///   oblique shear -> width-factor x-scale -> height scale
///   -> justification offset -> rotation -> translation to [anchor]
///
/// Shear before the x-scale, deliberately: `w * (x + k*y)` is not
/// `w*x + k*y`, and scaling the already-slanted glyph is the DXF reading. The
/// text ladder golden is the evidence, and a mutant that swaps the two is
/// killed by `text_geometry_test`'s width-factor-and-oblique case.
Transform2 textLocalTransform(
    ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor) {
  final scale = metrics.capHeight == 0
      ? 0.0
      // Cap height, not the em size: DXF's height is the capital-letter height.
      : attrs.height / metrics.capHeight;
  final k = math.tan(attrs.obliqueAngle);

  // Glyph space -> shear -> width factor -> uniform height scale.
  final a = attrs.widthFactor * scale;
  final c = attrs.widthFactor * k * scale;
  final d = scale;

  final dx = switch (attrs.h) {
        TextJustifyH.left || TextJustifyH.aligned || TextJustifyH.fit => 0.0,
        TextJustifyH.centre || TextJustifyH.middle => -metrics.advanceWidth / 2,
        TextJustifyH.right => -metrics.advanceWidth,
      } *
      attrs.widthFactor *
      scale;
  final dy = switch (attrs.v) {
        TextJustifyV.baseline => 0.0,
        TextJustifyV.bottom => metrics.descent,
        TextJustifyV.middle => (metrics.descent - metrics.ascent) / 2,
        TextJustifyV.top => -metrics.ascent,
      } *
      scale;

  final cos = math.cos(attrs.rotation), sin = math.sin(attrs.rotation);
  // rotation ∘ (linear part), then the rotated offset plus the anchor.
  return Transform2(
    cos * a - sin * 0.0,
    sin * a + cos * 0.0,
    cos * c - sin * d,
    sin * c + cos * d,
    anchor.x + cos * dx - sin * dy,
    anchor.y + sin * dx + cos * dy,
  );
}

/// The glyph box in the text's own space, before [textLocalTransform].
Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics) =>
    Aabb2(Vector2(0, -metrics.descent), Vector2(metrics.advanceWidth, metrics.ascent));
```

- [ ] **Step 5: Run the tests**

Run: `cd packages/jet_cad_2d && dart test test/document/text_geometry_test.dart`
Expected: PASS, all eleven.

- [ ] **Step 6: Export and commit**

Add `export 'src/document/text_geometry.dart';` to `lib/jet_cad_2d.dart`.

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): resolve text attributes and compose the local transform in one place"
```

---

