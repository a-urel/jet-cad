// The demo polices its own colours (fix round 1; ported from the old
// planner package's theme_colours_test, M-DT-14, dark
// theme spec D9a): no literal colour in the demo's `lib` but the allowed
// ones. Each is named by (file, exact literal), so a second, different
// literal in the same file goes red; an allow-list entry that no longer
// matches anything goes red too (a stale entry would silently allow the next
// literal of that spelling); a missing root fails. The old package's scan
// no longer reads the demo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scanned root, relative to `apps/restaurant_demo`.
const List<String> kRoots = ['lib'];

/// The three patterns, as the old scan's: the word boundary keeps
/// `TrueColor(0x...)`, document data, out; `Color.from*` in all its forms;
/// `Colors.` and `CupertinoColors.`, but `Colors.transparent` is no colour.
final List<RegExp> kPatterns = [
  RegExp(r'\bColor\(0[xX]'),
  RegExp(r'\bColor\.from(ARGB|RGBO)?\('),
  RegExp(r'\b(Cupertino)?Colors\.(?!transparent\b)'),
];

/// Allowed as a whole file: the POS look, a hand-built ColorScheme of
/// another design system's tokens, literal by nature.
const List<String> kAllowedFiles = ['lib/demo_theme.dart'];

/// Allowed (file, exact literal) pairs: a match is allowed when the source
/// at the match starts with the literal, and a literal ending in a word
/// character is not followed by another (`Colors.teal` does not cover
/// `Colors.tealAccent`). Task 8 adds the badge literals if it restores them.
const List<(String, String)> kAllowedLiterals = [
  // The demo's theme seed.
  ('lib/main.dart', 'Colors.teal'),
  // The statuses a POS would set: Ordered, Eating, Bill.
  ('lib/statuses.dart', 'Color(0x99FFB300)'),
  ('lib/statuses.dart', 'Color(0x9943A047)'),
  ('lib/statuses.dart', 'Color(0x99E53935)'),
];

final RegExp _word = RegExp(r'\w');

typedef Hit = ({String file, int line, String text});
typedef Scan = ({List<Hit> offenders, List<String> stale, int files});

Scan scan(
    {List<String> roots = kRoots,
    List<String> allowedFiles = kAllowedFiles,
    List<(String, String)> allowed = kAllowedLiterals,
    Map<String, String> override = const {}}) {
  final offenders = <Hit>[];
  final used = <Object>{};
  var files = 0;
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) {
      throw StateError('scanned directory missing: $root '
          '(${dir.absolute.path})');
    }
    final paths = [
      for (final e in dir.listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart')) e.path.replaceAll(r'\', '/'),
    ]..sort();
    for (final path in paths) {
      files++;
      final source = override[path] ?? File(path).readAsStringSync();
      final matches = [for (final p in kPatterns) ...p.allMatches(source)];
      if (allowedFiles.contains(path)) {
        if (matches.isNotEmpty) used.add(path);
        continue;
      }
      for (final m in matches) {
        final entry = allowed.where((a) {
          if (a.$1 != path || !source.startsWith(a.$2, m.start)) return false;
          final end = m.start + a.$2.length;
          return !(_word.hasMatch(a.$2[a.$2.length - 1]) &&
              end < source.length &&
              _word.hasMatch(source[end]));
        }).firstOrNull;
        if (entry != null) {
          used.add(entry);
          continue;
        }
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        final start = source.lastIndexOf('\n', m.start) + 1;
        var end = source.indexOf('\n', m.start);
        if (end < 0) end = source.length;
        offenders.add((
          file: path,
          line: line,
          text: source.substring(start, end).trim()
        ));
      }
    }
  }
  return (
    offenders: offenders,
    stale: [
      for (final f in allowedFiles)
        if (!used.contains(f)) 'whole file $f',
      for (final a in allowed)
        if (!used.contains(a)) '(${a.$1}, ${a.$2})',
    ],
    files: files,
  );
}

String describe(Scan s) => [
      for (final h in s.offenders) '${h.file}:${h.line}: ${h.text}',
      for (final e in s.stale) 'stale allow-list entry: $e',
    ].join('\n');

void main() {
  test(
      'M-DT-14: no literal colour in the demo but the allowed ones, and '
      'every allow-list entry still matches', () {
    final s = scan();
    expect(s.files, greaterThan(3), reason: 'premise: the scan read lib');
    expect(describe(s), isEmpty);
  });

  test('a missing root fails loudly', () {
    expect(() => scan(roots: ['no_such_dir']), throwsStateError);
  });

  test(
      "the scan's own mutants: a stray literal in main.dart, a second "
      'spelling, Color.fromARGB, a Colors member and a stale entry go red; '
      'TrueColor and Colors.transparent do not', () {
    const main = 'lib/main.dart';
    final src = File(main).readAsStringSync();
    expect(scan(override: {main: src}).offenders, isEmpty, reason: 'premise');
    Scan with_(String extra) => scan(override: {main: '$src\n$extra\n'});
    final line = '\n'.allMatches(src).length + 2;
    expect(with_('const c = Color(0xFF000000);').offenders.map((h) => h.line),
        [line]);
    expect(with_('final c = Colors.tealAccent;').offenders, hasLength(1),
        reason: 'Colors.teal does not cover tealAccent');
    expect(with_('final c = Color.fromARGB(255, 1, 2, 3);').offenders,
        hasLength(1));
    expect(with_('final c = Colors.blue;').offenders, hasLength(1));
    expect(with_('final c = Colors.transparent;').offenders, isEmpty);
    expect(with_('const c = TrueColor(0x8A6D3B);').offenders, isEmpty);
    expect(
        scan(allowed: [...kAllowedLiterals, ('lib/main.dart', 'Colors.blue')])
            .stale,
        ['(lib/main.dart, Colors.blue)']);
    // The theme file is allowed whole.
    const theme = 'lib/demo_theme.dart';
    expect(
        scan(override: {
          theme:
              '${File(theme).readAsStringSync()}\nconst x = Color(0xFF123456);'
        }).offenders,
        isEmpty);
  });
}
