import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

final _model = MetricModelMeasurer();
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

void main() {
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
        _resolve(attrs: packTextAttrs(h: TextJustifyH.left)),
        m,
        Vector2.zero());
    final centre = textLocalTransform(
        _resolve(attrs: packTextAttrs(h: TextJustifyH.centre)),
        m,
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
        _resolve(attrs: packTextAttrs(v: TextJustifyV.bottom)),
        m,
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
            attrs: packTextAttrs(
                h: TextJustifyH.middle, v: TextJustifyV.baseline)),
        m,
        Vector2.zero());
    expect(a.f, closeTo(b.f, 1e-9));
  });

  test('rotation turns counter-clockwise, and by how much', () {
    // `rotation is not symmetric about its sign`, below, names the right
    // property and cannot see a *global* sign flip: `plus.b == -minus.b`
    // holds just as well when both are negated. Plan 3c Task 13's S9 mutant
    // (`math.sin(-rotation)`) walked straight through the whole of this file
    // and was caught two packages away, by a pick test and a golden. The
    // spec's table says the killer for that mutant is an arithmetic
    // expectation; this is it.
    final m = _model.measure(text: 'WC', style: _plain);
    final t = textLocalTransform(_resolve(rotation: 0.4), m, Vector2.zero());
    // Hand-derived: `_plain` leaves the width factor at 1 and the oblique at
    // 0, so the linear map is a uniform 200/70 (height over cap height) with
    // no shear, and rotation by +0.4 takes (la, 0) to (cos*la, sin*la).
    const scale = 200 / 70.0;
    expect(t.a, closeTo(math.cos(0.4) * scale, 1e-9));
    expect(t.b, closeTo(math.sin(0.4) * scale, 1e-9));
    // The sign is the whole point: +0.4 rad must send the baseline's x axis
    // *up* in a y-up space, not down.
    expect(t.b, greaterThan(0.0));
  });

  test('rotation is not symmetric about its sign', () {
    final m = _model.measure(text: 'WC', style: _plain);
    // 0 and pi are degenerate for a sign flip; 0.4 rad is not.
    final plus = textLocalTransform(_resolve(rotation: 0.4), m, Vector2.zero());
    final minus =
        textLocalTransform(_resolve(rotation: -0.4), m, Vector2.zero());
    expect(plus.b, closeTo(-minus.b, 1e-9));
    expect(plus.b, isNot(closeTo(0.0, 1e-6)));
  });

  test('the width factor scales the already-sheared glyph, not the other way',
      () {
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

  test(
      'a non-baseline vertical justification carries the oblique shear into '
      'the horizontal offset, but never into the vertical one', () {
    final style = TextStyleRecord(
        handle: const Handle(7),
        name: 'SLANT',
        fontFamily: 'Roboto',
        obliqueAngle: 0.3);
    final m = _model.measure(text: 'WC', style: _plain);
    final scale = 200.0 / 70.0;
    final t = textLocalTransform(
        _resolve(
            attrs: packTextAttrs(h: TextJustifyH.right, v: TextJustifyV.top),
            style: style),
        m,
        Vector2.zero());
    // Reference point is (advanceWidth, ascent) in glyph space. Carried
    // through the shear before being negated, so e picks up a term from the
    // *vertical* reference point too: e = -scale * (refX + tan(k) * refY).
    // A flat per-axis offset (dx depending only on refX) would instead give
    // -scale * advanceWidth, which this pins against.
    final expectedE = -scale * (m.advanceWidth + math.tan(0.3) * m.ascent);
    expect(t.e, closeTo(expectedE, 1e-9));
    expect(t.e, isNot(closeTo(-scale * m.advanceWidth, 1e-6)));
    // b is always 0 (the shear only tilts x), so the vertical offset is the
    // same as the oblique-free top justification: no cross term reaches f.
    expect(t.f, closeTo(-m.ascent * scale, 1e-9));
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
}
