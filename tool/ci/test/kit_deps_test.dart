// Umbrella A1, spec K9: the contract depends on neither the plan library
// nor a kit; a kit depends on neither the plan library nor another kit, in
// its pubspec or in any import under lib/, test/ or tool/.
import 'dart:io';

import 'package:jet_cad_ci/kit_deps.dart';
import 'package:test/test.dart';

String pubspec(String name,
    {List<String> dependencies = const [],
    List<String> devDependencies = const [],
    List<String> overrides = const []}) {
  final lines = ['name: $name'];
  void section(String title, List<String> deps) {
    if (deps.isEmpty) return;
    lines.add('$title:');
    for (final d in deps) {
      lines.add('  $d: any');
    }
  }

  section('dependencies', dependencies);
  section('dev_dependencies', devDependencies);
  section('dependency_overrides', overrides);
  return '${lines.join('\n')}\n';
}

PackageSource package(String name,
        {List<String> dependencies = const [],
        List<String> devDependencies = const [],
        List<String> overrides = const [],
        Map<String, String> files = const {}}) =>
    PackageSource(
      pubspec: pubspec(name,
          dependencies: dependencies,
          devDependencies: devDependencies,
          overrides: overrides),
      dartFiles: files,
    );

Future<ProcessResult> check(List<String> args) => Process.run(
    Platform.resolvedExecutable, ['run', 'check_kit_deps.dart', ...args]);

void main() {
  group('the rule', () {
    test('D1 the contract and kits on the contract and the engine are clean',
        () {
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit', dependencies: [
              'jet_cad_2d',
              'meta'
            ], files: {
              'lib/jet_cad_2d_kit.dart':
                  "import 'package:jet_cad_2d/jet_cad_2d.dart';\n",
            }),
            package('jet_cad_2d_kit_restaurant', dependencies: [
              'jet_cad_2d_kit',
              'jet_cad_2d_flutter'
            ], files: {
              // M-D1a: forbid every jet_cad_2d_* package.
              'lib/a.dart': "import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';\n"
                  "import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';\n",
              // M-D1b: forbid the kit's own package.
              'test/a_test.dart':
                  "import 'package:jet_cad_2d_kit_restaurant/x.dart';\n",
            }),
          ]),
          isEmpty);
    });

    test("D2 a kit's pubspec naming the plan library", () {
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit_cinema',
                dependencies: ['jet_cad_2d_kit', 'jet_cad_2d_plan']),
          ]),
          [
            'jet_cad_2d_kit_cinema: pubspec dependencies names jet_cad_2d_plan'
          ]);
    });

    test("D3 a kit's dev_dependencies naming another kit", () {
      // M-D3: read `dependencies` only.
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit_cinema',
                devDependencies: ['jet_cad_2d_kit_restaurant']),
          ]),
          [
            'jet_cad_2d_kit_cinema: pubspec dev_dependencies names '
                'jet_cad_2d_kit_restaurant',
          ]);
    });

    test("D4 the contract's overrides naming the plan; the contract on a kit",
        () {
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit',
                dependencies: ['jet_cad_2d_kit_restaurant'],
                overrides: ['jet_cad_2d_plan']),
          ]),
          [
            'jet_cad_2d_kit: pubspec dependencies names jet_cad_2d_kit_restaurant',
            'jet_cad_2d_kit: pubspec dependency_overrides names jet_cad_2d_plan',
          ]);
    });

    test('D5 imports under lib, test and tool, every directive kind', () {
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit_cinema', files: {
              'lib/src/a.dart':
                  "export 'package:jet_cad_2d_kit_restaurant/symbols.dart';\n",
              'test/b_test.dart':
                  "import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';\n",
              // M-D5: read only the first URI of a directive.
              // The first URI is allowed, the second is not: firstMatch finds
              // only the allowed one.
              'tool/c.dart': "import 'package:jet_cad_2d_kit/a.dart'\n"
                  "    if (dart.library.io) "
                  "'package:jet_cad_2d_kit_architecture/x.dart';\n",
            }),
          ]),
          [
            'jet_cad_2d_kit_cinema: lib/src/a.dart imports jet_cad_2d_kit_restaurant',
            'jet_cad_2d_kit_cinema: test/b_test.dart imports jet_cad_2d_plan',
            'jet_cad_2d_kit_cinema: tool/c.dart imports jet_cad_2d_kit_architecture',
          ]);
    });

    test('D6 a comment or a string naming the plan is not an import', () {
      // M-D6: scan the whole text for package URIs.
      expect(
          kitDepsProblems([
            package('jet_cad_2d_kit_cinema', files: {
              'lib/a.dart': "// See package:jet_cad_2d_plan/x.dart.\n"
                  "const uri = 'package:jet_cad_2d_plan/x.dart';\n",
            }),
          ]),
          isEmpty);
    });

    test('D7 only the contract and kits are checked', () {
      expect(
          kitDepsProblems([
            package('jet_cad_2d_plan', dependencies: ['jet_cad_2d_kit_cinema']),
            package('jet_cad_2d_kitchen', dependencies: ['jet_cad_2d_plan']),
          ]),
          isEmpty);
      expect(isKitPackage('jet_cad_2d_kit_restaurant'), isTrue);
      expect(isKitPackage('jet_cad_2d_kit'), isFalse);
      expect(isKitPackage('jet_cad_2d_kitchen'), isFalse);
    });

    test('D8 importedPackages reads directives only', () {
      expect(
          importedPackages("import 'package:a_b/x.dart';\n"
              "export \"package:c/y.dart\" show Y;\n"
              "part 'z.dart';\n"
              "import 'dart:io';\n"
              "// import 'package:d/z.dart';\n"),
          {'a_b', 'c'});
    });
  });

  group('the script', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('check_kit_deps'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(String path, String text) => File('${tmp.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);

    test('D9 the repository holds the rule: exit 0', () async {
      final r = await check([]);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('package(s) checked'));
    });

    test('D10 a kit naming the plan and another kit: exit 1, both named',
        () async {
      write('jet_cad_2d_kit_cinema/pubspec.yaml',
          pubspec('jet_cad_2d_kit_cinema', dependencies: ['jet_cad_2d_plan']));
      write('jet_cad_2d_kit_cinema/test/a_test.dart',
          "import 'package:jet_cad_2d_kit_restaurant/x.dart';\n");
      write('jet_cad_2d_kit_cinema/build/ignored.dart',
          "import 'package:jet_cad_2d_plan/x.dart';\n");
      final r = await check(['--packages', tmp.path]);
      expect(r.exitCode, 1);
      expect(
          r.stderr,
          allOf(contains('pubspec dependencies names jet_cad_2d_plan'),
              contains('test/a_test.dart imports jet_cad_2d_kit_restaurant')));
      expect(r.stderr, isNot(contains('build/')));
    });

    test('D11 no kit yet: the rule holds vacuously', () async {
      write('jet_cad_2d/pubspec.yaml', pubspec('jet_cad_2d'));
      final r = await check(['--packages', tmp.path]);
      expect(r.exitCode, 0);
      expect(r.stdout, contains('0 package(s) checked'));
      final missing = await check(['--packages', '${tmp.path}/none']);
      expect(missing.exitCode, 0);
    });

    test('D12 bad usage: exit 2', () async {
      expect((await check(['--packages'])).exitCode, 2);
    });
  });
}
