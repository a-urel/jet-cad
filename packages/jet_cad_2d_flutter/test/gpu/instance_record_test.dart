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
      InstanceFieldOffset.halfWidth,
      InstanceFieldOffset.x0,
      InstanceFieldOffset.y0,
      InstanceFieldOffset.x1,
      InstanceFieldOffset.y1,
      InstanceFieldOffset.x2,
      InstanceFieldOffset.y2,
      InstanceFieldOffset.r,
      InstanceFieldOffset.g,
      InstanceFieldOffset.b,
      InstanceFieldOffset.a,
      InstanceFieldOffset.dashPeriod,
      InstanceFieldOffset.dashPhase,
      InstanceFieldOffset.dashFracStart,
      InstanceFieldOffset.dashFracEnd,
    ];
    expect(offsets, List<int>.generate(kFloatsPerInstance, (i) => i),
        reason: 'offsets must be 0..kFloatsPerInstance-1 with no gaps');
  });

  test('the record is sixteen floats and kind_half is adjacent', () {
    expect(kFloatsPerInstance, 16);
    expect(InstanceFieldOffset.halfWidth, InstanceFieldOffset.kind + 1,
        reason: 'the shader reads them as one vec2 attribute, which is what '
            'keeps the attribute count at ES 100\'s floor of eight');
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

  test('a solid stroke writes zero into all four dash slots', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1, y0: 2, x1: 3, y1: 4, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
    expect(into[InstanceFieldOffset.dashPhase], 0.0);
    expect(into[InstanceFieldOffset.dashFracStart], 0.0);
    expect(into[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('a dashed stroke carries its element extent and its phase', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1,
        y0: 2,
        x1: 3,
        y1: 4,
        halfWidth: 0.5,
        argb: 0xFF112233,
        dashPeriod: 18.0,
        dashPhase: 4.0,
        dashFracStart: 0.0,
        dashFracEnd: 12.0 / 18.0);
    expect(into[InstanceFieldOffset.dashPeriod], 18.0);
    expect(into[InstanceFieldOffset.dashPhase], 4.0);
    expect(into[InstanceFieldOffset.dashFracEnd], closeTo(0.6667, 1e-4));
  });

  test(
      'a negative period is preserved bit for bit -- it is the collapse '
      'representative marker, not a magnitude', () {
    final into = Float32List(kFloatsPerInstance);
    writeJoin(into, 0,
        vx: 0,
        vy: 0,
        prevX: -1,
        prevY: 0,
        nextX: 0,
        nextY: 1,
        halfWidth: 1,
        argb: 0xFF000000,
        dashPeriod: -18.0);
    expect(into[InstanceFieldOffset.dashPeriod], -18.0);
    expect(into[InstanceFieldOffset.dashPeriod].isNegative, isTrue);
  });

  test('a point is never dashed', () {
    // `VerticesDrawSink.point` does not consult a linetype, and neither does
    // the painter's point path -- `_emitScreenSpace` returns before
    // `_patternFor` is ever called. `writePoint` therefore takes no dash
    // arguments at all, so a caller cannot express something the reference
    // cannot draw.
    //
    // The dash slots are pre-filled with a plausible dashed record's values
    // before `writePoint` runs -- a fresh `Float32List` is already zero, so
    // asserting zero afterward without this would only prove
    // `Float32List`'s own zero-initialisation, not that `writePoint`
    // actually clears the slots. This reads as "this index used to hold a
    // dashed instance", the case `_writeDash`'s own doc calls out: a record
    // reused across frames, or sliced from a buffer that once held a dashed
    // instance at this index, is not guaranteed to already be zero here.
    final into = Float32List(kFloatsPerInstance);
    into[InstanceFieldOffset.dashPeriod] = 18.0;
    into[InstanceFieldOffset.dashPhase] = 4.0;
    into[InstanceFieldOffset.dashFracStart] = 0.1;
    into[InstanceFieldOffset.dashFracEnd] = 0.6667;
    writePoint(into, 0, x: 1, y: 2, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
    expect(into[InstanceFieldOffset.dashPhase], 0.0);
    expect(into[InstanceFieldOffset.dashFracStart], 0.0);
    expect(into[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('a fill record carries three corners, no width and no dash', () {
    // Pre-filled with garbage so a writer that leaves a slot untouched is
    // caught. A fresh Float32List is all zeros, and most of this record's
    // expected values are zero, so a zero-initialised buffer would let a
    // missing write pass -- the degenerate-fixture trap, at the record
    // level.
    final data = Float32List(kFloatsPerInstance)
      ..fillRange(0, kFloatsPerInstance, 17.5);
    writeFill(data, 0,
        x0: 3.5,
        y0: -4.25,
        x1: 11.0,
        y1: 2.5,
        x2: -6.75,
        y2: 9.5,
        argb: 0x8033CC66);

    expect(data[InstanceFieldOffset.kind], kKindFill);
    expect(data[InstanceFieldOffset.halfWidth], 0.0,
        reason: 'a fill has no width and the shader must not expand it');
    expect(data[InstanceFieldOffset.x0], 3.5);
    expect(data[InstanceFieldOffset.y0], -4.25);
    expect(data[InstanceFieldOffset.x1], 11.0);
    expect(data[InstanceFieldOffset.y1], 2.5);
    expect(data[InstanceFieldOffset.x2], -6.75);
    expect(data[InstanceFieldOffset.y2], 9.5);
    expect(data[InstanceFieldOffset.r], closeTo(0x33 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.g], closeTo(0xCC / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.b], closeTo(0x66 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.dashPeriod], 0.0);
    expect(data[InstanceFieldOffset.dashPhase], 0.0);
    expect(data[InstanceFieldOffset.dashFracStart], 0.0);
    expect(data[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('the four kind tags are distinct and ordered for a < dispatch', () {
    // The shader dispatches `kind < 0.5`, `< 1.5`, `< 2.5`, else. These
    // values are not merely distinct: renumbering them without editing
    // cad_stroke.vert draws one kind as another, silently.
    expect(<double>[kKindStroke, kKindJoin, kKindPoint, kKindFill],
        <double>[0, 1, 2, 3]);
  });

  test('a fill at index 2 writes only its own record', () {
    final data = Float32List(kFloatsPerInstance * 4)
      ..fillRange(0, kFloatsPerInstance * 4, 17.5);
    writeFill(data, 2,
        x0: 1, y0: 2, x1: 3, y1: 4, x2: 5, y2: 6, argb: 0xFF000000);
    expect(data[kFloatsPerInstance * 1], 17.5,
        reason: 'the record before it is untouched');
    expect(data[kFloatsPerInstance * 3], 17.5,
        reason: 'the record after it is untouched');
    expect(data[kFloatsPerInstance * 2 + InstanceFieldOffset.kind], kKindFill);
  });
}
