# Publishing the host packages on pub.dev — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `jet_cad_2d_flutter` and `jet_cad_floor_plan` publishable on pub.dev at 0.7.1, with every dependency on a published package a hosted constraint, CI's dry run over three packages, a host probe that proves it checks the commit under test, and a host guide that describes pub.dev only.

**Architecture:** Approach A: pubspecs name siblings by hosted caret constraints; the pub workspace still resolves them to the local copies, so development is unchanged. The host probe (outside the workspace) takes the four repository packages from git at the commit under test through `dependency_overrides`, and its lock check fails unless all four came from that commit. A host carries the restaurant symbol library in its own code and assets.

**Tech Stack:** Dart 3.13 / Flutter 3.47.6, pub workspaces, `dart pub publish --dry-run`, pana 0.23.19, GitHub Actions, bash.

**Spec:** [docs/superpowers/specs/2026-10-13-publish-host-packages-design.md](../specs/2026-10-13-publish-host-packages-design.md) (revision 2, approved by the human on 2026-10-13). Read it before any task: every task cites its D-sections.

## Global Constraints

- Hosted constraints: `jet_cad_2d: ^0.7.1`, `jet_cad_2d_flutter: ^0.7.1`, `jet_cad_floor_plan: ^0.7.1` (D1). A dependency on `jet_cad_restaurant_symbols` or `jet_cad_2d_gpu` stays `path:`.
- `jet_cad_2d_flutter` and `jet_cad_floor_plan`: `version: 0.7.1`, `sdk: ^3.6.0`, `flutter: ">=3.44.0"`, no `publish_to`, `repository: https://github.com/a-urel/jet-cad`, `issue_tracker: https://github.com/a-urel/jet-cad/issues`.
- LICENSE in each published package: the root `LICENSE`, byte for byte (Apache 2.0).
- No screenshots anywhere (the human: *"görselsiz kalsın"*).
- Never run `dart pub publish` without `--dry-run`. Never push, tag or merge: the human's word only.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them. Check `git status` after every pub operation.
- Never synthesize test output; quote what commands print.
- Never `git checkout` a file to revert a mutation: copy it aside first and restore from the copy, then `cmp`.
- Code, comments and commit messages in English; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every task ends green: the gate of each package it touches (CLAUDE.md), compared against `tool/ci/standing_failures.txt` / `standing_skips.txt` with `tool/ci/expect_failures.dart` where the package has standing entries.
- Worktree-guarded sessions refuse bash loops, `trap` and `$VAR` pipelines: run each package's commands as separate plain commands.

## Review Focus

1. **The planner's archive must hold every run-time asset** — `assets/library/furniture.jetlib`, `lib/fonts/Roboto-Regular.ttf`, `assets/fonts/Roboto_LICENSE.txt` — or a pub.dev host's planner starts with no furniture and no font. Pinned in Task 3, Step 9 (the dry-run listing is grepped for all three).
2. **A pubspec slipping back to `path:` for a published package** (an app copied from an old branch, a merge) would pass every gate in the workspace and break nothing until a host resolves. Pinned in Task 1 by `tool/ci/test/dependency_lines_test.dart`.
3. **A dropped or misspelt override in the probe** resolves silently from pub.dev once the packages are published. Pinned in Task 5 (the lock check's source and ref, with mutants).
4. **Stale copied symbol files in the probe** from an earlier run could mask a copy step that no longer runs. Pinned in Task 6, Step 3 (the clean line removes them; `scripts_test.dart` SC14 pins the order).
5. **The planner example must load its furniture from the package's own asset, with no network**: a host that copies the example gets an empty palette otherwise. Pinned in Task 3, Step 2 (the test pumps `FloorPlanExampleApp` and requires the loader's state to be loaded with entries; M-FX1 removes the source and must go red). Fonts are not loaded under `flutter test` (Ahem); the example's `main` loads them, as the host guide's §2 does.

---

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

### Task 2: `jet_cad_2d_flutter` 0.7.1, packaged (D2)

**Files:**
- Modify: `packages/jet_cad_2d_flutter/pubspec.yaml`, `packages/jet_cad_2d_flutter/README.md`, `packages/jet_cad_2d_flutter/lib/export_testing.dart` (library comment), `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` (the doc comment naming `shaders/cad_stroke.vert`), the files `dart doc` names
- Create: `packages/jet_cad_2d_flutter/LICENSE`, `.pubignore`, `CHANGELOG.md`, `example/lib/main.dart`, `test/example_test.dart`

**Interfaces:**
- Consumes: Task 1's pubspec (hosted `jet_cad_2d: ^0.7.1`, `version: 0.7.1`).
- Produces: `example/lib/main.dart` defines `class DraftExampleApp extends StatefulWidget` and a top-level `DraftDocument buildExampleDocument()`; the test imports `../example/lib/main.dart`.

- [ ] **Step 1: Baseline**

Run: `dart pub -C packages/jet_cad_2d_flutter publish --dry-run` — record the errors and warnings it prints (expected: no LICENSE, no CHANGELOG, `publish_to`). Run `cd packages/jet_cad_2d_flutter && dart doc --dry-run` — expected "Found 6 warnings" (F-4); record each warning's line.

- [ ] **Step 2: Write the failing example test**

`packages/jet_cad_2d_flutter/test/example_test.dart`:

```dart
// The published example (spec D2): it builds, shows its document, and
// frames all of it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../example/lib/main.dart';

void main() {
  testWidgets('the example shows a line and a circle, framed whole',
      (tester) async {
    await tester.pumpWidget(const DraftExampleApp());
    final canvas = tester.widget<DraftCanvas>(find.byType(DraftCanvas));
    final doc = canvas.document;
    expect(doc.entities.liveCount, 2);

    // The circle is where the example says: a pick 1 unit outside its top
    // edge finds it, as an edge (a pick inside a closed circle would hit
    // its fill at any radius and test nothing).
    final hit = HitPath();
    expect(
        canvas.index
            .pickInto(Vector2(300, 301), 2, const QueryFilter.picking(), hit),
        isTrue);
    expect(doc.entities.kindAt(doc.entities.slotOf(hit.entity)!),
        EntityKind.circle);
    expect(hit.kind, HitKind.edge);

    // The camera frames the whole drawing.
    final size = tester.getSize(find.byType(DraftCanvas));
    final visible = canvas.camera.value.visibleWorld(size);
    final extents = doc.extents;
    expect(visible.minX, lessThanOrEqualTo(extents.minX));
    expect(visible.minY, lessThanOrEqualTo(extents.minY));
    expect(visible.maxX, greaterThanOrEqualTo(extents.maxX));
    expect(visible.maxY, greaterThanOrEqualTo(extents.maxY));
  });
}
```

