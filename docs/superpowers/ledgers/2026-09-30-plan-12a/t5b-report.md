# Task 5b report: the Task 5 review's I-1, m-1, m-2, m-4 (plan 12a)

**Commit:** `15cdbea` `test(app): a replaced titled document forgets its file`
on `plan-12a/document-lifecycle` (parent `95bf923`). Not pushed. It ends with
the two trailers. The change is test-only: 2 files, +150 −2.
- `apps/floor_planner/test/document_host_test.dart`
- `apps/floor_planner/test/document_save_test.dart`

There is no `lib` change: `git diff --quiet HEAD` on `lib/document_host.dart`
and `lib/main.dart` exits 0. `packages/jet_cad/analysis_options.yaml` was
modified by `flutter pub get`; it is left unstaged and was not committed.

## What landed

**I-1 and m-1: DH6** (`document_host_test.dart`). The case is "New and Open
sample from a titled document forget its file".

1. **Titled and saved.** The sample is opened as `plan.jetplan` at `/p/plan`.
   A wall is drawn through the Wall tool under the rotated 0.1 px/mm camera,
   centred far from the origin at (41234.5, 27345.25). Cmd+S (a real chord)
   then writes in place. Premises: one write at `/p/plan`, no ask, depth 1,
   clean, `(plan, plan.jetplan, /p/plan)`.
2. **New.** Right after `newFlow()` returns, before any pump:
   - the view is still the old document's (premise);
   - the old document is **not** disposed (m-1).

   After one `pump()`:
   - it is disposed;
   - the view is the new document's;
   - the name, file name and location are `('Untitled', null, null)`;
   - the title is `Untitled — jet-cad`;
   - `document-name` reads `Untitled`.
3. **Edit, then Cmd+S.** A wall is drawn on the new document, far from the
   origin. Cmd+S then **asks**:
   - `saveLocationCalls == ['Untitled.jetplan']`;
   - the second write goes to `/p/fresh` with the document's bytes, not to
     `/p/plan`;
   - the document is named `fresh`, is clean, and sits at `/p/fresh`.
4. **Titled and left clean.** `plan.jetplan` is opened again at `/p/plan`. A
   wall is drawn off-origin and then undone. Premises: `canRedo`, clean,
   titled.
5. **Open sample.** The old document is not disposed before the pump and is
   disposed after it. The name, file name and location are
   `('Untitled', null, null)`, and the title and name label read `Untitled`.
   The Save step then asks:
   - a second `Untitled.jetplan` ask;
   - the third write goes to `/p/flat`;
   - `/p/plan` was written exactly once, by its own save;
   - `unscriptedCalls == 0`.

**m-2: DS7** (`document_save_test.dart`). This is a Save As whose
`saveLocation` throws, on a titled, dirty document. The fixture is
`titledDirty` at `/p/flat`, edited off-origin at (-38765.5, 29345.75). The
throw is `scriptSaveLocationThrow(StateError('the panel failed'))`. The test
asserts:
- one ask, for `flat.jetplan`;
- the dialog's title is `Could not save flat` and its text is
  `Bad state: the panel failed`;
- the flow is busy while the dialog is up;
- after OK:
  - the step returns `false` and the dialog is gone;
  - there are no writes;
  - the document is still dirty, busy is cleared, and it is the same
    document with `undoDepth` 1;
  - it is still `(flat, flat.jetplan, /p/flat)`, titled `• flat — jet-cad`;
  - `unscriptedCalls == 0`.

**m-4: DH5.** One premise was added before the swap:
`expect(old.commands.onBeforeMutate, isNotNull, reason: 'premise')`.

Both file headers now name the new cases. The app suite went from 561 to
**563** tests.

## Mutants

**Procedure.** The runner is `…/scratchpad/p12t5b-mutants.py`. It uses the
reviewer's exact mutation strings from `p12r5-mutants.py`, and for each
mutant it:
1. copies the file to a backup at `…/scratchpad/p12t5b-<id>-<file>`;
2. applies an exact replace, asserting a count of 1;
3. runs `CI=true flutter test <file>`;
4. `cp`s the backup back and runs `diff`.

Every restore's `diff` exited 0. Afterwards, `cmp` of every backup against the
committed `lib/document_host.dart` and `lib/main.dart` showed them identical.
The logs are `p12t5b-<id>.log`, and the summary is `p12t5b-mutants-run.log`.
Line numbers refer to the committed test files.

| Mutant | Mutation | Result: red test and line |
|---|---|---|
| **R3** | `replace` keeps `fileName ?? _fileName` and `location ?? _location` | **RED**, DH6 `document_host_test:295`. Actual `(plan, plan.jetplan, /p/plan)` |
| **R1** | the old document is disposed synchronously in `replace`, not post-frame | **RED**, DH6 `:290`, "not disposed under the still-mounted old shell". Actual `true` |
| **R10** | the `saveLocation` throw is uncaught (`} finally {}`) | **RED**, DS7 `document_save_test:272`. The `StateError: the panel failed` escapes `saveAsStep`, and then `:277` finds no dialog |
| M-12a-19 | `replace` keeps the first subscription | **RED**, DH4 `:45` (dirtyRun's "edit"; called at `:188`), and also DH6 `:303` (the dirty premise after an edit on the new document) |
| M-12a-20 | the shell disposes the snap unconditionally | **RED**, all six DH cases. "A SnapSettings was used after being disposed": DH5 `:209`, DH6 `:298`, and DH1 to DH4 at teardown, as in the Task 5 report |
| M-12a-21 | the old document is never disposed | **RED**, DH5 `:204` ("the first swap"), and also DH6 `:293` ("disposed after it") |

All the DH line numbers moved by +1 against the Task 5 review. The header
comment of `document_host_test.dart` gained a line, and the lines after 217
also moved by the m-4 premise.

## Gates

These are for the app, in the worktree, with `CI=true` and
`PATH=/root/flutter/bin:$PATH`, run on the final tree before the commit. The
logs are `…/scratchpad/p12t5b-app-{test,analyze,format}.log`.

| Command | Result | Exit |
|---|---|---|
| `flutter test` | `04:01 +563: All tests passed!` | 0 |
| `flutter analyze` | `No issues found! (ran in 1.7s)` | 0 |
| `dart format --output=none --set-exit-if-changed .` | `Formatted 120 files (0 changed)` | 0 |

The engine and render packages were not touched and were not re-run.

## Notes

- The first `dart format` check flagged `document_host_test.dart`. It was
  formatted before the mutant runs and the gates, so every line number above
  is from the committed file.
- DH6 swaps from a clean document both times: once saved, once edited and
  undone. The dirty-document dialog (D10) that comes later therefore does not
  change what it asserts.
