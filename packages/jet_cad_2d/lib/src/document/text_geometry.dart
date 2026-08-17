import 'dart:math' as math;

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

/// Resolves one text entity's effective height, rotation, width factor,
/// oblique angle and justification against its [style].
///
/// The single place these decisions are made: `entityBounds` and the painter
/// both call this rather than each re-deriving it, which is what keeps a
/// text entity's glyph box and its drawn glyphs from disagreeing.
ResolvedTextAttributes resolveTextAttributes(
    GeometryPayload payload, int textAttrs, TextStyleRecord style) {
  var h = TextJustifyH.values[textAttrs & 0xF];
  var fellBack = false;
  if (h == TextJustifyH.aligned || h == TextJustifyH.fit) {
    // Both need a second point the payload does not carry. The fallback
    // lives here, not in the painter, so the box and the glyphs agree.
    h = TextJustifyH.left;
    fellBack = true;
  }
  // DXF ignores the vertical code entirely when 72 = 4 (middle).
  final v = h == TextJustifyH.middle
      ? TextJustifyV.middle
      : TextJustifyV.values[(textAttrs >> 4) & 0xF];

  return ResolvedTextAttributes(
    // A non-zero fixed height on the style overrides the entity's own —
    // TextStyleRecord.fixedHeight's own contract.
    height:
        style.fixedHeight != 0 ? style.fixedHeight : scalarOr(payload, 0, 0),
    rotation: scalarOr(payload, 1, 0),
    widthFactor: (textAttrs & _kOverrideWidthFactor) != 0
        ? scalarOr(payload, 2, style.widthFactor)
        : style.widthFactor,
    obliqueAngle: (textAttrs & _kOverrideOblique) != 0
        ? scalarOr(payload, 3, style.obliqueAngle)
        : style.obliqueAngle,
    h: h,
    v: v,
    fellBackFromAlignedOrFit: fellBack,
  );
}

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
  final scale = metrics.capHeight == 0 ? 0.0 : attrs.height / metrics.capHeight;
  final k = math.tan(attrs.obliqueAngle);

  // Glyph space -> shear -> width factor -> uniform height scale.
  final a = attrs.widthFactor * scale;
  const b = 0.0;
  final c = attrs.widthFactor * k * scale;
  final d = scale;

  final refX = switch (attrs.h) {
    TextJustifyH.left || TextJustifyH.aligned || TextJustifyH.fit => 0.0,
    TextJustifyH.centre || TextJustifyH.middle => metrics.advanceWidth / 2,
    TextJustifyH.right => metrics.advanceWidth,
  };
  final refY = switch (attrs.v) {
    TextJustifyV.baseline => 0.0,
    TextJustifyV.bottom => -metrics.descent,
    TextJustifyV.middle => (metrics.ascent - metrics.descent) / 2,
    TextJustifyV.top => metrics.ascent,
  };
  // Reference point carried through the linear map above, then negated: this
  // is what lands the reference point exactly on [anchor] once rotation and
  // translation are applied.
  final dx = -(a * refX + c * refY);
  final dy = -(b * refX + d * refY);

  final cos = math.cos(attrs.rotation), sin = math.sin(attrs.rotation);
  return Transform2(
    cos * a - sin * b,
    sin * a + cos * b,
    cos * c - sin * d,
    sin * c + cos * d,
    anchor.x + cos * dx - sin * dy,
    anchor.y + sin * dx + cos * dy,
  );
}

/// The glyph box in the text's own space, before [textLocalTransform] is
/// applied to it.
///
/// Independent of [attrs] on purpose: height, width factor, oblique angle,
/// rotation and justification are exactly what [textLocalTransform] encodes,
/// so folding any of them in here too would give a caller two places to get
/// the same answer from and a way for them to disagree.
Aabb2 textLocalBounds(ResolvedTextAttributes attrs, TextMetrics metrics) =>
    Aabb2.raw(0, -metrics.descent, metrics.advanceWidth, metrics.ascent);