Run: `cd packages/jet_cad_2d_flutter && flutter test test/example_test.dart`
Expected: FAIL (the example does not exist).

- [ ] **Step 3: Write the example**

`packages/jet_cad_2d_flutter/example/lib/main.dart` (no `example/pubspec.yaml`: spec D2, V-1):

```dart
// A document shown in a DraftCanvas: a line and a circle, framed whole.
//
// Run from the package directory with `flutter run -t example/lib/main.dart`.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() => runApp(const DraftExampleApp());

/// A line and a circle, measured by the Flutter text measurer that
/// [DraftCanvas] requires.
DraftDocument buildExampleDocument() {
  final doc = DraftDocument.empty(measurer: FlutterTextMeasurer());
  doc.commands
    ..execute(addDrafted(doc, EntityKind.line,
        linePayload(Vector2(100, 100), Vector2(500, 100)),
        layer: ReservedHandles.layerZero))
    ..execute(addDrafted(
        doc, EntityKind.circle, circlePayload(Vector2(300, 250), 50),
        layer: ReservedHandles.layerZero));
  return doc;
}

class DraftExampleApp extends StatefulWidget {
  const DraftExampleApp({super.key});

  @override
  State<DraftExampleApp> createState() => _DraftExampleAppState();
}

class _DraftExampleAppState extends State<DraftExampleApp> {
  final DraftDocument document = buildExampleDocument();
  late final SpatialIndex index = SpatialIndex(document);
  CameraController? camera;

  @override
  void dispose() {
    camera?.dispose();
    index.dispose();
    document.dispose();
    (document.textMeasurer as FlutterTextMeasurer).clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(builder: (context, constraints) {
          // Framed once, at the first layout: the drawing's extents with a
          // margin, fitted to the space the canvas gets.
          camera ??= CameraController(ViewportTransform.fit(
              document.extents.inflate(20), constraints.biggest));
          return DraftCanvas(
              document: document, index: index, camera: camera!);
        }),
      );
}
```

If `Aabb2` has no `inflate`, build the margin box with `Aabb2(minX - 20, minY - 20, maxX + 20, maxY + 20)` (check `packages/jet_cad_2d/lib/src/geometry/aabb2.dart` for the constructor's form). If `FlutterTextMeasurer` or `CameraController`'s constructor differ from the forms in `test/draft_canvas_test.dart`, follow that test.

- [ ] **Step 4: Run the test to see it pass; fire its mutants**

Run: `flutter test test/example_test.dart` — Expected: PASS.

- **M-RX1**: the example's circle command removed → the test FAILS (`liveCount` 1). 
- **M-RX2**: the camera fitted to `Aabb2` of `(0, 0)–(1, 1)` instead of the extents → the test FAILS (the visible box).

Each from a copy of `example/lib/main.dart`, restored, `cmp`.

- [ ] **Step 5: Pubspec, LICENSE, `.pubignore`**

`pubspec.yaml`: remove `publish_to: none`; `repository: https://github.com/a-urel/jet-cad`; add `issue_tracker: https://github.com/a-urel/jet-cad/issues`; add

```yaml
topics:
  - cad
  - drawing
  - canvas
  - pdf
```

Description (60–180 characters, no spec references):

```yaml
description: >-
  Flutter rendering and interaction for the jet_cad_2d engine: a CAD canvas
  with camera, rulers, selection and snapping, and PDF and PNG export.
```

Check each claim of that description against `lib/jet_cad_2d_flutter.dart`'s exports before keeping it (rulers: `RulerFrame`; selection: the selection overlay; snapping: `InteractionLayer`'s snap; export: `src/export/`); drop any the barrel does not carry. `environment:` — `sdk: ^3.6.0`, and replace the comment block above it with:

```yaml
environment:
  # The floor pub workspaces document for their members; it sets language
  # 3.6, which formats and analyses as 3.5 did. pdf 3.13.x requires Dart
  # >= 3.12.0, which Flutter first ships in 3.44.0: that bound binds.
  sdk: ^3.6.0
  flutter: ">=3.44.0"
```

Run: `cp LICENSE packages/jet_cad_2d_flutter/LICENSE && cmp LICENSE packages/jet_cad_2d_flutter/LICENSE` (from the root).

`packages/jet_cad_2d_flutter/.pubignore`:

```
# Left out of the pub.dev archive, at the package root only: the suites,
# the test runner's build output, and the shaders, which the package's GPU
# tests read and jet_cad_2d_gpu compiles from the repository. The example
# stays in.
/test/
/build/
/shaders/
```

- [ ] **Step 6: README, CHANGELOG, library comments**

Replace `README.md` with a pub.dev README: one paragraph on what the package is; a "What it holds" list (`DraftCanvas`, `CameraController` and `ViewportTransform`, `RulerFrame`, `InteractionLayer`, the PDF and PNG export) — each name checked against the barrel; the example's essential lines (the `DraftCanvas(document:, index:, camera:)` call and the `FlutterTextMeasurer` requirement) with a link to `https://github.com/a-urel/jet-cad/blob/main/packages/jet_cad_2d_flutter/example/lib/main.dart`; "The API": the barrel is the API, nothing under `src/`, `export_testing.dart` is a test instrument and not API; the 0.x rule (a minor release may break the API, a patch does not); "Where it comes from" (the engine of jet-cad's floor planner; `jet_cad_floor_plan` builds on it); License (Apache 2.0, `LICENSE`). The developer notes of today's README (the tests, the goldens, the rigs) move, unchanged, to `packages/jet_cad_2d_flutter/test/README.md`: `.pubignore` leaves `test/` out of the archive, so they stay in the repository only (a `doc/` folder would be published).

