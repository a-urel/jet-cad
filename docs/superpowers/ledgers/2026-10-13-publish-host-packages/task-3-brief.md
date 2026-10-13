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

