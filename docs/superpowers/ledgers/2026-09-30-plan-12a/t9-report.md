# Task 9 report (code part): the sweep (plan 12a)

**Commits** on `plan-12a/document-lifecycle`, parent `5998504`, not pushed, both trailers on each:
- `e678183` `fix(app): the status line takes the width the name leaves`: `lib/main.dart` and DC12b in `test/document_commands_test.dart` (item 5).
- `c6c3445` `test: plan 12a sweep - carried test gaps, comments, app environment`: everything else.

No `docs/`, `roadmap/` or `STATUS.md` edit. `analysis_options.yaml` was not committed; the only change left in the tree is `packages/jet_cad/analysis_options.yaml`, which `pub get` rewrites. After the sweep, `git diff --stat -- packages/*/lib apps/floor_planner/lib apps/floor_planner/test/support` showed only the three intended lib files (`main.dart`, `document_host.dart`, `startup_plan.dart`). No mutant was left behind, and every restore `diff` exited 0.

## Carried items

| # | What | Where (final tree) |
|---|---|---|
| 1 | The `pushUndoOnly` comment reworded: redo records through `commitRedo`, which, unlike `recordExecute`, leaves the redo stack alone. Comment only. | `packages/jet_cad_2d/test/document/command_test.dart:365-370` |
| 2 | MS4 now has two expects after typing and before Enter: `tool.isMidShape` and `rig.tools.active.isMidShape` are both false. | `mid_shape_test.dart:181-183` |
| 3 | **Deviation:** only `flutter: ">=3.38.0"` was raised. `sdk` stays `^3.5.0`, with a comment explaining why. See "Item 3" below. | `apps/floor_planner/pubspec.yaml` |
| 4 | DF7: `holdWrites` set, then `failNextWrite`. The write is recorded, no write is held, it throws, and the next write is held again. DF8: `createDocumentFiles(askName: …)` through `document_files.dart` does not throw (the stub would), and `writesInPlace` is true. | `document_files_test.dart:151` (DF7), `:175` (DF8) |
| 5 | The status line takes the free width. The name and the status share one `Expanded` (a `LayoutBuilder` + `Row`). The name is capped at half of that shared width by a `ConstrainedBox` and takes only what it needs; the status is `Expanded`. There is no `Spacer`, and a 16 px gap sits before OSNAP. DC12 (800 × 600) is unchanged and green. New DC12b at 1440 × 900 checks two things. (a) Short name `• plan` with the notice `Room — Already a room: the living room by the bay` (≈686 px): the notice is not cut, it starts 16 px after the name, and it is wider than half the shared width. (b) After Save As with a long name: the name is cut at exactly half, the status is cut, it ends at the same right edge, and OSNAP and zoom are on screen. **Deviation from the literal "Expanded, no Spacer":** a `Flexible` name beside an `Expanded` status gives the status only half the free width, because Flutter does not redistribute a loose flexible's unused share. The half-cap layout gives the status everything the name leaves. The mutant `T6-m1-halves` (the literal reading) is red at DC12b:923. | `lib/main.dart:684-720`, DC12b `document_commands_test.dart:883` |
| 6 | DH7: pumps `DocumentHost` over a `_CountingSession` whose `busy` counts its listeners. After New, Open sample and Open, each followed by two pumps, the count equals the pre-swap count. Busy still disables `toolbar-save` on the new shell afterwards. It counts `session.busy` only: the host's `_notBusy` `DerivedFlag` exposes no listener count, and I did not add a lib seam for it. R6 already leaks through `busy` (each file flag has it among its `_idleSources`), so R6 is red. | `document_host_test.dart:360` |
| 7 | Dartdoc on `fileCommands`: `enabled` means only "no flow running"; it is not mid-shape-aware; bind through the shell. | `document_host.dart:229-232` |
| 8 | ST1 is now a loop over Cmd+S and Cmd+Shift+S (ST1, ST1b), with a `cmdShiftS` helper. | `document_settle_test.dart:98-155` |
| 9 | ST5 has a third case, a touch on the Page panel on macOS: the entry ends, is cancelled, the canvas has the focus, and Cmd+S saves. ST6 adds a mouse click on Android: the entry ends, is cancelled, and the canvas has the focus. | ST5 `:269`, ST6 `:314` |
| 10 | Both deviations are pinned. ST7 (deviation 2): a scale typed then left by **Tab** keeps its text; Cmd+S re-syncs the field to the stored scale, commits nothing, and the bytes carry the stored scale. ST8 (deviation 6): an empty entry, then Cmd+S; the settle closes it, commits nothing, the canvas is focused, and the result is clean. | ST7 `:342`, ST8 `:379` |
| 11 | Stale comments. `startup_plan.dart`: "Builds the startup flat" → "Builds the sample flat (File > Open sample, spec 12a D4)"; `startupPage`'s dartdoc now says it is the sample's page and that New's is `defaultPage()`. `document_host.dart` `openSampleFlow`: "the startup flat" → "the sample flat". The header of `startup_plan.dart:1-4` had already been fixed by Task 5. The grep `fixture a human\|no redo\|before sub-project 12\|sub-project 12\|startup flat\|app opens on` over the app's `lib`, `packages/*/lib` and `macos/Runner` now finds nothing. | |
| 12 | RP8: dirty and titled, then New, and the dialog is up. For each of Cmd and Ctrl with S, O, N and Shift+S: the key is handled, there is still exactly one dialog, no write, no `saveLocation` call, and `openCalls` is unchanged. Cancel then `expectKept`, with `unscriptedCalls` 0. | `document_replace_test.dart:594`; M-12a-24 red at `:628` |
| 13 | DO6's description now reads "a cancelled picker, after the replace dialog, shows no error dialog"; its inline comment is reworded the same way. | `document_open_test.dart:305` |

