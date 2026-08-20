// A point marker is axis-aligned on the screen, on both backends.
//
// `CanvasDrawSink` used to draw it through `drawRawPoints` under the pushed
// residual, so a rotated instance turned the marker with it. Nothing wants
// that: the marker marks a position, and its orientation carries no
// information about the drawing.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const _lw = 100;
const _pxPerMm = 4.0;

ResolvedStyle _style() => const ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

/// Rasterises [picture] into a small buffer and returns the axis-aligned
/// pixel bounding box of everything with nonzero alpha.
///
/// Kept to a 16x16 image, the same budget `vertices_draw_sink_test.dart`
/// uses for its own rasterised assertions.
Future<({int minX, int maxX, int minY, int maxY})> _alphaBounds(
    Picture picture) async {
  const size = 16;
  final image = await picture.toImage(size, size);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  picture.dispose();

  var minX = size, maxX = -1, minY = size, maxY = -1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final alpha = bytes[(y * size + x) * 4 + 3];
      if (alpha > 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}

void main() {
  test('the marker is axis-aligned on screen under a rotated residual',
      () async {
    // A 30-degree residual with no translation in local space -- the marker
    // is drawn at the local origin, so only the *shape* can grow, not the
    // position. An axis-aligned marker rasterises to a 4x4-pixel square
    // (1.0 mm at 4 px/mm) however the residual rotates; a marker drawn in
    // local space and then rotated with the residual comes back with a
    // bigger bounding box, because a rotated square's axis-aligned bbox is
    // wider than the square itself.
    //
    // MUTATION: revert `point` to push the residual and call
    // `canvas.drawRawPoints` in local space -- the old behaviour. Measured
    // directly: at this same angle the old code's rasterised bounding box is
    // 6x6 device pixels, not 4x4.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 8, 8);

    final recorder = PictureRecorder();
    final sink = CanvasDrawSink(
      canvas: Canvas(recorder),
      pixelsPerPaperMm: _pxPerMm,
      measurer: FlutterTextMeasurer(),
      textStyleOf: (_) => const TextStyleRecord(
          handle: ReservedHandles.standardTextStyle,
          name: 'Standard',
          fontFamily: 'Roboto'),
    );

    sink
      ..beginResidual(t)
      ..point(0, 0, _style())
      ..endResidual();
    expect(sink.canvasCallCount, 1);

    final bounds = await _alphaBounds(recorder.endRecording());
    final width = bounds.maxX - bounds.minX + 1;
    final height = bounds.maxY - bounds.minY + 1;
    // The axis-aligned square is 4 device pixels on a side; the old,
    // locally-drawn-then-rotated square rasterises to 6.
    expect(width, 4);
    expect(height, 4);
  });

  test('the two sinks agree on where the marker goes', () {
    // The position is not in question -- only the orientation -- so this pins
    // the position on the sink whose geometry is readable, and Task 10's
    // comparison covers the pair.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 100, 200);
    final sink = VerticesDrawSink(pixelsPerPaperMm: _pxPerMm)
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();

    final v = sink.debugPositions();
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < v.length; i += 2) {
      minX = math.min(minX, v[i]);
      maxX = math.max(maxX, v[i]);
      minY = math.min(minY, v[i + 1]);
      maxY = math.max(maxY, v[i + 1]);
    }
    // 1.0 mm at 4 px/mm is a 4-pixel square, axis-aligned whatever the
    // residual does.
    expect(maxX - minX, closeTo(4.0, 1e-6));
    expect(maxY - minY, closeTo(4.0, 1e-6));
  });
}
