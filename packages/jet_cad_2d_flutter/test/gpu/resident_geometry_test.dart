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
    // The literal, not the production expression restated: 59875 records *
    // 16 floats/record * 4 bytes/float. Asserting `59875 * kFloatsPerInstance
    // * 4` here would move in lockstep with a broken `kFloatsPerInstance` (a
    // stride mismatch against the shader's 64-byte record) and stay green.
    expect(ResidentGeometry.byteLengthFor(59875), 3832000);
  });

  test('the buffer prices sixteen floats', () {
    expect(ResidentGeometry.byteLengthFor(1000), 1000 * 16 * 4);
  });

  group('kCornerVertices', () {
    test('is six vertices -- two triangles, not a strip', () {
      // The exact list, not just its length: this is the only place this
      // data is reachable without a GPU, so the assertion has to carry the
      // whole thing rather than a derived property a wrong constant could
      // still satisfy.
      expect(ResidentGeometry.kCornerVertices, <double>[
        0, -1, 1, 0, 0, 0, //
        0, 1, 0, 1, 0, 0, //
        1, -1, 0, 0, 1, 0, //
        1, -1, 0, 1, 0, 0, //
        0, 1, 0, 0, 0, 1, //
        1, 1, 0, 0, 1, 0, //
      ]);
    });

    test('cornerVertexCount is derived from the table, and equals six', () {
      // **Pins the relationship, not just today's value.** The second
      // assertion is the load-bearing one: it says `cornerVertexCount` IS
      // the table's length over its stride, so the draw call at
      // `GpuDrawBackend.render` cannot drift from the buffer it draws
      // from. Before `cornerVertexCount` existed, `pass.draw(6, ...)` was
      // a bare literal and a seventh corner vertex would have drawn 6 of 7
      // -- green in this whole package, visible only on a device.
      //
      // A seventh corner now goes red HERE, on the first assertion, as
      // "6 -> 7" -- and red in the literal-list test above as well, which
      // asserts the full 36-element table rather than a length. Two
      // independent alarms, which is the point: the list test catches a
      // wrong VALUE, this one catches a broken RELATIONSHIP, and only the
      // second would survive someone updating the list and forgetting the
      // draw call.
      expect(ResidentGeometry.cornerVertexCount, 6);
      expect(
          ResidentGeometry.cornerVertexCount,
          ResidentGeometry.kCornerVertices.length ~/
              ResidentGeometry.kFloatsPerCorner);
    });

    test('covers exactly four distinct corners', () {
      final points = <(double, double)>{
        for (var i = 0;
            i < ResidentGeometry.kCornerVertices.length;
            i += ResidentGeometry.kFloatsPerCorner)
          (
            ResidentGeometry.kCornerVertices[i],
            ResidentGeometry.kCornerVertices[i + 1]
          ),
      };
      expect(points, hasLength(4),
          reason: 'six vertices sharing one diagonal make two triangles of '
              'one quad; four distinct points is what that claim means');
    });

    test('the corner buffer is six vertices of six floats', () {
      expect(ResidentGeometry.kCornerVertices.length,
          6 * ResidentGeometry.kFloatsPerCorner);
    });

    test('every join weight selects exactly one of the four points', () {
      // A weight vector that summed to anything but 1 would put the vertex
      // somewhere between two roles, which draws a wedge of the wrong shape
      // rather than failing loudly. A weight vector that was all zeroes would
      // collapse it onto the origin.
      for (var v = 0; v < 6; v++) {
        final base = v * ResidentGeometry.kFloatsPerCorner + 2;
        final w = ResidentGeometry.kCornerVertices.sublist(base, base + 4);
        expect(w.reduce((a, b) => a + b), 1.0, reason: 'vertex $v weights $w');
        expect(w.where((x) => x == 1.0).length, 1,
            reason: 'vertex $v weights $w');
      }
    });

    test('the two join triangles are (V, A, B) and (A, M, B)', () {
      // Named so a reordering of kCornerVertices is a test failure with the
      // role in the message, not a silently different wedge.
      const v = 0, a = 1, b = 2, m = 3;
      int roleOf(int vertex) {
        final base = vertex * ResidentGeometry.kFloatsPerCorner + 2;
        return ResidentGeometry.kCornerVertices
            .sublist(base, base + 4)
            .indexOf(1.0);
      }

      expect(<int>[roleOf(0), roleOf(1), roleOf(2)], <int>[v, a, b]);
      expect(<int>[roleOf(3), roleOf(4), roleOf(5)], <int>[a, m, b]);
    });
  });

  group('kInstanceVertexLayout', () {
    test('slot 0 carries corner and join_weight, per vertex, stride 24', () {
      final corner = ResidentGeometry.kInstanceVertexLayout.buffers[0];
      expect(corner.strideInBytes, ResidentGeometry.kFloatsPerCorner * 4);
      expect(corner.stepMode, VertexStepMode.vertex);
      expect(corner.attributes, hasLength(2));
      final byName = {
        for (final a in corner.attributes) a.name: a.offsetInBytes,
      };
      expect(byName, {'corner': 0, 'join_weight': 8});
    });

    test(
        'the vertex layout declares eight attributes, which is the ES 100 '
        'floor the shader header claims', () {
      final attributes = ResidentGeometry.kInstanceVertexLayout.buffers
          .expand((b) => b.attributes)
          .toList();
      expect(attributes, hasLength(8),
          reason: 'gl_MaxVertexAttribs is guaranteed to be at least 8 and no '
              'more; a ninth binds on every platform this project runs on '
              'today and falsifies the header');
      expect(
          attributes.map((a) => a.name),
          containsAll(<String>[
            'corner',
            'join_weight',
            'kind_half',
            'p0',
            'p1',
            'p2',
            'color',
            'dash',
          ]));
    });

    test(
        'slot 1 carries the instance record at the record\'s own offsets, '
        'per instance, stride 64', () {
      final instance = ResidentGeometry.kInstanceVertexLayout.buffers[1];
      // Stride: kFloatsPerInstance * 4. A wrong stride here disagrees with
      // instance_record.dart's own 16-float layout silently, since nothing
      // in the shader bundle enforces it from the Dart side.
      expect(instance.strideInBytes, kFloatsPerInstance * 4);
      expect(instance.stepMode, VertexStepMode.instance);

      // Offsets are the record's own -- [kind, halfWidth, x0, y0, x1, y1,
      // x2, y2, r, g, b, a, dashPeriod, dashPhase, dashFracStart,
      // dashFracEnd] -- not impellerc's single-combined-buffer reflection,
      // which describes a layout this code does not use, and which still
      // describes the pre-Plan-C shader in any case.
      final offsetsByName = {
        for (final a in instance.attributes) a.name: a.offsetInBytes,
      };
      expect(offsetsByName, {
        'kind_half': 0,
        'p0': 8,
        'p1': 16,
        'p2': 24,
        'color': 32,
        'dash': 48,
      });
    });

    test('every instance attribute offset is derived from InstanceFieldOffset',
        () {
      final instanceBuffer = ResidentGeometry.kInstanceVertexLayout.buffers[1];
      expect(instanceBuffer.strideInBytes, kFloatsPerInstance * 4);
      expect(
          instanceBuffer.attributes
              .firstWhere((a) => a.name == 'dash')
              .offsetInBytes,
          InstanceFieldOffset.dashPeriod * 4);
    });

    test(
        'writeStroke and the vertex layout agree on where every field '
        'lands -- a derivation, not a restatement', () {
      // Distinct values in every slot, so a field landing at the wrong
      // offset reads a value that belongs to a different field rather than
      // coincidentally matching (a fixture at 0.0 or a repeated value would
      // hide exactly that mistake). writeStroke packs colour from `argb`
      // (0xAARRGGBB); picking one byte per channel keeps every colour slot
      // distinct too.
      final record = Float32List(kFloatsPerInstance);
      writeStroke(record, 0,
          x0: 11.0,
          y0: 22.0,
          x1: 33.0,
          y1: 44.0,
          halfWidth: 5.5,
          argb: 0x8060A0C0,
          dashPeriod: 9.0,
          dashPhase: 1.5,
          dashFracStart: 0.25,
          dashFracEnd: 0.75);
      final bytes = ByteData.sublistView(record);

      // Read every field back through kInstanceVertexLayout's own attribute
      // offsets, never through InstanceFieldOffset's float indices directly
      // -- that would only prove the layout agrees with itself. This is the
      // cross-check the plain offset map above cannot make: it fails if
      // *either* writeStroke's write order or kInstanceVertexLayout's
      // attribute offsets move without the other, because both are read
      // through the one path a real upload would use.
      final instance = ResidentGeometry.kInstanceVertexLayout.buffers[1];
      double byName(String name, int floatIndexWithinAttribute) {
        final attr = instance.attributes.singleWhere((a) => a.name == name);
        return bytes.getFloat32(
            attr.offsetInBytes + floatIndexWithinAttribute * 4, Endian.host);
      }

      expect(byName('kind_half', 0), kKindStroke);
      expect(byName('kind_half', 1), 5.5, reason: 'halfWidth');
      expect(byName('p0', 0), 11.0, reason: 'x0');
      expect(byName('p0', 1), 22.0, reason: 'y0');
      expect(byName('p1', 0), 33.0, reason: 'x1');
      expect(byName('p1', 1), 44.0, reason: 'y1');
      expect(byName('p2', 0), 0.0, reason: 'x2, unused by a stroke');
      expect(byName('p2', 1), 0.0, reason: 'y2, unused by a stroke');
      expect(byName('color', 0), closeTo(0x60 / 255.0, 1e-6), reason: 'r');
      expect(byName('color', 1), closeTo(0xA0 / 255.0, 1e-6), reason: 'g');
      expect(byName('color', 2), closeTo(0xC0 / 255.0, 1e-6), reason: 'b');
      expect(byName('color', 3), closeTo(0x80 / 255.0, 1e-6), reason: 'a');
      expect(byName('dash', 0), 9.0, reason: 'dashPeriod');
      expect(byName('dash', 1), 1.5, reason: 'dashPhase');
      expect(byName('dash', 2), 0.25, reason: 'dashFracStart');
      expect(byName('dash', 3), 0.75, reason: 'dashFracEnd');
    });
  });
}
