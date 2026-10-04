// Dark theme spec D9a, R-4, R-19 (plan Task 6, M-DT-14): no literal colour
// in a widget. A widget takes its colours from `Theme.of(context)`; the
// literals that remain are data, or not a screen colour, and each is named
// here by (file, exact literal), so a second, different literal in the same
// file goes red; the same literal again does not (`layer_row.dart` has two).
// An allow-list entry that no longer matches anything goes red too: a
// stale entry would silently allow the next literal of that spelling.
//
// The scan reads the source text of every `.dart` file under the four
// directories below, relative to this package. A directory that is missing
// fails the test, so a moved package cannot make the scan pass on nothing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scanned roots (spec D9a), relative to `packages/jet_cad_floor_plan`.
const List<String> kRoots = [
  'lib',
  '../jet_cad_2d_flutter/lib',
  '../../apps/floor_planner/lib',
  '../../apps/restaurant_demo/lib',
];

/// The three patterns (R-4, amended R-C6-3). The word boundary keeps
/// `TrueColor(0x...)`, document data, out of the first; the second takes
/// every `Color.from*`, `Color.from(alpha: ...)` too; the third takes
/// `CupertinoColors` as well, which its word boundary alone would miss.
/// `Colors.transparent` is no colour.
final List<RegExp> kPatterns = [
  RegExp(r'\bColor\(0[xX]'),
  RegExp(r'\bColor\.from(ARGB|RGBO)?\('),
  RegExp(r'\b(Cupertino)?Colors\.(?!transparent\b)'),
];

/// Allowed as a whole file (paths relative to `packages/jet_cad_floor_plan`,
/// `/`-separated): the palettes and the two status caption inks.
const List<String> kAllowedFiles = [
  '../jet_cad_2d_flutter/lib/src/canvas_palette.dart',
];

/// Allowed (file, exact literal) pairs (spec D9a): a match is allowed when
/// the source at the match starts with the literal, and a literal ending in
/// a word character is not followed by another (`Colors.teal` does not
/// cover `Colors.tealAccent`).
const List<(String, String)> kAllowedLiterals = [
  // The layer colour swatch shows the layer's colour (data).
  ('lib/src/layers/layer_row.dart', 'Color(0xFF000000 |'),
  // The opaque carrier paint: the colour rides on the vertices.
  (
    '../jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart',
    'Color(0xFFFFFFFF)'
  ),
  // Export's white page (D7); written `ui.Color(` there.
  (
    '../jet_cad_2d_flutter/lib/src/export/page_export.dart',
    'Color(0xFFFFFFFF)'
  ),
  // The theme seed.
  ('../../apps/floor_planner/lib/main.dart', 'Color(0xFF2266CC)'),
  // The demo's theme seed and its three statuses (data).
  ('../../apps/restaurant_demo/lib/main.dart', 'Colors.teal'),
  ('../../apps/restaurant_demo/lib/main.dart', 'Color(0x99FFB300)'),
  ('../../apps/restaurant_demo/lib/main.dart', 'Color(0x9943A047)'),
  ('../../apps/restaurant_demo/lib/main.dart', 'Color(0x99E53935)'),
];

final RegExp _word = RegExp(r'\w');

/// One literal colour found in a file.
typedef Hit = ({String file, int line, String text});

/// The result of a scan: the matches no entry allows, and the allow-list
/// entries (whole files and pairs) that matched nothing.
typedef Scan = ({
  List<Hit> offenders,
  List<String> stale,
  Map<String, int> files
});

