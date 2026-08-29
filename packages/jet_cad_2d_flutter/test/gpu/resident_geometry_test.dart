import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';
import 'package:jet_cad_2d_flutter/src/gpu/resident_geometry.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('returns null rather than throwing where there is no GPU', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(Float32List(kFloatsPerInstance), 1);
    expect(g, isNull,
        reason: 'the caller falls back; it must not have to catch');
  });

  test('reports the byte length the instance count implies', () {
    expect(
        ResidentGeometry.byteLengthFor(59875), 59875 * kFloatsPerInstance * 4);
  });
}
