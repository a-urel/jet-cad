# Task 8 report: app, replacing and closing a dirty document (plan 12a, spec D10, D11, D12 Swift)

**Commit:** `5998504` `feat(app): ask before replacing or closing a dirty document` on `plan-12a/document-lifecycle` (parent `725ff74`). Not pushed. The message ends with the two trailers. 12 files, +1349 −37:
- `lib/document_host.dart`, `lib/main.dart`
- `lib/exit_guard.dart`, `lib/exit_guard_stub.dart`, `lib/exit_guard_web.dart` (new)
- `macos/Runner/MainFlutterWindow.swift`
- `test/document_replace_test.dart`, `test/document_exit_test.dart`, `test/support/fake_exit_guard.dart` (new)
- `test/support/document_rig.dart`, `test/document_host_test.dart`, `test/document_open_test.dart` (migrated, see deviation 2)

`packages/jet_cad/analysis_options.yaml` has been rewritten by `pub get`. It is left unstaged and was not committed.

## The API as landed

**`document_host.dart`**
- `enum SaveChoice { save, discard, cancel }`.
- `DocumentSession.differsFromSave`: `stateId != savedState`, read from the dispatcher now. `_recompute` uses it. See **the defect found** below.
- `DocumentHost({session, files, ExitGuard? exitGuard})`. The host owns the guard: it disposes it, and uses `createExitGuard()` when the guard is null.
- `DocumentHostState`:
  - **`_mayDiscard()`.** The loop is `while (_session.differsFromSave)`, which asks `_askToSave()`:
    - Save: `if (!await saveStep()) return false;` and then loop. The save is nested, so busy stays the outer flow's. A save that succeeds while an edit landed during the write asks again (T-8).
    - Don't Save: true.
    - Cancel: false.

    A clean document gets true with no dialog.
  - **`_askToSave()`** is `showDialog<SaveChoice>(barrierDismissible: false)` of `_SaveChangesDialog`, with `null` read as cancel. The dialog:
    - keys: `replace-dialog`, `replace-title` ("Save the changes to <name>?"), `replace-discard`, `replace-cancel`, `replace-save`;
    - Save is a `FilledButton` with `autofocus: true`, so Enter saves;
    - Escape is bound to Cancel by a `CallbackShortcuts` inside the dialog.
  - **The flows.** `newFlow`, `openSampleFlow` and `openFlow` run `_settlePendingInput(); if (!await _mayDiscard()) return;` first. For Open this comes before the picker.
  - **`_onExitRequested()`** (T-7):
    1. `busy` → `AppExitResponse.cancel`.
    2. Otherwise `_flow(() { settle; return _mayDiscard(); })`, so the exit is itself a busy flow: its dialog disables the commands, and a second request cancels.
    3. The result: `exit` or `cancel`.

    It checks busy, not idle, so a pending shape does not block the exit (U-7).
  - **Lifecycle.**
    - `initState`: `_exitListener = AppLifecycleListener(onExitRequested: _onExitRequested)`; `_exitGuard = widget.exitGuard ?? createExitGuard()`; arm it now; `_session.dirty.addListener(_armExitGuard)`.
    - `dispose`: remove the listener, dispose the guard, dispose the lifecycle listener.
- **`FloorPlannerApp({files, exitGuard})`**: a new test seam, passed through to the host.

**`exit_guard.dart`**
- `abstract interface class ExitGuard { set armed(bool); void dispose(); }`.
- `export 'exit_guard_stub.dart' if (dart.library.js_interop) 'exit_guard_web.dart';`. I checked that `dart.library.js_interop` is false on this VM.
- Stub: `createExitGuard()` returns a no-op guard.
- Web: `WebExitGuard` adds and removes one `beforeunload` `JSFunction` on arm and disarm. The handler calls `preventDefault()` and sets `returnValue` to a non-empty string. `dispose` disarms.
- `package:web` is imported only in `*_web.dart`, and `dart:io` only in `document_files_io.dart` (grep).

**`MainFlutterWindow.swift`**
- `@objc func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }`, with a comment citing spec 12a D11 (R-4, T-13).
- **It cannot be built or run here** (no macOS toolchain). It is left for the human's look.

## The defect found (in scope, fixed)

The controller's note asked for a clean document with an unsubmitted panel value, then New. On the first run of that test (RP7), **New replaced the document with no dialog, so the typed and just-committed edit was lost**.

