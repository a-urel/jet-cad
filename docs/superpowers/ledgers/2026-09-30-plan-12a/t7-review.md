# Review: plan 12a, Task 7 (`725ff74`)

**Verdict: Approved.** There are no Important findings. The five minor findings and notes below can be fixed in Task 9's sweep or left as they are.

- **Reviewed in:** the detached worktree `.claude/worktrees/plan-12a-review` at `725ff74`, parent `15cdbea`.
- **Read:** CLAUDE.md; the plan (the header, P-1 to P-6, the global constraints, Gates, Tasks 6 and 7, and the mutant table); spec D2 whole, plus D6, D7, D14, Testing, Named mutants, the rulings and revisions 2 to 4; `t7-brief.md`; `t7-report.md`; `t6-review.md`, for R1 and m5.
- **Every claim in the report was checked independently.** Mutants were made with `cp` backups under `scratchpad/p12r7-`, restored, and `diff` exited 0 each time. After the last run, `cmp` of all 25 backups against the tree found them identical. The runner is `p12r7-mutants.py` and its log is `p12r7-mutants.log`.
- **Two scratch test files** (`test/p12r7_p6_scratch_test.dart` and `test/p12r7_probe_test.dart`) were created, run and deleted, all before the gates ran.
- **The final `git status`** shows only the known `packages/jet_cad/analysis_options.yaml` rewrite.

## Scope and spec conformance

The diff does what Task 7 asks and nothing else. It touches `main.dart`, `page_panel.dart`, `text_entry_overlay.dart`, DC10 and DC10b, and the new `document_settle_test.dart`. `selection_panel.dart` is untouched, as the plan allows.

**The settle** (`main.dart:523-529`) matches D2 and T-4 step by step:
1. It calls `finish(ctx)` on an open entry (R-5).
2. It calls `handBack()` when the primary focus is a `PanelFieldFocusNode`.
3. It re-syncs the scale field.
4. It calls `applyFocusChangesIfNeeded()`.

It is synchronous, and it is never called during a build.

**The ordering works.** `finish` makes the overlay's `_onPending` queue the focus hand-back. At step 2 the primary focus is still the entry's node, so nothing is handed back twice. The apply then lands the focus on the canvas. `_onFocus` runs afterwards, finds the entry no longer pending, and cancels nothing.

**Host flows.** At `document_host.dart:262-331`, all five flows call the settle as their first statement, before their first await.

**Undo and Redo** settle first and then re-read `canUndo` / `canRedo` (U-2). `debugOnSettle` is gone and has no references left anywhere in the repo. The commit message is the plan's, and it ends with the two trailers.

**Fixtures meet the testing bar.**
- ST1, ST2, ST3 and ST5 build their documents through the real tools, far from the origin (`far = (37654.25, -28765.5)`), under `aimCamera`'s rotated camera (0.3 rad).
- Each starts dirty with history.
- ST4 first submits a non-default scale of 125, which the save shows as `1:125`. So a re-sync to the default would be red, not green.
- The assertions are on the decoded bytes, `bytes == bytesOf(doc)`, the depth, `savedState == stateId`, and where the focus is.

**P-6.** ST3 and ST5 use `TargetPlatformVariant.only(macOS)` with `PointerDeviceKind.mouse`. That covers the entry being opened, the toolbar tap and the clicks outside. ST6 is Android with touch on purpose.

## Mutants I fired

All mutants were run with `CI=true flutter test test/document_settle_test.dart test/document_commands_test.dart`. The overlay mutants and Y10 also ran `planner_draw_test.dart` and `room_tool_test.dart`. The line given is the first failing line.