`CHANGELOG.md`:

```markdown
# Changelog

## 0.7.1

The first release on pub.dev. The code is jet-cad 0.7.0's render package
(git tag `v0.7.0`); what changed is how it is packaged: its own LICENSE
(Apache 2.0), a README written for pub.dev, a runnable example, `sdk:
^3.6.0`, and its dependency on `jet_cad_2d` from pub.dev (`^0.7.1`).

From this release on, `jet_cad_2d_flutter` has its own version on pub.dev
and its own git tags (`jet_cad_2d_flutter-vX.Y.Z`). Before it, the package
was released with the other jet-cad packages under one version; that
history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
```

`lib/export_testing.dart`'s library comment: add *"Not API: a test instrument, outside semver; it may change in any release."* `geometry_collector.dart`: where its doc comment names `shaders/cad_stroke.vert`, say the shader sources are in the repository (`packages/jet_cad_2d_flutter/shaders/`), not in the published package.

- [ ] **Step 7: Doc warnings to zero**

Run: `dart doc --dry-run` in the package; fix each warning the way the engine's were fixed (`1dc167d`'s `6f683f2`): a reference to a member in scope by its qualified name, or code-quoted when it names something outside the library. Expected after: "Found 0 warnings and 0 errors."

- [ ] **Step 8: Gate, dry run, pana**

Run the package's gate (test with `expect_failures.dart`, analyze, format). Commit (Step 9), then run `dart pub -C packages/jet_cad_2d_flutter publish --dry-run` on the committed state — Expected: "Package has 0 warnings.", exit 0; record the archive size and check the listing has no `test/`, `build/` or `shaders/`.

