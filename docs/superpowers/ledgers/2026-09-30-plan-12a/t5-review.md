# Task 5 review — plan 12a (efb8700)

**Verdict: Needs fixes.** There is one Important finding, I-1: a test gap on a path that can lose data. The code itself conforms to the spec. The fix is one test of about 15 lines, and it is written below.

The review worktree was `.claude/worktrees/plan-12a-review`, detached at `efb87009fd47e5f68a69ca2dc7b795c6c9edf9bc`. I read:
- `CLAUDE.md`
- the plan: header, P-2 to P-6, Global constraints, Gates, File structure, Task 5 and the mutant table
- the spec: D1, D2, D5, D8, D9 and D13 in full, plus D4, D6, D14, Testing, Named mutants and Revisions 2 to 4
- `t5-brief.md`, `t5-report.md`, `t3-review.md` (m1), `t4-review.md` (n-1, n-2), and the ledger's rulings

The report's claims were not taken as evidence. Each one was re-run or re-read.

## Scope

The commit touches exactly the plan's files for Task 5, and nothing outside `apps/floor_planner`:
- `lib/document_host.dart` (new)
- `lib/main.dart`
- `lib/startup_plan.dart` (a comment only)
- `test/planner_shell_test.dart` (migrated)
- `test/document_{host,open,save}_test.dart` and `test/support/document_rig.dart` (new)

`analysis_options.yaml` is not in the commit. The only omission is `fileCommands`/`ShellCommand`, which is deviation 1 and is accepted below.

## Spec conformance (D2, D5, D8, D13), checked in the code

**Session and title (P-3, U-4)**
- `DocumentSession` holds the document, the measurer, the file name and display name, the location, `savedState`, and the `dirty` and `busy` notifiers.
- `FloorPlannerApp` is stateful. It owns the session and the files, and rebuilds `MaterialApp(onGenerateTitle:)` from `ListenableBuilder(Listenable.merge([session, session.dirty]))`, with `home: DocumentHost`.

**The keyed swap (D2, S-11, S-24, S-28)**
- The host builds `PlannerShell(key: ObjectKey(session.document), …)`.
- `replace` does, in order:
  1. cancels the old subscription and listens to the new document (S-23);
  2. resets the file name, the location and the save point;
  3. calls `_recompute()`, then `notifyListeners()` once;
  4. registers a post-frame callback that runs `oldDocument.dispose()` and then `oldMeasurer.clear()`, and calls `ensureVisualUpdate()`.
- The disposal timing is correct:
  - The keyed element swap runs the new shell's `initState` during build. The old state is unmounted in `finalizeTree`, which runs before the post-frame callbacks.
  - So the old shell's `dispose` releases the expander, `onAfterMutate`/`onBeforeMutate` and the table listeners over a live dispatcher. After that the host disposes the dispatcher and clears the measurer.
  - Probe P5 confirms this at HEAD. Right after `newFlow()` returns, the old document is **not** disposed. After one `pump()`, it is.
- `CommandDispatcher.dispose` only closes the stream (`undo.dart:279`) and does not null the hooks. So DH5's null checks prove that the old shell released them; they are not produced by the dispose itself.

**The measurer**
- There is one measurer per document, and it is cleared exactly once:
  - after the swap, post-frame;
  - at once when a decode fails (`document_host.dart:254`);
  - by the session when the app is disposed.
- The shell creates and clears a measurer only for the document it builds itself when bare (deviation 4).

**The settle registrar**
- The shell registers its settle in `initState` and calls the returned release in `dispose`.
- The release clears the slot only if the slot still holds its own callback: `identical(_settle, settle)`. Both sides hold the same tear-off object, so this is correct under the keyed swap, where the new shell's `initState` runs before the old shell's `dispose`.
- It is a no-op until Task 7 and is not mutant-testable yet (R11).

**The busy span (D6, S-21, T-8)**
- `_flow` sets `busy` synchronously, before its first await, when no flow is running. It clears `busy` in a `finally`.
- A nested call runs its body without touching `busy`.
- The error dialogs are awaited, so `busy` covers them. DO6:352 and DS2:103 assert this, and R13 goes red on them.

**Open (D8)**
- The flow picks the file, calls `utf8.decode`, then `decodeString(measurer: fresh, registerComponents: registerAppComponents, diagnostics: [])`.
- It catches any object with `catch (e)`, not `on Exception`.
- On failure the dialog reads `Could not open <file>` over `e.toString()`. Nothing else changes.
- It does not add a DASHED record (R-3).
- On success it swaps, named after the file, at the returned location.

