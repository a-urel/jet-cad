# Final whole-branch review: plan 12a (the document lifecycle)

**Verdict: Ready with fixes.**
- **Code:** no Important finding. Every decision (D1 to D14, R-1 to R-10, as amended) is met. Every sampled named mutant and every cross-task mutant I added is red, except one equivalent (Yi).
- **What the fixes are:** documentation corrections only (D-1 to D-5 below). The results note and STATUS predate Task 9b, and 9b shifted the line numbers of `document_commands_test.dart`, so figures of record are stale.
- **Minor code findings:** one, m-1 (a debug-only framework assertion). No code change is required before merge.

**How I reviewed:**
- **Where:** the detached worktree `.claude/worktrees/plan-12a-review` at `da20206`. Scope: `cac7765..da20206` (19 commits).
- **What I read:** CLAUDE.md; the spec whole (revision 4 plus "Amended at execution"); the plan; the ledger (every ruling); t9b-brief, t9b-report, t9-review; the results note; the `2d57d22` edits to STATUS, `roadmap/00-README.md`, `roadmap/12-app-shell.md` and the rooms spec. I also read all of `document_host.dart`, `shell_commands.dart`, `document_toolbar.dart`, `shortcut_guard.dart`, the `_io`/`_web`/`_stub` files, the `main.dart` diff, `undo.dart` and the render diff.
- **Tree state:** it is left as I found it. `git status` shows only the known `packages/jet_cad/analysis_options.yaml` rewrite.
  - Every mutant was restored by `cp`, and each restore printed `diff=0`.
  - One mutant run was interrupted by SIGINT, after Ya had finished and Yb had just started. Python's `finally` restored the file, and `diff` against the Yb backup gave 0.
  - Probes were deleted.
- **Scripts and logs:** in the scratchpad: `p12rF-*.log`, `p12rF-results.jsonl`, `mut.py`, `m9b.py`, `mnamed.py`, `mown.py`, `webprobe.py`, and `probes/`.

## Gates (run by me on `da20206`, `CI=true`, `PATH=/root/flutter/bin:$PATH`, after `flutter pub get`)

| Package | Command | Result |
|---|---|---|
| engine | `dart test` | `00:20 +1106 -2: Some tests failed.`: the two standing `generate_document_test` cases (rc 1, standing) |
| engine | `dart analyze` / `dart format --output=none --set-exit-if-changed .` | No issues found! / Formatted 159 files (0 changed) |
| render | `flutter test` | `00:57 +974 ~1 -7: Some tests failed.`: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2 (standing) |
| render | `flutter analyze` / `dart format …` | No issues found! / Formatted 178 files (0 changed) |
| app | `flutter test` | `03:26 +596: All tests passed!` (rc 0) |
| app | `flutter analyze` / `dart format …` | No issues found! / Formatted 127 files (0 changed) |
| app | `flutter build web --release` | `✓ Built build/web` (rc 0) |

- **The two invariant tests are green and unedited:** `git diff cac7765..da20206` of `packages/jet_cad_2d/test/invariants` and `packages/jet_cad_2d_flutter/test/invariants` is empty.
- **Web compiles both `_web` files.** I put a type error in each of `document_files_web.dart` and `exit_guard_web.dart` and ran `flutter build web --release`. It exited 1, and both errors were printed ("A value of type 'String' can't be returned…" and "…can't be assigned…"). Both files were restored with `diff` 0.

## 1. Task 9b (`da20206`) as its task review

- **Scope:** only `main.dart` (+24/−8) and `document_commands_test.dart` are changed. There is no docs change and the packages are untouched.
- **The fix is sound:**
  - `tail = min(16, free)`, `shared = free − tail`, `gap = min(16, shared)`, and the cap is `min(shared/2, shared − gap)`.
  - None of these can go negative, and when `shared ≥ 32` they reduce exactly to Task 9's layout.
  - The deviation from the reviewer's `(W−16)/2` is justified: that formula would move the name 8 px off DC12b's half.
- **DC12b's premise** now reads `getMaxIntrinsicWidth`, as asked (m-2 closed).
- **First overflow, measured by me** with a temporary probe on DC12c's fixture, stepping 1 px down from 900 px at 600 px high. The probe was deleted.
  - Long name and long status: first overflow at **575 px** ("overflowed by 1.00 pixels"; zoom right edge 564 in a 575 px bar). This matches the report.
  - Long name with the ordinary status line: first overflow at **561 px**. The zoom text is narrower there.
  - Both are below the old 590/591 px floor. m-1 of the Task 9 review is closed.

**Mutants re-fired (`--plain-name DC12`: DC12, DC12b, DC12c).** Every one is red, and every restore gave `diff=0`.

