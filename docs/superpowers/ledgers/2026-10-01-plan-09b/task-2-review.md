# Task 2 review (independent) — 674f717
Status: in progress
- Diff d4e85f6..674f717: 5 files, all under apps/floor_planner (document_host.dart, main.dart, 2 new lib files, 1 new test file). packages/ untouched; no existing test edited.
- Gate (real): `03:37 +814: All tests passed!`; `No issues found!`; `Formatted 145 files (0 changed)` fmt=0; `✓ Built build/web` build=0.
- Purity: symbol_library_state.dart imports only symbol_library.dart; rootBundle appears only in symbol_library_loader.dart.
- M-09b10 retry does nothing (loader:52 `return; return;`): RED SL6 (Expected Loading, Actual Failed). restored diff=0
- failure swallowed as loading (loader:62): RED SL2-SL6, +8 -5. restored diff=0
- host not passing symbols (host:537 null): RED SL10, SL11. restored diff=0
- app disposes a given loader (main:101 `_symbols.dispose()`): RED SL10. restored diff=0
- HUNT Error escapes (loader:61 `on Exception catch`): RED SL5. restored diff=0
- HUNT no notify on ready (loader:71): RED SL1, SL6, SL7. restored diff=0
- HUNT SL9 vacuity, wrong asset key (loader:13): RED SL9 -> SL9 is real. restored diff=0
- HUNT view offset dropped (loader:18 asUint8List()): SURVIVED +13 (equivalent under the test binding's fresh buffers; accepted). restored diff=0
- app never loads (main:96): RED SL10 (Expected 1 Actual 0). restored diff=0
- HUNT app's own loader never reads the bundle (main:79 read throws): SURVIVED `+13: All tests passed!`. restored diff=0 -> finding 1
- app keeps own loader alive (main:101 removed): RED SL11. restored diff=0
- Host keys PlannerShell by ObjectKey(document) (document_host.dart:528) and passes widget.symbols on every build: the new shell after New/Open gets the same loader (SL10 proves it for New).
- Final git status --short: empty.

## Verdict: Approved (one minor finding, optional fix)
1. MINOR test/symbols/symbol_library_loader_test.dart:257-263 (SL11): the production path (app-made loader over rootBundle) is never shown to reach ready; a main.dart:79 mutant giving the own loader a throwing read survives. Fix: after the pump, `expect(own!.state, isA<SymbolLibraryReady>())` (rootBundle answers in testWidgets, SL9).
2. NOTE main.dart:76-79 / 61-63 dartdoc: `late final` ignores a later `symbols` on rebuild, like `files`; acceptable (root widget, test seam), worth one sentence in the field's doc.
Decisions accepted: load() once (retry is the way back, matches D2); late final loader (R-4: one per app).