**Save and Save As (D5, D9, D13, S-2)**
- `_encode()` reads the document, the `stateId` and `utf8.encode(encodeToString(doc))` in one synchronous block, after the settle hook.
- Success calls `markSaved(capturedId)`, which recomputes `dirty` at once (T-13).
- Failure and cancel leave the save point where it was.
- The destination follows D9:
  - an untitled document runs Save As;
  - a titled document with `writesInPlace` writes to its location;
  - on web, a titled document downloads without asking.

**Task 3 review m1: confirmed.** The bare shell's fallback is now `widget.document ?? newDocument(_ownMeasurer = FlutterTextMeasurer())`, at `main.dart:150`. It is no longer `startupPlan`. `main.dart` imports only `kMaxScale` and `kMinScale` from `startup_plan.dart`.
- My mutant X5 restores `startupPlan`. It goes red at `planner_shell_test.dart:99`, the new empty-launch case.
- The stale comment at `startup_plan.dart:26-28` is corrected.

**Task 4 review n-1: confirmed.** A titled Save on web writes to `location ?? fileName` under `fileName`. Two tests pin it:
- DS5 (location null, write location `flat.jetplan`, no prompt);
- DS1 with `writesInPlace: false`.

**Task 4 review n-2: confirmed.**
- `main.dart:7` imports `document_files.dart`, and `main.dart:52` calls `createDocumentFiles(askName: _askName)`.
- Probe W1: I passed `bytes` to `revokeObjectURL` in `document_files_web.dart:74`. `CI=true flutter build web --release` then exited 1 with `Error: The argument type 'Uint8List' can't be assigned to the parameter type 'String'`. The file was restored (`diff` exit 0) and the build rebuilt `✓ Built build/web`. The web build therefore compiles `_web`.

**The web name prompt**
- `_askName` shows the prompt through the navigator key's context.
- Probe P1: `showDocumentNamePrompt(navigatorState.context, …)` inside the pumped app shows the prompt and returns the typed name. The navigator's own context is a valid context for the dialog.

## Tests and the testing bar

The fixtures are not degenerate:
- **Edits:** every edit goes through the real Wall tool, far from the origin at (41234.5, 27345.25) or (-38765.5, 29345.75), under a rotated camera at 0.1 px/mm, with the shape ended. `drawWall` asserts that Select is active afterwards.
- **"Did not change" tests:** DO6 and DS2 start dirty with `undoDepth` 1, as the spec's preamble requires (S-13).
- **DO2** rotates a group through the rotation grip with a mouse drag, with the premise |angle| > 0.05, and compares the transform entries exactly.
- **DO6's `scale.jetplan`** asserts that exactly one field was zeroed.

**The migration of `planner_shell_test` did not weaken any test.**
- The diff replaces `const FloorPlannerApp()` with `pumpSample(tester)` in the 12 cases. Every assertion is unchanged, and one new case is added.
- The only side difference is the `MaterialApp` theme: the default instead of `colorSchemeSeed`. No assertion in the file reads a theme or a colour (grep).
- No other test file changed. No other test pumps `FloorPlannerApp` or a bare `PlannerShell()` (grep).
- The app path is now exercised by the 18 `document_*` tests.
- App count: 526 → **545**, which is 19 new tests and none removed.

## Mutants

Procedure: for each mutant, `cp` the file to `scratchpad/p12r5-<id>-<file>.bak`, apply an exact replace with its count asserted as 1, run `CI=true flutter test <files>`, `cp` the backup back, and `diff`. All **33 restores in the scripted run and 5 in the probe runs exited 0**.

The runner is `scratchpad/p12r5-mutants.py`, with logs `p12r5-<id>.log` and the summary `p12r5-mutants-run.log`. I wrote the mutations myself; they are not the implementer's script. Line numbers are the failing expectation's line in the named file.

### The task's named mutants, re-fired: all red

| Mutant | Mutation | Red (test : line) |
|---|---|---|
| M-12a-1 | the save encodes a key-sorted map | DO1 `document_open_test:124`; also DO2 :204, DO3 :257 |
| M-12a-2 (save) | `markSaved(_session.savedState, …)` | DH3 `document_host_test:64`; DS1 ×2 :78, DS2 :116, DS4 :177, DS5 :215 |
| M-12a-3 failure | `markSaved(encoded.stateId)` in the write's `catch` | DS2 `document_save_test:106` |
| M-12a-3 cancel | `markSaved(encoded.stateId)` when the place is null | DS3 `document_save_test:137` |
| M-12a-4 | dirty is sticky (`dirty.value \|\| …`) | DH3 :48; DH2 :141; DH4 :37 |
| M-12a-7 | decode registers only `parametricCatalog.registerComponents` | DO4 `document_open_test:275` (DO6 :340 too) |
| M-12a-7b | decode registers only `PageComponent.register` | DO5 :294 (DO1 :136, DO2 :213, DO3 :252 too) |
| M-12a-8 | Open swaps to `newDocument` before decoding | DO6 :357 |
| M-12a-13 | the save point is read after the write (`_session.document.commands.stateId`) | DS1 ×2 `document_save_test:74` |
| M-12a-16 | `on Exception catch` in decode | DO6 :340: the `list.jetplan` `_TypeError` escapes (`json_codec.dart:161`) and no dialog shows |
| M-12a-17 | busy cleared only when the result is not `false` (no `finally`) | DS2 :107; DS3 :139 |
| M-12a-18 | `ensureDashedLinetype(document)` after decode | DO3 :253 |
| M-12a-19 | `replace` keeps the first subscription | DH4 `document_host_test:44` |
| M-12a-20 | the shell disposes the snap unconditionally | DH5 :208; DH1 to DH4 fail at teardown (double dispose) |
| M-12a-21 | the old document is not disposed | DH5 :203 |
| X5 (Task 3 m1) | the bare shell falls back to `startupPlan` | `planner_shell_test:99` |

