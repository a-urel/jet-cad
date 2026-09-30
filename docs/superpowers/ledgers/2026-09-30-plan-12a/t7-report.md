# Task 7 report: app, settling pending input (plan 12a, spec D2 settle, T-1, T-4, U-1, U-2)

**Commit:** `725ff74` `feat(app): flows settle pending input first` on `plan-12a/document-lifecycle` (parent `15cdbea`). Not pushed. The message ends with the two trailers. 5 files, +430 −38:
- `apps/floor_planner/lib/main.dart`
- `apps/floor_planner/lib/page_panel.dart`
- `apps/floor_planner/lib/text_entry_overlay.dart`
- `apps/floor_planner/test/document_commands_test.dart` (DC10 and DC10b converted, and a helper added)
- `apps/floor_planner/test/document_settle_test.dart` (new)

`packages/jet_cad/analysis_options.yaml` has been rewritten by `flutter pub get`. It is left unstaged and was not committed.

## The API as landed

**`main.dart`, `_PlannerShellState._settlePendingInput()`.** It is synchronous. It is registered with the host through `onSettle`, as in Task 5, and `_undo` and `_redo` call it too. It runs these steps in order:
1. `if (_text.isPending) _text.finish(_context);`: the open text entry's typed text is committed as one step (R-5), and the entry closes. The overlay's `_onPending` then hands the focus back to the canvas. An empty entry just closes.
2. `if (FocusManager.instance.primaryFocus is PanelFieldFocusNode) …handBack();`: a focused panel field is handed back. For a Selection panel field, its focus-loss listener commits the value.
3. `_pagePanel.currentState?.resyncScale();`: the scale field shows the stored scale again, and nothing is committed.
4. `FocusManager.instance.applyFocusChangesIfNeeded();` (T-4).

`PlannerShell.debugOnSettle` is **removed**, because no test needs it any more (see DC10/DC10b below). `main.dart` now imports `panel_focus.dart`. The shell holds `GlobalKey<PagePanelState> _pagePanel` and passes it as the `PagePanel`'s key.

The host is unchanged. Every flow (`newFlow`, `openSampleFlow`, `openFlow`, `saveStep`, `saveAsStep`) already calls the registered settle first (Task 5).

**`page_panel.dart`.** `_PagePanelState` is now the public `PagePanelState`. It gains `void resyncScale() => _syncScale();`, with dartdoc citing D2 and D14. Nothing else changed.

**`text_entry_overlay.dart`** is the route-scope fix, below. The `TextField` gains `onTapOutside: _onTapOutside`. `_onTapOutside` returns without acting for a native touch on Android, iOS and Fuchsia. Otherwise it calls `_focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild)`. So focus is dropped in exactly the cases where `_EditableTextTapOutsideAction` drops it (editable_text.dart:6876-6906), but it goes back to the canvas, not to the route's scope. The focus loss still cancels the entry through `_onFocus`, unchanged: D2's "that rule stays for every other focus loss". The class dartdoc now covers the flow commit and where the focus goes.

## The route-scope finding (from the Task 6 report)

I probed each ordinary path with a scratch test, deleted afterwards. After each path I recorded `primaryFocus`, then pressed Cmd+S and checked whether a write happened. The settle was still a no-op then; this was the tree at `15cdbea`.

| Path | Android, touch (the test default) | macOS, mouse |
|---|---|---|
| Text entry, then Enter | canvas, saves | canvas, saves |
| Text entry, then Escape | canvas, saves | canvas, saves |
| Text entry, then a click on the tool palette | canvas, saves | **route scope, Cmd+S wrote 0** |
| Text entry, then a click on the Page panel's title | entry stays open (touch does not unfocus), saves | **route scope, entry cancelled, Cmd+S wrote 0** |
| Text entry, then a click on the grid checkbox | entry stays open, saves | **route scope, Cmd+S wrote 0** |
| Error dialog closed (OK) | canvas, saves | canvas, saves |
| Scale field, then Enter (handBack) | canvas, saves | canvas, saves |
| Scale field, then a tap outside (handBack) | canvas, saves | canvas, saves |
| Scale field, then a palette tap | canvas, saves | canvas, saves |
| After New (a swap), then a scale field typed, then Cmd+S | saves | saves |
| Text entry, then toolbar Save | saves; the entry stayed open (no settle yet) | the same |

