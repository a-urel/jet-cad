# Task 2 report — the library loader and its wiring (spec D2, R-4)

Commit: 674f717 `feat(app): load the symbol library once per app` (parent d4e85f6).
(First committed as 70edc3d once the gates were green; amended to 674f717 with a one-line test fix in SL7, see Mutants. Never pushed.)

Files:
- apps/floor_planner/lib/symbols/symbol_library_state.dart (new, pure: imports only symbol_library.dart). `sealed class SymbolLibraryState`; `SymbolLibraryLoading`, `SymbolLibraryReady(library)`, `SymbolLibraryFailed(error)`.
- apps/floor_planner/lib/symbols/symbol_library_loader.dart (new; the only `rootBundle` user). `kFurnitureLibraryAsset`, `readBundledLibrary()`, `SymbolLibraryLoader extends ChangeNotifier({read})`: `state`, `load()`, `retry()`, `dispose()`.
- apps/floor_planner/lib/main.dart: `FloorPlannerApp({files, exitGuard, symbols})`; `_symbols = widget.symbols ?? (_ownSymbols = SymbolLibraryLoader())`, `load()` in `initState`, `_ownSymbols?.dispose()`; passes `symbols` to `DocumentHost`. `PlannerShell({..., symbols})` stores the field and does nothing with it.
- apps/floor_planner/lib/document_host.dart: `DocumentHost({..., symbols})`, passes `symbols: widget.symbols` to every `PlannerShell` it builds.
- apps/floor_planner/test/symbols/symbol_library_loader_test.dart (new, 13 tests).

## Gates (app; engine and render untouched by this task, not re-run: the diff touches only apps/floor_planner)

```
03:00 +814: All tests passed!         (flutter test: 801 after Task 1 + 13 new)
No issues found! (ran in 1.3s)        (flutter analyze)
Formatted 145 files (0 changed) in 0.63 seconds.  fmt_exit=0
✓ Built build/web                     (flutter build web --release)
```
After the SL7 edit: `00:01 +13: All tests passed!` (the file), `No issues found!`, format `fmt=0`.

## Tests
- SL1 load() from the real asset bytes (File) → ready with the same keys as an independent decode; one notification; one read; a second load() reads and notifies nothing.
- SL2 missing asset (real `File(...no-such-library...).readAsBytes()`) → failed with `PathNotFoundException`.
- SL3 the real asset cut in half → failed with `SymbolLibraryError`.
- SL4 the 09a fixture (positive control loads, 3 keys) then the fixture with an upper-case tag → failed, `SymbolLibraryError` whose message names `Seating`.
- SL5 a thrown `StateError` (an Error, not an Exception) → failed.
- SL6 retry() after a failure: loading while it runs, then ready; reads 2; notified states [Failed, Loading, Ready].
- SL7 retry() while the first load runs, and from ready: no read, no notification.
- SL8 load() after dispose reads nothing; a load ending after dispose neither notifies nor throws.
- SL9 the default read (`rootBundle`) in a plain `testWidgets` loads the declared asset: same keys as the File. **It works without `runAsync`** (the test binding's asset handler answers inside the fake-async zone), so no DefaultAssetBundle fallback was needed.
- SL10 `FloorPlannerApp(symbols: injected)`: one read (load in initState), the shell's `symbols` is the same loader, still the same after a New swap (new document, new shell), still one read; after unmount the injected loader is not disposed.
- SL11 bare `FloorPlannerApp(files:)`: the shell and the host carry the app-made loader; after unmount it is disposed (`addListener` throws FlutterError).
- SL12 a bare `PlannerShell()` has `symbols == null`.

## Mutants
Each: cp backup to scratchpad/b2, one-line sed, `CI=true flutter test test/symbols/symbol_library_loader_test.dart` in the foreground, cp back, `diff` exit 0 (`restored diff=0` every time). Lines at 674f717.

| Id | File:line | Mutation | Red test(s) | Real output |
|---|---|---|---|---|
| M-09b10 (retry does nothing) | symbol_library_loader.dart:52 | `return;` → `return; return;` | SL6 | `Expected: <Instance of 'SymbolLibraryLoading'>` / `Actual: SymbolLibraryFailed:<SymbolLibraryFailed(FileSystemException: first read fails, path = '')>` |
| M-09b10b (retry sets loading, never runs) | :54 | `await _run();` removed | SL6 | `SL6 ... [E]`, `+12 -1: Some tests failed.` |
| failure swallowed as loading | :62 | `SymbolLibraryFailed(e)` → `const SymbolLibraryLoading()` | SL2, SL3, SL4, SL5, SL6 | SL2 `Expected: <Instance of 'SymbolLibraryFailed'>` / `Actual: SymbolLibraryLoading:<SymbolLibraryLoading()>`; `+8 -5` |
| host does not pass symbols | document_host.dart:537 | `symbols: widget.symbols` → `symbols: null` | SL10, SL11 | `Expected: same instance as <Instance of 'SymbolLibraryLoader'>` / `Actual: <null>` |
| app does not pass symbols | main.dart:132 | `symbols: _symbols` → `symbols: null` | SL10, SL11 | same as above |
| app never loads | main.dart:96 | `_symbols.load();` → `_symbols;` | SL10 | `Expected: <1>` / `Actual: <0>` |
| app disposes a given loader | main.dart:101 | `_ownSymbols?.dispose()` → `_symbols.dispose()` | SL10 | `SL10 ... [E]`, `+12 -1` |
| app keeps its own loader alive | main.dart:101 | line removed | SL11 | `Expected: throws <Instance of 'FlutterError'>` / `Actual: <Closure: () => void>` |
| load() not once | loader.dart:44 | `_disposed \|\| _started` → `_disposed` | SL1 | `Expected: <1>` / `Actual: <2>` |
| load() after dispose runs | :44 | `_disposed \|\| _started` → `_started` | SL8 | `Expected: <0>` / `Actual: <1>` |
| completion after dispose notifies | :65 | `if (_disposed) return;` removed | SL8 | `SL8 ... [E]`, `+12 -1` |
| retry from any state | :52 | `_state is! SymbolLibraryFailed` → `false` | SL7 | `Expected: <1>` / `Actual: <2>` |

Note: on the first firing of "retry from any state", SL7 went red only by its 30 s timeout (it awaited a retry blocked on an uncompleted gate). SL7 now does `unawaited(r.loader.retry())` for the in-flight case, so the mutant reds on the read count (output above is the re-fire after that edit).

## Decisions / deviations
- `load()` is once-only (a second call is a no-op); the plan says nothing about a repeated load, and the app calls it once.
- `retry()` from loading or ready is a no-op (plan: "only from failed").
- `catch (e)` catches Errors too ("any throw"); SL5 proves it.
- `readBundledLibrary()` and `kFurnitureLibraryAsset` are public top-level names in the loader file (for Task 9 / readability); `rootBundle` stays only there.
- `FloorPlannerApp` uses `late final` for the loader, like `_files`: a later rebuild with a different `symbols` is not followed (same as `files`).
- No UI, no thumbnail-cache parameter (Tasks 3 and 9).
- Engine and render untouched; not re-run.

## Open issues
None.
