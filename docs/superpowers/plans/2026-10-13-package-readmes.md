# The published packages' READMEs, screenshots and funding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `jet_cad_2d`, `jet_cad_2d_flutter` and `jet_cad_floor_plan` 0.7.2 with READMEs that link the three packages and the host guide, screenshots of the renderer's and the planner's widgets produced by a command in the repository, funding links, every README snippet analysed by CI, and R-10's two exports.

**Architecture:** A new unpublished Flutter package `tool/screenshots` pumps eleven scenes built from the packages' public widgets with real fonts and writes PNGs into each package's `doc/screenshots/` when `UPDATE_SCREENSHOTS=1`; without it (CI) it renders the same scenes and compares no pixels. Two pure-Dart checks in `tool/ci` hold the rest: `check_screenshots.dart` (pub.dev's `screenshots:` rules, the budget, tag-pinned README image URLs) and `check_readmes.dart` (every README `dart` block is in `tool/readme_probe`, which CI analyses).

**Tech Stack:** Dart 3.13 / Flutter 3.47.6, pub workspaces, `flutter_test` (`RenderRepaintBoundary.toImage`, `FontLoader`), `package:yaml`, GitHub Actions, `dart pub publish --dry-run`.

**Spec:** [docs/superpowers/specs/2026-10-13-package-readmes-design.md](../specs/2026-10-13-package-readmes-design.md) (revision 1, approved by the human on 2026-10-13, with amendments A1–A4). Read it before any task: every task cites its D-sections.

## Global Constraints

- Versions: `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` at `0.7.2`; every live-line dependency on them `^0.7.2` (D10, from Task 7 on; `^0.7.1` before).
- Funding, verbatim, in the three published pubspecs: `https://github.com/sponsors/a-urel`, `https://buymeacoffee.com/yazemo` (D3). `.github/FUNDING.yml`: `github: a-urel`, `buy_me_a_coffee: yazemo`.
- The engine's README has **no image** (spec Decision 6).
- Screenshots: renderer R1–R5, planner P1–P6, files and order as spec D5; each PNG ≤ 1 MB, each package's total ≤ 4 MB, descriptions 10–160 characters, ≤ 10 entries (D6, D7).
- README image URLs: `https://raw.githubusercontent.com/a-urel/jet-cad/<package>-v0.7.2/packages/<package>/doc/screenshots/<file>` — absolute, tag-pinned (D6).
- Scenes use the barrels; `package:jet_cad_floor_plan/editor.dart` only for `startupPlan`, `symbolThumbnailDocument`, `searchSymbols`, `SymbolWords`, `symbolIdOf` (spec D4, A2).
- The generator never compares pixels (D4). The standing failure and skip lists do not change.
- Never run `dart pub publish` without `--dry-run`. Never push, tag or merge: the human's word only.
- **Never commit `analysis_options.yaml`.** Check `git status --short` after every pub operation.
- Never synthesize test output; quote what commands print. Never `git checkout` a file to revert a mutation: copy it aside, restore from the copy, `cmp`.
- Code, comments and commit messages in English; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Every task ends green: the CLAUDE.md gate of each package it touches; for `tool/ci`: `cd tool/ci && dart test`, plus `dart run tool/ci/check_guide.dart` from the root.
- Worktree-guarded sessions refuse bash loops and `$VAR` pipelines: run commands one by one.

## Review Focus

1. **A screenshot test that writes when CI runs it** would dirty the checkout and hide the "compare no pixels" rule. Pinned in Task 2, Step 4: without `UPDATE_SCREENSHOTS=1` the harness writes nothing (SH3 checks the files' modification times are untouched).
2. **Ahem or tofu in a published picture**: a scene pumped before the fonts load, or MaterialIcons missing, draws grey boxes that look like a layout. Pinned in Task 2 (FT1, FT2, with mutations M-FT1, M-FT2) and Task 3/4's eyes-on step, which looks at every PNG before committing it.
3. **A README image that resolves on `main` but not at the tag** (or the reverse): the tag is pushed only at publication. Pinned in Task 5 (SS9, SS10: a `main` ref and a `-v0.7.1` ref are red).
4. **The engine's README gaining an image** through a shared template edit. Pinned in Task 5 (SS12: any image in `jet_cad_2d/README.md` is red).
5. **A `.pubignore`d screenshot**: pub.dev rejects the upload, the dry run says nothing. Pinned in Task 5 (SS6) and Task 8, Step 9 (the dry-run listing grepped for every PNG).

---

### Task 1: R-10 — the planner exports `SymbolLibraryState` and `TableNumberProblem` (D9, A4)

**Files:**
- Modify: `packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart` (the export list, near line 64)
- Modify: `packages/jet_cad_floor_plan/test/host/barrel_test.dart` (B1's set; a new test)
- Modify: `docs/host-guide.md:155-164` (the `FloorPlanStrings` bullet)

**Interfaces:**
- Produces: `SymbolLibraryState`, `SymbolLibraryLoading`, `SymbolLibraryReady`, `SymbolLibraryFailed`, `TableNumberProblem` on `package:jet_cad_floor_plan/jet_cad_floor_plan.dart`. Task 3 relies on `SymbolLibraryReady` from the barrel.

- [ ] **Step 1: Write the failing test.** In `barrel_test.dart`, add the five names to B1's expected set, and add:

```dart
  test('B-R10 the library state and the number problem through the barrel',
      () {
    // An exhaustive switch over the sealed family and every enum value:
    // dropping either export (M-R10a, M-R10b) is a compile error here.
    String word(SymbolLibraryState s) => switch (s) {
          SymbolLibraryLoading() => 'loading',
          SymbolLibraryReady() => 'ready',
          SymbolLibraryFailed() => 'failed',
        };
    expect(word(const SymbolLibraryLoading()), 'loading');
    expect(TableNumberProblem.values.map((p) => p.name).toList(),
        ['length', 'control']);
  });
```

- [ ] **Step 2: Run it to see it fail.** `cd packages/jet_cad_floor_plan && flutter test test/host/barrel_test.dart`. Expected: compile errors naming `SymbolLibraryState` and `TableNumberProblem` (undefined).

- [ ] **Step 3: Add the exports** after the `symbol_library_loader.dart` export:

```dart
export 'src/symbols/symbol_library_state.dart'
    show
        SymbolLibraryState,
        SymbolLibraryLoading,
        SymbolLibraryReady,
        SymbolLibraryFailed;
```

and, keeping the file's order by path, `export 'src/tables/table_numbers.dart' show TableNumberProblem;`.

- [ ] **Step 4: Run it to see it pass.** Same command: all tests passed.

- [ ] **Step 5: Mutations.** Copy the barrel aside; remove the `symbol_library_state` export (M-R10a): B-R10 fails to compile; restore, `cmp`. Remove the `table_numbers` export (M-R10b): same; restore, `cmp`. Record both outputs' first error line for the results note.

- [ ] **Step 6: The guide.** Replace the bullet's last sentence (lines 161–164) with: "A class that implements or directly extends `FloorPlanStrings` must also write the abstract `tableNumberProblem(TableNumberProblem)`; the barrel exports `TableNumberProblem` since 0.7.2." The guide gains no code block, so the probe does not change. Run `dart run tool/ci/check_guide.dart` from the root: green.

- [ ] **Step 7: Gate and commit.** The planner's gate (CLAUDE.md, `--enable-vmservice` as CI runs it, compared with `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan <report>`), then:

```bash
git add packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart packages/jet_cad_floor_plan/test/host/barrel_test.dart docs/host-guide.md
git commit -m "feat(floor_plan): export SymbolLibraryState and TableNumberProblem (R-10)"
```

---

### Task 2: `tool/screenshots` — the package, real fonts, the capture harness (D4)

**Files:**
- Create: `tool/screenshots/pubspec.yaml`, `tool/screenshots/README.md`
- Create: `tool/screenshots/test/support/shots.dart`
- Create: `tool/screenshots/test/harness_test.dart`
- Modify: `pubspec.yaml` (root workspace list)
- Modify: `.github/workflows/ci.yml` (the `package` matrix)
- Modify: `tool/ci/test/dependency_lines_test.dart` (`pubspecs`, DL2's count)

**Interfaces:**
- Produces (`test/support/shots.dart`): `const Size kWide = Size(1280, 800)`, `const Size kPanel = Size(480, 800)`, `double kRatio` (1.5 until Task 3 measures), `bool get updating`, `Future<void> loadManifestFonts()`, `Future<void> pumpScene(WidgetTester tester, Widget scene, {Size size = kWide})`, `Future<void> settle(WidgetTester tester, {bool Function()? until})`, `Future<Uint8List> shoot(WidgetTester tester, {required String package, required String file, Size size = kWide})`.

- [ ] **Step 1: Record the archives before.** From each package directory: `dart pub publish --dry-run`. Copy each "Total compressed archive size" line into a scratch note for the results note (expected: the engine near 228 KB; take what it prints).

- [ ] **Step 2: The package.** `tool/screenshots/pubspec.yaml`:

```yaml
name: jet_cad_screenshots
description: >-
  The published packages' screenshots (package READMEs spec D4): eleven
  scenes over the packages' public widgets, written into each package's
  doc/screenshots/ with UPDATE_SCREENSHOTS=1. Not a product package.
publish_to: none
version: 0.1.0
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.44.0"

dev_dependencies:
  flutter:
    sdk: flutter
  flutter_test:
    sdk: flutter
  jet_cad_2d: ^0.7.1
  jet_cad_2d_flutter: ^0.7.1
  jet_cad_floor_plan: ^0.7.1
  jet_cad_restaurant_symbols:
    path: ../../packages/jet_cad_restaurant_symbols
  vector_math: ^2.2.0

flutter:
  uses-material-design: true
  # As a host declares it (host guide §2): the planner's bytes under the
  # bare family the plans name.
  fonts:
    - family: Roboto
      fonts:
        - asset: packages/jet_cad_floor_plan/fonts/Roboto-Regular.ttf
```

Add `  - tool/screenshots` to the root `pubspec.yaml`'s `workspace:` list (after `tool/ci`). `README.md`: three lines — what the package is, the command `cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test`, and "look at every PNG before committing it". Run `flutter pub get` at the root; `git status --short` must show no `analysis_options.yaml`.

- [ ] **Step 3: The harness.** `test/support/shots.dart`:

```dart
// The screenshots' harness (package READMEs spec D4): real fonts, a fixed
// logical size and ratio, a capture of the scene's boundary, and a write
// only under UPDATE_SCREENSHOTS=1. No pixel is ever compared.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Size kWide = Size(1280, 800);
const Size kPanel = Size(480, 800);

/// Device pixels per logical pixel (spec D6): 1.5 unless a file exceeds
/// the budget; Task 3 measures and records the choice.
const double kRatio = 1.5;

const Key _shot = ValueKey('screenshot');

bool get updating => Platform.environment['UPDATE_SCREENSHOTS'] == '1';

/// Every family of the test bundle's font manifest, Roboto and
/// MaterialIcons among them, through [FontLoader]: flutter_test draws Ahem
/// otherwise.
Future<void> loadManifestFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Pumps [scene] alone in a boundary of [size] at [kRatio].
Future<void> pumpScene(WidgetTester tester, Widget scene,
    {Size size = kWide}) async {
  tester.view.physicalSize = size * kRatio;
  tester.view.devicePixelRatio = kRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _shot, child: scene));
}

/// Lets real asynchronous work (asset reads, thumbnails) finish, frame by
/// frame, until [until] holds or forty rounds pass, then past animations.
Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
  for (var i = 0; i < 40 && !(until?.call() ?? false); i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump();
  }
  if (until != null) expect(until(), isTrue, reason: 'the scene settled');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The scene as PNG bytes; written to the package's doc/screenshots/ only
/// when [updating].
Future<Uint8List> shoot(WidgetTester tester,
    {required String package, required String file, Size size = kWide}) async {
  expect(tester.takeException(), isNull, reason: 'the scene threw');
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final png = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kRatio);
    expect(image.width, (size.width * kRatio).round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
  if (updating) {
    await tester.runAsync(() async {
      final out = File('../../packages/$package/doc/screenshots/$file');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(png);
    });
  }
  return png;
}
```

- [ ] **Step 4: The harness's own tests**, `test/harness_test.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'support/shots.dart';

void main() {
  setUpAll(loadManifestFonts);

  test('FT1 Roboto is a real face, not Ahem', () {
    // Ahem advances every glyph one em: "Mi" at 20 px is 40 px wide.
    final painter = TextPainter(
        text: const TextSpan(
            text: 'Mi', style: TextStyle(fontFamily: 'Roboto', fontSize: 20)),
        textDirection: TextDirection.ltr)
      ..layout();
    expect(painter.width, isNot(40.0));
    expect(painter.width, inInclusiveRange(15.0, 35.0));
  });

  testWidgets('FT2 a Material icon inks a glyph, not a box', (tester) async {
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: RepaintBoundary(
                key: ValueKey('icon'),
                child: Icon(Icons.add, size: 100, color: Color(0xFF000000))))));
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('icon')));
    final inked = (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var n = 0;
      for (var i = 3; i < raw.lengthInBytes; i += 4) {
        if (raw.getUint8(i) > 128) n++;
      }
      final all = image.width * image.height;
      image.dispose();
      return n / all;
    }))!;
    // A plus covers a fraction of its box; Ahem's tofu covers all of it.
    expect(inked, inExclusiveRange(0.02, 0.6));
  });

  testWidgets('SH3 without UPDATE_SCREENSHOTS nothing is written',
      (tester) async {
    if (updating) return; // the generator's own run writes, by design
    final dir = Directory('../../packages/jet_cad_floor_plan/doc/screenshots');
    final before = dir.existsSync()
        ? {for (final f in dir.listSync()) f.path: f.statSync().modified}
        : const <String, DateTime>{};
    await pumpScene(tester, const ColoredBox(color: Color(0xFFFFFFFF)));
    await shoot(tester, package: 'jet_cad_floor_plan', file: 'probe.png');
    expect(File('${dir.path}/probe.png').existsSync(), isFalse);
    final after = dir.existsSync()
        ? {for (final f in dir.listSync()) f.path: f.statSync().modified}
        : const <String, DateTime>{};
    expect(after, before);
  });
}
```

- [ ] **Step 5: Run and mutate.** `cd tool/screenshots && flutter test`: FT1, FT2, SH3 pass. M-FT1/M-FT2: comment out `setUpAll(loadManifestFonts)`; FT1 and FT2 must fail (quote the failures); restore from the copy. M-SH3: make `updating` return `true` unconditionally; SH3 must fail (it finds `probe.png`); restore, delete any `probe.png` written, `cmp`. **If FT2 fails with fonts loaded** (MaterialIcons not in the manifest), apply the spec's fallback: in `loadManifestFonts`, when no family `MaterialIcons` was loaded, read `${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf` and fail with a message naming the path when it is missing; record which route held.

- [ ] **Step 6: CI and the dependency lines.** In `ci.yml`'s `package` matrix add, after `apps/restaurant_demo`:

```yaml
          - package: tool/screenshots
            tool: flutter
```

In `dependency_lines_test.dart` add `'../../tool/screenshots/pubspec.yaml'` to `pubspecs` and raise DL2's count by 3 (its three hosted lines), updating the reason's text. `cd tool/ci && dart test`: green.

- [ ] **Step 7: Gate and commit.** `cd tool/screenshots && flutter analyze && dart format --output=none --set-exit-if-changed .`; `git status --short` (no `analysis_options.yaml`); commit the package, root pubspec, ci.yml and the test: `git commit -m "feat(tool): the screenshots package, real fonts and the capture harness"`.

---

### Task 3: The planner's scenes P1–P6 (D5, A1)

**Files:**
- Create: `tool/screenshots/test/planner_scenes_test.dart`
- Create: `packages/jet_cad_floor_plan/doc/screenshots/{design_light,design_dark,service_status,service_dark_focus,service_band,service_colors}.png` (generated)

**Interfaces:**
- Consumes: Task 2's harness; Task 1's `SymbolLibraryReady` on the barrel.

- [ ] **Step 1: The scenes**, one `testWidgets` each, sharing:

```dart
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';

import 'support/shots.dart';

const _package = 'jet_cad_floor_plan';

/// The restaurant demo's Salon (apps/restaurant_demo/assets/plans), read
/// from the repository: one source for the demo and the pictures.
final String _salon =
    File('../../apps/restaurant_demo/assets/plans/salon.json')
        .readAsStringSync();

/// The demo's statuses (DemoHomeState.kStatuses), by table number.
final Map<String, TableStatus> _statuses = {
  '1': TableStatus(color: const Color(0x99FFB300)),
  '2': TableStatus(color: const Color(0x9943A047)),
  '4': TableStatus(color: const Color(0x99E53935), caption: 'Bill'),
  '8': TableStatus(color: const Color(0x9943A047)),
  '10': TableStatus(color: const Color(0x99FFB300)),
};

/// A POS-like look from public fields (the demo's own theme is app code).
const FloorPlanTheme _pos = FloorPlanTheme(
  groupChipRadius: 6,
  selectionWidth: 3,
  focusVeilOpacity: 0.75,
  serviceBarHeight: 52,
);

Future<FloorPlanController> _controller(WidgetTester tester) async {
  final symbols = SymbolLibraryLoader(
      sources: const [furnitureSymbolSource, restaurantSymbolSource]);
  final controller = FloorPlanController(symbols: symbols, json: _salon);
  addTearDown(controller.dispose);
  return controller;
}

Widget _app(FloorPlanController controller,
        {Brightness brightness = Brightness.light,
        FloorPlanTheme? theme,
        FloorPlanFloorDrag floorDrag = FloorPlanFloorDrag.pan}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness),
      supportedLocales: floorPlanSupportedLocales,
      localizationsDelegates: floorPlanLocalizationsDelegates,
      home: Scaffold(
          body: FloorPlanView(
              controller: controller, theme: theme, floorDrag: floorDrag)),
    );