Every named mutant reproduces the red test and line the report claims.

### My own, at seams the named ones miss

| # | Mutation | Result |
|---|---|---|
| R2 | `replace` without `_recompute()` | RED DH2 :141, DH4 :37 |
| **R3** | `replace` keeps the file name and location when the new document has none (`fileName ?? _fileName`) | **survives**, all 31 tests in the four files. See **I-1** |
| R4 | the shell is not keyed by the document | RED DH2 :134, DH4 :43, DH5 :216 |
| R5 | titled, `writesInPlace`, location null → writes to the file name | survives: unreachable. See m-3 |
| R6 | no `identical(document, encoded.document)` guard before `markSaved` | survives: unreachable in Task 5. See m-3 |
| R7 | a successful Save As does not rename | RED DS3 :150, DS4 :175 |
| R8 | the suggested name is built from `fileName` (`house.jetplan.jetplan`) | RED DS3 :150, DS4 :190 |
| R9 | the app's builder listens to the session only, not to `dirty` (a form of M-12a-31) | RED DH3 :45, DS1 :76 |
| R10 | a `saveLocation` throw is not caught | survives the suite. See m-2 |
| R11 | the settle release clears unconditionally | survives: no-op until Task 7 (reported by the implementer) |
| R12 | Open drops the file's location | RED DH4 :184 |
| R13 | `_flow` never sets busy | RED DS1 :63, DS2 :103, DO6 :352 |
| R14 | `replace` does not notify | RED DH2 :149, DH5 :216 |
| R15 | the error dialog does not name the file | RED DO6 :342 |
| R16 | the shell ignores the passed snap | RED DH5 :234 |
| R17 | the title drops the `•` | RED DH3 :45 |
| R18 | `markSaved` notifies only when the file name changes, not the location | survives: equivalent for anything observable (the title shows the name only) |
| **R1** | the old document disposed synchronously in `replace`, not post-frame | **survives** the suite. See m-1 |

### Probes

The probe file was temporary, `test/p12r5_probe_test.dart`. It was deleted after use, and a copy is at `scratchpad/p12r5_probe_test.final.dart`.

| Probe | What it does | Result |
|---|---|---|
| P1 | the name prompt from the navigator's own context | green |
| P2 | `startupPage(finished sample.extents)` against the sample's page | **not equal**: origin (11575.0, 7250.0) against (11748.48…, 6976.52…). This confirms deviation 8 |
| P3 | the I-1 test | green at HEAD; **red under R3** at `:56`: `Expected (Untitled, null, null)`, `Actual (flat, flat.jetplan, /p/f)` |
| P4 | a Save As whose panel throws | green at HEAD (dialog `Bad state: panel`, false, not busy); **red under R10** (a `StateError` escapes, no dialog) |
| P5 | the old document is not disposed right after `newFlow()`, and is disposed after one pump | green at HEAD; **red under R1** at `:90` (`Expected: false, Actual: true`) |

## Findings

### Important

**I-1. Nothing tests that New or Open sample from a *titled* document drops the name and the location (R3 survives).**
- D2 and S-28 say a replacement resets "the save point, the name and the location", and the plan's checklist repeats it for `replace`.
- Every New and Open-sample fixture starts from an untitled document: DH2 is launch → New → Open sample, and DO1 and DH5 start from launch. `fileName ?? _fileName` is therefore indistinguishable from the correct code.
- The consequence, reasoned from the code and not run: under R3, Open `plan.jetplan` → New → Cmd+S would take `saveStep`'s titled branch. It would write the **empty document in place over `plan.jetplan` without asking**, and name it `plan`. That is silent data loss on the most ordinary sequence there is.
- **Fix:** add probe P3 as a test in `document_host_test.dart`. It opens a titled file with a location, runs `newFlow`, and expects `(Untitled, null, null)` and the title `Untitled — jet-cad`. It then opens again, runs `openSampleFlow`, and expects the same. R3 goes red at the first expect.
- This costs one test. It fits the precedent of Task 1's I-1, a test gap ruled into a follow-up task, if the controller prefers to route it that way.

