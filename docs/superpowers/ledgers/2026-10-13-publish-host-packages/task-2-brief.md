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

