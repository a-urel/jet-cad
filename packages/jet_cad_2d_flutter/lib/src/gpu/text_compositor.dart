import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../flutter_text_measurer.dart';
import 'resident_text.dart';
import 'text_patches.dart' show boundTransformedBox;

/// One patch's image and where it goes this frame.
///
/// [src] is the drawn region inside the patch target, anchored at the
/// target's origin (Ruling E8); [dst] is the same region on screen in
/// LOGICAL pixels; [layerBounds] is the label's box in logical pixels, the
/// `saveLayer` the patch is composited inside. Three `Rect`s per patch per
/// frame: the per-patch allocation invariant 1 names as its one exception.
class PatchImage {
  const PatchImage(
      {required this.textIndex,
      required this.image,
      required this.src,
      required this.dst,
      required this.layerBounds});

  final int textIndex;
  final Image image;
  final Rect src;
  final Rect dst;
  final Rect layerBounds;
}

/// The label's box under the outer transform, as a logical-pixel `Rect`.
///
/// The four corners are [boundTransformedBox]'s (Ruling P2) -- one bound
/// loop, shared with [patchRegionFor], not a second copy of it -- so a
/// rotated camera or a mirrored label bounds correctly here too. The caller
/// passes a reused scratch on the frame path; a null scratch allocates one
/// -- test callers.
Rect labelBoundsLogical(ResidentTextRecord t, Transform2 m,
    {Float64List? scratch}) {
  final bound = scratch ?? Float64List(4);
  boundTransformedBox(t.boxMinX, t.boxMinY, t.boxMaxX, t.boxMaxY, m, bound);
  return Rect.fromLTRB(bound[0], bound[1], bound[2], bound[3]);
}

/// Composites one frame: the main image, then the resident text list in
/// emission order, with a patch composited over each covered label.
///
/// **GPU-free** (Ruling E6): images in, canvas calls out. That is what lets
/// the composited differential run both arms through Skia in `flutter test`.
///
/// The paragraph path is the reference sink's own: `paragraphFor` on the
/// same cache, `translate(0, baseline); scale(1, -1)` for the same reason
/// `CanvasDrawSink.text` gives -- `drawParagraph` lays glyphs out y-down
/// from the top of the line while the residual maps glyph space, y up,
/// origin on the baseline. **One helper, [_drawLabel], used by both
/// branches**, so the flip cannot be forgotten on one of them.
class TextCompositor {
  TextCompositor({required this.measurer, required this.textStyleOf});

  final FlutterTextMeasurer measurer;
  final TextStyleRecord Function(Handle) textStyleOf;

  /// Reused per label: the column-major 4x4 `Canvas.transform` wants,
  /// written in place. Slots 10 and 15 are 1 forever.
  final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _patchPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..blendMode = BlendMode.srcATop;
  final Paint _layerPaint = Paint();

  /// Patches composited by the last [paint]. Diagnostics; reset per call.
  int get patchesComposited => _patchesComposited;
  int _patchesComposited = 0;

  /// Reused per plain label by the viewport test: [boundTransformedBox]'s
  /// caller-owned scratch, so rejecting an off-screen label allocates
  /// nothing.
  final Float64List _bound = Float64List(4);

  /// Plain labels the last [paint] did not draw because their box, under the
  /// outer transform, missed the viewport entirely. Diagnostics; reset per
  /// call. A patched label whose patch was off screen is not in `patches`,
  /// takes the plain branch, and is counted here too.
  int labelsSkipped = 0;

  void paint(
    Canvas canvas, {
    required Image? main,
    required Size viewport,
    required Transform2 collectionToLogical,
    required List<ResidentTextRecord> texts,
    required List<PatchImage> patches,
  }) {
    _patchesComposited = 0;
    labelsSkipped = 0;
    if (main != null) {
      canvas.drawImageRect(
          main,
          Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
          Rect.fromLTWH(0, 0, viewport.width, viewport.height),
          _imagePaint);
    }
    var p = 0;
    for (var i = 0; i < texts.length; i++) {
      final patch =
          p < patches.length && patches[p].textIndex == i ? patches[p++] : null;
      if (patch == null) {
        final t = texts[i];
        boundTransformedBox(t.boxMinX, t.boxMinY, t.boxMaxX, t.boxMaxY,
            collectionToLogical, _bound);
        // Wholly off screen: nothing to draw. A box touching the edge is
        // drawn -- the paragraph clips itself.
        if (_bound[2] < 0 ||
            _bound[0] > viewport.width ||
            _bound[3] < 0 ||
            _bound[1] > viewport.height) {
          labelsSkipped++;
          continue;
        }
        _drawLabel(canvas, t, collectionToLogical);
        continue;
      }
      // The layer's bounds are in the OUTER frame -- logical pixels -- and
      // the label's own six floats are applied inside `_drawLabel`, after
      // this call. A layer opened after the residual would be transformed
      // twice (a Copilot review finding on revision 5's first draft).
      //
      // **`saveLayer` clips to `patch.layerBounds`** -- the label's padded
      // box (`kTextBoxPadDevicePixels`, `text_patches.dart`) -- so any glyph
      // overhang beyond the paragraph's advance box, ascent or descent that
      // reaches past the pad would clip on a PATCHED label only, never on a
      // plain one drawn by [_drawLabel] alone. An assumption the corpus does
      // not exercise: nothing in this codebase's fixtures has a glyph whose
      // ink reaches that far.
      canvas.saveLayer(patch.layerBounds, _layerPaint);
      _drawLabel(canvas, texts[i], collectionToLogical);
      canvas.drawImageRect(patch.image, patch.src, patch.dst, _patchPaint);
      canvas.restore();
      _patchesComposited++;
    }
  }

  /// `outer ∘ residual`, composed by hand into [_matrix] -- six multiplies,
  /// no `Transform2` built per op (invariant 1) -- then the reference's
  /// baseline flip and `drawParagraph`.
  void _drawLabel(Canvas canvas, ResidentTextRecord t, Transform2 o) {
    final paragraph =
        measurer.paragraphFor(t.text, t.style, textStyleOf(t.style), t.argb);
    _matrix[0] = o.a * t.a + o.c * t.b;
    _matrix[1] = o.b * t.a + o.d * t.b;
    _matrix[4] = o.a * t.c + o.c * t.d;
    _matrix[5] = o.b * t.c + o.d * t.d;
    _matrix[12] = o.a * t.e + o.c * t.f + o.e;
    _matrix[13] = o.b * t.e + o.d * t.f + o.f;
    canvas.save();
    canvas.transform(_matrix);
    canvas.translate(0, paragraph.alphabeticBaseline);
    canvas.scale(1, -1);
    canvas.drawParagraph(paragraph, Offset.zero);
    canvas.restore();
  }
}