### Minor

**m-1. The post-frame disposal timing is not pinned (R1 survives).**
- Disposing the old document synchronously inside `replace` passes every test. Nothing in the old shell's teardown calls a checked dispatcher method, so the order is invisible to the suite.
- The spec's ordering exists so that the old shell, which is still mounted until the frame, never meets a disposed dispatcher. Examples are a stale event between the `replace` and the frame, or a future teardown that executes a command.
- P5 kills R1 in 3 lines: not disposed right after `newFlow()`, disposed after `pump()`. I suggest folding it into I-1's test.

**m-2. Deviation 5's save half is untested (R10 survives).**
- The report says a throw from `saveLocation()` is caught and shown. The only picker-throw test is DO6's `open()` throw.
- P4 (Save As with `scriptSaveLocationThrow(StateError('panel'))`: dialog, `false`, not busy) kills R10.
- This could go into Task 9's sweep.

**m-3. R5 and R6 are unreachable paths, recorded as equivalent today.**
- **R5:** a titled document with `writesInPlace` and no location cannot arise on macOS, because `open` always returns the path.
- **R6:** the identity guard, deviation 6, only matters if a swap lands during a held write. Task 6 prevents that by disabling commands while busy. Task 8's nested-flow tests (T-8) are where R6 becomes reachable, and they should re-fire it.

**m-4. DH5 has no premise that `onBeforeMutate` was set before the swap.**
- It asserts null afterwards, but asserts non-null only for `expander` and `onAfterMutate`, and `listeners > 0` before.
- `SpatialIndex` installs `onBeforeMutate` (`spatial_index.dart:170`), so the assertion is meaningful today. A one-line premise, `expect(old.commands.onBeforeMutate, isNotNull)`, would keep it so.

**m-5. R18 is equivalent. No action.**

## The nine deviations

1. **`fileCommands`/`ShellCommand` deferred to Task 6: accept.** Nothing would consume them yet, and the type is Task 6's file.
2. **`ShellSettleRegistrar` returns a release: accept.** The reasoning about the keyed swap is correct. The new state's `initState` runs during build, and the old state's `dispose` runs in `finalizeTree`. A `null` on dispose would erase the new registration. Task 7's tests should pin it (R11).
3. **`fileName` and the display name kept apart, and web Save writes to `location ?? fileName`: accept.** Pinned by DS4, DS5, R7 and R8.
4. **A bare shell owns the measurer of the document it builds: accept.** It is the only coherent option for `PlannerShell()`. `_ownMeasurer` is set only in the `late final` initialiser's fallback.
5. **Flows await their dialog, and picker throws are caught: accept.** Busy covering the dialog is what D11's exit check needs later. The save half is untested (m-2).
6. **`markSaved` skipped when the document changed during the write: accept.** It is correct, because ids are per dispatcher (S-28). It is unreachable today (m-3).
7. **The session disposes its document on app dispose: accept.** Flutter unmounts children before parents, so the shell's teardown runs over a live dispatcher first.
8. **`startupPage(...)` in D4/D8's wording does not hold literally: accept.** Probe P2 confirms it. The sample's page is computed before the dimensions extend the extents, and `startup_plan.dart:197`'s "which the rooms do not change" is about the rooms only. DO4 comparing against an independently built sample's page is the right assertion. Task 9 amends the spec, as the controller ruled.
9. **The window title becomes `<name> — jet-cad` on every platform: accept.** `onGenerateTitle` is the spec's mechanism, and only the web tab shows it.

## Gates

I ran these myself in the review worktree, with `CI=true`, `PATH=/root/flutter/bin:$PATH`, after `flutter pub get`, and with the probe file deleted.

| Package | Command | Result | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.` Only the standing `generate_document_test` pair ("the default document is the one Plan 2 measured, byte for byte", "both text fractions default to zero and change nothing") | 1 (standing) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.` Only `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | 1 (standing) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+545: All tests passed!` | 0 |
| app | `flutter analyze` | No issues found! (ran in 3.5s) | 0 |
| app | `dart format` | 117 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

The engine and render counts are unchanged from the brief. The app count is 526 + 19. The logs are `scratchpad/p12r5-gate-{engine,render,app}.log`.

At the end, `git status --short` shows only ` M packages/jet_cad/analysis_options.yaml`, the known rewrite by `pub get`. Every mutated file was restored with `diff` exit 0, and the probe test file is deleted.
