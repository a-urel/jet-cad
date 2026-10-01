import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../draw_sink.dart';

/// A [DrawSink] that writes PDF operators onto one page (spec 13 D3).
///
/// It works in the painter's screen space: points (pt), y down. A page set-up
/// `cm [1 0 0 -1 0 H]` is written once, so that space becomes the page's user
/// space, followed by `J 0`, `j 0` and `4 M`. Those are butt cap, miter join
/// and miter limit 4: Skia's `Paint` defaults, which `CanvasDrawSink` draws
/// with. PDF's own default miter limit is 10.
///
/// It mirrors `CanvasDrawSink`, op by op:
///
/// - A residual is written as `q`, then `cm residual`, deferred to the first
///   primitive drawn under it. `Q` is written only if the residual was
///   pushed.
/// - The stroke width is `lineweightHundredths / 100 · u`, divided by the
///   residual's scale magnitude. Lineweight 0 writes `0 w`, PDF's thinnest
///   line. No camera term.
/// - [point] is carried through the residual by hand, never under `cm`. It
///   is drawn as an axis-aligned square of side `lw / 100 · u`, and nothing
///   is drawn at lineweight 0.
/// - [text] is drawn under the residual, which maps glyph space (y up, origin
///   on the baseline, size `kNominalTextPixels`) to screen space. The page
///   set-up's flip cancels the camera's, so the glyphs stand upright in PDF
///   text space with no further flip: `BT /F size Tf Tz 0 0 Td [<…>] TJ ET`.
///   `Tz` stretches the run to the advance the painter laid its box out
///   with (see [text]).
///
/// The graphics state is written in full for every primitive: its colour,
/// its width (strokes) and its alpha as an `ExtGState` whose `CA` and `ca`
/// are alpha / 255. That includes alpha 255. Nothing a previous op or a `Q`
/// left behind is relied on, and no state is cached.
///
/// The package writes every number with 5 decimals (spec F-15), so
/// coordinates stay in the painter's spaces and `cm` carries the residual.
/// The tests' tolerances are derived from that rounding.
class PdfDrawSink implements DrawSink {
  /// Writes the page set-up onto a fresh graphics context of [page].
  ///
  /// [fontBytes] is the TrueType font every text is drawn in, whatever its
  /// style's `fontFamily` (spec 13 R-3). It is embedded once, as one
  /// `PdfTtfFont`, when the first text is drawn: a page without text embeds
  /// no font.
  PdfDrawSink({
    required PdfDocument document,
    required PdfPage page,
    required this.pixelsPerPaperMm,
    required Uint8List fontBytes,
    required this.measurer,
    required this.textStyleOf,
  })  : _document = document,
        _fontBytes = fontBytes,
        _g = page.getGraphics() {
    final height = page.pageFormat.height;
    _g
      ..setTransform(_set(1, 0, 0, -1, 0, height))
      ..setLineCap(PdfLineCap.butt)
      ..setLineJoin(PdfLineJoin.miter)
      ..setMiterLimit(4);
  }

  final PdfDocument _document;
  final PdfGraphics _g;

  /// `u`: points per paper millimetre (72 / 25.4 for a true-scale page).
  final double pixelsPerPaperMm;

  /// Measures a text's advance the way the painter laid its box out, so the
  /// PDF's run is stretched to that same advance. The painter measures with
  /// `document.textMeasurer`; `exportPagePdf` passes that same instance, so
  /// the two cannot disagree. The sink calls nothing but [TextMeasurer.measure].
  final TextMeasurer measurer;

  /// Resolves a text entity's style handle to the record [measurer] needs,
  /// as `CanvasDrawSink.textStyleOf`.
  final TextStyleRecord Function(Handle) textStyleOf;

  final Uint8List _fontBytes;

  /// The one embedded font, built on the first [text].
  late final PdfTtfFont _font =
      PdfTtfFont(_document, ByteData.sublistView(_fontBytes));

  // Rewritten in place for every `cm`. `setTransform` copies what it needs.
  final Matrix4 _matrix = Matrix4.identity();

  Transform2 _residual = Transform2.identity();
  double _residualScale = 1.0;
  bool _inResidual = false;
  bool _transformPushed = false;

  /// The cubic Bezier handle for a circle quadrant, `4/3 · tan(pi/8)`.
  static final double _quadrantHandle = 4 / 3 * math.tan(math.pi / 8);

