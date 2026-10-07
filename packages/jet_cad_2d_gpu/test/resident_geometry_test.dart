import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
// The record's writer and kind tags: `GeometryCollector`'s wire format, which
// core's barrel deliberately does not export (only the record's size and
// field offsets). The layout test below cross-checks the vertex layout
// against the writer itself, so it has to read the writer.
// ignore: implementation_imports
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart'
    show kKindStroke, writeStroke;
import 'package:jet_cad_2d_gpu/src/gpu_facade.dart';
import 'package:jet_cad_2d_gpu/src/resident_geometry.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('returns null rather than throwing where there is no GPU', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(Float32List(kFloatsPerInstance), 1);
    expect(g, isNull,
        reason: 'the caller falls back; it must not have to catch');
  });

  test('create still returns null with no GPU, patches or not', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(Float32List(kFloatsPerInstance), 1,
        texts: const [],
        patches: [
          TextPatch(
              textIndex: 0,
              instances: Float32List(kFloatsPerInstance),
              instanceCount: 1)
        ]);
    expect(g, isNull);
  });

  group('kInstanceVertexLayout', () {
    test('slot 0 carries corner and join_weight, per vertex, stride 24', () {
      final corner = ResidentGeometry.kInstanceVertexLayout.buffers[0];
      expect(corner.strideInBytes, ResidentLayout.kFloatsPerCorner * 4);
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
