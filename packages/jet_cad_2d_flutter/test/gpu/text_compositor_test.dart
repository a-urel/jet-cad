import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/spy_canvas.dart';

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
    (await image.toByteData(format: ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();

int _alpha(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 3];
int _red(Uint8List px, int x, int y) => px[(y * _w + x) * 4];
int _blue(Uint8List px, int x, int y) => px[(y * _w + x) * 4 + 2];

/// A label at a large size, placed so its glyphs sit around (60, 60) in a
/// y-up glyph space mapped onto the image by a y-flip -- the shape of
/// residual the painter actually hands a sink.
ResidentTextRecord _label({required int instanceIndex}) => ResidentTextRecord(
    text: 'A B',
    style: const Handle(11),
    argb: 0xFF000000,
    a: 1,
    b: 0,
    c: 0,
    d: -1,
    e: 20,
    f: 80,
    boxMinX: 0,
    boxMinY: 0,
    boxMaxX: _w.toDouble(),
    boxMaxY: _h.toDouble(),
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
        viewport: Size(_w.toDouble(), _h.toDouble()),
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

  test('a plain label draws over the main image, in glyph space, y up',
      () async {
    final (ink, blank) = await samplePoints();
    final main = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFFFF0000)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
        main: main,
        viewport: Size(_w.toDouble(), _h.toDouble()),
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
            viewport: Size(_w.toDouble(), _h.toDouble()),
            collectionToLogical: Transform2.identity(),
            texts: [
              _label(instanceIndex: 0)
            ],
            patches: [
              PatchImage(
                  textIndex: 0,
                  image: patch,
                  src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  layerBounds:
                      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
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
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = half));
    final out = await _rgba(await _image((c) => compositor.paint(c,
            main: main,
            viewport: Size(_w.toDouble(), _h.toDouble()),
            collectionToLogical: Transform2.identity(),
            texts: [
              _label(instanceIndex: 0)
            ],
            patches: [
              PatchImage(
                  textIndex: 0,
                  image: patch,
                  src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  layerBounds:
                      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
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
        text: 'A B',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1,
        b: 0,
        c: 0,
        d: -1,
        e: 20,
        f: 300, // off the image
        boxMinX: 0,
        boxMinY: 200,
        boxMaxX: _w.toDouble(),
        boxMaxY: 400,
        instanceIndex: 0);
    final patch = await _image((c) => c.drawRect(
        Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
        Paint()..color = const Color(0xFF0000FF)));
    final out = await _rgba(await _image((c) => compositor.paint(c,
            main: null,
            viewport: Size(_w.toDouble(), _h.toDouble()),
            collectionToLogical: Transform2.identity(),
            texts: [
              _label(instanceIndex: 0),
              far
            ],
            patches: [
              PatchImage(
                  textIndex: 1,
                  image: patch,
                  src: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  dst: Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
                  layerBounds:
                      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble())),
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
            viewport: Size(_w.toDouble(), _h.toDouble()),
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

  test('the composed matrix is outer.multiply(residual), applied once',
      () async {
    // The reference `Transform2.multiply.multiply` composition, read the
    // same way `canvas_draw_sink_test.dart` reads `_transformBeforeDraw`:
    // record what actually reached `Canvas.transform` and compare it with
    // the formula, term for term, rather than trusting the implementation
    // that produced it.
    final spy = SpyCanvas();
    final outer = Transform2(2, 0.5, -0.5, 2, 7, -3);
    final t = _label(instanceIndex: 0);
    compositor.paint(spy,
        main: null,
        viewport: Size(_w.toDouble(), _h.toDouble()),
        collectionToLogical: outer,
        texts: [t],
        patches: const []);
    final call = spy.named('transform').single;
    final v = call.args[0]! as Float64List;
    final composed = Transform2(v[0], v[1], v[4], v[5], v[12], v[13]);
    final expected = outer.multiply(Transform2(t.a, t.b, t.c, t.d, t.e, t.f));
    expect(composed.a, closeTo(expected.a, 1e-9));
    expect(composed.b, closeTo(expected.b, 1e-9));
    expect(composed.c, closeTo(expected.c, 1e-9));
    expect(composed.d, closeTo(expected.d, 1e-9));
    expect(composed.e, closeTo(expected.e, 1e-9));
    expect(composed.f, closeTo(expected.f, 1e-9));
  });
}
