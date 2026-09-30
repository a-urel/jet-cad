# Task 5b review — plan 12a (15cdbea)

**Verdict: Approved.** There are no Important findings. The Task 5 review's I-1, m-1, m-2 and m-4 are closed. **Task 5 as efb8700 + 15cdbea can now be Approved.** I-1 was the only Important finding. m-3 and m-5 need no action in Task 5; m-3 carries R6 to Task 8.

The review worktree was `.claude/worktrees/plan-12a-review2`, detached at `15cdbea` (parent `95bf923`, Task 6). I read:
- `CLAUDE.md`
- the plan: header, P-1 to P-6, Global constraints, Gates, File structure, Task 5, Task 9, and the mutant assignment
- the spec: D2 in full (S-11, S-28, the post-frame disposal) and D8's failure wording
- `t5b-brief.md`, `t5b-report.md`, `t5-review.md` (I-1, m-1 to m-5, P3 to P5) and `t6-report.md` (the 561 baseline)
- `lib/document_host.dart`
- `test/support/document_rig.dart` and `test/support/fake_document_files.dart`

The report's claims were checked by re-running or re-reading them, not taken as evidence.

## Scope

`git show --stat 15cdbea` lists two files, +150 −2:
- `apps/floor_planner/test/document_host_test.dart`
- `apps/floor_planner/test/document_save_test.dart`

The commit is test-only, as the brief requires. There is no `lib` change and no `analysis_options.yaml`.

The two removed lines are the file-header comments, each extended by a clause. No assertion was removed or weakened. The commit message is the brief's, with both trailers, and it is not pushed.

## Brief item by item, checked in the code

**I-1: DH6 (`document_host_test.dart:249-357`).**

The first titled fixture:
- It is opened through `openFlow` from the fake as `plan.jetplan` at `/p/plan`.
- It is edited through the real Wall tool under the rotated 0.1 px/mm camera at `far = (41234.5, 27345.25)`. `drawWall` asserts the shape is ended.
- It is saved with a real Cmd+S chord, which writes in place. Premises: one write at `/p/plan`, no ask, depth 1, clean, and the tuple `(plan, plan.jetplan, /p/plan)`.

After `newFlow()` and one pump:
- the tuple is `('Untitled', null, null)` (`:295`);
- the title is `Untitled — jet-cad`;
- the `document-name` label reads `Untitled`.

The next step draws an off-origin wall on the new document, then presses Cmd+S. It **asks**: `saveLocationCalls == ['Untitled.jetplan']`, and the write goes to `/p/fresh` with the document's codec bytes.

The second titled fixture is opened again at `/p/plan`, edited off-origin and undone. Premises: `canRedo`, clean, titled. It is left clean by undo, not by saving.

`openSampleFlow()` then gives the same untitled result (`:341`). The Save step asks again and writes to `/p/flat`, so `/p/plan` was written exactly once, and `unscriptedCalls == 0`.

This is the fixture the brief asks for: a titled document with a location, edited through a real tool off the origin, then saved or left clean. It is not degenerate. The name, the file name and the location are all non-default before each swap.

**m-1: the post-frame disposal.**

Right after `newFlow()` returns, before any pump:
- the view is still the old document's (a premise, `:288`);
- `saved.commands.isDisposed` is false (`:290`).

After one `pump()` it is true (`:293`). The Open-sample half repeats this (`:337`, `:340`).

**m-2: DS7 (`document_save_test.dart:262-295`).**

The fixture is `titledDirty` at `/p/flat`: the sample opened from the fake, then an off-origin Wall edit at `(-38765.5, 29345.75)`, giving depth 1 and dirty. The panel is scripted with `scriptSaveLocationThrow(StateError('the panel failed'))`.

The test checks, in order:
- one ask, for `flat.jetplan`;
- the dialog's title is `Could not save flat`;
- the dialog's text is exactly `Bad state: the panel failed`. That distinguishes it from the fake's own unscripted-call `StateError`;
- `busy` is true under the dialog;
- after OK: the step returns `false`, the dialog is gone, and there are no writes;
- the document is still dirty and `busy` is false;
- it is the same document object, at depth 1;
- the tuple is unchanged, the title is `• flat — jet-cad`, and `unscriptedCalls == 0`.

This is a "did not change" test that starts dirty with history, as the spec's Testing preamble requires.

**m-4: DH5.** `:219` adds `expect(old.commands.onBeforeMutate, isNotNull, reason: 'premise')` before the swap. It sits next to the existing `expander` and `onAfterMutate` premises, and `:232` asserts null after the swap. It is green at HEAD, so the post-swap null check is now anchored.

## Mutants

**Procedure.** The runner is `scratchpad/p12r5b-mutants.py`. I wrote the mutation strings myself. For each mutant it:
1. copies the file to `scratchpad/p12r5b-<id>-<file>.bak`;
2. applies an exact replace, with the count asserted as 1;
3. runs `CI=true flutter test <files>`;
4. `cp`s the backup back and runs `diff`.

All **16 restores exited with `diff` 0**. Afterwards I ran `cmp` on every backup against the working `lib/document_host.dart` and `lib/main.dart`: all identical. `git status --short` shows only the known ` M packages/jet_cad/analysis_options.yaml`.

The logs are `scratchpad/p12r5b-<id>.log`, and the summary is `p12r5b-mutants-run.log`. Line numbers are the failing expectation's line in the committed test file.

### The task's three targets: all red

