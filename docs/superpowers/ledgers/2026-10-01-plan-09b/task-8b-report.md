# Task 8b report — owed test-only follow-ups

On 7d3bff7. Test files only; no lib change. Three commits:
- 7693621 `test(app): the Symbols tab's buttons take no focus (8b)` — symbol_panel_test.dart
- ebfd8bf `test(app): the app's own loader reaches ready (2b)` — symbol_library_loader_test.dart SL11
- 5566da3 `test(render): the hairline fixture joins the degeneracy guard (3c)` — symbol_thumbnails_test.dart

## Gates (after the third commit)
- app `CI=true flutter test`: `03:23 +884: All tests passed!` (no new test cases: assertions were added to existing tests)
- app analyze: `No issues found! (ran in 1.4s)`; format: `Formatted 152 files (0 changed)`
- render `CI=true flutter test`: `00:58 +1001 ~1 -7: Some tests failed.` (the 7 standing failures: text_ladder_golden_test rungs, listing truncated after 4 by flutter's "... and 3 more"; 1 skip)
- render analyze: `No issues found! (ran in 1.4s)`; format: `Formatted 182 files (0 changed)`

## 8b: the buttons take no focus
A helper `canTakeFocus(tester, key, inner)` = `Focus.of(<inner inside the button>).canRequestFocus`.
Asserted false for the x (`symbol-search-clear`, inner Icon), Retry (`symbol-retry`, inner text) and the empty-result Clear (`symbol-search-clear-empty`, inner text). For the x, the field also keeps focus after the tap (focus on the field, tap the x: `searchFocus.hasFocus` true, canvas false). The Retry test's canvas-focus comment now says that a tap never takes focus, and that `canTakeFocus` is the real guard.

Mutants (scratchpad/b8b/mut.sh, `ExcludeFocus(` -> `KeyedSubtree(`, symbol_panel.dart at 7d3bff7; each `restore diff exit=0`):
| line | red |
|---|---|
| 242 (x) | `+3 -1: search typing "bed" shows only the matches; the clear button restores all [E]` (Expected: false, Actual: <true> at test line 289, the canTakeFocus check) |
| 301 (Retry) | `+2 -1: states a failed load shows its message and Retry; Retry reaches ready (M-09b10) [E]` |
| 331 (empty Clear) | `+4 -1: search an empty result says so with the query, and its Clear restores all [E]` |

## 2b: SL11 reaches ready
After the pump: `expect(own!.state, isA<SymbolLibraryReady>())` and the keys equal the file's (the production rootBundle path).
Mutant: main.dart:88 `SymbolLibraryLoader()` -> `SymbolLibraryLoader(read: () async => throw StateError('mutant'))`:
`+11 -1: the wiring (spec 09b D2, R-4) SL11 without a loader the app makes one, hands it to the shell and disposes it with itself [E]`; restore diff exit=0.

## 3c: the hairline joins the guard
`(hairlineSymbol(), const Handle(810))` was added to the 'fixtures are not degenerate' loop. It passes (`00:00 +1: All tests passed!`). No mutant was fired: this is a precondition guard on a fixture, not a behaviour test.

## Not done
I did not take review notes 2 and 3 (the panel rebuilds on every tool notification; the empty-result Clear's focus outcome is not asserted). Both were notes, not findings.
