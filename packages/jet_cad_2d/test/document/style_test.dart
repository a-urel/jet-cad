import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('DraftColor encoding', () {
    test('round-trips every variant', () {
      const colors = <DraftColor>[
        ByLayerColor(),
        ByBlockColor(),
        IndexedColor(1),
        IndexedColor(255),
        TrueColor(0x000000),
        TrueColor(0xFF8800),
        TrueColor(0xFFFFFF),
      ];
      for (final c in colors) {
        expect(decodeColor(encodeColor(c)), c, reason: '$c');
      }
    });

    test('sentinels are the shared negative constants', () {
      expect(encodeColor(const ByLayerColor()), kByLayer);
      expect(encodeColor(const ByBlockColor()), kByBlock);
    });

    test('indexed and true colour never collide', () {
      // Indexed ACI is 1..255. A true colour of 0x0000FF must not decode as
      // ACI 255, which is what a naive untagged encoding would do.
      expect(decodeColor(encodeColor(const TrueColor(0x0000FF))),
          const TrueColor(0x0000FF));
      expect(decodeColor(encodeColor(const IndexedColor(255))),
          const IndexedColor(255));
      expect(encodeColor(const TrueColor(0x0000FF)),
          isNot(encodeColor(const IndexedColor(255))));
    });

    test('rejects an out-of-range ACI', () {
      expect(() => encodeColor(const IndexedColor(0)), throwsArgumentError);
      expect(() => encodeColor(const IndexedColor(256)), throwsArgumentError);
    });

    test('rejects an rgb value outside 24 bits', () {
      expect(
          () => encodeColor(const TrueColor(0x1000000)), throwsArgumentError);
      expect(() => encodeColor(const TrueColor(-1)), throwsArgumentError);
    });

    test('colours are value-equal so they can be compared in tests and undo',
        () {
      expect(const TrueColor(0x123456), const TrueColor(0x123456));
      expect(const IndexedColor(7).hashCode, const IndexedColor(7).hashCode);
      expect(const ByLayerColor(), isNot(const ByBlockColor()));
    });

    test('an unknown encoding is rejected rather than silently defaulted', () {
      expect(() => decodeColor(-99), throwsArgumentError);
    });
  });

  group('ReservedHandles', () {
    test('are distinct, non-none, and below firstFree', () {
      const reserved = <Handle>[
        ReservedHandles.layerZero,
        ReservedHandles.byLayerLinetype,
        ReservedHandles.byBlockLinetype,
        ReservedHandles.continuousLinetype,
        ReservedHandles.standardTextStyle,
      ];
      expect(reserved.toSet().length, reserved.length);
      for (final h in reserved) {
        expect(h.isNone, isFalse);
        expect(h.value, lessThan(ReservedHandles.firstFree.value));
      }
    });
  });

  test('EntityFlags.invisible is a single bit', () {
    expect(EntityFlags.invisible, 1);
    expect(0 | EntityFlags.invisible, 1);
  });
}
