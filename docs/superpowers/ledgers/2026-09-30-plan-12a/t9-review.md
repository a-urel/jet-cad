# Task 9 (code part) review — plan 12a

**Verdict: Approved.** No Important findings. Two minor findings (m-1, m-2) and three notes follow.

- **Scope:** `5998504..c6c3445`, two commits: `e678183` (item 5) and `c6c3445` (the rest).
- **Where:** the detached worktree `.claude/worktrees/plan-12a-review` at `c6c3445`.
- **What I read:** CLAUDE.md; the plan (header, P-1–P-6, global constraints, gates, Task 9, mutant assignment); spec D2, D7 and the named mutants; `t9-brief.md`, `t9-report.md` and `progress.md` (every Task 9 ruling); the reviews that carried each item (t2, t4, t6, t7, t8).
- **Tree state:** the only change left in the tree is the known `packages/jet_cad/analysis_options.yaml` rewrite. Every restore `diff` exited 0. The width probe file was deleted afterwards.

## Scope and conformance

- **Only the brief's items are in the diff.**
  - lib changes: `main.dart` (the top-bar layout, item 5); `document_host.dart` (the `fileCommands` dartdoc, item 7, and "sample flat", item 11); `startup_plan.dart` (dartdocs only, item 11).
  - Tests: the engine test's comment (item 1); MS4 (item 2); DF7, DF8 (item 4); DC12b (item 5); DH7 (item 6); ST1b, ST5, ST6, ST7, ST8 (items 8–10); RP8 (item 12); DO6's wording (item 13).
  - `pubspec.yaml`: item 3.
- **No `docs/`, `roadmap/` or `STATUS.md` edit.**
- **Commits:** both carry both trailers, and the split matches the brief (`fix(app): …` for item 5, `test: plan 12a sweep …` for the rest).
- **Item 1:** the reworded comment names `commitRedo` and `recordExecute`. Both are real (`undo.dart:44`, `:82`), and `recordExecute` is the one that clears `_redo` (`:48`). The comment is true.
- **Item 11:** my own grep of `apps/floor_planner/lib`, `packages/*/lib` and `macos/Runner` for `fixture a human|no redo|before sub-project 12|sub-project 12|startup flat|app opens on|opens on the|startup document|launch flat` finds only `outline_cache.dart:48` ("the startup plan at x = 5e3"). That is a precision rationale in the frozen render package, not a claim about launch, so it is not stale. Every `launch`/`startup` mention left in the app's lib describes 12a correctly.

## The 13 carried items — each landed, each pinned by a mutant I fired