| Mutant | Mutation | Red at |
|---|---|---|
| A | `main.dart` = the `2d57d22` copy | DC12c `document_commands_test:1003` |
| B | `tail = 0` plus a fixed 16 px `SizedBox` before OSNAP | DC12c `:1003` |
| C | cap `constraints.maxWidth / 2` | DC12b `:973`, DC12c `:1003` |
| E | the `5998504` bar block (`Flexible`/`Flexible`/`Spacer`) | DC12b `:956`, DC12c `:1003` |
| F | "halves" (`Flexible` name, `Expanded` status, 16 px before OSNAP) | DC12b `:956`, DC12c `:1003` |
| G | DC12b's room name `'den'` | DC12b `:961` (the premise) |
| L1 (own) | the tail gap moved in front of the status | DC12b `:958` |
| L2 (own) | cap `shared − gap` (no half) | DC12b `:972` |
| L3 (own) | `tail = 16` fixed, inside the builder | DC12c `:1003` |
| L4 (own) | `gap = min(16, free)` | DC12c `:1003` |
| L5 (own) | `shared = free` | DC12b `:973`, DC12c `:1003` |

**Task 9b: Approved** (folded into this review, as ruled).

## 2. The branch against the spec, and the cross-task seams

**Decisions:** D1–D14 and R-1–R-10, as amended, are met. I read every one against the code.
- **D2:** the swap is keyed. The replacement is built before `replace`. Disposal and measurer clearing happen post-frame. The settle registrar releases only its own registration.
- **D3:** the transitions are whole. `abort*` changes nothing, and `clear` keeps `_state`.
- **D5:** flows decide from `differsFromSave`; the UI shows `dirty`.
- **D6:** one table. The chords are bound for disabled commands too. Mid-shape and busy combine through `DerivedFlag`. There is a consume-only binding above the Navigator.
- **D8:** Open catches any object and clears the fresh measurer.
- **D9:** the conditional exports are correct.
- **D10/D11:** the order is busy → settle → decide. The exit is itself a busy flow.

**Cross-task probes.** These were temporary tests, deleted afterwards. All were green, except S2, which exposed m-1.

| Probe | What it checks | Result |
|---|---|---|
| S1 (×4) | Dirty and titled, New by Cmd+N or by a toolbar click, answered Don't Save or Save. Then, with no canvas click, Cmd+S and `L`. | Focus is on `InteractionLayer` after the swap. Cmd+S asks where (untitled). `L` gives LineTool. |
| S1c | Clean, Open sample by toolbar click, then Cmd+S and `L`. | Same result: the keys reach the new shell. |
| S3 (×3) | New, Open sample or Open with a text entry typed on a clean document. | The settle commits the text, the dialog asks, Cancel keeps the document, and no picker opens. |
| S5 | Cmd+Z and Cmd+Shift+Z under the replace dialog. | History unchanged (depth, canRedo, stateId). |
| S2 | The exit request with a text entry typed on a clean document. | Behaviour is correct: the text is committed, the dialog asks, Cancel gives `AppExitResponse.cancel`, and the document and text are kept. But see m-1. |
| Yi-probe | Focus after a toolbar click, and Tab from the canvas, with and without `ExcludeFocus`. | Identical either way (see "Own mutants"). |

**Shortcuts and the toolbar under each overlay:**
- **Replace dialog:** RP1 (all seven buttons disabled), RP8 (file chords handled, nothing runs), S5 (edit chords inert).
- **Error dialog:** DC9.
- **Text entry:** ST2/ST3 (Cmd+S and toolbar Save commit the entry), S3.
- **Mid-shape:** DC5, and EX6 for the exit.

**Web and macOS paths:**
- `dart:io` appears only in `document_files_io.dart`. `package:web` and `dart:js_interop` appear only in `*_web.dart`.
- There is no `cross_file` import.
- The web build compiles both `_web` files (the probe above).

## 3. Non-negotiables

| Rule | Status |
|---|---|
| Frame path | Invariant tests green and unedited. Nothing added runs per frame: `DerivedFlag.update` is O(1) and runs on tool notifications; `MaterialApp` rebuilds on name or dirty changes only. |
| Draw order | No entity writes. |
| `Tolerance` vs `==` | Only exact comparisons of ints and stored values (`stateId`, the page literal). |
| `analysis_options.yaml` | None in `git diff --name-only cac7765..da20206`. |
| Trailers | All 19 commits carry both trailers (checked per commit). |
| Model identifiers | None in the diff or the messages beyond the mandated `Co-Authored-By` trailer, which the plan's global constraints quote. |

## 4. Mutants

**Named mutants re-fired (my own spellings).** Every one is red, and every restore gave `diff=0`.

