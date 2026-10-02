# Task 10 report — the search text survives a tab switch (spec D13)

Status: committed `f424f9b`; post-commit gate below.

## Design note (proposed ruling R-C10-1)

The host keys the shell by its document (`PlannerShell(key: ObjectKey(document))`,
document_host.dart), so a controller made in `_PlannerShellState.initState`
would die with every document replacement, which D13 says the text survives.
The smallest faithful thing: the controller lives one level up, in
`DocumentHostState` (the object-snap pattern of spec 12a D2 and the Export
choice: "the host's, so a document swap keeps it"), handed to every shell as
`PlannerShell.symbolSearch`; a bare shell (no host) owns one of its own,
created in `initState` and disposed in `dispose`. The shell hands it to
`SymbolPanel.query`, which no longer creates or disposes one.

## Concurrency finding (environment)

While my first full app run was in flight, another agent was editing and
testing in the plan worktree (uncommitted changes to
`test/symbols/furniture_library_test.dart`, `test/symbols/symbol_library_test.dart`,
a new `test/fixtures/`, and live `flutter_tester` processes). That run showed
`+1090 -5`: one failure in `furniture_library_test.dart` (the other agent's
in-progress edit: `bed.wardrobe` 7 leaves vs 6) and four
`Asset 'shaders/ink_sparkle.frag' not found` failures (two `flutter test`
processes sharing `build/unit_test_assets`). Not counted as a gate. To keep
my mutants out of the other agent's runs and theirs out of my gates, gates
and mutants run in a detached scratch worktree
(`scratchpad/task10/wt`, at `bb39637` plus exactly my five files' diff).
I did not touch the other agent's files.


## Commit

- `f424f9b` fix(app): keep the symbol search across tab switches
  (parent `7dbfc88`, another agent's Task 3 follow-up committed while I worked; it touches only
  `test/fixtures/furniture_pre_09c.jetlib`, `furniture_library_test.dart`, `symbol_library_test.dart`, disjoint from mine).

## Files changed (app only; engine and render untouched, not re-run)

- `apps/floor_planner/lib/symbols/symbol_panel.dart`: new required `SymbolPanel.query` (TextEditingController);
  `_query` is now a getter over `widget.query`; `initState` adds the listener, `dispose` only removes it
  (no `dispose()` of the controller); new `didUpdateWidget` moves the listener when a different controller is handed in.
- `apps/floor_planner/lib/main.dart`: `PlannerShell.symbolSearch` (optional); `_PlannerShellState._symbolQuery`
  set in `initState` to the host's or to `_ownSymbolQuery = TextEditingController()`; `_ownSymbolQuery?.dispose()`
  in `dispose`; passed to `SymbolPanel(query: _symbolQuery)`. The panel is still built only on the Symbols tab.
- `apps/floor_planner/lib/document_host.dart`: `DocumentHostState._symbolSearch` made in `initState`, disposed in
  `dispose`, passed as `PlannerShell(symbolSearch: _symbolSearch)`; class doc names it.
- `apps/floor_planner/test/symbols/symbol_panel_test.dart`, `apps/floor_planner/test/symbols/symbol_shell_test.dart`.

## Existing construction sites changed

- `test/symbols/symbol_panel_test.dart`, `Host.build` (the only `SymbolPanel(` in tests, old :143, now :148, the new argument at :156):
  `query: query ?? this.query`, where `Host.query` is a test-owned `TextEditingController` (new field :110,
  disposed in `Host.dispose`). `Host.build`/`Host.pump` gained an optional `query` override (for the
  didUpdateWidget test). No existing assertion was changed.
- `lib/main.dart` `_leftPanel` (the only production site).

## Tests added (8)

Panel (`symbol_panel_test.dart`, group "the search controller is the caller's (spec 09c D13)"):
- "the field edits the given controller, and its text filters the gallery both ways (M-09c-t)"
- "a panel built over a controller that already reads "bed" opens filtered, the clear button showing (M-09c-t)"
- "the panel gone, the controller stays usable: not disposed, and the panel's listener removed (M-09c-t2, M-09c-t3)"
- "a different controller handed in: the panel follows it and leaves the old one (M-09c-t4)"

Shell (`symbol_shell_test.dart`, group "the search text (spec 09c D13)"):
- SS12 "bed" typed, Tools and back (with a W press, a shell rebuild, while the panel is away): field reads "bed",
  gallery == the search's own "bed" ids, categories == ['Bed Room'], clear button shown.
- SS13 a document replacement keeps it: `newFlow()` then `openSampleFlow()`; premises: document replaced and
  disposed, a new shell state, the new shell opens on Tools; then Symbols: same controller, "bed", filtered.
- SS14 the panel gone (Tools tab) the host's controller still takes text and listeners; the next Symbols tab shows
  "sofa" filtered; the app unmounted, the controller is disposed (addListener throws FlutterError); a new app's
  field is empty and its controller a different one.
- SS15 a bare `PlannerShell(symbols: loader)` keeps its own across a tab switch and disposes it on unmount.

## Gates

All in the scratch worktree (see Concurrency finding).
- Pre-commit tree (`bb39637` + my five files, byte-identical to the committed files, checked by `cmp`):
  `CI=true flutter test` -> `07:48 +1092: All tests passed!` (Task 5 recorded 1084; +8 new).
  `CI=true flutter analyze` -> `No issues found! (ran in 9.9s)`.
  `dart format --output=none --set-exit-if-changed .` -> `Formatted 180 files (0 changed)`, exit 0.
  `CI=true flutter build web --release` -> `✓ Built build/web`.
  `apps/dev_harness_2d`: `CI=true flutter analyze` -> `No issues found! (ran in 4.8s)`.
- Engine and render layer: untouched (app files only), not re-run.

## Mutants (all fired in scratch worktree `wt2`, cp backup / mutate / run / cp back / diff exit 0)

| Id | File:line | Change | Red tests | Output excerpt |
|---|---|---|---|---|
| M-09c-t (spec) | `lib/symbols/symbol_panel.dart:116` | `TextEditingController get _query => widget.query;` -> `final TextEditingController _query = TextEditingController();` | panel: all 4 new; shell: SS12, SS13, SS14, SS15 | `00:40 +25 -8: Some tests failed.`; SS12 `Expected: 'bed' Actual: ''` |
| M-09c-t2 (brief: the panel disposes the given controller) | `symbol_panel.dart:147` | `_query.dispose();` added after `removeListener` | 31 tests incl. "the panel gone, the controller stays usable", SS12-SS15 | `00:33 +2 -31: Some tests failed.`; `A TextEditingController was used after being disposed.` |
| M-09c-t3 (the panel leaves its listener) | `symbol_panel.dart:147` | `_query.removeListener(_onQuery);` deleted | "the panel gone, the controller stays usable", "a different controller handed in", SS14 | `00:29 +30 -3: Some tests failed.`; `setState() called after dispose(): _SymbolPanelState#10eb5` |
| M-09c-t4 (didUpdateWidget ignores a new controller) | `symbol_panel.dart` didUpdateWidget | `if (identical(...)) return;` -> `return;` | "a different controller handed in" | `00:09 +17 -1: Some tests failed.`; `Expected: ['sofa.three@1']` |
| M-09c-t5 (plan: the shell recreates it per build) | `lib/main.dart` `_leftPanel` | `query: _symbolQuery,` -> `query: TextEditingController(text: ''),` | SS12, SS13, SS14, SS15 | `00:29 +11 -4: Some tests failed.`; SS12 `Expected: 'bed' Actual: ''` |
| M-09c-t6 (the host recreates it per build) | `lib/document_host.dart` build | `symbolSearch: _symbolSearch,` -> `symbolSearch: TextEditingController(),` | SS13, SS14 | `00:25 +13 -2: Some tests failed.`; `Expected: same instance as TextEditingController` |
| M-09c-t7 (the shell ignores the host's: per-shell, so per document) | `lib/main.dart` initState | `widget.symbolSearch ?? (_ownSymbolQuery = ...)` -> `(_ownSymbolQuery = ...)` | SS13, SS14 | `00:24 +13 -2: Some tests failed.` |
| M-09c-t8 (the host does not dispose it) | `document_host.dart` dispose | `_symbolSearch.dispose();` deleted | SS14 | `00:18 +14 -1: Some tests failed.`; `Expected: throws <Instance of 'FlutterError'>` / `disposed with the host` |
| M-09c-t9 (a bare shell does not dispose its own) | `lib/main.dart` dispose | `_ownSymbolQuery?.dispose();` deleted | SS15 | `00:19 +14 -1: Some tests failed.`; `disposed by the shell that made it` |

Each mutant ran `CI=true flutter test test/symbols/symbol_panel_test.dart test/symbols/symbol_shell_test.dart`
(t4: the panel file; t5-t9: the shell file). Full outputs: `scratchpad/task10/M-09c-t*.out`.

## Proposed rulings

- **R-C10-1 (where the controller lives).** Spec D13 / plan Task 10 say "the shell owns" the controller,
  "created in initState, disposed in dispose", and that the text "survives a document change". The host keys the
  shell by its document (`PlannerShell(key: ObjectKey(document))`, spec 12a D2), so a shell-state controller dies
  with every replacement: both cannot hold. Done: the document host owns it (the object-snap and Export-choice
  pattern: made in `initState`, disposed in `dispose`) and hands it to each shell as `PlannerShell.symbolSearch`;
  a bare shell owns its own (initState/dispose). "A new app starts empty" holds (host per app). Cost if wrong:
  move one field from `DocumentHostState` to `_PlannerShellState` and drop SS13's replacement half. Spec wording
  amendment at execution ("the shell" -> "the document host, through the shell").
- **R-C10-2 (didUpdateWidget).** Not asked for; the panel moves its listener when handed a different controller
  (today nothing does so). One test, one mutant (t4). Cost if wrong: delete 6 lines and a test.

## Found, not fixed

- Concurrent agents in the plan worktree share `build/unit_test_assets`: two simultaneous `flutter test` runs there
  produce spurious `Asset 'shaders/ink_sparkle.frag' not found` failures. Controller may want one test runner per
  worktree at a time, or scratch worktrees for gates/mutants.
- Process slip: when resetting my scratch worktree `wt` to the commit I ran `git checkout -q -- apps/floor_planner/lib
  apps/floor_planner/test` there. It only discarded my own patch in a throwaway detached worktree (the same content
  is in `f424f9b`); no file in the plan worktree was touched that way. Recorded because the rule forbids it.

## For the reviewer to look at hardest

- R-C10-1: whether the host is acceptable as "the shell" for D13.
- SS13 relies on New / Open sample being clean (no Save dialog); premises assert the swap.
- Dispose order: the shell disposes `_ownSymbolQuery` after its subtree (the panel) has removed its listener;
  the host's outlives every shell.

## Post-commit gate (the committed tree, `f424f9b` checked out detached in the scratch worktree)

`CI=true flutter test` -> `08:27 +1095: All tests passed!` (1092 + the 3 tests of `7dbfc88`). Analyze, format,
web build and harness analyze were run on the pre-commit tree, which differs from `f424f9b` only by `7dbfc88`'s
three test-side files.

The scratch worktrees `scratchpad/task10/wt` and `wt2` were removed after the runs (`git worktree remove --force`).