/// Scans [roots] (each must exist) under [allowedFiles] and [allowed].
/// [override] replaces a file's text by its path, for the scan's own
/// mutants.
Scan scan(
    {List<String> roots = kRoots,
    List<String> allowedFiles = kAllowedFiles,
    List<(String, String)> allowed = kAllowedLiterals,
    Map<String, String> override = const {}}) {
  final offenders = <Hit>[];
  final used = <Object>{};
  final files = <String, int>{};
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
      files.update(root, (n) => n + 1, ifAbsent: () => 1);
      final source = override[path] ?? File(path).readAsStringSync();
      final matches = [
        for (final p in kPatterns) ...p.allMatches(source),
      ];
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

const String symbolPanel = 'lib/src/symbols/symbol_panel.dart';

void main() {
  test(
      'M-DT-14: no literal colour in the widgets of both packages and both '
      'apps but the allowed ones, and every allow-list entry still matches '
      '(D9a)', () {
    final s = scan();
    for (final root in kRoots) {
      expect(s.files[root], greaterThan(0), reason: 'premise: $root scanned');
    }
    expect(s.files.values.reduce((a, b) => a + b), greaterThan(100),
        reason: 'premise: the scan read the packages');
    expect(describe(s), isEmpty);
  });

  test('every scanned directory exists, and a missing one fails loudly', () {
    for (final root in kRoots) {
      expect(Directory(root).existsSync(), isTrue, reason: root);
    }
    expect(() => scan(roots: [...kRoots, '../../apps/no_such_app/lib']),
        throwsStateError);
  });

  test(
      "the scan's own mutants: a literal added to symbol_panel.dart, a second "
      'literal in an allow-listed file, Color.fromARGB, a Colors member and '
      'a stale entry each go red; TrueColor and Colors.transparent do not', () {
    final panel = File(symbolPanel).readAsStringSync();
    expect(scan(override: {symbolPanel: panel}).offenders, isEmpty,
        reason: 'premise: the panel as it is');

    Scan withPanel(String extra) =>
        scan(override: {symbolPanel: '$panel\n$extra\n'});
    final lines = '\n'.allMatches(panel).length + 2;

    final added = withPanel('const c = Color(0xFF123456);');
    expect(added.offenders.map((h) => '${h.file}:${h.line}'),
        ['$symbolPanel:$lines'],
        reason: 'the scratch literal, by file:line');
    expect(withPanel('final c = Color.fromARGB(255, 1, 2, 3);').offenders,
        hasLength(1));
    expect(withPanel('final c = Color.fromRGBO(1, 2, 3, 1);').offenders,
        hasLength(1));
    expect(
        withPanel('final c = Color.from(alpha: 1, red: 0, green: 0, blue: 0);')
            .offenders,
        hasLength(1),
        reason: 'Color.from, the component constructor (R-C6-3)');
    expect(withPanel('final c = CupertinoColors.systemBlue;').offenders,
        hasLength(1),
        reason: 'CupertinoColors (R-C6-3)');
    expect(withPanel('final c = Colors.blue;').offenders, hasLength(1));
    expect(withPanel('final c = Colors.tealAccent;').offenders, hasLength(1));
    expect(withPanel('final c = Colors.transparent;').offenders, isEmpty);
    expect(withPanel('const c = TrueColor(0x8A6D3B);').offenders, isEmpty);

    // A second, different literal in an allow-listed file.
    const demo = '../../apps/restaurant_demo/lib/main.dart';
    final demoSource = File(demo).readAsStringSync();
    expect(
        scan(override: {demo: '$demoSource\nconst x = Color(0x99123456);\n'})
            .offenders
            .map((h) => h.file),
        [demo]);

    // A stale entry: the literal it names is gone from its file.
    const seedFile = '../../apps/floor_planner/lib/main.dart';
    final seedSource = File(seedFile).readAsStringSync();
    expect(seedSource.contains('Color(0xFF2266CC)'), isTrue);
    final stale = scan(override: {
      seedFile: seedSource.replaceAll('Color(0xFF2266CC)', 'Color(0xFF2266CD)')
    });
    expect(stale.stale, [
      '(../../apps/floor_planner/lib/main.dart, '
          'Color(0xFF2266CC))'
    ]);
    expect(stale.offenders.map((h) => h.text), [contains('Color(0xFF2266CD)')]);
    expect(
        scan(allowed: [
          ...kAllowedLiterals,
          ('lib/src/page_panel.dart', 'Colors.blue'),
        ]).stale,
        ['(lib/src/page_panel.dart, Colors.blue)'],
        reason: "an entry for an offender D6a removed (F-12)");
  });
}
