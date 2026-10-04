# Task 10 review: the search text survives a tab switch (spec D13)

Reviewer: independent, detached worktree `.worktrees/plan-09c1-review-t10` at `f424f9b`.
Diff reviewed: `git diff 7dbfc88..f424f9b` (5 files, +291 / -7; app only).

## Verdict: **Approved**

There are no blocking, major or minor findings. Four notes follow. R-C10-1 and R-C10-2 are accepted.

## 1. Implementation against spec D13 and plan Task 10

- `symbol_panel.dart`: `_query` is now a getter over the required `widget.query`. `initState` adds the listener. The new `didUpdateWidget` returns early on an identical controller; otherwise it moves the listener from the old controller to the new one. `dispose` removes the listener and no longer disposes the controller. The panel is still built only on the Symbols tab (`main.dart:827`, `_LeftTab.symbols => SymbolPanel(`), so the plan's "the panel is still removed on the Tools tab" and R-B9-2's "no hidden rebuilds" both hold. The clear button (`_clear` -> `_query.clear()`) now acts on the caller's controller, as intended.
- `main.dart`: `PlannerShell.symbolSearch` is optional. `_symbolQuery = widget.symbolSearch ?? (_ownSymbolQuery = TextEditingController())` is set once in `initState`. `dispose` calls `_ownSymbolQuery?.dispose()`, so only the shell's own controller is disposed and the host's is never touched. The only production `SymbolPanel(` site passes `query: _symbolQuery`.
- `document_host.dart`: `_symbolSearch` is created in `initState`, disposed in `dispose`, and passed to every `PlannerShell`.

### R-C10-1 (the host owns the controller): accepted

I checked the premise. `DocumentHostState.build` returns `PlannerShell(key: ObjectKey(_session.document), …)` (`document_host.dart:632-633`), and SS13 asserts `tester.state(find.byType(PlannerShell))` is a new state after `newFlow()` and `openSampleFlow()`. A controller created in `_PlannerShellState.initState` would therefore be disposed on every document replacement.

D13 asks for two things that conflict under 12a D2's keying: "the shell owns" the controller, and the text "survives … a document change". The text-survival requirement is the observable one. Raising ownership one level, to the host, is the established pattern: object snap (`SnapSettings snap`, "the host's, so it survives a swap (spec 12a D2)") does the same. The host passes the controller through the shell, so the panel still receives it from the shell as D13 says. "A new app starts empty" holds because there is one host per app, and SS14 asserts it.

A bare shell (no host) still owns its own controller, created in `initState` and disposed in `dispose`, which is the plan's literal wording; SS15 covers it.

The spec wording needs the at-execution amendment in Task 11 (see note N-1).

### R-C10-2 (`didUpdateWidget` moves the listener): accepted

The code is correct. It returns early on an identical controller, removes the listener from the old one and adds it to the new one. `dispose` then removes the listener from the current `widget.query`, which is the one that holds it. Nothing in production hands in a different controller today. The cost is six lines, and two of my own mutants (R-1, R-2) show the test pins both halves.

### Disposal order

- Shell: `_ownSymbolQuery?.dispose()` runs in `_PlannerShellState.dispose`. Flutter's `_InactiveElements._unmount` (`/root/flutter/packages/flutter/lib/src/widgets/framework.dart:2115-2119`) unmounts children before their parent, so the panel's `dispose` (which removes its listener) and the `TextField`'s detach both run before the shell disposes the controller. `ChangeNotifier.removeListener` is also explicitly allowed on a disposed notifier (`change_notifier.dart:339-344`), so the order is safe either way.
- Host: `_symbolSearch.dispose()` runs in `DocumentHostState.dispose`, after the whole subtree (shell, panel) has unmounted, for the same reason. The host's controller outlives every shell. A shell that disposed the host's controller (my R-3) turns 14 tests red.

### SS13's premise (New / Open sample without a Save dialog)

Typing in the search field does not touch the document, so the document is clean after `pumpSymbolsApp`, and `newFlow` and `openSampleFlow` replace it without `_askToSave`. The test asserts that the replacement happened: the document is a different object and is disposed, and the shell state is new. If a dialog did appear, `await replace()` would never complete and the test would time out, which is a red result, not a false green. See N-2.

### Other checks

- Geometry, sign, tolerance, draw order, permissions and undo are not touched by this diff. The diff touches no frame or paint path; the panel's `setState` on a query change is as it was before.
- Allocation invariant tests are unedited: `git diff --stat 4d6b78f..f424f9b -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants` is empty. The same range over `7dbfc88..f424f9b` is also empty.
- No `analysis_options.yaml` is in the diff, either `7dbfc88..f424f9b` or `4d6b78f..f424f9b`. `git status` in the review worktree shows only `packages/jet_cad/analysis_options.yaml` modified, by pub get, uncommitted.
- Purity holds. `wall_attach.dart` and `symbol_box.dart` import only `package:jet_cad_2d`, `vector_math`, `dart:math`, and app files (`opening_geometry`, `wall`, `wall_geometry`, `symbol_library`), and none of those import Flutter or `dart:ui`. The only grep hits are the comments that state the rule. Neither file is in this diff.

