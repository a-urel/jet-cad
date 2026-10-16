# Standing implementer notes (4a, restaurant kit)

Read with your task brief. These hold for every task.

## Binding rules
- Work only in `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/restaurant-kit`. Never `cd` to the main checkout.
- Never push, merge, tag or `dart pub publish` (dry-run is fine). Never run `git stash` bare.
- Never commit any `analysis_options.yaml` (`flutter pub get` rewrites three); the only exception is `packages/jet_cad_2d_kit_restaurant/analysis_options.yaml`, once, in Task 1. Stage files by name, never `git add -A`.
- Never synthesize test output: every count or line in your report is copied from a run you made.
- Code, comments and commit messages in English. Commit trailer: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` (or your own model's name).
- Do not dispatch subagents.
- Do not touch `apps/floor_planner`, `packages/jet_cad_floor_plan`, `packages/jet_cad_restaurant_symbols`, or the engine packages (`jet_cad`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_gpu`). `jet_cad_2d_plan` and `apps/architecture_demo` only where your brief says. A one-off script may READ the old restaurant package (Task 1), never modify it.

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
- (3b, carried) `controller.dirty` is a microtask late; `settlePendingInput` is @internal; PlanEditor settles before its file callbacks. `kFileChords`, `showPlanExportDialog` are public. A dispose test must reparent then unmount. Kits may not import the plan library or another kit (check_kit_deps). `PlanBuild` is `void Function(DraftDocument, KitWords)` with no symbol services.
- (T1) Kit: lib/src/catalog/* (FurnitureSymbol→CatalogSymbol), keys.dart RestaurantSymbols (69), definitions.dart restaurantSymbolDefinitions() built from catalog via encodeLibrary+decode (cached; a test holds bytes == committed asset). Fixture test/fixtures/old_catalog_geometry.json keeps old keys + seats (25 seated). 8 keys renamed (ledger).
- (T2) restaurantKit, restaurantNames (en map empty: English is the library text), restaurantSymbolEntries() (key@1 → SymbolEntry: symbol, unit, definition, leaves) — samples place from entries. Moved to demo: RL15 → symbols_load_test, SC3 → corner_booth_test.
- (T3) PlanToolIds exported (ED-9 updated). A second PlanCanvas on one controller asserts in debug; two PlanServiceViews may share it; the most recent canvasRect reporter drives (re-inserted on report; fallback .last after unmount).
- (T4) O1: engine snapInto/resolveDragPoint take Set<Handle>? exclude; SelectTool excludes the dragged objects for the move TARGET only (the base keeps own-geometry snaps). O2: orientation row in a FittedBox. Engine CHANGELOGs have Unreleased entries (engine joins 4b's wave).
- (T5) PlanController.pageFlowBusy (ValueListenable<bool>) is public: true from an export/print start (dialog included) to its end. architecture_demo busy = session flows OR pageFlowBusy. Locale adopted in the build (adoptLocale), notices re-word in the same frame.
- (T6) Demo: lib/main.dart is the shell (two areas, area/language/look toggles, PlanEditor); lib/samples/salon.dart (room built first, tables 1-11), teras.dart; old tests in test/_pending/*.dart.txt (demo → T7; events, badges, host_chrome, look → T8); the demo's own colour invariant test/invariants/theme_colours_test.dart (add allow-list entries for restored literals). Task-6 report lists every feature T7/T8 must restore.
- (T7) Demo split: main.dart (510) + area, statuses, groups, zones, table_menu, editor_profiles, side_panel. demo.log is back (Task 8 adds the other sources). test/_pending/demo_pending.dart.txt now holds only Task 8's rows (D3, D4, D6-D10, D14, D16, Dark theme, DQ1, DQ2, D19b) + events/badges/host_chrome/look pending files. DH1/DH2/DH7 halves are covered by PF1-PF4 and FIND — confirm and port the rest.
