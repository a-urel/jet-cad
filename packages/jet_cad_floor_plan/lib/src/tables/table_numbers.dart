// Table numbers (spec 14a T4, T5): what a number may be, and the next one.
//
// No Flutter import: this file is Dart over `dart:core` only.

/// A number's longest length, in UTF-16 code units (T4).
const int kTableNumberMaxLength = 8;

final RegExp _counted = RegExp(r'^[0-9]{1,8}$');

/// The largest number [nextTableNumber] writes: eight digits (T4, T5).
const int _kLargestCounted = 99999999;

/// Why [raw], trimmed, is not a table number, or null when it is one (T4):
/// non-empty, at most [kTableNumberMaxLength] code units, no control
/// character (no line break).
String? tableNumberError(String raw) {
  final n = raw.trim();
  if (n.isEmpty || n.length > kTableNumberMaxLength) {
    return '1 to $kTableNumberMaxLength characters';
  }
  for (final u in n.codeUnits) {
    if (u < 0x20 || (u >= 0x7F && u <= 0x9F)) {
      return 'No line breaks or control characters';
    }
  }
  return null;
}

/// The value of [number] when it counts for [nextTableNumber]: 1 to 8 ASCII
/// digits, leading zeros allowed (`"07"` is 7). Null otherwise.
int? countedTableNumber(String number) =>
    _counted.hasMatch(number) ? int.parse(number) : null;

/// The next table number over the live tables' [numbers] (T5): `max + 1`
/// over the counted ones, written without leading zeros; `"1"` when none
/// counts. When `max + 1` would take nine digits, the smallest unused
/// positive integer instead, so a placement never makes a duplicate or an
/// invalid number.
String nextTableNumber(Iterable<String> numbers) {
  final used = <int>{};
  var max = 0;
  for (final n in numbers) {
    final v = countedTableNumber(n.trim());
    if (v == null) continue;
    used.add(v);
    if (v > max) max = v;
  }
  if (max < _kLargestCounted) return '${max + 1}';
  var candidate = 1;
  while (used.contains(candidate)) {
    candidate++;
  }
  return '$candidate';
}