- **Cause.** On a desktop pointer, `EditableText`'s default tap-outside is a plain `unfocus()`. That clears the scope's focus history and leaves the focus on the route's `FocusScopeNode`, which is above the shell's `CallbackShortcuts`. The file chords then reach only the consume-only binding above the Navigator, so they run nothing. The tool letters are dead too, until a canvas click.
- **What was not affected.**
  - The panel fields already hand back.
  - A closed dialog restores the home scope's history, which contains the canvas.
  - The toolbar is `ExcludeFocus` and inside the `TextFieldTapRegion`.
- **Fix.** A settle could not do this: with the focus on the scope, Cmd+S never reaches the shell, so no settle runs. So the fix is in the entry's own hand-back: `_onTapOutside`, above. ST5 pins it and ST6 pins the platform rule it keeps.

## Tests

App total: **+569 = 563 (at `15cdbea`) + 6 new**. DC10 and DC10b were converted in place, so their count is unchanged.

**Converted, in `document_commands_test.dart`:**
- A new helper, `typeThickness(tester, on, wall, text)`: a canvas click selects the wall, a tap on `wall-thickness`, then `enterText` without Enter. Its premises: the wall is selected, the focus is a `PanelFieldFocusNode`, and the document is unchanged.
- `pumpBare` loses its `debugOnSettle` parameter.

| Test | Pins |
|---|---|
| **DC10** (U-2, M-12a-29), now with a real typed value | A bare shell with two walls off-origin under a rotated camera; Cmd+Z leaves a redo stack. The remaining wall's thickness is typed as `262.5` without Enter, and Redo is enabled. A tap on `toolbar-redo` (the tap region keeps the field focused) gives:<br>• the params `== copyWith(thickness: 262.5)`<br>• depth 2, `canRedo` false<br>• **dispatcher calls == 1** (the settle's commit; there is no redo call)<br>• no `CommandRedone` and exactly one `CommandApplied`<br>• Redo disabled, and the focus handed back |
| **DC10b** (R-9), now with a real typed value | Two walls. The last wall's thickness is typed as `90`. A tap on `toolbar-undo` gives:<br>• the params `==` the originals (the commit is undone, the wall stays)<br>• depth 2, `stateId ==` the two-wall id, `canRedo`<br>The tap is on the button because Cmd+Z in a focused field is guarded (S-7). A tap on Redo then brings back thickness 90, so the redo branch is the committed value. |

**New, in `document_settle_test.dart`** (world point `far = (37654.25, −28765.5)`, rotated camera):

