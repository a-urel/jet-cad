import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The GPU split's guard (spec `2026-10-07-gpu-package-split-design.md` S7,
/// M-G1): `jet_cad_2d_flutter` neither depends on nor imports a GPU package.
///
/// **Why it matters to a host.** `flutter_scene` carries a build hook that
/// compiles shaders with the engine's `impellerc`, and raises the Flutter
/// floor to 3.47. Flutter runs the hooks of the built app's own dependency
/// closure, so one dependency key here puts that hook into every host's
/// build. The GPU lives in `jet_cad_2d_gpu`, which depends on this package
/// and plugs in through `resident_gpu.dart`'s registry -- never the other
/// way round.
const List<String> kForbiddenPackages = <String>[
  'flutter_scene',
  'flutter_gpu',
  'jet_cad_2d_gpu',
];

const List<String> _dependencySections = <String>[
  'dependencies',
  'dev_dependencies',
  'dependency_overrides',
];

/// The forbidden packages that [pubspec] names as a dependency **key** in any
/// dependency section. Keys, not text: a comment, a description or a `path:`
/// value that mentions a name does not count, and neither does a look-alike
/// key (`flutter_scene_extras:`) or a key nested under a dependency.
List<String> forbiddenDependencyKeys(String pubspec) =>
    dependencyKeys(pubspec).where(kForbiddenPackages.contains).toList();

/// The keys directly under each dependency section of [pubspec], in order.
///
/// **A hand-rolled reading, not a YAML parser.** `package:yaml` reaches this
/// workspace's lock only transitively, and `depend_on_referenced_packages`
/// would want it declared in this host-facing package's pubspec. So this
/// reads the shapes `pub` accepts for a dependency section and a person
/// might write:
///
/// - the section as a block map, its keys at **whatever indent its first key
///   uses** (two spaces is a convention, not a rule);
/// - a key plain, `"double-quoted"` or `'single-quoted'`, the section's own
///   name included;
/// - the section as a **flow map**, `dependencies: {flutter_scene: ^0.23.0}`,
///   on one line or across several, with quoted keys and bare keys
///   (`{a, b}`); only its top level counts.
///
/// Comments go first: a `#` at the start of a line or after whitespace,
/// outside a quoted scalar. Not read: explicit `? key` entries, anchors and
/// aliases. Task 2's lock check (`tool/ci/check_host_lock.dart`) is the
/// end-to-end backstop for a shape this misses.
List<String> dependencyKeys(String pubspec) {
  final keys = <String>[];
  final lines = pubspec.split('\n').map(_withoutComment).toList();
  var i = 0;
  while (i < lines.length) {
    final line = lines[i++];
    if (line.trim().isEmpty || _indentOf(line) != 0) continue;
    final top = _leadingKey(line);
    if (top == null || !_dependencySections.contains(top.key)) continue;
    final value = top.rest.trim();
    if (value.startsWith('{')) {
      // A flow map: gather lines until its brackets close.
      final flow = StringBuffer(value);
      while (_flowDepth(flow.toString()) > 0 && i < lines.length) {
        flow
          ..write('\n')
          ..write(lines[i++]);
      }
      keys.addAll(_flowMapKeys(flow.toString()));
      continue;
    }
    // A block map: the first indented line sets the key indent, a deeper
    // line belongs to a dependency's own value, and indent 0 ends it.
    int? keyIndent;
    while (i < lines.length) {
      final l = lines[i];
      if (l.trim().isEmpty) {
        i++;
        continue;
      }
      final indent = _indentOf(l);
      if (indent == 0) break;
      keyIndent ??= indent;
      if (indent == keyIndent) {
        final key = _leadingKey(l.substring(indent));
        if (key != null) keys.add(key.key);
      }
      i++;
    }
  }
  return keys;
}

int _indentOf(String line) => line.length - line.trimLeft().length;

/// Whether a quote at [at] in [s] opens a quoted scalar: at the start, or
/// after whitespace, a flow indicator or a `:`. An apostrophe inside a plain
/// scalar (`it's`) does not.
bool _opensQuote(String s, int at) => at == 0 || ' \t{[,:'.contains(s[at - 1]);

