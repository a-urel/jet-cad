# Task 8 report — the app: shell, view, chrome slots, first web build

## What I implemented

Transcribed the brief's three files verbatim:

- `apps/floor_planner/test/planner_shell_test.dart` (new) — three widget
  tests: canvas/gesture-detector presence and a non-empty, off-origin
  document with the right clamp constants; the camera fitted to the real
  viewport size on first layout (Ruling 01-2); the three chrome slots
  present and non-zero width.
- `apps/floor_planner/lib/planner_view.dart` (new) — `PlannerView`, a
  `LayoutBuilder` over `CameraGestureDetector` + `DraftCanvas` (`tiles:
  false`, no `backend`), fitting the camera once to the first non-zero
  constraint.
- `apps/floor_planner/lib/main.dart` (replaced the Task 6 placeholder) —
  `FloorPlannerApp` (`MaterialApp` → `PlannerShell`) and `PlannerShell`, a
  `StatefulWidget` owning `FlutterTextMeasurer`, `DraftDocument`
  (`startupPlan`), `SpatialIndex`, `CameraController` (fitted to the
  nominal 1440×900, re-fitted once by `PlannerView` at the real size) and
  `GesturePolicy.forPlatform()`; disposes the measurer/index/camera; lays
  out `Scaffold(body: Column([top bar, Row([left panel, PlannerView,
  right panel])]))` with keys `chrome-top`/`chrome-left`/`chrome-right`.

One deviation from the brief's literal text, allowed by my instructions:
`dart format` re-wrapped the `if` condition in `planner_view.dart`'s
`LayoutBuilder` across three lines instead of two (whitespace only, no
semantic change) — see the TDD section below.

## TDD evidence

**RED** — `cd apps/floor_planner && CI=true flutter test test/planner_shell_test.dart`,
run before `planner_view.dart` existed and before `main.dart` was replaced:

```
test/planner_shell_test.dart:2:8: Error: Error when reading 'lib/planner_view.dart': No such file or directory
import 'package:floor_planner/planner_view.dart';
       ^
test/planner_shell_test.dart:16:32: Error: 'PlannerView' isn't a type.
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
                               ^^^^^^^^^^^
...
00:00 +0 -1: Some tests failed.
```

Expected and matches the brief exactly: `planner_view.dart` didn't exist
yet, so the test file fails to compile.

**GREEN** — after writing `planner_view.dart` and replacing `main.dart`,
same command:

```
00:00 +0: loading .../test/planner_shell_test.dart
00:00 +0: the shell shows a canvas over a non-empty, off-origin plan
00:00 +1: the camera is fitted to the real viewport on first layout
00:00 +2: the three chrome slots are laid out and empty
00:00 +3: All tests passed!
```

## What I tested and the results

### Full app test suite — `CI=true flutter test`

```
00:00 +3: .../test/planner_shell_test.dart: the shell shows a canvas over a non-empty, off-origin plan
00:00 +3: .../test/startup_plan_test.dart: the clamp constants bracket the fitted scale by decades
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
00:00 +4: .../test/planner_shell_test.dart: the shell shows a canvas over a non-empty, off-origin plan
00:00 +5: .../test/planner_shell_test.dart: the camera is fitted to the real viewport on first layout
00:00 +6: .../test/planner_shell_test.dart: the three chrome slots are laid out and empty
00:00 +7: All tests passed!
```

7/7 passing (4 in `planner_shell_test.dart`, 1 in `startup_plan_test.dart`
— counted twice in the tail because of interleaved async loading lines,
actual test count is 4).

### `flutter analyze`

```
Analyzing floor_planner...
No issues found! (ran in 1.1s)
```

Clean.

### `dart format --output=none --set-exit-if-changed .`