| Mutant | Mutation | Result |
|---|---|---|
| **M-12a-11** (no settle) | The host's `_settlePendingInput() => _settle?.call()` becomes `{}` | red: ST1:126, ST2:164, ST3:201, ST4:248 |
| **M-12a-11** (no apply) | `applyFocusChangesIfNeeded()` is deleted from the shell's settle | red: ST1:126 (thickness 200, not 262.5), DC10:730 (depth 3), DC10b:756 (the wall is gone) |
| **M-12a-22** | The toolbar's `TextFieldTapRegion(` becomes `KeyedSubtree(` | red: ST3:201 (texts `[]`) |
| **M-12a-28** | `TextTool.isMidShape => isPending` | red: ST2:162 (no write), ST3:191 (Save is disabled) |
| **M-12a-29** | `_redo` does not re-read `canRedo` | red: DC10:732 (dispatcher calls 2, not 1) |
| **t6-review R1** | `ShellShortcutGuard` also lists `...kFileChords` | **red:** ST1:121 (Cmd+S not handled with the thickness field focused), ST2:159, ST4:239. It survived the whole suite at Task 6 and is now pinned. That closes t6-review m2. |
| Y7 | `saveStep` does not settle | red: ST1:126, ST2:164, ST3:201, ST4:248 |
| Y11 | The overlay's `onTapOutside:` is removed (back to the framework's default) | red: ST5:280 (the canvas does not have the focus) |
| Y12 | `_onTapOutside` does a plain `_focus.unfocus()` | red: ST5:280 |
| Y1 | `_onTapOutside`: `if (!kIsWeb)`, so a **mouse** on Android keeps the entry open | **survives** (+61), see m2 |
| Y2 | `_onTapOutside`: macOS moves to the `return` cases, so a **touch** on macOS keeps it open | **survives** (+61), see m2 |
| Y3 | `newFlow` does not settle | **survives**: settle and commands files +22; every document, shell and new-document test file +67. See m1. |
| Y4 | `openFlow` does not settle | **survives** (+22, +67), see m1 |
| Y5 | `openSampleFlow` does not settle | **survives** (+22, +67), see m1 |
| Y6 | `saveAsStep` does not settle | **survives** (+22, +67), see m1 |
| Y8 | `resyncScale` re-syncs only while the scale field is focused (undoes deviation 2) | **survives** (+22), see m3 |
| Y9 | The settle skips `finish` on an empty entry (undoes deviation 6) | **survives** (+22), see m3 |
| Y10 | `finish` moved after `applyFocusChangesIfNeeded` | survives (+61). It is equivalent for anything a test can observe: the commit is still synchronous before the flow encodes, and only the focus hand-back moves by a microtask. |

Every named Task 7 mutant is red at the line the report gives. All of the report's lines match mine.

## The route-scope fix (`text_entry_overlay.dart:99-113`)

**Is it the framework's rule, exactly?** Compared with `_EditableTextTapOutsideAction` (`editable_text.dart:6876-6906`, Flutter 3.47.2):

- **macOS, Windows and Linux:** the framework unfocuses for every kind of pointer. The fix does the same: for a touch, the switch breaks to the unfocus, and every other kind skips the switch.
- **Android, iOS and Fuchsia, touch:** the framework unfocuses only on the web. The fix returns early only when `!kIsWeb`, so it matches.
- **Android, iOS and Fuchsia, mouse, stylus, inverted stylus or unknown:** the framework unfocuses, and so does the fix.
- **Android, iOS and Fuchsia, trackpad:** the framework throws `UnimplementedError`, while the fix unfocuses. This case cannot be reached: a trackpad sends pan and zoom events, not a `PointerDownEvent` with that kind.

So the fix is exact for every reachable case. It changes only where the focus goes: `previouslyFocusedChild`, as `_onPending` and `handBack` already do. When the node no longer has the focus, `unfocus` does nothing, so an `onTapOutside` armed at an earlier build is harmless.

**What overriding costs.** Setting `onTapOutside` bypasses `Actions.invoke(EditableTextTapOutsideIntent)`, so an ancestor that overrides that intent would no longer be consulted. The app has no such override (grep of `lib/`), so nothing is lost today. The dartdoc states the rule accurately.

**The Task 6 finding is resolved.** I re-fired the fix's removal (Y11) and a plain unfocus (Y12): both are red at ST5:280.

**Paths I probed on macOS with a mouse**, each starting from a titled document, then Cmd+S (scratch test, deleted):

| Path | Focus afterwards | Cmd+S handled | Writes |
|---|---|---|---|
| A pick in the sheet dropdown | `DropdownButton<SheetSize?>`, inside the shell | yes | 1 |
| Text entry, then a canvas click | `InteractionLayer` | yes | 1 |
| A click on the Portrait segment | `InteractionLayer` | yes | 1 |
| Thickness field typed, then a dropdown pick | `DropdownButton` | yes | 1 |
| Text entry, then Tab | `InteractionLayer` | yes | 1 |

No ordinary path I found leaves the focus on the route's scope. That agrees with the report's table.

## Findings

### Important

None.

### Minor

