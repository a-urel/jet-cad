# 3b final fix wave: report

Status: DONE with concerns. Commits (oldest first): 4fa37742 fix(demo) teardown guards; 8295cc76 test teardown tests; cafa8ff3 fix exit settle; 518e2757 unused import; 492c3719 WE3; fac57b29 palette cache; 0ce785fb SS7; b6831537 SS13/SS14; 17a472b8 rig helpers; 90f1576b + 6b695558 headers; 7277dd24 smoke test + PNG; 826f08c1 docs.

## Items
- A1 done. `busyExportDialog(... isDisposed:)`, `BusyPagePrinter(..., isDisposed:)`; host passes `_session.isDisposed`. Tests BU-teardown-print (drives the editor's own printer, because the library swallows the late throw), BU-teardown-dialog. Mutations: guard removed in printer -> BU-teardown-print red; guard removed in dialog -> BU-teardown-dialog red; host's printer wiring removed -> BU-teardown-print red. Host's dialog wiring: no test (the dialog route dies with the navigator; unreachable).
- A2 done. `if (file == null || !mounted) return;`. `FakeDocumentFiles.holdOpens/heldOpens`. Test OP-teardown pumps a `DocumentHost` over a test-owned controller and session (a disposed app controller would swallow the wrongly-run load; the live one makes it visible: document replaced, session named). Mutation: check removed -> OP-teardown red.
- A3 done. `mounted` check after the save panel (`holdSaveLocations/heldSaveLocations` hook). No check after the write: nothing follows it (would be untestable code). Test EX-teardown (asserts no write). Mutation: check removed -> EX-teardown red.
- A4 done. `_symbols` field and its dispose dropped from main.dart; all tests green.
- A5 done as: `if (!_controller.damaged.value) _controller.save();` (`damaged` is public); documented in the `_onExitRequested` comment (a damaged plan's typed uncommitted value is not settled on exit). FALLBACK note: no red test: a damaged plan cannot be produced through the architecture kit with public means (tried a sabotaged command with NaN and bad thickness: not damaged). The mutation (remove the guard) is therefore not pinned.
- A6 done. EX-save-throws: a wall with a NaN end set by command (dirty, not damaged, save throws JsonUnsupportedObjectError); exit asks, Cancel -> cancel, Don't Save -> exit. Mutation: try/catch removed -> red.
- B1 done: WE3 asserts uB (back-centre along B) closeTo(1500, 250); observed 1682 (grid snap of the drag). Mutation: drop point moved to 500 along B -> only that assertion red (actual 800).
- B2 done: the cache key was reachable (id, cell size and ratio from the RawImage, foreground 0x000000): `c.thumbnails.imageFor` with a throwing builder returns the same entry; `shown.isCloneOf(cached)`, length unchanged. Mutation: key of another symbol -> red. The `// Decided:` header updated.
- B3 done: `overlayCalls` helper (counting Canvas over the public Tool.paintOverlay/paintWorldOverlay in symbol_rig.dart). Premise: hover shows the ghost (calls > 0); after New: armed tool and active tool paint 0. Mutation (scratch edit of jet_cad_2d_flutter tool.dart, reverted, git diff --quiet): remove `_active.cancel(context)` in `ToolController.activate` -> SS7 red.
- B4 done: SS14-open `matches(RegExp(r'^architecture\.sofa'))`; SS13-open `before.commands.isDisposed`. Mutations: scratch edit of plan_controller `_drop` (no session.dispose) -> SS13-open red; typed term changed to 'chair' -> SS14-open red. Reverted, clean.
- C1 done. `titledDirty(rig, {name, location, at})` and `canvasFocused(tester, {exact})` in app_rig.dart; copies deleted in replace/save/settle/palette. Exceptions: document_exit_test's helper builds a different state (saved as hall, then a second wall, depth 2) so it is renamed `savedThenDirty` (not a copy); document_save_test keeps a thin `titledDirtyFlat` (pumps the app, calls the shared helper). The `far` constants differ in value per file, so they were not merged. Replace tests pass `at: far` (their own point) to keep the pointer where their later walls are drawn (the first run showed an off-screen draw otherwise).
- C2 done: headers on app_fakes.dart and export_rig.dart.
- D1-D3 done: `integration_test/smoke_test.dart` (+ `integration_test` dev dependency), PNG committed at docs/superpowers/notes/2026-10-16-architecture-demo-smoke.png. FALLBACK: the macOS sandbox lets the app write only inside its container, so the test writes the PNG to its temp dir (or to --dart-define=SMOKE_OUT) and I copied it to docs/ by hand. Mutation: `markSaved` removed -> smoke red ("Expected: false, Actual: true").

## Gates (real last lines)
- app: `00:34 +176: All tests passed!`; `No issues found! (ran in 3.5s)`; `Formatted 44 files (0 changed)`
- smoke: `flutter test integration_test/smoke_test.dart -d macos` -> `00:03 +1: All tests passed!` (printed `Failed to foreground app; open returned 1`, harmless)
- jet_cad_2d_plan (--enable-vmservice): `02:02 +1558: All tests passed!`, analyze clean, format 0 changed
- jet_cad_2d_integration (--enable-vmservice): `01:00 +228: All tests passed!`, analyze clean, format 0 changed
- `flutter build macos` built Release/architecture_demo.app (48.8MB); `flutter build web` built build/web. git status clean after all.

## Concerns
- A5's guard has no red test (above).
- In the PNG the Page panel's "Landscape" button wraps to "Landscap/e" at the 1440 px window: a cosmetic finding in the library's panel, not fixed.
- The drawn wall in the smoke test is outside the fitted view after reopen (the camera fits on load), so the PNG shows the sample only.