/// Calls [onChar] for each character of [s] outside a quoted scalar; stops
/// early when it returns `true`.
void _scanUnquoted(String s, bool Function(String c, int k) onChar) {
  String? quote;
  for (var k = 0; k < s.length; k++) {
    final c = s[k];
    if (quote != null) {
      if (quote == '"' && c == r'\') {
        k++;
      } else if (c == quote) {
        if (quote == "'" && k + 1 < s.length && s[k + 1] == "'") {
          k++;
        } else {
          quote = null;
        }
      }
    } else if ((c == '"' || c == "'") && _opensQuote(s, k)) {
      quote = c;
    } else if (onChar(c, k)) {
      return;
    }
  }
}

/// [line] without its `#` comment.
String _withoutComment(String line) {
  var end = line.length;
  _scanUnquoted(line, (c, k) {
    if (c == '#' && (k == 0 || ' \t'.contains(line[k - 1]))) {
      end = k;
      return true;
    }
    return false;
  });
  return line.substring(0, end);
}

final RegExp _plainKey = RegExp(
    r'^([^\s\-?:,\[\]{}#&*!|>%@`"' "'" r'][^\n]*?)\s*:(\s.*|)$',
    dotAll: true);
final RegExp _afterQuotedKey = RegExp(r'^\s*:(.*)$', dotAll: true);

/// The key that the mapping entry [s] (no leading whitespace) starts with,
/// and the text after its `:`; `null` when [s] is not a `key:` entry.
({String key, String rest})? _leadingKey(String s) {
  if (s.startsWith('"') || s.startsWith("'")) {
    final q = s[0];
    final key = StringBuffer();
    var k = 1;
    for (; k < s.length; k++) {
      if (q == '"' && s[k] == r'\' && k + 1 < s.length) {
        key.write(s[++k]);
      } else if (q == "'" &&
          s[k] == "'" &&
          k + 1 < s.length &&
          s[k + 1] == "'") {
        key.write("'");
        k++;
      } else if (s[k] == q) {
        break;
      } else {
        key.write(s[k]);
      }
    }
    if (k >= s.length) return null;
    final after = _afterQuotedKey.firstMatch(s.substring(k + 1));
    return after == null ? null : (key: key.toString(), rest: after.group(1)!);
  }
  final plain = _plainKey.firstMatch(s);
  return plain == null ? null : (key: plain.group(1)!, rest: plain.group(2)!);
}

/// How many of [flow]'s brackets are still open.
int _flowDepth(String flow) {
  var depth = 0;
  _scanUnquoted(flow, (c, k) {
    if (c == '{' || c == '[') depth++;
    if (c == '}' || c == ']') depth--;
    return false;
  });
  return depth;
}

final RegExp _bareKey = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final RegExp _bareQuotedKey = RegExp(r'''^(["'])(.*)\1$''');

/// The top-level keys of the flow map [flow], which starts with `{`.
List<String> _flowMapKeys(String flow) {
  final entries = <String>[];
  var depth = 0;
  var from = 1;
  _scanUnquoted(flow, (c, k) {
    if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
      if (depth == 0) {
        entries.add(flow.substring(from, k));
        return true;
      }
    } else if (c == ',' && depth == 1) {
      entries.add(flow.substring(from, k));
      from = k + 1;
    }
    return false;
  });
  final keys = <String>[];
  for (final raw in entries) {
    final entry = raw.trim();
    if (entry.isEmpty) continue;
    final key = _leadingKey(entry);
    if (key != null) {
      keys.add(key.key);
      continue;
    }
    // `{flutter_scene}`: a key with a null value, which `pub` reads as any
    // version.
    if (_bareKey.hasMatch(entry)) {
      keys.add(entry);
    } else if (_bareQuotedKey.firstMatch(entry) case final m?) {
      keys.add(m.group(2)!);
    }
  }
  return keys;
}

