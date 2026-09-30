# Task 8 review — plan 12a (5998504)

**Verdict: Approved.** There are no Important findings. The minor findings and nits below are for Task 9 or for the record.

**Scope of the review**
- Worktree: the detached review worktree `plan-12a-review`, at HEAD `5998504`, parent `725ff74`.
- Read: CLAUDE.md; the plan (header, P-1 to P-6, Global constraints, Gates, Task 8, the mutant assignment); spec D2, D5, D10, D11, D12, D14 whole, with the Testing entries and the named mutants; `t8-brief.md`; `t8-report.md`.
- Every claim below was re-run or re-read by me. Logs are in `scratchpad/p12r8-*.log`.

## The incident: no mutant left behind

I read the full diff `725ff74..5998504 -- lib/document_host.dart` line by line.
- Every hunk is an intended change: the header comment, imports, `differsFromSave` with `_recompute` using it, the `DocumentHost` constructor and field, `SaveChoice`, `_exitListener` and `_exitGuard`, `_mayDiscard`, `_askToSave`, `_onExitRequested`, `_armExitGuard`, one `if (!await _mayDiscard()) return;` after the settle in each of `newFlow`, `openSampleFlow` and `openFlow`, `initState`, `dispose`, and `_SaveChangesDialog`.
- `_mayDiscard` reads `while (_session.differsFromSave)`. That is not the incident's `M-12a-10-all` form.
- The code the diff does not touch is still in its original form. My mutant driver asserts a match count of exactly 1 for each original text, and every one matched:
  - `_session.markSaved(encoded.stateId,`
  - `if (identical(_session.document, encoded.document)) {`
  - `if (busy.value) return body();`
  - `_fileName = fileName;\n    _location = location;`
- The branch worktree `plan-12a` is at `5998504`, with no change under `apps/` or `packages/*/lib` (`git status`: only `packages/jet_cad/analysis_options.yaml`).
- After my own mutant run, `lib/document_host.dart` in the review worktree is byte-identical to a reference copy taken before the run (`diff` exit 0), and every per-mutant `.bak` diff also exited 0.

## Conformance (plan Task 8, spec D10, D11, D12)

