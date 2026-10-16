### Task 2: The app's scaffold, the boundary and the chord layer

**Files:**
- Create: `apps/architecture_demo/pubspec.yaml`, `analysis_options.yaml`,
  `lib/main.dart`, `test/boundary_test.dart`, `test/app_shell_test.dart`
- Create: `apps/architecture_demo/macos/**`, `web/**` copied from
  `apps/floor_planner` (not `build/`), renamed
- Modify: root `pubspec.yaml` (`workspace:` gains
  `apps/architecture_demo` after `apps/floor_planner`)

**Interfaces:**
- Produces: `ArchitectureDemoApp` (StatefulWidget) with test seams
  `{DocumentFiles? files, ExitGuard? exitGuard, PagePrinter printer =
  const PrintingPagePrinter()}` — Task 2 creates it with only `printer`;
  Tasks 3-4 add the other two. Its state exposes
  `@visibleForTesting PlanController get controller`.
- Produces: `const Color kAppSeed = Color(0xFF2266CC);`

- [ ] **Step 1: Copy the runners.** `cp -R apps/floor_planner/macos apps/floor_planner/web apps/architecture_demo/` (no `build/`). In `macos/Runner/Configs/AppInfo.xcconfig` set `PRODUCT_NAME = architecture_demo`, `PRODUCT_BUNDLE_IDENTIFIER = dev.jetcad.architectureDemo`; replace `floor_planner` in `Runner.xcscheme`, `project.pbxproj` (`floor_planner.app` → `architecture_demo.app`), `web/index.html` and `web/manifest.json` (names and descriptions: "jet-cad architecture demo"). `grep -rn "floor_planner\|floorPlanner" apps/architecture_demo` must print nothing. Keep `MainFlutterWindow.swift`'s close-button routing (the exit request, Task 5).

- [ ] **Step 2: pubspec.**

```yaml
name: architecture_demo
description: >-
  The architecture kit's demo: the plan library's editor over the
  architecture kit, with the document flows (new, open sample, open, save,
  save as, export, print, exit) on macOS and the web.
publish_to: none
version: 0.0.1
resolution: workspace

environment:
  # The old floor_planner's bounds, for its reasons: printing 5.15 needs
  # Flutter 3.41 and pdf 3.13 needs Dart 3.12 (Flutter 3.44); the sdk
  # bound sets the language version, kept at 3.5 so the formatter's style
  # matches the copied files.
  sdk: ^3.5.0
  flutter: ">=3.44.0"

dependencies:
  file_selector: ^1.1.0
  flutter:
    sdk: flutter
  jet_cad_2d_kit_architecture: ^0.1.0
  jet_cad_2d_plan: ^0.1.0
  # The print wrapper names PdfPageFormat (PagePrinter's signature).
  pdf: ^3.13.1
  web: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

Check the two package versions in their pubspecs and use those. If the
old app declared a font family in `flutter: fonts:` for a reason that
still holds (the web engine fetching Roboto), check whether
`jet_cad_2d_plan` ships its font and `ensurePlanFonts` registers it; add
the family from `packages/jet_cad_2d_plan/...` only if the library's
README or its example app does the same. Write which in the report.

- [ ] **Step 3: analysis_options.yaml:** copy the old app's. Commit it once
  in this task (the one exception).

- [ ] **Step 4: N1, the boundary test (red first).**

```dart
// N1 (spec B6): the app names neither old package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _banned = ['jet_cad_floor_plan', 'jet_cad_restaurant_symbols'];

void main() {
  test('N1 the pubspec and every Dart file name no old package', () {
    final files = <File>[
      File('pubspec.yaml'),
      for (final dir in ['lib', 'test'])
        ...Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
    ];
    final hits = <String>[];
    for (final f in files) {
      if (f.path.endsWith('boundary_test.dart')) continue;
      final text = f.readAsStringSync();
      for (final name in _banned) {
        if (text.contains(name)) hits.add('${f.path}: $name');
      }
    }
    expect(files.length, greaterThan(2), reason: 'the walk found the files');
    expect(hits, isEmpty);
  });
}
```

Mutation M-N1: add `// jet_cad_floor_plan` to `lib/main.dart` → red.

- [ ] **Step 5: main.dart, the shell.** The app owns one controller and
  shows one editor; no host flows yet.

```dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// The app's theme seed, light and dark alike (the old app's).
const Color kAppSeed = Color(0xFF2266CC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ensurePlanFonts();
  } catch (error, stack) {
    // A failed registration is reported, not fatal: the app still starts.
    FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'architecture_demo',
        context: ErrorDescription('while registering the plan font')));
  }
  registerFontLicences();
  runApp(const ArchitectureDemoApp());
}

class ArchitectureDemoApp extends StatefulWidget {
  const ArchitectureDemoApp(
      {super.key, this.printer = const PrintingPagePrinter()});

  /// Where Print hands the page's PDF: the platform's dialog unless a test
  /// gives a fake.
  final PagePrinter printer;

  @override
  State<ArchitectureDemoApp> createState() => ArchitectureDemoAppState();
}

class ArchitectureDemoAppState extends State<ArchitectureDemoApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  /// The app's one controller: New, Open sample and Open replace the plan
  /// inside it, so the editor, its panels and its caches stay.
  late final PlanController _controller =
      PlanController(kits: [architectureKit], symbols: PlanSymbolLoader());

  @visibleForTesting
  PlanController get controller => _controller;

  /// Marks a file chord handled, and does nothing.
  static void _consume() {}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigator,
        title: 'jet-cad',
        debugShowCheckedModeBanner: false,
        supportedLocales: planSupportedLocales,
        localizationsDelegates: planLocalizationsDelegates,
        theme: ThemeData(colorSchemeSeed: kAppSeed),
        darkTheme:
            ThemeData(colorSchemeSeed: kAppSeed, brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        // The file chords once more above the Navigator, consume-only: a
        // dialog's route is outside the editor's focus chain, and on the
        // web an unhandled Cmd/Ctrl+S opens the browser's Save Page. The
        // editor's own bindings run the commands when the home route has
        // the focus.
        builder: (context, child) => CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            for (final chord in kFileChords) chord: _consume,
          },
          child: child!,
        ),
        home: Scaffold(
            body: PlanEditor(controller: _controller, printer: widget.printer)),
      );
}
```

Check `PlanSymbolLoader`'s ownership: if the controller disposes a loader
it was given, keep it; if not, the app disposes it after the controller.
Read `PlanController.dispose` and say which in the report.

- [ ] **Step 6: app_shell_test.dart.**
  - AS1: the app pumps; one `PlanEditor`; the Symbols tab exists (the
    kit's furniture); `controller.dirty.value` is false. Mutation: build
    the controller with `kits: []` (the Symbols tab disappears).
  - CH-consume (Review Focus 5): open a dialog over the home route
    (`showDialog` with a `TextField`), send Meta+S and Control+S; the key
    event result is handled (`tester.sendKeyEvent` returns true) and the
    controller's `save` is not reached (nothing written; there is no host
    yet, so assert no exception and the dialog still up). Mutation: drop
    the `builder:` layer → the key is not handled.
  - AS-dispose: unmount the app (pump `SizedBox()`); no "used after
    dispose" error. Mutation: dispose the controller in `deactivate`.

- [ ] **Step 7:** `flutter pub get` at the repo root (it rewrites three
  `analysis_options.yaml`; never stage those), then the app's gates, then
  `flutter build macos --debug` and `flutter build web` once (paste their
  last lines into the report).

- [ ] **Step 8: Commit** `feat(demo): scaffold apps/architecture_demo on the plan library and the architecture kit`.

---

