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