Future<void> _ready(WidgetTester tester, SymbolLibraryLoader symbols) =>
    settle(tester, until: () => symbols.state is SymbolLibraryReady);
```

`setUpAll(() async { await loadManifestFonts(); await ensureFloorPlanFonts(); })`. If `FloorPlanController` does not expose its loader, keep the `SymbolLibraryLoader` in a local and pass it to `_ready`. Scenes:
- **P1** `design_light.png`: `_app(c)`, design mode (the default), `_ready`, `shoot`.
- **P2** `design_dark.png`: as P1 with `brightness: Brightness.dark`.
- **P3** `service_status.png`: `c.setMode(FloorPlanMode.selection)`, `c.setTableStatus(_statuses)`, `c.setTableGroups({'party': TableGroup(members: {'6', '7'}, label: 'Party of 8')})`.
- **P4** `service_dark_focus.png`: dark, `theme: _pos`, selection mode, `_statuses`, `c.setTableFocus({'8', '9', '10', '11'})`.
- **P5** `service_band.png`: light, selection mode, `floorDrag: FloorPlanFloorDrag.band`; a mouse gesture from a floor point right of tables 3–5 to a point left of them (right to left: a crossing band): `final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse); await g.moveTo(to); await tester.pump();` then `shoot`, then `await g.up()`. Take `from`/`to` from `c.worldToGlobal` of world points read off the plan, or from fractions of `c.canvasRect.value`, so the band crosses three tables and starts on the floor.
- **P6** `service_colors.png`: light, selection mode, `c.setTablesColor({'1': FloorPlanColor.blue, '2': FloorPlanColor.blue, '3': FloorPlanColor.teal, '6': FloorPlanColor.purple, '7': FloorPlanColor.purple, '9': FloorPlanColor.orange})`.

Table numbers 1–11 are the Salon's (`kDemoZones` in `apps/restaurant_demo/lib/main.dart`); if a number is not on the plan, `setTableStatus` ignores it — check with `c.tables`/`tableAt` and pick numbers that are.

- [ ] **Step 2: Run without writing.** `cd tool/screenshots && flutter test test/planner_scenes_test.dart`: six passed, `git status --short` shows nothing new.

- [ ] **Step 3: Generate and look.** `UPDATE_SCREENSHOTS=1 flutter test test/planner_scenes_test.dart`. Open each PNG (Read tool) and check: real text and icons (no grey boxes), the plan fitted and fully visible, statuses/captions/group chip/veil/band/colours as the scene names. Adjust scenes until each reads at a glance; never edit a PNG.

- [ ] **Step 4: Measure.** `ls -l packages/jet_cad_floor_plan/doc/screenshots/`. If any file exceeds 1 MB or the six exceed 4 MB, set `kRatio = 1.0`, regenerate, re-measure. Record the ratio and the six sizes for the results note.

- [ ] **Step 5: Commit** the test and the six PNGs: `git commit -m "feat(tool): the planner's six scenes and their screenshots"`.

---

### Task 4: The renderer's scenes R1–R5 (D5, A3)

**Files:**
- Create: `tool/screenshots/test/support/renderer_stage.dart`
- Create: `tool/screenshots/test/renderer_scenes_test.dart`
- Create: `packages/jet_cad_2d_flutter/doc/screenshots/{canvas_light,canvas_dark,selection_grips,selection_band,symbol_gallery}.png` (generated)

**Interfaces:**
- Consumes: Task 2's harness.
- Produces: `RendererStage({required DraftDocument document, required bool dark})` with a `GlobalKey<RendererStageState>` exposing `selection` (`SelectionController`) and `camera`.

- [ ] **Step 1: The stage**, the renderer's public widgets composed as `PlannerView` composes them (`packages/jet_cad_floor_plan/lib/src/planner_view.dart:334-440`), with no planner widget:

```dart
// The renderer's widgets alone (spec D5 R1-R4): a ruler frame around an
// interaction layer over the page chrome, the canvas and the selection
// overlay, light or on the dark canvas.
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

