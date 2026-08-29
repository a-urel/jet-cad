import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

const _style = ResolvedStyle(
    argb: 0xFF203040,
    lineweightHundredths: 50,
    linetype: Handle.none,
    linetypeScale: 1);

void main() {
  test('applies the residual, and a non-uniform one', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: 4, devicePixelRatio: 2, lineweightScale: 1);

    // **Deliberately not the identity, not at the origin, and not uniform.**
    // a=2, d=3 with a translation: a collector that drops the residual writes
    // (1,1)->(2,2); one that applies it writes (12,13)->(14,16).
    c.beginResidual(Transform2(2, 0, 0, 3, 10, 10));
    final pts = Float64List.fromList([1, 1, 2, 2]);
    c.polyline(pts, 2, _style, closed: false);
    c.endResidual();

    expect(c.instanceCount, 1);
    final r = c.data.sublist(0, kFloatsPerInstance);
    expect(r[0], kKindStroke);
    expect(r.sublist(1, 5), [12.0, 13.0, 14.0, 16.0]);
  });

  test('emits one instance per segment, in walk order', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0, 1, 1]), 3, _style,
        closed: false);
    c.endResidual();

    expect(c.instanceCount, 2);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(c.data.sublist(kFloatsPerInstance + 1, kFloatsPerInstance + 5),
        [1.0, 0.0, 1.0, 1.0]);
  });

  test('drops a zero-length segment rather than handing the shader a NaN', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([5, 5, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.instanceCount, 0);
  });

  test('counts the ops Plan A does not draw instead of dropping them silently',
      () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.circle(0, 0, 5, _style);
    c.text('x', Handle.none, _style);
    c.endResidual();
    expect(c.instanceCount, 0);
    expect(c.skippedOps, 2);
  });
}
