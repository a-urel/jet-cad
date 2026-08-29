import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_draw_backend.dart';

void main() {
  group('buildFrameInfo', () {
    test(
        'maps screen space to NDC with y flipped, every matrix term load-'
        'bearing', () {
      // 200x100 device pixels -- asymmetric on purpose, so a swapped width
      // and height shows up as a wrong half-viewport rather than cancelling
      // out. `collectionToScreen` uses six distinct, nonzero terms -- not
      // `Transform2.identity()` -- so every one of `a, b, c, d, e, f` is
      // load-bearing: with an identity fixture `b == c == 0` and the two
      // off-diagonal outputs (`at(1)`, `at(4)`) would read zero whether the
      // code multiplies the right term or not, which is exactly the
      // diagonal-matrix trap this codebase's own Task 3 fell into once
      // (`vertices_draw_sink.dart:41-57`'s sibling defect, one plan earlier).
      final collectionToScreen = Transform2(2, 3, 5, 7, 11, 13);
      final data = buildFrameInfo(collectionToScreen, 200, 100);
      double at(int i) => data.getFloat32(i * 4, Endian.host);

      // sx = 2/200 = 0.01, sy = -2/100 = -0.02.
      // Column-major mat4; float32 round-trip error at these magnitudes is
      // under 1e-7, so 1e-6 both clears that noise and is far tighter than
      // any of these mutations' effect (a dropped negation or a swapped term
      // changes the result by 100%, not by parts in a million).
      expect(at(0), closeTo(2 * 0.01, 1e-6), reason: 'a * sx');
      expect(at(1), closeTo(3 * -0.02, 1e-6),
          reason: 'b * sy -- zero under an identity fixture, so only a '
              'non-diagonal collectionToScreen exercises it');
      expect(at(4), closeTo(5 * 0.01, 1e-6),
          reason: 'c * sx -- same trap as at(1), the other off-diagonal term');
      expect(at(5), closeTo(7 * -0.02, 1e-6),
          reason: 'd * sy -- the y-scale row; negating sy here is the named '
              'mutation for this task');
      expect(at(12), closeTo(11 * 0.01 - 1, 1e-6), reason: 'e * sx - 1');
      expect(at(13), closeTo(13 * -0.02 + 1, 1e-6), reason: 'f * sy + 1');
      expect(at(16), closeTo(100, 1e-6), reason: 'half viewport x');
      expect(at(17), closeTo(50, 1e-6), reason: 'half viewport y');
    });
  });

  group('composeTransforms', () {
    test('outer ∘ inner, every term of both operands load-bearing', () {
      // Six distinct primes on each side: a shared value anywhere would let
      // a transposed pair of terms (e.g. b and c swapped) compute the same
      // wrong answer as the right one and pass by accident.
      const outer = Transform2(2, 3, 5, 7, 11, 13);
      const inner = Transform2(17, 19, 23, 29, 31, 37);

      final result = composeTransforms(outer, inner);

      // Hand-computed, not read back from `Transform2.multiply` -- this is
      // an independent implementation of the same formula, and comparing it
      // against the method it duplicates would not catch a shared mistake.
      expect(result.a, 2 * 17 + 5 * 19); // 129
      expect(result.b, 3 * 17 + 7 * 19); // 184
      expect(result.c, 2 * 23 + 5 * 29); // 191
      expect(result.d, 3 * 23 + 7 * 29); // 272
      expect(result.e, 2 * 31 + 5 * 37 + 11); // 258
      expect(result.f, 3 * 31 + 7 * 37 + 13); // 365
    });
  });
}
