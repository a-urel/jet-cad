import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The GPU-free half of what was `resident_geometry_test.dart` before the GPU
/// split: `ResidentLayout` is the corner table and the per-record price that
/// left `ResidentGeometry` for this package (spec S3). The GPU half --
/// `create` and `kInstanceVertexLayout` -- moved with `ResidentGeometry` to
/// `jet_cad_2d_gpu/test/resident_geometry_test.dart`.
void main() {
  test('reports the byte length the instance count implies', () {
    // The literal, not the production expression restated: 59875 records *
    // 16 floats/record * 4 bytes/float. Asserting `59875 * kFloatsPerInstance
    // * 4` here would move in lockstep with a broken `kFloatsPerInstance` (a
    // stride mismatch against the shader's 64-byte record) and stay green.
    expect(ResidentLayout.byteLengthFor(59875), 3832000);
  });

  test('the buffer prices sixteen floats', () {
    expect(ResidentLayout.byteLengthFor(1000), 1000 * 16 * 4);
  });

  test('the byte length prices every sub-buffer beside the main buffer', () {
    // 1000 main instances + 37 patch instances, 64 bytes each.
    expect(ResidentLayout.byteLengthFor(1000, patchInstances: 37),
        (1000 + 37) * 64);
  });

  group('kCornerVertices', () {
    test('is six vertices -- two triangles, not a strip', () {
      // The exact list, not just its length: this is the only place this
      // data is reachable without a GPU, so the assertion has to carry the
      // whole thing rather than a derived property a wrong constant could
      // still satisfy.
      expect(ResidentLayout.kCornerVertices, <double>[
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
      expect(ResidentLayout.cornerVertexCount, 6);
      expect(
          ResidentLayout.cornerVertexCount,
          ResidentLayout.kCornerVertices.length ~/
              ResidentLayout.kFloatsPerCorner);
    });

    test('covers exactly four distinct corners', () {
      final points = <(double, double)>{
        for (var i = 0;
            i < ResidentLayout.kCornerVertices.length;
            i += ResidentLayout.kFloatsPerCorner)
          (
            ResidentLayout.kCornerVertices[i],
            ResidentLayout.kCornerVertices[i + 1]
          ),
      };
      expect(points, hasLength(4),
          reason: 'six vertices sharing one diagonal make two triangles of '
              'one quad; four distinct points is what that claim means');
    });

    test('the corner buffer is six vertices of six floats', () {
      expect(ResidentLayout.kCornerVertices.length,
          6 * ResidentLayout.kFloatsPerCorner);
    });

    test('every join weight selects exactly one of the four points', () {
      // A weight vector that summed to anything but 1 would put the vertex
      // somewhere between two roles, which draws a wedge of the wrong shape
      // rather than failing loudly. A weight vector that was all zeroes would
      // collapse it onto the origin.
      for (var v = 0; v < 6; v++) {
        final base = v * ResidentLayout.kFloatsPerCorner + 2;
        final w = ResidentLayout.kCornerVertices.sublist(base, base + 4);
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
        final base = vertex * ResidentLayout.kFloatsPerCorner + 2;
        return ResidentLayout.kCornerVertices
            .sublist(base, base + 4)
            .indexOf(1.0);
      }

      expect(<int>[roleOf(0), roleOf(1), roleOf(2)], <int>[v, a, b]);
      expect(<int>[roleOf(3), roleOf(4), roleOf(5)], <int>[a, m, b]);
    });
  });
}