/// The forbidden packages a Dart [source] reaches by a `package:` URI in an
/// **import or export directive**: its URI, or either half of a conditional
/// one, wherever its lines break. A directive is a line that starts with
/// `import` or `export`, up to its `;`; `//` lines inside it are skipped.
/// A `package:` URI anywhere else -- a string literal, such as
/// `DraftCanvas`'s fallback report naming `package:jet_cad_2d_gpu`, or a
/// `//` or `///` comment -- does not count.
List<String> forbiddenPackageUris(String source) {
  final directive = RegExp(r'^[ \t]*(?:import|export)\b[^;]*', multiLine: true);
  final uri = RegExp(r'''['"]package:([A-Za-z_][A-Za-z0-9_]*)/''');
  final found = <String>[];
  for (final d in directive.allMatches(source)) {
    for (final line in d.group(0)!.split('\n')) {
      if (line.trimLeft().startsWith('//')) continue;
      for (final m in uri.allMatches(line)) {
        if (kForbiddenPackages.contains(m.group(1))) found.add(m.group(1)!);
      }
    }
  }
  return found;
}

/// Each shape [dependencyKeys] reads, as a section [section] that names
/// [name] as a dependency key beside a harmless one.
final Map<String, String Function(String section, String name)> _shapes =
    <String, String Function(String, String)>{
  'block, two-space indent': (s, n) =>
      '$s:\n  meta: ^1.18.0\n  $n:\n    path: ../$n\n',
  'block, four-space indent': (s, n) =>
      '$s:\n    meta: ^1.18.0\n    $n:\n        path: ../$n\n',
  'block, one-space indent': (s, n) => '$s:\n meta: ^1.18.0\n $n: ^0.23.0\n',
  'block, comments before the first key': (s, n) =>
      '$s:\n# moved here\n      # at another indent\n  meta: ^1.18.0\n'
      '  $n: ^0.23.0 # it is back\n',
  'block, double-quoted key': (s, n) =>
      '$s:\n  meta: ^1.18.0\n  "$n": ^0.23.0\n',
  'block, single-quoted key': (s, n) =>
      "$s:\n  meta: ^1.18.0\n  '$n' : ^0.23.0\n",
  'block, quoted section': (s, n) => '"$s":\n  meta: ^1.18.0\n  $n: ^0.23.0\n',
  'flow map': (s, n) => '$s: {meta: ^1.18.0, $n: ^0.23.0}\n',
  'flow map, quoted key with a map value': (s, n) =>
      '$s: {meta: ^1.18.0, "$n": {path: ../$n}}\n',
  'flow map across lines': (s, n) =>
      '$s: {\n  meta: ^1.18.0,\n  $n: ^0.23.0\n}\n',
  'flow map, bare key': (s, n) => '$s: {meta, $n}\n',
};

String _pubspecWith(String body) =>
    'name: x\n${body}flutter:\n  uses-material-design: true\n';