pana: `git archive HEAD packages/jet_cad_2d_flutter | tar -x -C <scratch>`, remove `test/`, `build/` and `shaders/` from the copy, run `dart pub global run pana --no-warning <scratch>/packages/jet_cad_2d_flutter` (pana finds the Flutter SDK on the path; if it does not, pass `--flutter-sdk "$(dirname "$(dirname "$(which flutter)")")"`). Record the score and each section for the results note.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): package 0.7.1 for pub.dev (D2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

with a body listing what changed and the mutants M-RX1 and M-RX2. Check `git diff --cached --stat` lists no `analysis_options.yaml`.

---

### Task 3: `jet_cad_floor_plan` 0.7.1, packaged (D3, D11)

**Files:**
- Modify: `packages/jet_cad_floor_plan/pubspec.yaml`, `packages/jet_cad_floor_plan/lib/editor.dart` (library comment), the files `dart doc` names
- Create: `packages/jet_cad_floor_plan/LICENSE`, `.pubignore`, `README.md`, `CHANGELOG.md`, `example/lib/main.dart`, `test/example_test.dart`

**Interfaces:**
- Consumes: Task 1's pubspec (hosted `jet_cad_2d` and `jet_cad_2d_flutter`, `version: 0.7.1`).
- Produces: `example/lib/main.dart` defines `class FloorPlanExampleApp extends StatefulWidget` with a `FloorPlanController` it owns and disposes.

- [ ] **Step 1: Baseline**

Run: `dart pub -C packages/jet_cad_floor_plan publish --dry-run` and `dart doc --dry-run` in the package (expected "Found 23 warnings", F-5); record both.

- [ ] **Step 2: Write the failing example test**

`packages/jet_cad_floor_plan/test/example_test.dart`:

```dart
// The published example (spec D3): it shows the planner over an empty
// plan with the furniture library loaded from the package's own asset.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

import '../example/lib/main.dart';

void main() {
  testWidgets('the example shows the planner with its furniture library',
      (tester) async {
    await tester.pumpWidget(const FloorPlanExampleApp());
    await tester.pumpAndSettle();
    expect(find.byType(FloorPlanView), findsOneWidget);

    final state =
        tester.state<FloorPlanExampleAppState>(find.byType(FloorPlanExampleApp));
    final library = state.symbols.state;
    expect(library, isA<SymbolLibraryLoaded>(),
        reason: 'the furniture library is read from the package asset');
    expect((library as SymbolLibraryLoaded).library.entries, isNotEmpty);
  });
}
```

Check the names against the barrel before running: `SymbolLibraryLoaded` (and its `library`) is in `lib/src/symbols/symbol_library_state.dart`; if the barrel does not export it, import `package:jet_cad_floor_plan/symbol_sources.dart` or `symbols.dart`, whichever does; if the loaded library's entries are not `entries`, use the getter `SymbolLibrary` has (read `symbol_library.dart`). If the test needs `await tester.runAsync(state.symbols.load)` for the asset read to finish, do that rather than `pumpAndSettle` alone.

Run: `cd packages/jet_cad_floor_plan && flutter test test/example_test.dart` — Expected: FAIL (no example).

- [ ] **Step 3: Write the example**

`packages/jet_cad_floor_plan/example/lib/main.dart` (no `example/pubspec.yaml`):

```dart
// The floor planner over an empty plan, with the furniture library the
// package ships. Run from the package directory with
// `flutter run -t example/lib/main.dart`.
import 'package:flutter/material.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFloorPlanFonts();
  registerFontLicences();
  runApp(const FloorPlanExampleApp());
}

class FloorPlanExampleApp extends StatefulWidget {
  const FloorPlanExampleApp({super.key});

  @override
  State<FloorPlanExampleApp> createState() => FloorPlanExampleAppState();
}

class FloorPlanExampleAppState extends State<FloorPlanExampleApp> {
  /// One loader for the furniture library the package ships.
  final SymbolLibraryLoader symbols =
      SymbolLibraryLoader(sources: const [furnitureSymbolSource]);

  late final FloorPlanController controller =
      FloorPlanController(symbols: symbols);

  @override
  void dispose() {
    controller.dispose();
    symbols.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        supportedLocales: floorPlanSupportedLocales,
        localizationsDelegates: floorPlanLocalizationsDelegates,
        home: Scaffold(body: FloorPlanView(controller: controller)),
      );
}
```

Follow the host probe (`tool/ci/host_probe/lib/main.dart`) where a name differs: it is checked against the barrel by CI. If the controller loads the library itself when given `symbols:`, keep it so; if the probe calls `symbols.load()`, do the same in `initState`.

- [ ] **Step 4: Run the test to see it pass; fire its mutants**

Run: `flutter test test/example_test.dart` — Expected: PASS.

- **M-FX1**: `sources: const []` in the example (no furniture) → the test FAILS.
- **M-FX2**: `FloorPlanView` replaced by `const SizedBox()` → the test FAILS.

Each from a copy, restored, `cmp`.

- [ ] **Step 5: Pubspec, LICENSE, `.pubignore`**

`pubspec.yaml`: remove `publish_to: none`; add `repository:`, `issue_tracker:` (Global Constraints); topics:

```yaml
topics:
  - cad
  - floor-plan
  - restaurant
  - point-of-sale
```

Description (60–180 characters):

```yaml
description: >-
  An embeddable parametric floor planner for Flutter: walls, openings,
  rooms, dimensions and furniture symbols, with a host API for tables.
```

Check each claim against the barrel and `editor.dart`. `environment:` — `sdk: ^3.6.0` with the comment block rewritten as in Task 2 Step 5 (keep the reason the Flutter floor binds: printing and pdf). LICENSE copied and `cmp`ed. `.pubignore`:

```
# Left out of the pub.dev archive, at the package root only: the suites,
# the test runner's build output, and the furniture library's generator.
# assets/ and lib/fonts/ stay in: the planner loads them at run time.
/test/
/build/
/tool/
```

- [ ] **Step 6: README, CHANGELOG, `editor.dart`**

`README.md`: what the planner is (one paragraph); "Embedding it" — the example's `FloorPlanController` / `FloorPlanView` lines, the fonts (`ensureFloorPlanFonts`, `registerFontLicences`, the pubspec `fonts:` block of the host guide §2), the languages (`floorPlanSupportedLocales`, `floorPlanLocalizationsDelegates`); "The host guide": `https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md`; "A symbol library of your own": `SymbolLibrarySource`, `SymbolNames`, `SymbolLibraryLoader(sources: [furnitureSymbolSource, …])`, and that `symbols.dart` holds the catalog types and builder; "The API": `jet_cad_floor_plan.dart` is the host API; `symbols.dart` and `symbol_sources.dart` are the symbol libraries' API; `editor.dart` is the floor planner app's editor frame, not host API, outside semver; nothing under `src/`; the 0.x rule; License (Apache 2.0, and Roboto under its own Apache 2.0 licence in `assets/fonts/`).

`CHANGELOG.md`:

```markdown
# Changelog

## 0.7.1

The first release on pub.dev. The code is jet-cad 0.7.0's planner (git
tag `v0.7.0`); what changed is how it is packaged: its own LICENSE (Apache
2.0), a README and a runnable example, `sdk: ^3.6.0`, and its dependencies
on `jet_cad_2d` and `jet_cad_2d_flutter` from pub.dev (`^0.7.1`). Plans
are stored as in 0.7.0 (schema 10): a plan either saves opens in the other.

**Moving a host from git to pub.dev:**

1. Replace the git dependencies on `jet_cad_floor_plan` and
   `jet_cad_restaurant_symbols` with `jet_cad_floor_plan: ^0.7.1`.
2. Remove the import of `jet_cad_restaurant_symbols`. Copy its library
   and names into your app as the host guide's "The restaurant symbols"
   says, and give the loader your own `SymbolLibrarySource` in place of
   `restaurantSymbolSource`.
3. Keep the source's name `restaurant`, and never load your copy together
   with the package's source: the same keys in two sources make the
   loader fail.

From this release on, `jet_cad_floor_plan` has its own version on pub.dev
and its own git tags (`jet_cad_floor_plan-vX.Y.Z`). Before it, the package
was released with the other jet-cad packages under one version; that
history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
```

`lib/editor.dart`'s library comment: add *"Not host API and outside semver: it may change in any release."*

- [ ] **Step 7: Doc warnings to zero**

As Task 2 Step 7. Expected: "Found 0 warnings and 0 errors."

- [ ] **Step 8: Gate**

The planner's gate (`flutter test --enable-vmservice` with `expect_failures.dart`, analyze, format), and `apps/floor_planner`'s and `apps/restaurant_demo`'s gates (they import the planner).

- [ ] **Step 9: Commit, dry run, archive check, pana**

Commit:

```bash
git add packages/jet_cad_floor_plan
git commit -m "feat(jet_cad_floor_plan): package 0.7.1 for pub.dev (D3)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then `dart pub -C packages/jet_cad_floor_plan publish --dry-run > <scratch>/planner-dry.txt 2>&1; echo $?` — Expected: exit 0, "Package has 0 warnings.". **Review Focus 1:** `grep -E 'furniture.jetlib|Roboto-Regular.ttf|Roboto_LICENSE.txt' <scratch>/planner-dry.txt` must print three lines; `grep -E '^\S*\s*(├|└)── (test|tool|build)$' <scratch>/planner-dry.txt` must print nothing. pana as Task 2 Step 8 (remove `test/`, `build/`, `tool/`).

---

### Task 4: CI `publishable` over three packages (D5)

**Files:**
- Modify: `.github/workflows/ci.yml` (the `publishable` job)

- [ ] **Step 1: Rewrite the job as a matrix**

Replace the `publishable` job with:

```yaml
  publishable:
    name: ${{ matrix.package }}, publishable to pub.dev
    runs-on: ubuntu-latest
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        package:
          - packages/jet_cad_2d
          - packages/jet_cad_2d_flutter
          - packages/jet_cad_floor_plan
    steps:
      - uses: actions/checkout@v5
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
      - name: Resolve the workspace
        run: flutter pub get
      # Decision 2 of the publishing spec: each published package carries
      # the root's Apache 2.0 licence, byte for byte.
      - name: The licence is the root's
        run: cmp LICENSE ${{ matrix.package }}/LICENSE
      # A dry run uploads nothing; it exits 65 on any warning (a version
      # bump without its CHANGELOG entry, a modified checked-in file), not
      # only on an error. A dependent's dry run does not need its
      # dependency on pub.dev (spec F-2).
      - name: Publish dry run
        working-directory: ${{ matrix.package }}
        run: dart pub publish --dry-run
```

- [ ] **Step 2: Check the YAML and each step locally**

Run: `ruby -ryaml -e 'y = YAML.load_file(".github/workflows/ci.yml"); p y["jobs"]["publishable"]["strategy"]["matrix"]["package"]'` — Expected: the three paths.

For each of the three packages, run `cmp LICENSE <package>/LICENSE` and `dart pub -C <package> publish --dry-run` on the committed tree — Expected: no output from `cmp`; "Package has 0 warnings.", exit 0.

Mutant **M-CI1**: append a byte to `packages/jet_cad_2d_flutter/LICENSE` (copy first); `cmp` must exit 1 and the dry run must report the modified file with exit 65. Restore, `cmp`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: dry-run and licence checks for the three published packages (D5)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The lock check proves the probe tests the commit (D6)

**Files:**
- Modify: `tool/ci/lib/host_lock.dart`, `tool/ci/check_host_lock.dart`, `tool/ci/test/host_lock_test.dart`, `tool/ci/test/scripts_test.dart`

**Interfaces:**
- Produces, in `package:jet_cad_ci/host_lock.dart`:
  - `const List<String> probedFromCommit = ['jet_cad_2d', 'jet_cad_2d_flutter', 'jet_cad_floor_plan', 'jet_cad_restaurant_symbols'];`
  - `Map<String, String> lockEntryFields(String lock, String name)` — the entry's `source` and `description`'s `resolved-ref` (keys `source`, `resolved-ref`), empty when the package is not in the lock; throws `FormatException` as `lockPackages` does.
  - `List<String> notFromCommit(String lock, String ref)` — one message per package of `probedFromCommit` that is missing, not `source: git`, or at another `resolved-ref`, in that list's order.
- `check_host_lock.dart <pubspec.lock> [--ref <sha>]`: with `--ref`, also fails (exit 1, each message printed) on `notFromCommit`; without it, behaves as today.

- [ ] **Step 1: Write the failing tests**

Append to `tool/ci/test/host_lock_test.dart` (the fixture `host_post_split.lock.txt` resolves the four packages from git at `2b35b69931d6acdb03c219a38c923a8fd3fdc50c`):

```dart
  group('HL-C the four packages come from the commit under test', () {
    const ref = '2b35b69931d6acdb03c219a38c923a8fd3fdc50c';

    test('HL-C1 the green lock: all four from git at the ref', () {
      expect(notFromCommit(green, ref), isEmpty);
      expect(lockEntryFields(green, 'jet_cad_2d'),
          {'source': 'git', 'resolved-ref': ref});
    });

    test('HL-C2 another ref: each of the four named', () {
      const other = '0000000000000000000000000000000000000000';
      expect(notFromCommit(green, other), hasLength(4));
      expect(notFromCommit(green, other).first, contains('jet_cad_2d'));
    });

    // The named mutant of spec D6: one override dropped, so pub took the
    // package from pub.dev.
    for (final name in [
      'jet_cad_2d',
      'jet_cad_2d_flutter',
      'jet_cad_floor_plan',
      'jet_cad_restaurant_symbols',
    ]) {
      test('HL-C3 $name hosted: named', () {
        final entry = entryOf(green, name);
        final hostedEntry = [
          '  $name:',
          '    dependency: transitive',
          '    description:',
          '      name: $name',
          '      sha256: "0000"',
          '      url: "https://pub.dev"',
          '    source: hosted',
          '    version: "0.7.1"',
        ].join('\n');
        final lock = green.replaceFirst(entry, hostedEntry);
        expect(lock, isNot(green), reason: 'premise');
        expect(notFromCommit(lock, ref), [contains(name)]);
      });
    }

    test('HL-C4 a package missing from the lock: named', () {
      final lock = green.replaceFirst(
          '${entryOf(green, 'jet_cad_restaurant_symbols')}\n', '');
      expect(notFromCommit(lock, ref), [contains('jet_cad_restaurant_symbols')]);
    });
  });
```

Add to `scripts_test.dart`, next to SC9–SC13, a case that runs the CLI with `--ref`:

```dart
    test('SC16 --ref: the green lock at its ref exits 0, at another exits 1',
        () async {
      const ref = '2b35b69931d6acdb03c219a38c923a8fd3fdc50c';
      final ok = await Process.run('dart', [
        'run', 'check_host_lock.dart',
        'test/fixtures/host_post_split.lock.txt', '--ref', ref,
      ]);
      expect(ok.exitCode, 0, reason: '${ok.stdout}${ok.stderr}');
      final bad = await Process.run('dart', [
        'run', 'check_host_lock.dart',
        'test/fixtures/host_post_split.lock.txt',
        '--ref', '0000000000000000000000000000000000000000',
      ]);
      expect(bad.exitCode, 1);
      expect(bad.stdout, contains('jet_cad_floor_plan'));
    });
```

(Match the surrounding SC cases' working-directory and invocation style; if they call a helper, use it.)

Run: `cd tool/ci && dart test test/host_lock_test.dart test/scripts_test.dart` — Expected: HL-C and SC16 FAIL (undefined names / unknown flag).

- [ ] **Step 2: Implement**

In `tool/ci/lib/host_lock.dart`, add:

```dart
/// The packages the host probe must take from the commit under test, by
/// its `dependency_overrides` (publishing spec D6): once they are on
/// pub.dev, a dropped override would resolve silently from there.
const List<String> probedFromCommit = [
  'jet_cad_2d',
  'jet_cad_2d_flutter',
  'jet_cad_floor_plan',
  'jet_cad_restaurant_symbols',
];

/// The `source` and the description's `resolved-ref` of the package
/// [name]'s entry in [lock] (keys `source` and `resolved-ref`, each only
/// when present); empty when [lock] has no such package.
Map<String, String> lockEntryFields(String lock, String name) {
  if (!lockPackages(lock).contains(name)) return const {};
  final lines = lock.split('\n');
  final start = lines.indexWhere((l) => RegExp('^ +$name:\\s*\$').hasMatch(l));
  final indent = lines[start].length - lines[start].trimLeft().length;
  final fields = <String, String>{};
  for (final line in lines.skip(start + 1)) {
    final content = line.trimLeft();
    if (content.isEmpty) continue;
    final depth = line.length - content.length;
    if (depth <= indent) break;
    final m = RegExp(r'^(source|resolved-ref):\s*"?([^"\s]+)"?').firstMatch(content);
    if (m != null) fields[m[1]!] = m[2]!;
  }
  return fields;
}

/// One message per package of [probedFromCommit] that [lock] does not
/// resolve from git at [ref]: missing, another source, or another
/// resolved ref.
List<String> notFromCommit(String lock, String ref) => [
      for (final name in probedFromCommit)
        if (lockEntryFields(lock, name) case final f
            when f['source'] != 'git' || f['resolved-ref'] != ref)
          f.isEmpty
              ? '$name: not in the lock'
              : '$name: ${f['source']} at ${f['resolved-ref'] ?? 'no ref'}, '
                  'not git at $ref',
    ];
```

In `tool/ci/check_host_lock.dart`: accept `<pubspec.lock>` alone or `<pubspec.lock> --ref <sha>` (any other shape: the usage line, exit 2, as today); after the forbidden-package check, when `--ref` is given, print each `notFromCommit` message as `${file.path}: $message` and exit 1 if any. Update the usage text and the header comment (*"… and, with --ref, that the four repository packages came from git at that commit (publishing spec D6)"*).

- [ ] **Step 3: Run the tests; fire the mutants**

Run: `cd tool/ci && dart test` — Expected: all pass.

- **M-LK1**: in `notFromCommit`, drop the `f['source'] != 'git' ||` clause → HL-C3 FAILS for each name.
- **M-LK2**: drop the `|| f['resolved-ref'] != ref` clause → HL-C2 FAILS.

Each from a copy of `host_lock.dart`, restored, `cmp`.

- [ ] **Step 4: Format, analyze, commit**

Run: `cd tool/ci && dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart && dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart host_probe/lib`

```bash
git add tool/ci/lib/host_lock.dart tool/ci/check_host_lock.dart tool/ci/test/host_lock_test.dart tool/ci/test/scripts_test.dart
git commit -m "ci: the lock check proves the probe took the commit under test (D6)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The probe and the host guide on pub.dev (D6, D8, D9)

**Files:**
- Modify: `tool/ci/host_probe/pubspec.yaml.in`, `tool/ci/host_probe.sh`, `tool/ci/host_probe/lib/main.dart`, `tool/ci/host_probe/.gitignore`, `docs/host-guide.md` (§1 and a new subsection after §1's text, "The restaurant symbols"), `tool/ci/test/guide_test.dart`, `tool/ci/test/scripts_test.dart` (SC14)
- Create: `tool/ci/package_root.dart`, its test case in `scripts_test.dart`

**Interfaces:**
- Consumes: Task 5's `check_host_lock.dart ... --ref <sha>`.
- Produces: `dart run tool/ci/package_root.dart <probe dir> <package>` prints the absolute directory of `<package>` from `<probe dir>/.dart_tool/package_config.json` (its `rootUri`, resolved against the config file), exit 2 with a message when the package is absent.

- [ ] **Step 1: `package_root.dart`, test first**

Add to `scripts_test.dart`:

```dart
  test('SC17 package_root.dart prints a package\'s root from a config',
      () async {
    final dir = Directory.systemTemp.createTempSync('package_root');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.dart_tool').createSync();
    File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync(
        '{"configVersion":2,"packages":[{"name":"a","rootUri":"../x/a",'
        '"packageUri":"lib/"},{"name":"b","rootUri":"file:///abs/b",'
        '"packageUri":"lib/"}]}');
    final a = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'a']);
    expect(a.exitCode, 0);
    // `../x/a` resolves against `.dart_tool/`, so the root is `<dir>/x/a`.
    expect((a.stdout as String).trim(), endsWith('/x/a'));
    expect(Directory((a.stdout as String).trim()).parent.parent.path,
        Directory(dir.path).resolveSymbolicLinksSync());
    final b = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'b']);
    expect((b.stdout as String).trim(), '/abs/b');
    final none = await Process.run('dart', ['run', 'package_root.dart', dir.path, 'c']);
    expect(none.exitCode, 2);
  });
```

Run it — FAIL (no script). Write `tool/ci/package_root.dart`:

```dart
// Prints a package's root directory from a resolved project's
// .dart_tool/package_config.json (publishing spec D6): host_probe.sh
// copies the restaurant library from the package pub resolved.
//
//   dart run tool/ci/package_root.dart <project dir> <package>
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: package_root.dart <project dir> <package>');
    exit(2);
  }
  final config = File('${args[0]}/.dart_tool/package_config.json');
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final p in (json['packages'] as List).cast<Map<String, Object?>>()) {
    if (p['name'] != args[1]) continue;
    final root = config.uri.resolve(p['rootUri'] as String);
    stdout.writeln(root.toFilePath().replaceAll(RegExp(r'/$'), ''));
    return;
  }
  stderr.writeln('${config.path}: no package ${args[1]}');
  exit(2);
}
```

Note the relative `rootUri` resolves against the config file's URI (`.dart_tool/`), so `../x/a` is `<dir>/x/a`. Run SC17 — PASS. Add `package_root.dart` to the analyze and format file lists in `.github/workflows/ci.yml`'s `ci-tools` job and in Task 5 Step 4's command.

- [ ] **Step 2: The template**

`tool/ci/host_probe/pubspec.yaml.in`: header comment rewritten (*"The probe's pubspec … The dependency line a host writes (docs/host-guide.md §1), from pub.dev; the overrides take the four repository packages from git at the commit under test, and check_host_lock.dart --ref proves they did (publishing spec D6)."*). `environment: sdk: ^3.6.0`. Then:

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan: ^0.7.1

flutter:
  uses-material-design: true
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf
  assets:
    - assets/restaurant.jetlib

dependency_overrides:
  jet_cad_2d:
    git:
      url: @URL@
      path: packages/jet_cad_2d
      ref: @REF@
  jet_cad_2d_flutter:
    git:
      url: @URL@
      path: packages/jet_cad_2d_flutter
      ref: @REF@
  jet_cad_floor_plan:
    git:
      url: @URL@
      path: packages/jet_cad_floor_plan
      ref: @REF@
  jet_cad_restaurant_symbols:
    git:
      url: @URL@
      path: packages/jet_cad_restaurant_symbols
      ref: @REF@
```

(No `dependencies:` entry for the restaurant package: the override puts it in the graph, F-11, so the released `main.dart` files that import it still analyse.)

- [ ] **Step 3: `host_probe.sh`**

- The clean line becomes (Review Focus 4: a copy left by an earlier run must not mask a copy step that no longer runs):

```bash
rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock" \
  "$probe/assets/restaurant.jetlib" "$probe/lib/restaurant_names.dart"
```

- The lock check becomes `dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock" --ref "$ref"`.
- After the lock check, before `flutter analyze`:

```bash
# Publishing spec D9: the probe carries the restaurant library as a host
# does, copied from the package pub resolved at this commit, its names'
# import pointed at the planner's barrel.
symbols=$(dart run "$ci/package_root.dart" "$probe" jet_cad_restaurant_symbols)
mkdir -p "$probe/assets"
cp "$symbols/assets/restaurant.jetlib" "$probe/assets/restaurant.jetlib"
sed 's#package:jet_cad_floor_plan/symbol_sources.dart#package:jet_cad_floor_plan/jet_cad_floor_plan.dart#' \
  "$symbols/lib/src/names.dart" > "$probe/lib/restaurant_names.dart"
```

The script has already done `cd "$probe"` by then; the paths above are absolute, so the block works from anywhere. Update the script's header comment: the probe resolves from pub.dev with overrides; the restaurant symbols are copied.

`tool/ci/host_probe/.gitignore`: add `/assets/restaurant.jetlib` and `/lib/restaurant_names.dart` with a comment *"Copied by tool/ci/host_probe.sh from the commit under test (publishing spec D9)."*

`scripts_test.dart` SC14: the expected clean line and lock-check line become the two above; add `final copy = at(r'symbols=$(dart run "$ci/package_root.dart" "$probe" jet_cad_restaurant_symbols)');` and expect `check < copy && copy < analyze`.

- [ ] **Step 4: The probe's `main.dart`**

- Remove `import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';`; add `import 'dart:typed_data';` and `import 'restaurant_names.dart';`; add `rootBundle` to the `package:flutter/services.dart` `show` list.
- Add, at the top level (this exact text goes into the guide, Step 5):

```dart
/// The restaurant library, from this app's own assets (host guide, "The
/// restaurant symbols").
Future<Uint8List> readRestaurantLibrary() async {
  final data = await rootBundle.load('assets/restaurant.jetlib');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

const SymbolLibrarySource restaurantSource = SymbolLibrarySource(
    name: 'restaurant',
    read: readRestaurantLibrary,
    names: restaurantSymbolNames);
```

- The loader: `sources: const [furnitureSymbolSource, restaurantSource],`.
- The header comment: the probe depends on the planner from pub.dev (overridden to the commit under test) and carries the restaurant library as a host does.

- [ ] **Step 5: The host guide**

§1 "The dependency" becomes:

- Opening: *"Add the planner from pub.dev, with `dart pub add jet_cad_floor_plan` or in your pubspec:"* and the YAML block

```yaml
dependencies:
  flutter:
    sdk: flutter
  jet_cad_floor_plan: ^0.7.1
```

  Then: *"The engine (`jet_cad_2d`) and the renderer (`jet_cad_2d_flutter`) come with it, from pub.dev. Import only the planner's barrel, `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`. Anything under `src/` is not API."* Keep the Flutter-floor paragraph (3.44 or later; built and tested with 3.47.6; no build hook, no GPU renderer).
- Removed: the git YAML block, the SHA, *"Why a SHA and not the tag"*, the paragraph on the restaurant package at the tag, and the engine-on-pub.dev sentence added at `1dc167d`.

New subsection, at the end of §1, *"### The restaurant symbols"*, as spec D9: the three steps, with the YAML fragment

```yaml
  assets:
    - assets/restaurant.jetlib
```

(shown exactly so, indented: it is matched by containment after §2's `fonts:` in the probe's template) and the Dart block of Step 4 (the `readRestaurantLibrary` / `restaurantSource` text, verbatim). Then the loader line as the guide's later Dart block shows it (§4's `SymbolLibraryLoader(sources: const [furnitureSymbolSource, restaurantSource])` — change that existing block where it says `restaurantSymbolSource`). Then the two rules: never load the copy with the package's `restaurantSymbolSource`; saved plans do not depend on the library. And where the files come from: the tag `jet_cad_floor_plan-vX.Y.Z` of the planner release you depend on, `packages/jet_cad_restaurant_symbols/assets/restaurant.jetlib` and `packages/jet_cad_restaurant_symbols/lib/src/names.dart` (its import changed to the planner's barrel).

