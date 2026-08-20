import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/geometry_store.dart';
import 'tables.dart';
import 'text_metrics.dart';
import 'text_scalars.dart';

/// Horizontal justification, DXF group 72 order: `index` is the stored code.
enum TextJustifyH { left, centre, right, aligned, middle, fit }

/// Vertical justification, DXF group 73/74 order: `index` is the stored code.
enum TextJustifyV { baseline, bottom, middle, top }

const int _kOverrideWidthFactor = 1 << 8;
const int _kOverrideOblique = 1 << 9;

/// Packs justification plus per-entity override flags into
/// `EntityRecord.textAttrs`.
///
/// Bits 0-3 hold [TextJustifyH.index]; bits 4-7 hold [TextJustifyV.index].
/// Bit 8 (width factor) and bit 9 (oblique angle) say whether the matching
/// payload scalar is a real per-entity override; when a bit is clear the
/// style's value wins and the scalar is not read at all. Override *bits*
/// rather than a NaN sentinel, because `jsonEncode` throws on NaN and
/// `GeometryPayload`'s list equality compares scalars with `!=`, so a NaN
/// payload would break both saving and equality.
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

/// One text entity's stored attributes, resolved against its style.
///
/// Every DXF ambiguity this format carries — a fixed style height that wins
/// over the entity's own, a vertical code that 72=4 ignores, an alignment
/// this engine cannot represent — has already been decided by the time this
/// exists, so nothing downstream re-decides it differently.
@immutable
class ResolvedTextAttributes {
  const ResolvedTextAttributes({
    required this.height,
    required this.rotation,
    required this.widthFactor,
    required this.obliqueAngle,
    required this.h,
    required this.v,
    required this.fellBackFromAlignedOrFit,
  });

  final double height;
  final double rotation;
  final double widthFactor;
  final double obliqueAngle;
  final TextJustifyH h;
  final TextJustifyV v;

  /// True when the stored code was 72=3 (aligned) or 72=5 (fit) and was
  /// downgraded to [TextJustifyH.left] here, because both need a second
  /// alignment point the payload does not carry. This is how a later painter
  /// task learns to raise a `Diagnostic` instead of silently drawing
  /// left-justified text as if that were what the document asked for.
  final bool fellBackFromAlignedOrFit;
}

/// One text entity's layout — its resolved attributes, its composed local
/// transform and its laid-out glyph box — in reusable, refillable storage.
///
/// **Why a mutable form of all three exists.**
/// `SpatialIndex._considerLeaf` lays out every text candidate a pick
/// touches, and [resolveTextAttributes], [textLocalTransform] and
/// [textLocalBounds] each hand back a fresh object: three allocations per
/// *candidate*, which is exactly what the zero-allocation budget on
/// `pickInto`/`snapInto` forbids and what
/// `test/invariants/query_allocation_test.dart` measures. One of these,
/// owned by the index and refilled per candidate, allocates nothing.
///
/// **The layout decisions live here, and only here.** The three functions
/// below are thin wrappers that fill a throwaway instance and copy the
/// answer out, so the fixed-height rule, DXF's 72=4 rule, the aligned/fit
/// fallback and the shear-before-scale order are each written exactly once.
/// A second, hand-inlined copy of them inside the index — which is the
/// obvious way to make the pick path allocation-free — is precisely the
/// box/glyph disagreement this file exists to prevent.
///
/// Caller-owned and refilled in place, so nothing may hold a reference to a
/// [TextLayout] it did not fill itself; the same rule [HitPath] and
/// [SnapResult] state for their own reusable buffers.
///
/// **Prefer the three wrappers.** This is not a second supported way to ask
/// where a text entity's glyphs sit; it is the allocation-free way, for the
/// two paths that have a budget. [resolveTextAttributes],
/// [textLocalTransform] and [textLocalBounds] are the same answers in
/// immutable form and are what every other caller should use.
///
/// It carried `@internal` until Plan 3c Task 10, on the reading that the
/// query path was the only caller with such a budget. That reading was
/// measured wrong: `DraftPainter._drawText`, in `jet_cad_2d_flutter`, is on
/// the frame path — the path this project's first non-negotiable says
/// allocates nothing in steady state — and going through the wrappers there
/// cost nine allocations per text leaf against a residual-path norm of one
/// (`test/invariants/text_paint_allocation_test.dart`). An annotation that
/// forbids the fix for a budget in another package is encoding an assumption,
/// not a rule, so it is gone; the ownership rule above is what still binds.
class TextLayout {
  /// Every double this object holds, in one typed array rather than in
  /// fourteen plain `double` fields.
  ///
  /// **Measured, not stylistic.** A store to an ordinary `double` field of a
  /// Dart object boxes the value; this object is refilled for every text
  /// candidate a pick considers, so the plain-fields version was measured
  /// (`test/invariants/query_allocation_test.dart`'s 64-label fixture, VM
  /// allocation profiler) at roughly 10 extra `_Double` instances per text
  /// candidate — 644 per pick, a textbook per-candidate allocation, just of
  /// a class nothing was watching. A `Float64List` element store keeps the
  /// value unboxed and takes that to zero.
  ///
  /// The accessors below name the slots; nothing outside this class indexes
  /// it.
  final Float64List _values = Float64List(14);

