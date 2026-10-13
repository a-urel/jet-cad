### Task 11: The dependency rule and the CI job (K9)

**Files:**
- Create: `tool/ci/lib/kit_deps.dart`, `tool/ci/check_kit_deps.dart`
- Test: `tool/ci/test/kit_deps_test.dart`
- Modify: `.github/workflows/ci.yml` (the `ci-tools` job, the `publishable` matrix; the `package` matrix entry came with Task 1)

**Interfaces:**
- Consumes: `package:yaml` (`loadYaml`), already a dependency of `tool/ci`.
- Produces: `package:jet_cad_ci/kit_deps.dart` — `const String contractPackage = 'jet_cad_2d_kit'`, `const String planPackage = 'jet_cad_2d_plan'`, `bool isKitPackage(String name)` (`^jet_cad_2d_kit_[a-z0-9_]+$`), `final class PackageSource({required String pubspec, required Map<String, String> dartFiles})`, `Set<String> importedPackages(String dart)`, `List<String> kitDepsProblems(List<PackageSource> packages)`; the script `dart run tool/ci/check_kit_deps.dart [--packages <dir>]` (exit 0 clean, 1 with problems on stderr, 2 on bad usage).

Plan decision: the script picks the packages to check by directory name under `packages/` (`jet_cad_2d_kit` and `jet_cad_2d_kit_*`) and checks each by the `name` in its pubspec; it reads `dependencies`, `dev_dependencies` and `dependency_overrides`, and every `import`, `export` and `part` URI of every `.dart` file under `lib/`, `test/` and `tool/`, conditional URIs included, never a comment or a string literal.
Plan decision: `--packages <dir>` points the script at another tree, so its tests run it on temporary fixtures as CI runs it on the repository.
Plan decision: `jet_cad_2d_kit` joins the `publishable` matrix (the licence comparison and `dart pub publish --dry-run`), so the exit gate's dry run is held on every push, not only once.

- [ ] **Step 1: Write the failing test.** Create `tool/ci/test/kit_deps_test.dart`:

```dart
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
            package('jet_cad_2d_kit',
                dependencies: ['jet_cad_2d', 'meta'],
                files: {
                  'lib/jet_cad_2d_kit.dart':
                      "import 'package:jet_cad_2d/jet_cad_2d.dart';\n",
                }),
            package('jet_cad_2d_kit_restaurant',
                dependencies: ['jet_cad_2d_kit', 'jet_cad_2d_flutter'],
                files: {
                  // M-D1a: forbid every jet_cad_2d_* package.
                  'lib/a.dart':
                      "import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';\n"
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
          ['jet_cad_2d_kit_cinema: pubspec dependencies names jet_cad_2d_plan']);
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
```

- [ ] **Step 2: Run it to see it fail.** Run: `cd tool/ci && dart test test/kit_deps_test.dart`. Expected: compilation error (`Error when reading 'lib/kit_deps.dart'`).

- [ ] **Step 3: The rule.** Create `tool/ci/lib/kit_deps.dart`:

```dart
// Umbrella A1, spec K9: the dependency rule of the kit architecture. The
// contract (jet_cad_2d_kit) depends on neither the plan library nor a kit;
// a kit (jet_cad_2d_kit_*) depends on neither the plan library nor another
// kit. Kits cooperate only through the contract.
import 'package:yaml/yaml.dart';

const String contractPackage = 'jet_cad_2d_kit';
const String planPackage = 'jet_cad_2d_plan';

final RegExp _kit = RegExp(r'^jet_cad_2d_kit_[a-z0-9_]+$');

/// Whether [name] is a kit's package (not the contract's).
bool isKitPackage(String name) => _kit.hasMatch(name);

/// A package as the check reads it: its pubspec's text and its Dart files
/// under lib/, test/ and tool/ (package-relative path → text).
final class PackageSource {
  const PackageSource({required this.pubspec, required this.dartFiles});

  final String pubspec;
  final Map<String, String> dartFiles;
}

/// A directive and everything up to its `;` (conditional URIs included).
final RegExp _directive =
    RegExp(r'^\s*(?:import|export|part)\s+([^;]*);', multiLine: true);
final RegExp _package = RegExp(r'''['"]package:([a-z0-9_]+)/''');

/// The packages [dart]'s import, export and part directives name.
Set<String> importedPackages(String dart) => {
      for (final directive in _directive.allMatches(dart))
        for (final uri in _package.allMatches(directive.group(1)!))
          uri.group(1)!,
    };

/// Every break of the rule among [packages], as `<package>: <what>`.
/// Packages that are neither the contract nor a kit are not checked.
List<String> kitDepsProblems(List<PackageSource> packages) {
  final problems = <String>[];
  for (final p in packages) {
    final Object? doc = loadYaml(p.pubspec);
    if (doc is! Map) {
      problems.add('a pubspec that is not a map');
      continue;
    }
    final name = doc['name'];
    if (name is! String) {
      problems.add('a pubspec without a name');
      continue;
    }
    if (name != contractPackage && !isKitPackage(name)) continue;
    bool forbidden(String dep) =>
        dep == planPackage || (isKitPackage(dep) && dep != name);
    for (final section in const [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final deps = doc[section];
      if (deps is! Map) continue;
      for (final dep in deps.keys) {
        if (dep is String && forbidden(dep)) {
          problems.add('$name: pubspec $section names $dep');
        }
      }
    }
    final paths = p.dartFiles.keys.toList()..sort();
    for (final path in paths) {
      final deps = importedPackages(p.dartFiles[path]!).toList()..sort();
      for (final dep in deps) {
        if (forbidden(dep)) problems.add('$name: $path imports $dep');
      }
    }
  }
  return problems;
}
```