  @override
  bool get shadesDashes => false;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) =>
      throw UnsupportedError(
        'PdfDrawSink consumes dash spans, not dash patterns; '
        'DraftPainter must not open a dash bracket on a sink whose '
        'shadesDashes is false',
      );

  @override
  void endDash() => throw UnsupportedError('PdfDrawSink does not shade dashes');

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    // The painter never nests residuals. If one ever did, the open `q` is
    // closed first, so `q`/`Q` stay balanced whatever the caller does.
    _popTransform();
    _residual = residual;
    _residualScale = residual.scaleMagnitude;
    _inResidual = true;
  }

  @override
  void endResidual() {
    _popTransform();
    _residual = Transform2.identity();
    _residualScale = 1.0;
    _inResidual = false;
  }

  /// Outside a residual a primitive is in screen space and pushes nothing,
  /// so every `q` this sink writes has its `Q` at the residual's end.
  void _pushTransform() {
    if (_transformPushed || !_inResidual) return;
    final r = _residual;
    _g
      ..saveContext()
      ..setTransform(_set(r.a, r.b, r.c, r.d, r.e, r.f));
    _transformPushed = true;
  }

  void _popTransform() {
    if (!_transformPushed) return;
    _g.restoreContext();
    _transformPushed = false;
  }

  /// [_matrix] as the PDF matrix `[a b c d e f]` (column-major storage:
  /// columns 0 and 1 carry the linear part, column 3 the translation).
  Matrix4 _set(double a, double b, double c, double d, double e, double f) =>
      _matrix
        ..setIdentity()
        ..setEntry(0, 0, a)
        ..setEntry(1, 0, b)
        ..setEntry(0, 1, c)
        ..setEntry(1, 1, d)
        ..setEntry(0, 3, e)
        ..setEntry(1, 3, f);

  /// An axis-aligned square on the page, around the point carried through the
  /// residual by hand, as `CanvasDrawSink.point` draws it.
  @override
  void point(double x, double y, ResolvedStyle style) {
    final side = _widthFor(style.lineweightHundredths, 1.0);
    if (side <= 0) return;
    // Screen space: a `cm` left open by an earlier primitive under this
    // residual is closed first, and the next primitive pushes it again.
    _popTransform();
    final sx = _residual.a * x + _residual.c * y + _residual.e;
    final sy = _residual.b * x + _residual.d * y + _residual.f;
    _fillState(style);
    _g
      ..drawRect(sx - side / 2, sy - side / 2, side, side)
      ..fillPath();
  }

  @override
  void polyline(
    Float64List points,
    int count,
    ResolvedStyle style, {
    required bool closed,
  }) {
    if (count <= 0) return;
    _pushTransform();
    _strokeState(style);
    _g.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _g.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    if (closed) _g.closePath();
    _g.strokePath();
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) {
    _pushTransform();
    _strokeState(style);
    _circlePath(cx, cy, r);
    _g.strokePath();
  }

  @override
  void arc(
    double cx,
    double cy,
    double r,
    double start,
    double sweep,
    ResolvedStyle style,
  ) {
    if (sweep == 0 || !sweep.isFinite) return;
    _pushTransform();
    _strokeState(style);
    // A sweep past a full turn draws the full circle, as `Canvas.drawArc`.
    final s = sweep.clamp(-2 * math.pi, 2 * math.pi);
    // At most 90 degrees per cubic; the tolerance keeps an exact quarter
    // turn (or a multiple of one) from splitting into a sliver.
    final n = math.max(1, (s.abs() / (math.pi / 2) - 1e-9).ceil());
    final theta = s / n;
    // Signed: a negative sweep runs clockwise in the local frame.
    final k = 4 / 3 * math.tan(theta / 4);
    var a0 = start;
    _g.moveTo(cx + r * math.cos(a0), cy + r * math.sin(a0));
    for (var i = 0; i < n; i++) {
      final a1 = start + theta * (i + 1);
      _cubic(cx, cy, r, a0, a1, k);
      a0 = a1;
    }
    _g.strokePath();
  }

  @override
  void fillPolygon(
    Float64List points,
    int count,
    Int32List triangles,
    ResolvedStyle style,
  ) {
    if (count < 3) return;
    _pushTransform();
    _fillState(style);
    _g.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _g.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    _g
      ..closePath()
      ..fillPath();
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    _pushTransform();
    _fillState(style);
    _circlePath(cx, cy, r);
    _g.fillPath();
  }

  /// One run at `kNominalTextPixels`, its origin at glyph space's (0, 0)
  /// under the residual.
  ///
  /// `Tz` is `100 · w_flutter / w_pdf`:
  ///
  /// - `w_flutter` is the advance [measurer] gives, the one the painter, the
  ///   picker and `entityBounds` agree on.
  /// - `w_pdf` is the run's advance from the `/W` widths **as the `pdf`
  ///   package writes them**: each glyph's advance in thousandths of an em,
  ///   truncated to an integer (`ttffont.dart`, `_buildType0`), so a viewer
  ///   draws exactly `w_flutter`.
  ///
  /// When either advance is unusable (an empty run, a font with no glyph for
  /// any of it), `Tz` is written as 100. It is always written, as every other
  /// part of the state is.
  @override
  void text(String text, Handle style, ResolvedStyle resolved) {
    if (text.isEmpty) return;
    final font = _font;
    // `w_pdf` below reproduces the `/W` widths of the CID (`/Type0`) path. A
    // simple TrueType font (`simpleTrueTypeFonts`, or a font the package does
    // not write as CID) has `/Widths` by byte code instead, and `Tz` would
    // then be silently wrong.
    if (!font.isCidFont) {
      throw StateError(
        'PdfDrawSink needs a font written as a CID /Type0 font; this '
        'document writes it as a simple /TrueType font',
      );
    }
    _pushTransform();
    _fillState(resolved);
    final pdfAdvance = _pdfTextAdvance(font, text, kNominalTextPixels);
    final flutterAdvance =
        measurer.measure(text: text, style: textStyleOf(style)).advanceWidth;
    final ratio = flutterAdvance / pdfAdvance;
    _g.drawString(
      font,
      kNominalTextPixels,
      text,
      0,
      0,
      scale: pdfAdvance > 0 && ratio.isFinite && ratio >= 0 ? ratio : 1.0,
    );
  }

  /// The advance of [text] at [size] in [font] from the widths the `pdf`
  /// package writes into the font's `/W`: per glyph,
  /// `(advanceWidth · 1000).toInt()` thousandths of an em, as
  /// `PdfTtfFont._buildType0` writes them.
  static double _pdfTextAdvance(PdfTtfFont font, String text, double size) {
    var thousandths = 0;
    for (final rune in text.runes) {
      thousandths += (font.glyphMetrics(rune).advanceWidth * 1000.0).toInt();
    }
    return thousandths / 1000 * size;
  }

  /// A full circle as four 90-degree cubics from angle 0, closed.
  void _circlePath(double cx, double cy, double r) {
    _g.moveTo(cx + r, cy);
    for (var q = 0; q < 4; q++) {
      _cubic(
          cx, cy, r, q * math.pi / 2, (q + 1) * math.pi / 2, _quadrantHandle);
    }
    _g.closePath();
  }

  /// One cubic from angle [a0] to [a1] on the circle, with the signed handle
  /// length [k] (in radii) along each end's tangent.
  void _cubic(double cx, double cy, double r, double a0, double a1, double k) {
    final c0 = math.cos(a0), s0 = math.sin(a0);
    final c1 = math.cos(a1), s1 = math.sin(a1);
    _g.curveTo(
      cx + r * (c0 - k * s0),
      cy + r * (s0 + k * c0),
      cx + r * (c1 + k * s1),
      cy + r * (s1 - k * c1),
      cx + r * c1,
      cy + r * s1,
    );
  }

  void _strokeState(ResolvedStyle style) {
    _g
      ..setStrokeColor(_rgb(style.argb))
      ..setLineWidth(_widthFor(style.lineweightHundredths, _residualScale));
    _alpha(style.argb);
  }

  void _fillState(ResolvedStyle style) {
    _g.setFillColor(_rgb(style.argb));
    _alpha(style.argb);
  }

  /// One `ExtGState` per distinct alpha (the package keeps one entry per
  /// equal state), written for every primitive, opaque ones included.
  void _alpha(int argb) {
    final opacity = ((argb >> 24) & 0xFF) / 255;
    _g.setGraphicState(PdfGraphicState(opacity: opacity));
  }

  static PdfColor _rgb(int argb) => PdfColor(
        ((argb >> 16) & 0xFF) / 255,
        ((argb >> 8) & 0xFF) / 255,
        (argb & 0xFF) / 255,
      );

  double _widthFor(int lineweightHundredths, double residualScale) {
    final device = lineweightHundredths / 100.0 * pixelsPerPaperMm;
    final w = residualScale == 0 ? device : device / residualScale;
    // 0 writes `0 w`: the thinnest line the output device can draw.
    return w.isFinite && w > 0 ? w : 0.0;
  }

  /// The document this sink writes into; its graphic states are shared.
  PdfDocument get document => _document;
}
