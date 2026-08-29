import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_draw_backend.dart';

void main() {
  group('buildFrameInfo', () {
    test(
        'maps a device-space transform to NDC with y flipped, every float '
        'load-bearing', () {
      // 200x100 device pixels -- asymmetric on purpose, so a swapped width
      // and height shows up as a wrong half-viewport rather than cancelling
      // out. `collectionToDevice` uses six distinct, nonzero terms -- not
      // `Transform2.identity()` -- so every one of `a, b, c, d, e, f` is
      // load-bearing: with an identity fixture `b == c == 0` and the two
      // off-diagonal outputs (`at(1)`, `at(4)`) would read zero whether the
      // code multiplies the right term or not, which is exactly the
      // diagonal-matrix trap this codebase's own Task 3 fell into once
      // (`vertices_draw_sink.dart:41-57`'s sibling defect, one plan earlier).
      final collectionToDevice = Transform2(2, 3, 5, 7, 11, 13);
      final data = buildFrameInfo(collectionToDevice, 200, 100);
      double at(int i) => data.getFloat32(i * 4, Endian.host);

      // sx = 2/200 = 0.01, sy = -2/100 = -0.02.
      // Column-major mat4; float32 round-trip error at these magnitudes is
      // under 1e-7, so 1e-6 both clears that noise and is far tighter than
      // any of these mutations' effect (a dropped negation or a swapped term
      // changes the result by 100%, not by parts in a million).
      expect(at(0), closeTo(2 * 0.01, 1e-6), reason: 'a * sx');
      expect(at(1), closeTo(3 * -0.02, 1e-6),
          reason: 'b * sy -- zero under an identity fixture, so only a '
              'non-diagonal collectionToDevice exercises it');
      expect(at(4), closeTo(5 * 0.01, 1e-6),
          reason: 'c * sx -- same trap as at(1), the other off-diagonal term');
      expect(at(5), closeTo(7 * -0.02, 1e-6),
          reason: 'd * sy -- the y-scale row; negating sy here is the named '
              'mutation for this task');
      expect(at(12), closeTo(11 * 0.01 - 1, 1e-6), reason: 'e * sx - 1');
      expect(at(13), closeTo(13 * -0.02 + 1, 1e-6), reason: 'f * sy + 1');
      expect(at(16), closeTo(100, 1e-6), reason: 'half viewport x');
      expect(at(17), closeTo(50, 1e-6), reason: 'half viewport y');

      // The structural zeros and ones -- unaffected by the fixture's
      // transform terms, but not unimportant: `at(15)` is the homogeneous
      // `w` of the matrix's last column. A typo turning that `1` into a `0`
      // makes every `gl_Position.w` zero -- a whole frame of nothing -- and
      // nothing else in this test would notice, since none of the six
      // transform-derived assertions above touch row/column 15.
      expect(at(2), 0);
      expect(at(3), 0);
      expect(at(6), 0);
      expect(at(7), 0);
      expect(at(8), 0);
      expect(at(9), 0);
      expect(at(10), 1);
      expect(at(11), 0);
      expect(at(14), 0);
      expect(at(15), 1, reason: 'homogeneous w -- see comment above');
      expect(at(18), 0);
      expect(at(19), 0);
    });

    test(
        'a dpr fold survives composeTransforms + Transform2.scale, not just '
        'buildFrameInfo alone', () {
      // `buildFrameInfo` itself takes no `dpr` -- `GpuDrawBackend.render`
      // folds it in beforehand by composing the logical-space transform with
      // `Transform2.scale(dpr, dpr)` before calling this function. A fixture
      // at `dpr == 1` (the test above) cannot tell a correct fold from a
      // dropped one apart, because `Transform2.scale(1, 1)` is the identity
      // and a dropped fold is indistinguishable from an applied no-op one.
      // This test picks `dpr == 2` and builds its device-space input the
      // same way `render` does, so a broken fold -- wrong composition order,
      // `Transform2.scale` given the wrong axes, or the fold skipped
      // entirely -- moves these numbers away from what is asserted below.
      const dpr = 2.0;
      const logicalWidth = 200.0;
      const logicalHeight = 100.0;
      final widthPx = (logicalWidth * dpr).round(); // 400
      final heightPx = (logicalHeight * dpr).round(); // 200

      // The same logical-space fixture as the test above -- six distinct,
      // nonzero terms, still in the collection camera's logical screen space
      // (what `composeTransforms(camera.worldToScreenMatrix,
      // _collectionInverse)` would produce in `render`).
      final logicalTransform = Transform2(2, 3, 5, 7, 11, 13);

      // `render`'s exact recipe: fold `dpr` in as the outermost transform.
      final collectionToDevice =
          composeTransforms(Transform2.scale(dpr, dpr), logicalTransform);

      // Composing with a uniform `Transform2.scale(dpr, dpr)` as the outer
      // transform multiplies every one of the inner transform's six terms by
      // `dpr` (worked by hand: `Transform2.scale`'s own `b` and `c` are 0, so
      // every cross term in `composeTransforms`'s formula drops out and only
      // the `dpr * term` product survives) -- so `collectionToDevice` here is
      // `Transform2(4, 6, 10, 14, 22, 26)`.
      expect(collectionToDevice.a, 4);
      expect(collectionToDevice.b, 6);
      expect(collectionToDevice.c, 10);
      expect(collectionToDevice.d, 14);
      expect(collectionToDevice.e, 22);
      expect(collectionToDevice.f, 26);

      final data = buildFrameInfo(collectionToDevice, widthPx, heightPx);
      double at(int i) => data.getFloat32(i * 4, Endian.host);

      // sx = 2/400 = 0.005, sy = -2/200 = -0.01.
      //
      // These NDC-scale/translate numbers are numerically identical to the
      // dpr == 1 test above (0.02, -0.06, 0.05, -0.14, -0.89, 0.74) -- not a
      // copy/paste mistake, but the correct physics of it: for a fixed
      // logical viewport, the NDC mapping of a logical point does not depend
      // on dpr (device pixels cancel: `dpr * term` over `widthPx == logical
      // * dpr` leaves `term` over `logical`, the same ratio regardless of
      // dpr). What *does* depend on dpr -- and is the direct fingerprint of
      // the fold actually reaching `widthPx`/`heightPx` -- is `half_viewport`
      // below: `200, 100` here against `100, 50` in the dpr == 1 test, exactly
      // doubled.
      //
      // What a *dropped* fold would produce, for contrast (not asserted,
      // worked by hand to show this fixture is discriminating): calling
      // `buildFrameInfo(logicalTransform, widthPx, heightPx)` directly --
      // i.e. forgetting `Transform2.scale(dpr, dpr)` -- gives `sx = 2/400 =
      // 0.005` against the *unscaled* `a = 2`, so `at(0) = 2 * 0.005 = 0.01`,
      // not the `0.02` asserted below. Every other transform-derived term
      // shifts the same way.
      expect(at(0), closeTo(4 * 0.005, 1e-6), reason: 'a * sx, dpr folded in');
      expect(at(1), closeTo(6 * -0.01, 1e-6), reason: 'b * sy, dpr folded in');
      expect(at(4), closeTo(10 * 0.005, 1e-6), reason: 'c * sx, dpr folded in');
      expect(at(5), closeTo(14 * -0.01, 1e-6), reason: 'd * sy, dpr folded in');
      expect(at(12), closeTo(22 * 0.005 - 1, 1e-6),
          reason: 'e * sx - 1, dpr folded in');
      expect(at(13), closeTo(26 * -0.01 + 1, 1e-6),
          reason: 'f * sy + 1, dpr folded in');
      expect(at(16), closeTo(200, 1e-6),
          reason: 'half viewport x -- device pixels, doubled from the '
              'dpr == 1 test');
      expect(at(17), closeTo(100, 1e-6),
          reason: 'half viewport y -- device pixels, doubled from the '
              'dpr == 1 test');
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

      // Hand-computed against the documented `outer ∘ inner` contract, not
      // read back by calling `Transform2.multiply` directly and comparing --
      // `composeTransforms` delegates to `multiply`, so this pins the
      // delegation's argument order (`outer` as the receiver, `inner` as the
      // argument) rather than merely restating it: swapping to
      // `inner.multiply(outer)` would still compile and still read
      // plausibly, but composes in the opposite order and would move every
      // one of these six numbers.
      expect(result.a, 2 * 17 + 5 * 19); // 129
      expect(result.b, 3 * 17 + 7 * 19); // 184
      expect(result.c, 2 * 23 + 5 * 29); // 191
      expect(result.d, 3 * 23 + 7 * 29); // 272
      expect(result.e, 2 * 31 + 5 * 37 + 11); // 258
      expect(result.f, 3 * 31 + 7 * 37 + 13); // 365
    });
  });
}