  static const int _kHeight = 0;
  static const int _kRotation = 1;
  static const int _kWidthFactor = 2;
  static const int _kObliqueAngle = 3;
  static const int _kA = 4;
  static const int _kMinX = 10;

  /// Resolved attributes — see [ResolvedTextAttributes], whose fields these
  /// mirror one for one.
  double get height => _values[_kHeight];
  set height(double value) => _values[_kHeight] = value;
  double get rotation => _values[_kRotation];
  set rotation(double value) => _values[_kRotation] = value;
  double get widthFactor => _values[_kWidthFactor];
  set widthFactor(double value) => _values[_kWidthFactor] = value;
  double get obliqueAngle => _values[_kObliqueAngle];
  set obliqueAngle(double value) => _values[_kObliqueAngle] = value;
  TextJustifyH h = TextJustifyH.left;
  TextJustifyV v = TextJustifyV.baseline;
  bool fellBackFromAlignedOrFit = false;

  /// The six coefficients [textLocalTransform] returns as a [Transform2],
  /// valid after [composeTransform].
  double get a => _values[_kA];
  double get b => _values[_kA + 1];
  double get c => _values[_kA + 2];
  double get d => _values[_kA + 3];
  double get e => _values[_kA + 4];
  double get f => _values[_kA + 5];

  /// The glyph box [textLocalBounds] returns as an [Aabb2], valid after
  /// [layOutBox].
  double get minX => _values[_kMinX];
  double get minY => _values[_kMinX + 1];
  double get maxX => _values[_kMinX + 2];
  double get maxY => _values[_kMinX + 3];

  /// Resolves one text entity's effective height, rotation, width factor,
  /// oblique angle and justification against its [style], into this object.
  void resolve(GeometryPayload payload, int textAttrs, TextStyleRecord style) {
    var justifyH = TextJustifyH.values[textAttrs & 0xF];
    var fellBack = false;
    if (justifyH == TextJustifyH.aligned || justifyH == TextJustifyH.fit) {
      // Both need a second point the payload does not carry. The fallback
      // lives here, not in the painter, so the box and the glyphs agree.
      justifyH = TextJustifyH.left;
      fellBack = true;
    }
    h = justifyH;
    // DXF ignores the vertical code entirely when 72 = 4 (middle).
    v = justifyH == TextJustifyH.middle
        ? TextJustifyV.middle
        : TextJustifyV.values[(textAttrs >> 4) & 0xF];
    // A non-zero fixed height on the style overrides the entity's own —
    // TextStyleRecord.fixedHeight's own contract.
    height =
        style.fixedHeight != 0 ? style.fixedHeight : scalarOr(payload, 0, 0);
    rotation = scalarOr(payload, 1, 0);
    widthFactor = (textAttrs & _kOverrideWidthFactor) != 0
        ? scalarOr(payload, 2, style.widthFactor)
        : style.widthFactor;
    obliqueAngle = (textAttrs & _kOverrideOblique) != 0
        ? scalarOr(payload, 3, style.obliqueAngle)
        : style.obliqueAngle;
    fellBackFromAlignedOrFit = fellBack;
  }

  /// Copies an already-resolved [attrs] in, for the callers that hold one.
  void adopt(ResolvedTextAttributes attrs) {
    height = attrs.height;
    rotation = attrs.rotation;
    widthFactor = attrs.widthFactor;
    obliqueAngle = attrs.obliqueAngle;
    h = attrs.h;
    v = attrs.v;
    fellBackFromAlignedOrFit = attrs.fellBackFromAlignedOrFit;
  }

  /// The resolved attributes as an immutable record — allocates, so not for
  /// the query path.
  ResolvedTextAttributes get attributes => ResolvedTextAttributes(
        height: height,
        rotation: rotation,
        widthFactor: widthFactor,
        obliqueAngle: obliqueAngle,
        h: h,
        v: v,
        fellBackFromAlignedOrFit: fellBackFromAlignedOrFit,
      );

  /// Fills [minX]..[maxY] with the glyph box in the text's own space,
  /// before [composeTransform]'s transform is applied to it.
  ///
  /// Independent of the resolved attributes on purpose: height, width
  /// factor, oblique angle, rotation and justification are exactly what
  /// [composeTransform] encodes, so folding any of them in here too would
  /// give a caller two places to get the same answer from and a way for
  /// them to disagree.
  void layOutBox(TextMetrics metrics) {
    _values[_kMinX] = 0;
    _values[_kMinX + 1] = -metrics.descent;
    _values[_kMinX + 2] = metrics.advanceWidth;
    _values[_kMinX + 3] = metrics.ascent;
  }