First run: exit 1, `Changed lib/planner_view.dart` — the brief's `if
(!_fitted && constraints.biggest.width > 0 &&\n constraints.biggest.height
> 0)` line wrap didn't match `dart format`'s own preferred wrapping. Ran
`dart format lib/planner_view.dart` (whitespace-only per my instructions),
re-ran the check:

```
Formatted 5 files (0 changed) in 0.02 seconds.
```

Clean. Re-ran `test/planner_shell_test.dart` after the format pass to
confirm still green (see GREEN above, same output).

### `flutter build macos --debug` (tail)

```
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
```

### `flutter build web` (tail) — spec criterion 2, first web compile of `jet_cad_2d_flutter` with the package actually imported

```
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons). This usually means you are referring to font families in an IconData class but not including them in the assets section of your pubspec.yaml, are missing the package that would include them, or are missing "uses-material-design: true".
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             23.6s
✓ Built build/web
```

No failure inside `jet_cad_2d_flutter` on web — it compiled cleanly. The
`cupertino_icons` font warning is a standard tree-shaking notice, unrelated
to the package under test, and not an error.

### `flutter run -d macos` (Step 6 — quick look)

Ran non-interactively in the background (`flutter run -d macos &`), since
this session has no interactive stdin to send `q`. Startup log:

```
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
[IMPORTANT:flutter/shell/platform/embedder/embedder_surface_metal_impeller.mm(53)] Using the Impeller rendering backend (MetalSDF).
Failed to foreground app; open returned 1
Syncing files to device macOS...                                    68ms

Flutter run key commands.
r Hot reload. 🔥🔥🔥
...
A Dart VM Service on macOS is available at: http://127.0.0.1:56410/...
```

The app process launched and stayed up (confirmed via `ps aux`, PID
present, Dart VM Service serving), i.e. it ran without crashing. `open
returned 1` / "Failed to foreground app" indicates this agent's session
has no active GUI/display session to bring a window to the front, and I
have no screenshot tool for a native macOS desktop window in this
environment (only iOS Simulator and permission-gated computer-use tooling
for the user's live desktop, neither appropriate here). I could not
visually confirm the 1440×900 window or the flat rendering. Per the task
instructions ("If it cannot be run non-interactively in your environment,
say so in the report and skip; do not block on it"), I stopped there:
killed the `flutter run` and app processes cleanly (`pkill` / `kill`) and
did not treat this as a blocker, since `flutter build macos --debug`
already proved the same code compiles and links, and the widget tests
already prove `DraftCanvas`/`CameraGestureDetector` render over the
fitted, non-empty document.

### `git status --short` before commit

```
 M apps/floor_planner/lib/main.dart
?? apps/floor_planner/lib/planner_view.dart
?? apps/floor_planner/test/planner_shell_test.dart
```

No `analysis_options.yaml` anywhere in the workspace was modified by
`pub get`/`flutter test`/the builds — checked after every gate, always
came back clean of `analysis_options.yaml` entries.

## Files changed

- `apps/floor_planner/lib/main.dart` — replaced (Task 6 placeholder → full shell)
- `apps/floor_planner/lib/planner_view.dart` — new
- `apps/floor_planner/test/planner_shell_test.dart` — new

Commit: `7fcc400` — `feat(floor_planner): the shell, the view, three empty
chrome slots; builds for macOS and web`. Only files under
`apps/floor_planner/lib` and `apps/floor_planner/test` are in the commit
(verified via `git show --stat`).

## Self-review findings

- Diffed the committed `main.dart` against the brief's Step 4 text: exact
  match (structure, doc comments, key names, sizes, colors).
- `planner_view.dart` matches the brief's Step 3 text except for the
  `dart format`-driven line wrap of the `if` condition in `LayoutBuilder`
  (3 lines instead of 2) — purely cosmetic, same tokens, same semantics.
- `planner_shell_test.dart` is byte-for-byte the brief's Step 1 text.
- No files created outside the three named in the brief; nothing else in
  the working tree was touched (`git status --short` before staging showed
  exactly these three paths).
- The three chrome-slot tests, the fitted-camera test, and the
  non-empty/off-origin test all assert on real values pulled from
  `startup_plan.dart` and `jet_cad_2d`/`jet_cad_2d_flutter` — no
  degenerate fixture (the document is off-origin per its own doc comment,
  and the fit-viewport test specifically guards Ruling 01-2 against the
  nominal-1440×900 fit).
- Test/analyze/format output is pasted verbatim from actual command runs
  in this session, not synthesized.

## Issues or concerns

- Step 6's visual confirmation was not obtainable in this sandboxed,
  non-interactive session (no display/foreground session, no screenshot
  tool for native macOS windows). The app process itself launched and
  ran without error, and the equivalent build (`flutter build macos
  --debug`) succeeded, so I consider this a low-risk gap, not a defect,
  but flagging it since the brief asked for a look.
- No other concerns: both gates (`flutter test`/`flutter analyze`/`dart
  format`) are clean, and both builds (`macos --debug`, `web`) succeeded,
  including the package's first-ever web compile.