**m1. Only Save's settle is pinned: removing it from Save As, New, Open or Open sample leaves every test green (Y3 to Y6).**
- **What D2 requires:** every flow settles first.
- **What the code does:** every flow does settle, but no test fails when one of them stops.
- **Save As matters now:** without its settle, Cmd+Shift+S would write bytes without the typed value. That is exactly S-4 and S-5, reached by another chord.
- **New and Open** replace the document. A missing settle there becomes observable with Task 8's dirty check (D10). A clean document with a typed Selection value would have to ask first, the same way T-7 does for exit.
- **Suggested fix:** add a Cmd+Shift+S case to ST1, or loop ST1 over Cmd+S and Cmd+Shift+S. Also give Task 8 or Task 9 a replace-flow case: clean document, value typed, New → the dialog appears.

**m2. The kept platform rule is pinned in two of its four reachable cases.**
- ST5 pins macOS with a mouse (the focus drops) and ST6 pins Android with touch (the focus stays).
- Android with a **mouse**, where it must drop (Y1), and macOS with a **touch**, where it must drop (Y2), both survive.
- The web branch cannot be tested under `flutter test`, because `kIsWeb` is a constant.
- The code is correct (see the table above). The report's "ST6 pins the platform rule" is only partly true.
- **Suggested fix:** add a mouse tap to ST6 on Android: the entry ends and the canvas gets the focus. Add a touch tap to ST5 on macOS.

**m3. Deviations 2 and 6 are behaviour with no test (Y8, Y9 survive).**
- **Deviation 2:** the scale is re-synced even when its field is not focused. The report's reason is a scale left by Tab with its text still showing. No test does that.
- **Deviation 6:** the settle closes an empty entry. No test opens an empty entry and then saves.
- Both behaviours are sensible, and both are consistent with D2 and R-5. Either pin them (Tab out of the scale, then Cmd+S; T, a click, Cmd+S, then the entry is closed and the canvas focused), or accept them as unpinned and record that in the results note.

### Notes (no action needed)

**n1. P-6 and DC10/DC10b.**
- DC10 and DC10b are now Task 7's toolbar pointer-path tests (U-2, R-9). They tap with `flutter_test`'s default Android touch.
- I ran a scratch copy on `TargetPlatformVariant.only(macOS)`, with mouse taps on the buttons, the canvas selection click and the field. Both are green there.
- On that copy, M-12a-11 (no apply) is red at 731 and 757, and M-12a-29 is red at 733, as in the originals. So the result does not depend on the platform.
- M-12a-22 does not bite either DC test, on either platform. The Selection field's own `onTapOutside: handBack` (`selection_panel.dart:771`) commits the value on pointer-down even without the tap region, with the same end state. So ST3, the text entry, is rightly the only test that pins M-12a-22.
- Converting DC10 and DC10b to macOS with a mouse would be for uniformity only.

**n2. Deviations 1, 3, 4 and 5 are sound.**
- **1.** A public `PagePanelState` with a `GlobalKey` avoids a `page_panel.dart` to `main.dart` import cycle. The key belongs to each shell state, so a keyed swap gives a fresh one.
- **3.** DC10 and DC10b were converted to real typed values, and `debugOnSettle` was removed, as the brief asked.
- **4.** A Cmd+Z in a focused field is guarded (S-7), so R-9 can only be exercised through the button.
- **5.** `text_entry_overlay.dart` is in Task 7's file list.

**n3. Stale citations, confirmed.** Spec D2 cites `text_entry_overlay.dart:22-24, 72-78` at spec lines 195 and 206. `_onFocus` is now at `:80-86`. This is for Task 9's amendments.

**n4. The report's out-of-scope web point stands.** `EditableText.connectionClosed` unfocuses the entry with a plain `unfocus()` when the browser input blurs. That can only be seen in a browser, so it goes to the human's web look.

## Gates (`725ff74`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

- **Engine** was run in parallel with the mutants; they touched no engine file.
- **Render, app and the web build** were run after every mutant was restored, both scratch tests were deleted, and the backups were checked with `cmp`.

| Package | Command | Result | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.`: the 2 standing `generate_document_test` failures | 1 (standing, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | Formatted 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.`: the 7 standing failures, `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 | 1 (standing, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | Formatted 178 files (0 changed) | 0 |
| app | `flutter test` | `+569: All tests passed!` | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | Formatted 121 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

The app count of 569 matches the report's 563 + 6 (ST1 to ST6). The engine and render counts are unchanged from the brief's baseline.