  /// Fills [a]..[f] with the transform from glyph space to the entity's own
  /// space, anchored at ([anchorX], [anchorY]). See [textLocalTransform]'s
  /// doc comment for the composition order and why it is that order.
  void composeTransform(TextMetrics metrics, double anchorX, double anchorY) {
    final scale = metrics.capHeight == 0 ? 0.0 : height / metrics.capHeight;
    final k = math.tan(obliqueAngle);

    // Glyph space -> shear -> width factor -> uniform height scale.
    final la = widthFactor * scale;
    const lb = 0.0;
    final lc = widthFactor * k * scale;
    final ld = scale;

    final refX = switch (h) {
      TextJustifyH.left || TextJustifyH.aligned || TextJustifyH.fit => 0.0,
      TextJustifyH.centre || TextJustifyH.middle => metrics.advanceWidth / 2,
      TextJustifyH.right => metrics.advanceWidth,
    };
    final refY = switch (v) {
      TextJustifyV.baseline => 0.0,
      TextJustifyV.bottom => -metrics.descent,
      TextJustifyV.middle => (metrics.ascent - metrics.descent) / 2,
      TextJustifyV.top => metrics.ascent,
    };
    // Reference point carried through the linear map above, then negated:
    // this is what lands the reference point exactly on the anchor once
    // rotation and translation are applied.
    final dx = -(la * refX + lc * refY);
    final dy = -(lb * refX + ld * refY);

    final cos = math.cos(rotation), sin = math.sin(rotation);
    _values[_kA] = cos * la - sin * lb;
    _values[_kA + 1] = sin * la + cos * lb;
    _values[_kA + 2] = cos * lc - sin * ld;
    _values[_kA + 3] = sin * lc + cos * ld;
    _values[_kA + 4] = anchorX + cos * dx - sin * dy;
    _values[_kA + 5] = anchorY + sin * dx + cos * dy;
  }
}

/// Resolves one text entity's effective height, rotation, width factor,
/// oblique angle and justification against its [style].
///
/// The single place these decisions are made: `entityBounds` and the painter
/// both call this rather than each re-deriving it, which is what keeps a
/// text entity's glyph box and its drawn glyphs from disagreeing. The
/// decisions themselves live in [TextLayout.resolve]; this wrapper is the
/// allocating, immutable face of them.
ResolvedTextAttributes resolveTextAttributes(
        GeometryPayload payload, int textAttrs, TextStyleRecord style) =>
    (TextLayout()..resolve(payload, textAttrs, style)).attributes;

/// Composed innermost-first:
///
///   oblique shear -> width-factor x-scale -> height scale
///   -> justification offset -> rotation -> translation to [anchor]
///
/// Shear before the x-scale, deliberately: `w * (x + k*y)` is not
/// `w*x + k*y`. Scaling the already-slanted glyph is the DXF reading, and
/// either transform alone commutes with the rest of this composition — only
/// a case with both a width factor and an oblique angle can tell the two
/// orders apart, which is why the crossed test in `text_geometry_test.dart`
/// pins this order and would fail against the swapped one.
///
/// The justification offset is the *same* shear/scale linear map applied to
/// the justification reference point (e.g. top-left is `(0, ascent)` before
/// any transform), then negated, rather than a plain per-axis nudge added on
/// top. A plain nudge is indistinguishable from this for every case the
/// tests exercise (h=left or oblique=0 for every non-baseline v case here),
/// but it silently drifts for a justified, obliqued entity: the reference
/// point would then land somewhere other than [anchor], which is exactly the
/// kind of box/glyph disagreement this file exists to prevent.
Transform2 textLocalTransform(
    ResolvedTextAttributes attrs, TextMetrics metrics, Vector2 anchor) {
  final layout = TextLayout()
    ..adopt(attrs)
    ..composeTransform(metrics, anchor.x, anchor.y);
  return Transform2(layout.a, layout.b, layout.c, layout.d, layout.e, layout.f);
}

/// The glyph box in the text's own space, before [textLocalTransform] is
/// applied to it.
///
/// Independent of [attrs] on purpose: height, width factor, oblique angle,
/// rotation and justification are exactly what [textLocalTransform] encodes,
/// so folding any of them in here too would give a caller two places to get
/// the same answer from and a way for them to disagree.
Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics) {
  final layout = TextLayout()..layOutBox(metrics);
  return Aabb2.raw(layout.minX, layout.minY, layout.maxX, layout.maxY);
}