- [ ] **Step 4: The script.** Create `tool/ci/check_kit_deps.dart`:

```dart
// Umbrella A1, spec K9: fails when the kit contract or a kit names the plan
// library or another kit, in its pubspec or in an import under lib/, test/
// or tool/. Passes vacuously for packages that do not exist yet.
//
//   dart run tool/ci/check_kit_deps.dart [--packages <dir>]
import 'dart:io';

import 'lib/kit_deps.dart';

void main(List<String> args) {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  var root = '$repo/packages';
  if (args.length == 2 && args[0] == '--packages') {
    root = args[1];
  } else if (args.isNotEmpty) {
    stderr.writeln('usage: check_kit_deps.dart [--packages <dir>]');
    exit(2);
  }
  final dir = Directory(root);
  final candidates = dir.existsSync()
      ? (dir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <Directory>[];
  final packages = <PackageSource>[];
  for (final d in candidates) {
    final name = d.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (name != contractPackage && !isKitPackage(name)) continue;
    final pubspec = File('${d.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final files = <String, String>{};
    for (final sub in const ['lib', 'test', 'tool']) {
      final subDir = Directory('${d.path}/$sub');
      if (!subDir.existsSync()) continue;
      for (final f in subDir.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('.dart')) {
          files[f.path.substring(d.path.length + 1)] = f.readAsStringSync();
        }
      }
    }
    packages.add(
        PackageSource(pubspec: pubspec.readAsStringSync(), dartFiles: files));
  }
  final problems = kitDepsProblems(packages);
  if (problems.isEmpty) {
    stdout.writeln('kit dependencies: ${packages.length} package(s) checked, '
        'none names the plan library or another kit');
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}
```

- [ ] **Step 5: Run the tests.** Run: `cd tool/ci && dart test test/kit_deps_test.dart`. Expected: `All tests passed!` (D9 prints `1 package(s) checked`: `packages/jet_cad_2d_kit` exists since Task 1). Then from the worktree root: `dart run tool/ci/check_kit_deps.dart`. Expected: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`.

- [ ] **Step 6: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-D1a (`forbidden` returns `dep.startsWith('jet_cad_2d_')`) → D1 red; M-D1b (drop `&& dep != name`) → D1 red; M-D3 (`for (final section in const ['dependencies'])`) → D3, D4 red; M-D5 (`_package.firstMatch` in place of `allMatches`, one URI per directive) → D5 red; M-D6 (`importedPackages` scans `_package.allMatches(dart)` over the whole text) → D6 red; M-D10 (add `'build'` to the script's sub-directories) → D10 red.

- [ ] **Step 7: CI.** In `.github/workflows/ci.yml`:
  - (The `package` matrix entry for `packages/jet_cad_2d_kit` is already in, from Task 1 Step 8a.)
  - In `jobs.ci-tools`, the `Analyze` step's `run` gains `check_kit_deps.dart` after `check_readmes.dart`; the `Format` step's `run` gains `check_kit_deps.dart` after `check_readmes.dart`; after the step `The package READMEs' code is the probe's`, add:

```yaml
      - name: No kit names the plan library or another kit
        run: dart run tool/ci/check_kit_deps.dart
```

  - In `jobs.publishable.strategy.matrix.package`, add `- packages/jet_cad_2d_kit` after `- packages/jet_cad_2d_flutter`.
  - Check the workflow parses: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` (no output) and `git diff .github/workflows/ci.yml` shows only the four additions of this step (the `Analyze` and `Format` lines, the new step, the `publishable` entry).

- [ ] **Step 8: The gate.** Run each, expect exit 0:
  - `cd tool/ci && dart test && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart package_root.dart check_screenshots.dart check_readmes.dart check_kit_deps.dart && dart format --output=none --set-exit-if-changed lib test check_kit_deps.dart`
  - from the root: `dart run tool/ci/check_kit_deps.dart`, `dart run tool/ci/check_guide.dart`, `dart run tool/ci/check_readmes.dart`.

- [ ] **Step 9: Commit.**

```bash
git add tool/ci/lib/kit_deps.dart tool/ci/check_kit_deps.dart tool/ci/test/kit_deps_test.dart .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci(kit): the kit dependency rule and the jet_cad_2d_kit jobs (K9)

check_kit_deps.dart fails when jet_cad_2d_kit names jet_cad_2d_plan or a
kit, or a jet_cad_2d_kit_* names the plan library or another kit, in its
pubspec sections or in a directive under lib/, test/ or tool/; it passes
vacuously for kits not written yet. CI runs the check in the tools job and
dry-runs the package's publish.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