Search the guide for every other mention of `jet_cad_restaurant_symbols`, `restaurantSymbolSource`, `git`, `SHA` and `0fa649e` and bring each in line; check `tool/ci/check_guide.dart` reads only §-blocks the probe has.

- [ ] **Step 6: `guide_test.dart`**

- GD1: `expect(fencedBlocks(guide, 'yaml'), hasLength(3), reason: 'premise: §1\'s dependency, §2\'s fonts, the symbols\' asset');`
- GD3 becomes:

```dart
  test('GD3 a pubspec line the probe does not have is named', () {
    final moved = guide.replaceFirst(
        'jet_cad_floor_plan: ^0.7.1', 'jet_cad_floor_plan: ^0.7.2');
    expect(moved, isNot(guide), reason: 'premise');
    expect(
        missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: dependencies:']);
  });
```

- GD4 becomes:

```dart
  test('GD4 the symbols\' asset line is the probe\'s', () {
    final moved = guide.replaceFirst(
        '    - assets/restaurant.jetlib', '    - assets/symbols.jetlib');
    expect(moved, isNot(guide), reason: 'premise');
    expect(missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: assets:']);
  });
```

Run: `cd tool/ci && dart test && dart run check_guide.dart` (from the repository root for `check_guide.dart`: `dart run tool/ci/check_guide.dart`) — Expected: all pass; *"all N code blocks are in the host probe"*.

