// Table numbers (spec 14a T4, T5): what a number may be, and the next one.
//
// No Flutter import: this file is Dart over `dart:core` only.

/// A number's longest length, in UTF-16 code units (T4).
const int kTableNumberMaxLength = 8;

final RegExp _counted = RegExp(r'^[0-9]{1,8}$');

/// The largest number [nextTableNumber] writes: eight digits (T4, T5).
const int _kLargestCounted = 99999999;

/// Why a text is not a table number (T4), as a value a UI words (spec 14d
/// L6).
enum TableNumberProblem {
  /// Empty, or longer than [kTableNumberMaxLength] code units, trimmed.
  length,

  /// A control character, a line break among them.
  control,
}

/// Whether the UTF-16 code unit [u] is a control character: below U+0020
/// (C0, a line break among them) or U+007F to U+009F (DEL and C1). The one
/// rule [tableNumberProblem] and the table data limits
/// (`tableDataProblem`) share.
bool isControlCodeUnit(int u) => u < 0x20 || (u >= 0x7F && u <= 0x9F);

/// Why [raw], trimmed, is not a table number, or null when it is one (T4):
/// non-empty, at most [kTableNumberMaxLength] code units, no control
/// character (no line break).
TableNumberProblem? tableNumberProblem(String raw) {
  final n = raw.trim();
  if (n.isEmpty || n.length > kTableNumberMaxLength) {
    return TableNumberProblem.length;
  }
  if (n.codeUnits.any(isControlCodeUnit)) return TableNumberProblem.control;
  return null;
}

/// [tableNumberProblem] in English, or null.
String? tableNumberError(String raw) => switch (tableNumberProblem(raw)) {
      null => null,
      TableNumberProblem.length => '1 to $kTableNumberMaxLength characters',
      TableNumberProblem.control => 'No line breaks or control characters',
    };

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