| Test | Pins |
|---|---|
| **ST1** (S-4, S-5, S-19; M-12a-11) | The app, two walls drawn through the Wall tool, the second one selected by a canvas click. Its thickness is typed as `262.5` with no Enter. Premises: the field is focused, nothing is committed, depth 2, dirty. Then Cmd+S (untitled, so Save As is scripted). Results:<br>• one write, and **the decoded bytes' `WallParams` `== copyWith(thickness: 262.5)`**<br>• the bytes `==` `bytesOf(doc)`<br>• depth 3 (**the commit is its own step**)<br>• **clean**, and `savedState == stateId`<br>• the canvas has the focus<br>• one Cmd+Z restores the original params, keeps both walls, and makes the document dirty |
| **ST2** (R-5; M-12a-11) | A wall, then T and a click. `Kitchen` is typed and not committed (premise). Then Cmd+S. Results:<br>• **the decoded bytes' text entities are `['Kitchen']`**, and the bytes `==` `bytesOf(doc)`<br>• depth +1, the entry closed, **clean**<br>• the canvas has the focus, and L then activates the Line tool |
| **ST3** (T-1, U-1; M-12a-22, M-12a-28), `TargetPlatformVariant.only(macOS)` | A wall, then T and a **mouse** click. `Hall` is typed, and `toolbar-save` is **enabled** with the entry open. A **mouse** tap on `toolbar-save` gives:<br>• the decoded bytes' texts `['Hall']`, and the bytes `==` the document's<br>• depth +1, the entry closed, **clean**<br>• the canvas focused |
| **ST4** (T-13, D14) | A non-default stored scale is submitted first: `125` with Enter, one step, dirty. Then `40` is typed without Enter (the field is focused). Then Cmd+S. Results:<br>• the decoded bytes' scale is 125, and the bytes `==` the document's<br>• the document's scale is still 125, and depth is still 1 (nothing committed)<br>• **the field shows `panelNumberText(125)`**<br>• clean, and the canvas focused |
| **ST5** (route-scope fix), macOS | A wall; Cmd+S names the file `/p/room`. Then, for a **mouse** click on `tool-line` and then on the Page panel's title:<br>• a text entry with `Porch` typed ends<br>• the bytes are unchanged (cancelled, not committed)<br>• **the canvas has the focus**<br>• **Cmd+S is handled and writes** the unchanged bytes at `/p/room` |
| **ST6** (the kept platform rule), `TargetPlatformVariant.only(android)` | A touch tap on the Page title with the entry open: the entry stays open with the focus, as `EditableText`'s default does, and Enter (`receiveAction(done)`) still commits `Stair`. |

## Mutants

Procedure, driven by `…/scratchpad/p12t7-mutants.py`:
1. `cp` a backup to `…/scratchpad/p12t7-<name>-<file>`.
2. Apply the mutation as a Python replace that asserts exactly one match.
3. Run `CI=true flutter test test/document_settle_test.dart test/document_commands_test.dart`. X11 also runs `planner_draw_test.dart`.
4. `cp` the backup back, then `diff` it: every one exited 0.

After all runs, `cmp` of every backup against the tree showed them identical. The logs are `p12t7-mutants.log` and `p12t7-mutants-2.log` (the second covers X5b, X11, X6 and M-12a-22, re-run after ST6 was added). Lines refer to the committed files, and each is the first failing line of the red test.

| Mutant | Mutation | Red test : line |
|---|---|---|
| **M-12a-11** (no settle) | The host's `_settlePendingInput() => _settle?.call()` becomes `{}`, so no flow settles | ST1:126 (bytes lack the thickness), ST2:164 (no text), ST3:201, ST4:248 (the field shows 40) |
| **M-12a-11** (no apply) | Delete `applyFocusChangesIfNeeded()` from the settle | ST1:126 (the bytes were encoded before the commit landed); DC10:730 (the redo ran first, depth 3); DC10b:756 |
| **M-12a-22** | The toolbar's `TextFieldTapRegion(` becomes `KeyedSubtree(` | ST3:201 (the entry was cancelled on pointer down, so the bytes have no text) |
| **M-12a-28** | `TextTool.isMidShape => isPending` | ST3:191 (**Save disabled** with the entry open); ST2:162 (Cmd+S does nothing) |
| t2-review R3 | `isMidShape => isPending && controller.text.isNotEmpty` | ST3:199 (the button tap makes no write); ST2:162. This closes t2-review's m-1 at the app level. |
| **M-12a-29** (re-fired with the real settle) | `_redo` does not re-read `canRedo` | DC10:732 (dispatcher calls 2, not 1) |
| X1 | The settle drops `_text.finish` | ST2:164, ST3:201 |
| X2 | The settle calls `cancelText` instead of `finish` | ST2:164, ST3:201 |
| X3 | The settle drops `handBack` | ST1:126, ST4:251 (the focus stays on the field), DC10:727, DC10b:756 |
| X4 | The settle drops `resyncScale` | ST4:248 |
| X5 (first form) | `applyFocusChangesIfNeeded` inserted before the hand-back, **with the final call kept** | **survived** (+21). This mutant is equivalent: the apply simply runs twice. X5b below replaces it. |
| X5b | The apply moved **before** the hand-back, with none after | ST1:126, DC10:730, DC10b:756 |
| X6 | The overlay's `onTapOutside` removed (back to the framework default) | ST5:280 (the focus is on the route scope) |
| X7 | `onTapOutside` does a plain `_focus.unfocus()` | ST5:280 |
| X8 | `_undo` does not settle | DC10b:756 (the undo removes the wall) |
| X9 | `_redo` does not settle | DC10:727 |
| X10 | The shell's settle body is empty | ST1:126, ST2:164, ST3:201, ST4:248, DC10:727, DC10b:756 |
| X11 | `onTapOutside` drops the focus on every platform and pointer | It **survived** the first run (+49). I added ST6, and it is now red at ST6:302 (the entry closed on an Android touch). |

