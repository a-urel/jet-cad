### Task 4: The compositor, and the region arithmetic it draws by

**Files:**
- Create: `lib/src/gpu/text_compositor.dart`
- Modify: `lib/src/gpu/text_patches.dart` (add `PatchRegion`, `patchRegionFor`, `patchTargetSizeFor`)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Test: `test/gpu/text_compositor_test.dart`, `test/gpu/text_patches_test.dart` (region and size)

**Interfaces:**
- Consumes: `ResidentTextRecord`, `FlutterTextMeasurer.paragraphFor(text, styleHandle, style, argb)`,
  `Paragraph.alphabeticBaseline`, `Transform2`.
- Produces:
  ```dart
  class PatchRegion { final int x, y, width, height; }   // device pixels, on screen
  PatchRegion? patchRegionFor(ResidentTextRecord t, Transform2 collectionToDevice,
      int widthPx, int heightPx, {required int maxWidth, required int maxHeight});
  (int, int) patchTargetSizeFor(ResidentTextRecord t, double devicePixelRatio,
      {double bandUpperScale = kBandUpperScale, required int maxWidth, required int maxHeight});
  class PatchImage { textIndex; ui.Image image; Rect src; Rect dst; Rect layerBounds; }
  class TextCompositor {
    TextCompositor({required FlutterTextMeasurer measurer, required TextStyleRecord Function(Handle) textStyleOf});
    void paint(Canvas canvas, {ui.Image? main, required Size viewport,
        required Transform2 collectionToLogical, required List<ResidentTextRecord> texts,
        required List<PatchImage> patches});
    int get patchesComposited;   // diagnostics, reset per paint
  }
  Rect labelBoundsLogical(ResidentTextRecord t, Transform2 collectionToLogical);
  ```