| # | Landed | Mutant (my spelling) | Red on `c6c3445` |
|---|---|---|---|
| 1 | yes (comment only) | — | — |
| 2 | MS4 `:181-183` | R3 `isMidShape => isPending && controller.text.isNotEmpty` | +32 −2: **MS4 mid_shape:181** (×2 flipY) |
| 3 | flutter `>=3.38.0`, sdk kept `^3.5.0` (deviation, ruled) | — | see Deviations |
| 4 | DF7 `:151`, DF8 `:175` | R7 (the fake checks `holdWrites` first); S1 (drop the `dart.library.io` export line) | R7 +7 −1: **DF7 files:160** (`Expected: empty, Actual: [_AsyncCompleter]`, an assertion, not a timeout). S1 +7 −1: **DF8 files:180** (the stub's `UnsupportedError`) |
| 5 | `main.dart:684-720`, DC12b `:883` | old layout (the `5998504` bar with its `Spacer`, taken from `git show`); halves (`Flexible` name + `Expanded` status) | old layout +16 −1: **DC12b commands:923**. Halves +16 −1: **DC12b commands:923** |
| 6 | DH7 `host:360` | R6 (the `_fileEnabled` dispose loop dropped) | +6 −1: **DH7 host:380** |
| 7 | dartdoc `document_host.dart:228-232` | — | — |
| 8 | ST1/ST1b loop | Y6 (`saveAsStep` without `_settlePendingInput`) | +8 −1: **ST1b settle:140** |
| 9 | ST5 touch/macOS, ST6 mouse/Android | Y1 (`if (!kIsWeb)`); Y2 (macOS moved to the `return` cases) | Y1 +8 −1: **ST6 settle:337**. Y2 +8 −1: **ST5 settle:297** |
| 10 | ST7 `:342`, ST8 `:379` | Y8 (re-sync only while the scale is focused); Y9 (the settle skips an empty entry) | Y8 +8 −1: **ST7 settle:373**. Y9 +8 −1: **ST8 settle:396** |
| 11 | yes | — | grep above |
| 12 | RP8 `replace:594` | M-12a-24 (the above-Navigator binding dropped) | +26 −2: **RP8 replace:628** (`handled`), DC9 commands:649 |
| 13 | DO6 `open:305`, `:382` | — | — |

**The fixtures are not degenerate.**
- ST7: the typed `40` differs from the stored scale, and it leaves by Tab, not by a tap.
- ST8: a wall is in history, so the undo depth is 1.
- DH7: three swaps of different kinds, then busy still reaches the new shell's Save.
- RP8: titled and dirty, both modifiers, four chords each.
- DC12b: a 1440 × 900 window, a real room notice, and a long name after Save As.

## Named mutants re-fired (my own spellings, not the implementer's script)

| Mutant | Mutation | Result | Red test : line |
|---|---|---|---|
| M-12a-2 | `markSaved(_session.savedState, …)` | +4 −11 (host + exit) | **DH3 host:68**, DH4:68, DH6:275; **EX1 exit:64**, EX2/4/5/6/7:41, EX3:210, EG1:374 |
| M-12a-10 | `while (_session.differsFromSave && identical(1, 2))` | +1 −10 (replace) | **RP1 replace:124**, RP2:164, RP3:213, RP4:260, RP6:355, RP7:423, RN1:453, RN2:505, RN3:549, RP8:607 |
| M-12a-13 | `markSaved(_session.document.commands.stateId, …)` | +6 −2 (save) | **DS1 save:75** |
| M-12a-19 | `_changes?.cancel()` and the re-`_listen()` in `replace` dropped | +5 −2 (host) | **DH4 host:48**, DH6:304 |
| M-12a-24 | the above-Navigator `kFileChords` binding dropped | +26 −2 | **DC9 commands:649**, **RP8 replace:628** |
| M-12a-26 | the nested `_flow` clears busy in a `finally` | +16 −3 (replace + exit) | **RN2 replace:521**, RN3:561, EX4 exit:266 |
| M-12a-28 | `TextTool.isMidShape => isPending` (app tests) | +6 −3 (settle) | **ST3 settle:206**, ST2:177, ST8:396 |
| M-12a-29 | the Redo `canRedo` guard dropped | +16 −1 (commands) | **DC10 commands:732** (`spy.calls`, the `onBeforeMutate` spy) |

These match the implementer's table. The only difference is that for M-12a-10 I record the test's own line where it failed inside `document_rig.dart` (for example RP2:164); the report records `rig:114` for those.

## My own mutants at seams the sweep did not name

| Mutant | Mutation | Result | Red |
|---|---|---|---|
| O1 | `DerivedFlag.dispose` skips its first source, so a shell file flag leaks onto the host's `_notBusy`, which DH7 does not count | +15 −9 | "A DerivedFlag was used after being disposed" on the next busy change: DH7 host:396, DH2:147, DH5:224, DH6:269, DC4/DC9 commands:117, DC12b:934, and others |
| O2 | the shell's `_undoEnabled.dispose()` dropped | +6 −1 | **DH7 host:380** |
| O3 | the fake reuses the queued write error (`.first`, not `removeAt(0)`) | +6 −2 | DF5 files:103/108, **DF7 files:167** |
| O4 | no 16 px gap between the name and the status | +16 −1 | **DC12b commands:925** |
| O5 | the name capped at a third | +16 −1 | **DC12b commands:938** |
| O6 | the outer binding lacks the Save As chords | +26 −2 | DC9 commands:649, **RP8 replace:628** |
| O7 | the outer binding keeps only the Meta chords | +26 −2 | DC9 commands:649, **RP8 replace:628** |
| O8 | `resyncScale() {}` | +7 −2 | ST4 settle:263, **ST7 settle:373** |
| O9 | the name capped at the full shared width | +15 −2 | DC12 commands:826, DC12b:937 |

Every mutant I fired (8 named, 11 carried or sample, 9 own; 28 runs) is red. There is no survivor. O1 answers the question item 6's deviation leaves open. DH7 counts only `session.busy`, but a leak onto `_notBusy` is still caught, by the framework's used-after-dispose assertion on the next busy change. The gap is closed in practice.

## Findings

**m-1. The layout of item 5 overflows 32 px sooner in a narrow window.**
- **Probe:** a temporary widget test (not landed; deleted after) pumps `FloorPlannerApp` at 600 px high, stepping the width down from 900 by 2 px.
  - On `c6c3445`, the first overflow is at **622 px** ("A RenderFlex overflowed by 1.00 pixels on the right").
  - With the `5998504` bar restored (by `cp`, then restored, `diff=0`), the first overflow is at **590 px**.
- **Why:**
  - The new fixed `SizedBox(width: 16)` before OSNAP replaces a `Spacer` whose minimum is 0.
  - Inside the shared `Expanded`, the name's cap `W/2` plus the 16 px gap exceeds `W` once `W < 32`. Before, only the 16 px gap was fixed.
- **Impact:** the target sizes (800 × 600 in DC12, 1440 × 900 in DC12b) are unaffected, and so is the ruling's intent. Spec D7 does name "a narrow window", though.
- **Suggested fix:** cap the name at `max(0, (constraints.maxWidth - 16) / 2)`, and decide whether the gap before OSNAP is wanted. Otherwise, record the 624 px floor with D14's limits.

**m-2. DC12b's premise at `document_commands_test.dart:927-928` is tautological.**
- **What:** `paragraph(status).size.width > shared / 2` is meant to show that the notice's text needs more than half the shared width. But the status `Text` sits in an `Expanded`, so its `RenderParagraph` is laid out tight, and `size.width` is the slot's width, not the text's.
- **Why it matters little:** the old-layout and halves mutants, red at `:923`, prove the notice does need more than half. The test works, but this line does not check what its reason says. If the fixture's text were ever shortened, the test would stop distinguishing the layouts and stay green.
- **Suggested fix:** compare `paragraph(status).getMaxIntrinsicWidth(double.infinity)`.

**Notes (no action in this task):**
- **n-1:** RP8's "no write / no picker / one dialog" expectations cannot go red under M-12a-24. The shell's bindings are not in the dialog route's focus chain, and busy is set in any case. The chord being handled (`:628`) is what M-12a-24 turns red. That is the intent (T-3, U-3); the other expectations guard a future regression.
- **n-2:** the spec amendment should cover D7's literal wording ("`Flexible` … `Flexible` … Spacer", spec `:423-426`). The bar is now one `Expanded` holding a name capped at half and an `Expanded` status, with a 16 px gap before OSNAP.
- **n-3:** stale citations spot-checked, all confirmed:
  - `placement_tool.dart:206-211`
  - `text_entry_overlay.dart:80-86` (`_onFocus`) and `:24-29`
  - `text_tool.dart:59` (`finish`)
  - `page_panel.dart:96-98` (`_onScaleTapOutside`)

## Deviations (judged)

- **Item 3 (sdk kept `^3.5.0`):** sound.
  - I checked without touching the pubspec: `dart format --language-version=3.10 --output=none --set-exit-if-changed lib test` in the app gives "Formatted 127 files (120 changed)"; at 3.5 it gives 0 changed.
  - `file_selector_web-0.9.5` and `file_selector_macos-0.9.5+1` (both in the lock) declare `sdk: ^3.10.0` and `flutter: ">=3.38.0"`, so the flutter bound states the real floor.
  - Ruled; the language bump is a later item.
- **Item 5 (a half-capped name in a shared `Expanded`, not `Flexible` + `Expanded`):** sound. The halves mutant (the literal reading) is red at DC12b:923, so the literal form would not meet the ruling's intent. The residual cost is m-1.
- **Item 6 (only `session.busy` counted):** acceptable. R6 and O2 are red at DH7:380, and O1 shows a leak onto `_notBusy` is caught anyway.
- **DF7 reorder:** correct. R7 now fails on an assertion at `:160`, not on a 30 s timeout.

## Greps (run by me on `c6c3445`)

- `grep -rn "dart:io" apps/floor_planner/lib` → `lib/document_files_io.dart:6` only.
- `grep -rln "package:web" apps/floor_planner/lib` → `document_files_web.dart`, `exit_guard_web.dart`.
- `grep -rn cross_file` over the app's pubspec, lib and test, `packages/*/pubspec.yaml`, `packages/*/lib` and the root pubspec → no output (rc 1). It appears in `pubspec.lock:116` only, as a transitive dependency.
- `grep -rnwE "takeUndo|pushRedo|takeRedo|pushUndoOnly"` over `packages/*/lib`, `packages/*/test` and the app's lib and test → no output (rc 1). `\.push\(` finds only `parametric/room_label.dart:55,71-74`, which is `_MaxHeap` (`:51`), not `UndoStack`.
- `grep -rn "startupPlan(" apps/floor_planner/lib` → `document_host.dart:363` (Open sample) and `startup_plan.dart:65` (the definition). 14 test files; none in packages.
- `parametricCatalog.registerComponents`:
  - lib: `parametric/catalog.dart:45`, inside `registerAppComponents`.
  - tests: the 10 hits the report lists, each a decode's `registerComponents` argument or closure (I read the context of room_fixture 651/688, startup_plan_test 737, selection_panel_test 702, opening_panel_test 514).
- `Future.delayed(Duration.zero)` in the app's lib and `packages/*/lib` → no output. `debugOnSettle` in `apps` and `packages` → no output.

## Gates (`c6c3445`, `export PATH=/root/flutter/bin:$PATH`, `CI=true` on each; after `flutter pub get`)

| Package | Command | Result |
|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.`: the two standing `generate_document_test` cases (rc 1, standing) |
| engine | `dart analyze` / `dart format …` | No issues found! / Formatted 159 files (0 changed) |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.`: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 (standing) |
| render | `flutter analyze` / `dart format …` | No issues found! / Formatted 178 files (0 changed) |
| app | `flutter test` | `+595: All tests passed!` (rc 0) |
| app | `flutter analyze` / `dart format …` | No issues found! / Formatted 127 files (0 changed) |
| app | `flutter build web --release` | `✓ Built build/web` (rc 0) |

The counts match the report and the branch point plus Task 9's 8 new app tests.

**Logs and scripts** (scratchpad):
- `p12r9-gate-engine.log`, `p12r9-engine-full.log`, `p12r9-render-full.log`, `p12r9-app-full.log`, `p12r9-web.log`
- mutants: `p12r9-mut.py`, `p12r9-sweep.out`, one `p12r9-<name>.log` per mutant, and the parser `p12r9-parse.py`
- the width probe: `p12r9-probe.py`, `p12r9_probe_width_test.dart`