class RendererStage extends StatefulWidget {
  const RendererStage(
      {super.key, required this.document, required this.dark, required this.canvas});

  final DraftDocument document;
  final bool dark;

  /// The canvas's size inside the rulers, fitted once (a known size: no
  /// fit during layout).
  final Size canvas;

  @override
  State<RendererStage> createState() => RendererStageState();
}

class RendererStageState extends State<RendererStage> {
  late final SpatialIndex index = SpatialIndex(widget.document);
  late final SelectionController selection =
      SelectionController(widget.document);
  late final OutlineCache outlines = OutlineCache(widget.document, selection);
  late final PageNotifier page = PageNotifier(widget.document);
  late final CameraController camera = CameraController(
      ViewportTransform.fit(widget.document.extents.expandedBy(500), widget.canvas));
  late final ToolController tools = ToolController(
      initial: SelectTool(),
      context: ToolContext(
          document: widget.document,
          index: index,
          camera: camera,
          selection: selection));

  @override
  void dispose() {
    tools.dispose();
    outlines.dispose();
    page.dispose();
    camera.dispose();
    selection.dispose();
    index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paperArgb = widget.dark ? kDarkCanvasPaper : 0xFFFFFFFF;
    final paper = widget.dark ? PaperPalette.dark : PaperPalette.light;
    return ColoredBox(
      color: Color(paperArgb),
      child: RulerFrame(
        camera: camera,
        page: page,
        chrome: widget.dark ? ChromePalette.dark : ChromePalette.light,
        child: InteractionLayer(
          tools: tools,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PageChromePainter(
                  camera: camera,
                  page: page,
                  chrome: widget.dark ? ChromePalette.dark : ChromePalette.light,
                  paper: paper,
                  sheetArgb: widget.dark ? kDarkCanvasPaper : null,
                  repaint: Listenable.merge([camera, page]),
                ),
              ),
            ),
            DraftCanvas(
              document: widget.document,
              index: index,
              camera: camera,
              resolver: canvasResolverFor(widget.document,
                  paper: paperArgb, dark: widget.dark),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: SelectionOverlayPainter(
                  selection: selection,
                  tools: tools,
                  camera: camera,
                  outlines: outlines,
                  paper: paper,
                  repaint: Listenable.merge([selection, tools, camera, outlines]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
```

Every name above is on `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` except those the analyzer reports: for each one it reports, read the barrel and use the exported name; if one is not exported, stop and record it (the stage may only use public API). How `PlannerShell` wires the dark canvas is at `planner_shell.dart:327-343` and `:1509-1515`; follow it where this stage differs. If the fitted page sits poorly, fit to the page sheet's bounds instead of `extents`.

- [ ] **Step 2: The scenes**, `renderer_scenes_test.dart`; the document is `startupPlan(FlutterTextMeasurer())` (`package:jet_cad_floor_plan/editor.dart`); the canvas size is `kWide` minus the rulers (`kRulerThickness` if the barrel exports it, else 24, with a premise `expect(tester.getSize(find.byType(DraftCanvas)), canvas)`):
- **R1** `canvas_light.png`: the stage, light.
- **R2** `canvas_dark.png`: `dark: true`, inside `Theme(data: ThemeData(brightness: Brightness.dark))`.
- **R3** `selection_grips.png`: light; a mouse drag left to right (a window) around a few walls and furniture, released, so the selection shows its grips; then a mouse hover (`tester.createGesture(kind: PointerDeviceKind.mouse)`, `addPointer`, `moveTo`) over one more entity; `pump`; `shoot`.
- **R4** `selection_band.png`: light; a mouse drag right to left (a crossing band), held: `startGesture`, `moveTo`, `pump`, `shoot`, `up`.
- **R5** `symbol_gallery.png`, at `kPanel`: the furniture library loaded with `SymbolLibraryLoader(sources: const [furnitureSymbolSource])` (`await tester.runAsync(loader.load)`, then `loader.state as SymbolLibraryReady`), grouped as `SymbolPanel._ready` does (`symbol_panel.dart:227-275`):

```dart
final words = SymbolWords.english;
final groups = searchSymbols(library.entries, '', words);
final measurer = FlutterTextMeasurer();
final thumbnails = SymbolThumbnails(maxEntries: 128);
addTearDown(thumbnails.dispose); // if SymbolThumbnails has no dispose, drop this line
final gallery = SymbolGallery(
  categories: [
    for (final g in groups)
      GalleryCategory(
        id: g.category,
        name: words.category(g.category),
        symbols: [
          for (final e in g.symbols)
            GallerySymbol(
              id: symbolIdOf(e),
              label: words.name(e),
              thumbnailKey: symbolIdOf(e),
              thumbnailDocument: () => symbolThumbnailDocument(e, measurer),
            ),
        ],
      ),
  ],
  selectedId: null,
  enabled: true,
  onSelect: (_) {},
  thumbnails: thumbnails,
  foreground: const Color(0xFF1F1F1F),
  selectedForeground: const Color(0xFF0B57D0),
  cellColor: const Color(0xFFFFFFFF),
);
```

inside a `MaterialApp(home: Material(child: gallery))`; `settle` until the thumbnails have painted (pump rounds; there is no state to wait on, so forty rounds and an eyes-on check).

- [ ] **Step 3: Run without writing**, then **generate and look**, as Task 3 Steps 2–3, for the five files.

- [ ] **Step 4: Measure** as Task 3 Step 4 (one ratio for both packages: if the renderer's files force 1.0, regenerate the planner's too and say so).

- [ ] **Step 5: Gate and commit.** `flutter test`, `flutter analyze`, format in `tool/screenshots`; commit the stage, the test and the five PNGs: `git commit -m "feat(tool): the renderer's five scenes and their screenshots"`.

---

### Task 5: `check_screenshots.dart` (D7)

**Files:**
- Modify: `tool/ci/pubspec.yaml` (`dependencies: yaml: ^3.1.3`)
- Create: `tool/ci/lib/screenshots.dart`
- Create: `tool/ci/check_screenshots.dart`
- Create: `tool/ci/test/screenshots_test.dart`
- Modify: `.github/workflows/ci.yml` (`ci-tools`: analyze and format lists, a new step)

**Interfaces:**
- Produces: `List<String> screenshotProblems({required String package, required String pubspec, required String readme, required String pubignore, required int? Function(String path) sizeOf})` — `sizeOf` returns the file's byte count or null when missing; `List<String> imagelessProblems(String readme)`.

- [ ] **Step 1: Write the failing tests**, `tool/ci/test/screenshots_test.dart`, over an in-memory fixture:

```dart
import 'package:jet_cad_ci/screenshots.dart';
import 'package:test/test.dart';

const _pkg = 'jet_cad_2d_flutter';
const _ignore = '/test/\n/build/\n/shaders/\n';
/// The package's directory at its release tag; a README URL is this plus
/// the screenshot's path.
const _url = 'https://raw.githubusercontent.com/a-urel/jet-cad/'
    'jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter';

String pubspec(List<(String, String)> shots, {String version = '0.7.2'}) => [
      'name: $_pkg',
      'version: $version',
      'screenshots:',
      for (final (d, p) in shots) ...["  - description: '$d'", '    path: $p'],
    ].join('\n');

String readme(Iterable<String> paths, {String base = _url}) =>
    paths.map((p) => '![$p]($base/$p)').join('\n\n');

const _good = [
  ('The canvas with rulers, light.', 'doc/screenshots/a.png'),
  ('The canvas on the dark canvas.', 'doc/screenshots/b.png'),
];

List<String> run({
  List<(String, String)> shots = _good,
  String? md,
  String ignore = _ignore,
  int? Function(String)? sizeOf,
  String version = '0.7.2',
}) =>
    screenshotProblems(
      package: _pkg,
      pubspec: pubspec(shots, version: version),
      readme: md ?? readme(shots.map((s) => s.$2)),
      pubignore: ignore,
      sizeOf: sizeOf ?? (_) => 200 * 1024,
    );

void main() {
  test('SS1 a good set has no problem', () => expect(run(), isEmpty));

  test('SS2 an eleventh entry', () {
    final eleven = [
      for (var i = 0; i < 11; i++) ('Screenshot number $i.', 'doc/s/$i.png')
    ];
    expect(run(shots: eleven), contains(startsWith('11 screenshots')));
  });

  test('SS3 a 9- and a 161-character description', () {
    expect(run(shots: [('123456789', 'doc/s/a.png')]),
        contains(contains('description')));
    expect(run(shots: [('x' * 161, 'doc/s/a.png')]),
        contains(contains('description')));
    expect(run(shots: [('x' * 160, 'doc/s/a.png')]), isEmpty);
    expect(run(shots: [('1234567890', 'doc/s/a.png')]), isEmpty);
  });

  test('SS4 a missing file', () {
    expect(run(sizeOf: (p) => p.endsWith('b.png') ? null : 1),
        contains(contains('missing')));
  });

  test('SS5 a file over 1 MB, a total over 4 MB', () {
    expect(run(sizeOf: (_) => 1024 * 1024 + 1), contains(contains('1 MB')));
    final five = [
      for (var i = 0; i < 5; i++) ('Screenshot number $i.', 'doc/s/$i.png')
    ];
    expect(run(shots: five, sizeOf: (_) => 900 * 1024),
        contains(contains('4 MB')));
  });

  test('SS6 a path the archive leaves out', () {
    expect(run(shots: [('A test screenshot.', 'test/a.png')]),
        contains(contains('.pubignore')));
    expect(run(shots: [('A hidden screenshot.', '.github/a.png')]),
        contains(contains('dot')));
  });

  test('SS7 a path not normalised, or of another type', () {
    expect(run(shots: [('A dotted screenshot.', './doc/a.png')]),
        contains(contains('normalised')));
    expect(run(shots: [('An SVG screenshot.', 'doc/a.svg')]),
        contains(contains('type')));
  });

  test('SS8 a duplicate path', () {
    expect(run(shots: [_good[0], _good[0]]), contains(contains('twice')));
  });

  test('SS9 a README image on main', () {
    final main = _url.replaceFirst('jet_cad_2d_flutter-v0.7.2', 'main');
    expect(run(md: readme(_good.map((s) => s.$2), base: main)),
        contains(contains('tag')));
  });

  test("SS10 a README image on the previous version's tag", () {
    final old = _url.replaceFirst('-v0.7.2', '-v0.7.1');
    expect(run(md: readme(_good.map((s) => s.$2), base: old)),
        contains(contains('tag')));
  });

  test('SS11 a relative README image, an unlisted one, a listed one unshown',
      () {
    expect(
        run(
            md: '![a](doc/screenshots/a.png)\n'
                '${readme(['doc/screenshots/b.png'])}'),
        contains(contains('absolute')));
    expect(
        run(
            md: readme([..._good.map((s) => s.$2), 'doc/screenshots/c.png'])),
        contains(contains('not listed')));
    expect(run(md: readme(['doc/screenshots/a.png'])),
        contains(contains('not in the README')));
  });

  test("SS12 the engine's README has no image", () {
    expect(imagelessProblems('# jet_cad_2d\n\nText.\n'), isEmpty);
    expect(imagelessProblems('![x](https://example.com/x.png)'), isNotEmpty);
    expect(imagelessProblems('<img src="x.png">'), isNotEmpty);
  });

  test('SS13 a .pubignore pattern the reader does not know', () {
    expect(run(ignore: '*.png\n'), contains(contains('pattern')));
  });
}
```

- [ ] **Step 2: Run them to see them fail.** `cd tool/ci && dart test test/screenshots_test.dart`: fails to load (`package:jet_cad_ci/screenshots.dart` not found).

- [ ] **Step 3: Implement** `tool/ci/lib/screenshots.dart`:

```dart
// The screenshots' check (package READMEs spec D7): pub.dev's rules for a
// pubspec's `screenshots:` (pana's 10 entries and 160 characters, the
// upload's 10-character floor, a normalised path in the archive), the
// spec's budget (1 MB a file, 4 MB a package), and the README's images:
// absolute, pinned to the package's release tag, each one listed, each
// listed one shown. `dart pub publish --dry-run` checks none of this.
import 'package:yaml/yaml.dart';

const int maxEntries = 10;
const int maxFileBytes = 1024 * 1024;
const int maxTotalBytes = 4 * 1024 * 1024;
const Set<String> imageTypes = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

final RegExp _markdownImage = RegExp(r'!\[[^\]]*\]\(([^)\s]+)\)');
final RegExp _htmlImage = RegExp(r'<img\s[^>]*src="([^"]+)"');

/// Every image URL of [markdown], Markdown and HTML.
List<String> imageUrls(String markdown) => [
      for (final m in _markdownImage.allMatches(markdown)) m[1]!,
      for (final m in _htmlImage.allMatches(markdown)) m[1]!,
    ];

/// The engine's README must stay without images (spec Decision 6).
List<String> imagelessProblems(String readme) => [
      for (final url in imageUrls(readme)) 'an image in an imageless README: $url'
    ];

/// The directories a package's `.pubignore` leaves out: only root-anchored
/// directory patterns (`/test/`) are read; any other line is a problem, so
/// the check never guesses at a rule it does not implement.
({Set<String> dirs, List<String> problems}) _ignored(String pubignore) {
  final dirs = <String>{};
  final problems = <String>[];
  for (final raw in pubignore.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final m = RegExp(r'^/([\w.-]+)/$').firstMatch(line);
    if (m == null) {
      problems.add('.pubignore: a pattern this check does not read: $line');
    } else {
      dirs.add(m[1]!);
    }
  }
  return (dirs: dirs, problems: problems);
}

bool _normalised(String path) =>
    path.isNotEmpty &&
    !path.startsWith('/') &&
    !path.contains('\\') &&
    !path.contains(':') &&
    path.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');

List<String> screenshotProblems({
  required String package,
  required String pubspec,
  required String readme,
  required String pubignore,
  required int? Function(String path) sizeOf,
}) {
  final yaml = loadYaml(pubspec) as YamlMap;
  final version = yaml['version'] as String;
  final entries = (yaml['screenshots'] as YamlList?)?.cast<YamlMap>().toList() ??
      const <YamlMap>[];
  final problems = <String>[];
  if (entries.isEmpty) problems.add('no screenshots: entry');
  if (entries.length > maxEntries) {
    problems.add('${entries.length} screenshots: pub.dev shows $maxEntries');
  }
  final ignored = _ignored(pubignore);
  problems.addAll(ignored.problems);
  final paths = <String>[];
  var total = 0;
  for (final e in entries) {
    final path = e['path'] as String;
    final description = (e['description'] as String).trim();
    if (paths.contains(path)) problems.add('$path: listed twice');
    paths.add(path);
    if (description.length < 10 || description.length > 160) {
      problems.add('$path: description of ${description.length} characters '
          '(10 to 160)');
    }
    if (!_normalised(path)) {
      problems.add('$path: not a normalised relative path');
      continue;
    }
    final segments = path.split('/');
    if (segments.any((s) => s.startsWith('.'))) {
      problems.add('$path: under a dot directory, never in the archive');
    }
    if (ignored.dirs.contains(segments.first)) {
      problems.add('$path: left out by .pubignore');
    }
    if (!imageTypes.contains(path.split('.').last.toLowerCase())) {
      problems.add('$path: not an image type pub.dev takes');
    }
    final size = sizeOf(path);
    if (size == null) {
      problems.add('$path: missing');
    } else {
      total += size;
      if (size > maxFileBytes) problems.add('$path: $size bytes, over 1 MB');
    }
  }
  if (total > maxTotalBytes) problems.add('$total bytes in all, over 4 MB');

  final base = 'https://raw.githubusercontent.com/a-urel/jet-cad/'
      '$package-v$version/packages/$package/';
  final shown = <String>{};
  for (final url in imageUrls(readme)) {
    if (!url.startsWith('https://')) {
      problems.add('README: $url is not absolute');
    } else if (!url.startsWith(base)) {
      problems.add('README: $url is not on the tag $package-v$version');
    } else {
      final path = url.substring(base.length);
      shown.add(path);
      if (!paths.contains(path)) problems.add('README: $path not listed');
    }
  }
  for (final path in paths) {
    if (!shown.contains(path)) problems.add('$path: not in the README');
  }
  return problems;
}
```

Add `dependencies:` with `yaml: ^3.1.3` to `tool/ci/pubspec.yaml`; `flutter pub get` at the root.

- [ ] **Step 4: Run them to see them pass.** `cd tool/ci && dart test test/screenshots_test.dart`: SS1–SS13 pass. Then three source mutations, each red, restored from a copy and `cmp`ed: M-SS-a (`maxEntries = 11`: SS2 red), M-SS-b (`description.length < 9`: SS3 red), M-SS-c (drop `$package-v$version` from `base` for `main`: SS9 red).

- [ ] **Step 5: The command**, `tool/ci/check_screenshots.dart`:

```dart
// Package READMEs spec D7: the renderer's and the planner's screenshots
// against pub.dev's rules and the spec's budget, and the engine's README
// without an image. Run from anywhere: paths come from the script's place.
//
//   dart run tool/ci/check_screenshots.dart
import 'dart:io';

import 'lib/screenshots.dart';

void main() {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  String read(String path) => File('$repo/$path').readAsStringSync();
  final problems = <String>[];
  for (final package in ['jet_cad_2d_flutter', 'jet_cad_floor_plan']) {
    final dir = 'packages/$package';
    problems.addAll(screenshotProblems(
      package: package,
      pubspec: read('$dir/pubspec.yaml'),
      readme: read('$dir/README.md'),
      pubignore: read('$dir/.pubignore'),
      sizeOf: (path) {
        final f = File('$repo/$dir/$path');
        return f.existsSync() ? f.lengthSync() : null;
      },
    ).map((p) => '$package: $p'));
  }
  problems.addAll(imagelessProblems(read('packages/jet_cad_2d/README.md'))
      .map((p) => 'jet_cad_2d: $p'));
  if (problems.isEmpty) {
    stdout.writeln('screenshots: every rule holds');
    return;
  }
  problems.forEach(stderr.writeln);
  exit(1);
}
```

Run `dart run tool/ci/check_screenshots.dart`: **red** now, naming "no screenshots: entry" for both packages (Task 8 adds them). Quote the output in the task report; this is expected until Task 8.

- [ ] **Step 6: CI.** In `ci-tools`, add `check_screenshots.dart` to the Analyze and Format lists, and after "The host guide's code is the probe's" add:

```yaml
      - name: The screenshots hold pub.dev's rules
        run: dart run tool/ci/check_screenshots.dart
```

- [ ] **Step 7: Gate and commit.** `cd tool/ci && dart test && dart analyze --fatal-infos lib test check_screenshots.dart && dart format --output=none --set-exit-if-changed lib test check_screenshots.dart`; commit: `git commit -m "feat(ci): check_screenshots, pub.dev's screenshot rules and the README's images"`.

---

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

### Task 7: 0.7.2 — versions, constraints, CHANGELOGs, the guide (D10)

**Files:**
- Modify: `packages/{jet_cad_2d,jet_cad_2d_flutter,jet_cad_floor_plan}/pubspec.yaml` (`version`, constraints)
- Modify: every other live-line pubspec naming a published package (the list in `dependency_lines_test.dart`)
- Modify: `packages/*/CHANGELOG.md` (three), `CHANGELOG.md` (root index)
- Modify: `docs/host-guide.md` (§1: the version, `^0.7.2`), `tool/ci/host_probe/pubspec.yaml.in` (`^0.7.2`)
- Modify: `tool/ci/test/dependency_lines_test.dart` (DL2's `'^0.7.2'`, DL3's example), `tool/ci/test/guide_test.dart` (GD3's strings)

- [ ] **Step 1: The tests first.** DL2 expects `'^0.7.2'`; GD3 replaces `'jet_cad_floor_plan: ^0.7.2'` with `'jet_cad_floor_plan: ^0.7.3'`. `cd tool/ci && dart test`: DL2 and GD3 red (quote them).

- [ ] **Step 2: Versions and constraints.** `version: 0.7.2` in the three; every `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_floor_plan` constraint in the live line's pubspecs (including `tool/screenshots` and `tool/readme_probe`) `^0.7.2`; `pubspec.yaml.in`'s line `^0.7.2`; the guide's §1 block and text (line 7 "**0.7.2**", line 24, line 33 "0.7.2 is built and tested with Flutter 3.47.6"); leave every "Since 0.7.0" marker and the schema 10 paragraph's version list (add 0.7.2 to "saved by 0.6.0, 0.7.0 or 0.7.1" at line 2271 and to line 2275's list). `flutter pub get`; `git status --short`.

- [ ] **Step 3: CHANGELOGs.** Each package's file gains, above `## 0.7.1`:
  - engine: `## 0.7.2` — the README links the renderer, the planner and the host guide, and says a host adds only the planner; funding links (GitHub Sponsors, Buy Me a Coffee). No code change; plans are stored as in 0.7.1.
  - renderer: `## 0.7.2` — screenshots (pub.dev gallery and README) of the canvas light and dark, the selection's grips, the crossing band and the symbol gallery; the README's package table and host guide link; funding links; `jet_cad_2d: ^0.7.2`. No code change.
  - planner: `## 0.7.2` — exports `SymbolLibraryState` (`SymbolLibraryLoading`, `SymbolLibraryReady`, `SymbolLibraryFailed`) and `TableNumberProblem` (R-10: a host implementing `FloorPlanStrings` no longer imports `editor.dart`); screenshots of the editor light and dark and of the service view (statuses and a group, a POS theme with a zone in focus, a rubber band, table colours); the README's package table; funding links; `jet_cad_2d: ^0.7.2`, `jet_cad_2d_flutter: ^0.7.2`. Plans are stored as in 0.7.1 (schema 10).
  The root `CHANGELOG.md`'s index names each package's 0.7.2.

- [ ] **Step 4: Green.** `cd tool/ci && dart test` (DL2, GD3 green); `dart run tool/ci/check_guide.dart`; each package's CLAUDE.md gate (the engine's and the renderer's change only pubspecs and CHANGELOGs: their suites must still match the standing lists). Commit, then from each package directory `dart pub publish --dry-run`: "Package has 0 warnings." each (the version bump has its CHANGELOG entry; the tree is committed). Commit: `git commit -m "chore: jet_cad_2d, jet_cad_2d_flutter and jet_cad_floor_plan 0.7.2"`.

---

### Task 8: The READMEs, funding and the screenshots field (D1–D3, D6)

**Files:**
- Modify: `packages/jet_cad_2d/README.md`, `packages/jet_cad_2d_flutter/README.md`, `packages/jet_cad_floor_plan/README.md`, `README.md`
- Create: `.github/FUNDING.yml`
- Modify: the three published pubspecs (`funding:`; `screenshots:` for the renderer and the planner)
- Modify: `tool/readme_probe/lib/*.dart` only if a README's code changes

- [ ] **Step 1: The packages table** (spec D1, verbatim table and sentence) replaces "Where it comes from" in each package README; each gains the host guide link (`https://github.com/a-urel/jet-cad/blob/main/docs/host-guide.md`). The engine's README gains no image.

- [ ] **Step 2: Support**, before "License" in the three package READMEs and the root:

```markdown
## Support

If jet-cad is useful to you, you can support its development through
[GitHub Sponsors](https://github.com/sponsors/a-urel) or
[Buy Me a Coffee](https://buymeacoffee.com/yazemo).
```

- [ ] **Step 3: The root README** per spec D2: the two sentences, the table, "Embedding the floor planner in an app: [docs/host-guide.md](docs/host-guide.md).", Support, then the existing licence text with the OCCT paragraph introduced by "The dormant `packages/jet_cad` line depends on Open CASCADE Technology (OCCT), …".

- [ ] **Step 4: Funding.** In each published pubspec, after `issue_tracker:`:

```yaml
funding:
  - https://github.com/sponsors/a-urel
  - https://buymeacoffee.com/yazemo
```

`.github/FUNDING.yml`:

```yaml
github: a-urel
buy_me_a_coffee: yazemo
```

- [ ] **Step 5: The screenshots field**, after `funding:`. Renderer:

```yaml
screenshots:
  - description: 'A drawing on its sheet, with rulers, drawn by DraftCanvas on a light canvas.'
    path: doc/screenshots/canvas_light.png
  - description: 'The same drawing on the dark canvas, its colours re-toned for a dark theme.'
    path: doc/screenshots/canvas_dark.png
  - description: 'A selection with its grips, and an entity under the mouse highlighted.'
    path: doc/screenshots/selection_grips.png
  - description: 'A crossing selection band, dragged right to left.'
    path: doc/screenshots/selection_band.png
  - description: 'SymbolGallery: a furniture library in collapsible categories of thumbnails.'
    path: doc/screenshots/symbol_gallery.png
```

Planner:

```yaml
screenshots:
  - description: 'FloorPlanView in design mode: tools, symbols, layers and the page, light theme.'
    path: doc/screenshots/design_light.png
  - description: 'Table statuses with captions and a group of tables in the service view.'
    path: doc/screenshots/service_status.png
  - description: 'The editor in a dark theme.'
    path: doc/screenshots/design_dark.png
  - description: 'The service view in a dark POS theme, one zone of tables in focus.'
    path: doc/screenshots/service_dark_focus.png
  - description: 'Rubber-band selection of tables (floorDrag: band).'
    path: doc/screenshots/service_band.png
  - description: 'Tables in plan colours.'
    path: doc/screenshots/service_colors.png
```

(The planner's restaurant tables come from the repository's restaurant symbols, which a host copies per the host guide; say so in the README's Screenshots section, not in the 160 characters.)

- [ ] **Step 6: The images in the READMEs.** Renderer: R1 under the first paragraph; a `## Screenshots` section before "The API" with R2–R5, each with a one-line caption. Planner: P1 under the first paragraph, P3 after "Embedding it"'s first paragraph; `## Screenshots` with P2, P4, P5, P6 and the restaurant symbols sentence. Every URL `https://raw.githubusercontent.com/a-urel/jet-cad/<package>-v0.7.2/packages/<package>/doc/screenshots/<file>`, alt text naming the scene.

- [ ] **Step 7: The checks.** `dart run tool/ci/check_screenshots.dart`: "screenshots: every rule holds". `dart run tool/ci/check_readmes.dart` and `cd tool/readme_probe && flutter analyze`: green. `cd tool/ci && dart test`: green. Mutation M-T8: copy the planner README aside, change one URL's tag to `main`, run `check_screenshots`: red naming it; restore, `cmp`.

- [ ] **Step 8: Commit** README, pubspecs and FUNDING.yml: `git commit -m "docs: the packages' READMEs, screenshots and funding links"`.

- [ ] **Step 9: Dry runs.** From each package directory `dart pub publish --dry-run`: "Package has 0 warnings."; record each "Total compressed archive size". For the renderer and the planner, grep the dry run's file listing for every PNG of `screenshots:` (all present) and for `test/` (absent).

---

### Task 9: The record — results note, STATUS, the full gate

**Files:**
- Create: `docs/superpowers/notes/2026-10-13-package-readmes-results.md`
- Modify: `STATUS.md` (In flight, Resume here, the release checklist), `roadmap/00-README.md` only if its Status table lists releases (check; leave it otherwise)

- [ ] **Step 1: The results note**: what landed per task with commit SHAs; the font route (manifest or fallback); the ratio and every PNG's size; the archive sizes before and after per package; the machine and Flutter that generated the PNGs; every named mutation (M-R10a/b, M-FT1/2, M-SH3, M-SS-a/b/c, M-RM-a/b/c, M-T8) with the line that showed it red; the spec's amendments A1–A4; anything found and not fixed.

- [ ] **Step 2: STATUS.** "In flight": this branch, spec, plan, note. "Resume here": the release checklist of spec D11, in order, each step a command:

```bash
cd packages/jet_cad_2d
dart pub publish --dry-run
dart pub publish
git tag jet_cad_2d-v0.7.2 <merge commit>
git push origin jet_cad_2d-v0.7.2
```

then the renderer and the planner the same way, each preceded by pana's lower-bounds section on the package's archive once its dependencies are on pub.dev, and a note: run from the package directory, never the root ("private package"); if `main` has moved past the merge commit, publish from a worktree at that commit (`git worktree add /tmp/jet-cad-0.7.2 <merge commit>`). After the planner: D7's pub-only probe (STATUS's existing recipe), and a look at the three pages on pub.dev (images, gallery, Funding block).

- [ ] **Step 3: The full gate**, every command run and its last line quoted in the note: the three package gates of CLAUDE.md with the standing comparison; `tool/screenshots` test/analyze/format; `tool/readme_probe` analyze/format; `cd tool/ci && dart test`; `check_guide`, `check_readmes`, `check_screenshots`; three dry runs at 0 warnings; `git status --short` clean, no `analysis_options.yaml` in `git log --name-only main..HEAD`.

- [ ] **Step 4: Commit** the note and STATUS: `git commit -m "docs: package READMEs results and the 0.7.2 release checklist"`.

- [ ] **Step 5: The whole-branch review.** An Opus subagent reviews `main..HEAD` against the spec and this plan (the reviewer verifies claims itself; the note's outputs are claims). Apply its fixes in one wave or rule on each in the note; commit. If the plan ran subagent-driven, archive `.superpowers/sdd/2026-10-13-package-readmes/` to `docs/superpowers/ledgers/2026-10-13-package-readmes/` and commit. Then stop: the merge waits for the human's word.