void main() {
  test("the pubspec names no GPU package as a dependency", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // Not vacuous: the same reading finds the keys the pubspec does have.
    expect(dependencyKeys(pubspec),
        containsAll(<String>['jet_cad_2d', 'meta', 'pdf', 'flutter_test']));
    // MUTATION (M-G1): `flutter_scene: ^0.23.0` back under `dependencies:`.
    expect(forbiddenDependencyKeys(pubspec), isEmpty);
  });

  test('no file under lib/ reaches a GPU package by a package: URI', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty, reason: 'run from the package root');
    for (final f in files) {
      for (final name in forbiddenPackageUris(f.readAsStringSync())) {
        offenders.add('${f.path}: package:$name/');
      }
    }
    // MUTATION (M-G1): one lib/ file importing `package:jet_cad_2d_gpu/`.
    expect(offenders, isEmpty);
  });

  group('the key matcher', () {
    // Spelled out here, not read from `_dependencySections`: a section
    // dropped from that list must turn these red, not drop out of them.
    const sections = <String>[
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ];
    // MUTATIONS, one shape each: the key indent fixed at 2; quoted keys not
    // unquoted; flow maps skipped; a bare flow key skipped; comments kept;
    // a section dropped from `_dependencySections`.
    for (final MapEntry(key: shape, value: write) in _shapes.entries) {
      test('is red on each name under each section: $shape', () {
        for (final name in kForbiddenPackages) {
          for (final section in sections) {
            expect(forbiddenDependencyKeys(_pubspecWith(write(section, name))),
                <String>[name],
                reason: '$name under $section');
          }
        }
      });
    }

    test('is green on look-alikes, comments, values and other sections', () {
      const pubspec = 'name: x\n'
          'description: draws without flutter_scene or flutter_gpu\n'
          'dependencies:\n'
          '  # flutter_scene: ^0.23.0 -- moved to jet_cad_2d_gpu\n'
          '  flutter_scene_extras: ^1.0.0\n'
          '  my_flutter_gpu: ^1.0.0\n'
          '  scene: ^0.3.0\n'
          '  other:\n'
          '    path: ../jet_cad_2d_gpu\n'
          '    flutter_scene: nested, not a dependency key\n'
          'flutter:\n'
          '  flutter_scene: not a dependency section\n';
      expect(forbiddenDependencyKeys(pubspec), isEmpty);
    });

    test('is green on look-alikes in every shape, and still reads them', () {
      const pubspec = 'name: x\n'
          "description: it's {flutter_scene: not a dependency section}\n"
          'dependencies: # {flutter_scene: ^0.23.0}\n'
          '    # flutter_scene: ^0.23.0 -- moved to jet_cad_2d_gpu\n'
          '    my_flutter_scene_tools: ^1.0.0\n'
          '    "flutter_scene_extras": ^1.0.0\n'
          "    'my_flutter_gpu': ^1.0.0\n"
          '    other:\n'
          '        flutter_scene: nested, not a dependency key\n'
          'dev_dependencies: {my_flutter_scene_tools: ^1.0.0, '
          'other: {path: ../other, flutter_scene: nested}, '
          'list: [flutter_gpu]}\n'
          'dependency_overrides: {\n'
          '  "flutter_scene_extras": {path: ../flutter_scene},\n'
          '  my_flutter_gpu\n'
          '}\n'
          'executables: {flutter_scene: not a dependency section}\n'
          'flutter:\n'
          '  flutter_scene: not a dependency section\n';
      // MUTATION: nested flow keys read as top-level ones, or a substring
      // match instead of a whole key -- either turns this red.
      expect(forbiddenDependencyKeys(pubspec), isEmpty);
      // Not vacuous: green because the look-alikes are read and refused,
      // not because nothing was read.
      expect(dependencyKeys(pubspec), <String>[
        'my_flutter_scene_tools',
        'flutter_scene_extras',
        'my_flutter_gpu',
        'other',
        'my_flutter_scene_tools',
        'other',
        'list',
        'flutter_scene_extras',
        'my_flutter_gpu',
      ]);
    });
  });

  group('the URI matcher', () {
    for (final name in kForbiddenPackages) {
      test('is red on $name by import, export and conditional import', () {
        expect(forbiddenPackageUris("import 'package:$name/x.dart';"),
            <String>[name]);
        expect(forbiddenPackageUris('export "package:$name/x.dart" show y;'),
            <String>[name]);
        expect(
            forbiddenPackageUris("import 'stub.dart'\n"
                "    if (dart.library.io) 'package:$name/x.dart';"),
            <String>[name]);
        // MUTATION: a directive read only up to the end of its first line.
        expect(
            forbiddenPackageUris(
                "library;\n\nimport\n    'package:$name/x.dart'"
                '\n    show Y;'),
            <String>[name]);
      });
    }

    test('is green on comments and look-alike packages', () {
      expect(
          forbiddenPackageUris(
              '/// Installed by `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`.\n'
              "// import 'package:flutter_scene/src/gpu/gpu.dart';\n"
              "import 'package:flutter_scene_extras/x.dart';\n"
              "import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';\n"),
          isEmpty);
    });

    test('is green on a package: URI in a string literal', () {
      // `DraftCanvas`'s fallback report names the GPU package in a string;
      // a reword that adds the barrel's path must not trip the guard.
      // MUTATION: any quoted `package:` URI on a non-comment line counted,
      // directive or not (this guard's first matcher).
      expect(
          forbiddenPackageUris("import 'package:meta/meta.dart';\n\n"
              'const String report = '
              "'an app that wants this backend calls installResidentGpu() '\n"
              "    'from package:jet_cad_2d_gpu first';\n"
              'const String reworded = '
              "'calls installResidentGpu() from '\n"
              "    'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart first';\n"
              "final uri = Uri.parse('package:flutter_scene/x.dart');\n"),
          isEmpty);
    });
  });
}
