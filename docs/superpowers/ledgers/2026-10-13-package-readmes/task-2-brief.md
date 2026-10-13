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