| Mutant | Mutation | Red at (first line) |
|---|---|---|
| M-12a-2 | `markSaved` does not move `_savedState` | **DH3 `document_host_test:68`**; **EX1 `document_exit_test:64`**; also EX2–EX7, EG1 |
| M-12a-9 | `invoke` runs a disabled Undo | DC7 `document_commands_test:600` |
| M-12a-10 | `while (false && differsFromSave)` | **RP1 `document_replace_test:124`**; RP2–RP8, RN1–RN3 |
| M-12a-11a | the host's settle is a no-op | ST1 `document_settle_test:140`; ST2–ST4, ST7, ST8 |
| M-12a-11b | no `applyFocusChangesIfNeeded` | ST1 `:140`, ST1b |
| M-12a-13 | `markSaved(<id after the write>)` | DS1 `document_save_test:75` (both `writesInPlace`) |
| M-12a-15c | the guard lacks Ctrl+Y | DC8 `document_commands_test:643` |
| M-12a-19 | `replace` keeps the first subscription | DH4 `document_host_test:48`; DH6 `:304` |
| M-12a-23 | `_idle` ignores mid-shape | DC5 `document_commands_test:453`; `:526` |
| M-12a-24 | the above-Navigator bindings removed | DC9 `document_commands_test:682`; RP8 `document_replace_test:628` |
| M-12a-25 | the exit returns `exit` when clean, before settling | EX5 `document_exit_test:301` |
| M-12a-26 | a nested `_flow` clears busy | RN2 `document_replace_test:521`; RN3 `:561` |
| M-12a-28 | `TextTool.isMidShape => isPending` | app ST3 `document_settle_test:206` (ST2 `:177`, ST8 `:396`); render MS4 `mid_shape_test:177` |
| M-12a-29 | Redo reads `canRedo` before the settle | DC10 `document_commands_test:765` |
| M-12a-31 | the app's `ListenableBuilder` listens to nothing | DC11 `document_commands_test:821` |

**Own mutants at cross-task seams:**

| Mutant | Mutation | Result |
|---|---|---|
| Ya | `replace` keeps the old save point | Red: 29 tests in 7 files. The first lines are DC4 `commands:422` and DH2 `host:156`. Some tests hang to the 10 min timeout on a dialog that never comes. |
| Yb | the settle release drops the registration unconditionally (a keyed swap runs the new `initState` before the old `dispose`) | Red: RP7 `document_replace_test:423` |
| Yc | the title listens to `dirty` only, not the session (name changes) | Red: DH6 `document_host_test:298` |
| Yd | the exit is not a busy flow | Red: EX2 `document_exit_test:130`, EX4 `:266` |
| Ye | the exit guard does not follow `dirty` | Red: EG1 `document_exit_test:365` |
| Yf | the shell's Undo/Redo flags ignore the history stream | Red: DC1 `commands:259` and 5 more |
| Yg | the settle does not re-sync the page scale | Red: ST4 `settle:263`, ST7 `:373` |
| Yh | `_write` marks saved without the identity guard | Red: RN3 `document_replace_test:567` |
| Yj | the exit's busy check removed | Red: EX1 `exit:64`, EX4 `:232` |
| Yk | the exit does not settle | Red: EX5 `exit:301` |
| Yi | `ExcludeFocus(excluding: false)` on the toolbar | **Survives (equivalent).** A tap on an `IconButton` does not request focus: my probe shows `InteractionLayer` focused after a toolbar click under both trees, and Tab from the canvas lands on the page panel's dropdown under both. `ExcludeFocus` only keeps the buttons out of keyboard traversal, which spec D7 motivates and no test observes. Recorded, no action. |

**No survivor is a defect.**

## Findings

### Important

None.

### Minor

