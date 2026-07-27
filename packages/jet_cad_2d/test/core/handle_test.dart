import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  group('Handle', () {
    test('none is zero and reports isNone', () {
      expect(Handle.none.value, 0);
      expect(Handle.none.isNone, isTrue);
      expect(const Handle(1).isNone, isFalse);
    });

    test('hex round-trips in the DXF uppercase form', () {
      expect(const Handle(0x1A).toHex(), '1A');
      expect(const Handle(0xFFFFFFFF).toHex(), 'FFFFFFFF');
      expect(Handle.parseHex('1a'), const Handle(0x1A));
      expect(Handle.parseHex('FFFFFFFF'), const Handle(0xFFFFFFFF));
    });

    test('rejects values above the 32-bit ceiling', () {
      // The ceiling is a document invariant, not a web quirk: entity columns
      // are Uint32List on every platform.
      expect(() => Handle.parseHex('100000000'), throwsA(isA<HandleRangeError>()));
      expect(() => Handle.checked(kMaxHandle + 1), throwsA(isA<HandleRangeError>()));
      expect(Handle.checked(kMaxHandle), const Handle(kMaxHandle));
    });

    test('rejects negative values', () {
      expect(() => Handle.checked(-1), throwsA(isA<HandleRangeError>()));
    });

    test('fromJson wraps a bare int, because the extension type is erased', () {
      // A JSON decoder hands back `int`. Handle and int are the same type at
      // runtime, so the wrap has to be explicit at the boundary.
      expect(Handle.fromJson(26), const Handle(26));
      expect(const Handle(26).toJson(), 26);
      expect(() => Handle.fromJson('26'), throwsA(isA<HandleRangeError>()));
    });
  });

  group('HandleSeed', () {
    test('allocates monotonically from one', () {
      final seed = HandleSeed();
      expect(seed.next(), const Handle(1));
      expect(seed.next(), const Handle(2));
      expect(seed.current, const Handle(2));
    });

    test('raiseTo moves the seed forward but never backward', () {
      final seed = HandleSeed()..raiseTo(const Handle(100));
      expect(seed.next(), const Handle(101));
      seed.raiseTo(const Handle(5));
      expect(seed.next(), const Handle(102));
    });

    test('throws rather than wrapping past the ceiling', () {
      final seed = HandleSeed()..raiseTo(const Handle(kMaxHandle));
      expect(seed.next, throwsA(isA<HandleRangeError>()));
    });
  });
}