- [ ] **Step 7: Commit, then run the probe and the released probes locally**

The probe resolves the commit by git, so commit first, with Step 8's command, then from the repository root:

```bash
rm -rf ~/.pub-cache/git/cache/jet-cad-*
tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"
```

Expected: the lock check prints its two lines with no failure; "No issues found!"; "✓ Built build/web"; the final "host probe: no GPU renderer, no build hook" line. Then `tool/ci/old_host_probe.sh v0.3.0`, `v0.4.0`, `v0.5.1`, `v0.6.0` — each "No issues found!". Then `git status --short` — expected clean (the copied files and the written pubspec are ignored). (The pub git-cache trap: STATUS "Traps".)

Mutant **M-PR1** (Review Focus 3): in a copy of `pubspec.yaml.in`, delete the `jet_cad_2d_flutter:` override block; run `host_probe.sh` against the same commit: it must fail at the lock check naming `jet_cad_2d_flutter` (before 0.7.1 is on pub.dev the resolution itself may fail first — record which; either is red). Restore, `cmp`.

- [ ] **Step 8: The commit (made at the start of Step 7)**

```bash
git add tool/ci docs/host-guide.md .github/workflows/ci.yml
git commit -m "ci,docs: the host probe and the guide on pub.dev (D6, D8, D9)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Commit before Step 7's probe run; amend nothing afterwards: a fix is a new commit and the probe runs again.)

---

### Task 7: Changelogs, STATUS and the results note (D4, D10, D11)

**Files:**
- Modify: `CHANGELOG.md`, `STATUS.md`
- Create: `docs/superpowers/notes/2026-10-13-publish-host-packages-results.md`

- [ ] **Step 1: The root CHANGELOG becomes an index**

Replace its preamble and its *Unreleased* section (both written at `1dc167d`) with:

```markdown
# Changelog