## Gates (final tree `725ff74`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Package | Command | Summary | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.` These are the two standing `generate_document_test` failures ("the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero…"). | 1 (standing, unchanged) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.` These are the seven standing failures: text ladder rungs 1–5 and text lod ladder rungs 1–2. | 1 (standing, unchanged) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | 178 files (0 changed) | 0 |
| app | `flutter test` | `+569: All tests passed!` | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | 121 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

Timing of the runs:
- **Engine:** run while the mutant batch was running. The mutants touch only app files and `text_tool.dart`, not the engine.
- **Render, app and web build:** run after every mutant was restored and every backup `cmp`'d, on content identical to the commit.

## Deviations

1. **The page panel's hook is a `GlobalKey<PagePanelState>`**, with the state made public and given a `resyncScale()` method. The plan says only "`_syncScale` reachable from the settle". A registrar parameter would have needed `ShellSettleRegistrar` in `page_panel.dart`, which would import `main.dart`.
2. **The settle re-syncs the scale unconditionally**, not only when the field is focused. This also covers the case the page panel's dartdoc accepts, where the scale was left by Tab or by another field with text still showing. `_syncScale` writes only when the text differs.
3. **DC10 and DC10b were converted in place** to real typed values, not duplicated in the new file, and `debugOnSettle` was removed. The plan's U-2 and R-9 tests are therefore DC10 and DC10b.
4. **R-9 is exercised through the Undo button.** In a focused panel field Cmd+Z is guarded (S-7, DC8), so a typed value reaches Undo's settle only through the toolbar.
5. **The route-scope fix is in `text_entry_overlay.dart`** (`onTapOutside`), a file in Task 7's plan list. It keeps `EditableText`'s platform rule for *when* focus drops, which duplicates the framework's switch in about ten lines, and changes only *where* focus goes. ST6 pins the rule.
6. The settle closes an open but **empty** text entry, because `finish` with empty text commits nothing and cancels.

## Found outside scope (reported, not fixed)

- **Web input blur.** On web, `EditableText.connectionClosed` unfocuses a text entry with a plain `unfocus()` when the input loses focus while the app is still `resumed` (the order `page_panel.dart`'s dartdoc describes for Chromium). That could still leave the focus on the route scope after a real window switch. It is only reachable in a browser, and it belongs to the human's web look.
- **Stale citations.** `text_entry_overlay.dart`'s line numbers, which spec D2 cites (`:22-24, 72-78`), have moved. The `_onFocus` handler is now at `:80-86`. This is for Task 9's amendments.
- **t2-review m-1 is now covered.** R3 on `TextTool.isMidShape` is red at the app level (ST2, ST3). The optional two lines in `mid_shape_test.dart` are still not added (render is frozen).
