// Names a plan writes once and counts (spec 14d L7, moved into the
// contract by 3a C1.6): a new layer's `Layer n`, a new room's `Room n`, in
// the language of the moment, the lowest free `n` counted over every
// language's name, so a plan edited in two languages never gets `Room 3`
// and `Oda 3`. The patterns name no plan type: a kit passes one per locale
// of its words, the plan library one per built-in language.
//
// Pure Dart: no Flutter, no dart:io.

final RegExp _numbered = RegExp(r'^(.*) ([1-9][0-9]*)$');

/// The `n` of [name] when [name] is one of [patterns] at `n`, compared by
/// [fold] (none: exactly); otherwise null. `n` is a positive integer
/// written without a leading zero, after a space, at the end.
int? numberedNameIndex(String name, Iterable<String Function(int n)> patterns,
    {String Function(String)? fold}) {
  final m = _numbered.firstMatch(name);
  if (m == null) return null;
  final n = int.tryParse(m[2]!);
  if (n == null) return null;
  final f = fold ?? _same;
  final folded = f(name);
  for (final pattern in patterns) {
    if (f(pattern(n)) == folded) return n;
  }
  return null;
}

String _same(String s) => s;
