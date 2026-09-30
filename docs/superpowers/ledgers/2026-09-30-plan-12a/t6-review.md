# Task 6 review — plan 12a, `95bf923` `feat(app): the command table, toolbar and shortcuts`

Reviewer: independent, detached worktree `.claude/worktrees/plan-12a-review` at `95bf923`.
Read: CLAUDE.md; the plan (header, P-1…P-6, global constraints, gates, Task 6, mutant table);
the spec's D6 and D7 whole, plus Architecture/Invariants, the Testing preamble, the tests by area, the named mutants,
R-7…R-10 and Revisions 2–4; `t6-brief.md`; `t6-report.md`; the full diff; the whole of `document_commands_test.dart`.

## Verdict: **Approved**

The diff does Task 6's checklist and nothing else:
- `ShellCommand` and the table.
- Idle, meaning not busy and not mid-shape.
- Undo and Redo as settle → re-read → return (U-2).
- Meta and Ctrl on every chord, plus Ctrl+Y. A disabled binding stays and consumes the key.
- The consume-only binding above the Navigator, in `MaterialApp.builder`.
- The guard gains the three redo chords.
- The toolbar: `TextFieldTapRegion`, then `ExcludeFocus`, then 7 keyed buttons with ⌘/Ctrl tooltips and a group gap.
- The name, with `•` and the `Edited` tooltip while dirty, in a `Flexible` with ellipsis.
- The status line, `Flexible` with ellipsis.
- Undo and Redo only in a bare shell.
- The `_undo` binding and its "no redo in 02" comment are gone.

Every named mutant of Task 6 goes red where the report says. All gates are green, with standing failures only, and the web build succeeds. There are no Important findings. The four Minor findings below are one layout regression and three test gaps. None of them blocks the task.

## Gates (run by me on `95bf923`, CI=true, PATH=/root/flutter/bin)

| Package | Command | Result | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed`. Only the 2 standing `generate_document_test` failures ("the default document is the one Plan 2 measured…", "both text fractions…") | 1 (standing) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed`. Only the 7 standing failures: text ladder rungs 1–5 and text lod ladder rungs 1–2 | 1 (standing) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+561: All tests passed!` (545 + 16) | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format` | 120 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

Logs: `scratchpad/p12r6-engine.log`, `p12r6-render.log`, `p12r6-web.log`.

After everything, `git status` in the review worktree shows only ` M packages/jet_cad/analysis_options.yaml`, the known pub-get rewrite. That includes a scratch measurement test, which I deleted.

## Mutants fired by me

Procedure: my own runner, `scratchpad/p12r6-mutants.py`.
1. `cp` a backup to `scratchpad/p12r6-<tag>-<file>`.
2. Replace text, asserting exactly one match.
3. Run `CI=true flutter test`.
4. `cp` the backup back, then `diff`. **Every diff exited 0.**

Line numbers are the first failing line in `test/document_commands_test.dart` unless another file is named.

### The named mutants (all red, matching the report)

| Mutant | My mutation | Red |
|---|---|---|
| M-12a-9 | The Undo chord is bound to `c.run()`, skipping `invoke` | DC7 : 549 |
| M-12a-12 | `_flow` never sets `busy.value = true` | DC7 : 528, DC9 : 629 |
| M-12a-15a | The guard lacks Meta+Shift+Z | DC8 : 592 |
| M-12a-15b | The guard lacks Ctrl+Shift+Z | DC8 : 592 |
| M-12a-15c | The guard lacks Ctrl+Y | DC8 : 592 |
| M-12a-23 | `_idle` ignores `isMidShape` | DC5 : 402, DC6 : 475 |
| M-12a-24 | The above-Navigator binding is empty | DC9 : 631 |
| M-12a-29 | Redo does not re-read `canRedo` after the settle | DC10 : 716 (spy calls 2, not 1) |
| M-12a-30 | The above-Navigator binding invokes the host's matching command, through a `GlobalKey<DocumentHostState>` | DC9 : 672 (a write lands with the dropdown up) |
| M-12a-31 | The app's `ListenableBuilder` listens to `Listenable.merge([])` | DC11 : 766; also DH3 and DH4 in `document_host_test` (title assertions) |

M-12a-29 is observable only through the `onBeforeMutate` spy, because `CommandDispatcher.redo()` itself refuses when `!canRedo`. The implementer's note 1 is correct. The spy measures exactly the spec invariant "the UI never relies on the dispatcher refusing".

### My own mutants at other seams

