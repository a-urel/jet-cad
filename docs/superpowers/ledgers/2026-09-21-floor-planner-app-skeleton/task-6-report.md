# Task 6 report: `apps/floor_planner` — the scaffold, the workspace, the window

Status: **DONE** (see "Fix report — unblock" below). Originally reported
BLOCKED at Step 4 (build); the coordinator issued a controller ruling to
overwrite the generated `lib/main.dart` with a placeholder rather than raise
the pubspec's `sdk:` floor. That ruling was applied, both builds now pass,
and Steps 4–6 were completed and committed at `472c46e`.

## What was done, step by step

### Step 1: Create

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/apps
flutter create --org dev.jetcad --project-name floor_planner --platforms macos,web floor_planner
```

Output:

```
Creating project floor_planner...
Resolving dependencies in `floor_planner`...
Downloading packages...
Got dependencies in `floor_planner`.
Wrote 46 files.

All done!
You can find general documentation for Flutter at: https://docs.flutter.dev/
Detailed API documentation is available at: https://api.flutter.dev/
If you prefer video documentation, consider: https://www.youtube.com/c/flutterdev

In order to run your application, type:

  $ cd floor_planner
  $ flutter run

Your application code is in floor_planner/lib/main.dart.
```

```sh
cd floor_planner && rm -f README.md test/widget_test.dart && ls
```

```
analysis_options.yaml
floor_planner.iml
lib
macos
pubspec.lock
pubspec.yaml
test
web
```

`git status --short` at the repo root immediately after showed only
`?? apps/floor_planner/` — no other file in the workspace was touched by
`flutter create`.

### Step 2: The pubspec

Checked the generated `apps/floor_planner/pubspec.yaml` first: it pinned
`flutter_lints: ^6.0.0`, matching the brief exactly, so no deviation was
needed there.

Replaced `apps/floor_planner/pubspec.yaml` verbatim with the brief's Step 2
content (name, description, `publish_to: none`, `version: 0.0.1`,
`resolution: workspace`, `sdk: ^3.5.0`, `flutter: ">=3.24.0"`, the three
dependencies, `flutter_test` + `flutter_lints: ^6.0.0`, `uses-material-design: true`).

Added `- apps/floor_planner` to the root `pubspec.yaml`'s `workspace:` list,
after `- apps/dev_harness_2d` (now the last line of the list).

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton
flutter pub get
```

Output (tail):

```
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (108.0.0 available)
  analyzer 13.3.0 (14.4.0 available)
  code_assets 1.2.1 (2.1.0 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  shadcn_ui 0.55.1 (0.57.0 available)
  test 1.31.1 (1.32.0 available)
  test_api 0.7.12 (0.7.14 available)
  test_core 0.6.18 (0.6.20 available)
Got dependencies!
10 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Deleting old lock-file: `./apps/floor_planner/pubspec.lock`.
Deleting old package config: `./apps/floor_planner/.dart_tool/package_config.json`.
See https://dart.dev/go/workspaces-stray-files for details.
Upgrading analysis_options.yaml to exclude build and platform directories.
```

`git status --short` after:

```
 M packages/jet_cad/analysis_options.yaml
 M pubspec.yaml
?? apps/floor_planner/
```

Restored the rewritten file:

```sh
git checkout -- packages/jet_cad/analysis_options.yaml
```

`git status --short` after restore:

```
 M pubspec.yaml
?? apps/floor_planner/
```

Only `packages/jet_cad/analysis_options.yaml` was rewritten by this `pub get`;
no other `analysis_options.yaml` under `packages/` or `apps/dev_harness_2d`
was touched. `apps/floor_planner/analysis_options.yaml` was left exactly as
generated, per Ruling 01-1.

### Step 3: The window (spec D7)

Found the single `contentRect` line in
`apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib`:

```
335:            <rect key="contentRect" x="335" y="390" width="800" height="600"/>
```

Changed it to:

```xml
            <rect key="contentRect" x="335" y="390" width="1440" height="900"/>
```

