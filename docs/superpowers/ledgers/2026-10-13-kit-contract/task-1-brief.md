### Task 1: The package, the workspace entry and the purity test (K1)

**Files:**
- Create: `packages/jet_cad_2d_kit/pubspec.yaml`, `packages/jet_cad_2d_kit/analysis_options.yaml`, `packages/jet_cad_2d_kit/LICENSE`, `packages/jet_cad_2d_kit/README.md`, `packages/jet_cad_2d_kit/CHANGELOG.md`
- Create: `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`, `packages/jet_cad_2d_kit/lib/authoring.dart`
- Create: `packages/jet_cad_2d_kit/test/support/import_walker.dart`, `packages/jet_cad_2d_kit/test/invariants/purity_test.dart`
- Modify: `pubspec.yaml` (root, the `workspace:` list), `.github/workflows/ci.yml` (the `package` matrix entry the existing `tool/ci` test SC16 requires)

**Interfaces:**
- Consumes: nothing.
- Produces: the package `jet_cad_2d_kit` resolvable in the workspace; `walkImports(String packageRoot, String packageName, Iterable<String> entries) → ImportWalk` (`visited: Set<String>`, `violations: List<String>`) in `test/support/import_walker.dart`; the purity test P1, which every later task keeps green. Later tasks add `export` lines to the two barrels.

- [ ] **Step 1: The pubspec.** Create `packages/jet_cad_2d_kit/pubspec.yaml`:

```yaml
name: jet_cad_2d_kit
description: >-
  The kit contract for jet_cad_2d plans: plan components, the .jetlib symbol
  library format and validator, kit words, and a pure-Dart authoring toolkit.
version: 0.1.0
repository: https://github.com/a-urel/jet-cad
issue_tracker: https://github.com/a-urel/jet-cad/issues
funding:
  - https://github.com/sponsors/a-urel
  - https://buymeacoffee.com/yazemo
topics:
  - cad
  - floor-plan
  - symbols
resolution: workspace

environment:
  sdk: ^3.6.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.2
  meta: ^1.18.0
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  lints: ^6.1.0
```

- [ ] **Step 2: The analysis options**, a copy of `jet_cad_2d_flutter`'s strict set without the platform folders. Create `packages/jet_cad_2d_kit/analysis_options.yaml`:

```yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    unused_import: error
    unused_local_variable: error
  exclude:
    - build/**

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - prefer_final_locals
    - unawaited_futures
```

- [ ] **Step 3: Licence, README, CHANGELOG.** Run from the worktree root: `cp LICENSE packages/jet_cad_2d_kit/LICENSE` then `cmp LICENSE packages/jet_cad_2d_kit/LICENSE` (no output). Create `packages/jet_cad_2d_kit/README.md` (Task 10 completes it):

```markdown
# jet_cad_2d_kit

The kit contract for jet_cad_2d plans. Work in progress: see `docs/kits.md`
in the repository.
```

Create `packages/jet_cad_2d_kit/CHANGELOG.md`:

```markdown
## 0.1.0

- The kit contract's symbol side: the plan components (`jetcad.symbol`,
  `jetcad.unit`, `jetcad.manifest`, `jetcad.library`), the `.jetlib`
  library format and its validator, `KitNames`, `SymbolLibrarySource`,
  `PlanKit`, and the pure-Dart authoring toolkit with its conformance test.
```

- [ ] **Step 4: The two barrels**, empty for now. Create `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart`:

```dart
/// The kit contract of jet_cad_2d plans: the components a plan stores, the
/// `.jetlib` symbol library format, a kit's words, its symbol sources and
/// its `PlanKit` descriptor.
///
/// A Flutter library: it reads bundled assets. The model it exports is pure
/// Dart and is shared with `package:jet_cad_2d_kit/authoring.dart`.
library;
```

Create `packages/jet_cad_2d_kit/lib/authoring.dart`:

```dart
/// The kit authoring toolkit, pure Dart: the catalog language, the library
/// builder, the shared shape helpers, the geometry snapshot and the
/// conformance test. A kit's generator runs it under plain `dart run`.
library;
```