The packages are published on pub.dev, each with its own version, its own
CHANGELOG and its own git tags:

- [`jet_cad_2d`](packages/jet_cad_2d/CHANGELOG.md), the engine
  (`jet_cad_2d-vX.Y.Z`);
- [`jet_cad_2d_flutter`](packages/jet_cad_2d_flutter/CHANGELOG.md), the
  renderer (`jet_cad_2d_flutter-vX.Y.Z`);
- [`jet_cad_floor_plan`](packages/jet_cad_floor_plan/CHANGELOG.md), the
  planner a host depends on (`jet_cad_floor_plan-vX.Y.Z`).

A host depends on the planner from pub.dev (see
[docs/host-guide.md](docs/host-guide.md)). Up to 0.7.0 the packages were
released together, by git, under one version and one tag (`vX.Y.Z`); that
shared history follows, unchanged.
```

Keep every section from `## 0.7.0` down byte for byte (`git diff` shows only the head changed).

- [ ] **Step 2: STATUS**

- The ruling *"The engine's own version"*: rewrite to Decision 4 and D10 — every published package its own version, CHANGELOG and tag; the shared `vX.Y.Z` line ended at `v0.7.0`; `jet_cad_2d_gpu` and `jet_cad_restaurant_symbols` unpublished, untagged; D1's lower-bound rule at a dependent's release.
- The ruling *"The host packages go to pub.dev too"*: point at the spec and this plan; mark the order's second and third steps prepared on this branch.
- *In flight*: this branch, the spec, the plan, the record.
- *Resume here*: the human's checklist of D10, per package in order — `main` pushed and CI green; for a dependent, its lower bounds per D1 and pana's lower-bounds section green; `dart pub publish --dry-run`; `dart pub publish`; the tag (`jet_cad_2d_flutter-v0.7.1`, `jet_cad_floor_plan-v0.7.1`, on the merge commit); the version visible on pub.dev; after the planner, D7: resolve `tool/ci/host_probe` with its `dependency_overrides` block removed (a scratch copy of the template), `flutter analyze`, record the result.
- *Commands*: the dry run for each of the three packages.