`MainFlutterWindow.swift` was not touched. Since the whole `apps/floor_planner/`
tree is untracked (new app), `git diff --stat -- apps/floor_planner/macos`
produces no output (there is no tracked baseline to diff against yet); the
untracked-file check `git status --short -- apps/floor_planner/macos` shows a
single `?? apps/floor_planner/macos/` line, and no edits were made under
`macos/` other than the one `contentRect` line above — confirmed by re-reading
the file and by the fact that no other command touched that directory.

### Step 4: Build both targets as generated — FAILED

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/apps/floor_planner
flutter build macos --debug 2>&1 | tail -3
```

Tail:

```
Command PhaseScriptExecution failed with a nonzero exit code
warning: Run script build phase 'Run Script' will be run during every build because it does not specify any outputs. To address this issue, either add output dependencies to the script phase, or configure it to run in every build by unchecking "Based on dependency analysis" in the script phase. (in target 'Flutter Assemble' from project 'Runner')
** BUILD FAILED **
```

First error, verbatim (full build log at `/tmp/floor_planner_macos_build.log`):

```
Building macOS application...
lib/main.dart:31:22: Error: This requires the experimental 'dot-shorthands' language feature to be enabled.
Try passing the '--enable-experiment=dot-shorthands' command line option.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
                     ^
lib/main.dart:105:30: Error: This requires the experimental 'dot-shorthands' language feature to be enabled.
Try passing the '--enable-experiment=dot-shorthands' command line option.
          mainAxisAlignment: .center,
                             ^
Target kernel_snapshot_program failed: Exception
Failed to package /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-01-app-skeleton/apps/floor_planner.
```

`flutter build web` was also attempted for completeness. Same root cause,
first error verbatim (full log at `/tmp/floor_planner_web_build.log`):

```
Compiling lib/main.dart for the Web...
lib/main.dart:31:22:
Error: This requires the experimental 'dot-shorthands' language feature to be enabled.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
                     ^
lib/main.dart:105:30:
Error: This requires the experimental 'dot-shorthands' language feature to be enabled.
          mainAxisAlignment: .center,
                             ^
Error: Compilation failed.
```

**Root cause, isolated:** Flutter 3.47.2's `flutter create` template (Dart SDK
3.13.2) writes `lib/main.dart` using dot-shorthand syntax (`.fromSeed(...)`,
`.center`) at lines 31 and 105. That syntax is still gated behind
`--enable-experiment=dot-shorthands` in this Dart/Flutter release, and Flutter
tooling derives the *language version* fed to the frontend from the package's
`environment: sdk:` constraint. The brief's pubspec pins `sdk: ^3.5.0`, which
resolves to a language version too old for the experiment to be considered
available at all (the tool doesn't even suggest the flag as viable — it's a
hard error either way at this SDK series). I confirmed the isolation
experimentally: temporarily bumping the app's `sdk:` constraint to `^3.13.2`
(matching the installed Dart/Flutter, nothing else changed) made
`flutter build macos --debug` succeed (`✓ Built build/macos/Build/Products/Debug/floor_planner.app`).
I then reverted that experiment and restored the pubspec to the brief's exact
Step 2 content before writing this report — no lasting change was left from
the experiment. `flutter pub get` was re-run after reverting, and the
resulting stray rewrite of `packages/jet_cad/analysis_options.yaml` was
restored again with `git checkout --`.

Per the task instructions ("If a build fails, paste the first error verbatim
and report BLOCKED — do not patch packages") and per the brief's own framing
("the counter app does not yet import [jet_cad_2d_flutter]; if *this* build
fails, the failure is the scaffold's, not the package's"), I did not patch
`lib/main.dart` (Step 1's note: tasks 7–8 replace it; this task must leave it
as generated) and did not change the pubspec's `sdk:` constraint from the
brief's specified `^3.5.0`. **I did not run Step 6 (commit)** — the brief
requires both builds to pass before the commit step, and they do not with the
pubspec as specified.

### Step 5: The launch entry

Not yet applied — held back since the plan's per-task ends-green gate wasn't
reached and I did not want to add unreviewed edits beyond what's needed to
diagnose the blocker. (If the fix is simply raising the app's `sdk:`
constraint, Step 5 is unaffected by it and can be applied immediately once
Step 4 is unblocked.)

### Step 6: Commit

Not performed — blocked on Step 4.

## Files changed (currently, uncommitted)

- `pubspec.yaml` (root): added `- apps/floor_planner` to `workspace:`, after
  `- apps/dev_harness_2d`.
- `apps/floor_planner/` (new, untracked): generated by `flutter create`, minus
  `README.md` and `test/widget_test.dart`; `pubspec.yaml` replaced with the
  brief's Step 2 content; `macos/Runner/Base.lproj/MainMenu.xib` has the
  single `contentRect` width/height change (800x600 → 1440x900).
- `.vscode/launch.json`: not yet touched.

No other file in the workspace is modified. `git status --short` at the
worktree root currently reads:

```
 M pubspec.yaml