- [ ] **Step 5: The workspace entry.** In the root `pubspec.yaml`, add `  - packages/jet_cad_2d_kit` to the `workspace:` list directly after `  - packages/jet_cad_2d_gpu`. Run from the worktree root: `flutter pub get`. Expected: `Got dependencies!` (or `Resolving dependencies... ` then success). Then `git status --short`. Expected: the new `packages/jet_cad_2d_kit/` directory and ` M pubspec.yaml`; if any existing `analysis_options.yaml` shows as modified, leave it unstaged (Global Constraints).

- [ ] **Step 6: Write the walker and its failing test.** Create `packages/jet_cad_2d_kit/test/support/import_walker.dart`:

```dart
// The import-graph walker of the purity test (spec K1): from entry files,
// follows every relative and own-package import, export and part URI and
// reports any URI outside an allow-list. An allow-list, not a deny-list:
// a new dependency is impure until someone looks at it.
import 'dart:io';

/// The `dart:` libraries a pure file may import.
const Set<String> allowedDartLibraries = {
  'async',
  'collection',
  'convert',
  'core',
  'math',
  'typed_data',
};

/// The packages (other than the walked one) a pure file may import.
const Set<String> allowedPackages = {'jet_cad_2d', 'meta', 'vector_math'};

/// What a walk saw: every package-relative file it read, and every URI
/// outside the allow-lists as `<file>: <uri>`.
final class ImportWalk {
  ImportWalk(this.visited, this.violations);

  final Set<String> visited;
  final List<String> violations;
}

/// A directive and everything up to its `;` (conditional URIs included).
final RegExp _directive =
    RegExp(r'^\s*(?:import|export|part)\s+([^;]*);', multiLine: true);
final RegExp _uri = RegExp(r'''['"]([^'"]+)['"]''');

/// Walks the import graph of [packageName], rooted at [packageRoot], from
/// [entries] (package-relative paths such as `lib/authoring.dart`).
ImportWalk walkImports(
    String packageRoot, String packageName, Iterable<String> entries) {
  final visited = <String>{};
  final violations = <String>[];
  final queue = [...entries];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!visited.add(path)) continue;
    final text = File('$packageRoot/$path').readAsStringSync();
    for (final directive in _directive.allMatches(text)) {
      for (final match in _uri.allMatches(directive.group(1)!)) {
        final uri = match.group(1)!;
        if (uri.startsWith('dart:')) {
          if (!allowedDartLibraries.contains(uri.substring(5))) {
            violations.add('$path: $uri');
          }
        } else if (uri.startsWith('package:')) {
          final slash = uri.indexOf('/');
          final package = uri.substring('package:'.length, slash);
          if (package == packageName) {
            queue.add('lib/${uri.substring(slash + 1)}');
          } else if (!allowedPackages.contains(package)) {
            violations.add('$path: $uri');
          }
        } else {
          queue.add(Uri.parse(path).resolve(uri).path);
        }
      }
    }
  }
  return ImportWalk(visited, violations);
}

/// Every `.dart` file under [directory] (package-relative), sorted; empty
/// when the directory does not exist.
List<String> dartFilesUnder(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  return [
    for (final f in dir.listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path,
  ]..sort();
}
```

Create `packages/jet_cad_2d_kit/test/invariants/purity_test.dart`:

```dart
// Spec K1: the authoring library and every model file are pure Dart. The
// walker is tested on its own fixtures first, so a walker that reads
// nothing cannot pass P1 vacuously.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/import_walker.dart';

/// A throw-away package tree: path → text.
String tree(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('kit_purity_').path;
  for (final MapEntry(key: path, value: text) in files.entries) {
    File('$root/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  return root;
}

void main() {
  test(
      'P1 lib/authoring.dart and every file under lib/src/model reach no '
      'Flutter, dart:ui or dart:io, and reach every authoring file', () {
    final model = dartFilesUnder('lib/src/model');
    final walk =
        walkImports('.', 'jet_cad_2d_kit', ['lib/authoring.dart', ...model]);
    expect(walk.violations, isEmpty);
    expect(walk.visited, contains('lib/authoring.dart'));
    for (final f in [...model, ...dartFilesUnder('lib/src/authoring')]) {
      expect(walk.visited, contains(f), reason: '$f is not reached');
    }
  });

  test('P2 a Flutter import two hops away is found', () {
    final root = tree({
      'lib/authoring.dart': "export 'src/model/a.dart';\n",
      'lib/src/model/a.dart': "import 'b.dart';\n",
      'lib/src/model/b.dart': "import 'package:flutter/foundation.dart';\n",
    });
    final walk = walkImports(root, 'kit', ['lib/authoring.dart']);
    expect(walk.violations,
        ['lib/src/model/b.dart: package:flutter/foundation.dart']);
    expect(walk.visited, {
      'lib/authoring.dart',
      'lib/src/model/a.dart',
      'lib/src/model/b.dart',
    });
  });

  test('P3 dart:io, dart:ui and an own-package import of an impure file', () {
    final root = tree({
      'lib/a.dart': "import 'dart:io';\nimport 'package:kit/src/b.dart';\n",
      'lib/src/b.dart': "import 'dart:ui' as ui;\n",
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations,
        ['lib/a.dart: dart:io', 'lib/src/b.dart: dart:ui']);
  });

  test('P4 the allowed libraries and packages pass', () {
    final root = tree({
      'lib/a.dart': "import 'dart:convert';\nimport 'dart:math' as math;\n"
          "import 'package:jet_cad_2d/jet_cad_2d.dart';\n"
          "import 'package:meta/meta.dart';\n"
          "import 'package:vector_math/vector_math_64.dart' show Vector2;\n"
          "import '../lib/b.dart';\n",
      'lib/b.dart': "import 'dart:typed_data';\n",
    });
    final walk = walkImports(root, 'kit', ['lib/a.dart']);
    expect(walk.violations, isEmpty);
    expect(walk.visited, {'lib/a.dart', 'lib/b.dart'});
  });

  test("P5 a conditional import's second URI is read", () {
    final root = tree({
      'lib/a.dart': "import 'b.dart'\n"
          "    if (dart.library.io) 'package:flutter/widgets.dart';\n",
      'lib/b.dart': '',
    });
    expect(walkImports(root, 'kit', ['lib/a.dart']).violations,
        ['lib/a.dart: package:flutter/widgets.dart']);
  });
}
```

- [ ] **Step 7: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/invariants/purity_test.dart`. Expected: `All tests passed!` (5 tests; P1 passes with an empty model: the barrels exist and import nothing).

- [ ] **Step 8: Mutation check.** Each of these must turn its test red; revert with `git checkout -- <file>` after each, on committed files (Global Constraints).
  - M-P1 (K1's own): create `lib/src/model/probe.dart` containing `import 'package:flutter/foundation.dart';` → P1 red (`violations` names it). Delete the file.
  - M-P2: in `import_walker.dart`, replace `queue.add(Uri.parse(path).resolve(uri).path);` with nothing (relative imports not followed) → P2 red.
  - M-P5: in `walkImports`, take only the first URI of a directive (`final match = _uri.firstMatch(directive.group(1)!)!;` in place of the loop) → P5 red.
  - M-P3: add `'io'` to `allowedDartLibraries` → P3 red.

- [ ] **Step 8a: The CI matrix entry.** `tool/ci/test/scripts_test.dart` SC16 requires every `packages/*` with a pubspec to be in the `package` matrix of `.github/workflows/ci.yml`, so the entry goes in with the package, not ten commits later. In `jobs.package.strategy.matrix.include`, after the `packages/jet_cad_2d_gpu` entry (`- package: packages/jet_cad_2d_gpu` / `tool: flutter`), add:

```yaml
          - package: packages/jet_cad_2d_kit
            tool: flutter
```

  (same indentation as its neighbours). Check the workflow parses: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` (no output).

- [ ] **Step 9: The gates.** Run each, expect exit 0:
  - `cd tool/ci && dart test` (SC16 is green only with Step 8a).
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` (run `dart format .` first if the check reports files).
  - `cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_gpu && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`

- [ ] **Step 10: Commit.** `git status --short` first; stage by explicit path only:

```bash
git add pubspec.yaml .github/workflows/ci.yml packages/jet_cad_2d_kit/pubspec.yaml packages/jet_cad_2d_kit/analysis_options.yaml packages/jet_cad_2d_kit/LICENSE packages/jet_cad_2d_kit/README.md packages/jet_cad_2d_kit/CHANGELOG.md packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/test/support/import_walker.dart packages/jet_cad_2d_kit/test/invariants/purity_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the jet_cad_2d_kit package and its purity test (K1)

A workspace member at 0.1.0 with its two barrels, empty for now, and the
import walker that keeps lib/authoring.dart and lib/src/model pure Dart:
an allow-list of dart: libraries and packages, conditional URIs read.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
