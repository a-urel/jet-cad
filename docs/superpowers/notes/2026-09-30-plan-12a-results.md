# Plan 12a results — the document lifecycle

**Branch:** `plan-12a/document-lifecycle`, cut from `spec-12a/document-lifecycle`
at `d499615` (the plan's commit; the spec branch was cut from `main` at
`cac7765`). **Spec:** [2026-09-30-document-lifecycle-design.md](../specs/2026-09-30-document-lifecycle-design.md),
revision 4 (`2be9233`), approved by the human on 2026-09-30 ("onaylıyorum,
planı yaz"), amended at execution (its closing section). **Plan:**
[2026-09-30-document-lifecycle.md](../plans/2026-09-30-document-lifecycle.md).
**Ledger:** [`ledgers/2026-09-30-plan-12a/`](../ledgers/2026-09-30-plan-12a/)
(`progress.md` carries every ruling with its cost-if-wrong).

Sub-project 12 is split into slices (the human's decision 1); this is 12a.
The app now opens on an empty document; New, Open, Open sample, Save and
Save As work on macOS (native panels, write in place) and on web (file
picker, download); the document is swapped at runtime by a keyed rebuild;
dirty follows the undo position against a save point; replacing or closing
a dirty document asks; a toolbar and the shortcuts come from one command
table; Undo gets a button and Redo gets both.

Every task had a fresh implementer and an independent reviewer, who re-ran
the gates and re-fired the mutants in a separate, detached worktree.

| Task | Commits | Review |
|---|---|---|
| 1 Engine: the state identity (D3) | `f8e296d`, `06c9c44` (1b) | Needs fixes (a new dispatcher's initial id unpinned) → 1b Approved |
| 2 Render: `Tool.isMidShape` (D6, U-1) | `1fce8b7` | Approved |
| 3 The empty document, one registration (D4, D8) | `7b08ae9` | Approved |
| 4 `DocumentFiles` for macOS and web (D9, D12) | `0b3bf76` | Approved |
| 5 The session, the swap, Open and Save (D2, D5, D8, D13) | `efb8700`, `15cdbea` (5b) | Needs fixes (a titled document's file kept across a replace was unpinned) → 5b Approved |
| 6 The command table, toolbar, shortcuts (D6, D7) | `95bf923` | Approved |
| 7 Settling pending input (D2) | `725ff74` | Approved |
| 8 Replacing and closing a dirty document (D10, D11, D12) | `5998504` | Approved |
| 9 Sweep: carried gaps, status-line width, mutants, greps | `e678183`, `c6c3445` | Approved (m-1: the new top bar overflows 32 px sooner, at 622 px; m-2: DC12b's width premise reads the slot) → 9b |

## What the execution found that the spec did not

- **Focus stranded on the route scope.** On macOS with a mouse, a text
  entry ended by a click on the tool palette, the page panel's title or a
  checkbox left focus on the route's scope (EditableText's default
  tap-outside is a plain `unfocus()`); Cmd+S was then consumed above the
  Navigator and saved nothing, and the tool letters were dead until a
  canvas click. Found by Task 6, confirmed and fixed in Task 7: the entry's
  `onTapOutside` reproduces the framework's platform rule and returns focus
  to the canvas (ST5, ST6; mutants Y1, Y2, X6, X7).
- **A stale dirty flag in the replace flows.** The settle commits a typed
  panel value synchronously, but `session.dirty` is recomputed from the
  dispatcher's asynchronous change stream a microtask later; New, Open and
  Open sample read "clean" and replaced a document the settle had just
  dirtied, losing the value. Found by a test the Task 7 review asked for;
  fixed in Task 8: `DocumentSession.differsFromSave` reads the dispatcher.
  Flows decide from the dispatcher; the UI shows the notifier (RP7, EX5;
  mutant X1).
- **The status line was capped at a third of the free width** (Task 6's
  three flex-1 children): room notices were cut at 1440 px with room to
  spare. Task 9: the name and the status share one `Expanded`, the name
  capped at half and taking only what it needs (DC12, DC12b).
- Spec D4/D8's `PageNotifier.value == startupPage(...)` does not hold
  literally (the sample computes its page before its dimensions extend the
  extents); DO4 compares with an independently built sample.

## Mutants

All 32 named mutants (M-12a-1 … 31 and 7b), with variants, and the render
mutant were re-fired on the final tree `c6c3445` by Task 9's sweep (58 runs,
every restore `diff` 0) and are red; the first red line of each:

| Mutant | Red at |
|---|---|
| M-12a-1 save writes a key-sorted map | DO1 `document_open_test:124` (first bytes == the codec's) |
| M-12a-2 save point not moved on save | DH3 `document_host_test:68`; exit half EX1 `document_exit_test:64` |
| M-12a-3 moved on a failed / cancelled save | DS2 `document_save_test:107` / DS3 `:138` |
| M-12a-4 dirty never cleaned by undo | DH3 `document_host_test:52` |
| M-12a-5 id from the top entry's identity | `undo_state_test:97` |
| M-12a-6 id = depth / eviction hands the id down | `undo_state_test:215` / `:224` |
| M-12a-7 / 7b decode registers only the catalog / only the page | DO4 `document_open_test:275` / DO5 `:294` |
| M-12a-8 swap before decode | DO6 `document_open_test:360` |
| M-12a-9 disabled Undo chord calls the dispatcher | DC7 `document_commands_test:567` |
| M-12a-10 replace without the dialog (all, and per flow) | RP1 `document_replace_test:124` |
| M-12a-11 no settle / no focus apply | ST1 `document_settle_test:140` |
| M-12a-12 busy never set | DS1 `document_save_test:64` |
| M-12a-13 save point read after the write | DS1 `document_save_test:75` |
| M-12a-14 abort restamps (undo / redo) | `undo_state_test:261` / `:286` |
| M-12a-15 a/b/c the guard lacks a redo chord | DC8 `document_commands_test:610` |
| M-12a-16 Open catches `on Exception` only | DO6 `document_open_test:343` |
| M-12a-17 busy not reset on failure | DS2 `document_save_test:108` |
| M-12a-18 Open adds the DASHED record | DO3 `document_open_test:253` |
| M-12a-19 the first subscription kept | DH4 `document_host_test:48` |
| M-12a-20 the shell disposes the host's snap | DH5 `document_host_test:210` |
| M-12a-21 the old document not disposed | DH5 `document_host_test:205` |
| M-12a-22 toolbar outside the tap region | ST3 `document_settle_test:216` |
| M-12a-23 idle ignores mid-shape | DC5 `document_commands_test:420` |
| M-12a-24 no above-Navigator binding | DC9 `document_commands_test:649`; RP8 `document_replace_test:628` (under the D10 dialog) |
| M-12a-25 exit checks clean before settling | EX5 `document_exit_test:301` |
| M-12a-26 a nested flow clears busy | RN2 `document_replace_test:521` |
| M-12a-27 default page origin from the portrait size | ND1 `new_document_test:41` |
| M-12a-28 `TextTool.isMidShape => isPending` | ST3 `document_settle_test:206`; render MS4 `mid_shape_test:177` |
| M-12a-29 Redo does not re-read `canRedo` | DC10 `document_commands_test:732` (the `onBeforeMutate` spy) |
| M-12a-30 the outer binding runs the command | DC9 `document_commands_test:690` |
| M-12a-31 the app's builder never rebuilds | DC11 `document_commands_test:788` |

The reviews added more than a hundred mutants of their own; every survivor
was either closed by a test (Tasks 1b, 5b, and the carried items of Task 9)
or recorded as equivalent (listed in each review). Task 9's report has the
full tables.

## Engine and render changes

- Engine (Task 1): `UndoStack` entries record the state they return to;
  transitions `recordExecute`, `beginUndo/commitUndo/abortUndo`,
  `beginRedo/commitRedo/abortRedo`; `CommandDispatcher.stateId`. The old
  public primitives (`push`, `takeUndo`, `pushRedo`, `takeRedo`,
  `pushUndoOnly`) are removed (plan P-2; nothing outside the dispatcher
  used them). During an undo or redo `apply` the entry now stays on its
  stack (no command re-enters the dispatcher).
- Render (Task 2): `Tool.isMidShape` (false; `PlacementTool` → `isPending`;
  `TextTool` → false).

## Gates of record (Linux container)

Branch point (`cac7765`): engine 1,095 + 2 standing
(`test/testing/generate_document_test.dart`), render 940 + 1 skip + 7
standing (`text_ladder` 1–5, `text_lod_ladder` 1–2), app 514.

- **engine** 1,106 + 2 standing (+11: `undo_state_test.dart`); analyze and
  format clean. No engine file changed after `06c9c44`.
- **render** 974 + 1 skip + 7 standing (+34: `mid_shape_test.dart`, 2
  expects added by Task 9); analyze and format clean.
- **app** 595 (+81); analyze and format clean.
- **web** `flutter build web --release` `✓ Built` (`c6c3445`).

## Found, not fixed

- **The language version.** `file_selector_web` needs Dart ^3.10 / Flutter
  >= 3.38; the app's pubspec now declares `flutter: ">=3.38.0"` but keeps
  `sdk: ^3.5.0` (with a comment): raising `sdk` to ^3.10 switches the
  formatter to the tall style (120 files restyled) and raises 8
  `use_null_aware_elements` lints. Its own item.
- **The macOS quit quirk** (spec D11, D14): a second Cmd+Q or close click
  while the exit dialog is up quits without saving (Flutter's embedder).
  Not mitigated.
- **Cmd+W** (the menu's Close) routes through `windowShouldClose` and so
  asks to quit the app — consistent with terminating after the last window
  closes; for the human's look.
- **The first macOS plugin.** `file_selector_macos` is the app's first
  macOS plugin; the first macOS build will add CocoaPods or Swift Package
  Manager integration to `macos/`, to be committed then.
- **Web:** a download's success is not reported (decision 9); a picker
  cancel on Safari before 16.4 is never reported (the commands stay
  disabled until reload); an input blur after a window switch may still
  unfocus a text entry to the route scope (`connectionClosed`); browsers
  show their generic `beforeunload` text.
- **Equivalent or unreachable, recorded:** the replace dialog's barrier
  dismiss (a `null` answer is Cancel); the host's dirty-listener removal
  (host and session share a lifetime); the default page attached without
  `execute` (only `stateId` differs); the save identity guard before
  `markSaved` (reachable only by a swap under a held write, which the UI
  disables — pinned through the flows by RN3).
- Carried from earlier, untouched: the fix/live-object-rule note's list.

## The human's look (owed)

**macOS** (the sandboxed release build): New, Open, Save, Save As with the
native panels; a saved `.jetplan` opens back identically; Cmd+Q and the
window's close button on a dirty document ask, and Cancel keeps the
window (the known quirk: a second Cmd+Q during the dialog quits); Cmd+W
asks to quit; the first build's `macos/` integration changes, to commit.

**Web (Chrome, Firefox, Safari):** Open picks a file; Save downloads
`name.jetplan` and the download lands (Safari and Firefox especially: the
anchor is clicked detached and its URL revoked at once); Cmd/Ctrl+S never
opens the browser's Save Page, even during a pending save or with the name
prompt up; closing a dirty tab warns; a click on Save while typing a text
entry saves the text.