?? apps/floor_planner/
```

## Self-review findings

- Step 1: matches brief exactly; `git status --short` after `flutter create`
  showed only the new `apps/floor_planner/` directory.
- Step 2: pubspec content matches the brief verbatim (`flutter_lints: ^6.0.0`
  needed no override); workspace list gained exactly one line, in the
  specified position; the only `analysis_options.yaml` rewritten by
  `flutter pub get` outside `apps/floor_planner` was
  `packages/jet_cad/analysis_options.yaml`, restored both times it happened
  (once during the real run, once after the sdk-constraint isolation test).
- Step 3: the xib change is the single `contentRect` line, verified by
  re-reading the file; no other file under `apps/floor_planner/macos` was
  edited.
- Step 4: **blocked**, both macOS and web builds fail identically, root cause
  isolated to `sdk: ^3.5.0` vs. the generated `main.dart`'s use of
  dot-shorthand syntax under Flutter 3.47.2 / Dart 3.13.2. Did not patch
  `packages/`, did not patch `lib/main.dart`, did not change the pubspec's
  `sdk:` constraint from the brief's specified value.
- Step 5, Step 6: not performed, per the gating in the task instructions.

## Issues or concerns

- **The blocker:** the brief's pubspec `environment: sdk: ^3.5.0` is
  incompatible with `flutter create`'s own generated `lib/main.dart` on the
  installed Flutter 3.47.2 (Dart 3.13.2) toolchain — the template uses
  dot-shorthand syntax that this Dart version only supports experimentally,
  gated by language version/experiment flag, and the low `sdk:` floor forecloses
  it. This is not a defect in `jet_cad_2d` or `jet_cad_2d_flutter` (neither is
  imported yet by the generated app) and not something Step 1–3 or 5 could
  have avoided while also matching the brief's exact pubspec content.
- Two ways to unblock, for whoever resolves this (not decided by me, since it
  changes a value the brief specified verbatim):
  1. Raise the app's `environment: sdk:` floor to match the installed
     toolchain (e.g. `^3.13.2`, or whatever floor the plan wants pinned) —
     confirmed sufficient by direct experiment (see above).
  2. Leave `sdk: ^3.5.0` and pass `--enable-experiment=dot-shorthands` to the
     build/run commands (would also need reflecting in `.vscode/launch.json`
     args and any CI build commands) — not tested, and changes more surface
     than option 1.
  This is a plan/spec-level call (the brief fixes the exact pubspec text), so
  I stopped rather than guessing at that value change.
- No commit was created. The worktree currently has the uncommitted, correct
  state for Steps 1–3 as described above, ready to resume from once the sdk
  question is resolved.

## Fix report — unblock

Controller ruling: keep the brief's pubspec verbatim (`sdk: ^3.5.0`, same
floor as every other workspace member) and replace the generated counter app
with a minimal placeholder that compiles at language version 3.5, since
`flutter create`'s generated `main.dart` (not the sdk floor) is the thing to
change, given Task 8 replaces `main.dart` anyway.

### 1. Overwrote `apps/floor_planner/lib/main.dart`

Replaced the file with exactly the text supplied by the ruling:

```dart
import 'package:flutter/material.dart';