| Mutant | Result |
|---|---|
| R3: the history listener updates Undo's flag only, not Redo's | red: DC1 : 208, DC2 : 262, DC3 : 304, DC5 : 394, DC10 : 698 |
| R4: the shell binds only the edit commands' chords, not the file chords | red: DC4 : 330, DC7 : 526, DC9 : 627, DC11 : 773 |
| R5: no `Edited` tooltip on the dirty name | red: DC11 : 768 |
| R8: the tooltip names the **last** chord, not the first | red: DC1b ×3 : 239 (Redo would read Ctrl+Y / ⌘Y) |
| R1: the guard also guards the file chords, so Cmd+S in a panel field would not save | **survives the whole app suite** (`+561`), see m2 |
| R6: the shell does not dispose its five file-command `DerivedFlag`s | **survives** DC + DH (`+21`), see m3 |
| R7: the shell's file flag drops the host's `enabled` (`() => _idle`) | survives; equivalent, see m4 |
| R10: the host's `_notBusy` is always true | survives; equivalent, see m4 |
| R9: Undo does not re-read `canUndo` after the settle | survives; equivalent, as the report says (a settle only adds history, so `canUndo` cannot turn false) |
| R2: `ExcludeFocus(excluding: false)` | survives; the report says so too (an `IconButton` tap does not take focus; only Tab traversal would show it) |

## Findings

### Important

None.

### Minor

**m1. The status line is now capped at one third of the free width, even when the bar has room.**
- **What:** the top-bar Row holds the name (`Flexible`), the status line (`Flexible`) and a `Spacer`: three flex-1 children. A loose `Flexible` gets at most its 1/3 share of the free space, and space the name leaves unused is not given back to the status line.
- **Evidence:** a scratch widget test (deleted) at **1440 × 900** with the sample open ran the Room tool over each room seed. Every status came out with:
  - `maxWidth = 282.67`
  - `didExceedMaxLines = true`
  - the status starting at x = 450, and OSNAP starting at x = 1015, so about 280 px stays empty to the right of the cut status.

  This is in the test font (Ahem, 14 px per glyph). Before this commit the status line had no width limit.
- **Real fonts:** at about 7 px per glyph the cap is about 40 characters. "Room — Already a room: <long name>" is cut in the target window size while space sits unused.
- **Test coverage:** DC12 pins only the 800 px case, which is correct there.
- **Suggested fix:** give the status line the leftover space. For example, drop the `Spacer` and make the status `Expanded`, keeping the name `Flexible`, or give the status a larger flex. Then re-check DC12.
- **Scope:** D7 literally says "Flexible" plus Spacer, so this is a layout consequence, not a spec violation. It could be fixed in Task 7 or Task 9, or recorded for the human's look.

**m2. Nothing pins "the file chords are not guarded" (D6: "Cmd+S in a panel field saves").**
- **Evidence:** mutant R1 (the guard lists `kFileChords` too) passes all 561 app tests.
- **Where it gets pinned:** Task 7's pending-input test, "thickness typed without Enter, Cmd+S → bytes carry it", presses Cmd+S with the panel field focused and should catch R1.
- **Action:** the Task 7 brief and reviewer should fire R1 against that test. If Task 7's test gets its focus some other way, a Task 6-style case is needed: a field focused, Cmd+S, then one write.

**m3. The shell's disposal of its file-command flags is unpinned, and a regression there would leak every old document.**
- **Why it matters:**
  - Each of the shell's five `DerivedFlag`s listens to the host's `_notBusy` and to `session.busy`, both of which outlive the shell.
  - Their `compute` closure captures the shell `State`, and through it the old document, its tools and its index.
  - The code disposes them correctly. But mutant R6 (no disposal) passes DC and DH. With R6, every swap would leak the whole previous document into the host's listener lists for the app's lifetime, and nothing would fail. It fails silently, because the old flag is never disposed, so no "used after dispose" assertion fires.
- **Suggested check:** add a swap-hygiene assertion in the style of Task 5's (S-11). For example, after an Open, count the listeners on `session.busy`, or on the host's flag, through a debug counter or `hasListeners` in a test. Could go in Task 9's sweep.

**m4. Busy gates the file commands twice.**
- **How:** the host's `enabled` (`_notBusy`) and the shell's `_idle` (which reads `_busy`) both do it.
- **Evidence:** R7 and R10 each survive, because the other half still gates. Neither is a defect.
- **The trade-off:**
  - Keeping the host's half makes `DocumentHostState.fileCommands` safe to use on its own, for example by the later menu bar. That is a reasonable reading of deviation 3.
  - But `fileCommands` on the host is **not** mid-shape-aware. A later consumer that binds the host's list directly, rather than the shell's re-wrapped list, would act mid-shape (R-8).