**D10, the replace dialog**
- The dialog has the keys `replace-save`, `replace-discard` and `replace-cancel`.
- Save is the default: a `FilledButton` with `autofocus`, so Enter saves (RP4). Escape is Cancel, through an explicit `CallbackShortcuts` (RP1, EX2).
- It runs after the settle, in front of New, Open sample and Open. For Open it comes before the picker (RP6, and DO6's new `openCalls` premise).
- Save runs `saveStep` nested, so busy stays the outer flow's (RN1, RN2).
- A cancelled or failed save leaves everything as it was (RP3, EX2, EX3).
- A save that succeeded while an edit landed during the write asks again (RN2, EX4).
- A clean document is replaced without a dialog (RP5).

**D11, the exit request**
- The host owns the `AppLifecycleListener` and disposes it (EX7).
- The order is busy → cancel, then settle, then clean → exit, then the dialog (T-7). Busy is checked, not idle, so a shape part-way does not block the exit (U-7, EX6).
- Save exits only if the document is still clean, and otherwise asks again (EX4).
- `ExitGuard`:
  - `set armed(bool)` and `dispose`, injectable;
  - armed from the session's `dirty` notifier, which survives swaps, so the guard follows every document (EG1);
  - on the web, a `beforeunload` listener that calls `preventDefault()` and sets `returnValue`, and is removed when disarmed or disposed;
  - elsewhere, a no-op stub.

**Platform selection**
- The conditional export is `if (dart.library.js_interop)`, the same condition `document_files.dart` uses.
- On the VM it selects the stub. I checked this with a throwaway script: `js_interop: false io: true which: stub`.
- The release web build contains the web guard: `build/web/main.dart.js` holds `This plan has unsaved changes.` once and `beforeunload` twice.

**Greps (Ruling 11-2)**
- `package:web` appears only in `document_files_web.dart` and `exit_guard_web.dart`.
- `dart:io` appears only in `document_files_io.dart`.
- There is no `Future.delayed` in `lib/`.

**The commit**
- The message is the plan's and ends with both trailers.
- `analysis_options.yaml` is not in the commit.
- Nothing outside Task 8's files changed, apart from the `main.dart` seam (`exitGuard`, deviation 5) and the three migrated tests and the rig.

**Swift, reviewed by reading (it cannot be built here)**
- `@objc func windowShouldClose(_ sender: NSWindow) -> Bool { NSApp.terminate(nil); return false }` sits in `MainFlutterWindow`, with a comment that cites spec 12a D11 (R-4, T-13).
- This matches the spec's snippet exactly. `@objc` is required, because the class does not adopt `NSWindowDelegate` and Swift methods on an `NSObject` subclass are not implicitly `@objc`.
- The selector maps to `windowShouldClose:`.
- AppKit consults the window itself only when the window has no delegate that implements the method. In `MainMenu.xib` the window (`QvC-M9-y7g`, `customClass="MainFlutterWindow"`) has no `delegate` outlet; the only `delegate` outlet (line 11) is the `NSApplication`'s, pointing to `AppDelegate`.
- `AppDelegate` keeps `applicationShouldTerminateAfterLastWindowClosed` true, as D11 reasons.
- A side effect worth one line in the human's look: Cmd+W, the menu's Close, also routes through `performClose:` and so asks to quit the app. That is consistent with terminating after the last window closes.
- The macOS behaviour itself is the human's look.

## The `differsFromSave` fix

**The defect is real.**
- The settle commits synchronously, but `dirty` is recomputed from `commands.changes`, an async stream, one microtask later.
- X1 (`while (_session.dirty.value)`) is red at RP7 `:423` and EX5 `:301` (N7 below). So without the fix, New, Open, Open sample and the exit would have dropped a just-committed panel value without asking.

**Is `dirty` read anywhere it could be stale?** I grepped every read of `dirty`, `differsFromSave` and `savedState` in `lib/`:
- The decision reads are only `_mayDiscard`, which is used by the three replace flows and the exit. All four go through `differsFromSave`.
- The loop re-reads the dispatcher after the nested save, so an edit made during a held write is seen.
- The notifier's other readers are presentation only:
  - the tab title (`main.dart:84-88`);
  - the top bar's `•` and "Edited" (`main.dart:637-645`);
  - the exit guard (`document_host.dart:341`).

  A one-microtask lag is harmless for all three. In particular, `beforeunload` is dispatched from the event loop, never inside the same synchronous block as a settle.
- `replace` and `markSaved` recompute `dirty` synchronously, so no swap or save leaves it stale.
- No stale read remains.

Task 9's D5 amendment should say that flows read the dispatcher and the UI reads the notifier, as the implementer proposes.

## The three migrated tests (deviation 2): not weakened

I read the full diff of `document_host_test.dart` and `document_open_test.dart`.
- **DH2 and DH4:** `await host.<flow>(); await tester.pump();` becomes `discardAndRun(tester, host.<flow>())`. That answers Don't Save, asserts that no dialog is left, awaits the flow and pumps. Every assertion that follows is unchanged.
- **DO6:** the extra `pump()` becomes `expect(files.openCalls, calls)` ("the dialog first") followed by `answerReplace(…, 'replace-discard')`. This is stronger: it pins D10's dialog-before-picker for every failure case. The picker-throw case and the cancel case are migrated the same way, and every "same document, depth, dirty, busy cleared" assertion is kept.
- The count is unchanged, as 569 + 18 = 587 shows.

## The seven deviations

| # | Deviation | Ruling |
|---|---|---|
| 1 | `differsFromSave` | Accept. It fixes a real defect and is pinned by X1 (N7). |
| 2 | The three migrations | Accept. Not weakened (see above). |
| 3 | The exit is itself a `_flow` | Accept. S-17's "no second dialog" and D6's outermost busy both need it. Pinned by X5 and by N4 at EX4 `:266`. |
| 4 | The dialog is not barrier-dismissible | Accept. **Unpinned but equivalent:** Y9, `barrierDismissible: true`, survives, because a barrier dismiss pops `null` and `_askToSave` reads `null` as Cancel. The outcome is the same either way (nit n-1). |
| 5 | `FloorPlannerApp.exitGuard` seam | Accept. The host owns it and disposes it (X9). |
| 6 | RN3 calls the flows directly | Accept. The UI cannot reach a swap under a held write, because every command is disabled while busy. It is the only way to reach R6, and R6 is red there (N6). |
| 7 | The Swift edit is not built | Accept. It was read (above); the human's look covers it. |

## Test quality (testing bar)

**Fixtures are not degenerate**
- Every fixture is dirty with history from the real Wall tool, far off the origin: (-39876.25, 33456.5) in the replace tests and (44321.75, -36543.25) in the exit tests.
- The camera is rotated at 0.1 px/mm, and the shape is ended.
- Titled fixtures carry a real name and location, so `(name, fileName, location)` and the title are asserted against non-default values.
- The failing-dialog helpers (`noDialog`, `requestExit`'s dialog count) make a mutant fail fast instead of hanging. That held on every red mutant in my run.

**Coverage of the spec's list**
The spec's Testing entries for replace flows, nested flows, exit and web specifics each map to a test:

| Spec entry | Test |
|---|---|
| dirty and New → dialog; Cancel | RP1 |
| Don't Save | RP2 |
| Save with the panel cancelled | RP3 |
| Save succeeds | RP4 |
| clean → no dialog | RP5 |
| Open → dialog before the picker | RP6 |
| nested flows | RN1, RN2 |
| clean → exit | EX1 |
| save then exit | EX1 |
| dirty → Cancel, Don't Save, Save ok, Save fails | EX2 |
| busy → cancel | EX4 |
| a panel value typed → the dialog | EX5 |
| the guard across a swap | EG1 |

The brief's additions are present: n-2 is RP2, with R3 red there; m-3 is RN3, with R6 red there; the controller's relayed case is RP7.

## Mutants I fired

**Procedure**
- Driven by `scratchpad/p12r8-mutants.py`.
- For each mutant: `cp` to `p12r8-<id>-document_host.dart.bak`, an exact replace with the count asserted as 1, `CI=true flutter test` on the named files, `cp` back.
- After each: `diff` against the `.bak` exited 0, and `diff` against the pre-run reference exited 0.
- Summary: `p12r8-mutants-run.log`. The lines were extracted by `p12r8-summ.py` from the per-mutant logs.
- Files: R is `test/document_replace_test.dart`, E is `test/document_exit_test.dart`. Lines are the failing expectation's line; `rig:114` is `answerReplace`'s "the dialog is up" premise, and `rig:124` is `noDialog`.

**The named mutants and the report's key mutants**

| Id | Mutation | Result: red tests and lines |
|---|---|---|
| N1 **M-12a-2 (exit)** | `markSaved(_session.savedState, …)` in `_write` | −8 of 8. **EX1 `E:64` from the body `E:92`**: the exit after a Save As asked. The others fail at `titledClean`'s clean premise `E:41`, EX3 at `rig:124`, EG1 at `E:374`. Matches the report. |
| N2 **M-12a-10** | `while (false && differsFromSave)` | −15 of 18: RP1 `R:124`, RP2 `rig:114`, RP3 `rig:114`, RP4 `R:260`, RP6 `R:355`, RP7 `R:423`, RN1, RN2 and RN3 at `rig:114`, EX2 `E:129`, EX3 `rig:114`, EX4 `E:231`, EX5 `E:301`, EX6 `E:335`, EG1 `rig:114`. Matches the report. |
| N3 **M-12a-25** | `if (!differsFromSave) return exit;` before the settle | EX5 `E:301`. Matches. |
| N4 **M-12a-26** | a nested `_flow` clears busy in a `finally` | RN2 `R:521`, RN3 `R:561`, EX4 `E:266`. Matches. |
| N5 **R3** (n-2) | `fileName ?? _fileName`, `location ?? _location` in `replace` | **RP2 `R:169`**, RP4 `R:272`, RN1 `R:485`, RN3 `R:552`. Matches. |
| N6 **R6** (m-3) | the `identical(document, encoded.document)` guard becomes `if (true)` | **RN3 `R:567`**: expected `(Untitled, null, null)`, actual `(plan, plan.jetplan, /p/plan)`. Matches. |
| N7 X1 (the defect) | `while (_session.dirty.value)` | RP7 `R:423`, EX5 `E:301`. Matches. |

**My own mutants, at seams the report's list does not name**

| Id | Mutation | Result |
|---|---|---|
| Y1 | Escape pops **Don't Save** instead of Cancel | Red: RP1 `R:84` (`expectKept` from `R:142`), EX2 `E:144`. So Escape is pinned as *Cancel*, not merely as "closes the dialog". |
| Y2 | busy → **exit** (not cancel) | Red: EX4 `E:232` |
| Y3 | Save's result ignored (`await saveStep();`, loop on) | Red: RP3 `rig:124`, EX2 `rig:124`, EX3 `rig:124` |
| Y4 | Open settles **after** the ask (the order in `openFlow` swapped) | Red: RP7 `R:423`, at the Open iteration ("Open: the settle made it dirty") |
| Y5 | the exit's settle after `_mayDiscard`'s synchronous check, inside the flow | Red: EX5 `E:301` |
| Y6 | the guard is not armed in `initState` | Red: EG1 `E:361` |
| Y7 | the dialog names `fileName` rather than `name` | Red: RP1 `R:125` |
| Y8 | the host does not remove its `dirty` listener on dispose | **Survives** (+8). Equivalent in the app: the session and the host are disposed together (nit n-2). |
| Y9 | `barrierDismissible: true` | **Survives** (+18). Equivalent: `null` is Cancel (deviation 4, nit n-1). |

I did not re-fire the report's per-flow M-12a-10 variants, S-new, S-sample, S-open or X2 to X13. N2, Y4 and the overlaps above cover the same seams.

## Probes (temporary test file, run, then deleted)

`test/zz_p12r8_probe_test.dart` was written in the review worktree, run, and removed. `git status` afterwards shows only `analysis_options.yaml`.
- **P1.** With the **D10** dialog up (dirty, titled), each of Cmd and Ctrl with S, O, N and Shift+S is handled. There is no write and no open call, and still exactly one dialog. Cancel then keeps the document. **Green.**
- **P2.** An edit lands during the held nested Save, and the dialog is asked again. A second Save, not held, writes the bytes **with** the edit to `/p/a`, then the document is replaced: clean, not busy, Untitled. **Green.**

The transcript was `00:04 +2: All tests passed!`.

## Findings

### Important

None.

### Minor

- **m-1 (Task 9).** The spec's "Above the dialogs" test names the **D10 dialog** (T-3: "with the D10 dialog up … Cmd+S is handled and makes no write").
  - DC9 still uses the error dialog as the stand-in, because D10 did not exist in Task 6. No landed test presses a file chord under the replace dialog.
  - Probe P1 shows that the behaviour holds.
  - Suggestion: add P1's first half as a case of DC9 or of RP1, and re-fire M-12a-24 against it in Task 9's sweep. Cost: a few lines.
- **m-2 (Task 9, spec wording).** D11's busy list says "a dialog or a panel up".
  - The page panel's sheet or units dropdown is a route but not busy. An exit request with the dropdown open exits if the document is clean, and otherwise shows the dialog above the menu.
  - That is harmless, and nothing is lost. D11's amendment should say that "a panel" means the native open and save panels, which are inside a flow.

### Nits

- **n-1.** Deviation 4 is unpinned. Y9 survives, and is equivalent in outcome. Either record it as equivalent in the results note, or drop the claim that only the three answers and Escape close the dialog.
- **n-2.** Y8 is equivalent today, because the host and the session share a lifetime. If the session ever outlives the host, the missing `removeListener` would make `FakeExitGuard` throw ("armed after dispose"). The code is right; this is only a note that nothing pins it.
- **n-3.** The web guard's runtime behaviour is covered only by the build and by reading. I read it:
  - `_listener` is one `late final JSFunction`, so `removeEventListener` gets the identical function;
  - the setter is idempotent;
  - `dispose` disarms.

  It is correct. Browsers show their own text, which is for the human's web look, as the report says.
- **n-4.** DO6's description still ends "a cancel shows nothing". The replace dialog now shows first, and only the error dialog is absent. This is wording only.
- **n-5.** `DocumentHostState` reads `widget.exitGuard` once, in `initState`. A rebuilt `FloorPlannerApp` with a different guard is ignored. This is a test seam only, and no caller does it.

## Gates (review worktree at `5998504`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.` These are the standing `generate_document_test` two: "the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing". | 1 (standing, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.` These are the standing `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. | 1 (standing, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+587: All tests passed!` (569 + 18 new) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 127 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web`; the web guard is in `main.dart.js` | 0 |

The tree is left with no tracked change except the known `packages/jet_cad/analysis_options.yaml` rewrite from `pub get`. `build/` is git-ignored.
