# Standing implementer notes (3b, architecture demo)

Read with your task brief. These hold for every task.

## Binding rules
- Work only in `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-demo`. Never `cd` to the main checkout.
- Never push, merge, tag or `dart pub publish` (dry-run is fine). Never run `git stash` bare.
- Never commit any `analysis_options.yaml` (`flutter pub get` rewrites three); the only exception is `apps/architecture_demo/analysis_options.yaml`, once, in Task 2. Stage files by name, never `git add -A`.
- Never synthesize test output: every count or line in your report is copied from a run you made.
- Code, comments and commit messages in English. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (or your own model's name).
- Do not dispatch subagents.
- Do not touch `apps/floor_planner`, `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, or the engine packages (`jet_cad`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`). `jet_cad_2d_plan` only where your brief says.

## Porting rules
- Never weaken a ported assertion. Never skip a case.
- A case whose premise is impossible splits into `<id>-open` (what the app does now) and its intent, with `// Decided: premise impossible (<why>)`.
- Every ported file starts with a header comment naming its old file and the audit section (`docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md`).
- COVERED rows: open the named covering test, confirm it exists and asserts the intent, list it in the report as `COVERED, checked: <file>:<line>`.

## Testing bar
- Each new test and each behaviour change names a mutation that turns it red. Run it on committed code, revert with `git checkout -- <file>`, show `git diff --quiet` passing. List every mutation and the red test in the report.
- Beware degenerate fixtures (identity transform, origin, defaults).

## Gates (every task ends green)
- App: `cd apps/architecture_demo && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
- If you touched `packages/jet_cad_2d_plan`: `flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` there.
- If you touched `packages/jet_cad_2d_integration`: same with `--enable-vmservice`.

## Report
Write the full report to the path your dispatch names: status, commits, the gates' real last lines, every mutation, every audit row outcome (porting tasks), decisions and concerns. Return only status, commits, one-line test summary, concerns.

## Facts learned (updated per task)
- (T1-2) `jet_cad_2d_plan` is 0.8.0, `jet_cad_2d_kit_architecture` per its pubspec. The app state owns `PlanSymbolLoader` and disposes it after the controller. `kFileChords`, `showPlanExportDialog` are public. `barrel_test.dart` ED-9 pins the barrel's exact name set.
- (T1-2) A dispose test that only unmounts does not catch a dispose in `deactivate`; reparent via GlobalKey, then unmount.
- (T3) AppStrings has no LocalizationsDelegate (AppStrings.of reads the locale). Copied layer files never used FloorPlanStrings; a cancel word comes from `PlanStrings.of(context)` (check its name) for the dialogs. Fakes: test/support/app_fakes.dart.
- (T4) `controller.dirty` follows the change stream (a microtask late); the host yields one microtask before reading it (`_mayDiscard`). `settlePendingInput` is @internal; `newPlan`/`load`/`save`/`markSaved` settle themselves, and PlanEditor settles before onNew/onOpen/onSave/onSaveAs. Task 5's exit request: settle via a discarded `controller.save()` or the library route Task 4b adds, then yield, then read dirty.
- (T4b) settlePendingInput now finishes an open text entry (TextEntryOverlay registers a settle) and the page panel hands focus back. DocumentSession has `isDisposed`; `_flow`'s finally skips busy once disposed; `_write` returns before markSaved when the host is unmounted (DS8). The name widget's maxWidth is 160 (DC12 at 800 px).
- (T5) Exit settles by a discarded controller.save() in try/catch, then a microtask yield, then dirty. N5: tester.platformDispatcher.localesTestValue reaches the app (title needs two pumps).
- (T6) Busy wrappers refuse while busy (dialog → null, printer → return). Export button is in the bar; name widget 144 px. app_rig has chordHandled. pubspec declares the Roboto family (EF12).
