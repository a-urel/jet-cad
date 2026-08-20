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
  test(
      'the marker is axis-aligned on screen under a sheared, '
      'non-uniformly-scaled residual', () async {
    // `a != d` (1.5 vs 0.8) and both shear terms `b`, `c` are nonzero and not
    // a rotation pairing (`b != -c`) -- on purpose, and for two separate
    // reasons:
    //
    // 1. Shape: a residual that only rotates or uniformly scales (`a == d`)
    //    still distorts a *locally drawn* square's bounding box (see the
    //    MUTATION below), so it already discriminates old from new -- but a
    //    residual that also shears is the stronger claim, and the one this
    //    task actually makes: on screen, in *any* residual.
    // 2. Position: `sx = a*x + c*y + e` and `sy = b*x + d*y + f` cannot tell
    //    a correct implementation from one with `a` and `d` swapped when
    //    `a == d` -- the swap is then a no-op. The point here is drawn at a
    //    nonzero local coordinate `(3, 4)` and the assertion below pins the
    //    exact device-space bounds, not just their size, so that swap is
    //    caught by this fixture too.
    //
    // MUTATION 1: revert `point` to push the residual and call
    // `canvas.drawRawPoints` in local space -- the old behaviour. The local
    // square then goes through the same sheared transform as the rest of the
    // scene and comes back a non-square parallelogram, not a 4x4 axis-aligned
    // box.
    //
    // MUTATION 2: swap `a` and `d` in the coordinate math (`sx = d*x + c*y +
    // e; sy = b*x + a*y + f`). The marker stays a 4x4 axis-aligned square --
    // that claim survives -- but it recenters at the wrong device position,
    // which the exact-bounds assertion below catches.
    const t = Transform2(1.5, 0.3, 0.4, 0.8, 1.9, 3.9);

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
      ..point(3, 4, _style())
      ..endResidual();
    expect(sink.canvasCallCount, 1);

    final bounds = await _alphaBounds(recorder.endRecording());
    // sx = 1.5*3 + 0.4*4 + 1.9 = 8.0; sy = 0.3*3 + 0.8*4 + 3.9 = 8.0. The
    // marker's half-width is a device-pixel quantity (2.0, from 1.0 mm at
    // 4 px/mm) that does not scale with the residual, so the rasterised
    // square sits exactly on [6, 9]x[6, 9] whatever `a`, `b`, `c`, `d` are --
    // this is the whole "axis-aligned and uniform on screen" claim.
    expect(bounds, (minX: 6, maxX: 9, minY: 6, maxY: 9));
  });

  test('the two sinks agree on where the marker goes', () {
    // The position is not in question -- only the orientation -- so this pins
    // the position on the sink whose geometry is readable, and Task 10's
    // comparison covers the pair.
    //
    // Non-uniform and sheared (`a != d`, `b != -c`) rather than a pure
    // rotation: a residual with `a == d` cannot distinguish this sink's
    // `sx = a*x + c*y + e` from a version with `a` and `d` swapped, so a
    // symmetric fixture here would not actually be pinning the formula.
    const t = Transform2(1.7, 0.35, -0.2, 0.9, 100, 200);
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