| Mutant | Mutation | Run | Red (test : line, actual) |
|---|---|---|---|
| **R3** | `replace`: `_fileName = fileName ?? _fileName; _location = location ?? _location;` | host+save, +13 −1 | DH6 `document_host_test:295`: expected `(Untitled, null, null)`, actual `(plan, plan.jetplan, /p/plan)` |
| **R1** | `oldDocument.dispose()` synchronously in `replace`, before `notifyListeners()`; removed from the post-frame callback | host+save, +13 −1 | DH6 `document_host_test:290`: expected `false`, actual `true` |
| **R10** | the `saveLocation` `catch` in `_saveAs` replaced by `finally {}` | host+save, +13 −1 | DS7 `document_save_test:272`: `Bad state: the panel failed` escapes the `saveAsStep()` future. Then `:277` finds no dialog (`Bad state: No element`) |

### The named mutants the brief asks to stay red

| Mutant | Mutation | Run | Red |
|---|---|---|---|
| M-12a-19 | `replace` neither cancels nor re-listens (keeps the first subscription) | host, +4 −2 | DH4 `:45` (in `dirtyRun`, the "edit" expectation); DH6 `:303` (the dirty premise on the new document) |
| M-12a-20 | the shell disposes the snap unconditionally (`main.dart:601`) | host, +0 −6 | all six DH cases; DH5 `:209` (`'OSNAP'` for `'osnap off'`), the others at teardown or with multiple exceptions |
| M-12a-21 | `oldDocument.dispose()` removed from the post-frame callback | host, +4 −2 | DH5 `:204`; DH6 `:293` |

These match the report's red lines exactly: `:295`, `:290`, `:272`, `:45`/`:303`, `:209`, and `:204`/`:293`.

### My own, at seams the three targets do not separate

| # | Mutation | Red (test : line, actual) |
|---|---|---|
| R3-name-only | only the file name survives `replace` | DH6 `:295`, actual `(plan, plan.jetplan, null)` |
| R3-loc-only | only the location survives `replace` (name Untitled, location `/p/plan`) | DH6 `:295`, actual `(Untitled, null, /p/plan)` |
| R3-new-flow | only `newFlow` passes the current `fileName`/`location` into `replace` | DH6 `:295` |
| R3-sample-flow | only `openSampleFlow` passes them | DH6 `:341`, actual `(plan, plan.jetplan, /p/plan)`. The Open-sample half stands on its own |
| R10-true | the `saveLocation` catch returns `true` | DS7 `:284` |
| R10-no-dialog | the catch returns `false` without showing the dialog | DS7 `:277` (`No element`) |
| R10-unawaited | `unawaited(_showError(…))`, so busy is not held under the dialog | DS7 `:282`, busy `false` |
| R10-filename | the dialog is titled from `fileName` (`flat.jetplan`) | DS7 `:276` |
| R10-markSaved | the catch calls `markSaved(encoded.stateId)` | DS7 `:287`, dirty `false` |
| R10-forget-file | the catch renames the document (`markSaved(savedState, fileName: 'x.jetplan')`) | DS7 `:291`, actual `(x, x.jetplan, null)` |

Every one of these goes red. Each half of DH6 (New, Open sample) and each clause of DS7 has at least one mutant that only it catches.

## Findings

### Important

None.

### Minor

- **n-1. DH6's Save-routing assertions are redundant against R3.** These are the ask (`saveLocationCalls`) and the write to `/p/fresh`, not `/p/plan`. The name/location tuple at `:295`/`:341` fails first under every R3 variant.
  - I found no reachable mutant that keeps the tuple right and still writes in place. `saveStep` with `fileName == null` always goes to Save As.
  - They still pin the user-visible consequence that I-1 named (no silent overwrite), so they are worth keeping.
  - No action.
- **n-2. DH6 swaps from clean documents only**, as the report notes. The dirty-replace path gains the D10 dialog in Task 8, whose tests should include a titled dirty document that is replaced after Discard. There, R3 would matter again through a different flow.
  - This is a note for Task 8's brief, not for this task.

## Is Task 5 (efb8700 + 15cdbea) approvable?

**Yes.**

| Finding | Status |
|---|---|
| I-1 | Closed: R3 red at DH6 `:295`, with both flows independently covered |
| m-1 | Closed: R1 red at DH6 `:290` |
| m-2 | Closed: R10 and five variants red in DS7 |
| m-4 | Closed: the premise is at DH5 `:219` |
| m-3 | Recorded as unreachable today; R6 is to be re-fired in Task 8 (T-8) |
| m-5 | Equivalent; no action |

The Task 5 review found the code conforming to spec. Nothing in `lib` changed since then (15cdbea is test-only), and the named mutants M-12a-19, 20 and 21 remain red.

## Gates

I ran these myself in `plan-12a-review2` at `15cdbea`, with `CI=true` and `PATH=/root/flutter/bin:$PATH`, after the mutant run and restores. The logs are `scratchpad/p12r5b-gate-{test,analyze,format}.log`.

| Package | Command | Result | Exit |
|---|---|---|---|
| app | `flutter test` (the two files, before the mutants) | `00:12 +14: All tests passed!` | 0 |
| app | `flutter test` | `05:25 +563: All tests passed!` (561 at Task 6 + DH6 + DS7) | 0 |
| app | `flutter analyze` | `No issues found! (ran in 5.5s)` | 0 |
| app | `dart format --output=none --set-exit-if-changed .` | `Formatted 120 files (0 changed)` | 0 |

The engine and render packages, and the web build, were not re-run: the commit touches only two app test files. At the end, `git status --short` shows only ` M packages/jet_cad/analysis_options.yaml`, the known rewrite by `pub get`.