- **Suggested fix:** one line of dartdoc on `fileCommands`: "enabled is only not-busy; the shell adds mid-shape".

**m5 (note, no action required). P-6 says pointer-path toolbar tests run on macOS with a mouse.**
- DC1, DC2, DC3, DC5, DC7 and DC10 tap the buttons with `flutter_test`'s default Android touch.
- None of these taps interacts with a focused field or an open text entry, which is the reason for T-1 and U-8. So the result does not depend on it.
- Task 7's toolbar tests (T-1, M-12a-22) must follow P-6.

**m6 (note). DC9(a) starts from the clean launch document at depth 0.**
- It asserts "nothing happened", which the S-13 preamble forbids for history assertions.
- Its assertions are on file calls (open, save-location, write) and on the document's identity, all of which a stray New, Open or Save would change even from clean. So the fixture is not degenerate for what it measures.
- DC9(b) and DC7 use the prescribed dirty, titled fixture with history.

## The six deviations (and 7–9)

1. **`List<SingleActivator>` rather than `List<ShortcutActivator>`.** Accepted. The tooltip needs `trigger` and `shift`, and every chord is a `SingleActivator`. `SingleActivator` is also a `MenuSerializableShortcut`, which suits the later menu bar.
2. **`tooltip` as a getter over `defaultTargetPlatform`.** Accepted. It is read at build, and DC1b pins all three platforms.
3. **Idle split between host (busy) and shell (mid-shape), with `withEnabled` in the shell.** Accepted.
   - One definition per command still holds: id, label, icon, chords and run live once.
   - The toolbar and the chords both use the same wrapped list, so they cannot disagree. R4 and X14 prove the wrapped list is what is bound and shown.
   - See m4 for the dartdoc caveat.
4. **`PlannerShell.debugOnSettle`.** Accepted as a `@visibleForTesting` seam. It is inert without a callback, and it is the only way to pin U-2 before Task 7 exists. Task 7 should decide whether to keep it or to re-express DC10 and DC10b with a real typed value. Either way, M-12a-29 must stay red.
5. **`DerivedFlag`.** Accepted and sound:
   - `value` is live.
   - It notifies only on a change, which keeps the per-hover `ToolController` notifications from rebuilding the toolbar.
   - Sources are removed on dispose.
   - The Undo and Redo flags are updated from the async broadcast `changes` stream (`undo.dart:104`), a microtask late. That is harmless, since `invoke` reads the live `value` anyway.
6. **The chord constants are shared by the table, the guard and the outer binding.** Accepted. The tests spell the chords literally, so a table that lost a chord is caught: X8 per the report, R8 and M15a–c per mine.
7. **Undo and Redo do not set busy.** Accepted; they are synchronous.
8. **The tooltip exists only while dirty.** Matches D7.
9. **`IconButton` sizing.** Accepted: 7 buttons fit the 44 px bar, and DC12 finds no overflow at 800 px.

## The three out-of-scope items

1. **The consume-only binding swallows the file chords in dialog text fields, such as the web name prompt.** Agree. It is intended by U-3 and R-10, and Cmd/Ctrl+S, O, N and Shift+S are not text-editing keys. It is worth recording for the human's web look.
2. **The route scope holding focus with no child focused puts the shell's bindings out of the chain.** Agree that this is pre-existing and not made worse; the outer binding then consumes and runs nothing. DC9 shows that focus returns to the canvas after the error dialog (Cmd+O acts again). DC4 shows that the new shell has the focus after each New (Ctrl+N after Cmd+N works).
3. **M-12a-29 is visible only through `onBeforeMutate`.** Agree. Task 9's re-fire should use the same spy, or Task 7's real-settle test with it.

## Claims in the report I verified

- The +1311 −25 diff and its file list.
- The API as described.
- 16 new tests and app 561.
- The engine and render standing counts, unchanged.
- The web build.
- Every named mutant red at the stated lines: DC7:549, DC7:528, DC9:629, DC8:592, DC5:402, DC6:475, DC9:631, DC10:716, DC9:672, DC11:766.
- R9 and R2 survive as the report says.

I did not re-fire X1–X15 individually. My R3, R4, R5 and R8 overlap X6, X9, X12 and X11 at neighbouring seams, and all were red.
