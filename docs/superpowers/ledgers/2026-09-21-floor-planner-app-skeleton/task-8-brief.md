### Task 8: The app — shell, view, chrome slots, and the first web build of the package

**Files:**
- Create: `apps/floor_planner/lib/main.dart` (replace the generated one)
- Create: `apps/floor_planner/lib/planner_view.dart`
- Test: `apps/floor_planner/test/planner_shell_test.dart`

**Interfaces:**
- Consumes: `startupPlan`, `kMinScale`, `kMaxScale` (Task 7);
  `CameraGestureDetector`, `GesturePolicy.forPlatform()`, `DraftCanvas`,
  `CameraController`, `ViewportTransform.fit`, `SpatialIndex`,
  `FlutterTextMeasurer`.
- Produces: `FloorPlannerApp`, `PlannerShell`, `PlannerView({required
  document, required index, required camera, required policy})`.

- [ ] **Step 1: Write the failing shell test**

`apps/floor_planner/test/planner_shell_test.dart`:

```dart
import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  testWidgets('the shell shows a canvas over a non-empty, off-origin plan',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    expect(find.byType(DraftCanvas), findsOneWidget);
    expect(find.byType(CameraGestureDetector), findsOneWidget);
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(view.document.extents.minX, greaterThan(0));
    expect(view.camera.minScale, kMinScale);
    expect(view.camera.maxScale, kMaxScale);
  });

  // Ruling 01-2: fitted once to the size the view actually got, so the plan
  // is fully visible and the camera is not the nominal 1440 x 900 fit.
  testWidgets('the camera is fitted to the real viewport on first layout',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final expected = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
  });

  testWidgets('the three chrome slots are laid out and empty', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    for (final key in const [
      Key('chrome-top'),
      Key('chrome-left'),
      Key('chrome-right')
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).width, greaterThan(0));
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart`
Expected: compile error — `FloorPlannerApp` undefined (the generated
`main.dart` has `MyApp`).

- [ ] **Step 3: The view**

`apps/floor_planner/lib/planner_view.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The drawing area: a [CameraGestureDetector] over a [DraftCanvas].
///
/// Tiles off, `backend` unset (spec D6): a floor plan is 500-5,000
/// entities, and the resident backend cannot run on web, which this product
/// targets. Neither is a default a later sub-project may flip without a
/// measurement.
class PlannerView extends StatefulWidget {
  const PlannerView({
    super.key,
    required this.document,
    required this.index,
    required this.camera,
    required this.policy,
  });

  final DraftDocument document;
  final SpatialIndex index;
  final CameraController camera;
  final GesturePolicy policy;

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  /// Ruling 01-2: the camera is fitted once, to the size the view really
  /// got, before the canvas under it has listened to anything.
  bool _fitted = false;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (!_fitted && constraints.biggest.width > 0 &&
              constraints.biggest.height > 0) {
            _fitted = true;
            widget.camera.value = ViewportTransform.fit(
                widget.document.extents, constraints.biggest);
          }
          return CameraGestureDetector(
            camera: widget.camera,
            policy: widget.policy,
            child: DraftCanvas(
              document: widget.document,
              index: widget.index,
              camera: widget.camera,
              tiles: false,
            ),
          );
        },
      );
}
```

- [ ] **Step 4: The app and the shell**

`apps/floor_planner/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'planner_view.dart';
import 'startup_plan.dart';

void main() => runApp(const FloorPlannerApp());

class FloorPlannerApp extends StatelessWidget {
  const FloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Floor planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2266CC)),
        home: const PlannerShell(),
      );
}

/// Owns the document, the index and the camera for the window's lifetime,
/// and lays out the chrome slots -- a top bar, a left panel and a right
/// panel, sized and empty -- so sub-projects 04, 05 and 12 add to a layout
/// rather than invent one.
class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key});

  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  final FlutterTextMeasurer _measurer = FlutterTextMeasurer();
  late final DraftDocument _document = startupPlan(_measurer);
  late final SpatialIndex _index = SpatialIndex(_document);
  // Fitted to the nominal window; PlannerView re-fits once at the real size.
  late final CameraController _camera = CameraController(
    ViewportTransform.fit(_document.extents, const Size(1440, 900)),
    minScale: kMinScale,
    maxScale: kMaxScale,
  );
  final GesturePolicy _policy = GesturePolicy.forPlatform();

  @override
  void dispose() {
    _camera.dispose();
    _index.dispose();
    _measurer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            key: const Key('chrome-top'),
            height: 44,
            color: scheme.surfaceContainer,
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  key: const Key('chrome-left'),
                  width: 240,
                  color: scheme.surfaceContainerLow,
                ),
                Expanded(
                  child: ColoredBox(
                    color: scheme.surface,
                    child: PlannerView(
                      document: _document,
                      index: _index,
                      camera: _camera,
                      policy: _policy,
                    ),
                  ),
                ),
                Container(
                  key: const Key('chrome-right'),
                  width: 280,
                  color: scheme.surfaceContainerLow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the app's line, including both builds**

```sh
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
flutter build macos --debug 2>&1 | tail -3
flutter build web 2>&1 | tail -20
```

Expected: tests PASS, analyze clean, both builds `✓ Built`. **The web build
is spec criterion 2 and the first time `jet_cad_2d_flutter` has been
compiled for web.** If it fails inside the package (a `dart:ffi` or
`dart:io` reach that the `flutter_scene` shim does not cover, or
`gesture_policy_platform_web.dart`), that is a finding about the package:
paste the first error verbatim into the ledger, stop, and report it as the
task's result. Do not patch the package inside this task.

- [ ] **Step 6: Run it, once, and look**

`cd apps/floor_planner && flutter run -d macos` — the window opens at
1440×900, the flat is visible, nothing else is checked here (Task 10 is the
look). Quit.

- [ ] **Step 7: Commit**

```sh
git status --short
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "feat(floor_planner): the shell, the view, three empty chrome slots; builds for macOS and web"
```

---