## 2. Gates (re-run by me on `f424f9b`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Gate | Mine | Implementer's |
|---|---|---|
| app `flutter test` | `05:14 +1095: All tests passed!`, exit 0 | `+1095` (post-commit) |
| app `flutter analyze` | `No issues found! (ran in 10.8s)` | No issues |
| app `dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | same |
| app `flutter build web --release` | `✓ Built build/web` | same (pre-commit tree) |
| `apps/dev_harness_2d` `flutter analyze` | `No issues found! (ran in 2.4s)` | same |
| engine, render layer | not re-run: the diff touches only `apps/floor_planner` | not re-run (same reason) |

My counts match the implementer's. The implementer ran analyze, format, web and harness on a pre-commit tree; I ran them on the committed `f424f9b`, and they are green there too.

## 3. Mutants (re-fired by me)

Method: cp backup, mutate (exact single-match replacement), run, cp back, then `diff` the backup against the file. Every restore diff exited 0. The test files were `test/symbols/symbol_panel_test.dart` and/or `test/symbols/symbol_shell_test.dart`. Outputs are in `scratchpad/review10/<id>.out`.

| Id | Mutation | Result | Red tests (summary line) |
|---|---|---|---|
| M-09c-t (spec) | panel `_query` getter -> `final _query = TextEditingController()` | **red** | 4 panel D13 + SS12, SS13, SS14, SS15 (`+25 -8`) |
| M-09c-t2 | panel `dispose` also disposes the controller | **red** | 31 tests (`+2 -31`) |
| M-09c-t3 | panel `dispose` does not remove its listener | **red** | "panel gone…", "different controller…", SS14 (`+30 -3`) |
| M-09c-t4 | `didUpdateWidget` always returns | **red** | "different controller…" (`+17 -1`) |
| M-09c-t5 (plan: shell recreates per build) | `query: TextEditingController(text: '')` | **red** | SS12, SS13, SS14, SS15 (`+11 -4`) |
| M-09c-t6 | host passes a new controller per build | **red** | SS13, SS14 (`+13 -2`) |
| M-09c-t7 | shell ignores the host's controller | **red** | SS13, SS14 (`+13 -2`) |
| M-09c-t8 | host does not dispose its controller | **red** | SS14 (`+14 -1`) |
| M-09c-t9 | bare shell does not dispose its own | **red** | SS15 (`+14 -1`) |
| R-1 (mine) | `didUpdateWidget` keeps the listener on the old controller | **red** | "different controller…" (`+17 -1`) |
| R-2 (mine) | `didUpdateWidget` never listens to the new controller | **red** | "different controller…" (`+17 -1`) |
| R-3 (mine) | shell disposes `_symbolQuery` (the host's) instead of `_ownSymbolQuery` | **red** | SS13, SS1-SS5, SS6-SS8, SS9, SS10, SS12, SS14, SS15 (`+1 -14`) |
| R-4 (mine) | panel `initState` never adds its listener | **red** | 7, incl. "field edits the given controller", SS12 (`+26 -7`) |
| R-5 (mine) | each new shell clears the controller in `initState` (a document change empties the search) | **red** | SS13 (`+14 -1`) |

All 14 are red, and none survive.

## 4. Degenerate fixtures (P-2)

P-2's geometric axes (angle, far origin, mirror, scale, camera scale) do not apply to a text-controller task, and no tool or pointer path is added. The degenerate fixture for this task would be the empty string, and the tests avoid it:

- They use a non-empty query ("bed", "sofa", "sofa three").
- They assert the filtering premise: "bed" ids equal the search's own `searchSymbols(…, 'bed')` result, there are fewer than all ids, and the only category is `['Bed Room']`.
- They check a second distinct text ("sofa") written while the panel is away.
- They distinguish the controller's identity (`same(given)` / `isNot(same(given))`), not just its text.
- SS12 forces a shell rebuild (W) while the panel is away, which targets per-build recreation.
- "A new app starts empty" is checked with a different controller identity, so an empty field there is not a coincidence.

## Notes

- **N-1 (note, spec amendment, Task 11).** Record R-C10-1 in the spec's "Amended at execution (Plan 09c-1)". D13's "The shell owns the search field's `TextEditingController`" should become "the document host owns it, created in `initState` and disposed with the host, and hands it to each shell, which hands it to `SymbolPanel`; a shell without a host owns one of its own". The reason to record: the host keys the shell by `ObjectKey(document)` (12a D2).
- **N-2 (note, test hygiene).** SS13 does not assert `sessionOf(tester).dirty.value == false` before each replacement. A dirty document would make the flow wait on the Save dialog, and the test would time out, which is red. An explicit premise would give a clearer failure message. This is optional.
- **N-3 (note, process).** The implementer reports a `git checkout --` in its own throwaway scratch worktree, which the rules forbid. It is not in the reviewed code, and the controller has already logged it (C-1). The concurrent-runner finding (`build/unit_test_assets` shared between two `flutter test` runs) is confirmed as a real hazard. This review ran its suite and mutants serially, in its own worktree only.
- **N-4 (note).** `PlannerShell.symbolSearch` is read once, in `initState`. A host that later passed a different controller to the same shell would be ignored. The doc comment states this, and the only host passes a `late final` controller, so it is acceptable as is.