- **Cause.** The settle commits synchronously, but `session.dirty` is recomputed from `commands.changes`, an async stream that delivers a microtask later. The check read the notifier, which still said clean.
- **Fix.** `_mayDiscard` reads `differsFromSave`, which asks the dispatcher.
- **Pins.** The mutant X1, which reverts to `dirty.value`, is red at RP7 and EX5. The exit path had the same exposure, and M-12a-25's test (EX5) covers it.

## Tests

The app is **+587 = 569 (at `725ff74`) + 18 new**. No existing test was removed. Three were migrated (deviation 2).

Every fixture is dirty with history from the real Wall tool, far off the origin (`(-39876.25, 33456.5)` for the replace tests, `(44321.75, -36543.25)` for the exit tests), under the rig's rotated 0.1 px/mm camera, with the shape ended (Select active). Titled fixtures are the sample opened as `plan.jetplan` at `/p/plan`, or a Save As to `/p/hall`. Before any await on a flow or exit future, `noDialog`/`requestExit` assert that no dialog is left, so a mutant fails fast instead of hanging.

**`document_replace_test.dart`**

| Test | Pins |
|---|---|
| RP1 | Titled and dirty, then New, Open sample and Open. Each is answered once with Cancel and once with Escape. Pins:<br>• the dialog appears, with its title<br>• busy is true under it, and all seven buttons are disabled<br>• afterwards: the same object in the session and the view, not disposed, the same depth, dirty, the name/fileName/location tuple and title unchanged, not busy, New enabled again<br>• no picker, no panel, no write |
| RP2 (n-2, R3) | **Titled and dirty**, then New and Don't Save:<br>• the old document is disposed; the new one is empty<br>• `(Untitled, null, null)`, clean, the title and the `document-name` label<br>• nothing is written<br>Then titled and dirty again, then Open sample and Don't Save: the same, with the sample's bytes. Then an edit and Cmd+S **asks where** (`Untitled.jetplan`) and writes to `/p/new`, not over `/p/plan`. |
| RP3 | **Untitled and dirty**, New, Save, and the panel is cancelled:<br>• one ask, no write<br>• the same document and depth, dirty, not busy<br>**Titled and dirty**, Open sample, Save, and the write fails:<br>• the error dialog, busy under it<br>• `expectKept`, and the write was attempted at `/p/plan` |
| RP4 | Titled and dirty, then New, answered with **Enter** (the default is Save):<br>• written in place with the bytes from before the swap, no ask<br>• then replaced: empty, untitled, clean, not busy<br>Then untitled and dirty, Open sample, Save: a Save As at `/p/room` with the document's bytes, then replaced by the sample. |
| RP5 | A clean titled document with history (edited, then saved), then New, Open sample and Open: **no dialog**, each replaces, and Open calls the picker at once. |
| RP6 | Titled and dirty, then Open. The dialog appears **before the picker** (`openCalls` unchanged):<br>• Cancel: no picker, everything kept<br>• Save: written with the pre-swap bytes, **then** the picker; `other` at `/p/other`, clean |
| RP7 (controller's note, and the defect above) | A clean titled document; the drawn wall is selected, and its thickness is typed without Enter (the field has focus, nothing is committed, clean). Then New, Open sample and Open, in turn:<br>• the dialog appears<br>• the value **was committed** as its own step (depth +1)<br>• Cancel: `expectKept` at depth +1<br>Between the three, a re-save makes the document clean again. |
| RN1 (T-8) | Titled and dirty, then **Cmd+N**, Save, with the write held. Then Cmd+O, Cmd+S, Cmd+N, Cmd+Z and a tap on each of the 7 buttons, all disabled:<br>• no picker, no ask, no second write, no second dialog<br>• the depth and `stateId` unchanged, busy<br>Completing the write gives the pre-flow bytes, the document replaced, not busy. |
| RN2 (T-8, M-12a-26) | Titled and dirty, New, Save, write held. A **wall is drawn through the tool while the write is held**. Completing it gives:<br>• the written bytes are the pre-edit ones<br>• **the dialog again**, the document not replaced, dirty<br>• **busy still true**, and the buttons disabled<br>Cancel then keeps the edit (`expectKept`). |
| RN3 (t5-review m-3, R6) | Titled and dirty. `saveStep()` with the write held (the outer flow), then `newFlow()` called directly (nested), then Don't Save, which swaps. The UI cannot reach this, because every command is disabled while busy, so the flows are called directly. Completing the write gives:<br>• `true`<br>• the **new** document stays `(Untitled, null, null)` with its title<br>• `savedState == fresh.stateId`, clean, not busy<br>An edit and Cmd+S then ask where. |

**`document_exit_test.dart`** (all through `tester.binding.handleRequestAppExit()`)

| Test | Pins |
|---|---|
| EX1 (M-12a-2 exit half) | Clean at launch: exit. An edit, then **Cmd+S (Save As), then the exit: exit, no dialog**. No premise reads the save point in between. The same after a save in place. |
| EX2 | Titled and dirty:<br>• Cancel: cancel, and everything kept; busy under the dialog<br>• Escape: cancel<br>• Save with a failing write: the error dialog, then cancel, still dirty<br>• Don't Save: exit, nothing written, the document untouched<br>• Save that succeeds: the document's bytes in place, then exit, clean |
| EX3 | Untitled and dirty:<br>• Save with the panel cancelled: cancel, one ask, no write, dirty<br>• Save As scripted: exit, and the bytes are the document's |
| EX4 (S-17, T-8) | Busy cancels at once, with **no second dialog**:<br>• while New's dialog is up<br>• while a Cmd+S write is held<br>• while the exit's own Save is held<br>In the last case, an edit during the hold gives the pre-edit bytes, then **asked again** (busy), then Don't Save, then exit. |
| EX5 (T-7, M-12a-25) | Clean titled, a selected wall's thickness typed without Enter. The exit request brings up **the dialog**: the value is committed as its own step. Cancel gives cancel, and the value stays. |
| EX6 (U-7) | A Wall placement part-way on a clean document: exit, no dialog. A chain with a wall down: the dialog, then Don't Save, then exit. |
| EX7 (S-18 disposal) | A dirty document, the app replaced by a `SizedBox`, then the exit request: `exit`, and `takeException()` is null. |
| EG1 (D9, D11) | With `writesInPlace: false` and a `FakeExitGuard`, the armings are **exactly** `[false, true, false, true, false, true, false, true, false, true, false, true, false]`, for: launch, edit, undo, the Redo button, a web Save As, edit, a titled web Save (no ask), edit, New (Don't Save), **the new document's edit**, undo, edit, Open sample. The guard is disposed with the host. |

**Rig and support.**
- `pumpApp(…, {FakeExitGuard? exitGuard})`.
- `answerReplace(tester, key)` (premise: the dialog is up), `discardAndRun(tester, flow)` and `noDialog(tester)`.
- `FakeExitGuard` records every `armed`, has `isArmed` and `disposed`, and throws if armed after dispose.

## Mutants

Procedure, driven by `…/scratchpad/p12t8-mutants.py`:
1. `cp` to `…/scratchpad/p12t8-<id>-document_host.dart.bak`.
2. An exact replace, with the count asserted as 1.
3. `CI=true flutter test <files>`.
4. `cp` back, then `diff`: **every one exited 0**.

The final run is `p12t8-mutants-run.log`, with per-mutant logs `p12t8-<id>.log`. It ran on the final tests. Afterwards `lib/document_host.dart` is identical to the pre-run reference copy.

**One incident.** An earlier run was stopped mid-mutant, and it left `M-12a-10-all` in the file. I restored it from that mutant's `.bak` (diff against the reference was clean) before anything else ran. No `git checkout` was used.

Lines are the failing expectation's line in the named file. `rig:114` is `answerReplace`'s "the dialog is up" premise.

| Mutant | Mutation | Red test : line |
|---|---|---|
| **M-12a-2 (exit)** | `markSaved(_session.savedState, …)` in `_write` | **EX1 `document_exit_test:92`** (the exit after Save As asked, `requestExit`'s `:64`); the others at `titledClean`'s clean premise `:41`; EG1 `:374` |
| **M-12a-10** (all) | `while (false && differsFromSave)` | RP1 :124, RP2/RP3 rig:114, RP4 :260, RP6 :355, RP7 :423, RN1–RN3 |
| M-12a-10, New only | the `_mayDiscard` line dropped from `newFlow` | RP1 :124, RP2 rig:114, RP3 rig:114, RP4 :260, RP7 :423, RN1–RN3 rig:114 |
| M-12a-10, Open sample only | the same in `openSampleFlow` | RP1 :124, RP2/RP3/RP4 rig:114, RP7 :423 |
| M-12a-10, Open only | the same in `openFlow` | RP1 :124, RP6 :355, RP7 :423, DO6 `document_open_test:339` |
| **M-12a-25** | `if (!differsFromSave) return exit;` before the settle | EX5 :301 |
| **M-12a-26** | the nested `_flow` clears busy in a `finally` | RN2 :521 (busy under the second dialog), RN3 :561, EX4 :266 |
| **R3** (n-2) | `_fileName = fileName ?? _fileName; _location = location ?? _location;` | **RP2 :169** (actual `plan…/p/plan`), RP4 :272, RN1 :485, RN3 :552 |
| **R6** (m-3) | the `identical(document, encoded.document)` guard becomes `if (true)` | **RN3 :567** (the new document named `plan`) |
| S-new (controller) | `newFlow` without the settle | RP7 :423 |
| S-sample (controller) | `openSampleFlow` without the settle | RP7 :423 |
| S-open (controller) | `openFlow` without the settle | RP7 :423 |
| X1 | `_mayDiscard` reads `dirty.value` (the defect) | RP7 :423, EX5 :301 |
| X2 | Save succeeded, so `return saveStep()` (no re-ask) | RN2 :518, EX4 :265 |
| X3 | Open asks after the picker | RP1 :124, RP6 :355, RP7 :423, DO6 :339 |
| X4 | the exit ignores busy | EX4 (`requestExit` :64, a second dialog) |
| X5 | the exit is not a busy flow (`Future.sync`) | EX2 :130 (not busy under the dialog), EX4 :266 |
| X6 | Escape unbound (rebound to F24) | RP1 :138, EX2 :142 |
| X7 | Save not autofocused (Enter does nothing) | RP1 :138, RP4 :263 |
| X8 | the guard does not listen to dirty | EG1 :365 |
| X9 | the guard is not disposed | EG1 :414 |
| X10 | the lifecycle listener is not disposed | EX7 :349 (a stale host answers), and EX2 :165, EX3 :211, EX4 :269, EX6 :326 |
| X11 | the guard is armed with `!dirty` | EG1 :361 |
| X12 | Don't Save returns false | RP2 :166, RN3 :550, EX2 :165, EX4 :269, EX6 :338, EG1 :391 |
| X13 | the exit does not settle | EX5 :301 |

**Web build probe W1.** I set `exit_guard_web.dart`'s `returnValue` to `42`. `CI=true flutter build web --release` then **exited 1**: `lib/exit_guard_web.dart:29:25: Error: A value of type 'int' can't be assigned to a variable of type 'String'`. I restored the file (diff 0). The web build therefore compiles the `_web` guard.

## Gates (final tree `5998504`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

The logs are in `scratchpad/p12t8-gate-*.log`.

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.` These are the standing "the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing". | 1 (standing, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.` These are the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. | 1 (standing, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+587: All tests passed!` | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 127 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

## Deviations

1. **`DocumentSession.differsFromSave`** is new, and the replace and exit flows read it rather than the `dirty` notifier. This is the defect above: the notifier lags the settle's synchronous commit by a microtask.
2. **Three existing tests were migrated**, because they replaced a *dirty* document and relied on Task 5's unconditional replace, which D10 now puts behind the dialog. Each now answers Don't Save through the new rig helpers. No assertion was removed.
   - **DH2**: the edit, then New.
   - **DH4**: the edited launch, then Open.
   - **DO6**: every failure, the picker throw and the cancel. It also gains "the dialog before the picker" (`openCalls` unchanged until Don't Save), which is exactly the spec's wording: "from a dirty document with history → Open → Don't Save → the picker returns".

   Without the migration these tests wait forever on the dialog. The count stays 569, and the full suite at that point was `+569: All tests passed!`.
3. **The exit flow is itself a `_flow`** (busy while it asks). That is what makes a second request cancel with no second dialog (S-17), and what disables the commands under the exit dialog. X5 pins it.
4. **The dialog is not barrier-dismissible**, and Escape is bound explicitly inside it, so only the three answers and Escape close it.
5. **`FloorPlannerApp` gains `exitGuard`**, a test seam passed to the host. The host owns and disposes whichever guard it gets.
6. **RN3 calls the flows directly**, because a swap under a held write is unreachable from the UI: every command is disabled while busy. It is the only way to exercise deviation 6's guard (R6), as the brief asks.
7. **The Swift edit is not built here** (no Xcode). It is the spec's snippet plus a comment; the human's look covers it.

## Found outside scope (reported, not fixed)

- **D11's engine quirk is not mitigated** (the plan says optional). A second Cmd+Q or close click while the exit dialog is up terminates at once. This stays in D14 and the human's look.
- **The dirty notifier's lag may matter elsewhere.** Anything else that reads `session.dirty` right after a synchronous commit sees a stale value until the next microtask. Today only the flows did (now fixed); the title and the guard catch up on the microtask. Task 9 may want a sentence in D5's amendment: "flows read the dispatcher, the UI the notifier".
- **Web `beforeunload`.** Current browsers show their own generic text, and ignore the `returnValue` string beyond its truthiness. This is for the human's web look.