**What the compositor does, in order** (revision 5, "Per frame, in emission
order"): the main image over the viewport; then the text list in list order —
a plain label is `save; transform(outer ∘ residual); translate(0, baseline);
scale(1, -1); drawParagraph; restore`; a patched label is `saveLayer(layerBounds)`
then the same paragraph then `drawImageRect(patch, src, dst, srcATop)` then
`restore`. `patches` is sorted by `textIndex` (Task 2 guarantees it) and is
consumed with one cursor. **The baseline flip is in one helper both branches
call** — the spec says so because it is the flip `canvas_draw_sink_test.dart`'s
*"a paragraph is drawn in glyph space, y up"* test exists to protect.

- [ ] **Step 1: Region and size tests**

Append to `test/gpu/text_patches_test.dart`:

```dart
  group('patchRegionFor', () {
    // A label whose collection box is (10, 20) .. (50, 40); the camera maps
    // collection to device by scale 2 and a translation, so on screen the
    // box is (120, 240) .. (200, 280).
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    const cam = Transform2(2, 0, 0, 2, 100, 200);

    test('is the box under the camera, rounded outward, on screen', () {
      final r = patchRegionFor(t, cam, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [120, 240, 80, 40]);
    });

    test('rounds outward, never inward', () {
      const cam2 = Transform2(2, 0, 0, 2, 100.4, 200.6);
      final r = patchRegionFor(t, cam2, 800, 600, maxWidth: 800, maxHeight: 600)!;
      // 120.4 -> 120, 240.6 -> 240, right edge 200.4 -> 201, bottom 280.6 -> 281
      expect([r.x, r.y, r.width, r.height], [120, 240, 81, 41]);
    });

    test('a label partly off the top-left edge is clamped, not negative', () {
      // `Viewport` and `Scissor` throw on a negative origin. Box on screen:
      // (-40, -20) .. (40, 20) -> the visible part is (0, 0) .. (40, 20).
      const cam3 = Transform2(2, 0, 0, 2, -60, -60);
      final r = patchRegionFor(t, cam3, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect([r.x, r.y, r.width, r.height], [0, 0, 40, 20]);
      // Box on screen: (-280, -360) .. (-200, -320) -> entirely off: null.
      const cam4 = Transform2(2, 0, 0, 2, -300, -400);
      expect(patchRegionFor(t, cam4, 800, 600, maxWidth: 800, maxHeight: 600),
          isNull);
    });

    test('a region larger than the target is clamped to the target', () {
      final r = patchRegionFor(t, cam, 800, 600, maxWidth: 30, maxHeight: 30)!;
      expect([r.width, r.height], [30, 30]);
    });

    test('a rotated camera bounds all four corners', () {
      // 90-degree rotation: the 40x20 box becomes 20x40 on screen; a region
      // built from two corners only would have a negative size.
      final rot = Transform2.translation(300, 300)
          .multiply(Transform2.rotation(3.141592653589793 / 2));
      final r = patchRegionFor(t, rot, 800, 600, maxWidth: 800, maxHeight: 600)!;
      expect(r.width, 20);
      expect(r.height, 40);
    });
  });

  group('patchTargetSizeFor', () {
    final t = _label(minX: 10, minY: 20, maxX: 50, maxY: 40, at: 0);
    test('is the box at the band ceiling, in device pixels, rounded up', () {
      // 40x20 collection units * dpr 2 * ceiling 2 = 160x80.
      expect(patchTargetSizeFor(t, 2.0, maxWidth: 4000, maxHeight: 4000),
          (160, 80));
    });
    test('is clamped to the viewport', () {
      expect(patchTargetSizeFor(t, 2.0, maxWidth: 100, maxHeight: 50), (100, 50));
    });
    test('is never zero', () {
      final thin = _label(minX: 10, minY: 20, maxX: 10, maxY: 20, at: 0);
      expect(patchTargetSizeFor(thin, 1.0, maxWidth: 100, maxHeight: 100), (1, 1));
    });
  });
```

- [ ] **Step 2: Implement the region arithmetic in `text_patches.dart`**

```dart
/// Where a patch draws on screen this frame: device pixels, on the viewport.
class PatchRegion {
  const PatchRegion(this.x, this.y, this.width, this.height);
  final int x, y, width, height;
}

/// The label's box under the live camera, intersected with the viewport,
/// rounded outward and clamped to the patch target's size (Ruling E8).
///
/// Returns null when the label is entirely off screen -- no pass, no
/// composite. Never returns a negative origin: `flutter_gpu`'s `Viewport`
/// and `Scissor` throw on one, and the pass is anchored at the target's own
/// origin anyway; this region's `x, y` are for the compositor's `dst`.
PatchRegion? patchRegionFor(ResidentTextRecord t, Transform2 collectionToDevice,
    int widthPx, int heightPx,
    {required int maxWidth, required int maxHeight}) {
  final m = collectionToDevice;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  void corner(double x, double y) {
    final dx = m.a * x + m.c * y + m.e, dy = m.b * x + m.d * y + m.f;
    if (dx < minX) minX = dx;
    if (dx > maxX) maxX = dx;
    if (dy < minY) minY = dy;
    if (dy > maxY) maxY = dy;
  }
  corner(t.boxMinX, t.boxMinY);
  corner(t.boxMaxX, t.boxMinY);
  corner(t.boxMinX, t.boxMaxY);
  corner(t.boxMaxX, t.boxMaxY);
  final x0 = minX.floor().clamp(0, widthPx);
  final y0 = minY.floor().clamp(0, heightPx);
  final x1 = maxX.ceil().clamp(0, widthPx);
  final y1 = maxY.ceil().clamp(0, heightPx);
  if (x1 <= x0 || y1 <= y0) return null;
  final w = (x1 - x0).clamp(0, maxWidth);
  final h = (y1 - y0).clamp(0, maxHeight);
  return PatchRegion(x0, y0, w, h);
}

/// The patch target's size: the label's box at the band's CEILING, in
/// device pixels, rounded up and clamped to the viewport -- the largest
/// region [patchRegionFor] can return inside the band, so a zoom inside it
/// resizes the region and never the texture. Never zero in either
/// dimension: a zero-sized texture is a per-backend question this plan does
/// not ask (the same rule `ResidentGeometry._upload` applies to an empty
/// instance buffer).
(int, int) patchTargetSizeFor(ResidentTextRecord t, double devicePixelRatio,
    {double bandUpperScale = kBandUpperScale,
    required int maxWidth,
    required int maxHeight}) {
  final k = devicePixelRatio * bandUpperScale;
  final w = ((t.boxMaxX - t.boxMinX) * k).ceil().clamp(1, maxWidth);
  final h = ((t.boxMaxY - t.boxMinY) * k).ceil().clamp(1, maxHeight);
  return (w, h);
}
```

**A rotated box under a rotating camera:** `patchTargetSizeFor` sizes by the
collection box's width and height, but under a rotated live camera the
device region is the rotated box's bound and can be up to √2 larger in each
dimension. `CameraController` in this codebase pans and zooms and does not
rotate; if that changes, `patchRegionFor`'s clamp-to-target keeps the pass
legal (the drawn region shrinks) and the harness's `patchClipped` counter
(Task 6) reports it. Write that sentence into `patchTargetSizeFor`'s doc.

- [ ] **Step 3: Compositor tests**

Create `test/gpu/text_compositor_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const TextStyleRecord _standard =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

const int _w = 200, _h = 120;

/// Paints [draw] into a [_w] x [_h] image.
Future<Image> _image(void Function(Canvas c) draw) {
  final recorder = PictureRecorder();
  draw(Canvas(recorder));
  return recorder.endRecording().toImage(_w, _h);
}

Future<Uint8List> _rgba(Image image) async =>
    (await image.toByteData(format: ImageByteFormat.rawRgba))!.buffer.asUint8List();

int _alpha(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 3];
int _red(Uint8List px, int x, int y) => px[(y * _w + x) * 4];
int _blue(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 2];

/// A label at a large size, placed so its glyphs sit around (60, 60) in a
/// y-up glyph space mapped onto the image by a y-flip -- the shape of
/// residual the painter actually hands a sink.
ResidentTextRecord _label({required int instanceIndex}) =>
    const ResidentTextRecord(
        text: 'A B',
        style: Handle(11),
        argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 20, f: 80,
        boxMinX: 0, boxMinY: 0, boxMaxX: _w.toDouble(), boxMaxY: _h.toDouble(),
        instanceIndex: instanceIndex);

void main() {
  late FlutterTextMeasurer measurer;
  late TextCompositor compositor;
  setUp(() {
    measurer = FlutterTextMeasurer();
    compositor = TextCompositor(
        measurer: measurer, textStyleOf: (Handle h) => _standard);
  });

  /// Where the label alone has ink, and where inside its box it has none --
  /// found by rendering, never assumed: `flutter test`'s font is not the
  /// device's.
  Future<(Point<int>, Point<int>)> samplePoints() async {
    final alone = await _rgba(await _image((c) => compositor.paint(c,
        main: null,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: const [])));
    Point<int>? ink, blank;
    for (var y = 20; y < 100 && (ink == null || blank == null); y++) {
      for (var x = 20; x < 180; x++) {
        final a = _alpha(alone, x, y);
        if (a > 200 && ink == null) ink = Point(x, y);
        if (a == 0 && blank == null && x > 30) blank = Point(x, y);
      }
    }
    expect(ink, isNotNull, reason: 'the label rendered no ink at all');
    expect(blank, isNotNull, reason: 'the label has no blank pixel to test');
    return (ink!, blank!);
  }

  test('a plain label draws over the main image, in glyph space, y up', () async {
    final (ink, blank) = await samplePoints();
    final main = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFFFF0000)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: const [])));
    expect(_red(out, ink.x, ink.y), lessThan(60), reason: 'ink is black');
    expect(_red(out, blank.x, blank.y), greaterThan(200), reason: 'main shows');
    expect(compositor.patchesComposited, 0);
  });

  test('a patch puts later geometry over the ink and nowhere else (srcATop)',
      () async {
    final (ink, blank) = await samplePoints();
    final main = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFFFF0000)));
    // The patch: solid blue over the whole region, transparent elsewhere --
    // what a pass over a sub-buffer of one huge stroke would render.
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFF0000FF)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: [
          PatchImage(
              textIndex: 0,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    expect(_blue(out, ink.x, ink.y), greaterThan(200),
        reason: 'over the glyph: the later stroke covers the label');
    expect(_red(out, blank.x, blank.y), greaterThan(200),
        reason: 'beside the glyph: the main image, untouched -- srcOver '
            'would paint blue here');
    expect(_blue(out, blank.x, blank.y), lessThan(60));
    expect(compositor.patchesComposited, 1);
  });

  test('a translucent later fill blends once inside the ink, never twice',
      () async {
    final (ink, blank) = await samplePoints();
    // Main: the fill (50% blue) already over white, as the main pass draws
    // it. Patch: the same 50% blue over transparent.
    const half = Color(0x800000FF);
    final main = await _image((c) => c
      ..drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF))
      ..drawRect(Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
          Paint()..color = half));
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()), Paint()..color = half));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0)],
        patches: [
          PatchImage(
              textIndex: 0,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    // Beside the glyph: exactly the main image's 50% blue over white --
    // red channel ~128. A second blend (srcOver) would push it to ~64.
    expect(_red(out, blank.x, blank.y), inInclusiveRange(118, 138));
    // Over the glyph: 50% blue over black ink -- red 0, blue ~128.
    expect(_blue(out, ink.x, ink.y), inInclusiveRange(118, 138));
  });

  test('labels and patches walk in list order, with one cursor', () async {
    // Two labels; only the SECOND is patched. A compositor that matched
    // patches by position rather than by textIndex would patch the first.
    final (ink, _) = await samplePoints();
    final far = ResidentTextRecord(
        text: 'A B', style: const Handle(11), argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 20, f: 300, // off the image
        boxMinX: 0, boxMinY: 200, boxMaxX: _w.toDouble(), boxMaxY: 400,
        instanceIndex: 0);
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFF0000FF)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: null,
        viewport: const Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: Transform2.identity(),
        texts: [_label(instanceIndex: 0), far],
        patches: [
          PatchImage(
              textIndex: 1,
              image: patch,
              src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
              layerBounds: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
        ])));
    expect(_blue(out, ink.x, ink.y), lessThan(60),
        reason: "the first label's ink is not patched");
  });

  test('the outer transform moves the label, and is applied once', () async {
    // Under `translation(30, 0)` every pixel of the label's row moves by
    // exactly 30: a compositor that applied the outer transform twice moves
    // it by 60, one that ignored it by 0, and neither reproduces the row.
    final (ink, _) = await samplePoints();
    Future<Uint8List> under(Transform2 outer) async =>
        _rgba(await _image((c) => compositor.paint(c,
            main: null,
            viewport: const Size(_w.toDouble(), _h.toDouble()),
            collectionToLogical: outer,
            texts: [_label(instanceIndex: 0)],
            patches: const [])));
    final identity = await under(Transform2.identity());
    final shifted = await under(Transform2.translation(30, 0));
    var inked = 0;
    for (var x = 0; x + 30 < _w; x++) {
      expect(_alpha(shifted, x + 30, ink.y), _alpha(identity, x, ink.y),
          reason: 'row ${ink.y}, x $x');
      if (_alpha(identity, x, ink.y) > 200) inked++;
    }
    expect(inked, greaterThan(0), reason: 'the row compared carries ink');
  });

  test('labelBoundsLogical is the four corners under the outer transform', () {
    final t = _label(instanceIndex: 0);
    final r = labelBoundsLogical(t, Transform2.rotation(3.141592653589793 / 2));
    expect(r.width, closeTo(_h.toDouble(), 1e-6));
    expect(r.height, closeTo(_w.toDouble(), 1e-6));
  });
}
```

The `Point` type is `dart:math`'s; add `import 'dart:math' show Point;`.

- [ ] **Step 4: Implement `text_compositor.dart`**

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../flutter_text_measurer.dart';
import 'resident_text.dart';

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
/// Four corners, re-bounded -- a rotated camera or a mirrored label must
/// not produce a negative-sized layer.
Rect labelBoundsLogical(ResidentTextRecord t, Transform2 m) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  void corner(double x, double y) {
    final lx = m.a * x + m.c * y + m.e, ly = m.b * x + m.d * y + m.f;
    if (lx < minX) minX = lx;
    if (lx > maxX) maxX = lx;
    if (ly < minY) minY = ly;
    if (ly > maxY) maxY = ly;
  }
  corner(t.boxMinX, t.boxMinY);
  corner(t.boxMaxX, t.boxMinY);
  corner(t.boxMinX, t.boxMaxY);
  corner(t.boxMaxX, t.boxMaxY);
  return Rect.fromLTRB(minX, minY, maxX, maxY);
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

  void paint(
    Canvas canvas, {
    required Image? main,
    required Size viewport,
    required Transform2 collectionToLogical,
    required List<ResidentTextRecord> texts,
    required List<PatchImage> patches,
  }) {
    _patchesComposited = 0;
    if (main != null) {
      canvas.drawImageRect(
          main,
          Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
          Rect.fromLTWH(0, 0, viewport.width, viewport.height),
          _imagePaint);
    }
    var p = 0;
    for (var i = 0; i < texts.length; i++) {
      final patch = p < patches.length && patches[p].textIndex == i
          ? patches[p++]
          : null;
      if (patch == null) {
        _drawLabel(canvas, texts[i], collectionToLogical);
        continue;
      }
      // The layer's bounds are in the OUTER frame -- logical pixels -- and
      // the label's own six floats are applied inside `_drawLabel`, after
      // this call. A layer opened after the residual would be transformed
      // twice (a Copilot review finding on revision 5's first draft).
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
```

The hand composition is `Transform2.multiply`'s formula with `o` as the
receiver (`transform2.dart:62-69`) — check it term for term against that
method before committing, and add a test in `text_compositor_test.dart` that
records `_matrix` through a `SpyCanvas` (`test/support/spy_canvas.dart`) for
one label under a non-identity outer transform and compares it with
`o.multiply(Transform2(t.a, t.b, t.c, t.d, t.e, t.f))` — the same way
`canvas_draw_sink_test.dart` reads `_transformBeforeDraw`.

Add to `lib/jet_cad_2d_flutter.dart`:
```dart
export 'src/gpu/text_compositor.dart';
```

- [ ] **Step 5: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/gpu/text_compositor.dart lib/src/gpu/text_patches.dart lib/jet_cad_2d_flutter.dart \
  test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart
git commit -m "feat(gpu): the text compositor -- a label over the main image, a patch over its ink"
```

---

