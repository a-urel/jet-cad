// Software Skia's `drawVertices` does not antialias, at all -- an instrument
// property `fill_seam_test.dart`'s zero result depends on.
//
// `fill_seam_test.dart` measures 0.000% divergence between `CanvasDrawSink`
// and `VerticesDrawSink` under a translucent fill. Task 15's review correctly
// pushed back on reading that zero as evidence the mode-2 seam (partial
// coverage on a shared triangulation edge, double-blended) is absent on real
// hardware: the zero could equally mean the *instrument* cannot produce a
// seam at all, independent of whether the artefact is real. This file
// settles which one it is, with `Canvas.drawVertices` driven directly -- no
// `VerticesDrawSink`, no residual, nothing this repository wrote -- so a
// green run here is a fact about `flutter_test`'s software Skia, not about
// this codebase.
//
// **Probe 1.** Two triangles sharing a diagonal edge -- the exact shape a
// shared triangulation edge takes -- filled translucent, once with
// `Paint.isAntiAlias = true` and once `false`. If AA does anything on this
// path, the flag changes at least one byte near the diagonal. It does not:
// the two captures are byte-identical, and so is the same two-triangle
// rectangle against a single `drawPath` fill of the identical rectangle.
//
// **Probe 2.** Sampled directly along the diagonal. Every pixel the
// `drawVertices` capture puts near the edge reads the flat, fully-covered
// fill colour -- never a blend toward white -- while the *same* slope filled
// by `Canvas.drawPath` (one triangle, same hypotenuse) shows a real
// partial-coverage ramp at the same coordinates.
//
// **Conclusion this file pins:** `flutter_test`'s software Skia does not
// implement per-primitive antialiasing for `drawVertices`, independent of
// the paint flag. Mode 2's predicted mechanism -- partial coverage from two
// adjacent triangles compounding into a double blend -- has nothing to act
// on in this instrument. `fill_seam_test.dart`'s 0.000% is real *for this
// instrument* and answers nothing about Impeller/GPU, where MSAA-based
// per-primitive antialiasing is real. If this test ever goes red,
// `flutter_test`'s Skia has changed and `fill_seam_test.dart` needs to be
// re-measured before its zero is trusted again.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _capture(
    WidgetTester tester, void Function(Canvas) draw) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 400),
      Paint()..color = const Color(0xFFFFFFFF));
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await tester.runAsync(() => picture.toImage(400, 400));
  addTearDown(image!.dispose);
  final data = (await tester
      .runAsync(() => image.toByteData(format: ImageByteFormat.rawRgba)))!;
  picture.dispose();
  return data;
}

int _maxDelta(ByteData a, ByteData b) {
  var worst = 0;
  for (var i = 0; i < a.lengthInBytes; i++) {
    final d = (a.getUint8(i) - b.getUint8(i)).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

List<int> _rgba(ByteData d, int x, int y, int width) {
  final i = (y * width + x) * 4;
  return [
    d.getUint8(i),
    d.getUint8(i + 1),
    d.getUint8(i + 2),
    d.getUint8(i + 3)
  ];
}

const int _argb = 0x803366CC;
const List<int> _fullCoverage = [
  153,
  178,
  229,
  255
]; // 0x3366CC at 0x80 over white

/// Rectangle `(100,100)-(300,220)` split into two triangles by the diagonal
/// `(100,100)-(300,220)` -- the shape `VerticesDrawSink.fillPolygon` produces
/// for any triangulated region with a shared interior edge.
final Float32List _positions = Float32List.fromList([
  100, 100, 300, 100, 300, 220, // T1
  100, 100, 300, 220, 100, 220, // T2
]);
final Int32List _colors = Int32List.fromList(List.filled(6, _argb));

/// Six device-pixel coordinates straddling the diagonal
/// `(100,100)-(300,220)` (slope 0.6): close enough to the edge that a real
/// antialiaser would show partial coverage at more than one of them.
const List<(int, int)> _straddlePoints = [
  (150, 130),
  (150, 131),
  (150, 132),
  (199, 160),
  (200, 160),
  (201, 160),
];

void main() {
  testWidgets(
      'drawVertices ignores isAntiAlias: the paint flag changes nothing',
      (tester) async {
    final aaOn = await _capture(tester, (canvas) {
      final v = Vertices.raw(VertexMode.triangles, _positions, colors: _colors);
      canvas.drawVertices(v, BlendMode.srcOver, Paint()..isAntiAlias = true);
      v.dispose();
    });
    final aaOff = await _capture(tester, (canvas) {
      final v = Vertices.raw(VertexMode.triangles, _positions, colors: _colors);
      canvas.drawVertices(v, BlendMode.srcOver, Paint()..isAntiAlias = false);
      v.dispose();
    });

    // MUTATION (documentary, not injected here): if `flutter_test`'s Skia
    // ever antialiases `drawVertices`, this goes nonzero and the comment
    // block above says what to do about it.
    expect(_maxDelta(aaOn, aaOff), 0,
        reason: 'if this is nonzero, software Skia now antialiases '
            'drawVertices and fill_seam_test.dart must be re-measured -- its '
            '0.000% was read against an instrument that could not have shown '
            'a seam');
  });

  testWidgets(
      'drawVertices shows no coverage ramp on a shared edge where drawPath does',
      (tester) async {
    final vertices = await _capture(tester, (canvas) {
      final v = Vertices.raw(VertexMode.triangles, _positions, colors: _colors);
      canvas.drawVertices(v, BlendMode.srcOver, Paint()..isAntiAlias = true);
      v.dispose();
    });
    final path = await _capture(tester, (canvas) {
      final p = Path()
        ..moveTo(100, 100)
        ..lineTo(300, 100)
        ..lineTo(300, 220)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..color = const Color(_argb)
            ..isAntiAlias = true);
    });

    for (final (x, y) in _straddlePoints) {
      final vRgba = _rgba(vertices, x, y, 400);
      expect(vRgba, _fullCoverage,
          reason: 'drawVertices at ($x,$y) should be flat full coverage or '
              'this straddle point was chosen badly, not a genuine ramp -- '
              'got $vRgba');
    }

    final pathValues = [
      for (final (x, y) in _straddlePoints) _rgba(path, x, y, 400)
    ];
    final pathShowsAPartialPixel = pathValues.any((rgba) =>
        rgba[0] != 255 && rgba[0] != _fullCoverage[0] && rgba != _fullCoverage);
    expect(pathShowsAPartialPixel, isTrue,
        reason: 'the same slope filled by drawPath should show at least one '
            'genuinely partial-coverage pixel at these coordinates, or this '
            'is not the contrast probe 2 claims to be -- got $pathValues');
  });
}