// Scaffold placeholder. Task 8 replaces this file with the real shell; it
// exists only so the generated project builds under the workspace's
// `sdk: ^3.5.0` floor, which the generator's own dot-shorthand syntax
// does not.
void main() => runApp(const FloorPlannerApp());

class FloorPlannerApp extends StatelessWidget {
  const FloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Floor planner',
        home: Scaffold(body: Center(child: Text('floor_planner'))),
      );
}
```

### 2. Confirmed pubspec and removed files

`apps/floor_planner/pubspec.yaml` still reads exactly as Step 2 of the brief
specifies (`sdk: ^3.5.0`, `flutter_lints: ^6.0.0`, no changes needed — the
brief's pubspec was never altered from the original attempt). `test/`
contains no files (`test/widget_test.dart` had already been removed) and
`README.md` is absent.

### 3. Re-ran Step 4, plus analyze and format

```sh
cd apps/floor_planner
flutter build macos --debug 2>&1 | tail -3
```

```
Try `flutter pub outdated` for more information.
Building macOS application...
✓ Built build/macos/Build/Products/Debug/floor_planner.app
```

```sh
flutter build web 2>&1 | tail -3
```

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             21.8s
✓ Built build/web
```

```sh
flutter analyze
```

```
Analyzing floor_planner...
No issues found! (ran in 1.0s)
```

```sh
dart format --output=none --set-exit-if-changed .
```

```
Formatted 1 file (0 changed) in 0.01 seconds.
```
Exit code: 0.

Both builds green, analyze clean, format clean.

### 4. Steps 5 and 6

`git status --short` before touching `.vscode/launch.json` (right after the
builds/analyze/format runs above):

```
 M pubspec.yaml
?? apps/floor_planner/
```

No stray `analysis_options.yaml` rewrite this time — nothing to restore.

Appended the brief's Step 5 entry to `.vscode/launch.json`, after the last
existing configuration (`"2d: measure 50k -- tiles ON, debug"`), keeping every
prior entry in place. Verified the result is valid JSON-with-comments by
stripping `//` comment lines and parsing with `json.loads`: 12
configurations total (11 original + 1 new), last entry's name is
`"floor_planner: macOS"`.

`git status --short` right before staging:

```
 M .vscode/launch.json
 M pubspec.yaml
?? apps/floor_planner/
```

Still no stray `analysis_options.yaml` changes anywhere in the workspace.

```sh
git add pubspec.yaml apps/floor_planner .vscode/launch.json
git commit -m "$(cat <<'EOF'
build(floor_planner): scaffold the product app as a workspace member, 1440x900 window

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
)"
```

Result: commit `472c46e4455e96f15319be107d13060c010314d2`
("build(floor_planner): scaffold the product app as a workspace member,
1440x900 window"), 41 files changed, 1666 insertions(+).

`git show --stat HEAD` confirms only the allowed paths are in the commit:
`.vscode/launch.json`, `pubspec.yaml`, and everything under
`apps/floor_planner/` (`lib/main.dart`, `pubspec.yaml`,
`analysis_options.yaml`, the macOS Runner project including the edited
`MainMenu.xib`, the web scaffold, `.gitignore`, `.metadata`). `pubspec.lock`
and `floor_planner.iml` are correctly excluded, matched by `.gitignore:3:*.lock`
and `apps/floor_planner/.gitignore:16:*.iml` respectively — confirmed with
`git check-ignore -v`.

### Fix self-review

- `lib/main.dart` matches the ruling's text exactly (verified by re-reading
  after write).
- Pubspec unchanged from the original Step 2 content — `sdk: ^3.5.0` kept
  verbatim, no floor was raised.
- Both builds, analyze, and format are clean with the placeholder in place.
- `.vscode/launch.json` gained exactly one entry, appended last, JSON
  structure validated; no existing entry was reordered or edited.
- Commit contains only `pubspec.yaml`, `.vscode/launch.json`, and
  `apps/floor_planner/**`; no `analysis_options.yaml` outside
  `apps/floor_planner/` is touched at any point in the final state.
- `apps/floor_planner/analysis_options.yaml` is in this commit, as generated,
  per Ruling 01-1, and no later task should modify it here.

No further concerns.