- [ ] **Step 3: The results note**

`docs/superpowers/notes/2026-10-13-publish-host-packages-results.md`, in the engine note's shape (`2026-10-13-publish-jet-cad-2d.md`): the request and the rulings (quoted); what each task did and its commit; the dry runs (archive sizes, 0 warnings, exit codes, the Review Focus 1 grep); `dart doc` 6 → 0 and 23 → 0; pana for both packages (each section; the repository check's note); every mutant with its result (M-DL1, M-RX1, M-RX2, M-FX1, M-FX2, M-CI1, M-LK1, M-LK2, M-PR1); the probe and the four released probes; **D4's barrel audit**: for each package, the types in a public signature of a barrel export that the barrel does not export (a rough grep, labelled as such, as in the engine's note); the gates per package; D11's migration steps for the restaurant software; *Owed* (the human's checklist, D7, the CI run on the pushed branch).

- [ ] **Step 4: Full gate and commit**

Every gate of Task 1 Step 6 once more, and `dart pub publish --dry-run` for the three packages on the committed state.

```bash
git add CHANGELOG.md STATUS.md docs/superpowers/notes/2026-10-13-publish-host-packages-results.md
git commit -m "docs: the host packages' publication, recorded (D4, D10, D11)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then the whole-branch independent review (an Opus subagent, no Codex) on `git diff main..HEAD`; its findings are applied as new commits and recorded in the results note.
