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
    // 10 floats/record * 4 bytes/float. Asserting `59875 * kFloatsPerInstance
    // * 4` here would move in lockstep with a broken `kFloatsPerInstance` (a
    // stride mismatch against the shader's 40-byte record) and stay green.
    expect(ResidentGeometry.byteLengthFor(59875), 2395000);
  });

  group('kCornerVertices', () {
    test('is six vertices -- two triangles, not a strip', () {
      // The exact list, not just its length: this is the only place this
      // data is reachable without a GPU, so the assertion has to carry the
      // whole thing rather than a derived property a wrong constant could
      // still satisfy.
      expect(ResidentGeometry.kCornerVertices, <double>[
        0, -1, 0, 1, 1, -1, //
        1, -1, 0, 1, 1, 1, //
      ]);
    });

    test('covers exactly four distinct corners', () {
      final points = <(double, double)>{
        for (var i = 0; i < ResidentGeometry.kCornerVertices.length; i += 2)
          (
            ResidentGeometry.kCornerVertices[i],
            ResidentGeometry.kCornerVertices[i + 1]
          ),
      };
      expect(points, hasLength(4),
          reason: 'six vertices sharing one diagonal make two triangles of '
              'one quad; four distinct points is what that claim means');
    });
  });

  group('kStrokeVertexLayout', () {
    test('slot 0 carries corner, per vertex, stride 8', () {
      final corner = ResidentGeometry.kStrokeVertexLayout.buffers[0];
      expect(corner.strideInBytes, 8);
      expect(corner.stepMode, VertexStepMode.vertex);
      expect(corner.attributes, hasLength(1));
      expect(corner.attributes.single.name, 'corner');
      expect(corner.attributes.single.offsetInBytes, 0);
    });

    test(
        'slot 1 carries the instance record at the record\'s own offsets, '
        'per instance, stride 40', () {
      final instance = ResidentGeometry.kStrokeVertexLayout.buffers[1];
      // Stride: kFloatsPerInstance * 4. A wrong stride here disagrees with
      // instance_record.dart's own 10-float layout silently, since nothing
      // in the shader bundle enforces it from the Dart side.
      expect(instance.strideInBytes, kFloatsPerInstance * 4);
      expect(instance.stepMode, VertexStepMode.instance);

      // Offsets are the record's own -- [kind, x0, y0, x1, y1, halfWidth, r,
      // g, b, a] -- not impellerc's single-combined-buffer reflection
      // (corner@0, kind@8, p0@12, p1@20, half_width@28, color@32), which
      // describes a layout this code does not use.
      final offsetsByName = {
        for (final a in instance.attributes) a.name: a.offsetInBytes,
      };
      expect(offsetsByName, {
        'kind': 0,
        'p0': 4,
        'p1': 12,
        'half_width': 20,
        'color': 24,
      });
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
          argb: 0x8060A0C0);
      final bytes = ByteData.sublistView(record);

      // Read every field back through kStrokeVertexLayout's own attribute
      // offsets, never through StrokeFieldOffset's float indices directly --
      // that would only prove the layout agrees with itself. This is the
      // cross-check the plain offset map above cannot make: it fails if
      // *either* writeStroke's write order or kStrokeVertexLayout's
      // attribute offsets move without the other, because both are read
      // through the one path a real upload would use.
      final instance = ResidentGeometry.kStrokeVertexLayout.buffers[1];
      double byName(String name, int floatIndexWithinAttribute) {
        final attr = instance.attributes.singleWhere((a) => a.name == name);
        return bytes.getFloat32(
            attr.offsetInBytes + floatIndexWithinAttribute * 4, Endian.host);
      }

      expect(byName('kind', 0), kKindStroke);
      expect(byName('p0', 0), 11.0, reason: 'x0');
      expect(byName('p0', 1), 22.0, reason: 'y0');
      expect(byName('p1', 0), 33.0, reason: 'x1');
      expect(byName('p1', 1), 44.0, reason: 'y1');
      expect(byName('half_width', 0), 5.5);
      expect(byName('color', 0), closeTo(0x60 / 255.0, 1e-6), reason: 'r');
      expect(byName('color', 1), closeTo(0xA0 / 255.0, 1e-6), reason: 'g');
      expect(byName('color', 2), closeTo(0xC0 / 255.0, 1e-6), reason: 'b');
      expect(byName('color', 3), closeTo(0x80 / 255.0, 1e-6), reason: 'a');
    });
  });
}