**m-1. Exiting with an open text entry reports a debug-only framework assertion.**
- **Trigger:** a text entry typed on a clean document, then an exit request (Cmd+Q, Quit, or the close button). It is reproduced by probe S2.
- **What happens:** the exit's settle commits and closes the entry, which disposes its `EditableText`. That `EditableText` owns an `AppLifecycleListener` (`editable_text.dart:2634, 3320`, Flutter 3.47).
- **Why that asserts:** `WidgetsBinding.handleRequestAppExit` iterates a copy of its observers (`binding.dart:895-918`). After the host's listener answers, the binding calls `didRequestAppExit` on the disposed one. In debug this reports "A AppLifecycleListener was used after being disposed" through `FlutterError.reportError`.
- **Impact:** the answer is still correct (cancel, text kept; the exit proceeds on Don't Save). In release the assert is off, and the disposed listener answers `exit`, which cannot override the host's cancel.
- **Visibility:** a red console error in the human's macOS debug run, and a failing widget test if a test drives this path. No landed test does.
- **Proposed fix:**
  - Record it in D14 and in the results note's found-not-fixed list ("exit with an open text entry: a debug-only framework assertion, harmless in release").
  - Optionally pin it with an EX test that runs the exit with a typed entry, answers Cancel, and expects `tester.takeException()` to be that assertion. A Flutter upgrade that fixes or changes it would then be noticed.
  - A code mitigation is not worth it: the observer list is the framework's.

**m-2. The spec's header still says "Status: design, revision 3".**
- **Where:** line 3. The text since `2be9233` applies revision 4, and the plan cites revision 4.
- **Fix:** "revision 4".

### Documentation corrections (D-1 to D-5): apply before merge

**D-1. Results note, Task 9's row.** It should read:

> | 9 Sweep: carried gaps, status-line width, mutants, greps | `e678183`, `c6c3445`, `da20206` (9b) | Approved (m-1: the new top bar first overflowed at 622 px, 32 px sooner; m-2: DC12b's width premise read the slot) → 9b (the gaps shrink in a narrow window, first overflow 575 px; DC12c; DC12b's premise reads the intrinsic width): Approved in the final whole-branch review |

The sentence "Every task had … an independent reviewer" should add that 9b's review was folded into the final review.

**D-2. Results note, the mutants section** needs 9b's facts:
- **The final tree is `da20206`, not `c6c3445`.** Say that the named mutants were re-fired by Task 9 on `c6c3445`, and that the final review re-fired a sample on `da20206` (the table in section 4 above).
- **Line numbers.** 9b inserted a 33-line helper, so every `document_commands_test` line in the table is stale by +33:
  - DC5 `:420` → **`:453`** (M-12a-23)
  - DC7 `:567` → **`:600`** (M-12a-9)
  - DC8 `:610` → **`:643`** (M-12a-15)
  - DC9 `:649` → **`:682`** (M-12a-24)
  - DC9 `:690` → **`:723`** (M-12a-30; I did not re-fire this one, but the source line is the same assertion shifted by 33)
  - DC10 `:732` → **`:765`** (M-12a-29)
  - DC11 `:788` → **`:821`** (M-12a-31)
  - Every other file's lines are unchanged, and I confirmed them: DH3 `:68`, EX1 `:64`, RP1 `:124`, ST1 `:140`, DS1 `:75`, DH4 `:48`, RP8 `:628`, EX5 `:301`, RN2 `:521`, ST3 `:206`, MS4 `:177`.
- **Add 9b's mutants:** A, B, C, E, F and G, red at DC12b `:956`/`:961`/`:973` and DC12c `:1003`.

**D-3. Results note, the other sections:**
- **"What the execution found":** the status-line item should add "Task 9b: the bar's gaps give way in a narrow window; first overflow 575 px (Task 9's layout 623 px, the `5998504` bar 591 px); DC12c steps 624 → 576 px."
- **Gates of record:** app **596** (+82: DC12c); web `✓ Built` on `da20206`.
- **Found, not fixed:** add m-1.

**D-4. The spec's amendment, D7.** Add one sentence: "Task 9b: the gap after the name and the 16 px gap before OSNAP sit inside the shared `Expanded` and shrink to 0 in a narrow window, and the half cap gives way to the gap below 32 px; the bar first overflows at 575 px in `flutter test`'s font (it was 591 px before 12a)." Also fix m-2 here.

**D-5. STATUS.md:**
- **Gates:** app **596**.
- **Reviews:** "Tasks 1 and 5 after a test-only follow-up each" becomes "Tasks 1 and 5 after a test-only follow-up each, Task 9 after a layout fix (9b, reviewed in the final review)".
- **Found and fixed:** add "the top bar overflowing sooner in a narrow window (9b)".
- **The human's look:** the list is a summary that omits two lines the note owes: Cmd+W asks to quit (macOS), and a click on Save while typing a text entry saves the text (web). Either add them or say "as the results note lists".
- **Nothing is ticked on the human's behalf:** the macOS and web look is OWED in STATUS, the note and the roadmap row. That is correct.

**Faithful as written** (checked against the ledger and the tree):
- `roadmap/00-README.md` row 12 (NOT MERGED, look OWED);
- `roadmap/12-app-shell.md`: its open items match the note's found list and D14;
- the rooms spec's R-3 note;
- the found-not-fixed list: language version, the quit quirk, Cmd+W, the first macOS plugin, the web limits, the equivalents;
- the spec amendment's other lines: D2, D4/D8, D5, D6, D9, D10/D11, D3 (the spec 02 note is correctly dropped: `UndoStack` is named in no other spec, by my grep), and the citations.

**Two notes on dates, not errors:**
- `origin/plan-12a/document-lifecycle` is at `2d57d22`; `da20206` is not pushed yet.
- The note's `ledgers/2026-09-30-plan-12a/` link resolves only once the archive commit lands.
