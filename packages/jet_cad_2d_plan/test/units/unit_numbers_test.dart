// Ported from jet_cad_floor_plan/test/tables/table_numbers_test.dart; assertions unchanged.
//
// Spec 14a T4, T5 (spec 2b S2 "The label", "Placed, numbered"): what a
// unit label may be, and the next number. Every expected value is written
// out by hand.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart';
import 'package:jet_cad_2d_plan/src/units/unit_numbers.dart';

void main() {
  group('nextUnitNumberOf (S2)', () {
    test('TN1 none counted gives "1"', () {
      expect(nextUnitNumberOf(const []), '1');
      expect(nextUnitNumberOf(const ['B4', 'Bahçe 3']), '1');
    });

    test('TN2 max + 1, not count + 1 (M-14a-1)', () {
      expect(nextUnitNumberOf(const ['1', '3']), '4');
      expect(nextUnitNumberOf(const ['12', '5', '9']), '13');
    });

    test(
        'TN3 leading zeros read as decimal; letters, spaces inside and nine '
        'digits or more do not count (M-14a-3)', () {
      expect(nextUnitNumberOf(const ['07', 'B9', '1234567890']), '8');
      expect(nextUnitNumberOf(const ['5', '1 2', '-3', '+9', '٣']), '6');
      expect(nextUnitNumberOf(const ['100000000']), '1',
          reason: 'nine digits are not a number this rule writes');
    });

    test('TN4 a number is trimmed before it is read', () {
      expect(nextUnitNumberOf(const [' 41 ']), '42');
    });

    test(
        'TN5 past eight digits, the smallest unused positive integer '
        '(M-14a-18)', () {
      expect(nextUnitNumberOf(const ['99999999', '1']), '2');
      expect(nextUnitNumberOf(const ['99999999', '1', '2', '00000003']), '4');
      expect(nextUnitNumberOf(const ['99999998']), '99999999');
    });

    test('TN6 counted values', () {
      expect(countedUnitNumber('07'), 7);
      expect(countedUnitNumber('12345678'), 12345678);
      expect(countedUnitNumber('123456789'), isNull);
      expect(countedUnitNumber('B4'), isNull);
      expect(countedUnitNumber(''), isNull);
    });
  });

  group('unitLabelError (S2)', () {
    test('TN7 valid numbers, trimmed', () {
      for (final n in const [
        '1',
        'B4',
        'Bahçe 3',
        '07',
        '12345678',
        ' 4 ',
        'ÇİĞ',
        ' 12345678 ',
        'a\u00A0b',
      ]) {
        expect(unitLabelError(n), isNull, reason: n);
      }
    });

    test('TN8 refused: empty, too long, control characters', () {
      expect(unitLabelError(''), '1 to 8 characters');
      expect(unitLabelError('   '), '1 to 8 characters');
      expect(unitLabelError('123456789'), '1 to 8 characters');
      expect(unitLabelError('a\nb'), isNotNull);
      expect(unitLabelError('a\tb'), isNotNull);
      expect(unitLabelError('a\u0085b'), isNotNull);
      // The edges (review F-7): DEL and the top of C1; nine UTF-16 code
      // units though eight characters (a surrogate pair).
      expect(unitLabelError('\u007F'), isNotNull);
      expect(unitLabelError('a\u009Fb'), isNotNull);
      expect(unitLabelError('1234567😀'), '1 to 8 characters');
    });
  });
}
