### Task 1: Hosted dependency lines (D1)

**Files:**
- Modify: `packages/jet_cad_2d_flutter/pubspec.yaml`, `packages/jet_cad_floor_plan/pubspec.yaml`, `packages/jet_cad_restaurant_symbols/pubspec.yaml`, `packages/jet_cad_2d_gpu/pubspec.yaml`, `apps/floor_planner/pubspec.yaml`, `apps/restaurant_demo/pubspec.yaml`, `apps/dev_harness_2d/pubspec.yaml`
- Create: `tool/ci/test/dependency_lines_test.dart`

**Interfaces:**
- Produces: every live-line pubspec names `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` by `^0.7.1`. `jet_cad_2d_flutter` and `jet_cad_floor_plan` are still at `version: 0.7.0` and `publish_to: none` after this task (Tasks 2 and 3 move them); a caret `^0.7.1` on a sibling at 0.7.0 does not resolve, so **this task also sets both packages' `version: 0.7.1`** (only the version line; the rest of their pubspec is Task 2's and 3's).

- [ ] **Step 1: Write the failing test**

`tool/ci/test/dependency_lines_test.dart`:

```dart
// Spec 2026-10-13-publish-host-packages D1: every pubspec of the live line
// names a published package by a hosted constraint, never by `path:` or
// `git:`. Run from tool/ci: the pubspecs are read from the repository.
import 'dart:io';

import 'package:test/test.dart';

/// The packages published on pub.dev.
const published = ['jet_cad_2d', 'jet_cad_2d_flutter', 'jet_cad_floor_plan'];

/// The live line's pubspecs, relative to tool/ci.
const pubspecs = [
  '../../packages/jet_cad_2d/pubspec.yaml',
  '../../packages/jet_cad_2d_flutter/pubspec.yaml',
  '../../packages/jet_cad_2d_gpu/pubspec.yaml',
  '../../packages/jet_cad_floor_plan/pubspec.yaml',
  '../../packages/jet_cad_restaurant_symbols/pubspec.yaml',
  '../../apps/floor_planner/pubspec.yaml',
  '../../apps/restaurant_demo/pubspec.yaml',
  '../../apps/dev_harness_2d/pubspec.yaml',
];

/// The dependency lines of [pubspec] that name one of [published] by a
/// source other than a hosted constraint: the key line followed by an
/// indented `path:` or `git:` line, or by a nested map.
List<String> nonHosted(String pubspec) {
  final lines = pubspec.split('\n');
  final found = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final key = RegExp(r'^  (\w+):\s*$').firstMatch(lines[i]);
    if (key == null || !published.contains(key[1])) continue;
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    if (RegExp(r'^    \S').hasMatch(next)) found.add('${key[1]}: ${next.trim()}');
  }
  return found;
}

/// The hosted constraints of [pubspec] on one of [published].
Map<String, String> hosted(String pubspec) => {
      for (final m in RegExp(r'^  (\w+): (\S+)\s*$', multiLine: true)
          .allMatches(pubspec))
        if (published.contains(m[1])) m[1]!: m[2]!,
    };

void main() {
  test('DL1 no live-line pubspec names a published package by path or git',
      () {
    for (final path in pubspecs) {
      expect(nonHosted(File(path).readAsStringSync()), isEmpty,
          reason: path);
    }
  });

  test('DL2 every such dependency is the caret of D1', () {
    var seen = 0;
    for (final path in pubspecs) {
      final constraints = hosted(File(path).readAsStringSync());
      seen += constraints.length;
      for (final c in constraints.values) {
        expect(c, '^0.7.1', reason: path);
      }
    }
    expect(seen, greaterThanOrEqualTo(12),
        reason: 'premise: the dependents are read; count them in the '
            'pubspecs at Step 3 and set this to that number exactly');
  });

  test('DL3 the reader sees a path dependency', () {
    expect(nonHosted('dependencies:\n  jet_cad_2d:\n    path: ../x\n'),
        ['jet_cad_2d: path: ../x']);
    expect(nonHosted('dependencies:\n  jet_cad_2d: ^0.7.1\n'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd tool/ci && dart test test/dependency_lines_test.dart`
Expected: DL1 and DL2 FAIL (today every dependent uses `path:`), DL3 passes.

- [ ] **Step 3: Rewrite the dependency lines**

In each pubspec listed under **Files**, replace every

```yaml
  jet_cad_2d:
    path: ../jet_cad_2d
```

(and the `../../packages/...` forms, and the same for `jet_cad_2d_flutter` and `jet_cad_floor_plan`) with the one-line hosted form:

```yaml
  jet_cad_2d: ^0.7.1
```

Keep comments that sit above a dependency. Leave every `jet_cad_restaurant_symbols:` and `jet_cad_2d_gpu:` `path:` dependency as it is. In `packages/jet_cad_2d_flutter/pubspec.yaml` and `packages/jet_cad_floor_plan/pubspec.yaml`, change `version: 0.7.0` to `version: 0.7.1`.

- [ ] **Step 4: Resolve the workspace and check nothing else moved**

Run: `flutter pub get` (repository root), then `git status --short`.
Expected: "Got dependencies!"; `git status` lists only the pubspecs of Step 3 and the new test. If any `analysis_options.yaml` appears, restore it from `git show HEAD:<path> > <path>` and never stage it.

Run: `grep -A3 '"name": "jet_cad_2d"' .dart_tool/package_config.json`
Expected: `"rootUri": "../packages/jet_cad_2d"` (F-1: the local copy).

- [ ] **Step 5: Run the test to see it pass; fire its mutant**

Run: `cd tool/ci && dart test test/dependency_lines_test.dart` — Expected: 3 passed.

Mutant **M-DL1**: copy `apps/restaurant_demo/pubspec.yaml` to the scratchpad, put `jet_cad_2d:` back as `path: ../../packages/jet_cad_2d`, run the test: DL1 must FAIL naming `apps/restaurant_demo/pubspec.yaml`. Restore from the copy; `cmp` it.

- [ ] **Step 6: Every gate**

Run each package's gate (CLAUDE.md "Every task ends green", and `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, `apps/floor_planner`, `apps/restaurant_demo`: `flutter test`, `flutter analyze`, format; `apps/dev_harness_2d`: `flutter analyze`; `tool/ci`: `dart test`, `dart run tool/ci/check_guide.dart`). Compare the engine's, the render package's and the planner's test runs with `dart run tool/ci/expect_failures.dart --package <p> --root <p> <json>` (from the repository root, with `--file-reporter "json:<file>"` on the test run; the planner's test run needs `--enable-vmservice`). On macOS the render package reports the text-lod-ladder rungs 1 and 2 as passing and the five text-ladder goldens as failing (STATUS: recorded); anything else is a failure of this task.

- [ ] **Step 7: Commit**

```bash
git add packages/*/pubspec.yaml apps/floor_planner/pubspec.yaml apps/restaurant_demo/pubspec.yaml apps/dev_harness_2d/pubspec.yaml tool/ci/test/dependency_lines_test.dart
git commit -m "build: name the published packages by hosted constraints (D1)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`packages/*/pubspec.yaml` must not pick up `packages/jet_cad/pubspec.yaml` changes: check `git diff --cached --stat` before committing.)

---

