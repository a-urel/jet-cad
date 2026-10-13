### Task 6: `tool/readme_probe` and `check_readmes.dart` (D8)

**Files:**
- Create: `tool/readme_probe/pubspec.yaml`, `tool/readme_probe/lib/engine.dart`, `lib/renderer.dart`, `lib/planner.dart`
- Create: `tool/ci/lib/readmes.dart`, `tool/ci/check_readmes.dart`, `tool/ci/test/readmes_test.dart`
- Modify: `packages/jet_cad_2d_flutter/README.md`, `packages/jet_cad_floor_plan/README.md` (snippets as declarations)
- Modify: `pubspec.yaml` (workspace), `.github/workflows/ci.yml` (`ci-tools`), `tool/ci/test/dependency_lines_test.dart`

**Interfaces:**
- Produces: `List<String> readmeProblems(String name, String readme, {required String dart, required String yaml})` in `tool/ci/lib/readmes.dart`; the probe files, which Task 8 keeps in step with the READMEs.

- [ ] **Step 1: Snippets that are declarations.** A probe holds each block contiguously, so a block must be statements or declarations, not a bare expression. In the renderer's README make the last line `final canvas = DraftCanvas(document: document, index: index, camera: camera);`; in the planner's, `final app = MaterialApp(` … `);` and `final loader = SymbolLibraryLoader(sources: [furnitureSymbolSource, mySymbolSource]);`. Change nothing else in the READMEs here.

- [ ] **Step 2: Write the failing tests**, `tool/ci/test/readmes_test.dart`:

```dart
// Package READMEs spec D8: every Dart block of a package README is in its
// probe file, which CI analyses against the barrels the README names.
import 'dart:io';

import 'package:jet_cad_ci/readmes.dart';
import 'package:test/test.dart';

String read(String path) => File(path).readAsStringSync();

final probeYaml = read('host_probe/pubspec.yaml.in');

final cases = {
  'jet_cad_2d': '../readme_probe/lib/engine.dart',
  'jet_cad_2d_flutter': '../readme_probe/lib/renderer.dart',
  'jet_cad_floor_plan': '../readme_probe/lib/planner.dart',
};

void main() {
  test('RM1 every README block is in its probe', () {
    for (final MapEntry(key: package, value: probe) in cases.entries) {
      final readme = read('../../packages/$package/README.md');
      expect(readmeProblems(package, readme, dart: read(probe), yaml: probeYaml),
          isEmpty,
          reason: package);
    }
  });

  test('RM2 a renamed identifier in a README is named', () {
    final readme = read('../../packages/jet_cad_2d/README.md');
    expect(readme, contains('DraftDocument.empty()'), reason: 'premise');
    final renamed =
        readme.replaceFirst('DraftDocument.empty()', 'DraftDocument.blank()');
    expect(
        readmeProblems('jet_cad_2d', renamed,
            dart: read(cases['jet_cad_2d']!), yaml: probeYaml),
        [startsWith('jet_cad_2d: dart: ')]);
  });

  test('RM3 a README without a Dart block is red', () {
    expect(readmeProblems('x', '# x\n\nNo code.\n', dart: '', yaml: ''),
        ['x: no dart block']);
  });

  test("RM4 the planner's font block is the host probe's", () {
    final readme = read('../../packages/jet_cad_floor_plan/README.md');
    final moved = readme.replaceFirst('Roboto-Regular.ttf', 'Roboto.ttf');
    expect(moved, isNot(readme), reason: 'premise');
    expect(
        readmeProblems('jet_cad_floor_plan', moved,
            dart: read(cases['jet_cad_floor_plan']!), yaml: probeYaml),
        [startsWith('jet_cad_floor_plan: yaml: ')]);
  });
}
```

Run `cd tool/ci && dart test test/readmes_test.dart`: fails to load.

- [ ] **Step 3: Implement** `tool/ci/lib/readmes.dart`:

```dart
// The package READMEs' check (package READMEs spec D8), the host guide's
// rule applied to each README: its Dart blocks are in a probe file CI
// analyses, its YAML blocks in the host probe's pubspec.
import 'guide.dart';

/// [readme]'s blocks missing from [dart] and [yaml], each prefixed with
/// [name]; a README with no Dart block is a problem of its own.
List<String> readmeProblems(String name, String readme,
    {required String dart, required String yaml}) {
  if (fencedBlocks(readme, 'dart').isEmpty) return ['$name: no dart block'];
  return [
    for (final m in missingBlocks(readme, dart: dart, yaml: yaml)) '$name: $m'
  ];
}
```

and `tool/ci/check_readmes.dart` on the model of `check_guide.dart` (repo path from `Platform.script`, the three cases of RM1, the YAML from `tool/ci/host_probe/pubspec.yaml.in`, `stdout` "package READMEs: all N code blocks are in the probes" or each problem on `stderr` and exit 1).

- [ ] **Step 4: The probe.** `tool/readme_probe/pubspec.yaml`:

```yaml
name: jet_cad_readme_probe
description: >-
  The package READMEs' code, analysed (package READMEs spec D8): one file
  per README, each importing only the barrels its README names. Not a
  product package.
publish_to: none
version: 0.1.0
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d: ^0.7.1
  jet_cad_2d_flutter: ^0.7.1
  jet_cad_floor_plan: ^0.7.1
  vector_math: ^2.2.0
```

Each `lib/*.dart` opens with a comment naming its README, imports only that README's barrels (engine: `package:jet_cad_2d/jet_cad_2d.dart`, `package:vector_math/vector_math_64.dart show Vector2`; renderer: `package:flutter/widgets.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` and `package:jet_cad_2d/jet_cad_2d.dart` for `DraftDocument`/`SpatialIndex`, which the README must then say it uses; planner: `package:flutter/material.dart`, `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`), and holds each block verbatim inside the smallest declaration that compiles: the engine's `void main()` as is; the renderer's statements in `Widget canvasFor(Size size) { … return canvas; }`; the planner's first block in `Widget appFor() { … return app; }`, its `main` block in `Future<void> main() async { … }`, the loader in `SymbolLibraryLoader loaderWith(SymbolLibrarySource mySymbolSource) { … return loader; }`. Add `  - tool/readme_probe` to the root workspace; `flutter pub get`; `git status --short` (no `analysis_options.yaml`).

- [ ] **Step 5: Run, analyze, mutate.** `cd tool/ci && dart test test/readmes_test.dart`: RM1–RM4 pass. `cd tool/readme_probe && flutter analyze`: "No issues found!". `dart run tool/ci/check_readmes.dart`: green. Mutations, each red then restored and `cmp`ed: M-RM-a, a README identifier renamed (check red); M-RM-b, the planner probe's barrel import dropped (analyze red); M-RM-c, `missingBlocks` call replaced by `[]` in `readmes.dart` (RM2 red).

- [ ] **Step 6: CI and dependency lines.** In `ci-tools` add `check_readmes.dart` to the Analyze and Format lists, and the steps:

```yaml
      - name: The package READMEs' code is the probe's
        run: dart run tool/ci/check_readmes.dart
      - name: Analyze the README probe
        working-directory: tool/readme_probe
        run: flutter analyze
```

Format the probe in the same job's Format step (add `../readme_probe/lib` to its list). Add `'../../tool/readme_probe/pubspec.yaml'` to `dependency_lines_test.dart`'s `pubspecs` and DL2's count +3.

- [ ] **Step 7: Gate and commit.** `cd tool/ci && dart test`, the analyze and format lines as CI runs them, `check_guide`, `check_readmes`; commit: `git commit -m "feat(ci): the package READMEs' code is analysed in tool/readme_probe"`.

---

