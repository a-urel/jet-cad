// Spec 14a T4, T5: what a table number may be, and the next one. Every
// expected value is written out by hand.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/src/tables/table_numbers.dart';

void main() {
  group('nextTableNumber (T5)', () {
    test('TN1 none counted gives "1"', () {
      expect(nextTableNumber(const []), '1');
      expect(nextTableNumber(const ['B4', 'Bahçe 3']), '1');
    });

    test('TN2 max + 1, not count + 1 (M-14a-1)', () {
      expect(nextTableNumber(const ['1', '3']), '4');
      expect(nextTableNumber(const ['12', '5', '9']), '13');
    });

    test(
        'TN3 leading zeros read as decimal; letters, spaces inside and nine '
        'digits or more do not count (M-14a-3)', () {
      expect(nextTableNumber(const ['07', 'B9', '1234567890']), '8');
      expect(nextTableNumber(const ['5', '1 2', '-3', '+9', '٣']), '6');
      expect(nextTableNumber(const ['100000000']), '1',
          reason: 'nine digits are not a number this rule writes');
    });

    test('TN4 a number is trimmed before it is read', () {
      expect(nextTableNumber(const [' 41 ']), '42');
    });

    test(
        'TN5 past eight digits, the smallest unused positive integer '
        '(M-14a-18)', () {
      expect(nextTableNumber(const ['99999999', '1']), '2');
      expect(nextTableNumber(const ['99999999', '1', '2', '00000003']), '4');
      expect(nextTableNumber(const ['99999998']), '99999999');
    });

    test('TN6 counted values', () {
      expect(countedTableNumber('07'), 7);
      expect(countedTableNumber('12345678'), 12345678);
      expect(countedTableNumber('123456789'), isNull);
      expect(countedTableNumber('B4'), isNull);
      expect(countedTableNumber(''), isNull);
    });
  });

  group('tableNumberError (T4)', () {
    test('TN7 valid numbers, trimmed', () {
      for (final n in const [
        '1',
        'B4',
        'Bahçe 3',
        '07',
        '12345678',
        ' 4 ',
        'ÇİĞ',
      ]) {
        expect(tableNumberError(n), isNull, reason: n);
      }
    });

    test('TN8 refused: empty, too long, control characters', () {
      expect(tableNumberError(''), '1 to 8 characters');
      expect(tableNumberError('   '), '1 to 8 characters');
      expect(tableNumberError('123456789'), '1 to 8 characters');
      expect(tableNumberError('a\nb'), isNotNull);
      expect(tableNumberError('a\tb'), isNotNull);
      expect(tableNumberError('a\u0085b'), isNotNull);
    });
  });
}
