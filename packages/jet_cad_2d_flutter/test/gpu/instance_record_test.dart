import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

void main() {
  test('writes a stroke at an offset without touching its neighbours', () {
    final buffer = Float32List(kFloatsPerInstance * 3);
    // Fill so an unwritten field is visible rather than coincidentally zero:
    // a record written into an all-zero buffer passes even if it writes
    // nothing, which is the degenerate fixture this guards.
    buffer.fillRange(0, buffer.length, -1);

    writeStroke(buffer, 1,
        x0: 3, y0: 4, x1: 5, y1: 6, halfWidth: 0.75, argb: 0x80402010);

    expect(buffer.sublist(0, kFloatsPerInstance), everyElement(-1.0),
        reason: 'record 0 must be untouched');
    expect(buffer.sublist(kFloatsPerInstance * 2), everyElement(-1.0),
        reason: 'record 2 must be untouched');

    final r = buffer.sublist(kFloatsPerInstance, kFloatsPerInstance * 2);
    expect(r[0], kKindStroke);
    expect(r.sublist(1, 5), [3.0, 4.0, 5.0, 6.0]);
    expect(r[5], 0.75);
    // 0x80402010 -> a=0x80, r=0x40, g=0x20, b=0x10
    expect(r[6], closeTo(0x40 / 255, 1e-6));
    expect(r[7], closeTo(0x20 / 255, 1e-6));
    expect(r[8], closeTo(0x10 / 255, 1e-6));
    expect(r[9], closeTo(0x80 / 255, 1e-6));
  });
}
