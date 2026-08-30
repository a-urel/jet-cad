import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

void main() {
  test('the field offsets are contiguous and cover the stride', () {
    // The offsets are read by three independent consumers -- the writers
    // below, `ResidentGeometry.kInstanceVertexLayout`, and (as a fourth,
    // uncheckable copy) `cad_stroke.vert`'s attribute list. A gap or an
    // overlap here is silent on every one of them until a device run.
    const offsets = <int>[
      InstanceFieldOffset.kind,
      InstanceFieldOffset.x0,
      InstanceFieldOffset.y0,
      InstanceFieldOffset.x1,
      InstanceFieldOffset.y1,
      InstanceFieldOffset.x2,
      InstanceFieldOffset.y2,
      InstanceFieldOffset.halfWidth,
      InstanceFieldOffset.r,
      InstanceFieldOffset.g,
      InstanceFieldOffset.b,
      InstanceFieldOffset.a,
    ];
    expect(offsets, List<int>.generate(kFloatsPerInstance, (i) => i),
        reason: 'offsets must be 0..kFloatsPerInstance-1 with no gaps');
  });

  test('the three kind tags are distinct and ordered for the shader', () {
    // `cad_stroke.vert` dispatches with `kind < 0.5` then `kind < 1.5`, so
    // the tags must be 0, 1, 2 in that order -- not merely distinct.
    expect(kKindStroke, 0.0);
    expect(kKindJoin, 1.0);
    expect(kKindPoint, 2.0);
  });

  test('writeStroke fills every slot and leaves p2 zeroed', () {
    final b = Float32List(kFloatsPerInstance * 2);
    // Index 1, not 0: writing at a non-zero index is the only way to catch a
    // writer that ignores its `index` argument, and the zero-fill of a fresh
    // Float32List would hide it at index 0.
    writeStroke(b, 1,
        x0: 3, y0: -4, x1: 11, y1: 6, halfWidth: 1.25, argb: 0x80402010);
    final r = b.sublist(kFloatsPerInstance);
    expect(r[InstanceFieldOffset.kind], kKindStroke);
    expect(r[InstanceFieldOffset.x0], 3);
    expect(r[InstanceFieldOffset.y0], -4);
    expect(r[InstanceFieldOffset.x1], 11);
    expect(r[InstanceFieldOffset.y1], 6);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
    expect(r[InstanceFieldOffset.halfWidth], 1.25);
    expect(r[InstanceFieldOffset.r], closeTo(0x40 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.g], closeTo(0x20 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.b], closeTo(0x10 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    // The first record is untouched: a writer that ignored `index` would
    // have written here instead.
    expect(b.sublist(0, kFloatsPerInstance).every((v) => v == 0), isTrue);
  });

  test('writeJoin puts the vertex first and the neighbours after it', () {
    // Order matters and is not symmetric: the shader takes the incoming
    // direction as `p0 - p1` and the outgoing as `p2 - p0`. Swapping p1 and
    // p2 reverses the turn and mirrors the wedge onto the wrong side.
    final b = Float32List(kFloatsPerInstance);
    writeJoin(b, 0,
        vx: 10,
        vy: 20,
        prevX: 4,
        prevY: 20,
        nextX: 10,
        nextY: 33,
        halfWidth: 2,
        argb: 0xFF010203);
    expect(b[InstanceFieldOffset.kind], kKindJoin);
    expect(b[InstanceFieldOffset.x0], 10);
    expect(b[InstanceFieldOffset.y0], 20);
    expect(b[InstanceFieldOffset.x1], 4);
    expect(b[InstanceFieldOffset.y1], 20);
    expect(b[InstanceFieldOffset.x2], 10);
    expect(b[InstanceFieldOffset.y2], 33);
    expect(b[InstanceFieldOffset.halfWidth], 2);
  });

  test('writePoint carries one position and zeroes the unused slots', () {
    final b = Float32List(kFloatsPerInstance);
    writePoint(b, 0, x: -7, y: 2.5, halfWidth: 0.5, argb: 0xFFFFFFFF);
    expect(b[InstanceFieldOffset.kind], kKindPoint);
    expect(b[InstanceFieldOffset.x0], -7);
    expect(b[InstanceFieldOffset.y0], 2.5);
    expect(b[InstanceFieldOffset.x1], 0);
    expect(b[InstanceFieldOffset.y1], 0);
    expect(b[InstanceFieldOffset.x2], 0);
    expect(b[InstanceFieldOffset.y2], 0);
    expect(b[InstanceFieldOffset.halfWidth], 0.5);
  });
}