### Item 3 (a finding for the controller)

I raised `sdk` to `^3.10.0` first and ran `pub get`; `pubspec.lock` did not change. But the sdk lower bound sets the **language version**, and it turned the app's gates red:
- `dart format --set-exit-if-changed` reported `Formatted 127 files (120 changed)`, exit 1. From 3.7 on, the formatter uses the tall style.
- `flutter analyze` reported `8 issues found` (`use_null_aware_elements` infos, e.g. `lib/parametric/room_tool.dart:311`).

"Nothing else changes" and "every task ends green" could not both hold. I kept `sdk: ^3.5.0` and raised only `flutter: ">=3.38.0"`, which already implies Dart 3.10, so the pubspec still states the toolchain it needs. A comment in the pubspec says why.

To take the full ruling, a separate commit would reformat 120 files and fix the 8 lints. That is for the controller to rule on.

## The sweep

**Script:** `scratchpad/p12t9-sweep.py`.
- For each mutant: `cp` each touched file to `p12t9-<name>-<file>.bak`, then apply exact replacements (each asserted to match once).
- Run `CI=true … test --reporter json`: the engine on `undo_state_test` + `command_test`, the render layer on `mid_shape_test`, and the app on all ten document-level files (`document_{commands,exit,files,host,open,replace,save,settle}_test`, `new_document_test`, `planner_shell_test`: 93 tests).
- In `finally`, `cp` back and `diff`. Every one of the 58 restores printed `diff=0`.

**Output and logs:** `scratchpad/p12t9-sweep.out` / `.log`, and one JSON log per mutant, `p12t9-<name>.log`.

**How lines are read:** the first line in each cell is the failing expectation ("caught by the test expectation on the following line"). `rig:N` is `test/support/document_rig.dart:N`; 114 is `answerReplace`'s "the dialog is up" premise and 124 is `noDialog`. File names are shortened, so `host:68` is `document_host_test.dart:68`. Counts are passed/failed within the run.

**Result: every mutant is red. There are no survivors.** DF7 was reworked once (below) and re-fired.

### Named mutants (32, plus the render mutant)

| Mutant | Mutation | Result | Red test : line |
|---|---|---|---|
| M-12a-1 | save writes a key-sorted map | +70 −23 | **DO1 open:124** (first bytes == the codec's); also DO2:204, DO3:257, DS1:60, DS2:116, DS4:175, DS5:215, DH6 host:311, EX2:178, EX3:213, EX4:264, RN1:482, RN2:517, RP4:269, RP6:374, ST1/ST1b:143, ST2:181, ST3:218, ST4:260, ST5:308, ST8:398 |
| M-12a-2 (save) | `markSaved(_session.savedState, …)` | +60 −33 | **DH3 host:68** (clean after save); DH4:68, DH6:275, DS1:79, DS2:117, DS4:178, DS5:216, DC9:703, DC11:796, DC12b:936, RP4:263, RP5:311, RP7:406, RN1:483, ST1/1b:146, ST2:185, ST3:221, ST4:265, ST5:311, ST7:376, ST8:401 |
| M-12a-2 (exit) | same run | | **EX1 exit:64** (save then exit asks nothing); EX2/4/5/6/7 exit:41, EX3 rig:124, EG1 exit:374 |
| M-12a-3 (failure) | save point moved on a failed write | +90 −3 | **DS2 save:107**; EX2 exit:121, RP3 replace:88 |
| M-12a-3 (cancel) | save point moved on a cancelled Save As | +90 −3 | **DS3 save:138**; EX3 exit:203, RP3 replace:223 |
| M-12a-4 | dirty = any change (never cleaned) | +86 −7 | **DH3 host:52** (undo → clean); DH4:52, DH6:325, DS1:79, EG1 exit:367, RP3:230 |
| M-12a-5 | id from the top entry's identity | engine +22 −9 | **exact-return undo_state:97**; walk :193, eviction :224, failed-undo :264, failed-redo :286, clear×3 :313, new-dispatcher :354 (as Tasks 1/1b) |
| M-12a-6 (a) | id = depth | +25 −6 | **eviction undo_state:215**; edit-after-undo :138, walk :161, clear×3 :313 |
| M-12a-6 (b) | eviction hands the evicted id down | +29 −2 | **eviction undo_state:224**; walk :191 |
| M-12a-7 | decode registers only the catalog | +88 −5 | **DO4 open:275** (page after Open); DO6:343, DC9:672, DC12:841, DC12b:948 |
| M-12a-7b | decode registers only `PageComponent` | +87 −6 | **DO5 open:294** (catalog after Open); DO1:136, DO2:213, DO3:252, DC12:850, DC12b:897 |
| M-12a-8 | swap before decode succeeds | +91 −2 | **DO6 open:360**; DC9:655 |
| M-12a-9 | a disabled Undo's chord calls the dispatcher | +91 −2 | **DC7 commands:567** (busy "no call", spy); RN1 replace:475 |
| M-12a-10 (all) | `while (false && differsFromSave)` | +74 −19 | **RP1 replace:124**; RP4:260, RP6:355, RP7:423, RP8:607, DO6:340, EX2:129, EX4:231, EX5:301, EX6:335, and rig:114 in DH2, DH4, EG1, EX3, RN1–3, RP2, RP3 |
| M-12a-10 (New only) | New skips the ask | +81 −12 | **RP1 replace:124**; RP4:260, RP7:423, RP8:607, EX4:231, rig:114 ×7 |
| M-12a-10 (Open sample only) | | +87 −6 | **RP1 replace:124**; RP7:423, rig:114 in EG1, RP2, RP3, RP4 |
| M-12a-10 (Open only) | | +88 −5 | **RP1 replace:124**; RP6:355, RP7:423, DO6:340, DH4 rig:114 |
| M-12a-11 (no settle) | `_settlePendingInput() {}` | +84 −9 | **ST1/ST1b settle:140**; ST2:179, ST3:216, ST4:263, ST7:373, ST8:396, EX5 exit:301, RP7 replace:423 |
| M-12a-11 (no apply) | `applyFocusChangesIfNeeded` dropped | +87 −6 | **ST1/ST1b settle:140**; DC10 commands:730, DC10b:756, EX5:301, RP7:423 |
| M-12a-12 | busy never set | +79 −14 | **DS1 save:64** (second Cmd+S makes no second write); DC7:546, DC9:647, DO6:355, DS2:104, DS7:282, EX2:130, EX4:64, RN1:455, RN2:521, RN3:561, RP1:128, RP3:238 |
| M-12a-13 | save point read after the write | +89 −4 | **DS1 save:75**; EX4 exit:265, RN2 replace:518 |
| M-12a-14 (undo) | abortUndo restamps with the current id | +29 −2 | **failed-undo undo_state:261**; walk :191 |
| M-12a-14 (redo) | abortRedo restamps | +29 −2 | **failed-redo undo_state:286**; walk :191 |
| M-12a-15 a/b/c | the guard lacks Meta+Shift+Z / Ctrl+Shift+Z / Ctrl+Y | +92 −1 each | **DC8 commands:610** |
| M-12a-16 | Open catches `on Exception` only | +91 −2 | **DO6 open:343**; DC9 commands:645 |
| M-12a-17 | busy not reset on failure | +87 −6 | **DS2 save:108**; DS3:140, DS7:288, DC4:359, EX2:122, EX3:204 |
| M-12a-18 | Open calls `ensureDashedLinetype` | +92 −1 | **DO3 open:253** |
| M-12a-19 | the first subscription kept | +70 −23 | **DH4 host:48** (dirty after Open); DH6:304, DS1/2/5/7 save:39, DC7:538, DC9:671, DC12:829, DC12b:919, EG1:394, RN1–3 and RP1–8 replace:65 |
| M-12a-20 | the shell disposes the host's snap | +31 −62 | **DH5 host:210** (F3 after a swap); crashes spread through most widget tests (disposed notifier) |
| M-12a-21 | old document not disposed | +85 −8 | **DH5 host:205** (swap hygiene); DH6:294, RN1:483, RN3:550, RP2:166, RP4:270, RP5:320, RP6:376 |
| M-12a-22 | toolbar outside the `TextFieldTapRegion` | +92 −1 | **ST3 settle:216** |
| M-12a-23 | `_idle` ignores mid-shape | +91 −2 | **DC5 commands:420**; DC6:493 |
| M-12a-24 | no above-Navigator file-chord binding | +91 −2 | **DC9 commands:649** (error dialog); **RP8 replace:628** (the D10 dialog, item 12) |
| M-12a-25 | exit checks clean before settling | +92 −1 | **EX5 exit:301** |
| M-12a-26 | a nested flow clears busy | +90 −3 | **RN2 replace:521**; RN3:561, EX4 exit:266 |
| M-12a-27 | default page origin from the portrait size | +88 −5 | **ND1 new_document:41**; ND3:73, DH1 host:113, DH2:141 |
| M-12a-28 | `TextTool.isMidShape => isPending` (app) | +90 −3 | **ST3 settle:206** (Save disabled with the entry open); ST2:177, ST8:396 |
| render (plan's MT) | same mutation, render test | +32 −2 | **MS4 mid_shape:177** (×2 flipY) |
| M-12a-29 | Redo does not re-read `canRedo` | +92 −1 | **DC10 commands:732**: `expect(spy.calls, 1, …)`, the `onBeforeMutate` spy |
| M-12a-30 | the outer binding runs the command | +92 −1 | **DC9 commands:690** (dropdown case, a write lands) |
| M-12a-31 | the app's builder never rebuilds | +80 −13 | **DC11 commands:788** (tab title); DH3:49, DH4:42, DS1:77, DS4:179, DS7:293, RN2 and RP1/3/6/7/8 replace:98 |

### The carried items' mutants

| Mutant | Mutation | Result | Red |
|---|---|---|---|
| t2-review R3 | `isMidShape => isPending && controller.text.isNotEmpty` | +32 −2 | **MS4 mid_shape:181** (×2) |
| t4-review R7 | the fake checks `holdWrites` before `failNextWrite` (a support-file mutant) | +92 −1 | **DF7 files:160** (see note) |
| t4-review S1 | the `if (dart.library.io)` export line dropped | +92 −1 | **DF8 files:180** (the stub throws `UnsupportedError`) |
| t6 m1: the old layout | Flexible name, Flexible status, `Spacer` | +92 −1 | **DC12b commands:923** (notice cut) |
| t6 m1: halves | Flexible name + Expanded status (the literal ruling) | +92 −1 | **DC12b commands:923** |
| t6 m1: name uncapped | no `ConstrainedBox` on the name | +91 −2 | **DC12 commands:826**, DC12b:937 |
| t6-review R6 | the shell's file-command flags not disposed | +92 −1 | **DH7 host:380** |
| t7-review Y1 | a mouse on Android keeps the entry (`if (!kIsWeb)`) | +92 −1 | **ST6 settle:337** |
| t7-review Y2 | a touch on macOS keeps the entry | +92 −1 | **ST5 settle:297** |
| t7 Y6 | Save As does not settle | +92 −1 | **ST1b settle:140** |
| t7 Y3 / Y4 / Y5 | New / Open / Open sample do not settle | +92 −1 each | **RP7 replace:423** (Task 8's case) |
| t7 Y7 | Save does not settle | +87 −6 | ST1:140, ST2:179, ST3:216, ST4:263, ST7:373, ST8:396 |
| t7 Y8 | re-sync only while the scale is focused (undoes deviation 2) | +92 −1 | **ST7 settle:373** |
| t7 Y9 | the settle skips an empty entry (undoes deviation 6) | +92 −1 | **ST8 settle:396** |

**DF7 (a finding, fixed in the test).**
- **First sweep:** R7 went red only by a **30 s timeout**. DF7 awaited the write, which R7 holds forever, before it checked `heldWrites`.
- **Fix:** DF7 now reads `writes`/`heldWrites` synchronously and awaits the throw afterwards.
- **Re-fire:** red at DF7:160 (`Expected: empty Actual: [Instance of '_AsyncCompleter<void>']`), `diff=0`. The line count is unchanged, so DF8:180 stands.

**Task 6's X10 and X15:** these mutants (name/status not `Flexible`) no longer apply to the new layout. `T6-m1-name-uncapped` covers the same seam.

## Greps (final tree, after the sweep, nothing mutated)

- **`dart:io` in the app's lib:** `grep -rn "dart:io" apps/floor_planner/lib` → `lib/document_files_io.dart:6:import 'dart:io';` only.
- **`package:web`:** `grep -rln "package:web" apps/floor_planner/lib` → `document_files_web.dart`, `exit_guard_web.dart` only.
- **`cross_file`:** `grep -rn cross_file` over the app's pubspec, lib and test, `packages/*/pubspec.yaml`, `packages/*/lib` and the root `pubspec.yaml` → no output. It is transitive only (via `file_selector`, in `pubspec.lock`).
- **The removed `UndoStack` primitives:**
  - `grep -rnwE "takeUndo|pushRedo|takeRedo|pushUndoOnly" packages/*/lib packages/*/test apps/floor_planner/lib apps/floor_planner/test` → no output (rc=1).
  - `grep -rnE "(history|_history|UndoStack\([^)]*\)|stack|undo)\.push\(" …` over the same paths → no output (rc=1).
  - A bare `.push(` grep finds only `parametric/room_label.dart:55,71-74`, which is a priority queue, not `UndoStack`.
- **`startupPlan(`:** `grep -rn "startupPlan(" apps/floor_planner/lib` → `document_host.dart:363` (Open sample) and `startup_plan.dart:65` (the definition). 14 test files call it.
- **`parametricCatalog.registerComponents`:** `grep -rn … apps/floor_planner/lib apps/floor_planner/test`.
  - lib: `parametric/catalog.dart:45` only, inside `registerAppComponents`.
  - test: every hit is a decode's `registerComponents` argument or closure: `opening_panel_test:514`, `room_paint_test:509`, `room_panel_test:421`, `dimension_panel_test:505`, `support/wall_fixture:310`, `support/room_fixture:651, 688`, `new_document_test:116`, `startup_plan_test:737`, `selection_panel_test:702`.
- **`Future.delayed(Duration.zero)`:** `grep -rn "Future.delayed(Duration.zero)" apps/floor_planner/lib packages/*/lib` → no output.
- **`debugOnSettle`:** `grep -rn debugOnSettle apps packages` → no output.

## Stale spec citations (for the amendment; the spec is not edited)

| Spec line | Cited | Now |
|---|---|---|
| 365 (D6), 632 (limits) | `placement_tool.dart:199-204` | `:206-211` (t2-review m-2; confirmed) |
| 195 (D2) | `text_entry_overlay.dart:22-24` ("Commit and cancel") | `:24-26`; `:26-29` now adds the flows' commit |
| 195, 206 (D2) | `text_entry_overlay.dart:72-78` (`_onFocus`) | `:80-86` (t7-review n3; confirmed) |
| Also found, not in a review: 193 (D2) | `text_tool.dart:53` (`finish`) | `:59` |
| Also found: 198 (D2) | `page_panel.dart:58-85` | `:67-94` |
| Also found: 200 (D2) | `page_panel.dart:88-90` (`_onScaleTapOutside`) | `:96-98` |

Other citations in the spec (e.g. `main.dart:366-390`, `:381`, `:398-399`, `undo.dart:227-231`) describe the pre-12a tree the spec was written against. No review raised them.

Also for the amendment:
- **Task 5 deviation 8:** DO4 compares with an independently built sample's page, not `startupPage(...)` literally.
- **Task 8:** "flows read the dispatcher, the UI the notifier".

## Gates (final tree `c6c3445`; `export PATH=/root/flutter/bin:$PATH`, `CI=true` on every command)

| Package | Command | Result | Exit |
|---|---|---|---|
| engine | `dart test` | `+1106 -2: Some tests failed.`: the standing `generate_document_test` pair ("both text fractions default to zero…", "the default document is the one Plan 2 measured…") | 1 (standing) |
| engine | `dart analyze` | No issues found! | 0 |
| engine | `dart format …` | Formatted 159 files (0 changed) | 0 |
| render | `flutter test` | `+974 ~1 -7: Some tests failed.`: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 (standing) | 1 (standing) |
| render | `flutter analyze` | No issues found! | 0 |
| render | `dart format …` | Formatted 178 files (0 changed) | 0 |
| app | `flutter test` | `+595: All tests passed!` | 0 |
| app | `flutter analyze` | No issues found! | 0 |
| app | `dart format …` | Formatted 127 files (0 changed) | 0 |
| app | `flutter build web --release` | `✓ Built build/web` | 0 |

**Test counts:** the engine and render counts are unchanged; the edits there were a comment and two expects inside MS4. The app count is 587 + 8: DF7, DF8, DC12b, DH7, ST1b, ST7, ST8, RP8. The engine gate ran after its comment edit; the render and app gates ran after the sweep, on the committed content, which differs from the swept tree only by DF7's reorder.

**Logs:** `scratchpad/p12t9-gate-*.log`.

## Deviations

1. **Item 3:** only the flutter bound was raised; see above. Controller's ruling needed.
2. **Item 5:** a half-cap `ConstrainedBox` inside an `Expanded` `LayoutBuilder`, rather than the literal `Flexible` name + `Expanded` status, which caps the status at half. That literal form is the mutant `T6-m1-halves`, red at DC12b.
3. **Item 6:** counts `session.busy` only; `_notBusy` has no listener count without a lib seam. R6 is red through `busy`.
4. **DF7:** reordered after the first sweep so that R7 fails on an assertion, not on a timeout.
